#!/usr/bin/env bash
# 07-consumer-symlinks.test.sh — the contract harness for
# lint/checks/07-consumer-symlinks.py.
#
#   PROBE: a dangling symlink in a consumer dir FAILS with the link named; a
#           dangling link nested deeper in the layer FAILS; a layer whose
#           symlinks all resolve PASSES; no consumer dir at all (root present,
#           nothing under it — e.g. a fresh/adopter clone) SKIPs green, never a
#           NOT-CHECKED/exit-2 claim; an absent consumer ROOT (a bare checkout)
#           SKIPs green too.
#
# ASSURANCE
#   PROBE:    bash lint/checks/07-consumer-symlinks.test.sh
#   SCHEDULE: scripts/run-all-proofs.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/07-consumer-symlinks.py"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

OUT="$(mktemp)"
run_check() { # <tmp-base> -> exit code; output in $OUT
  LINT_CONSUMER_BASE="$1" python3 "$CHECK" >"$OUT" 2>&1
  echo $?
}

work="$(mktemp -d)"
trap 'rm -rf "$work" "$OUT"' EXIT

build_base() { # <root> — an empty consumer base with a (nonexistent) app target
  mkdir -p "$1/infrastructure"
  : > "$1/infrastructure/ac-deploy-targets.list"
}

# --- 1 RED: dangling symlink in a consumer dir -> exit 1, named ---------------
t="$work/red"
build_base "$t"
mkdir -p "$t/.claude/skills"
ln -s "$t/.claude/skills/gone-skill" "$t/.claude/skills/dangling-link"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "broken symlink: .*dangling-link" "$OUT"; then
  ok "RED: dangling symlink failed, named"
else
  bad "RED: expected exit 1 naming dangling-link, got $rc"; cat "$OUT"
fi

# --- 2 RED-NESTED: dangling link deeper in the layer -> exit 1 ----------------
t="$work/red-nested"
build_base "$t"
mkdir -p "$t/.claude/agents"
ln -s ../skills/never-existed "$t/.claude/agents/deep-link"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "broken symlink: .*deep-link" "$OUT"; then
  ok "RED-NESTED: nested dangling link failed, named"
else
  bad "RED-NESTED: expected exit 1 naming deep-link, got $rc"; cat "$OUT"
fi

# --- 3 GREEN: every symlink resolves ------------------------------------------
t="$work/green"
build_base "$t"
mkdir -p "$t/.claude/skills/real-skill"
printf '# real-skill\n' > "$t/.claude/skills/real-skill/SKILL.md"
ln -s real-skill "$t/.claude/skills/linked"
rc=$(run_check "$t")
if [ "$rc" = 0 ]; then
  ok "GREEN: resolving symlinks pass"
else
  bad "GREEN: expected exit 0, got $rc"; cat "$OUT"
fi

# --- 4 SKIP: no consumer dir exists -> exit 0 (never NOT-CHECKED/exit 2) -----
# A consumer-less checkout (an adopter's fresh clone, or a root that exists but
# carries no deployed harness layer under it) must get a green suite: exit 2
# here used to be unfixable and unconditional in every fresh clone (ac-agnostic
# batch B). A skip is disclosed (SKIP token), never a silent/false pass.
t="$work/empty"
build_base "$t"
rc=$(run_check "$t")
if [ "$rc" = 0 ] && grep -qi "SKIP" "$OUT" && ! grep -qi "NOT-CHECKED" "$OUT"; then
  ok "EMPTY: no consumer dir -> SKIP exit 0, disclosed"
else
  bad "EMPTY: expected exit 0 SKIP (disclosed, no NOT-CHECKED), got $rc"; cat "$OUT"
fi

# --- 4b FAIL-CLOSED PRESERVED: a real consumer dir exists AND is broken -------
# Pins that "no consumer tree" (case 4, SKIP) and "a consumer tree that exists
# but is broken" (this case) are told apart: the same build_base() root, but
# with an actual .claude/skills tree carrying a dangling link, must still FAIL
# — the skip fix must never widen into "always green".
t="$work/empty-but-broken"
build_base "$t"
mkdir -p "$t/.claude/skills"
ln -s "$t/.claude/skills/gone-skill" "$t/.claude/skills/dangling-link"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "broken symlink: .*dangling-link" "$OUT"; then
  ok "FAIL-CLOSED: a present-but-broken consumer tree still fails"
else
  bad "FAIL-CLOSED: expected exit 1 naming dangling-link, got $rc"; cat "$OUT"
fi

# --- 5 SKIP: absent consumer root (a consumer-less checkout) -> exit 0 ---------
rc=$(run_check "$work/no-such-root")
if [ "$rc" = 0 ] && grep -qi "SKIP" "$OUT"; then
  ok "NO-ROOT: absent consumer root -> SKIP exit 0"
else
  bad "NO-ROOT: expected exit 0 SKIP, got $rc"; cat "$OUT"
fi

# --- 6 FLAGGED-LINE: a roster line's flags are not part of the app's name ------
# `<app> public` and `<app> packages=a,b` name the apps <app>. Read whole, the line names a
# directory that never exists, and the app leaves the union with no notice.
domain="$(basename "$(cd "$HERE/../../../.." && pwd)")"
for flags in "public" "packages=a,b" "public packages=a,b  # trailing comment"; do
  t="$work/flagged-$(printf '%s' "$flags" | tr -c 'a-z' '_')"
  build_base "$t"
  printf 'flagged-app %s\n' "$flags" > "$t/infrastructure/ac-deploy-targets.list"
  mkdir -p "$t/$domain/software/flagged-app/.claude/skills"
  ln -s gone-skill "$t/$domain/software/flagged-app/.claude/skills/flagged-dangling"
  rc=$(run_check "$t")
  if [ "$rc" = 1 ] && grep -q "broken symlink: .*flagged-dangling" "$OUT"; then
    ok "FLAGGED-LINE: 'flagged-app $flags' is walked as flagged-app"
  else
    bad "FLAGGED-LINE: 'flagged-app $flags' — expected exit 1 naming flagged-dangling, got $rc"; cat "$OUT"
  fi
done

echo
if [ "$fails" -eq 0 ]; then
  echo "All 07-consumer-symlinks contract cases passed."
  exit 0
fi
echo "$fails case(s) FAILED."
exit 1
