#!/usr/bin/env bash
# worker-paths.test.sh — worker.md and SKILL.md name <scripts>, never a repo-relative literal.
#
# ASSURANCE
#   PROBE:      bash skills/ac-implement/scripts/worker-paths.test.sh
#   SCHEDULE:   every scripts/run-all-proofs.sh run (repo-wide *.test.sh discovery),
#               scheduled by CI's `proofs` job.
#   MODE:       blocking
#   ON-FAILURE: closed
#
# worker.md is spawned VERBATIM into consumer repos via .agents/skills/ (and equivalents),
# where there is no root skills/ dir — a literal `skills/ac-implement/scripts/…` or
# `skills/ac-pipeline/SKILL.md` path resolves nowhere there. Delegation contract
# (skills/ac-pipeline/references/delegation-contract.md): literal paths only, never a
# shell var — shell state does not persist across tool calls. The fix is a placeholder,
# `<scripts>`, substituted from a `SCRIPTS=<absolute path>` line the conductor appends to
# the spawn prompt (the same convention as `<id>`).
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
WORKER="$HERE/../references/worker.md"
SKILL="$HERE/../SKILL.md"

PASS=0
FAIL=0
ok()  { PASS=$(( PASS + 1 )); echo "  ok   — $*"; }
bad() { FAIL=$(( FAIL + 1 )); echo "  FAIL — $*"; }

[ -f "$WORKER" ] || { echo "worker-paths.test: worker.md missing at $WORKER"; exit 1; }
[ -f "$SKILL" ]  || { echo "worker-paths.test: SKILL.md missing at $SKILL"; exit 1; }

# --- worker.md: no literal scripts/skill path survives -----------------------------------

grep -q 'skills/ac-implement/scripts' "$WORKER" \
  && bad "worker.md still spells the literal 'skills/ac-implement/scripts' path" \
  || ok "worker.md names no literal 'skills/ac-implement/scripts' path"

grep -q 'skills/ac-pipeline/SKILL.md' "$WORKER" \
  && bad "worker.md still spells the literal 'skills/ac-pipeline/SKILL.md' path" \
  || ok "worker.md names no literal 'skills/ac-pipeline/SKILL.md' path"

grep -q '<scripts>' "$WORKER" \
  && ok "worker.md uses the <scripts> placeholder" \
  || bad "worker.md never uses <scripts>"

# --- worker.md: the session-start SCRIPTS= stop rule --------------------------------------

grep -q 'SCRIPTS=' "$WORKER" \
  && ok "worker.md names the SCRIPTS= line it substitutes <scripts> from" \
  || bad "worker.md never names a SCRIPTS= line"

grep -q 'No `SCRIPTS=` line' "$WORKER" && grep -q 'stop (§9)' "$WORKER" \
  && ok "worker.md states the no-SCRIPTS-line stop rule (§9, never a repo-relative fallback)" \
  || bad "worker.md is missing the no-SCRIPTS-line -> stop rule"

grep -qi 'repo-relative' "$WORKER" \
  && ok "worker.md names the repo-relative fallback it forbids" \
  || bad "worker.md does not forbid a repo-relative fallback"

# --- SKILL.md: <scripts> is defined, and the appended SCRIPTS= line is named --------------

grep -qE '`<scripts>`.*=|`<scripts>` is its' "$SKILL" \
  && ok "SKILL.md defines <scripts>" \
  || bad "SKILL.md never defines <scripts>"

grep -q 'SCRIPTS=' "$SKILL" \
  && ok "SKILL.md names the appended SCRIPTS= line" \
  || bad "SKILL.md never names an appended SCRIPTS= line"

grep -q 'skills/ac-implement/scripts' "$SKILL" \
  && bad "SKILL.md still spells the literal 'skills/ac-implement/scripts' path" \
  || ok "SKILL.md names no literal 'skills/ac-implement/scripts' path"

echo ""
echo "worker-paths.test: $PASS passed, $FAIL failed"
if [ "$PASS" -eq 0 ]; then
  echo "worker-paths.test: NOT-GATED — zero cases ran; a harness that asserted nothing is not a pass"
  exit 1
fi
[ "$FAIL" -eq 0 ]
