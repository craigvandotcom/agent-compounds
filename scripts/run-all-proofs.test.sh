#!/usr/bin/env bash
# run-all-proofs.test.sh — the runner discovers tracked and untracked-not-ignored harnesses,
# never a gitignored copy of the tree.
set -uo pipefail
RUNNER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/run-all-proofs.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

git -C "$T" init -q
mkdir -p "$T/skills/a" "$T/_scratch/snap"
echo "_scratch/" > "$T/.gitignore"
touch "$T/skills/a/tracked.test.sh" "$T/skills/a/new.test.py" "$T/_scratch/snap/copy.test.sh"
git -C "$T" add .gitignore skills/a/tracked.test.sh

got="$(AC_HARNESS_ROOT="$T" bash "$RUNNER" --list)"
want=$'skills/a/new.test.py\nskills/a/tracked.test.sh'
if [ "$got" = "$want" ]; then echo "run-all-proofs.test.sh: ok"; exit 0; fi
printf 'FAIL run-all-proofs.test.sh: --list gave\n%s\nwant\n%s\n' "$got" "$want"; exit 1
