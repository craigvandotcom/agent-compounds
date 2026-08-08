#!/usr/bin/env bash
# shared-checkout-steal-probe.sh — the two-agent staging-steal simulation (bd-ctlqg).
#
# THE DEFECT, measured live 2026-08-01: two agents worked one shared checkout on
# disjoint files (correct, width-2 doctrine). Agent A ran `git add` on its three
# files. Before A reached `git commit`, agent B ran a whole-tree add and committed.
# A's three files landed inside B's commit. Live evidence: commit 40eb9177 carries
# the message "…[bd-jk3j6]" and the files public/sw.js, __tests__/unit/sw-cache.test.ts
# and __tests__/e2e/service-worker.spec.ts — all bd-gcrhc's.
#
# THE STAGING AREA IS SHARED STATE. It is per-worktree, not per-agent, so
# add-then-commit is not atomic across agents and any window between them is
# exploitable. Nothing fails loudly; the damage is to the RECORD — blame, bisect,
# revert-a-bead and review-by-range all misattribute A's work to B's bead.
#
# WHAT THIS PROVES, in a scratch repo under /tmp — never against a live checkout:
#   1  NEGATIVE CONTROL: whole-tree add DOES steal A's staged file into B's commit
#   2  NEGATIVE CONTROL: a pathspec-scoped ADD followed by a bare commit STILL steals.
#      Scoping the add is NOT the fix — `git commit` publishes the whole INDEX, and
#      the index is the shared state. This is the non-obvious half, and it is why
#      commit-discipline.md § H7d is pathspec-mandatory on the COMMIT, not the add.
#   3  the sanctioned shape — `git commit -- <paths>`, no add at all — does NOT steal
#   4  A's own later commit still carries A's file — no work is lost either way,
#      which is exactly why the defect is silent
#
# Both roles are driven sequentially from one shell with A's staging window held
# open, because the race needs no concurrency to reproduce — only an open window.
# That makes it deterministic and CI-safe.
#
# NOT PROVEN HERE: that dcg prevents step 1. It does not, today — dcg 0.6.7's hook
# path never evaluates the `git add` verb (see stash-pack-probe.sh's two-layer
# measurement). Until upstream is fixed, doctrine is the only live control and this
# probe is the regression test that will confirm the guard the day it starts biting.
#
# Usage: bash shared-checkout-steal-probe.sh
# Exit 0 — the steal reproduces AND the sanctioned shape avoids it.
set -uo pipefail

FAILURES=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILURES=$((FAILURES + 1)); }

WORK="$(mktemp -d /tmp/steal-probe-XXXXXX)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT INT TERM

setup_repo() { # $1 = repo dir. Fresh repo with A's and B's files already tracked.
  local r="$1"
  mkdir -p "$r"
  git -C "$r" init -q
  git -C "$r" config user.email probe@example.com
  git -C "$r" config user.name probe
  git -C "$r" config commit.gpgsign false
  printf 'base\n' > "$r/agent-a-file.txt"
  printf 'base\n' > "$r/agent-b-file.txt"
  git -C "$r" add -- agent-a-file.txt agent-b-file.txt
  git -C "$r" commit -q -m "baseline"
  # Both agents now edit their OWN disjoint file — correct width-2 doctrine.
  printf 'agent A work\n' > "$r/agent-a-file.txt"
  printf 'agent B work\n' > "$r/agent-b-file.txt"
  # AGENT A stages its file and has NOT yet committed. This is the open window.
  git -C "$r" add -- agent-a-file.txt
}

echo "=== Case 1: NEGATIVE CONTROL — whole-tree add steals A's staged file ==="
R1="$WORK/steal"
setup_repo "$R1"
git -C "$R1" add -A                                    # AGENT B, the defect shape
git -C "$R1" commit -q -m "fix(b): agent B's bead [bd-BBBB]"
B_FILES=$(git -C "$R1" show --name-only --format= HEAD | sort | command tr -d ' ')
echo "  files in B's commit: $(printf '%s' "$B_FILES" | command tr '\n' ' ')"
if printf '%s\n' "$B_FILES" | grep -qx 'agent-a-file.txt'; then
  pass "Case 1: the steal reproduces — A's file is inside B's commit, under B's bead message"
else
  fail "Case 1: the steal did NOT reproduce — this probe is not measuring the defect"
fi

echo
echo "=== Case 2: NEGATIVE CONTROL — scoping the ADD is not enough; a bare commit still steals ==="
R2="$WORK/scoped-add"
setup_repo "$R2"
git -C "$R2" add -- agent-b-file.txt                   # AGENT B scopes its ADD…
git -C "$R2" commit -q -m "fix(b): agent B's bead [bd-BBBB]"   # …then commits the whole INDEX
B2_FILES=$(git -C "$R2" show --name-only --format= HEAD | sort | command tr -d ' ')
echo "  files in B's commit: $(printf '%s' "$B2_FILES" | command tr '\n' ' ')"
if printf '%s\n' "$B2_FILES" | grep -qx 'agent-a-file.txt'; then
  pass "Case 2: a scoped add + bare commit STILL steals — the index is the shared state, not the add"
else
  fail "Case 2: expected the scoped-add path to still steal; it did not — re-derive the doctrine before trusting it"
fi

echo
echo "=== Case 3: the SANCTIONED shape — git commit -- <paths>, no add at all ==="
R3="$WORK/scoped-commit"
setup_repo "$R3"
git -C "$R3" commit -q -m "fix(b): agent B's bead [bd-BBBB]" -- agent-b-file.txt
B3_FILES=$(git -C "$R3" show --name-only --format= HEAD | sort | command tr -d ' ')
echo "  files in B's commit: $(printf '%s' "$B3_FILES" | command tr '\n' ' ')"
if printf '%s\n' "$B3_FILES" | grep -qx 'agent-a-file.txt'; then
  fail "Case 3: a pathspec-scoped COMMIT still captured A's file — H7d does not hold"
elif printf '%s\n' "$B3_FILES" | grep -qx 'agent-b-file.txt'; then
  pass "Case 3: B's commit carries B's file only — A's staged work is untouched (H7d holds)"
else
  fail "Case 3: B's own file is missing from B's commit — the fixture is wrong"
fi

echo
echo "=== Case 4: A's work survives in both worlds — which is why the steal is silent ==="
git -C "$R3" commit -q -m "fix(a): agent A's bead [bd-AAAA]" -- agent-a-file.txt
A_FILES=$(git -C "$R3" show --name-only --format= HEAD | sort | command tr -d ' ')
if printf '%s\n' "$A_FILES" | grep -qx 'agent-a-file.txt'; then
  pass "Case 4: after the scoped path, A commits its own file under its own bead — attribution intact"
else
  fail "Case 4: A could not commit its own file after B's scoped commit"
fi
echo "  (in Case 1's world A has nothing left to commit: its content already shipped under B's message,"
echo "   so no error ever surfaces — the loss is the RECORD, never the content)"

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "Staging-steal simulation passed: the defect reproduces, the pathspec-scoped shape avoids it (bd-ctlqg)."
  exit 0
else
  echo "$FAILURES staging-steal assertion(s) FAILED."
  exit 1
fi
