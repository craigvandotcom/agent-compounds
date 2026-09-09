#!/usr/bin/env sh
# dcg-fail-closed — wrapper enforcing ruling ac-dcg-fails-closed-u7hj (Craig, 2026-09-02):
# dcg guards irreversible actions, so when dcg cannot render a decision — crash, missing
# binary, non-JSON output — the wrapper BLOCKS. A broken destructive-command guard stops
# the line; it does not wave commands through at the moment the environment is broken
# enough to have crashed the guard. dcg's own decisions (exit 0) pass through untouched.
# Canon: hooks/hooks.json + ac-pipeline/references/assurance-declarations.md.
set -u
DCG="${DCG_UNDER_TEST:-$HOME/.local/bin/dcg}"
ERR="$(mktemp /tmp/dcg-fail-closed-stderr.XXXXXX)"
trap 'rm -f "$ERR"' EXIT
if [ ! -x "$DCG" ]; then
  echo "dcg-fail-closed: dcg missing or not executable at $DCG — BLOCKED (fail-closed)" >&2
  exit 2
fi
OUT="$("$DCG" "$@" 2>"$ERR")"
RC=$?
if [ "$RC" -eq 0 ] && { [ -z "$OUT" ] || printf '%s' "$OUT" | jq -e . >/dev/null 2>&1; }; then
  printf '%s' "$OUT"
  exit 0
fi
tail -2 "$ERR" >&2
echo "dcg-fail-closed: dcg exited ${RC:-0} without a parseable decision — BLOCKED (fail-closed ruling ac-dcg-fails-closed-u7hj)" >&2
exit 2
