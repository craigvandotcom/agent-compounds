#!/usr/bin/env bash
# 27-instance-tokens.test.sh — the fixture proving Check 27's contract.
#
#   PROBE (token-hunt leg): a banned word in a tracked file is RED, naming file
#           and word; a tree carrying none is GREEN; a gitignored carrier is
#           NEVER scanned (the population is what a clone receives, not what
#           sits on disk); an EXEMPT_PATHS carrier does not fail; no list and an
#           empty list both leave this leg with nothing to hunt — never claimed
#           as a pass FOR THIS LEG — but the overall check still goes green off
#           the machine-file leg below; a list to hunt with nothing read is
#           NOT-GATED (exit 2), never green.
#
#   PROBE (machine-file leg, merged in from the standalone check it replaces):
#           a committed machine.json is RED naming TRACKED; a force-added
#           (staged, uncommitted) machine.json is RED naming STAGED; a file
#           tracked in HEAD whose removal is STAGED (`git rm --cached`, still
#           uncommitted) is GREEN with a disclosed amnesty, and the commit that
#           lands it clears the amnesty; an ignored machine.json sitting
#           untracked on disk is GREEN; a checkout with no machine.json is
#           GREEN; a non-git root is NOT-GATED (2). This leg runs even when no
#           token list exists — the reason 38 is now folded in here rather than
#           standing alone: it used to be the only leg, so 27 without a list
#           was a bare 77 skip; now the whole check is still real verification.
#
#   Every fixture word here is synthetic. This harness is itself tracked, so a
#   real banned word in it would be the very leak the check exists to prevent —
#   the reason the previous version of this file needed an exemption.
#
# ASSURANCE
#   PROBE:    bash lint/checks/27-instance-tokens.test.sh
#   SCHEDULE: scripts/run-all-proofs.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/27-instance-tokens.py"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

# build_tree <dir> — a git checkout with a skill file, ready for `git add`.
build_tree() {
  mkdir -p "$1/lint" "$1/skills/demo"
  git -C "$1" init -q
  git -C "$1" config user.email "test@example.com"
  git -C "$1" config user.name "test"
}

# The check now shells out to git for the machine-file leg too, so it must
# always judge the given root, never an inherited GIT_* redirection.
run() { env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE python3 "$CHECK" "$1" >"$WORK/out" 2>&1; echo $?; }

# --- RED: a banned word in a tracked file --------------------------------------
t="$WORK/red"; build_tree "$t"
printf 'acme-widget\n' > "$t/lint/instance-tokens.local.txt"
printf 'this doc names acme-widget in prose\n' > "$t/skills/demo/SKILL.md"
git -C "$t" add -A
rc=$(run "$t")
if [ "$rc" = 1 ] && grep -q "skills/demo/SKILL.md" "$WORK/out" && grep -q "acme-widget" "$WORK/out"; then
  ok "RED: a banned word in a tracked file -> exit 1, naming file and word"
else
  bad "RED: expected 1 naming the carrier, got $rc"; cat "$WORK/out"
fi

# --- GREEN: nothing carries a banned word --------------------------------------
t="$WORK/green"; build_tree "$t"
printf 'acme-widget\n' > "$t/lint/instance-tokens.local.txt"
printf 'this doc names nothing in particular\n' > "$t/skills/demo/SKILL.md"
git -C "$t" add -A
rc=$(run "$t")
if [ "$rc" = 0 ] && grep -q "0 hit(s)" "$WORK/out"; then
  ok "GREEN: no banned word -> exit 0"
else
  bad "GREEN: expected 0, got $rc"; cat "$WORK/out"
fi

# --- GREEN: a GITIGNORED carrier is never scanned ------------------------------
# The population is what a clone RECEIVES. The adopter-local artifacts are full
# of these words by design and are never published; if this case ever fails, the
# check has started reading the working tree instead of the index.
t="$WORK/ignored"; build_tree "$t"
printf 'acme-widget\n' > "$t/lint/instance-tokens.local.txt"
printf 'this doc names nothing in particular\n' > "$t/skills/demo/SKILL.md"
printf 'local-notes.md\n' > "$t/.gitignore"
printf 'private notes about acme-widget\n' > "$t/local-notes.md"
git -C "$t" add -A
rc=$(run "$t")
if [ "$rc" = 0 ]; then
  ok "GREEN: a gitignored carrier is not scanned (population is the index, not the disk)"
else
  bad "gitignored carrier: expected 0, got $rc"; cat "$WORK/out"
fi

# --- GREEN: an EXEMPT_PATHS carrier does not fail ------------------------------
# LICENSE is exempt because its copyright holder is a deliberate authorship claim.
t="$WORK/exempt"; build_tree "$t"
printf 'acme-widget\n' > "$t/lint/instance-tokens.local.txt"
printf 'Copyright (c) 2026 acme-widget\n' > "$t/LICENSE"
printf 'clean prose\n' > "$t/skills/demo/SKILL.md"
git -C "$t" add -A
rc=$(run "$t")
if [ "$rc" = 0 ]; then
  ok "GREEN: an EXEMPT_PATHS carrier does not fail"
else
  bad "exempt carrier: expected 0, got $rc"; cat "$WORK/out"
fi

# --- no list at all: token-hunt leg SKIPs, machine-file leg still verifies -----
# A clone has no list. That leg alone hunts nothing — honest emptiness, never
# claimed as a pass for ITSELF — but the machine-file leg ran clean in this same
# checkout (no machine.json here at all), so the check as a whole is real
# verification, not a bare skip: exit 0, not 77.
t="$WORK/nolist"; build_tree "$t"
printf 'names acme-widget\n' > "$t/skills/demo/SKILL.md"
git -C "$t" add -A
rc=$(run "$t")
if [ "$rc" = 0 ] && grep -q "token-hunt leg skipped" "$WORK/out"; then
  ok "no list: token-hunt leg skips, machine-file leg clean -> exit 0"
else
  bad "no-list: expected 0 carrying 'token-hunt leg skipped', got $rc"; cat "$WORK/out"
fi
if grep -qE '^\s*ok:.*\(token-hunt leg\)' "$WORK/out"; then
  bad "no-list: printed a pass claim for the token-hunt leg while hunting nothing"
fi
if ! grep -qE '^\s*ok:.*\(machine-file leg\)' "$WORK/out"; then
  bad "no-list: the machine-file leg did not report its own clean result"
fi

# --- a list with no words: same shape as no list at all ------------------------
t="$WORK/emptylist"; build_tree "$t"
printf '# only comments here\n\n' > "$t/lint/instance-tokens.local.txt"
printf 'names acme-widget\n' > "$t/skills/demo/SKILL.md"
git -C "$t" add -A
rc=$(run "$t")
if [ "$rc" = 0 ] && grep -q "token-hunt leg skipped" "$WORK/out"; then
  ok "empty list: token-hunt leg skips, machine-file leg clean -> exit 0"
else
  bad "empty-list: expected 0 carrying 'token-hunt leg skipped', got $rc"; cat "$WORK/out"
fi

# --- NOT-GATED: words to hunt, but nothing read --------------------------------
# The failure the old check guarded with exit 2 and this rewrite nearly dropped:
# a list exists, so words WERE to be hunted, but no file was read. Green here
# would be a pass claim over an empty set.
t="$WORK/nothing"; build_tree "$t"
printf 'acme-widget\n' > "$t/lint/instance-tokens.local.txt"
# staged NOTHING, so the index — and therefore the population — is empty
rc=$(run "$t")
if [ "$rc" = 2 ] && grep -q "NOT-GATED" "$WORK/out"; then
  ok "NOT-GATED: a list to hunt but nothing read -> exit 2"
else
  bad "nothing-read: expected 2 carrying NOT-GATED, got $rc"; cat "$WORK/out"
fi

# --- machine-file leg (merged in from the standalone check it replaces) --------
# machine.json's tracked-ness is GIT STATE, not a file population, so these cases
# build throwaway repos of their own rather than reusing build_tree's token-hunt
# tree. None of them carry a token list, so the token-hunt leg skips in every
# one — the point is that the machine-file leg's own exit code still drives the
# overall result via combine().

# new_repo -> prints a temp git repo path carrying the same machine.json ignore
# rule this registry's own root does.
new_repo() {
  local w
  w="$(mktemp -d)"
  git init -q -b main "$w"
  git -C "$w" config user.email fixture@example.invalid
  git -C "$w" config user.name fixture
  printf 'machine.json\n' > "$w/.gitignore"
  printf '#!/usr/bin/env python3\n' > "$w/keep.py"
  git -C "$w" add .gitignore keep.py
  git -C "$w" commit -qm base
  printf '%s\n' "$w"
}

# --- RED: machine.json committed (tracked) -------------------------------------
w="$(new_repo)"
printf '{"org_root": "/x"}\n' > "$w/machine.json"
git -C "$w" add -f machine.json
git -C "$w" commit -qm "committed by accident"
rc=$(run "$w")
if [ "$rc" = 1 ] && grep -q "TRACKED" "$WORK/out"; then
  ok "machine-file RED: committed machine.json -> exit 1 naming TRACKED"
else
  bad "machine-file tracked case: expected 1 naming TRACKED, got $rc"; cat "$WORK/out"
fi
rm -rf "$w"

# --- RED: machine.json staged but not committed ---------------------------------
w="$(new_repo)"
printf '{"org_root": "/x"}\n' > "$w/machine.json"
git -C "$w" add -f machine.json
rc=$(run "$w")
if [ "$rc" = 1 ] && grep -q "STAGED" "$WORK/out"; then
  ok "machine-file RED: staged machine.json -> exit 1 naming STAGED"
else
  bad "machine-file staged case: expected 1 naming STAGED, got $rc"; cat "$WORK/out"
fi
rm -rf "$w"

# --- GREEN + AMNESTY: still in HEAD, removal staged (`git rm --cached`) --------
# `git rm --cached` keeps the file in HEAD's tree until that commit lands, and
# this check gates that very commit — so it passes with a DISCLOSED amnesty, and
# only while the removal is genuinely staged: the staged-but-not-committed case
# above stays RED, which is what keeps this narrow.
w="$(new_repo)"
printf '{"org_root": "/x"}\n' > "$w/machine.json"
git -C "$w" add -f machine.json
git -C "$w" commit -qm "committed by accident"
git -C "$w" rm --cached -q machine.json
rc=$(run "$w")
if [ "$rc" = 0 ] && grep -q "amnesty" "$WORK/out"; then
  ok "machine-file AMNESTY: tracked in HEAD, removal staged -> exit 0, amnesty disclosed"
else
  bad "machine-file amnesty case: expected 0 naming amnesty, got $rc"; cat "$WORK/out"
fi
# The amnesty is one commit long: once the removal lands, the run is plainly green.
git -C "$w" commit -qm "untrack the machine file"
rc=$(run "$w")
if [ "$rc" = 0 ] && ! grep -q "amnesty" "$WORK/out"; then
  ok "machine-file AMNESTY: the untracking commit clears it — the next run is plain green"
else
  bad "machine-file post-amnesty case: expected plain exit 0 with no amnesty, got $rc"; cat "$WORK/out"
fi
rm -rf "$w"

# --- GREEN: ignored machine.json on disk, never added ---------------------------
w="$(new_repo)"
printf '{"org_root": "/x"}\n' > "$w/machine.json"
rc=$(run "$w")
if [ "$rc" = 0 ]; then
  ok "machine-file GREEN: ignored, untracked machine.json on disk -> exit 0"
else
  bad "machine-file untracked case: expected 0, got $rc"; cat "$WORK/out"
fi
rm -rf "$w"

# --- GREEN: no machine.json at all -----------------------------------------------
w="$(new_repo)"
rc=$(run "$w")
if [ "$rc" = 0 ]; then
  ok "machine-file GREEN: checkout with no machine.json -> exit 0"
else
  bad "machine-file absent case: expected 0, got $rc"; cat "$WORK/out"
fi
rm -rf "$w"

# --- NOT-GATED: not a git checkout ------------------------------------------------
w="$(mktemp -d)"
rc=$(run "$w")
if [ "$rc" = 2 ]; then
  ok "machine-file NOT-GATED: non-git root -> exit 2 (no checkout to read)"
else
  bad "machine-file not-gated case: expected 2, got $rc"; cat "$WORK/out"
fi
rm -rf "$w"

# --- GREEN: the real registry's own machine.json is clean -----------------------
# Whatever the token-hunt leg finds here (this registry may or may not carry its
# own local token list) is out of scope for this case; the only thing asserted
# is that the machine-file leg itself never reports machine.json tracked/staged
# in this real, live checkout.
env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE python3 "$CHECK" "$HERE/../.." >"$WORK/out" 2>&1
if grep -q "machine.json is TRACKED\|machine.json is STAGED" "$WORK/out"; then
  bad "real registry: machine.json reported tracked/staged in the real checkout"
else
  ok "GREEN: the real registry's machine.json is neither tracked nor staged"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "All 27-instance-tokens contract cases passed."
  exit 0
else
  echo "FAILURES: $fails — the check behaves outside its contract ($(basename "$0"))"
  exit 1
fi
