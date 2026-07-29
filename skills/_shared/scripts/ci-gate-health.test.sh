#!/usr/bin/env bash
# ci-gate-health.test.sh — proof harness for `_shared/board-scan.md` Scan E, the
# scheduled-CI-gate health probe (bd-o9vmx).
#
# WHY IT EXISTS: Scan E is a pasted bash block, so its only possible regression test is to
# execute the block AS PUBLISHED. This extracts the live fenced ```bash block under
# `## Scan E`, builds a throwaway repo of fixture workflow files, stubs `gh`/`git`, and
# asserts `$CI_HEALTH` (plus the `$CI_GATES` token where the shape matters).
#
# THE INVARIANT IT GUARDS — the whole reason the bead exists: **the probe must never print
# green when it could not check.** Four independent failure paths (no `gh`, no auth, no
# network/garbage, zero completed runs) must ALL land on `unknown`, and `unknown` must
# survive a healthy sibling (case 11). A health check that reports `ok` on an unread gate
# would be a fresh instance of the defect Scan E was written to catch. The second invariant
# is escalation: streak 1 = `warn`, streak >= 2 = `ALARM`, because a persistently-red gate
# looks like coverage while providing none.
#
# Runs under bash AND zsh (the fleet default shell) — verify both before landing a Scan E
# edit:  bash <this>  &&  zsh <this>
# Exit 0 = all cases pass.

SELF_DIR=$(cd "$(dirname "$0")" && pwd)
DOC="$SELF_DIR/../board-scan.md"
[ -f "$DOC" ] || { echo "HARNESS FAIL: doc not found at $DOC"; exit 1; }

BLOCK=$(awk '/^## Scan E/{s=1} s&&/^```bash$/{f=1;next} f&&/^```$/{exit} f' "$DOC")
case "$BLOCK" in
  *"gh run list"*) : ;;
  *) echo "HARNESS FAIL: could not extract the Scan E bash block"; exit 1 ;;
esac

W=/tmp/ci-gate-proof
FIX="$W/fix"
PROJECT_ROOT="$W/repo"
ARTIFACTS_DIR="$W/art"
NOW_EPOCH=$(date -u +%s)

iso_ago() {  # <hours-ago> -> ISO8601 Z
  t=$(( NOW_EPOCH - $1 * 3600 ))
  date -u -r "$t" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "@$t" +%Y-%m-%dT%H:%M:%SZ
}

reset() {
  rm -rf "$W"
  mkdir -p "$FIX" "$ARTIFACTS_DIR" "$PROJECT_ROOT/.github/workflows"
}

wf() {  # wf <file> <cron|-->   ('--' = no schedule block at all)
  {
    echo "name: x"
    echo "on:"
    if [ "$2" != "--" ]; then
      echo "  schedule:"
      echo "    - cron: '$2'"
    fi
    echo "  workflow_dispatch:"
    echo "jobs: {}"
  } > "$PROJECT_ROOT/.github/workflows/$1"
}

runs() {  # runs <wf-file> <spec...>   spec = conclusion|event|hours-ago  ('' conclusion = in progress)
  target="$1"; shift
  out=""; first=1
  for spec in "$@"; do
    c=${spec%%|*}; rest=${spec#*|}; e=${rest%%|*}; a=${rest##*|}
    [ $first -eq 1 ] || out="$out,"; first=0
    out="$out{\"conclusion\":\"$c\",\"createdAt\":\"$(iso_ago "$a")\",\"event\":\"$e\"}"
  done
  printf '[%s]' "$out" > "$FIX/$target.json"
}

raw() { printf '%s' "$2" > "$FIX/$1.json"; }             # raw <wf-file> <literal stdout>
broken() { echo "$3" > "$FIX/$1.err"; echo "$2" > "$FIX/$1.rc"; }  # broken <wf> <rc> <stderr>

# --- stubs. `gh` answers per-workflow from $FIX; `git` answers only the remote probe. ---
gh() {
  _wf=""; _prev=""
  for _a in "$@"; do [ "$_prev" = "--workflow" ] && _wf="$_a"; _prev="$_a"; done
  if [ -f "$FIX/$_wf.rc" ]; then
    cat "$FIX/$_wf.err" >&2 2>/dev/null
    return "$(cat "$FIX/$_wf.rc")"
  fi
  cat "$FIX/$_wf.json" 2>/dev/null
}
git() {
  case "$*" in
    *"remote get-url"*) echo "git@github.com:acme/app.git" ;;
    *) command git "$@" ;;
  esac
}

PASS=0; FAIL=0
check() {  # check <name> <want-health> [want-substring-in-CI_GATES]
  CI_HEALTH=""; CI_GATES=""
  eval "$BLOCK" > "$W/out" 2>&1
  ok=1
  [ "$CI_HEALTH" = "$2" ] || ok=0
  if [ -n "${3:-}" ]; then
    case "$CI_GATES" in *"$3"*) : ;; *) ok=0 ;; esac
  fi
  if [ "$ok" = 1 ]; then
    PASS=$((PASS + 1)); printf 'ok   %-44s %s\n' "$1" "$CI_HEALTH"
  else
    FAIL=$((FAIL + 1)); printf 'FAIL %-44s got=%s want=%s gates=[%s]\n' "$1" "$CI_HEALTH" "$2" "$CI_GATES"
  fi
}

echo "shell: ${ZSH_VERSION:+zsh $ZSH_VERSION}${BASH_VERSION:+bash $BASH_VERSION}"

# --- healthy + escalation ladder -------------------------------------------------------
reset; wf e2e.yml '0 8 * * *'
runs e2e.yml 'success|schedule|10' 'success|schedule|34'
check "1  all green, fresh cron" ok "e2e.yml=green"

reset; wf e2e.yml '0 8 * * *'
runs e2e.yml 'failure|schedule|10' 'success|schedule|34'
check "2  streak 1 -> warn" warn "e2e.yml=red×1"

reset; wf e2e.yml '0 8 * * *'
runs e2e.yml 'failure|schedule|10' 'failure|schedule|34' 'success|schedule|58'
check "3  streak 2 -> ALARM" ALARM "e2e.yml=red×2"

reset; wf e2e.yml '0 8 * * *'
runs e2e.yml 'failure|workflow_dispatch|2' 'failure|schedule|14' 'success|workflow_dispatch|31' \
             'failure|workflow_dispatch|32' 'failure|schedule|38' 'failure|schedule|62' \
             'failure|schedule|86' 'failure|schedule|110'
check "4  measured e2e history (bd-o9vmx)" ALARM "e2e.yml=red×2"

reset; wf e2e.yml '0 8 * * *'
runs e2e.yml 'failure|schedule|10' 'failure|schedule|34' 'failure|schedule|58' \
             'failure|schedule|82' 'failure|schedule|106' 'failure|schedule|130' 'failure|schedule|154'
check "5  seven straight reds -> ALARM" ALARM "red×7"

reset; wf e2e.yml '0 8 * * *'
runs e2e.yml '|schedule|1' 'failure|schedule|25' 'failure|schedule|49'
check "6  in-flight run skipped, not green" ALARM "red×2"

reset; wf e2e.yml '0 8 * * *'
runs e2e.yml '|schedule|1' 'success|schedule|25'
check "7  in-flight over green -> ok" ok "e2e.yml=green"

reset; wf e2e.yml '0 8 * * *'
runs e2e.yml 'cancelled|schedule|10' 'success|schedule|34'
check "8  cancelled counts non-green" warn "red×1"

# --- the four degrade paths: EVERY one must be `unknown`, never `ok` -------------------
reset; wf e2e.yml '0 8 * * *'
broken e2e.yml 127 'zsh: command not found: gh'
check "9  gh absent (127) -> unknown" unknown "e2e.yml=unknown"

reset; wf e2e.yml '0 8 * * *'
broken e2e.yml 4 'gh: To get started with GitHub CLI, please run: gh auth login'
check "10 gh unauthenticated -> unknown" unknown "e2e.yml=unknown"

reset; wf e2e.yml '0 8 * * *'
broken e2e.yml 1 'dial tcp: lookup api.github.com: no such host'
check "11 no network -> unknown" unknown "e2e.yml=unknown"

reset; wf e2e.yml '0 8 * * *'
raw e2e.yml '<html>502 Bad Gateway</html>'
check "12 unparseable stdout -> unknown" unknown "e2e.yml=unknown"

reset; wf e2e.yml '0 8 * * *'
raw e2e.yml '[]'
check "13 zero runs -> unknown" unknown "e2e.yml=unknown"

reset; wf e2e.yml '0 8 * * *'
runs e2e.yml 'success|workflow_dispatch|3' 'success|workflow_dispatch|9'
# the suite IS green; what is unknown is whether the CRON still fires — so the row stays
# `green(no-sched-run)` while the VERDICT degrades to unknown. Both halves asserted.
check "14 dispatch-only window -> unknown" unknown "e2e.yml=green(no-sched-run)"

# --- precedence: a healthy sibling must never absorb a bad one -------------------------
reset; wf e2e.yml '0 8 * * *'; wf integration-tests.yml '0 4 * * *'
runs integration-tests.yml 'success|schedule|6'
broken e2e.yml 127 'command not found: gh'
check "15 unknown outranks a green sibling" unknown "integration-tests.yml=green"

reset; wf e2e.yml '0 8 * * *'; wf integration-tests.yml '0 4 * * *'
runs e2e.yml 'failure|schedule|10' 'failure|schedule|34'
broken integration-tests.yml 127 'command not found: gh'
check "16 ALARM outranks unknown" ALARM "integration-tests.yml=unknown"

# --- dead-cron detection, cadence-aware -----------------------------------------------
reset; wf e2e.yml '0 8 * * *'
runs e2e.yml 'success|schedule|120'
check "17 daily cron silent 5d -> ALARM" ALARM "e2e.yml=green(120h)"

reset; wf weekly.yml '0 8 * * 1'
runs weekly.yml 'success|schedule|120'
check "18 weekly cron at 5d is fine" ok "weekly.yml=green"

# --- enumeration: from the repo, never a list; `none` is not `unknown` ----------------
reset; wf quality-gate.yml '--'
check "19 no scheduled workflow -> none" none

reset; wf nightly.yaml '0 8 * * *'
runs nightly.yaml 'failure|schedule|10' 'failure|schedule|34'
check "20 .yaml extension is enumerated" ALARM "nightly.yaml=red×2"

echo "---"
echo "PASS=$PASS FAIL=$FAIL"
rm -rf "$W"
[ "$FAIL" -eq 0 ]
