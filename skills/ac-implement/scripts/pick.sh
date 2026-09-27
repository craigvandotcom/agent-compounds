#!/usr/bin/env bash
# pick.sh — the next bead a swarm worker may claim. Read-only: it selects, never claims.
#
# Eligibility is the whole filter: status `open` · label `refined` · type not `decision` · none
# of the labels epic / human-gate / device / unrefined · assignee unset or --actor · title not
# prefixed `PREMISE-FAILED:`. Order: bugs, then other work, then epics — an epic surfaces only
# when no child is left, so it is the terminal pick — each by priority, then age.
#
# The prod-write gate is claim-time eligibility: a bead labelled `sensitive-prod` (ac-polish's
# stamp for beads-standards' prod-write predicate) is eligible only with a CLOSED `blocks` edge
# to a DECISION bead. An open DECISION edge → GATED; no DECISION edge → MALFORMED. Both skip.
# The edge itself is read through bead.py's own public reader (`read_bead` + `blocking_ids`,
# ac-m9y4.3) — never a second inline edge-axis/title select of pick's own.
#
# Usage:  pick.sh [--actor NAME] [--burned "id id …"]   → `<id>`, `EPIC <id>`, or `DRY`
#         pick.sh --count [--actor NAME]               → the eligible pool size
# Stderr: `GATED <id>` / `MALFORMED <id>: no DECISION blocks edge`, one per skipped bead.
# Exit:   0 picked or counted · 1 DRY · 2 NOT-GATED (a br read failed — never read as DRY)
# Env:    AC2_BR_CMD — the br binary (br-call.sh)
#
#   PROBE:      bash skills/ac-implement/scripts/pick.test.sh — stub br, filter/order/gate/fail cases
#   SCHEDULE:   worker §1 every iteration · conductor Phase 0 (--count) · run-all-proofs.sh
#   MODE:       blocking
#   ON-FAILURE: closed — a failed read exits 2 NOT-GATED, never DRY and never a pick

ACTOR=""; BURNED=""; COUNT=0
while [ $# -gt 0 ]; do
  case $1 in
    --actor)  ACTOR=${2-}; shift 2 ;;
    --burned) BURNED=${2-}; shift 2 ;;
    --count)  COUNT=1; shift ;;
    *) echo "pick.sh: unknown argument: $1" >&2; exit 2 ;;
  esac
done

_TOOLS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../_tools" && pwd)"
. "$_TOOLS_DIR/br-call.sh"
export RUST_LOG=error
BEAD_PY_TOOL="${BEAD_PY_TOOL:-$_TOOLS_DIR/bead.py}"

ready=$(br_call ready --json -l refined --limit 0) || { echo "NOT-GATED: br ready failed" >&2; echo "NEXT: handback" >&2; exit 2; }
rows=$(printf '%s' "$ready" | jq -r --arg me "$ACTOR" '
  [ .[]
    | select(.status == "open")
    | select(.issue_type != "decision")
    | select(((.labels // []) | any(. == "epic" or . == "human-gate"
                or . == "device" or . == "unrefined")) | not)
    | select((.assignee // "") == "" or (.assignee // "") == $me)
    | select((.title | startswith("PREMISE-FAILED:")) | not)
  ]
  | sort_by(if .issue_type == "bug" then 0 elif .issue_type == "epic" then 2 else 1 end,
            .priority, .created_at)
  | .[] | [.id, .issue_type, ((.labels // []) | index("sensitive-prod") != null)] | @tsv') \
  || { echo "NOT-GATED: ready rows unparseable" >&2; echo "NEXT: handback" >&2; exit 2; }

n=0
while IFS=$'\t' read -r id type prod; do
  [ -n "$id" ] || continue
  case " $BURNED " in *" $id "*) continue ;; esac
  if [ "$prod" = true ]; then
    # DECISION edge via bead.py: total/closed counts of this bead's `blocks` edges onto a
    # DECISION-titled bead. `blocking_ids` (public, bead.py) selects the `blocks` axis; the
    # title/closed check reads each blocking id's own `read_bead` (title/status are dropped
    # from the canonical dependency dict on purpose, so each edge target is re-read once).
    edges=$(python3 -c '
import os, sys
sys.path.insert(0, os.path.dirname(sys.argv[1]))
import bead

canon, err = bead.read_bead(sys.argv[2])
if err:
    print("ERR " + err)
    sys.exit(2)
total = 0
closed_n = 0
for bid in bead.blocking_ids(canon):
    bcanon, berr = bead.read_bead(bid)
    if berr:
        print("ERR " + berr)
        sys.exit(2)
    if bcanon["title"].startswith("DECISION"):
        total += 1
        if bcanon["status"] == "closed":
            closed_n += 1
print("%d %d" % (total, closed_n))
' "$BEAD_PY_TOOL" "$id")
    rc=$?
    if [ "$rc" -ne 0 ]; then
      echo "NOT-GATED: bead.py could not read the DECISION edges for $id — $edges" >&2
      echo "NEXT: handback" >&2
      exit 2
    fi
    if [ "${edges#* }" -eq 0 ]; then
      if [ "${edges% *}" -gt 0 ]; then echo "GATED $id" >&2
      else echo "MALFORMED $id: no DECISION blocks edge" >&2; fi
      continue
    fi
  fi
  if [ "$COUNT" = 1 ]; then n=$((n + 1)); continue; fi
  if [ "$type" = epic ]; then echo "EPIC $id"; else echo "$id"; fi
  exit 0
done <<EOF
$rows
EOF

if [ "$COUNT" = 1 ]; then echo "$n"; exit 0; fi
echo DRY; exit 1
