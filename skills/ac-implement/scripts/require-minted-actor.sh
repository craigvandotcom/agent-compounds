#!/usr/bin/env bash
# require-minted-actor.sh — a swarm worker with no minted name must hand back.
#
# The static `ac-<ts>-<pid>` form, FoggyCreek, the OS user, and the git user are not
# identities. On refusal this writes a hand-back receipt and exits 1, so the claim
# that would have followed does not run. A minted name exits 0 and writes nothing.
#
#   PROBE: bash skills/ac-implement/scripts/require-minted-actor.test.sh
#   SCHEDULE: worker §2, before br update --claim
#   MODE: blocking
#   ON-FAILURE: closed — exit 1, receipt on disk, no claim
set -euo pipefail

ACTOR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --actor) ACTOR="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0" >&2; exit 2 ;;
    *) echo "require-minted-actor: unknown argument: $1" >&2; exit 2 ;;
  esac
done

refuse() {
  dir="${AC2_FLIGHT_DIR:-$(git rev-parse --git-common-dir 2>/dev/null || echo .)/ac-flight/}"
  mkdir -p "$dir"
  printf 'HAND-BACK: mint failed; actor=%s; claiming nothing\n' "${ACTOR:-<empty>}" > "$dir/hand-back"
  echo "require-minted-actor: hand back — $1" >&2
  exit 1
}

[ -n "$ACTOR" ] || refuse "no actor"
[ "$ACTOR" = "FoggyCreek" ] && refuse "chore identity cannot claim"
if printf '%s' "$ACTOR" | grep -qxE 'ac-[0-9]{8}-[0-9]{6}-[0-9]+'; then
  refuse "static ac-<ts>-<pid> fallback"
fi
me=$(id -un 2>/dev/null || true)
[ -n "$me" ] && [ "$ACTOR" = "$me" ] && refuse "OS user is not a minted actor"
git_name=$(git config --get user.name 2>/dev/null || true)
[ -n "$git_name" ] && [ "$ACTOR" = "$git_name" ] && refuse "git user.name is not a minted actor"
exit 0
