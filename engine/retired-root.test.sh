#!/usr/bin/env bash
# engine/retired-root.test.sh — a dangling symlink under a retired root is pruned;
# a live foreign link and a dangling link anywhere else are left alone.
#
# ASSURANCE
#   PROBE:    bash engine/retired-root.test.sh
#   SCHEDULE: scripts/run-all-proofs.sh
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SYNC="$ROOT/engine/sync.sh"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

[ -f "$SYNC" ] || { echo "HARNESS FAIL: missing $SYNC"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/skills" "$tmp/retired/skills" "$tmp/real"
echo x > "$tmp/real/file"
ln -s "$tmp/retired/skills/gone" "$tmp/skills/gone"
ln -s "$tmp/real/file" "$tmp/skills/alive"
ln -s "$tmp/nowhere/nope" "$tmp/skills/user-dangling"

out="$(RETIRED_ROOTS="$tmp/retired" bash "$SYNC" --reclaim-retired-dangling "$tmp/skills" 2>&1)" || {
  bad "reclaim exited non-zero: $out"
  echo "FAILURES: $fails"
  exit 1
}

if [ -L "$tmp/skills/gone" ]; then
  bad "dangling link under the retired root was left in place"
else
  ok "dangling retired link pruned"
fi
if [ -L "$tmp/skills/alive" ]; then
  ok "live foreign link kept"
else
  bad "live foreign link was removed"
fi
if [ -L "$tmp/skills/user-dangling" ]; then
  ok "dangling link outside a retired root kept"
else
  bad "dangling link outside a retired root was removed"
fi
if printf '%s\n' "$out" | grep -q 'pruned (dangling)'; then
  ok "prune was reported"
else
  bad "prune produced no report: $out"
fi

# Same tree with no retired root configured: nothing is a leftover, so the
# dangling retired-shaped link (re-seeded) must survive.
ln -s "$tmp/retired/skills/gone" "$tmp/skills/gone"
out="$(RETIRED_ROOTS= bash "$SYNC" --reclaim-retired-dangling "$tmp/skills" 2>&1)" || {
  bad "unconfigured reclaim exited non-zero: $out"
}
if [ -L "$tmp/skills/gone" ]; then
  ok "no retired root configured leaves the dangling link"
else
  bad "unconfigured run pruned a link it should not know"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "OK: retired-root prune ($(basename "$0"))"
  exit 0
fi
echo "FAILURES: $fails — dangling retired symlinks are outside the prune contract ($(basename "$0"))"
exit 1
