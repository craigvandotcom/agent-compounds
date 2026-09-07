#!/usr/bin/env bash
# parity.sh — run the LEGACY bash check and its PORTED v2 check over the same
# tree and diff verdicts. A non-empty diff blocks the port (ac-1p7j.2).
# Usage: parity.sh <NN>
#
# Parity is judged on the VIOLATION SETS, never on the prose around them: the
# two implementations may differ in notices, never in what they flag. The
# legacy side is the live extraction from lint.sh while the block still exists;
# once the port removes it, the extraction falls to the last git-history commit
# that carried it, so the harness keeps comparing against the REAL legacy judge
# — it never embeds a copy that could drift.
#
# Assurance
#   PROBE:    bash lint/parity.sh 14 (self-hosted; run manually at each port)
#   SCHEDULE: port-time gate for every Check port (not scheduled per-commit)
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK_ID="${1:-}"
[ -n "$CHECK_ID" ] || { echo "usage: parity.sh <check-id, e.g. 14>" >&2; exit 2; }

echo "== parity for check $CHECK_ID"
fails=0

# --- shared helpers for the block-extraction recipes ---------------------------
# extract_block <N> — the Check-N bash block, from the LIVE lint.sh while the
# block still exists, else from the last commit that carried it. Reads to EOF
# (never `grep -q`: an early exit SIGPIPEs awk and pipefail turns that into a
# false "block absent").
extract_block() {
  local n="$1" sha block
  block="$(awk -v n="$n" '
    index($0, "# Check " n " —") == 1 { f = 1 }
    f && seen && /^# Check [0-9]+ —/ { exit }
    f { seen = 1; print }' "$ROOT/lint.sh" 2>/dev/null)"
  if [ -n "$block" ]; then
    printf '%s\n' "$block"
    return 0
  fi
  for sha in $(git -C "$ROOT" rev-list HEAD -- lint.sh); do
    block="$(git -C "$ROOT" show "$sha:lint.sh" 2>/dev/null | awk -v n="$n" '
      index($0, "# Check " n " —") == 1 { f = 1 }
      f && seen && /^# Check [0-9]+ —/ { exit }
      f { seen = 1; print }')"
    if [ -n "$block" ]; then
      printf '%s\n' "$block"
      echo "-- legacy judge source: git history $sha (block removed by the port)" >&2
      return 0
    fi
  done
  return 1
}

# run_legacy <N> [root] — execute the extracted block with check/fail stubs and
# print its FAIL lines. The stubs are the block's own verdict channel: every
# legacy violation reaches the set through fail().
run_legacy() {
  local n="$1" root="${2:-$ROOT}" block
  block="$(extract_block "$n")" || { echo "NOT-CHECKED: no legacy Check-$n block in lint.sh or its history" >&2; return 2; }
  AC_ROOT="$root" bash -c '
    fail() { echo "FAIL: $*"; }
    check() { :; }
    eval "$1"
  ' _ "$block" 2>/dev/null | grep '^FAIL: ' || true
}

# compare_sets <name> <legacy-fails> <new-fails> <legacy-strip> <new-strip>
compare_sets() {
  local name="$1" a b
  a="$(printf '%s\n' "$2" | sed -E "$4" | sort)"
  b="$(printf '%s\n' "$3" | sed -E "$5" | sort)"
  if [ "$a" = "$b" ]; then
    echo "  ok    $name — verdicts match ($(printf '%s' "$a" | grep -c . || true) violation(s))"
  else
    echo "  FAIL  $name — verdict diff:"
    diff <(printf '%s\n' "$a") <(printf '%s\n' "$b") | sed 's/^/      /'
    fails=$((fails + 1))
  fi
}

finish() {
  if [ "$fails" -eq 0 ]; then echo "parity: legacy and ported verdicts agree."; exit 0; fi
  echo "parity: $fails verdict diff(es) — the port is NOT proven." >&2
  exit 1
}

# --- legacy side -------------------------------------------------------------
if [ "$CHECK_ID" = 14 ]; then
  LINT="$ROOT/lint.sh"
  if grep -q '^NNG_VIOLATIONS=()' "$LINT" 2>/dev/null; then
    FUNCS="$(awk '/^NNG_VIOLATIONS=\(\)/{f=1} f&&/^check$/{exit} f' "$LINT")"
    SRC="lint.sh (live block)"
  else
    LEGACY_SHA=""
    for sha in $(git -C "$ROOT" rev-list HEAD -- lint.sh); do
      if git -C "$ROOT" show "$sha:lint.sh" 2>/dev/null | grep -q '^NNG_VIOLATIONS=()'; then
        LEGACY_SHA="$sha"; break
      fi
    done
    if [ -z "$LEGACY_SHA" ]; then
      echo "NOT-CHECKED: no legacy Check-14 judge found in lint.sh or its history — verified nothing" >&2
      exit 2
    fi
    FUNCS="$(git -C "$ROOT" show "$LEGACY_SHA:lint.sh" | awk '/^NNG_VIOLATIONS=\(\)/{f=1} f&&/^check$/{exit} f')"
    SRC="git history $LEGACY_SHA (block removed by the port)"
  fi
  [ -n "$FUNCS" ] || { echo "NOT-CHECKED: could not extract the legacy functions" >&2; exit 2; }
  eval "$FUNCS"
  type nng_scan >/dev/null 2>&1 || { echo "NOT-CHECKED: nng_scan not defined after extraction" >&2; exit 2; }
  echo "-- legacy judge source: $SRC"

  NEW="$ROOT/lint/checks/14-no-net-growth.py"
  [ -f "$NEW" ] || { echo "NOT-CHECKED: $NEW missing — nothing ported to compare" >&2; exit 2; }

  compare() { # <name> <legacy-violations> <new-violations>
    local name="$1" a="$2" b="$3"
    if [ "$a" = "$b" ]; then echo "  ok    $name — verdicts match ($(printf '%s' "$a" | grep -c . || true) violation(s))"
    else
      echo "  FAIL  $name — verdict diff:"
      diff <(printf '%s\n' "$a") <(printf '%s\n' "$b") | sed 's/^/      /'
      fails=$((fails + 1))
    fi
  }

  # --- (a) the registry working tree, leg 1's base, leg 1's spec --------------
  base="$(NNG_BASE_REF=origin/main nng_leg1_base "$ROOT")"
  if [ -n "$base" ]; then
    NNG_VIOLATIONS=()
    nng_scan "$ROOT" agent-compounds "$base" 'skills/*/SKILL.md' >/dev/null 2>&1
    old_a="$(printf '%s\n' "${NNG_VIOLATIONS[@]:-}" | sort)"
    new_a="$(python3 "$NEW" --scan "$ROOT" agent-compounds "$base" 'skills/*/SKILL.md' 2>/dev/null | grep '^FAIL ' | sed 's/^FAIL 14-no-net-growth: net-positive SKILL.md file(s): //' | tr ',' '\n' | sed 's/^ *//;s/ *$//' | sort)"
    compare "registry tree (leg 1)" "$old_a" "$new_a"
  else
    echo "  SKIP  registry tree — legacy leg-1 base unresolvable (both sides degrade the same)"
  fi

  # --- (b) the fixture repo: growth, creation, family rules, shrink -----------
  W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
  git init -q --bare "$W/origin.git" -b master
  git clone -q "$W/origin.git" "$W/app" 2>/dev/null
  cd "$W/app" || exit 2
  git config user.email t@t.t; git config user.name t
  mkdir -p .claude/skills/foo .claude/skills/ac-plan
  for i in 1 2 3 4 5; do echo "line $i"; done > .claude/skills/foo/SKILL.md
  seq 1 10 | sed 's/^/line /' > .claude/skills/ac-plan/SKILL.md
  git add -A; git commit -qm base; git push -q origin master 2>/dev/null
  git remote set-head origin master

  run_both() { # <name> — snapshot the current repo state through both judges
    base="$(python3 "$NEW" --base-of "$W/app")"
    NNG_VIOLATIONS=()
    nng_scan "$W/app" app "$base" '.claude/skills/*/SKILL.md' >/dev/null 2>&1
    old_v="$(printf '%s\n' "${NNG_VIOLATIONS[@]:-}" | sort)"
    new_v="$(python3 "$NEW" --scan "$W/app" app "$base" '.claude/skills/*/SKILL.md' 2>/dev/null | grep '^FAIL ' | sed 's/^FAIL 14-no-net-growth: net-positive SKILL.md file(s): //' | tr ',' '\n' | sed 's/^ *//;s/ *$//' | sort)"
    compare "$1" "$old_v" "$new_v"
  }

  run_both "fixture: clean baseline"
  echo "line 6" >> .claude/skills/foo/SKILL.md; echo "line 7" >> .claude/skills/foo/SKILL.md
  run_both "fixture: +2 growth of an existing file"
  git checkout -q -- .claude/skills/foo/SKILL.md
  mkdir -p .claude/skills/other
  seq 1 20 | sed 's/^/line /' > .claude/skills/other/SKILL.md
  git add .claude/skills/other/SKILL.md
  run_both "fixture: created non-family SKILL.md (staged, uncommitted)"
  git commit -qm "create other"; git push -q origin master 2>/dev/null
  mkdir -p .claude/skills/ac-polish
  seq 1 50 | sed 's/^/line /' > .claude/skills/ac-polish/SKILL.md
  git add .claude/skills/ac-polish/SKILL.md
  run_both "fixture: family creation within cap (staged)"
  git reset -q .claude/skills/ac-polish/SKILL.md 2>/dev/null; rm -rf .claude/skills/ac-polish
  seq 1 90 | sed 's/^/line /' > .claude/skills/ac-plan/SKILL.md
  run_both "fixture: family growth (never deferred)"
  git checkout -q -- .claude/skills/ac-plan/SKILL.md 2>/dev/null
  seq 1 700 | sed 's/^/line /' > .claude/skills/ac-plan/SKILL.md
  run_both "fixture: family growth, larger (never deferred)"
  git checkout -q -- .claude/skills/ac-plan/SKILL.md 2>/dev/null
  seq 1 3 | sed 's/^/line /' > .claude/skills/foo/SKILL.md
  run_both "fixture: shrink"

  finish
elif [ "$CHECK_ID" = 8 ] || [ "$CHECK_ID" = 12 ]; then
  # --- recipes for Checks 8 and 12 (ac-1p7j.14, ported from inline blocks) -----
  # Both legacy blocks are inline (not functions like Check 14), extracted
  # between their section markers. The 12-block consumes CONSUMER_DIRS, which
  # the legacy Check 7 block built — so for 12 BOTH are eval'd in one shell.
  # Both judges run over the REAL consumer union ($HOME/Repos; the test-only
  # LINT_CONSUMER_BASE seam is unset on both sides). Each judge mktemps its own
  # dry-run dir, so the volatile tmp path is normalized before the sets are
  # compared — the verdict (what fired), not the prose, is what must match.
  TMPNORM='s/\(tmp: [^)]*\)/(tmp: TMP)/'
  case "$CHECK_ID" in
    8)  NEW="$ROOT/lint/checks/08-deploy-dry-run-inert.py"
        LSTRIP="s/^FAIL: //; $TMPNORM"; NSTRIP="s/^FAIL 08-deploy-dry-run-inert: //; $TMPNORM"
        old="$(run_legacy 8)" ;;
    12) NEW="$ROOT/lint/checks/12-deployed-app-conformance.py"
        LSTRIP="s/^FAIL: //"; NSTRIP="s/^FAIL 12-deployed-app-conformance: //"
        d7="$(extract_block 7)" || { echo "NOT-CHECKED: no legacy Check-7 block (CONSUMER_DIRS) in lint.sh or its history" >&2; exit 2; }
        d12="$(extract_block 12)" || exit 2
        old="$(AC_ROOT="$ROOT" bash -c '
          check() { :; }
          fail() { :; }   # the 7-block also SCANS for broken symlinks — that verdict is Check 7'"'"'s, never 12'"'"'s; only its CONSUMER_DIRS computation is consumed here
          eval "$1"
          fail() { echo "FAIL: $*"; }
          eval "$2"
        ' _ "$d7" "$d12" 2>/dev/null | grep '^FAIL: ' || true)" ;;
  esac
  [ -f "$NEW" ] || { echo "NOT-CHECKED: $NEW missing — nothing ported to compare" >&2; exit 2; }
  new="$(python3 "$NEW" "$ROOT" 2>/dev/null | grep '^FAIL ' || true)"
  compare_sets "registry tree" "$old" "$new" "$LSTRIP" "$NSTRIP"
  finish

elif [ "$CHECK_ID" = 7 ]; then
  # --- recipe for Check 7 (consumer symlink health, ac-1p7j.14) ---------------
  # Legacy block extracted between its section markers (live lint.sh, else the
  # last commit that carried it) and eval'd with check/fail shims. Both judges
  # walk the REAL consumer union (the test-only LINT_CONSUMER_BASE seam unset
  # on both sides), so a dir that exists only on this machine is scanned by
  # both or by neither.
  NEW="$ROOT/lint/checks/07-consumer-symlinks.py"
  [ -f "$NEW" ] || { echo "NOT-CHECKED: $NEW missing — nothing ported to compare" >&2; exit 2; }
  old="$(run_legacy 7)"
  new="$(python3 "$NEW" "$ROOT" 2>/dev/null | grep '^FAIL ' || true)"
  compare_sets "registry tree" "$old" "$new" 's/^FAIL: //' 's/^FAIL 07-consumer-symlinks: //'
  finish

elif [ "$CHECK_ID" = 10 ] || [ "$CHECK_ID" = 11 ]; then
  case "$CHECK_ID" in
    10) NEW="$ROOT/lint/checks/10-d-series-conformance.py"; LSTRIP='s/^FAIL: //'; NSTRIP='s/^FAIL 10-d-series-conformance: //' ;;
    11) NEW="$ROOT/lint/checks/11-g-series-conformance.py";  LSTRIP='s/^FAIL: //'; NSTRIP='s/^FAIL 11-g-series-conformance: //' ;;
  esac
  [ -f "$NEW" ] || { echo "NOT-CHECKED: $NEW missing — nothing ported to compare" >&2; exit 2; }
  old="$(run_legacy "$CHECK_ID")" || exit 2
  new="$(python3 "$NEW" "$ROOT" 2>/dev/null | grep '^FAIL ' || true)"
  compare_sets "registry tree (doctrine landings)" "$old" "$new" "$LSTRIP" "$NSTRIP"
  finish
elif [ "$CHECK_ID" = 15 ]; then
  NEW="$ROOT/lint/checks/15-line-ceilings.py"
  [ -f "$NEW" ] || { echo "NOT-CHECKED: $NEW missing — nothing ported to compare" >&2; exit 2; }
  old="$(run_legacy 15)" || exit 2
  new="$(python3 "$NEW" "$ROOT" 2>/dev/null | grep '^FAIL ' || true)"
  compare_sets "registry tree (ceilings + ratchet)" "$old" "$new" \
    's/^FAIL: Check 15: //' 's/^FAIL 15-line-ceilings: //'
  finish
else
  echo "NOT-CHECKED: no parity recipe for check '$CHECK_ID'" >&2
  exit 2
fi
