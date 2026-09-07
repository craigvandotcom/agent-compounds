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

# legacy_full <N> [root] — the same execution, FULL stdout (no FAIL filter), for
# recipes that also compare a population/accounting line.
legacy_full() {
  local n="$1" root="${2:-$ROOT}" block
  block="$(extract_block "$n")" || { echo "NOT-CHECKED: no legacy Check-$n block in lint.sh or its history" >&2; return 2; }
  AC_ROOT="$root" bash -c '
    fail() { echo "FAIL: $*"; }
    check() { :; }
    eval "$1"
  ' _ "$block" 2>/dev/null || true
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
elif [ "$CHECK_ID" = 16 ]; then
  NEW="$ROOT/lint/checks/16-mirror-fidelity.py"
  [ -f "$NEW" ] || { echo "NOT-CHECKED: $NEW missing — nothing ported to compare" >&2; exit 2; }
  old="$(run_legacy 16)" || exit 2
  new="$(python3 "$NEW" "$ROOT" 2>/dev/null | grep '^FAIL ' || true)"
  compare_sets "registry tree (mirror fidelity, violations)" "$old" "$new" \
    's/^FAIL: Check 16: //' 's/^FAIL 16-mirror-fidelity: //'
  # the marker accounting is the check's population assertion — the two judges
  # must have walked the same corpus, not merely flagged the same failures
  old_acc="$(legacy_full 16 | grep -o 'mirror markers: .*' || true)"
  new_acc="$(printf '%s\n' "$(python3 "$NEW" "$ROOT" 2>/dev/null)" | grep -o 'mirror markers: .*' || true)"
  if [ "$old_acc" = "$new_acc" ] && [ -n "$old_acc" ]; then
    echo "  ok    registry tree (mirror fidelity, accounting) — $old_acc"
  else
    echo "  FAIL  registry tree (mirror fidelity, accounting) — legacy: [$old_acc] ported: [$new_acc]"
    fails=$((fails + 1))
  fi
  finish
elif [ "$CHECK_ID" = 18 ]; then
  NEW="$ROOT/lint/checks/18-guard-liveness.py"
  [ -f "$NEW" ] || { echo "NOT-CHECKED: $NEW missing — nothing ported to compare" >&2; exit 2; }
  LSTRIP='s/^FAIL: Check 18: //'; NSTRIP='s/^FAIL 18-guard-liveness: //'
  old="$(run_legacy 18)" || exit 2
  new="$(python3 "$NEW" "$ROOT" 2>/dev/null | grep '^FAIL ' || true)"
  compare_sets "registry hooks (live)" "$old" "$new" "$LSTRIP" "$NSTRIP"
  # a doctored tree: a real hooks/ copy with bead-capture-guard chmod-x'd —
  # both judges must fail on the same two legs (executable check + gate leg)
  W="$(mktemp -d)"
  cp -R "$ROOT/hooks" "$W/hooks"
  chmod -x "$W/hooks/bead-capture-guard.py"
  old="$(run_legacy 18 "$W")"
  new="$(python3 "$NEW" "$W" 2>/dev/null | grep '^FAIL ' || true)"
  compare_sets "doctored hooks (dead bead-capture-guard)" "$old" "$new" "$LSTRIP" "$NSTRIP"
  rm -rf "$W"
  finish
elif [ "$CHECK_ID" = 19 ]; then
  NEW="$ROOT/lint/checks/19-bead-template-conformance.py"
  [ -f "$NEW" ] || { echo "NOT-CHECKED: $NEW missing — nothing ported to compare" >&2; exit 2; }
  LSTRIP='s/^FAIL: Check 19: //'; NSTRIP='s/^FAIL 19-bead-template-conformance: //'
  old="$(run_legacy 19)" || exit 2
  new="$(python3 "$NEW" "$ROOT" 2>/dev/null | grep '^FAIL ' || true)"
  compare_sets "registry templates (live)" "$old" "$new" "$LSTRIP" "$NSTRIP"
  # doctored tree: no scripts/ — both judges must fail on the missing judge,
  # never read a missing lint script as a clean sweep
  W="$(mktemp -d)"
  old="$(run_legacy 19 "$W")"
  new="$(python3 "$NEW" "$W" 2>/dev/null | grep '^FAIL ' || true)"
  compare_sets "missing-script fixture" "$old" "$new" "$LSTRIP" "$NSTRIP"
  rm -rf "$W"
  finish
elif [ "$CHECK_ID" = 20 ] || [ "$CHECK_ID" = 21 ] || [ "$CHECK_ID" = 22 ] || [ "$CHECK_ID" = 23 ]; then
  # --- recipes for the DELEGATING checks 20-23 (ac-1p7j.16) --------------------
  # Each legacy block was a thin lint.sh wrapper around a judge script under
  # scripts/; the port wraps the SAME judge. Parity runs the legacy block
  # (live lint.sh, else git history) and the port over the SAME audited tree
  # — the registry, then a built RED tree — and compares (a) the verdict,
  # where the port's exit 2 counts as a diff because NOT-GATED is not a pass,
  # and (b) the judge's own violation lines, with each side's wrapper header
  # stripped — the prose around the verdict may differ, the flagged set may not.
  case "$CHECK_ID" in
    20) NEW="$ROOT/lint/checks/20-harness-scheduling.py" ;;
    21) NEW="$ROOT/lint/checks/21-assurance-declarations.py" ;;
    22) NEW="$ROOT/lint/checks/22-ledger-integrity.py" ;;
    23) NEW="$ROOT/lint/checks/23-family-budget.py" ;;
  esac
  [ -f "$NEW" ] || { echo "NOT-CHECKED: $NEW missing — nothing ported to compare" >&2; exit 2; }
  JUDGE_ID="$(basename "$NEW" .py)"

  compare_delegating() { # <name> <tree>
    local name="$1" tree="$2" old new new_rc lr nr
    old="$(run_legacy "$CHECK_ID" "$tree")"
    new="$(python3 "$NEW" "$tree" 2>/dev/null)"; new_rc=$?
    # the judge's own lines (FAIL: ...) and the port's header (FAIL <id>: ...)
    # are both part of what the port prints — capture both shapes
    new="$(printf '%s\n' "$new" | grep -E '^FAIL[ :]' || true)"
    lr=0; nr=0
    printf '%s' "$old" | grep -q . && lr=1
    [ "$new_rc" -eq 1 ] && nr=1
    if [ "$lr" != "$nr" ] || [ "$new_rc" -eq 2 ]; then
      echo "  FAIL  $name — verdict diff (legacy fail line(s): $(printf '%s' "$old" | grep -c . || true), port exit=$new_rc)"
      fails=$((fails + 1))
      return
    fi
    compare_sets "$name" "$old" "$new" "s/^FAIL: Check $CHECK_ID: //" "s/^FAIL $JUDGE_ID: //"
  }

  # the RED state each delegating judge must flag, built fresh per leg
  build_red_tree() { # <W>
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
          printf -- '- first_seen: 2026-09-01\n- last_seen: 2026-09-02\n- status: open\n- receipt: nowhere (fixture)\n'
          printf -- '- control: I99\n- control_landed: 2026-08-01\n'
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

  compare_delegating "registry tree" "$ROOT"
  W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
  build_red_tree "$W/tree"
  compare_delegating "fixture RED tree" "$W/tree"
  finish

elif [ "$CHECK_ID" = 3 ] || [ "$CHECK_ID" = 4 ] || [ "$CHECK_ID" = 5 ] || [ "$CHECK_ID" = 9 ] || [ "$CHECK_ID" = 24 ]; then
  # --- recipes for Checks 3, 4, 5, 9 and 24 (ac-1p7j.13) -----------------------
  # Tree-walking blocks: registry tree, then each check's committed static
  # fixture. The strip patterns reduce both sides' wrapper headers so the
  # comparison is on the violation text.
  case "$CHECK_ID" in
    3)  NEW="$ROOT/lint/checks/03-frontmatter-conformance.py";  FX="03-frontmatter-conformance";  LSTRIP='s/^FAIL: //' ;;
    4)  NEW="$ROOT/lint/checks/04-readme-disk.py";              FX="04-readme-disk";              LSTRIP='s/^FAIL: //' ;;
    5)  NEW="$ROOT/lint/checks/05-agents-diagram.py";           FX="05-agents-diagram";           LSTRIP='s/^FAIL: //' ;;
    9)  NEW="$ROOT/lint/checks/09-stray-alias-agents.py";       FX="09-stray-alias-agents";       LSTRIP='s/^FAIL: //' ;;
    24) NEW="$ROOT/lint/checks/24-description-length.py";       FX="24-description-length";       LSTRIP='s/^FAIL: Check 24: //' ;;
  esac
  [ -f "$NEW" ] || { echo "NOT-CHECKED: $NEW missing — nothing ported to compare" >&2; exit 2; }
  JUDGE_ID="$(basename "$NEW" .py)"
  NSTRIP="s/^FAIL $JUDGE_ID: //"

  old="$(run_legacy "$CHECK_ID")" || exit 2
  new="$(python3 "$NEW" "$ROOT" 2>/dev/null | grep '^FAIL ' || true)"
  compare_sets "registry tree" "$old" "$new" "$LSTRIP" "$NSTRIP"

  old="$(run_legacy "$CHECK_ID" "$ROOT/lint/fixtures/$FX")" || exit 2
  new="$(python3 "$NEW" "$ROOT/lint/fixtures/$FX" 2>/dev/null | grep '^FAIL ' || true)"
  compare_sets "fixture tree" "$old" "$new" "$LSTRIP" "$NSTRIP"
  finish

elif [ "$CHECK_ID" = 1 ]; then
  # --- recipe for Check 1 (dead patterns, ac-1p7j.12) ---------------------------
  # Simple tree-walking block: registry tree, then the committed static fixture.
  NEW="$ROOT/lint/checks/1-dead-patterns.py"
  [ -f "$NEW" ] || { echo "NOT-CHECKED: $NEW missing — nothing ported to compare" >&2; exit 2; }
  LSTRIP='s/^FAIL: //'; NSTRIP="s/^FAIL $(basename "$NEW" .py): //"

  old="$(run_legacy 1)" || exit 2
  new="$(python3 "$NEW" "$ROOT" 2>/dev/null | grep '^FAIL ' || true)"
  compare_sets "registry tree" "$old" "$new" "$LSTRIP" "$NSTRIP"

  old="$(run_legacy 1 "$ROOT/lint/fixtures/1-dead-patterns")" || exit 2
  new="$(python3 "$NEW" "$ROOT/lint/fixtures/1-dead-patterns" 2>/dev/null | grep '^FAIL ' || true)"
  compare_sets "fixture tree" "$old" "$new" "$LSTRIP" "$NSTRIP"
  finish

elif [ "$CHECK_ID" = 2 ]; then
  # --- recipe for Check 2 (/ac-* cross-references, ac-1p7j.12) ------------------
  # Regex-extraction block: registry tree, then the committed static fixture.
  NEW="$ROOT/lint/checks/2-ac-cross-references.py"
  [ -f "$NEW" ] || { echo "NOT-CHECKED: $NEW missing — nothing ported to compare" >&2; exit 2; }
  LSTRIP='s/^FAIL: //'; NSTRIP="s/^FAIL $(basename "$NEW" .py): //"

  old="$(run_legacy 2)" || exit 2
  new="$(python3 "$NEW" "$ROOT" 2>/dev/null | grep '^FAIL ' || true)"
  compare_sets "registry tree" "$old" "$new" "$LSTRIP" "$NSTRIP"

  old="$(run_legacy 2 "$ROOT/lint/fixtures/2-ac-cross-references")" || exit 2
  new="$(python3 "$NEW" "$ROOT/lint/fixtures/2-ac-cross-references" 2>/dev/null | grep '^FAIL ' || true)"
  compare_sets "fixture tree" "$old" "$new" "$LSTRIP" "$NSTRIP"
  finish

elif [ "$CHECK_ID" = 6 ]; then
  # --- recipe for Check 6 (portability, ac-1p7j.12) -----------------------------
  # Simple tree-walking block: registry tree, then the committed static fixture.
  NEW="$ROOT/lint/checks/6-portability.py"
  [ -f "$NEW" ] || { echo "NOT-CHECKED: $NEW missing — nothing ported to compare" >&2; exit 2; }
  LSTRIP='s/^FAIL: //'; NSTRIP="s/^FAIL $(basename "$NEW" .py): //"

  old="$(run_legacy 6)" || exit 2
  new="$(python3 "$NEW" "$ROOT" 2>/dev/null | grep '^FAIL ' || true)"
  compare_sets "registry tree" "$old" "$new" "$LSTRIP" "$NSTRIP"

  old="$(run_legacy 6 "$ROOT/lint/fixtures/6-portability")" || exit 2
  new="$(python3 "$NEW" "$ROOT/lint/fixtures/6-portability" 2>/dev/null | grep '^FAIL ' || true)"
  compare_sets "fixture tree" "$old" "$new" "$LSTRIP" "$NSTRIP"
  finish

elif [ "$CHECK_ID" = 13 ]; then
  # --- recipe for Check 13 (ac-1p7j.13) ----------------------------------------
  # Delegating block (validate-skill.sh --registry): registry tree, then a
  # built RED tree (the judge copied in beside an over-cap description).
  NEW="$ROOT/lint/checks/13-skill-registry.py"
  [ -f "$NEW" ] || { echo "NOT-CHECKED: $NEW missing — nothing ported to compare" >&2; exit 2; }
  LSTRIP='s/^FAIL: Check 13 budget: //; s/^FAIL: Check 13: //'
  NSTRIP='s/^FAIL 13-skill-registry budget: //; s/^FAIL 13-skill-registry: //'

  old="$(run_legacy 13)" || exit 2
  new="$(python3 "$NEW" "$ROOT" 2>/dev/null | grep '^FAIL ' || true)"
  compare_sets "registry tree" "$old" "$new" "$LSTRIP" "$NSTRIP"

  W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
  mkdir -p "$W/skills/skill-builder/scripts" "$W/skills/overlong"
  cp "$ROOT/skills/skill-builder/scripts/validate-skill.sh" "$W/skills/skill-builder/scripts/"
  chmod +x "$W/skills/skill-builder/scripts/"*.sh
  { printf -- '---\nname: overlong\ndescription: "'
    for i in $(seq 1 140); do printf 'trigger word %d ' "$i"; done
    printf '"\n---\n\n# overlong\n'
  } > "$W/skills/overlong/SKILL.md"
  old="$(run_legacy 13 "$W")" || exit 2
  new="$(python3 "$NEW" "$W" 2>/dev/null | grep '^FAIL ' || true)"
  compare_sets "fixture RED tree (over-cap description)" "$old" "$new" "$LSTRIP" "$NSTRIP"
  finish

else
  echo "NOT-CHECKED: no parity recipe for check '$CHECK_ID'" >&2
  exit 2
fi
