#!/usr/bin/env bash
# allocate-wave-branch.sh — compute, create, and push the next numbered wave branch.
#
# Shared by ac-implement and ac-loop. Standalone: no inputs; reads git state only
# (refs/remotes/origin/wave/*, origin/main commit log, tags wave/*). Run AFTER
# `git fetch origin --prune` and only when no wave branch exists anywhere.
#
# Behavior contract:
# - HIGHEST = max 3-digit wave number across the UNION of three sources — live
#   remote wave refs, merge-commit messages on origin/main, and wave/* tags.
#   Union, not refs alone: `git fetch --prune` drops merged waves' refs, so a
#   refs-only scan can reuse a shipped number (incident: wave-collision —
#   see ac-implement references/incidents.md).
# - NEXT = zero-padded 3-digit string HIGHEST+1; seed 000 if no prior waves.
# - Collision guard: if the literal string "wave/$NEXT" already appears in
#   origin/main's log, print "collision: ..." and exit 1 (hard fail — does NOT
#   auto-increment past the collision).
# - On success: checks out wave/$NEXT from main, pushes with upstream set, and
#   prints the new branch name.
#
# No `set -e`: an empty scan (no prior waves) must fall through to the 000 seed,
# and the collision guard handles its own exit.

HIGHEST=$( { git for-each-ref --format='%(refname:strip=3)' refs/remotes/origin/wave/;
             git log origin/main --oneline | grep -oE 'wave/[0-9]{3}' | cut -d/ -f2;
             git tag -l 'wave/*' | cut -d/ -f2; } \
           | grep -oE '^[0-9]{3}$' | sort -n | tail -1)
# 10# forces base-10: zero-padded "008"/"009" are invalid octal in $((...)) —
# latent bug inherited from the original inline bash, caught + proven in the
# W2 shakedown (HIGHEST=009 produced an empty NEXT and a misfired guard).
NEXT=$(printf "%03d" $(( 10#${HIGHEST:-0} + 1 )))
# Guard: never reuse a number that ever existed in history.
git log origin/main --oneline | grep -q "wave/$NEXT" && { echo "collision: wave/$NEXT already in history"; exit 1; }
git checkout -b "wave/$NEXT" main
git push -u origin "wave/$NEXT"
echo "wave/$NEXT"
