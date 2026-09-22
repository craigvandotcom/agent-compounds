#!/usr/bin/env bash
# require-minted-actor.test.sh — the static fallback and the human identity cannot claim.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
S="$ROOT/skills/ac-implement/scripts/require-minted-actor.sh"
D="$(mktemp -d "${TMPDIR:-/tmp}/mint-actor.XXXXXX")"
export AC2_FLIGHT_DIR="$D"
fails=0
check() { # <want-rc> <actor> <name>
  out="$(bash "$S" --actor "$2" 2>&1)"; rc=$?
  if [ "$rc" = "$1" ]; then
    echo "ok    $3"
  else
    echo "FAIL  $3 want=$1 got=$rc out=$out"
    fails=$((fails + 1))
  fi
}
check 1 "ac-20260919-231831-355190" "static ac-<ts>-<pid> hands back"
check 1 "" "empty actor hands back"
check 1 "FoggyCreek" "chore identity hands back"
check 1 "$(id -un)" "OS user hands back"
check 1 "$(git config --get user.name)" "git user.name hands back"
check 0 "BlackEagle" "minted name proceeds"
if [ -f "$D/hand-back" ] && grep -q 'HAND-BACK:' "$D/hand-back"; then
  echo "ok    hand-back receipt was written"
else
  echo "FAIL  hand-back receipt missing"
  fails=$((fails + 1))
fi
rm -rf "$D"
if [ "$fails" -eq 0 ]; then
  echo "require-minted-actor: all cases passed"
  exit 0
fi
echo "require-minted-actor: $fails failed"
exit 1
