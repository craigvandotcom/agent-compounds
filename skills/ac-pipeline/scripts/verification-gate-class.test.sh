#!/usr/bin/env bash
# verification-gate-class.test.sh — proof harness for `ac-pipeline/references/verification-gate.md`
# Step 1 diff classification (bd-55f7a native fix, bd-mdbhr logic/webrt fix).
#
# WHY IT EXISTS: Step 1's classifier is a pasted bash block, so its only possible
# regression test is to execute the block AS PUBLISHED. This extracts the live first
# fenced ```bash block from the doc, stubs `git`, injects a fixture file list, and
# asserts the five CLASS_* flags. A doc edit that breaks a class is caught here, not
# in a wasted simulator pass.
#
# THE INVARIANT IT GUARDS: doc/test/CI files are excluded ONCE ($CODE_FILES) and
# EXACTLY ONE probe opts out to read unfiltered $FILES — CLASS_WEBUI's design-token
# line, where `design.md` legitimately IS the visual surface. Two failure directions:
# a blanket hoist kills that opt-out (PROOF1), and a per-class miss lets a lone
# `supabase/README.md` select passes (PROOF3) — while a doc must NEVER mask real code
# in a mixed diff (PROOF2, the fail-safe).
#
# Runs under bash AND zsh (the fleet default shell) — verify both before landing a
# Step 1 edit:  bash <this>  &&  zsh <this>
# Exit 0 = all cases pass.

SELF_DIR=$(cd "$(dirname "$0")" && pwd)
DOC="$SELF_DIR/../references/verification-gate.md"
[ -f "$DOC" ] || { echo "HARNESS FAIL: doc not found at $DOC"; exit 1; }

# First fenced bash block = Step 1. Drop the git-dependent FILES assignment (fixture instead).
BLOCK=$(awk '/^```bash$/{f=1;next} /^```$/{if(f)exit} f' "$DOC" | grep -v '^FILES=')
[ -n "$BLOCK" ] || { echo "HARNESS FAIL: could not extract the Step 1 bash block"; exit 1; }

# Stub git: only the package.json content probe must answer; everything else is inert.
git() {
  case "$*" in
    *"-- package.json"*) printf '%s\n' "$PKGDIFF" ;;
    *) : ;;
  esac
}

PASS=0
FAIL=0
# run_case <name> <newline-separated file list> <package.json diff> <want NATIVE,WEBUI,WEBRT,LOGIC,RUNTIME>
run_case() {
  name="$1"; FILES="$2"; PKGDIFF="$3"; want="$4"
  eval "$BLOCK" >/dev/null 2>&1
  got="$CLASS_NATIVE,$CLASS_WEBUI,$CLASS_WEBRT,$CLASS_LOGIC,$CLASS_RUNTIME"
  if [ "$got" = "$want" ]; then
    PASS=$((PASS + 1)); printf 'ok   %-46s %s\n' "$name" "$got"
  else
    FAIL=$((FAIL + 1)); printf 'FAIL %-46s got=%s want=%s\n' "$name" "$got" "$want"
  fi
}

echo "shell: ${ZSH_VERSION:+zsh $ZSH_VERSION}${BASH_VERSION:+bash $BASH_VERSION}"
echo "order: NATIVE,WEBUI,WEBRT,LOGIC,RUNTIME"

# --- native doc exclusion (bd-55f7a) stays fixed ---
run_case "native README only (bd-55f7a)"        'ios/App/fastlane/README.md'                  '' '0,0,0,0,0'
run_case "real native code"                     'ios/App/AppDelegate.swift'                   '' '1,0,0,0,1'
run_case "MIXED native code + native doc"       'ios/App/AppDelegate.swift
ios/App/fastlane/README.md'                                                                   '' '1,0,0,0,1'
run_case "capacitor.config.ts"                  'capacitor.config.ts'                         '' '1,0,0,0,1'
run_case "package.json capacitor dep bump"      'package.json'          '+    "@capacitor/core": "6.0.0"' '1,0,0,0,1'

# --- PROOF1: the ONE deliberate opt-out — markdown that IS visual surface ---
run_case "PROOF1 design.md alone -> WEBUI"      'design.md'                                   '' '0,1,0,0,0'
run_case "PROOF1 CORE/design.md (nested)"       '.claude/skills/CORE/design.md'               '' '0,1,0,0,0'
run_case "PROOF1 docs/design.md (excluded dir)" 'docs/design.md'                              '' '0,1,0,0,0'
run_case "globals.css alone -> WEBUI"           'src/app/globals.css'                         '' '0,1,0,0,1'

# --- PROOF3: docs-only no longer selects LOGIC / WEBRT (bd-mdbhr) ---
run_case "PROOF3 supabase/README.md -> LOGIC=0" 'supabase/README.md'                          '' '0,0,0,0,0'
run_case "PROOF3 hooks/README.md -> WEBRT=0"    'src/hooks/README.md'                         '' '0,0,0,0,0'
run_case "lib/ doc only"                        'lib/README.md'                               '' '0,0,0,0,0'

# --- PROOF2: a doc must NEVER mask real code (fail-safe) ---
run_case "PROOF2 MIXED supabase doc + .sql"     'supabase/README.md
supabase/migrations/20260101_x.sql'                                                           '' '0,0,0,1,1'
run_case "PROOF2 MIXED lib doc + lib code"      'lib/README.md
lib/format.ts'                                                                                '' '0,0,0,1,1'
run_case "PROOF2 MIXED hooks doc + hook code"   'src/hooks/README.md
src/hooks/useThing.ts'                                                                        '' '0,0,1,0,1'
run_case "lib/api/client.ts (WEBRT+LOGIC)"      'lib/api/client.ts'                           '' '0,0,1,1,1'

# --- other exclusions unchanged / tightened ---
run_case "beads ledger only"                    '.beads/issues.jsonl'                         '' '0,0,0,0,0'
run_case "test-only tsx (WEBUI=0)"              'src/components/Foo.test.tsx'                 '' '0,0,0,0,0'
run_case "real component tsx"                   'src/components/Foo.tsx'                      '' '0,1,0,0,1'

echo "---"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
