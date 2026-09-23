#!/usr/bin/env bash
# docket.sh — the ac-human docket in one call (read-only).
#
# Computes everything mechanical about the human's docket: the gate beads (the board-scan
# on-docket rules), kind, priority→age order, memo completeness, the anti-rot freshness tag
# (events + `verified:` stamps), queue lanes (collapse / elevate / unreadable titles),
# declared batch lanes with unanimous marking, plans awaiting sign-off, the hopper, and the
# frictions + memory cards. The model judges and drives; it never recomputes these.
#
# Usage:  docket.sh            the full docket for the project containing $PWD
#         docket.sh --gates    the 🔴 section only (one repo's slice of the org-wide sweep)
#         docket.sh --org      --gates for every `.beads/` repo, in parallel
# Lanes:  an app declares batch lanes in `<project>/.claude/docket-lanes.json`
#         (format: this skill's references/docket-lanes.md § Declared lanes).
# Env:    AC_HUMAN_FRICTION_CMD / AC_HUMAN_MEMORY_CMD override the card sources.
#         REPOS_ROOT + APPS_LIST choose the --org repos; unset → engine/machine.sh.
# Exit:   0 rendered (a failed read renders `?` and is named in the ⚠ Also section);
#         2 not inside a git repo.

MODE=full
case "${1:-}" in --gates) MODE=gates ;; --org) MODE=org ;; esac

SELF=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
SKILLS=$(cd "$SELF/../.." && pwd)
REGISTRY=$(cd "$SKILLS/.." && pwd)
BR_CALL="$SKILLS/_tools/br-call.sh"

if [ "$MODE" = org ]; then
  O=$(mktemp -d); trap 'rm -rf "$O"' EXIT
  {
    if [ -n "${REPOS_ROOT:-}" ]; then
      echo "$REPOS_ROOT"
      [ -f "${APPS_LIST:-}" ] && while IFS= read -r a; do [ -n "$a" ] && echo "$REPOS_ROOT/$a"; done < "$APPS_LIST"
    else
      ORG=$("$REGISTRY/engine/machine.sh" --org-root 2>/dev/null)
      [ -n "$ORG" ] && { echo "$ORG"; for c in "$ORG"/*/; do echo "${c%/}"; done; }
      echo "$REGISTRY"
      "$REGISTRY/engine/machine.sh" --targets 2>/dev/null | cut -f1
    fi
  } | awk 'NF && !seen[$0]++' | tee "$O/repos" >/dev/null
  n=0
  while IFS= read -r repo; do
    [ -d "$repo/.beads" ] || continue
    n=$((n + 1))
    ( cd "$repo" && timeout 60 "$SELF/docket.sh" --gates 2>&1 || echo "DEGRADED $repo — docket.sh exit $?" ) | tee "$O/$n.out" >/dev/null &
  done < "$O/repos"
  wait
  [ "$n" -eq 0 ] && { echo "org-wide: ? — no .beads/ repo found (set REPOS_ROOT/APPS_LIST or machine.json)"; exit 0; }
  for i in $(seq 1 "$n"); do cat "$O/$i.out"; echo; done
  exit 0
fi

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "docket: not a git repo"; exit 2; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
cd "$PROJECT_ROOT" || exit 2

job() {  # job <name> <seconds> <bash-source> — background; .out/.err/.rc land in $T
  ( timeout "$2" bash -c ". '$BR_CALL'; $3" >"$T/$1.out" 2>"$T/$1.err"; echo $? >"$T/$1.rc" ) &
}

job beads 20 'br_call list --limit 0 --json'
job unpushed 10 'if git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1;
  then git log @{u}..HEAD --oneline -- .beads/issues.jsonl | wc -l; else echo no-upstream; fi'
if [ "$MODE" = full ]; then
  job frictions 30 "${AC_HUMAN_FRICTION_CMD:-python3 '$SKILLS/skill-builder/scripts/friction-rollup.py' --root '$REGISTRY' --view dream}"
  MEM="$SKILLS/dream/scripts/memory-rollup.py"
  if [ -n "${AC_HUMAN_MEMORY_CMD:-}" ]; then job memory 60 "$AC_HUMAN_MEMORY_CMD"
  elif [ -f "$MEM" ]; then job memory 60 "python3 '$MEM' --json"
  else job memory 5 'echo "memory-rollup.py not found" >&2; exit 127'; fi
fi
wait

python3 - "$T" "$PROJECT_ROOT" "$MODE" <<'PY'
import datetime as dt, json, os, re, sqlite3, sys

T, ROOT, MODE = sys.argv[1], sys.argv[2], sys.argv[3]
NOW = dt.datetime.now(dt.timezone.utc)
TODAY = dt.date.today().isoformat()          # local calendar date — the freshness day boundary
failed = []
W, IND = 40, "   "     # every line fits a phone screen unwrapped; rows indent 3

def read(name, cmd):
    try:
        rc = int(open(f"{T}/{name}.rc").read().strip()); out = open(f"{T}/{name}.out").read()
    except (OSError, ValueError):
        failed.append(f"{cmd}: did not run"); return "", False
    if rc != 0:
        err = open(f"{T}/{name}.err").read().strip().splitlines()
        failed.append(f"{cmd}: " + ("timed out" if rc == 124 else err[0] if err else f"exit {rc}"))
        return out, False
    return out, True

def ts(s):
    if not s: return None
    s = re.sub(r"(\.\d{6})\d+", r"\1", str(s).strip().replace(" ", "T")).replace("Z", "+00:00")
    try: t = dt.datetime.fromisoformat(s)
    except ValueError: return None
    return t if t.tzinfo else t.replace(tzinfo=dt.timezone.utc)

def days(s):
    t = ts(s); return (NOW - t).total_seconds() / 86400 if t else 0

def age(s):
    t = ts(s)
    if not t: return "?"
    m = int((NOW - t).total_seconds() // 60)
    return f"{m}m" if m < 60 else f"{m // 60}h" if m < 48 * 60 else f"{m // 1440}d"

def cut(s, n=W - len(IND)):
    """Cut at a word boundary with an ellipsis — never mid-word."""
    s = " ".join(str(s or "").split())
    if len(s) <= n: return s
    c = s[: n - 1]; sp = c.rfind(" ")
    if sp > n * 0.6: c = c[:sp]
    return c.rstrip(" ,:;—-(") + "…"

def wrap2(s, w=W - len(IND)):
    """Up to 2 lines of a title, word-wrapped; the 2nd clipped with an ellipsis."""
    s = " ".join(str(s or "").split())
    if not s: return []
    if len(s) <= w: return [s]
    c = s[:w]; sp = c.rfind(" ")
    if sp > w * 0.6: c = c[:sp]
    rest = s[len(c):].strip()
    return [c, cut(rest, w)] if rest else [c]

def whole(s, w=W - len(IND)):
    """An id you act on, never cut: wrapped at its hyphens, each line inside w."""
    lines = [""]
    for part in re.findall(r"[^-]+-?", str(s or "")):
        if lines[-1] and len(lines[-1]) + len(part) > w: lines.append("")
        lines[-1] += part
    return [l[i:i + w] for l in lines for i in range(0, len(l), w)] or [""]

def pack(parts, width=W - len(IND)):
    """Join short parts with ` · `, starting a new line whenever the next would overflow."""
    lines = []
    for p in parts:
        if not p: continue
        if lines and len(lines[-1]) + 3 + len(p) <= width: lines[-1] += " · " + p
        else: lines.append(cut(p, width))
    return lines

# ── gate beads (board-scan § Docket health: on_docket) ────────────────────
DOCKET = {"human-gate", "pipeline-proposal", "dream-proposal"}
LIFECYCLE = DOCKET | {"refined", "unrefined", "refine-full", "refine-light", "human-ratified",
                      "gate-incomplete", "plan-gap"}
beads = None
raw, ok = read("beads", "br_call list")
if ok:
    try:
        data = json.loads(raw); beads = data["issues"] if isinstance(data, dict) else data
        if not all(b.get("id") and b.get("status") and b.get("created_at") for b in beads):
            raise ValueError("row shape")
    except (ValueError, KeyError, TypeError) as e:
        beads = None; failed.append(f"br_call list: {e}")

def on_docket(b):
    if b["status"] == "deferred": return False
    u = ts(b.get("defer_until"))
    if u and u > NOW: return False
    return b["status"] in ("open", "blocked", "in_progress")

labels = lambda b: set(b.get("labels") or [])
gates = [b for b in beads or [] if labels(b) & DOCKET and on_docket(b)]

# ── anti-rot: events are the record, comments carry the `verified:` stamp ─
fresh, released = {}, {}
db = os.path.join(ROOT, ".beads", "beads.db")
if gates:
    try:
        con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
        ids = [g["id"] for g in gates]; q = ",".join("?" * len(ids))
        for iid, text in con.execute(
                f"SELECT issue_id, text FROM comments WHERE issue_id IN ({q}) ORDER BY created_at", ids):
            m = re.match(r"\s*verified:\s*(\d{4}-\d{2}-\d{2})", text or "")
            if m: fresh[iid] = max(fresh.get(iid, ""), m.group(1))
        ev = {}
        for iid, et, cm in con.execute(
                f"SELECT issue_id, event_type, comment FROM events WHERE issue_id IN ({q}) "
                "ORDER BY created_at, id", ids):
            ev.setdefault(iid, []).append((et, cm or ""))
        for iid, rows in ev.items():  # RELEASED = human-gate removed, then a DECISION/RULING/RELEASE comment
            n, pending = 0, False
            for et, cm in rows:
                if et == "label_removed" and "human-gate" in cm: pending = True
                elif pending and et == "commented" and re.search(r"\b(DECISION|RULING|RELEASE)\b", cm):
                    n += 1; pending = False
            if n: released[iid] = n
        con.close()
    except sqlite3.Error as e:
        fresh = None; failed.append(f"{db}: {e}")

def fresh_tag(b):
    if fresh is None: return "⚠ freshness ?"
    v = fresh.get(b["id"])
    return "(tap-ready)" if v == TODAY else f"⚠ stale — reverify (verified {v})" if v else "⚠ never verified — reverify"

def kind(b):
    t, title = b.get("issue_type"), b.get("title", "")
    if t in ("task", "decision"): return "action" if t == "task" else "decision"
    return "action" if title.startswith("ACTION:") else "decision"

MEMO = ("evidence:", "consequence:", "recommendation:")
def memo_tag(b):
    if kind(b) != "decision": return ""
    if "gate-incomplete" in labels(b): return "⚠ gate-incomplete"
    d = (b.get("description") or "").lower()
    miss = [m[:-1] for m in MEMO if m not in d]
    if len(miss) == len(MEMO): return "⚠ no memo"
    return f"⚠ gate-incomplete (no {', '.join(miss)})" if miss else ""

def tag_list(b):
    out = [fresh_tag(b), memo_tag(b)]
    if released.get(b["id"]): out.append(f"⚠ released ×{released[b['id']]} — read events")
    return [t for t in out if t]

def prio(b):
    p = b.get("priority"); return p if isinstance(p, int) else 9
order = lambda b: (prio(b), -days(b["created_at"]))

# ── lanes: declared batch lanes first, then any label with >5 gates ───────
decl, lanes_file = [], os.path.join(ROOT, ".claude", "docket-lanes.json")
if os.path.isfile(lanes_file):
    try: decl = json.load(open(lanes_file)).get("lanes", [])
    except (ValueError, OSError, AttributeError) as e: failed.append(f"{lanes_file}: {e}")

def extract(b, specs):
    for s in specs if isinstance(specs, list) else [specs]:
        m = re.search(s["re"], b.get(s.get("from", "description")) or "", re.M | re.S)
        if m: return next((g for g in m.groups() if g), None) or m.group(0)
    return None

UUID = re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-|\b[0-9a-f]{12,}\b")
itemized, lanes = [], {}          # lanes: label -> (declaration | None, members)
for b in gates:
    d = next((L for L in decl if L.get("label") in labels(b)), None)
    if d and prio(b) > 1: lanes.setdefault(d["label"], (d, []))[1].append(b)
counts = {}
for b in gates:
    for l in labels(b) - LIFECYCLE: counts[l] = counts.get(l, 0) + 1
laned = {id(b) for _, m in lanes.values() for b in m}
for b in gates:
    if id(b) in laned: continue
    big = sorted((l for l in labels(b) - LIFECYCLE if counts[l] > 5), key=lambda l: (-counts[l], l))
    if big and prio(b) > 1: lanes.setdefault(big[0], (None, []))[1].append(b)
    else: itemized.append(b)
itemized.sort(key=order)
queued = sum(len(m) for _, m in lanes.values())

def prio_tag(b):
    return f"P{prio(b)}" if prio(b) < 9 else "P?"

def gate_block(b):
    """A gate as a stacked mini-block: id·age·P (col 0), title wrapped ≤2 lines, tags — indented."""
    rows = [cut(f"{b['id']} · {age(b['created_at'])} · {prio_tag(b)}", W)]
    rows += [IND + l for l in wrap2(b.get("title"))]
    rows += [IND + l for l in pack(tag_list(b))]
    return rows

def lane_block(label, d, members):
    members.sort(key=order)
    oldest = max(members, key=lambda b: days(b["created_at"]))
    name = (d or {}).get("name", label).upper()
    elevated = len(members) >= 20 or days(oldest["created_at"]) > 21
    out = [cut(f"🔁 {name} · {len(members)}", W), IND + cut(f"oldest {age(oldest['created_at'])}")]
    if elevated: out.append(IND + "⚠ elevated — run this sitting")
    if not d:
        out.append(IND + "→ work the queue")
    else:
        un = [b for b in members if d.get("unanimous") and extract(b, d["unanimous"])]
        out.append(IND + f"{len(un)} unanimous · {len(members) - len(un)} split")
        for b in members:
            vals = {f: extract(b, spec) for f, spec in (d.get("fields") or {}).items()}
            vals["title"] = b.get("title", "")
            segs = d.get("line", ["{title}"]); segs = [segs] if isinstance(segs, str) else segs
            parts = []
            for s in segs:  # a segment whose field did not match is dropped, never rendered as `?`
                try: parts.append(s.format(**{k: v for k, v in vals.items() if v}))
                except (KeyError, IndexError, ValueError): pass
            line = " · ".join(parts) or b.get("title", "")
            out.append(cut(f"{'✓' if b in un else '·'} {b['id']} · {age(b['created_at'])}", W))
            out += [IND + l for l in wrap2(line)]
            ft = fresh_tag(b)
            if ft: out.append(IND + cut(ft))
        if un: out.append(IND + cut(f"→ accept {len(un)} unanimous ✓"))
    unread = sum(1 for b in members if UUID.search(b.get("title", "")))
    if unread > 5: out.append(IND + cut(f"⚠ {unread} unreadable titles — re-title"))
    out.append("")
    return out

def red_section():
    if beads is None: return ["🔴 GATES · ?", IND + "br_call list failed", ""]
    if not gates: return ["🔴 GATES · 0", IND + "—", ""]
    out = []
    for k, title in (("decision", "DECISIONS"), ("action", "ACTIONS")):
        rows = [b for b in itemized if kind(b) == k]
        if not rows: continue
        out.append(f"🔴 {title} · {len(rows)}")
        for i, b in enumerate(rows):
            if i: out.append("")
            out += gate_block(b)
        out.append("")
    for label, (d, members) in sorted(lanes.items(), key=lambda kv: -len(kv[1][1])):
        out += lane_block(label, d, members)
    return out

up, _ = read("unpushed", "git log @{u}..HEAD")
up = up.strip() or "?"
unpushed = "no upstream" if up == "no-upstream" else f"{up} unpushed"

if MODE == "gates":
    gc = len(gates) if beads is not None else "?"
    print(cut(f"{os.path.basename(ROOT)} · {gc} gates · {unpushed}", W))
    print("\n".join(red_section()).rstrip())
    if failed: print("\n".join(cut(f"? {x}", W) for x in failed))
    sys.exit(0)

# ── 🟡 plans awaiting sign-off ────────────────────────────────────────────
def front(path):
    try: text = open(path, errors="replace").read()
    except OSError: return {}
    m = re.match(r"---\n(.*?)\n---", text, re.S)
    fm = {}
    for line in (m.group(1).splitlines() if m else []):
        k = re.match(r"^([A-Za-z_][\w-]*):\s*(.*?)\s*$", line)
        if k: fm[k.group(1)] = k.group(2).strip("'\"")
    return fm

plans = []
pdir = os.path.join(ROOT, "_plans")
for f in sorted(os.listdir(pdir)) if os.path.isdir(pdir) else []:
    p = os.path.join(pdir, f)
    if not f.endswith(".md") or f == "README.md" or not os.path.isfile(p): continue
    fm = front(p); st = fm.get("status", "draft")
    polished = "polish_rounds" in fm and any(k.startswith("polish_fixpoint_") for k in fm)
    if st in ("draft", "refined"): act = "→ approve / refine"
    elif st == "approved": act = "→ ready (plan-approve.sh ready)" if polished else "→ not polished: /ac-polish"
    else: continue
    invest = int(re.sub(r"\D", "", fm.get("polish_rounds") or fm.get("refinement_rounds") or "") or 0)
    plans.append((invest, os.path.getmtime(p), f"_plans/{f}", st, act))
plans.sort(key=lambda x: (-x[0], -x[1]))

# ── 🟢 hopper (board-scan Scan C) ─────────────────────────────────────────
hopper, pool, legacy = [], 0, 0
bdir = os.path.join(ROOT, "_backlog")
SKIPD = {"_done", "_shipped", "complete", "assets", "audits"}
for dp, dns, fns in os.walk(bdir) if os.path.isdir(bdir) else []:
    dns[:] = [d for d in dns if d not in SKIPD]
    top = os.path.relpath(dp, bdir).split(os.sep)[0]
    for f in fns:
        if not f.endswith(".md") or f.startswith("_") or f in ("ROADMAP.md", "BUSINESS-STRATEGY.md"): continue
        fm = front(os.path.join(dp, f)); st = fm.get("status", "?")
        if st == "complete": continue
        path = os.path.relpath(os.path.join(dp, f), ROOT)
        if st == "candidate": hopper.append((path, f"candidate · {fm.get('source', '?')}", "→ approve into pool / discard"))
        elif top == "active" and st == "captured": hopper.append((path, "captured", "→ /ac-plan"))
        elif top == "pool": pool += 1
        elif re.match(r"v\d", top): legacy += 1

# ── cards ─────────────────────────────────────────────────────────────────
def friction_card():
    raw, ok = read("frictions", "friction-rollup.py")
    if not ok: return ["🧰 FRICTIONS · ?", ""]
    try: d = json.loads(raw)["dream"]
    except (ValueError, KeyError, TypeError) as e:
        failed.append(f"friction-rollup.py: {e}"); return ["🧰 FRICTIONS · ?", ""]
    live = [e for e in d.get("entries", []) if e.get("status") in (None, "open")
            and (e.get("promotable") or (e.get("recurrence") or 0) >= 3)]
    live.sort(key=lambda e: -(e.get("weight") or 0))
    out = [f"🧰 FRICTIONS · top {min(3, len(live))} of {len(live)}"]
    for i, e in enumerate(live[:3], 1):
        mark = "·".join(m for m, on in (("critical", e.get("promotable")),
                                        ("common", (e.get("recurrence") or 0) >= 3)) if on)
        out.append(f"{i}. [{mark}] w{int(e.get('weight') or 0)}")
        out += [IND + l for l in whole(e["id"])]
        out.append(IND + cut("fix: " + (e.get("proposed_fix") or "—")))
    out.append(IND + "→ promote · won't fix · later" if live else IND + "—")
    out.append("")
    return out

def memory_card():
    raw, ok = read("memory", "memory-rollup.py")
    if not ok:
        why = (open(f"{T}/memory.err").read().strip().splitlines() or ["failed"])[0]
        failed.pop()
        return [cut(f"🧠 MEMORY · ? ({why})", W), ""]
    try:
        d = json.loads(raw); rows = sorted(d.get("rows", []), key=lambda r: -(r.get("score") or 0))
    except (ValueError, TypeError, AttributeError) as e:
        failed.append(f"memory-rollup.py: {e}"); return ["🧠 MEMORY · ?", ""]
    out = [f"🧠 MEMORY · top {min(3, len(rows))} of {len(rows)}"]
    for i, r in enumerate(rows[:3], 1):
        out.append(cut(f"{i}. [{r.get('kind')}] {r.get('score')} → {r.get('action')}", W))
        for j, f in enumerate(r.get("files") or []):
            lead = "↔ " if j else ""
            out += [IND + (lead if k == 0 else " " * len(lead)) + l
                    for k, l in enumerate(whole(os.path.basename(f), W - len(IND) - len(lead)))]
    out.append(IND + "→ apply · keep · later" if rows else IND + "—")
    for e in d.get("errors") or []: failed.append(f"memory-rollup.py: {cut(e, 60)}")
    out.append("")
    return out

# ── stray human-pending (not gated) ───────────────────────────────────────
STRAY = re.compile(r"waiting on|needs manual|requires account|human decision", re.I)
stray = [b for b in beads or [] if on_docket(b) and not labels(b) & DOCKET
         and STRAY.search((b.get("description") or "") + " " + (b.get("notes") or ""))]

# ── render: one stacked block per section, every line inside W ────────────
props = sum(1 for b in gates if "pipeline-proposal" in labels(b))
est = 2 * (len(itemized) + len([p for p in plans if "approve" in p[4]]))

out = [cut(f"{os.path.basename(ROOT)} · {TODAY}", W), ""]

need = [f"{len(plans)} plan(s) to sign off", f"{len(hopper)} in hopper — ~{est}min"]
if props: need.append(f"⚠ {props} proposal(s) pending")
for label, (d, members) in lanes.items():
    need.append(cut(f"🔁 {(d or {}).get('name', label)} {len(members)} queued"))
if itemized: need.append(f"→ next {itemized[0]['id']}")
need.append(unpushed)
out.append(f"🧑 NEEDS YOU · {'?' if beads is None else len(itemized)} gates")
out += [IND + cut(n) for n in need] + [""]

out += red_section()

out.append(f"🟡 PLANS · {len(plans)}")
if not plans: out.append(IND + "—")
for p in plans[:10]:
    out.append(cut(os.path.basename(p[2]), W))
    out.append(IND + cut(f"{p[3]} · {dt.datetime.fromtimestamp(p[1]):%m-%d}"))
    out.append(IND + cut(p[4]))
out.append("")

out.append(f"🟢 HOPPER · {len(hopper)}")
if not hopper: out.append(IND + "—")
for path, tag, action in hopper[:10]:
    out.append(cut(os.path.basename(path), W))
    out.append(IND + cut(tag))
    out.append(IND + cut(action))
out.append(IND + cut(f"pool {pool}" + (f" · ⚠ {legacy} legacy" if legacy else "")))
out.append("")

out += friction_card() + memory_card()

if stray or failed:
    out.append("⚠ ALSO")
    for b in stray[:5]:
        out.append(cut(f"{b['id']} · {age(b['created_at'])}", W))
        out += [IND + l for l in wrap2(b.get("title"))]
        out.append(IND + "human-pending, not gated")
    if failed: out += [IND + cut(f"? {x}") for x in failed]
print("\n".join(out).rstrip() + "\n")
PY
