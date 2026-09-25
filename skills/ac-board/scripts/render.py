#!/usr/bin/env python3
"""render.py — the ac-board render (read-only), fed by the reads board.sh ran.

Usage:  render.py <reads-dir> <project-root> <compact 0|1>
        Each read left <name>.out / .err / .rc in <reads-dir>; the beads jsonl is read in
        place for edges, holders and closure dates (br list carries none of those).
Env:    AC_BOARD_NOW (ISO timestamp) pins "now" — the test seam; unset = the real clock.
        AC_BOARD_STATE (a file) — the watch dashboard's memory: counts persist there, and a
        count that moved in the last DELTA_MIN minutes shows its change (`+2`).
        AC_BOARD_COLOR=1 colours the verdict, warnings, unknowns and changes.

Counts come from code, never from a model bucketing raw JSON. A read that cannot answer
renders `?` and is named in the flags block; nothing is guessed.
"""
import datetime as dt, json, math, os, re, sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "../../ac-pipeline/scripts"))
from pull_order import PLAN_ORDER, PLAN_RUNG, blocks_counts, front, plan_stage, rank  # noqa: E402

T, ROOT, COMPACT = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
NOW = (dt.datetime.fromisoformat(os.environ["AC_BOARD_NOW"]) if os.environ.get("AC_BOARD_NOW")
       else dt.datetime.now(dt.timezone.utc))
W = 40                 # every line fits a phone screen unwrapped
LIVE_MIN = 60          # an agent active within this many minutes is live
STALE_H = 24           # an in-progress bead untouched this long is stale
DELTA_MIN = 15         # a changed count shows its change this long on the watch dashboard
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


def bar(n, total, w=10):
    """n's share of its own section — plans never shrink beside beads. Any n > 0 shows."""
    f = max(1, round(w * n / total)) if n and total else 0
    return "▓" * f + "░" * (w - f)


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


BLOCKS = None if recs is None else blocks_counts(recs)  # open beads waiting on each id


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

# ── plans (Scan B) + the backlog pool ─────────────────────────────────────
plans = []
pdir = os.path.join(ROOT, "_plans")
if os.path.isdir(pdir):
    for f in sorted(os.listdir(pdir)):
        p = os.path.join(pdir, f)
        if not f.endswith(".md") or f == "README.md" or not os.path.isfile(p): continue
        text = slurp(p, errors="replace")
        st = plan_stage(front(text))
        if st is None:  # the Scan B fallback ladder
            st = ("refined" if "## Refinement Log" in text else
                  "approved" if "Status: Approved" in text else
                  "beadified" if jsonl and f in jsonl else "draft")
        plans.append((f[:-3], st, os.path.getmtime(p)))
pool_dir = os.path.join(ROOT, "_backlog/pool")
pool = len([f for f in os.listdir(pool_dir) if f.endswith(".md") and f != "README.md"]
           ) if os.path.isdir(pool_dir) else 0

# ── agents: who is live, and which bead each holds ────────────────────────
agents = mail = None
out, ok = read("roster", "agent-roster.py")
ros = out.strip().splitlines()
if ros and ros[0].startswith("#mail"): mail = ros[0].split("\t")[1]
split = next((l.split("\t")[1] for l in ros if l.startswith("#split")), None)
if ok: agents = [l.split("\t") for l in ros if l.strip() and not l.startswith("#")]
live_names = None if agents is None else {
    a[0] for a in agents if len(a) > 3 and (mins(a[3]) or LIVE_MIN) < LIVE_MIN}
holder = lambda b: b.get("assignee") or rec(b["id"]).get("assignee")
held = None if live_names is None else [b for b in loop["in_progress"] if holder(b) in live_names]

# ── verdict: one of four states, derived — never asserted ─────────────────
n_ready, n_unref, n_gates = len(loop["ready"]), len(loop["unrefined"]), len(gates)
n_blocked, n_ip = len(loop["blocked"]), len(loop["in_progress"])


def verdict():
    """(state — its plain meaning, [the counts behind it]). The board prints the state line;
    the compact line adds the counts, since it has no sections to carry them."""
    if beads is None or ready_ids is None: return "? unknown — the bead reads failed", []
    you = [f"{n_gates} on you"] if n_gates else []
    if (n_ready or n_ip) and live_names is None:
        return "? unknown — agent roster unreadable", [f"{n_ready} ready", f"{n_ip} in progress"]
    if held:
        return "✅ RUNNING — agents are building", [f"{len(held)} working", f"{n_ready} ready"] + you
    if n_ready:
        return "🥵 IDLE — work waiting, no agent on it", [f"{n_ready} ready"] + you
    rest = ([f"{n_unref} unrefined"] if n_unref else  # the lead cause only
            [f"{n_blocked} blocked"] if n_blocked else [f"{n_ip} unclaimed"] if n_ip else [])
    if n_gates: return "⛔ STUCK — waiting on you", [plural(n_gates, "gate")] + rest
    if live: return "⛔ STUCK — nothing can move", rest
    return "⏸ EMPTY — nothing planned", []


STATE_LINE, REASONS = verdict()
spark_s = "?" if closed7 is None else f"{spark(closed7)} {sum(closed7)}"
name = os.path.basename(ROOT)

if COMPACT:
    line = f"{name:<17}{STATE_LINE.split(' — ')[0]}"
    for r in REASONS:  # whole reasons only, while they fit
        if len(line) + 3 + len(r) > W: break
        line += " · " + r
    print(line)
    if failed: print("  ? " + " · ".join(failed))
    sys.exit(0)

# ── watch memory: a count that moved lately shows its change ──────────────
STATE = os.environ.get("AC_BOARD_STATE")
prev, snap = {}, {}
if STATE:
    try: prev = json.loads(slurp(STATE))
    except (OSError, ValueError): prev = {}


def delta(key, n):
    """`+2` beside a count that moved within DELTA_MIN on the watch dashboard; '' otherwise."""
    if not STATE or not isinstance(n, int): return ""
    p = prev.get(key)
    snap[key] = p if p and p.get("n") == n else {
        "n": n, "d": n - p["n"] if p else 0, "at": NOW.isoformat()}
    d, m = snap[key]["d"], mins(snap[key]["at"])
    return f"{d:+d}" if d and m is not None and m < DELTA_MIN else ""


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
if ci_line is None: ci_s = "?"
elif re.match(r"ci-gates:\s*0 scheduled", ci_line): ci_s = "none scheduled"
else: ci_s = ci_line.split(":", 1)[1].strip()

dk, _ = lines_of("docket", "Scan A docket-health")
docket_line = next((l for l in dk if l.startswith("docket-health:")), "")


def docket(key):
    """A docket-health count — `2 reason-less` or `plan-gap: 0` — or `?`."""
    m = re.search(rf"(\d+) {key}|{key}:\s*(\d+)", docket_line)
    return (m.group(1) or m.group(2)) if m else "?"


tr, ok = lines_of("truth", "board-truth.sh")
m = re.search(r"board-truth:\s*(\d+)", tr[0]) if ok and tr else None
truth = m.group(1) if m else "?"

# ── render: pipeline in reverse — nearest to done first; every line inside W ──
IND = "   "
SUB = "  "         # a stage's detail, under its label (block adds IND)


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


def stage(section, label, n, total, notes=()):
    """`label  n ▓▓░░ +d note` — the share bar is n against its own section's total. Notes
    that would overflow drop beneath the label."""
    head = f"{label:<12}{n:>3} {bar(n, total)}"
    d = delta(f"{section}.{label}", n)
    if d: head += " " + d
    notes = [x for x in notes if x]
    tail = " · ".join(notes)
    if tail and len(IND) + len(head) + 1 + len(tail) <= W: return [head + " " + tail]
    return [head] + [SUB + x for x in pack(notes, W - len(IND) - len(SUB))]


def pr_ci(p):
    checks = p.get("statusCheckRollup") or []
    bad = [c.get("name") or c.get("context") or "?" for c in checks
           if (c.get("conclusion") or c.get("state") or "").upper()
           in ("FAILURE", "ERROR", "TIMED_OUT", "CANCELLED", "ACTION_REQUIRED")]
    pend = sum(1 for c in checks if (c.get("status") or "COMPLETED").upper() != "COMPLETED"
               or (c.get("state") or "").upper() == "PENDING")
    if bad:
        return f"CI ✗ {len(bad)} failing: " + ", ".join(bad[:2]) + (" …" if len(bad) > 2 else "")
    if pend: return f"CI … {pend} running"
    return "CI ✓" if checks else "no CI checks"


out = [clip(f"{name} · {NOW.astimezone():%m-%d %H:%M}", W), clip(STATE_LINE, W), ""]

# BEADS — in progress → ready → human-gate → unrefined → blocked; bars share all open beads
orphans = no_memo = "?"
if beads is None:
    block("🧿 BEADS · ?")
else:
    total = len(live) + n_gates
    stale = sum(1 for b in loop["in_progress"]
                if (mins(rec(b["id"]).get("updated_at") or b.get("updated_at")) or 0) > STALE_H * 60)
    unclaimed = sum(1 for b in loop["in_progress"] if live_names is not None and holder(b) not in live_names)
    held_up = None if recs is None else sum(1 for r in recs.values() if is_open(r)
                                            and set(blockers(r["id"]) or []) & gate_ids)
    no_memo = sum(1 for b in gates if not re.search(
        r"(evidence|consequence|recommendation):", b.get("description") or "", re.I))
    rows_ = stage("beads", "in progress", n_ip, total,
                  (f"⚠ {stale} stale" if stale else "", f"{unclaimed} unclaimed" if unclaimed else ""))
    rows_ += stage("beads", "ready", n_ready, total)
    rows_ += stage("beads", "human-gate", n_gates, total,
                   ("block ?" if held_up is None else f"block {held_up}" if held_up else "",))
    if gates:
        kinds = [plural(sum(1 for g in gates if gate_kind(g) == k), k) for k in ("decision", "action")]
        oldest = age(min(b["created_at"] for b in gates))
        rows_ += [SUB + x for x in pack(kinds + [f"oldest {oldest}"], W - len(IND) - len(SUB))]
    rows_ += stage("beads", "unrefined", n_unref, total)
    rows_ += stage("beads", "blocked", n_blocked, total)
    if loop["blocked"]:
        if recs is None: rows_.append(SUB + "by ?")
        else:
            unref_ids = {b["id"] for b in loop["unrefined"]}
            by = {"gate": 0, "unrefined": 0, "work": 0}
            for b in loop["blocked"]:
                bl = set(blockers(b["id"]) or [])
                by["gate" if bl & gate_ids else "unrefined" if bl & unref_ids else "work"] += 1
            rows_ += [SUB + x for x in pack([f"by {k} {v}" for k, v in by.items() if v], W - len(IND) - len(SUB))]
    if loop["deferred"]: rows_ += stage("beads", "deferred", len(loop["deferred"]), total)
    if loop["other"]: rows_ += stage("beads", "other", len(loop["other"]), total)
    if not n_ready and n_unref: rows_.append("▲ nothing refined, so nothing ready")
    elif not n_ready and not n_ip and n_blocked: rows_.append("▲ every open bead waits on another")
    if recs is not None:
        epic_ids = {i for i, r in recs.items() if r.get("issue_type") == "epic"}
        orphans = sum(1 for b in live if not any(
            d.get("type") == "parent-child" and d.get("depends_on_id") in epic_ids
            for d in rec(b["id"]).get("dependencies") or []))
    block(f"🧿 BEADS · {total} open", *rows_)

# PLANS — most mature first (PLAN_ORDER), then beadified and the pool; bars share all live plans
PLAN_STAGES = PLAN_ORDER + ("beadified",)
known = set(PLAN_STAGES)
ptotal = len(plans) + pool
if not ptotal:
    block("📋 PLANS · none")
else:
    rows_ = []
    for label in PLAN_STAGES:
        n = sum(1 for _, st, _ in plans if st == label)
        if n or label in ("bead-ready", "approved", "draft"):
            rows_ += stage("plans", label, n, ptotal, ("needs you",) if n and label == "refined" else ())
    rows_ += stage("plans", "pool", pool, ptotal)
    other = sorted({st for _, st, _ in plans if st not in known})
    if other: rows_ += stage("plans", "other", sum(1 for _, st, _ in plans if st not in known),
                             ptotal, (", ".join(other),))
    if plans:
        o_age = age(dt.datetime.fromtimestamp(min(p[2] for p in plans), dt.timezone.utc).isoformat())
        rows_.append(SUB + f"oldest plan {o_age}")
    block(f"📋 PLANS · {ptotal} live", *rows_)

# FLOW — throughput: what closed, how far the epics are, what is in review
flow = kv("closed 7d", spark_s)
if epics:
    if recs is None: flow += kv("epics", "?")
    else:
        prog = [epic_progress(e["id"]) for e in epics]
        done, etotal = sum(d for d, _ in prog), sum(t for _, t in prog)
        near = sum(1 for d, t in prog if t and 0.7 <= d / t < 1)
        whole = sum(1 for d, t in prog if t and d == t)
        flow += kv("epics", f"{done}/{etotal} {bar(done, etotal)}")
        flow += [" " * 11 + x for x in pack([x for x in (
            plural(len(epics), "open epic"), f"{near} near done" if near else "",
            f"{whole} ready to close" if whole else "") if x], W - len(IND) - 11)]
if waves: flow += kv("waves", f"{waves} branch" + ("" if waves == 1 else "es"))
elif waves is None: flow += kv("waves", "?")
if prs is None: flow += kv("PRs", "?")
else:
    red = sum(1 for p in prs if pr_ci(p).startswith("CI ✗"))
    flow += kv("PRs", f"{len(prs)} open" + (f" · {red} red" if red else ""))
block("📈 FLOW", *flow)

# MACHINE — who is running it and whether its probes are healthy
mach = []
if agents is None: mach += kv("agents", "?")
else:
    lv = [a for a in agents if a[0] in live_names]
    working = sum(1 for a in lv if any(holder(b) == a[0] for b in loop["in_progress"]))
    mach += kv("agents", f"{len(lv)} live" + (f" · {working} working" if lv else ""))
if mail != "up": mach += kv("mail", mail or "?")
if split: mach += kv("split", f"⚠ {split} agents on another mailbox key")
mach += kv("CI gates", ci_s)
tg, ok = lines_of("triage", "triage-gate.sh --status")  # empty = the repo declares no gate
if tg: mach += kv("triage", tg[0].split(":", 1)[-1].strip())
elif not ok: mach += kv("triage", "?")
try:  # tidy shadow streak: trailing `match: true` runs — 7 means tidy-scan may apply for real
    with open(os.path.join(ROOT, ".claude/state/tidy-runs.jsonl")) as fh:
        runs = [json.loads(l) for l in fh if l.strip()]
    streak = next((i for i, r in enumerate(reversed(runs)) if r.get("match") is not True), len(runs))
    mach += kv("tidy", "ready to apply" if streak >= 7 else f"{streak}/7 agree")
except FileNotFoundError: pass
except (OSError, ValueError): mach += kv("tidy", "?")
# checks — always printed: a zero is the probe reporting it ran and found nothing
checks = [("board-truth", truth)] + [(k, docket(k)) for k in ("reason-less", "gate-incomplete", "plan-gap")] \
         + [("no epic", str(orphans)), ("no memo", str(no_memo))]
bad = [f"{k} {v}" for k, v in checks if v != "0"]
mach += kv("checks", "⚠ " + " · ".join(bad) if bad else "✓ all clear")
block("🖥  MACHINE", *mach)

# FLAGS — reads that could not answer
if not docket_line: failed.insert(0, "docket-health ?")
if failed: block("⚠ FLAGS", *(clip(f"? {x}", W - len(IND)) for x in failed))


# NEXT — the three moves closest to implement (pull_order.LADDER); pointers, never prompts
def moves():
    """(rank, subject, detail, route), ranked by rung, then within a rung."""
    if beads is None or ready_ids is None: return [((0,), "fix the failed reads", "see FLAGS", "")]
    m = []
    red = [p for p in prs or [] if pr_ci(p).startswith("CI ✗")]
    if red: m.append(((rank("red-pr"),), f"PR #{red[0]['number']} is red", pr_ci(red[0])[5:],
                      f"gh pr checks {red[0]['number']}"))
    unclaimed_ids = [b["id"] for b in loop["in_progress"] if live_names is not None and holder(b) not in live_names]
    if unclaimed_ids: m.append(((rank("reclaim"),), f"reclaim {plural(len(unclaimed_ids), 'unclaimed bead')}",
                                ", ".join(unclaimed_ids[:3]), "/ac-tidy"))
    if STATE_LINE.startswith("🥵"): m.append(((rank("implement"),), plural(n_ready, "ready bead"),
                                              "no agent taking them", "/ac-implement"))
    idle_gates = []
    for g in gates:
        k = (BLOCKS or {}).get(g["id"], 0)
        if k: m.append(((rank("gate"), -k), g["id"], f"{gate_kind(g)} · unblocks {plural(k, 'bead')}", "/ac-human"))
        else: idle_gates.append(g["id"])
    if n_unref: m.append(((rank("refine-bead"),), f"refine {plural(n_unref, 'bead')}",
                          "" if n_ready else "nothing is ready without them", "/ac-polish bead"))
    plan_move = {"bead-ready": ("beadify", "/ac-beadify"), "refined": ("rule on", "/ac-human"),
                 "polished": ("mark ready", "plan-approve.sh ready"), "approved": ("polish", "/ac-polish plan"),
                 "draft": ("approve", "/ac-human")}
    for i, st in enumerate(PLAN_ORDER):
        names = [n for n, s, _ in plans if s == st]
        if names:
            verb, route = plan_move[st]
            m.append(((rank(PLAN_RUNG[st]), i), f"{verb} {plural(len(names), 'plan')}",
                      ", ".join(names[:2]) + (" …" if len(names) > 2 else ""), route))
    if idle_gates:
        more = "more " if len(idle_gates) < n_gates else ""
        m.append(((rank("idle-gate"),), f"{len(idle_gates)} {more}gate{'s' if len(idle_gates) > 1 else ''}",
                  ", ".join(idle_gates[:3]) + (" …" if len(idle_gates) > 3 else ""), "/ac-human"))
    if pool: m.append(((rank("pool"),), f"promote {plural(pool, 'pool idea')}", "", "/ac-align"))
    if not m:
        m.append(((0,), "nothing open", "plan the next wave", "/ac-align") if STATE_LINE.startswith("⏸")
                 else ((0,), "nothing needs you", "the loop is running", ""))
    return sorted(m, key=lambda x: x[0])[:3]


out.append("🎯 NEXT")
for i, (_, subject, detail, route) in enumerate(moves(), 1):
    if i > 1: out.append("")
    out.append(clip(f"{i}. {subject}", W))
    out.extend(IND + d for d in pack(detail.split(", ") if detail else []) if d)
    if route: out.append(IND + clip(f"→ {route}", W - len(IND)))

if STATE:
    try:
        with open(STATE, "w", encoding="utf-8") as fh: json.dump(snap, fh)
    except OSError: pass

if os.environ.get("AC_BOARD_COLOR") == "1":
    tone = {"✅": "32", "🥵": "33", "⛔": "31", "⏸": "2", "?": "31"}.get(out[1][:1], "0")
    out[1] = f"\033[1;{tone}m{out[1]}\033[0m"
    for i in range(2, len(out)):
        s = re.sub(r"(⚠[^·]*)", "\033[33m\\1\033[0m", out[i])
        s = re.sub(r"(?<![\w/#-])([+-]\d+)(?=\s|$)", "\033[36m\\1\033[0m", s)
        out[i] = re.sub(r"(?<!\S)(\?)(?!\S)", "\033[31m\\1\033[0m", s)
print("\n".join(out))
