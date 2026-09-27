#!/usr/bin/env bash
# plan-coverage.sh — every plan "Done when:" line reached a bead (plan → beads coverage).
#
# The schema already makes each child AC quote its plan "Done when:" verbatim
# (beads-standards/reference/bead-schema.md), so the quote IS the trace: each plan line must
# reappear in one of the epic's children — never the epic itself, whose own text would
# cover every line without any bead doing the work. A deliverable the cut dropped
# whole — or reworded — passes every other gate and retires with the plan; this is the
# one check that notices. Whitespace and line wraps are normalised; the words must match.
#
# ASSURANCE (ac-pipeline/references/assurance-declarations.md § The four fields):
#   PROBE:      skills/_tools/plan-coverage.test.sh — both polarities
#   SCHEDULE:   every ac-beadify compile, before plan retirement (SKILL.md step 7);
#               every plan-deliver.sh stamp (the backstop); and on every CI run via
#               scripts/run-all-proofs.sh
#   MODE:       blocking
#   ON-FAILURE: closed   (an unreadable board or a plan with no Done when is a refusal)
#
# Usage:   plan-coverage.sh <plan.md> <epic-id>
# Env:     AC2_BR_CMD — the br binary br_call reads through (default: br)
# Verdicts (one greppable line each):
#   COVERED N                  exit 0
#   COVERAGE GAP: <line>       exit 1, one per missing line, plan not retired
#   REFUSED no-done-when       exit 1  (ac-plan requires one per deliverable)
#   NOT-GATED: <why>           exit 2  (verified nothing)
set -u
PLAN="${1:-}"; EPIC="${2:-}"

# shellcheck source=br-call.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/br-call.sh" 2>/dev/null \
  || { echo "NOT-GATED: br-call.sh helper missing"; exit 2; }
[ -n "$EPIC" ] && [ -r "$PLAN" ] \
  || { echo "NOT-GATED: usage: plan-coverage.sh <plan.md> <epic-id>"; exit 2; }

_TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
[ -f "$_TOOLS_DIR/bead.py" ] \
  || { echo "NOT-GATED: bead.py missing at $_TOOLS_DIR/bead.py — the epic's children cannot be resolved"; exit 2; }

SHOW=$(br_call show "$EPIC" --json) || { echo "NOT-GATED: br show refused for $EPIC"; exit 2; }
LIST=$(br_call list --all --limit 0 --json) || { echo "NOT-GATED: br list refused"; exit 2; }

# bead.py is the one bead reader (ac-m9y4.1): the epic's own parent-child children are
# read through its `parent_child_children` (ac-m9y4.9), never a second inline edge select.
# `BEAD_MODULE_PATH` is the same test-only override bead-capture-guard.py's own
# `_load_bead_module()` uses: a nonexistent path drives the crash-path fixture without
# ever touching the real file in a shared checkout.
printf '%s' "$LIST" | PLAN="$PLAN" EPIC="$EPIC" SHOW="$SHOW" TOOLS_DIR="$_TOOLS_DIR" python3 -c '
import importlib.util, json, os, re, sys
norm = lambda s: " ".join(s.split())
rows = lambda v: v if isinstance(v, list) else v.get("issues", [])
epic = os.environ["EPIC"]

def _load_bead():
    override = os.environ.get("BEAD_MODULE_PATH")
    path = override or os.path.join(os.environ["TOOLS_DIR"], "bead.py")
    spec = importlib.util.spec_from_file_location("bead", path)
    if spec is None or spec.loader is None:
        raise ImportError(f"cannot load bead.py at {path!r}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

try:
    bead = _load_bead()
    show = json.loads(os.environ["SHOW"])
    ids, err = bead.parent_child_children(show)
    if err:
        print(f"NOT-GATED: {epic} — {err}"); sys.exit(2)
    ids = set(ids)
    if not ids:
        print(f"NOT-GATED: {epic} has no parent-child children"); sys.exit(2)
    text = norm(" ".join(i.get("description") or "" for i in rows(json.load(sys.stdin)) if i["id"] in ids))
    plan = open(os.environ["PLAN"]).read()
    lines = [norm(l) for l in re.findall(r"Done when:(.*?)(?=\n\s*\n|\n\s*[-*] |\n#|\Z)", plan, re.S)]
    if not lines:
        print("REFUSED no-done-when: the plan carries no Done when: line"); sys.exit(1)
    gaps = [l for l in lines if l not in text]
    for g in gaps:
        print(f"COVERAGE GAP: {g}")
    if gaps: sys.exit(1)
    print(f"COVERED {len(lines)}")
except SystemExit:
    raise
except Exception as e:
    print(f"NOT-GATED: bead.py unavailable or crashed: {e}"); sys.exit(2)
'
