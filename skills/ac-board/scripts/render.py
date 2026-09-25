#!/usr/bin/env python3
"""render.py — the ac-board inline render (read-only): model.py computes every count and
derivation; this formats them into the 40-column stacked board. Pure presentation only —
never re-derives a count from raw JSON.

Usage:  render.py <reads-dir> <project-root> <compact 0|1>
Env:    AC_BOARD_NOW (ISO timestamp) pins "now" — the test seam; unset = the real clock
        (read by model.build(), not here).
"""
import datetime as dt, math, os, re, sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "../../ac-pipeline/scripts"))
from pull_order import PLAN_ORDER  # noqa: E402
import model  # noqa: E402

T, ROOT, COMPACT = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
W = 40              # every line fits a phone screen unwrapped
IND = "   "
SUB = "  "          # a stage's detail, under its label (block adds IND)

M = model.build(T, ROOT, COMPACT)
NOW = dt.datetime.fromisoformat(M["now"])


def ts(s):
    if not s: return None
    s = re.sub(r"(\.\d{6})\d+", r"\1", str(s).strip().replace(" ", "T")).replace("Z", "+00:00")
    try: t = dt.datetime.fromisoformat(s)
    except ValueError: return None
    return t if t.tzinfo else t.replace(tzinfo=dt.timezone.utc)


def age(s):
    t = ts(s)
    if t is None: return "?"
    m = int((NOW - t).total_seconds() / 60)
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


def stage(label, n, total, notes=()):
    """`label  n ▓▓░░ note` — the share bar is n against its own section's total. Notes
    that would overflow drop beneath the label."""
    head = f"{label:<12}{n:>3} {bar(n, total)}"
    notes = [x for x in notes if x]
    tail = " · ".join(notes)
    if tail and len(IND) + len(head) + 1 + len(tail) <= W: return [head + " " + tail]
    return [head] + [SUB + x for x in pack(notes, W - len(IND) - len(SUB))]


STATE_LINE, REASONS = M["verdict"]["line"], M["verdict"]["reasons"]
name = M["name"]

if COMPACT:
    line = f"{name:<17}{STATE_LINE.split(' — ')[0]}"
    for r in REASONS:  # whole reasons only, while they fit
        if len(line) + 3 + len(r) > W: break
        line += " · " + r
    print(line)
    if M["failed"]: print("  ? " + " · ".join(M["failed"]))
    sys.exit(0)

out = [clip(f"{name} · {NOW.astimezone():%m-%d %H:%M}", W), clip(STATE_LINE, W), ""]

# BEADS — in progress → ready → human-gate → unrefined → blocked; bars share all open beads
B = M["beads"]
if B is None:
    block("🧿 BEADS · ?")
else:
    total = B["total"]
    rows_ = stage("in progress", B["n_in_progress"], total,
                  (f"⚠ {B['stale']} stale" if B["stale"] else "",
                   f"{B['unclaimed']} unclaimed" if B["unclaimed"] else ""))
    rows_ += stage("ready", B["n_ready"], total)
    rows_ += stage("human-gate", B["n_gates"], total,
                   ("block ?" if B["held_up"] is None else f"block {B['held_up']}" if B["held_up"] else "",))
    if B["gates"]:
        kinds = [plural(sum(1 for g in B["gates"] if g["kind"] == k), k) for k in ("decision", "action")]
        oldest = age(min(g["created_at"] for g in B["gates"]))
        rows_ += [SUB + x for x in pack(kinds + [f"oldest {oldest}"], W - len(IND) - len(SUB))]
    rows_ += stage("unrefined", B["n_unrefined"], total)
    rows_ += stage("blocked", B["n_blocked"], total)
    if B["n_blocked"]:
        if B["blocked_by"] is None: rows_.append(SUB + "by ?")
        else: rows_ += [SUB + x for x in pack([f"by {k} {v}" for k, v in B["blocked_by"].items() if v],
                                              W - len(IND) - len(SUB))]
    if B["n_deferred"]: rows_ += stage("deferred", B["n_deferred"], total)
    if B["n_other"]: rows_ += stage("other", B["n_other"], total)
    if not B["n_ready"] and B["n_unrefined"]: rows_.append("▲ nothing refined, so nothing ready")
    elif not B["n_ready"] and not B["n_in_progress"] and B["n_blocked"]: rows_.append("▲ every open bead waits on another")
    block(f"🧿 BEADS · {total} open", *rows_)

# PLANS — most mature first (PLAN_ORDER), then beadified and the pool; bars share all live plans
PLAN_STAGES = PLAN_ORDER + ("beadified",)
known = set(PLAN_STAGES)
plans, pool = M["plans"], M["pool"]
ptotal = len(plans) + pool
if not ptotal:
    block("📋 PLANS · none")
else:
    rows_ = []
    for label in PLAN_STAGES:
        n = sum(1 for p in plans if p["stage"] == label)
        if n or label in ("bead-ready", "approved", "draft"):
            rows_ += stage(label, n, ptotal, ("needs you",) if n and label == "refined" else ())
    rows_ += stage("pool", pool, ptotal)
    other = sorted({p["stage"] for p in plans if p["stage"] not in known})
    if other: rows_ += stage("other", sum(1 for p in plans if p["stage"] not in known),
                             ptotal, (", ".join(other),))
    if plans:
        o_age = age(dt.datetime.fromtimestamp(min(p["mtime"] for p in plans), dt.timezone.utc).isoformat())
        rows_.append(SUB + f"oldest plan {o_age}")
    block(f"📋 PLANS · {ptotal} live", *rows_)

# FLOW — throughput: what closed, how far the epics are, what is in review
spark_s = "?" if M["closed7"] is None else f"{spark(M['closed7'])} {sum(M['closed7'])}"
flow = kv("closed 7d", spark_s)
items = M["epics"]["items"]
if items:
    if not M["epics"]["ok"]: flow += kv("epics", "?")
    else:
        done, etotal = sum(e["done"] for e in items), sum(e["total"] for e in items)
        near = sum(1 for e in items if e["total"] and 0.7 <= e["done"] / e["total"] < 1)
        whole = sum(1 for e in items if e["total"] and e["done"] == e["total"])
        flow += kv("epics", f"{done}/{etotal} {bar(done, etotal)}")
        flow += [" " * 11 + x for x in pack([x for x in (
            plural(len(items), "open epic"), f"{near} near done" if near else "",
            f"{whole} ready to close" if whole else "") if x], W - len(IND) - 11)]
if M["waves"]: flow += kv("waves", f"{M['waves']} branch" + ("" if M["waves"] == 1 else "es"))
elif M["waves"] is None: flow += kv("waves", "?")
if M["prs"] is None: flow += kv("PRs", "?")
else:
    red = sum(1 for p in M["prs"] if p["ci"].startswith("CI ✗"))
    flow += kv("PRs", f"{len(M['prs'])} open" + (f" · {red} red" if red else ""))
block("📈 FLOW", *flow)

# MACHINE — who is running it and whether its probes are healthy
mach = []
if M["agents"] is None: mach += kv("agents", "?")
else:
    lv = [a for a in M["agents"] if a["live"]]
    working = sum(1 for a in lv if a["holds"])
    mach += kv("agents", f"{len(lv)} live" + (f" · {working} working" if lv else ""))
if M["mail"] != "up": mach += kv("mail", M["mail"] or "?")
if M["split"]: mach += kv("split", f"⚠ {M['split']} agents on another mailbox key")
mach += kv("CI gates", M["ci"] or "?")
if M["triage"]["value"]: mach += kv("triage", M["triage"]["value"])
elif not M["triage"]["ok"]: mach += kv("triage", "?")
t = M["tidy"]
if t["status"] == "ok": mach += kv("tidy", "ready to apply" if t["streak"] >= 7 else f"{t['streak']}/7 agree")
elif t["status"] == "error": mach += kv("tidy", "?")
# checks — always printed: a zero is the probe reporting it ran and found nothing
no_memo = B["no_memo"] if B else None
orphans = B["orphans"] if B else None
cs = lambda v: "?" if v is None else str(v)
checks = [("board-truth", M["truth"]), ("reason-less", M["docket"]["reason_less"]),
          ("gate-incomplete", M["docket"]["gate_incomplete"]), ("plan-gap", M["docket"]["plan_gap"]),
          ("no epic", orphans), ("no memo", no_memo)]
bad = [f"{k} {cs(v)}" for k, v in checks if cs(v) != "0"]
mach += kv("checks", "⚠ " + " · ".join(bad) if bad else "✓ all clear")
block("🖥  MACHINE", *mach)

# FLAGS — reads that could not answer
if M["failed"]: block("⚠ FLAGS", *(clip(f"? {x}", W - len(IND)) for x in M["failed"]))

# NEXT — the three moves closest to implement (pull_order.LADDER); pointers, never prompts
out.append("🎯 NEXT")
for i, mv in enumerate(M["moves"][:3], 1):
    if i > 1: out.append("")
    out.append(clip(f"{i}. {mv['subject']}", W))
    out.extend(IND + d for d in pack(mv["detail"].split(", ") if mv["detail"] else []) if d)
    if mv["route"]: out.append(IND + clip(f"→ {mv['route']}", W - len(IND)))

print("\n".join(out))
