#!/usr/bin/env python3
"""render.py — the ac-board render (read-only), fed by the reads board.sh ran.

Usage:  render.py <reads-dir> <project-root> <compact 0|1>
        Each read left <name>.out / .err / .rc in <reads-dir>; the beads jsonl is read in
        place for edges, holders and closure dates (br list carries none of those).
Env:    AC_BOARD_NOW (ISO timestamp) pins "now" — the test seam; unset = the real clock.

Counts come from code, never from a model bucketing raw JSON. A read that cannot answer
renders `?` and is named in the flags block; nothing is guessed.
"""
import datetime as dt, json, math, os, re, sys

T, ROOT, COMPACT = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
NOW = (dt.datetime.fromisoformat(os.environ["AC_BOARD_NOW"]) if os.environ.get("AC_BOARD_NOW")
       else dt.datetime.now(dt.timezone.utc))
W = 40                 # every line fits a phone screen unwrapped
LIVE_MIN = 60          # an agent active within this many minutes is live
STALE_H = 24           # an in-progress bead untouched this long is stale
GATE_LABELS = {"human-gate", "pipeline-proposal", "dream-proposal"}
failed = []            # reads that could not answer — each renders `?` and is named in flags


def slurp(path, **kw):
    with open(path, **kw) as f: return f.read()


def read(name, cmd):
    """(stdout, ok) for a background read; a failure is recorded, never read as empty."""
    try:
        rc = int(slurp(f"{T}/{name}.rc").strip())
        out = slurp(f"{T}/{name}.out")
    except (OSError, ValueError):
        failed.append(f"{cmd}: did not run"); return "", False
    if rc != 0:
        err = slurp(f"{T}/{name}.err").strip().splitlines()
        why = "timed out" if rc == 124 else (err[0] if err else f"exit {rc}")
        failed.append(f"{cmd}: {why}"); return out, False
    return out, True


def ts(s):
    if not s: return None
    s = re.sub(r"(\.\d{6})\d+", r"\1", str(s).strip().replace(" ", "T")).replace("Z", "+00:00")
    try: t = dt.datetime.fromisoformat(s)
    except ValueError: return None
    return t if t.tzinfo else t.replace(tzinfo=dt.timezone.utc)


def mins(s):
    t = ts(s)
    return None if t is None else (NOW - t).total_seconds() / 60


def age(s):
    m = mins(s)
    if m is None: return "?"
    m = int(m)
    return f"{m}m" if m < 60 else f"{m // 60}h" if m < 48 * 60 else f"{m // 1440}d"


def clip(s, w):
    """Cut at a word boundary with an ellipsis — never mid-word."""
    s = " ".join((s or "").split())
    if len(s) <= w: return s
    cut = s[:w - 1]
    sp = cut.rfind(" ")
    if sp > w * 0.6: cut = cut[:sp]
    return cut.rstrip(" ,:;—-(") + "…"


def plural(n, word):
    return f"{n} {word}" + ("" if n == 1 else "s")


def spark(counts):
    top = max(counts) or 1
    return "".join("▁" if c == 0 else "▂▃▄▅▆▇█"[max(0, math.ceil(c / top * 7) - 1)] for c in counts)


def rows_of(raw):
    data = json.loads(raw)
    rows = data["issues"] if isinstance(data, dict) else data
    if not all(r.get("id") and r.get("status") and r.get("created_at") for r in rows):
        raise ValueError("row shape")
    return rows


# ── beads (Scan A categories) ─────────────────────────────────────────────
beads = ready_ids = None
raw, ok = read("beads", "br_call list")
if ok:
    try: beads = rows_of(raw)
    except (ValueError, KeyError, TypeError) as e: failed.append(f"br_call list: {e}")
raw, ok = read("ready", "br_call ready")
if ok:
    try: ready_ids = {r["id"] for r in rows_of(raw)}
    except (ValueError, KeyError, TypeError) as e: failed.append(f"br_call ready: {e}")

# The jsonl is the only source of edges, holders and closure dates.
recs = jsonl = None
try:
    jsonl = slurp(os.path.join(ROOT, ".beads/issues.jsonl"))
    recs = {r["id"]: r for r in (json.loads(l) for l in jsonl.splitlines() if l.strip())}
except OSError:
    failed.append(".beads/issues.jsonl: unreadable")
except (ValueError, KeyError) as e:
    failed.append(f".beads/issues.jsonl: {e}")

labels = lambda b: set(b.get("labels") or [])
is_open = lambda r: r.get("status") not in ("closed", "tombstone") and not r.get("closed_at")
rec = lambda i: (recs or {}).get(i, {})


def deferred(b):
    u = ts(b.get("defer_until"))
    return b["status"] == "deferred" or bool(u and u > NOW)


def gate_kind(b):
    t, title = b.get("issue_type"), b.get("title", "")
    if t in ("task", "decision"): return "action" if t == "task" else "decision"
    return "action" if title.startswith("ACTION:") else "decision"


gates, epics = [], []
loop = {k: [] for k in ("in_progress", "blocked", "ready", "unrefined", "deferred", "other")}
if beads is not None:
    for b in beads:
        if labels(b) & GATE_LABELS:
            if not deferred(b) and b["status"] in ("open", "blocked", "in_progress"): gates.append(b)
        elif b.get("issue_type") == "epic":
            epics.append(b)
        elif deferred(b):
            loop["deferred"].append(b)
        elif b["status"] == "in_progress":
            loop["in_progress"].append(b)
        elif b["status"] in ("open", "blocked") and ready_ids is not None and b["id"] not in ready_ids:
            loop["blocked"].append(b)
        elif b["status"] not in ("open", "blocked"):
            loop["other"].append(b)
        else:
            loop["ready" if "refined" in labels(b) else "unrefined"].append(b)
gate_ids = {b["id"] for b in gates}
live = [b for k in ("in_progress", "blocked", "ready", "unrefined", "other") for b in loop[k]]


def blockers(bid):
    """Open `blocks` targets of a bead — what it is waiting on. None when edges are unreadable."""
    if recs is None: return None
    return sorted(d["depends_on_id"] for d in rec(bid).get("dependencies") or []
                  if d.get("type") == "blocks" and is_open(rec(d["depends_on_id"])))


def blocks_count(gid):
    """How many open beads wait directly on this one."""
    if recs is None: return None
    return sum(1 for r in recs.values() if is_open(r) and gid in (blockers(r["id"]) or []))


def epic_progress(eid):
    kids = [r for r in (recs or {}).values()
            if any(d.get("type") == "parent-child" and d.get("depends_on_id") == eid
                   for d in r.get("dependencies") or [])]
    return sum(1 for r in kids if not is_open(r)), len(kids)


closed7 = None
if recs is not None:
    today = NOW.astimezone().date()
    closed7 = [0] * 7
    for r in recs.values():
        t = ts(r.get("closed_at"))
        if t:
            d = (today - t.astimezone().date()).days
            if 0 <= d < 7: closed7[6 - d] += 1

# ── plans (Scan B) ────────────────────────────────────────────────────────
STAGES = ("draft", "refined", "approved", "bead-ready", "beadified")
plans = []
pdir = os.path.join(ROOT, "_plans")
if os.path.isdir(pdir):
    for f in sorted(os.listdir(pdir)):
        p = os.path.join(pdir, f)
        if not f.endswith(".md") or f == "README.md" or not os.path.isfile(p): continue
        text = slurp(p, errors="replace")
        fm = re.match(r"---\n(.*?)\n---", text, re.S)
        st = None
        if fm:
            m = re.search(r"^status:\s*['\"]?([^'\"\n]+?)['\"]?\s*$", fm.group(1), re.M)
            st = m.group(1).strip() if m else None
        if st is None:  # the Scan B fallback ladder
            st = ("refined" if "## Refinement Log" in text else
                  "approved" if "Status: Approved" in text else
                  "beadified" if jsonl and f in jsonl else "draft")
        plans.append((f[:-3], st, os.path.getmtime(p)))

# ── agents: who is live, and which bead each holds ────────────────────────
agents = mail = None
out, ok = read("roster", "agent-roster.py")
ros = out.strip().splitlines()
if ros and ros[0].startswith("#mail"): mail = ros[0].split("\t")[1]
if ok: agents = [l.split("\t") for l in ros[1:] if l.strip()]
live_names = None if agents is None else {
    a[0] for a in agents if len(a) > 3 and (mins(a[3]) or LIVE_MIN) < LIVE_MIN}
holder = lambda b: b.get("assignee") or rec(b["id"]).get("assignee")
held = None if live_names is None else [b for b in loop["in_progress"] if holder(b) in live_names]

# ── verdict: one of four states, derived — never asserted ─────────────────
n_ready, n_unref, n_gates = len(loop["ready"]), len(loop["unrefined"]), len(gates)
n_blocked, n_ip = len(loop["blocked"]), len(loop["in_progress"])


def verdict():
    if beads is None or ready_ids is None: return "? verdict unknown — the bead reads failed"
    tail = lambda *parts: " · ".join(p for p in parts if p)
    you = plural(n_gates, "gate") + " on you" if n_gates else ""
    if (n_ready or n_ip) and live_names is None:
        return f"? {n_ready} ready · {n_ip} in progress · agent roster unreadable"
    if n_ready and not live_names:
        return tail(f"🥵 STARVED · {n_ready} ready · 0 agents taking", you)
    if n_ready or held:
        return tail(f"✅ FLOWING · {n_ready} ready · {plural(len(held), 'agent')} working", you)
    rest = (f"{n_unref} awaiting refinement" if n_unref else  # the lead cause only
            f"{n_blocked} blocked" if n_blocked else f"{n_ip} in progress, unheld" if n_ip else "")
    if n_gates:
        return tail(f"⛔ STALLED on you · 0 ready · {plural(n_gates, 'gate')}", rest)
    if live:
        return tail("⛔ STALLED · 0 ready", rest)
    return "⏸ EMPTY · 0 open"


VERDICT = verdict()
spark_s = "?" if closed7 is None else f"{spark(closed7)} {sum(closed7)}"
name = os.path.basename(ROOT)

if COMPACT:
    print(f"{name:<18} {VERDICT}  ·  closed 7d {spark_s}")
    if failed: print("  ? " + " · ".join(failed))
    sys.exit(0)

# ── the remaining reads (full board only) ─────────────────────────────────
def lines_of(nm, cmd):
    o, k = read(nm, cmd)
    return o.strip().splitlines(), k


waves = None
lines, ok = lines_of("waves", "git branch -r")
if ok:
    waves = len([l for l in lines if l.strip()])
    err = slurp(f"{T}/waves.err").strip()
    if err: failed.append(err.splitlines()[-1])

prs = None
o, ok = read("prs", "gh pr list")
if ok:
    try: prs = json.loads(o or "[]")
    except ValueError as e: failed.append(f"gh pr list: {e}")

ci, _ = lines_of("ci", "Scan E (gh run list)")
ci_line = next((l for l in ci if l.startswith("ci-gates:")), None)
if ci_line is None: ci_s = "CI gates: ?"
elif re.match(r"ci-gates:\s*0 scheduled", ci_line): ci_s = "CI gates: none scheduled"
else: ci_s = "CI gates: " + ci_line.split(":", 1)[1].strip()

dk, _ = lines_of("docket", "Scan A docket-health")
docket_line = next((l for l in dk if l.startswith("docket-health:")), "")


def docket(key):
    """A docket-health count — `2 reason-less` or `plan-gap: 0` — or `?`."""
    m = re.search(rf"(\d+) {key}|{key}:\s*(\d+)", docket_line)
    return (m.group(1) or m.group(2)) if m else "?"


tr, ok = lines_of("truth", "board-truth.sh")
m = re.search(r"board-truth:\s*(\d+)", tr[0]) if ok and tr else None
truth = m.group(1) if m else "?"

# ── render: one block per section, every line inside W so a phone never wraps ──
IND = "   "


def pack(parts, width=W - len(IND)):
    """Join parts with ` · `, starting a new line whenever the next part would overflow."""
    lines = []
    for p in parts:
        if lines and len(lines[-1]) + 3 + len(p) <= width: lines[-1] += " · " + p
        else: lines.append(clip(p, width))
    return lines


def block(head, *rows):
    out.append(head)
    out.extend(IND + r for r in rows if r)
    out.append("")


def kv(key, val, kw=11):
    """A key/value row, the value column aligned; an overlong value continues under it."""
    vs = pack(val.split(" · "), W - len(IND) - kw)
    return [f"{key:<{kw}}{vs[0]}"] + [" " * kw + v for v in vs[1:]]


out = [clip(f"{name} · {NOW.astimezone():%m-%d %H:%M}", W), ""]

# VERDICT — the state word alone, its reasons stacked beneath
vp = VERDICT.split(" · ")
block(clip(vp[0], W), *pack(vp[1:]))

# FLOW — throughput and the health probes
flow = kv("closed 7d", spark_s) + kv("CI gates", ci_s.split(":", 1)[1].strip())
tg, ok = lines_of("triage", "triage-gate.sh --status")  # empty = the repo declares no gate
if tg: flow += kv("triage", tg[0].split(":", 1)[-1].strip())
elif not ok: flow += kv("triage", "?")
try:  # tidy shadow streak: trailing `match: true` runs — 7 means tidy-scan may apply for real
    with open(os.path.join(ROOT, ".claude/state/tidy-runs.jsonl")) as fh:
        runs = [json.loads(l) for l in fh if l.strip()]
    streak = next((i for i, r in enumerate(reversed(runs)) if r.get("match") is not True), len(runs))
    flow += kv("tidy", "ready to apply" if streak >= 7 else f"{streak}/7 agree")
except FileNotFoundError: pass
except (OSError, ValueError): flow += kv("tidy", "?")
if waves: flow += kv("waves", f"{waves} branch" + ("" if waves == 1 else "es"))
elif waves is None: flow += kv("waves", "?")
if prs is None: flow += kv("PRs", "?")
elif prs:
    red = sum(1 for p in prs if pr_ci(p).startswith("CI ✗"))
    flow += kv("PRs", f"{len(prs)} open" + (f" · {red} red" if red else ""))
# CHECKS — always printed: a zero is the probe reporting it ran and found nothing
checks = [("board-truth", truth)] + [(k, docket(k)) for k in ("reason-less", "gate-incomplete", "plan-gap")]
bad = [f"{k} {v}" for k, v in checks if v != "0"]
flow += kv("checks", "⚠ " + " · ".join(bad) if bad else "✓ all clear")
block("📈 FLOW", *flow)

# YOU — the gates as counts; which one to take first is NEXT's job
if beads is None:
    block("🧑 YOU · ?")
else:
    kinds = [plural(sum(1 for g in gates if gate_kind(g) == k), k) for k in ("decision", "action")]
    held_up = None if recs is None else sum(1 for r in recs.values() if is_open(r)
                                            and set(blockers(r["id"]) or []) & gate_ids)
    oldest_g = min((b["created_at"] for b in gates), default=None)
    no_memo = sum(1 for b in gates if not re.search(
        r"(evidence|consequence|recommendation):", b.get("description") or "", re.I))
    foot = [f"{no_memo} without memo" if no_memo else ""] + [
        f"{docket(k)} {label}" for k, label in (("reason-less", "reason-less"), ("gate-incomplete", "incomplete"))
        if docket(k) not in ("0", "?")]
    block(f"🧑 YOU · {plural(n_gates, 'gate')}", *([] if not gates else pack(kinds) + pack(
        [f"blocking {'?' if held_up is None else held_up}", f"oldest {age(oldest_g)}"]) + pack([f for f in foot if f])))

# BEADS — one count per stage, numbers in one column, a warning beside the count it explains
if beads is None:
    block("🧿 BEADS · ?")
else:
    stale = sum(1 for b in loop["in_progress"]
                if (mins(rec(b["id"]).get("updated_at") or b.get("updated_at")) or 0) > STALE_H * 60)
    unheld = sum(1 for b in loop["in_progress"] if live_names is not None and holder(b) not in live_names)
    on_you = None if recs is None else sum(1 for b in loop["blocked"] if set(blockers(b["id"]) or []) & gate_ids)
    orphans = "?"
    if recs is not None:
        epic_ids = {i for i, r in recs.items() if r.get("issue_type") == "epic"}
        orphans = sum(1 for b in live if not any(
            d.get("type") == "parent-child" and d.get("depends_on_id") in epic_ids
            for d in rec(b["id"]).get("dependencies") or []))
    stage = lambda k, n, note="": f"{k:<12}{n:>3}" + (f"  {note}" if note else "")
    rows_ = [stage("unrefined", n_unref), stage("ready", n_ready),
             stage("in progress", n_ip, " · ".join(x for x in (f"⚠ {stale} stale" if stale else "",
                                                             f"{unheld} unheld" if unheld else "") if x)),
             stage("blocked", n_blocked, "? on you" if on_you is None else f"{on_you} on you" if on_you else ""),
             stage("no epic", orphans)]
    if loop["deferred"]: rows_.append(stage("deferred", len(loop["deferred"])))
    if loop["other"]: rows_.append(stage("other", len(loop["other"])))
    if not n_ready and n_unref: rows_.append("▲ nothing refined, so nothing ready")
    elif not n_ready and not n_ip and n_blocked: rows_.append("▲ every open bead waits on another")
    block(f"🧿 BEADS · {len(live)} open", *rows_)

# EPICS — one aggregate bar
if epics:
    if recs is None: block(f"🗂  EPICS · {len(epics)} open", "?")
    else:
        prog = [epic_progress(e["id"]) for e in epics]
        done, total = sum(d for d, _ in prog), sum(t for _, t in prog)
        fill = round(10 * done / total) if total else 0
        near = sum(1 for d, t in prog if t and 0.7 <= d / t < 1)
        whole = sum(1 for d, t in prog if t and d == t)
        block(f"🗂  EPICS · {len(epics)} open", f"{done}/{total} closed  {'▓' * fill}{'░' * (10 - fill)}",
              *pack([x for x in (f"{near} near done" if near else "",
                                 f"{whole} ready to close" if whole else "") if x]))

# PLANS — stage counts and age
if not plans:
    block("📋 PLANS · none")
else:
    counts = [f"{c} {s}" for s in STAGES if (c := sum(1 for _, st, _ in plans if st == s))]
    other = sum(1 for _, st, _ in plans if st not in STAGES)
    if other: counts.append(f"{other} other")
    o_age = age(dt.datetime.fromtimestamp(min(p[2] for p in plans), dt.timezone.utc).isoformat())
    one = len(counts) == 1
    block(f"📋 PLANS · {counts[0] if one else f'{len(plans)} live'}", *([] if one else pack(counts)),
          f"oldest {o_age}",
          f"{docket('plan-gap')} approved, no beads" if docket("plan-gap") not in ("0", "?") else "")

# AGENTS — counts only
if agents is None:
    block("🤖 AGENTS · ?", f"mail {mail or '?'}")
else:
    lv = [a for a in agents if a[0] in live_names]
    working = sum(1 for a in lv if any(holder(b) == a[0] for b in loop["in_progress"]))
    block(f"🤖 AGENTS · {len(lv)} live", *pack(([f"{working} working"] if lv else [])
                                            + [f"{len(agents) - len(lv)} idle >1h", f"mail {mail or '?'}"]))

# FLAGS — reads that could not answer
if not docket_line: failed.insert(0, "docket-health ?")
if failed: block("⚠ FLAGS", *(clip(f"? {x}", W - len(IND)) for x in failed))


# NEXT — the three most impactful moves, ranked; pointers, never prompts
def moves():
    """(score, subject, detail, route). A gate that holds up work outranks the jam; the jam
    outranks idle gates, unheld WIP, a red PR and approved plans."""
    if beads is None or ready_ids is None: return [(0, "fix the failed reads", "see FLAGS", "")]
    m = []
    if VERDICT.startswith("🥵"): m.append((100, plural(n_ready, "ready bead"), "no agent taking them", "/ac-implement"))
    idle_gates = []
    for g in gates:
        k = blocks_count(g["id"]) or 0
        if k: m.append((50 + 10 * k, g["id"], f"{gate_kind(g)} · unblocks {plural(k, 'bead')}", "/ac-human"))
        else: idle_gates.append(g["id"])
    if n_unref and not n_ready: m.append((45, f"refine {plural(n_unref, 'bead')}", "nothing is ready without them", "/ac-polish"))
    if idle_gates:
        more = "more " if len(idle_gates) < n_gates else ""
        m.append((35, f"{len(idle_gates)} {more}gate{'s' if len(idle_gates) > 1 else ''}",
                  ", ".join(idle_gates[:3]) + (" …" if len(idle_gates) > 3 else ""), "/ac-human"))
    unheld_ids = [b["id"] for b in loop["in_progress"] if live_names is not None and holder(b) not in live_names]
    if unheld_ids: m.append((30, f"reclaim {plural(len(unheld_ids), 'unheld bead')}", ", ".join(unheld_ids[:3]), "/ac-tidy"))
    red = [p for p in prs or [] if pr_ci(p).startswith("CI ✗")]
    if red: m.append((25, f"PR #{red[0]['number']} is red", pr_ci(red[0])[5:], f"gh pr checks {red[0]['number']}"))
    ok_plans = [p for p in plans if p[1] in ("approved", "bead-ready")]
    if ok_plans: m.append((20, f"beadify {plural(len(ok_plans), 'approved plan')}", "", "/ac-beadify"))
    if not m:
        m.append((0, "nothing open", "plan the next wave", "/ac-align") if VERDICT.startswith("⏸")
                 else (0, "nothing needs you", "the loop is running", ""))
    return sorted(m, key=lambda x: -x[0])[:3]


out.append("🎯 NEXT")
for i, (_, subject, detail, route) in enumerate(moves(), 1):
    if i > 1: out.append("")
    out.append(clip(f"{i}. {subject}", W))
    out.extend(IND + d for d in pack(detail.split(", ") if detail else []) if d)
    if route: out.append(IND + clip(f"→ {route}", W - len(IND)))
print("\n".join(out))
