#!/usr/bin/env bash
# bead-readback.test.sh — proof harness for bead-readback.sh against a REAL br in a throwaway
# .beads (a stub would prove nothing about what br persists — persistence is the claim).
#
# Coverage: a clean filing (bodies written with --description-file, edges wired) reads back
# OK; the 2026-09-28 clobber — a resolver whose loop variable leaks into the caller, so every
# rewrite lands on one bead — is caught as UNRESOLVED + DRIFT even though a parity computed
# from the local resolved files would pass; a board body that differs from its file with no
# placeholder is DRIFT; a Consumes line with no edge (and an edge with no line) is PARITY; a
# missing bead or file is NOT-GATED (exit 2), never OK.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/bead-readback.sh"
command -v br >/dev/null 2>&1 || { echo "SKIP: br is not installed — the read-back is only meaningful against a real board"; exit 77; }
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq is not installed — br_call needs it"; exit 77; }
PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf '  FAIL  %s\n' "$1"; }

W=$(mktemp -d /tmp/bead-readback-test-XXXXXX)
trap 'rm -rf "$W"' EXIT
cd "$W" || exit 2
git init -q . && RUST_LOG=error br init --prefix rb >/dev/null 2>&1 || { echo "br init failed"; exit 2; }
export RUST_LOG=error
unset AC2_BR_CMD

body() {  # <consumes-lines…> → a four-section body on stdout
  printf '## Intent\nOwned by: __EPIC__ sibling work.\n\n## Acceptance Criteria\n- it works\n  Probe: `true` — tier: none\n\n## Delivers\n- a/b.sh\n\n## Consumes\n'
  if [ $# -eq 0 ]; then echo "- none"; else printf '%s\n' "$@"; fi
}

# ---- a filing: epic + three children; B3 consumes B1 and B2 ------------------------------------
EPIC=$(br create "Readback fixture — the gate reads bodies back from the board" -t epic -p 2 -d "fixture epic" --silent)
mkdir -p src resolved
body > src/B1.md
body > src/B2.md
body "- __B1__ -> a/b.sh" "- __B2__ -> a/b.sh" > src/B3.md
declare -A ID
for b in B1 B2 B3; do ID[$b]=$(br create "child $b" -t task -p 2 --parent "$EPIC" -d "$(cat src/$b.md)" --silent); done
br dep add "${ID[B3]}" "${ID[B1]}" >/dev/null
br dep add "${ID[B3]}" "${ID[B2]}" >/dev/null

# The 2026-09-28 resolver, verbatim in shape: `b` is NOT local, so it leaks.
resolve_leaky() {
  cp "$1" "$2"
  for b in B3 B2 B1; do sed -i.bak "s/__${b}__/${ID[$b]}/g" "$2"; done
  sed -i.bak "s/__EPIC__/${EPIC}/g" "$2"
}
for b in B1 B2 B3; do
  resolve_leaky "src/$b.md" "resolved/$b.md"
  br update "${ID[$b]}" -d "$(cat "resolved/$b.md")" >/dev/null   # $b is now B1 every time
done
ARGS=("${ID[B1]}=resolved/B1.md" "${ID[B2]}=resolved/B2.md" "${ID[B3]}=resolved/B3.md")

# the local-file parity the 2026-09-28 script ran — it passes on this broken board
grep -qE '__(B[0-9]+|EPIC)__' resolved/*.md && bad "fixture: resolved files should be clean" || ok

out=$(bash "$SCRIPT" check "${ARGS[@]}"); rc=$?
[ "$rc" -eq 1 ] && ok || bad "leaky resolver: want rc 1, got $rc: $out"
printf '%s' "$out" | grep -q "UNRESOLVED ${ID[B3]} " && ok || bad "leaky resolver: B3 UNRESOLVED not reported: $out"
printf '%s' "$out" | grep -q "UNRESOLVED ${ID[B2]} " && ok || bad "leaky resolver: B2 UNRESOLVED not reported: $out"
printf '%s' "$out" | grep -q "DRIFT ${ID[B3]} " && ok || bad "leaky resolver: B3 DRIFT not reported: $out"
printf '%s' "$out" | grep -q "PARITY ${ID[B3]} " && ok || bad "leaky resolver: board Consumes (placeholders) vs edges not PARITY: $out"
printf '%s' "$out" | grep -q '^readback: FAIL ' && ok || bad "leaky resolver: no FAIL summary: $out"

# ---- the fix: a local loop variable, bodies written verbatim with --description-file ----------
resolve() {
  local src=$1 dst=$2 k
  cp "$src" "$dst"
  for k in B3 B2 B1; do sed -i.bak "s/__${k}__/${ID[$k]}/g" "$dst"; done
  sed -i.bak "s/__EPIC__/${EPIC}/g" "$dst"
}
for b in B1 B2 B3; do
  resolve "src/$b.md" "resolved/$b.md"
  br update "${ID[$b]}" --description-file "resolved/$b.md" >/dev/null
done
out=$(bash "$SCRIPT" check "${ARGS[@]}"); rc=$?
[ "$rc" -eq 0 ] && ok || bad "clean filing: want rc 0, got $rc: $out"
printf '%s' "$out" | grep -q '^readback: OK 3 beads$' && ok || bad "clean filing: no OK summary: $out"

# ---- DRIFT with no placeholder: the board holds a different (resolved) body --------------------
cp resolved/B1.md drift.md; printf 'an extra line the board never got\n' >> drift.md
out=$(bash "$SCRIPT" check "${ID[B1]}=drift.md"); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q "DRIFT ${ID[B1]} " && ok || bad "drift: want rc 1 + DRIFT, got $rc: $out"
printf '%s' "$out" | grep -q UNRESOLVED && bad "drift: no placeholder, yet UNRESOLVED: $out" || ok

# ---- PARITY both ways: a Consumes line with no edge, an edge with no line ----------------------
br update "${ID[B2]}" --description-file <(body "- ${ID[B1]} -> a/b.sh") >/dev/null
body "- ${ID[B1]} -> a/b.sh" > resolved/B2.md
out=$(bash "$SCRIPT" check "${ID[B2]}=resolved/B2.md"); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q "PARITY ${ID[B2]} " && ok || bad "parity (line, no edge): got $rc: $out"
br dep add "${ID[B1]}" "${ID[B2]}" >/dev/null   # B1 now blocks on B2, yet B1 Consumes none
out=$(bash "$SCRIPT" check "${ID[B1]}=resolved/B1.md"); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q "PARITY ${ID[B1]} " && ok || bad "parity (edge, no line): got $rc: $out"

# ---- NOT-GATED: a missing bead, a missing file, bad usage --------------------------------------
bash "$SCRIPT" check "rb-nope=resolved/B1.md" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] && ok || bad "missing bead: want rc 2, got $rc"
bash "$SCRIPT" check "${ID[B1]}=no-such-file.md" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] && ok || bad "missing file: want rc 2, got $rc"
bash "$SCRIPT" check "${ID[B1]}" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] && ok || bad "no =file: want rc 2, got $rc"

echo "bead-readback.test.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
