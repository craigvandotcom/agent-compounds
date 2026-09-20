#!/usr/bin/env bash
# 27-instance-tokens.test.sh — the fixture proving Check 27's contract.
#
#   PROBE: a banned word in a tracked file is RED, naming file and word; a tree
#           carrying none is GREEN; a gitignored carrier is NEVER scanned (the
#           population is what a clone receives, not what sits on disk); an
#           EXEMPT_PATHS carrier does not fail; no list and an empty list both
#           SKIP without claiming a pass; a list to hunt with nothing read is
#           NOT-GATED (exit 2), never green.
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

run() { python3 "$CHECK" "$1" >"$WORK/out" 2>&1; echo $?; }

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

# --- SKIP: no list at all -------------------------------------------------------
# A clone has no list. That is honest emptiness, not a verified pass — so the
# message must say so and must never read as "ok".
t="$WORK/nolist"; build_tree "$t"
printf 'names acme-widget\n' > "$t/skills/demo/SKILL.md"
git -C "$t" add -A
rc=$(run "$t")
if [ "$rc" = 0 ] && grep -q "skipped" "$WORK/out"; then
  ok "SKIP: no list -> exit 0, reported as a skip"
else
  bad "no-list: expected 0 carrying 'skipped', got $rc"; cat "$WORK/out"
fi
if grep -qE '^\s*ok:' "$WORK/out"; then
  bad "no-list: printed a pass claim while hunting nothing"
fi

# --- SKIP: a list with no words ------------------------------------------------
t="$WORK/emptylist"; build_tree "$t"
printf '# only comments here\n\n' > "$t/lint/instance-tokens.local.txt"
printf 'names acme-widget\n' > "$t/skills/demo/SKILL.md"
git -C "$t" add -A
rc=$(run "$t")
if [ "$rc" = 0 ] && grep -q "skipped" "$WORK/out"; then
  ok "SKIP: a list with no words -> exit 0, reported as a skip"
else
  bad "empty-list: expected 0 carrying 'skipped', got $rc"; cat "$WORK/out"
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

echo
if [ "$fails" -eq 0 ]; then
  echo "All 27-instance-tokens contract cases passed."
  exit 0
else
  echo "FAILURES: $fails — the check behaves outside its contract ($(basename "$0"))"
  exit 1
fi
