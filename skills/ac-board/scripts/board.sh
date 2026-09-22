#!/usr/bin/env bash
# board.sh — the whole ac-board render in one call (read-only).
#
# Runs every board read concurrently, then renders the board deterministically: counts come
# from code, never from a model bucketing raw JSON.
#
# Scan E (scheduled-CI health) and docket-health EXECUTE the fenced blocks in
# ac-pipeline/references/board-scan.md — the text ci-gate-health.test.sh proves. Never copy
# a scan in here.
#
# Usage:  board.sh [--compact]     (from inside the project; --compact = header lines only,
#                                   the org-wide one-block-per-repo view)
# Env:    AC_BOARD_FETCH_TIMEOUT (default 5s) bounds `git fetch`; past it, waves count the
#         refs of the last fetch and the flags line says so.
# Exit:   0 rendered (a failed read renders `?` and is named in the flags line);
#         2 not inside a git repo.

COMPACT=0; [ "${1:-}" = --compact ] && COMPACT=1

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "board: not a git repo"; exit 2; }
export PROJECT_ROOT
SELF=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
SKILLS=$(cd "$SELF/../.." && pwd)
DOC="$SKILLS/ac-pipeline/references/board-scan.md"
BR_CALL="$SKILLS/_tools/br-call.sh"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
cd "$PROJECT_ROOT" || exit 2

block() {  # block <heading-regex> — the first ```bash fence under that heading in board-scan.md
  local src
  src=$(awk -v h="$1" '$0 ~ h {s=1} s&&/^```bash$/{f=1;next} f&&/^```$/{exit} f' "$DOC")
  [ -n "$src" ] && printf '%s' "$src" || printf 'echo "board-scan.md: no bash fence under %s" >&2; exit 2' "$1"
}

job() {  # job <name> <seconds> <bash-source> — run in the background; .out/.err/.rc land in $T
  local name=$1 secs=$2 src=$3
  ( timeout "$secs" bash -c ". '$BR_CALL'; $src" >"$T/$name.out" 2>"$T/$name.err"
    echo $? >"$T/$name.rc" ) &
}

job beads  20 'br_call list --limit 0 --json'
job ready  20 'br_call ready --limit 0 --json'
if [ "$COMPACT" = 0 ]; then
  job docket 20 "$(block '^### Docket health')"
  job ci     60 "ARTIFACTS_DIR='$T/ci'; $(block '^## Scan E')"
  job truth  30 "'$SKILLS/ac-pipeline/scripts/board-truth.sh'"
  job waves  "$(( ${AC_BOARD_FETCH_TIMEOUT:-5} + 5 ))" \
    "timeout ${AC_BOARD_FETCH_TIMEOUT:-5} git fetch --prune --quiet || echo 'git fetch failed — waves as of last fetch' >&2
     git branch -r --list '*wave/*'"
  job prs    15 'gh pr list --state open --json number --jq length'
  job roster 15 "python3 '$SELF/agent-roster.py'"
fi
wait

python3 - "$T" "$PROJECT_ROOT" "$COMPACT" <<'PY'
import datetime as dt, json, os, re, sys

T, ROOT, COMPACT = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
NOW = dt.datetime.now(dt.timezone.utc)
failed = []  # reads that could not answer — each renders `?` and is named in the flags line

def read(name, cmd):
    """(stdout, ok) for a background read; a failure is recorded, never read as empty."""
    try:
        rc = int(open(f"{T}/{name}.rc").read().strip())
        out = open(f"{T}/{name}.out").read()
    except (OSError, ValueError):
        failed.append(f"{cmd}: did not run"); return "", False
    if rc != 0:
        err = open(f"{T}/{name}.err").read().strip().splitlines()
        why = "timed out" if rc == 124 else (err[0] if err else f"exit {rc}")
        failed.append(f"{cmd}: {why}"); return out, False
    return out, True

def ts(s):
    if not s: return None
    s = re.sub(r"(\.\d{6})\d+", r"\1", str(s).strip().replace(" ", "T")).replace("Z", "+00:00")
    try: t = dt.datetime.fromisoformat(s)
    except ValueError: return None
    return t if t.tzinfo else t.replace(tzinfo=dt.timezone.utc)

def age(s):
    t = ts(s)
    if not t: return "?"
    m = int((NOW - t).total_seconds() // 60)
    return f"{m}m" if m < 60 else f"{m // 60}h" if m < 48 * 60 else f"{m // 1440}d"

def cap(rows, fmt, n=10):
    lines = [fmt(r) for r in rows[:n]]
    if len(rows) > n: lines.append(f"  … +{len(rows) - n} more")
    return lines

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

GATE_LABELS = {"human-gate", "pipeline-proposal", "dream-proposal"}
labels = lambda b: set(b.get("labels") or [])
def deferred(b):
    u = ts(b.get("defer_until"))
    return b["status"] == "deferred" or bool(u and u > NOW)

decisions, actions, loop = [], [], {k: [] for k in
    ("in_progress", "blocked", "refined", "unrefined", "deferred", "other")}
epics = 0
if beads is not None:
    for b in beads:
        if labels(b) & GATE_LABELS:
            if deferred(b) or b["status"] not in ("open", "blocked", "in_progress"): continue
            t, title = b.get("issue_type"), b.get("title", "")
            kind = ("action" if t == "task" else "decision") if t in ("task", "decision") else \
                   ("action" if title.startswith("ACTION:") else "decision")
            (actions if kind == "action" else decisions).append(b)
        elif b.get("issue_type") == "epic":
            epics += 1
        elif deferred(b):
            loop["deferred"].append(b)
        elif b["status"] == "in_progress":
            loop["in_progress"].append(b)
        elif b["status"] in ("open", "blocked") and ready_ids is not None and b["id"] not in ready_ids:
            loop["blocked"].append(b)
        elif b["status"] not in ("open", "blocked"):
            loop["other"].append(b)
        else:
            loop["refined" if "refined" in labels(b) else "unrefined"].append(b)

n = lambda xs: "?" if beads is None else str(len(xs))
loop_ready = "?" if ready_ids is None else n(loop["refined"])

# ── plans (Scan B) ────────────────────────────────────────────────────────
STAGES = ("draft", "refined", "approved", "bead-ready", "beadified")
plans = []
pdir = os.path.join(ROOT, "_plans")
jsonl = None
try: jsonl = open(os.path.join(ROOT, ".beads/issues.jsonl")).read()
except OSError: pass
if os.path.isdir(pdir):
    for f in sorted(os.listdir(pdir)):
        p = os.path.join(pdir, f)
        if not f.endswith(".md") or f == "README.md" or not os.path.isfile(p): continue
        text = open(p, errors="replace").read()
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
plans.sort(key=lambda x: -x[2])
pcount = {s: sum(1 for _, st, _ in plans if st == s) for s in STAGES}
pother = sum(1 for _, st, _ in plans if st not in STAGES)

# ── the other reads ───────────────────────────────────────────────────────
def lines_of(name, cmd):
    out, ok = read(name, cmd)
    return out.strip().splitlines(), ok

waves = prs = "?"
if not COMPACT:
    lines, ok = lines_of("waves", "git branch -r")
    if ok:
        waves = str(len([l for l in lines if l.strip()]))
        err = open(f"{T}/waves.err").read().strip()
        if err: failed.append(err.splitlines()[-1])
    lines, ok = lines_of("prs", "gh pr list")
    if ok and lines and lines[0].isdigit(): prs = lines[0]
    ci, _ = lines_of("ci", "Scan E (gh run list)")
    ci_line = next((l for l in ci if l.startswith("ci-gates:")), None) or "ci-gates: ? · ci_health: unknown"
    dk, _ = lines_of("docket", "Scan A docket-health")
    docket_line = next((l for l in dk if l.startswith("docket-health:")), None) or "docket-health: ?"
    m = re.search(r"(\d+) reason-less", docket_line)
    reasonless = m.group(1) if m else "?"
    tr, ok = lines_of("truth", "board-truth.sh")
    m = re.search(r"board-truth:\s*(\d+)", tr[0]) if ok and tr else None
    truth = m.group(1) if m else "?"
    ros, ros_ok = lines_of("roster", "agent-roster.py")

# ── render ────────────────────────────────────────────────────────────────
out = [f"## Board — {os.path.basename(ROOT)} · {NOW.astimezone():%Y-%m-%d %H:%M}", ""]
out.append(f"🤖 loop: {loop_ready} ready · {pcount['bead-ready']} bead-ready plans · "
           f"{n(loop['in_progress'])} in-progress" + ("" if COMPACT else f" · {waves}w · {prs}PR"))
out.append(f"🧑 you: {n(decisions)} decisions · {n(actions)} actions")
if COMPACT:
    if failed: out.append("⚠ ? " + " · ".join(failed))
    print("\n".join(out)); sys.exit(0)
out += [ci_line, docket_line, ""]

gate = lambda b: f"  • {b['id']} {age(b['created_at'])} {b.get('title', '')}"
out.append(f"### 🧑 Human — {n(decisions + actions)} gates")
if beads is None: out.append("?")
elif not decisions and not actions: out.append("—")
else:
    out.append(f"decisions ({len(decisions)})"); out += cap(decisions, gate)
    out.append(f"actions ({len(actions)})"); out += cap(actions, gate)
out.append("")

out.append(f"### 📋 Plans ({len(plans)} live)")
if not plans: out.append("—")
else:
    out.append(" · ".join(f"{s} {pcount[s]}" for s in STAGES) + f" · other {pother}")
    out += cap(plans, lambda p: f"  • {p[0]} [{p[1]} · touched "
                                f"{dt.datetime.fromtimestamp(p[2]):%Y-%m-%d}]")
out.append("")

live = [(k, b) for k in ("in_progress", "blocked", "refined", "unrefined", "other") for b in loop[k]]
out.append(f"### 🧿 Beads ({n(live)} open, loop-side)")
if beads is None: out.append("?")
elif not live: out.append("—")
else:
    out.append(f"in-progress {len(loop['in_progress'])} · unrefined {len(loop['unrefined'])} · "
               f"refined {len(loop['refined'])} · blocked {len(loop['blocked'])}"
               + (f" · other {len(loop['other'])}" if loop["other"] else "")
               + f" · deferred {len(loop['deferred'])} · epics {epics}")
    out += cap(live, lambda kb: f"  • {kb[1]['id']} [{kb[1]['status'] if kb[0] == 'other' else kb[0]}"
                                f" · {age(kb[1]['created_at'])}] {kb[1].get('title', '')}")
out.append("")

if ros_ok and ros:
    mail = ros[0].split("\t")[1] if ros[0].startswith("#mail") else "?"
    agents = [l.split("\t") for l in ros[1:] if l.strip()]
    out.append(f"### 🤖 Agents ({len(agents)} active, last 24h · mail {mail})")
    out += cap(agents, lambda a: f"  • {a[0]} [{a[1]} · {a[2]}] {age(a[3]) if len(a) > 3 else '?'}") or ["—"]
else:
    out.append("### 🤖 Agents (? active · mail ?)")
out.append("")

# Flags: gates without a memo, and parentage-gap orphans (open non-epic, non-gate bead with
# no parent-child edge to an epic — edges come only from the jsonl; br list carries none).
memo = "?" if beads is None else str(sum(
    1 for b in decisions + actions
    if not re.search(r"(evidence|consequence|recommendation):", b.get("description") or "", re.I)))
orphans = "?"
if beads is not None and jsonl is not None:
    recs = [json.loads(l) for l in jsonl.splitlines() if l.strip()]
    epic_ids = {r["id"] for r in recs if r.get("issue_type") == "epic"}
    parented = {d["issue_id"] for r in recs for d in (r.get("dependencies") or [])
                if d.get("type") == "parent-child" and d.get("depends_on_id") in epic_ids}
    orphans = str(sum(1 for _, b in live if b["id"] not in parented))
out.append("### ⚠ Flags")
out.append(f"board-truth {truth} cited-but-open · {memo} gates w/o memo · "
           f"{reasonless} reason-less · {orphans} orphans")
if failed: out.append("? " + " · ".join(failed))
print("\n".join(out))
PY
