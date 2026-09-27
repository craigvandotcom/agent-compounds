#!/usr/bin/env bash
# plan-coverage.sh — every plan "Done when:" line reached a bead (plan → beads coverage).
#
# The schema already makes each child AC quote its plan "Done when:" verbatim
# (ac-beadify/references/bead-schema.md), so the quote IS the trace: each plan line must
# reappear in the text of the epic or one of its children. A deliverable the cut dropped
# whole — or reworded — passes every other gate and retires with the plan; this is the
# one check that notices. Whitespace and line wraps are normalised; the words must match.
#
# ASSURANCE (ac-pipeline/references/assurance-declarations.md § The four fields):
#   PROBE:      skills/_tools/plan-coverage.test.sh — both polarities
#   SCHEDULE:   every ac-beadify compile, before plan retirement (SKILL.md step 7);
#               and on every CI run via scripts/run-all-proofs.sh
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

SHOW=$(br_call show "$EPIC" --json) || { echo "NOT-GATED: br show refused for $EPIC"; exit 2; }
LIST=$(br_call list --all --limit 0 --json) || { echo "NOT-GATED: br list refused"; exit 2; }

printf '%s' "$LIST" | PLAN="$PLAN" EPIC="$EPIC" SHOW="$SHOW" python3 -c '
import json, os, re, sys
norm = lambda s: " ".join(s.split())
rows = lambda v: v if isinstance(v, list) else v.get("issues", [])
show = json.loads(os.environ["SHOW"]); show = show[0] if isinstance(show, list) else show
epic = os.environ["EPIC"]
ids = {epic} | {d["id"] for d in show.get("dependents") or [] if d.get("dependency_type") == "parent-child"}
if len(ids) == 1:
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
'
