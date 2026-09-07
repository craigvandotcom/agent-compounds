#!/usr/bin/env bash
# parity.sh — run the LEGACY bash check and its PORTED v2 check over the same
# tree and over a fixture, and diff verdicts. A non-empty diff blocks the port
# (ac-1p7j.2). Usage: parity.sh <NN>
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

  fails=0
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

  echo
  if [ "$fails" -eq 0 ]; then echo "parity: legacy and ported verdicts agree."; exit 0; fi
  echo "parity: $fails verdict diff(es) — the port is NOT proven." >&2
  exit 1

elif [ "$CHECK_ID" = 20 ] || [ "$CHECK_ID" = 21 ] || [ "$CHECK_ID" = 22 ] || [ "$CHECK_ID" = 23 ]; then
  # --- generic recipe for the DELEGATING checks --------------------------------
  # Checks 20-23 were thin lint.sh wrappers around a judge script under
  # scripts/; the ports wrap the SAME judge. Parity therefore runs the legacy
  # block (live extraction from lint.sh, falling back to the last commit that
  # carried it once the block is deleted) and the port over the SAME audited
  # tree and compares: (a) the verdict — legacy fail-count > 0 vs the port's
  # exit code, where exit 2 counts as a diff because NOT-GATED is not a pass;
  # (b) the judge's own violation lines, with each side's wrapper header
  # stripped — the prose around the verdict may differ, the flagged set may not.
  ID=""
  case "$CHECK_ID" in
    20) ID="20-harness-scheduling" ;;
    21) ID="21-assurance-declarations" ;;
    22) ID="22-ledger-integrity" ;;
    23) ID="23-family-budget" ;;
  esac
  NEW="$ROOT/lint/checks/$ID.py"
  [ -f "$NEW" ] || { echo "NOT-CHECKED: $NEW missing — nothing ported to compare" >&2; exit 2; }

  legacy_block() { # <NN> -> block text on stdout, rc 1 if nowhere to be found
    local nn="$1" sha
    if [ -f "$ROOT/lint.sh" ] && grep -q "^# Check $nn — " "$ROOT/lint.sh" 2>/dev/null; then
      awk -v n="$nn" '
        index($0, "# Check " n " — ") == 1 {f=1; next}
        f && /^# Check [0-9]+ — / {exit}
        f {print}' "$ROOT/lint.sh"
      return 0
    fi
    for sha in $(git -C "$ROOT" rev-list HEAD -- lint.sh); do
      if git -C "$ROOT" show "$sha:lint.sh" 2>/dev/null | grep -q "^# Check $nn — "; then
        git -C "$ROOT" show "$sha:lint.sh" | awk -v n="$nn" '
          index($0, "# Check " n " — ") == 1 {f=1; next}
          f && /^# Check [0-9]+ — / {exit}
          f {print}'
        return 0
      fi
    done
    return 1
  }

  run_legacy() { # <NN> <audited-root> -> LEGACY_OUT (with WRAPFAIL markers), LEGACY_FAILS
    local nn="$1" tree="$2" block
    block="$(legacy_block "$nn")" || { echo "NOT-CHECKED: no legacy Check-$nn block in lint.sh or its history — verified nothing" >&2; exit 2; }
    [ -n "$(printf '%s' "$block" | tr -d '[:space:]')" ] || { echo "NOT-CHECKED: legacy Check-$nn extraction is empty — verified nothing" >&2; exit 2; }
    LEGACY_OUT="$(
      AC_ROOT="$tree"
      check() { :; }
      fail() { printf 'WRAPFAIL: %s\n' "$*"; LEGACY_FAILS=$(( LEGACY_FAILS + 1 )); }
      LEGACY_FAILS=0
      eval "$block"
      printf 'LEGACY_FAILS=%s\n' "$LEGACY_FAILS"
    )"
    LEGACY_FAILS="$(printf '%s\n' "$LEGACY_OUT" | sed -n 's/^LEGACY_FAILS=//p')"
    LEGACY_OUT="$(printf '%s\n' "$LEGACY_OUT" | grep -v '^LEGACY_FAILS=' || true)"
  }

  violations() { # <out> <wrapper-header-regex> -> sorted judge violation lines
    printf '%s\n' "$1" | grep '^FAIL: ' | grep -Ev "$2" | LC_ALL=C sort
  }

  compare_leg() { # <name> <audited-root> <wrapper-header-regex>
    local name="$1" tree="$2" wraprx="$3" new_v old_v new_rc out
    run_legacy "$CHECK_ID" "$tree"
    out="$(python3 "$NEW" "$tree" 2>&1)"; new_rc=$?
    old_v="$(violations "$LEGACY_OUT" "$wraprx")"
    new_v="$(violations "$out" "^FAIL $ID: ")"
    local legacy_red=0 new_red=0
    [ "$LEGACY_FAILS" -gt 0 ] && legacy_red=1
    [ "$new_rc" -eq 1 ] && new_red=1
    if [ "$legacy_red" != "$new_red" ] || [ "$new_rc" = 2 ]; then
      echo "  FAIL  $name — verdict diff (legacy fails=$LEGACY_FAILS, port exit=$new_rc)"
      fails=$((fails + 1))
      return
    fi
    if [ "$old_v" = "$new_v" ]; then
      echo "  ok    $name — verdicts match ($(printf '%s' "$old_v" | grep -c . || true) violation(s))"
    else
      echo "  FAIL  $name — violation diff:"
      diff <(printf '%s\n' "$old_v") <(printf '%s\n' "$new_v") | sed 's/^/      /'
      fails=$((fails + 1))
    fi
  }

  build_red_tree() { # <W> — the RED state each delegating judge must flag
    local w="$1"
    mkdir -p "$w/scripts"
    case "$CHECK_ID" in
      20)
        mkdir -p "$w/.github/workflows" "$w/lint/checks"
        cp "$ROOT/scripts/harness-scheduling-check.sh" "$ROOT/scripts/run-all-harnesses.sh" "$w/scripts/"
        chmod +x "$w/scripts/"*.sh
        printf '#!/usr/bin/env bash\n# demo proof harness\nexit 0\n' > "$w/lint/checks/demo.test.sh"
        printf 'name: ci\non: [push]\njobs:\n  t:\n    runs-on: ubuntu-latest\n    steps:\n      - run: echo hi\n' > "$w/.github/workflows/ci.yml"
        ;;
      21)
        mkdir -p "$w/hooks"
        cp "$ROOT/scripts/assurance-declarations-check.sh" "$w/scripts/"
        chmod +x "$w/scripts/"*.sh
        printf '{"wiring":[{"id":"demo","command":"echo hi"}]}\n' > "$w/hooks/hooks.json"
        ;;
      22)
        mkdir -p "$w/skills/skill-builder/scripts" "$w/skills/ac-pipeline"
        cp "$ROOT/skills/skill-builder/scripts/friction-rollup.py" "$w/skills/skill-builder/scripts/"
        cp "$ROOT/skills/ac-pipeline/SKILL.md" "$w/skills/ac-pipeline/"
        cp "$ROOT/scripts/ac-ledger-integrity.sh" "$w/scripts/"
        chmod +x "$w/scripts/"*.sh
        { printf -- '---\nskill: ac-pipeline\ncreated: 2026-09-07\nlast_pass: never\nentries: 1\n---\n\n# fixture ledger\n\n## fixture-friction\n'
          printf -- '- skills: [ac-pipeline]\n- impact: M\n- frequency: every-run\n- perceptibility: silent\n- recurrence: 3\n'
          printf -- '- first_seen: 2026-09-01\n- last_seen: 2026-09-05\n- status: open\n- receipt: nowhere (fixture)\n'
        } > "$w/skills/ac-pipeline/FRICTIONS.md"
        ;;
      23)
        mkdir -p "$w/skills/ac-plan"
        cp "$ROOT/scripts/ac-budget-check.sh" "$w/scripts/"
        chmod +x "$w/scripts/"*.sh
        { printf '# ac-plan\n\nUses skills/ac-plan/references/deep.md.\n'
          for i in $(seq 1 810); do printf 'filler line %d\n' "$i"; done
        } > "$w/skills/ac-plan/SKILL.md"
        ;;
    esac
  }

  fails=0
  W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
  case "$CHECK_ID" in
    20) compare_leg "registry tree" "$ROOT" "^FAIL: Check $CHECK_ID: " ;;
    21) compare_leg "registry tree" "$ROOT" "^FAIL: Check $CHECK_ID: " ;;
    22) compare_leg "registry tree" "$ROOT" "^FAIL: Check $CHECK_ID: " ;;
    23) compare_leg "registry tree" "$ROOT" "^FAIL: Check $CHECK_ID: " ;;
  esac
  build_red_tree "$W/tree"
  compare_leg "fixture RED tree" "$W/tree" "^FAIL: Check $CHECK_ID: "

  echo
  if [ "$fails" -eq 0 ]; then echo "parity: legacy and ported verdicts agree."; exit 0; fi
  echo "parity: $fails verdict diff(es) — the port is NOT proven." >&2
  exit 1

else
  echo "NOT-CHECKED: no parity recipe for check '$CHECK_ID'" >&2
  exit 2
fi
