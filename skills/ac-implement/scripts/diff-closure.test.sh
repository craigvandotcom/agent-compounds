#!/usr/bin/env bash
# diff-closure.test.sh — RED/GREEN proof harness for diff-closure.sh.
#
# ASSURANCE-ROLE: test-harness
# CALLER: scripts/run-all-harnesses.sh (discovered by its *.test.sh glob) and any local run.
#
# Every case builds a fresh fixture repo with KNOWN callers, applies one working-tree change,
# and asserts the verdict token and the named files:
#   lib/db/foods.ts    exports updateFood (called by lib/api.ts + a test) and deleteFood
#                      (called by features/x.ts); helper() is not exported
#   lib/old-module.ts  imported by lib/consumer.ts
# Exit 0 = all cases pass.
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/diff-closure.sh"
[ -x "$SCRIPT" ] || { echo "HARNESS FAIL: $SCRIPT missing or not executable"; exit 1; }
W=$(mktemp -d "${TMPDIR:-/tmp}/diff-closure-t-XXXXXX"); trap 'rm -rf "$W"' EXIT
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf 'ok   %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf 'FAIL %s\n     %s\n' "$1" "${2:-}"; }

mkrepo() {  # <dir> — base commit with the known callers
  local R="$1"; mkdir -p "$R/lib/db" "$R/features" "$R/__tests__"
  git -C "$R" init -q
  printf 'export function updateFood(id: string) { return id }\nexport function deleteFood(id: string) { return id }\nfunction helper() { return 1 }\n' > "$R/lib/db/foods.ts"
  printf 'import { updateFood } from "./db/foods"\nexport const save = (id: string) => updateFood(id)\n' > "$R/lib/api.ts"
  printf 'import { deleteFood } from "../lib/db/foods"\nexport const del = (id: string) => deleteFood(id)\n' > "$R/features/x.ts"
  printf 'import { updateFood } from "../lib/db/foods"\ntest("u", () => updateFood("1"))\n' > "$R/__tests__/foods.test.ts"
  printf 'export const old = 1\n' > "$R/lib/old-module.ts"
  printf 'import { old } from "./old-module"\nexport const c = old\n' > "$R/lib/consumer.ts"
  git -C "$R" add -A >/dev/null
  git -C "$R" -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -q -m base >/dev/null
}
run() { local R="$1"; shift; out=$("$SCRIPT" --base HEAD -C "$R" "$@" 2>&1); rc=$?; }

# --- 0. NOT-GATED ------------------------------------------------------------------------
out=$("$SCRIPT" --base HEAD -C "$W" 2>&1); rc=$?
[ "$rc" = 2 ] && printf '%s' "$out" | grep -q NOT-GATED && ok "not a repo -> NOT-GATED" || fail "not a repo" "$out"
R0="$W/r0"; mkrepo "$R0"
out=$("$SCRIPT" --base HEAD --bead x --declared /dev/null -C "$R0" 2>&1); rc=$?
[ "$rc" = 2 ] && ok "--bead with --declared -> NOT-GATED" || fail "exclusive flags" "$out"
out=$("$SCRIPT" --base nope -C "$R0" 2>&1); rc=$?
[ "$rc" = 2 ] && printf '%s' "$out" | grep -q "not a commit" && ok "bad base -> NOT-GATED" || fail "bad base" "$out"

# --- 1. a changed export with an undeclared caller outside the diff -> REFUSED, test not blamed
R1="$W/r1"; mkrepo "$R1"
sed -i.bak 's/updateFood(id: string)/updateFood(id: string, opts: {})/' "$R1/lib/db/foods.ts"; rm -f "$R1/lib/db/foods.ts.bak"
run "$R1"
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "REFUSED \[unowned-callers\] symbols=1 undeclared=1 declared=0 tests-outside=1" \
   && printf '%s' "$out" | grep -q "updateFood  <- lib/api.ts" && ! printf '%s' "$out" | grep -q "<- __tests__"; then
  ok "changed export, caller outside diff, nothing declared -> REFUSED naming lib/api.ts; the test is reported, not refused"
else
  fail "undeclared caller" "rc=$rc $out"
fi

# --- 2. the same change with a declaration that covers the caller -> PASS -------------------
printf 'rg -l -w updateFood lib\n' > "$W/decl1"
run "$R1" --declared "$W/decl1"
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q "PASS symbols=1 callers=2 declared=2 tests-outside=1" \
  && ok "declared touchers command covers the caller -> PASS (the declaration was true)" || fail "declared pass" "rc=$rc $out"

# --- 3. drift: a second export changed that the declaration never covered -> REFUSED --------
sed -i.bak 's/deleteFood(id: string)/deleteFood(id: string, hard: boolean)/' "$R1/lib/db/foods.ts"; rm -f "$R1/lib/db/foods.ts.bak"
run "$R1" --declared "$W/decl1"
[ "$rc" = 1 ] && printf '%s' "$out" | grep -q "deleteFood  <- features/x.ts" && ! printf '%s' "$out" | grep -q "updateFood  <-" \
  && ok "drift: the undeclared second symbol is refused by name; the declared one is not" || fail "drift" "rc=$rc $out"

# --- 4. a non-exported change -> PASS symbols=0 --------------------------------------------
R4="$W/r4"; mkrepo "$R4"
sed -i.bak 's/return 1/return 2/' "$R4/lib/db/foods.ts"; rm -f "$R4/lib/db/foods.ts.bak"
run "$R4"
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q "PASS symbols=0" && ok "change to a non-exported helper -> PASS, nothing to close over" || fail "helper" "rc=$rc $out"

# --- 5. a deleted file with an importer -> REFUSED by import stem ---------------------------
R5="$W/r5"; mkrepo "$R5"
rm -f "$R5/lib/old-module.ts"
run "$R5"
[ "$rc" = 1 ] && printf '%s' "$out" | grep -q "deleted:old-module  <- lib/consumer.ts" \
  && ok "deleted file with a live importer -> REFUSED (the stamp-refined.sh class)" || fail "deleted file" "rc=$rc $out"

# --- 6. a new export nobody calls yet -> PASS ------------------------------------------------
R6="$W/r6"; mkrepo "$R6"
printf 'export function brandNew() { return 0 }\n' >> "$R6/lib/db/foods.ts"
run "$R6"
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q "PASS symbols=1 callers=0" && ok "new export with no callers -> PASS" || fail "new export" "rc=$rc $out"

# --- 7. a change with no bead and no outside callers pays nothing ----------------------------
R7="$W/r7"; mkrepo "$R7"
printf 'export const lonely = 1\n' > "$R7/lib/lonely.ts"; sed -i.bak 's/lonely = 1/lonely = 2/' "$R7/lib/lonely.ts"; rm -f "$R7/lib/lonely.ts.bak"
git -C "$R7" add lib/lonely.ts >/dev/null; git -C "$R7" -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -q -m add >/dev/null
sed -i.bak 's/lonely = 2/lonely = 3/' "$R7/lib/lonely.ts"; rm -f "$R7/lib/lonely.ts.bak"
run "$R7"
[ "$rc" = 0 ] && ok "self-contained change, no declaration -> PASS (a hotfix pays nothing)" || fail "self-contained" "rc=$rc $out"

# --- 8. SQL: an altered column with a reader outside the diff -> REFUSED --------------------
R8="$W/r8"; mkrepo "$R8"; mkdir -p "$R8/supabase/migrations"
printf 'select image_urls from foods;\n' > "$R8/lib/db/read.sql"; git -C "$R8" add -A >/dev/null; git -C "$R8" -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -q -m sql >/dev/null
printf 'alter table foods drop column image_urls;\n' > "$R8/supabase/migrations/002.sql"; git -C "$R8" add -A >/dev/null
run "$R8"
[ "$rc" = 1 ] && printf '%s' "$out" | grep -q "image_urls  <- lib/db/read.sql" && ok "SQL: dropped column with a reader outside the diff -> REFUSED" || fail "sql" "rc=$rc $out"

# --- 9. spawns nothing; assurance declared ---------------------------------------------------
if grep -nE '(^|[^[:alnum:]_-])(claude|codex|droid)[[:space:]]|subagent' "$SCRIPT" >/dev/null; then fail "script invokes an agent"; else ok "diff-closure spawns nothing"; fi
miss=""; for f in PROBE: SCHEDULE: MODE: ON-FAILURE:; do grep -q "$f" "$SCRIPT" || miss="$miss $f"; done
[ -z "$miss" ] && ok "4-field assurance declaration present" || fail "assurance declaration missing:$miss"

echo "---"; echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
