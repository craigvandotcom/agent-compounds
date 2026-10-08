#!/usr/bin/env bash
# claim.sh — claim a bead and record it, the CLAIM comment gated on the claim's OWN exit.
#
# Usage: claim.sh <bead-id> --actor <minted-name>
#
# Runs require-minted-actor.sh, then the atomic `br update --claim`, then (only if the claim
# succeeded) posts `CLAIM: <actor>` through a file. The claim's exit status is read directly,
# never through a pipe: `br update --claim | head` reports head's status and hid every refusal.
#
# Exit 0  claimed, exactly one CLAIM comment written
# Exit 1  require-minted-actor refused (hand-back receipt written) — claim nothing, go to §9
# Exit 2  usage / could not verify (br missing, comment failed after a successful claim)
# Exit 3  ALREADY-CLAIMED — the claim was refused; no comment written; burn the id, re-pick
#
#   PROBE: bash skills/ac-implement/scripts/claim.test.sh
#   SCHEDULE: worker §2, in place of the raw claim and comment commands
#   MODE: blocking
#   ON-FAILURE: closed — non-zero exit, no CLAIM comment
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ID=""; ACTOR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --actor) ACTOR="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,15p' "${BASH_SOURCE[0]}" >&2; exit 2 ;;
    -*) echo "claim: unknown option: $1" >&2; exit 2 ;;
    *) [ -z "$ID" ] && ID="$1" || { echo "claim: unexpected argument: $1" >&2; exit 2; }; shift ;;
  esac
done
[ -n "$ID" ] && [ -n "$ACTOR" ] || { echo "claim: usage: claim.sh <bead-id> --actor <name>" >&2; exit 2; }
command -v br >/dev/null 2>&1 || { echo "claim: NOT-GATED: br is not on PATH" >&2; exit 2; }

# shellcheck source=../../_tools/br-call.sh
. "$HERE/../../_tools/br-call.sh" 2>/dev/null \
  || { echo "claim: NOT-GATED: br-call.sh helper missing — the claim cannot be verified" >&2; exit 2; }

bash "$HERE/require-minted-actor.sh" --actor "$ACTOR" || exit 1

# br_call refuses both failure shapes: a non-zero exit AND an rc-0 JSON error envelope
# (VALIDATION_FAILED), returning 2. Its stderr carries the envelope message.
out=$(RUST_LOG=error br_call update "$ID" --claim --actor "$ACTOR" --json </dev/null 2>&1)
rc=$?
if [ "$rc" -ne 0 ]; then
  echo "claim: ALREADY-CLAIMED: $ID was refused (rc=$rc) — burn it and re-pick" >&2
  printf '%s\n' "$out" >&2
  exit 3
fi
printf '%s\n' "$out"

f=$(mktemp "${TMPDIR:-/tmp}/ac-claim.XXXXXX") || { echo "claim: NOT-GATED: cannot create a scratch file" >&2; exit 2; }
printf 'CLAIM: %s\n' "$ACTOR" > "$f"
RUST_LOG=error br comments add "$ID" -f "$f" </dev/null >/dev/null
crc=$?
rm -f "$f"
[ "$crc" -eq 0 ] || { echo "claim: NOT-GATED: claimed $ID but the CLAIM comment failed (rc=$crc)" >&2; exit 2; }
exit 0
