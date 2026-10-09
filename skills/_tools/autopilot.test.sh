#!/usr/bin/env bash
#
# autopilot.test.sh — hermetic proof for autopilot.sh, the one reader of a project's
# .claude/factory.json "autopilot" block.
#
# Every case builds a throwaway project directory with its own factory.json and runs the
# helper from inside it, so nothing here reads the registry's own config.  Exit contract
# under test: 0 yes/match, 1 no/inactive, 2 NOT-GATED (fail closed), 64 usage.
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SCRIPT="$HERE/autopilot.sh"
PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); printf '  ok   — %s\n' "$*"; }
bad() { FAIL=$((FAIL + 1)); printf '  FAIL — %s\n' "$*"; }

[ -x "$SCRIPT" ] || { echo "autopilot.test: autopilot.sh missing or not executable at $SCRIPT"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "autopilot.test: jq missing"; exit 77; }

WORK=$(mktemp -d "${TMPDIR:-/tmp}/ac-autopilot-test.XXXXXX") || {
  echo "autopilot.test: cannot create scratch directory"
  exit 1
}
trap 'rm -rf "$WORK"' EXIT

unset AC2_AUTOPILOT

PROTECT='^\\.claude/|^\\.github/|^scripts/ship/|^supabase/|\\.sql$|(^|/)package\\.json$'
VALID_BLOCK='{"autopilot":{"enabled":true,"implement":false,"max_priority":1,"width":2,"cap":1,"protect":"'"$PROTECT"'"}}'

# mkproj <name> [json]  — a project dir; no json argument means no factory.json at all.
mkproj() {
  local d="$WORK/$1"
  mkdir -p "$d/.claude"
  git init -q "$d"
  [ "$#" -ge 2 ] && printf '%s\n' "$2" >"$d/.claude/factory.json"
  PROJ="$d"
}

# run <project> <env-value|-> <args…>  — sets RC OUT ERR.
run() {
  local dir="$1" envv="$2"
  shift 2
  if [ "$envv" = "-" ]; then
    OUT=$(cd "$dir" && env -u AC2_AUTOPILOT "$SCRIPT" "$@" 2>"$WORK/stderr")
  else
    OUT=$(cd "$dir" && AC2_AUTOPILOT="$envv" "$SCRIPT" "$@" 2>"$WORK/stderr")
  fi
  RC=$?
  ERR=$(<"$WORK/stderr")
}

expect() { # expect <rc> <label>
  [ "$RC" -eq "$1" ] && ok "$2" || bad "$2 — expected rc=$1, got rc=$RC out='$OUT' err='$ERR'"
}

# ---------------------------------------------------------------------------------------
printf '%s\n' 'autopilot.test: case 1 — inactive states exit 1 and say nothing'
# ---------------------------------------------------------------------------------------
mkproj no-file
run "$PROJ" 1 active
expect 2 'AC2_AUTOPILOT=1 with no factory.json at all is NOT-GATED, not inactive'

mkproj no-block '{"ship":{"prove":"x"}}'
run "$PROJ" 1 active
expect 1 'no autopilot block → inactive'

mkproj disabled '{"autopilot":{"enabled":false,"max_priority":1,"protect":"^supabase/"}}'
run "$PROJ" 1 active
expect 1 'enabled:false → inactive'

mkproj no-enabled '{"autopilot":{"max_priority":1,"protect":"^supabase/"}}'
run "$PROJ" 1 active
expect 1 'enabled absent → inactive'

mkproj env-unset "$VALID_BLOCK"
run "$PROJ" - active
expect 1 'env unset → inactive even with a valid enabled block'
run "$PROJ" 0 active
expect 1 'AC2_AUTOPILOT=0 → inactive'

mkproj no-file-unset
run "$PROJ" - active
expect 1 'env unset and no factory.json → inactive (interactive runs are untouched)'

# ---------------------------------------------------------------------------------------
printf '%s\n' 'autopilot.test: case 2 — a valid block is active'
# ---------------------------------------------------------------------------------------
mkproj valid "$VALID_BLOCK"
run "$PROJ" 1 active
expect 0 'env set + enabled:true + protect + max_priority → active'
[ -z "$OUT" ] && ok 'active prints nothing on stdout' || bad "active printed '$OUT'"

mkdir -p "$PROJ/sub/dir"
run "$PROJ/sub/dir" 1 active
expect 0 'resolves the project root from a subdirectory'

# ---------------------------------------------------------------------------------------
printf '%s\n' 'autopilot.test: case 3 — protected'
# ---------------------------------------------------------------------------------------
run "$PROJ" 1 protected supabase/x.sql
[ "$RC" -eq 0 ] && [ "$OUT" = supabase/x.sql ] \
  && ok 'protected supabase/x.sql → printed, exit 0' \
  || bad "expected rc=0 out=supabase/x.sql, got rc=$RC out='$OUT' err='$ERR'"

run "$PROJ" 1 protected .beads/issues.jsonl
[ "$RC" -eq 1 ] && [ -z "$OUT" ] \
  && ok 'protected .beads/issues.jsonl → no match, exit 1' \
  || bad "ledger read as protected: rc=$RC out='$OUT'"

mkproj ledger-bait '{"autopilot":{"enabled":true,"max_priority":1,"protect":"^\\.beads/|\\.jsonl$"}}'
run "$PROJ" 1 protected .beads/issues.jsonl
[ "$RC" -eq 1 ] && [ -z "$OUT" ] \
  && ok 'ledger stays unprotected even when the project ERE would match it' \
  || bad "ledger matched a hostile ERE: rc=$RC out='$OUT'"
run "$PROJ" 1 protected .beads/other.jsonl
[ "$RC" -eq 0 ] && ok 'the ledger exemption is exact — a sibling .beads file still matches' \
  || bad "sibling .beads file escaped: rc=$RC out='$OUT'"

mkproj multi "$VALID_BLOCK"
run "$PROJ" 1 protected src/a.ts supabase/x.sql .claude/factory.json app/package.json
LINES=$(printf '%s\n' "$OUT" | paste -sd, -)
[ "$RC" -eq 0 ] && [ "$LINES" = 'supabase/x.sql,.claude/factory.json,app/package.json' ] \
  && ok 'several paths → only the matching ones, in order' \
  || bad "multi-path: rc=$RC out='$LINES'"

run "$PROJ" 1 protected ./supabase/x.sql
[ "$RC" -eq 0 ] && ok 'a leading ./ does not slip a path past an anchored ERE' \
  || bad "./supabase/x.sql escaped: rc=$RC out='$OUT'"

run "$PROJ" 1 protected src/a.ts
expect 1 'no match → exit 1'

run "$PROJ" 1 protected
expect 64 'protected with no paths is a usage error'

# protected is independent of the env switch and of enabled: the D10 done-when runs it on a disabled block.
mkproj off-but-declared '{"autopilot":{"enabled":false,"max_priority":1,"protect":"^supabase/"}}'
run "$PROJ" - protected supabase/x.sql
[ "$RC" -eq 0 ] && [ "$OUT" = supabase/x.sql ] \
  && ok 'protected reads the declared list with env unset and enabled:false' \
  || bad "protected on a disabled block: rc=$RC out='$OUT'"

mkproj no-block-protected '{"ship":{}}'
run "$PROJ" 1 protected supabase/x.sql
expect 1 'no autopilot block → nothing is protected'

# ---------------------------------------------------------------------------------------
printf '%s\n' 'autopilot.test: case 4 — get'
# ---------------------------------------------------------------------------------------
mkproj getter "$VALID_BLOCK"
run "$PROJ" 1 get max_priority
[ "$RC" -eq 0 ] && [ "$OUT" = 1 ] && ok 'get max_priority → 1' || bad "get max_priority: rc=$RC out='$OUT'"
run "$PROJ" 1 get enabled
[ "$RC" -eq 0 ] && [ "$OUT" = true ] && ok 'get enabled → true' || bad "get enabled: rc=$RC out='$OUT'"
run "$PROJ" 1 get protect
[ "$RC" -eq 0 ] && [ "$OUT" = '^\.claude/|^\.github/|^scripts/ship/|^supabase/|\.sql$|(^|/)package\.json$' ] \
  && ok 'get protect → the unescaped ERE, raw' || bad "get protect: rc=$RC out='$OUT'"
run "$PROJ" 1 get nosuchkey
[ "$RC" -eq 1 ] && [ -z "$OUT" ] && ok 'get of an absent key → exit 1, empty' || bad "get absent: rc=$RC out='$OUT'"
run "$PROJ" 1 get
expect 64 'get with no key is a usage error'

# ---------------------------------------------------------------------------------------
printf '%s\n' 'autopilot.test: case 5 — a misconfigured block fails closed (NOT-GATED, exit 2)'
# ---------------------------------------------------------------------------------------
notgated() { # notgated <label>
  if [ "$RC" -eq 2 ] && printf '%s' "$ERR" | grep -q 'NOT-GATED'; then ok "$1"
  else bad "$1 — expected rc=2 + NOT-GATED, got rc=$RC out='$OUT' err='$ERR'"; fi
}

mkproj bad-ere '{"autopilot":{"enabled":true,"max_priority":1,"protect":"^supabase/(["}}'
run "$PROJ" 1 active
notgated 'malformed ERE: active → NOT-GATED'
run "$PROJ" 1 protected supabase/x.sql
notgated 'malformed ERE: protected → NOT-GATED, never a silent no-match'
[ -z "$OUT" ] && ok 'malformed ERE prints no path' || bad "malformed ERE printed '$OUT'"

mkproj no-protect '{"autopilot":{"enabled":true,"max_priority":1}}'
run "$PROJ" 1 active
notgated 'missing protect → NOT-GATED'

mkproj empty-protect '{"autopilot":{"enabled":true,"max_priority":1,"protect":""}}'
run "$PROJ" 1 active
notgated 'empty protect → NOT-GATED (an empty ERE matches every path)'
run "$PROJ" 1 protected src/a.ts
notgated 'empty protect: protected → NOT-GATED, not "everything matches"'

mkproj empty-alt '{"autopilot":{"enabled":true,"max_priority":1,"protect":"^supabase/|"}}'
run "$PROJ" 1 active
notgated 'an ERE with an empty alternative (matches every path) → NOT-GATED'

mkproj no-maxprio '{"autopilot":{"enabled":true,"protect":"^supabase/"}}'
run "$PROJ" 1 active
notgated 'missing max_priority → NOT-GATED'

mkproj str-maxprio '{"autopilot":{"enabled":true,"max_priority":"high","protect":"^supabase/"}}'
run "$PROJ" 1 active
notgated 'non-integer max_priority → NOT-GATED'

mkproj str-enabled '{"autopilot":{"enabled":"yes","max_priority":1,"protect":"^supabase/"}}'
run "$PROJ" 1 active
notgated 'enabled that is not a boolean → NOT-GATED'

mkproj not-object '{"autopilot":true}'
run "$PROJ" 1 active
notgated 'autopilot block that is not an object → NOT-GATED'

mkproj bad-json '{"autopilot": {'
run "$PROJ" 1 active
notgated 'unparseable factory.json under env=1 → NOT-GATED'

mkproj get-bad '{"autopilot":{"enabled":true,"max_priority":1}}'
run "$PROJ" 1 get max_priority
notgated 'get on a block missing protect → NOT-GATED'

mkproj bad-json-unset '{"autopilot": {'
run "$PROJ" - active
expect 1 'unparseable factory.json with env unset → inactive, interactive runs untouched'

# ---------------------------------------------------------------------------------------
printf '%s\n' 'autopilot.test: case 6 — usage'
# ---------------------------------------------------------------------------------------
run "$PROJ" 1
expect 64 'no verb → usage error'
run "$PROJ" 1 frobnicate
expect 64 'unknown verb → usage error'

printf 'autopilot.test: %s passed, %s failed\n' "$PASS" "$FAIL"
[ "$PASS" -gt 0 ] || exit 1
[ "$FAIL" -eq 0 ]
