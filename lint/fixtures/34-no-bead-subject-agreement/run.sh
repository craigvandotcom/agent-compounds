#!/usr/bin/env bash
# run.sh — the RED case for lint/checks/34-no-bead-subject-agreement.py. The
# violation is a git STATE, not a static tree: a [no-bead] commit whose diff
# reaches a code file. Build a throwaway repo with exactly that state and exit 0
# only when the real check reports it.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CHECK="$ROOT/lint/checks/34-no-bead-subject-agreement.py"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
git init -q "$W/repo" -b main 2>/dev/null
cd "$W/repo" || exit 2
git config user.email t@t.t; git config user.name t

# base commit — the window's lower bound
printf 'base\n' > README.md
git add -A; git commit -qm base

# the offense: a [no-bead] commit whose diff touches a CODE file
mkdir -p src
printf 'real change\n' >> src/app.py
git add -A; git commit -qm "chore(ac-pipeline): friction — sensor-log append only [no-bead]"

out="$(python3 "$CHECK" "$W/repo" 2>&1)"; rc=$?
echo "$out" | sed 's/^/  | /'
if [ "$rc" -ne 1 ]; then echo "fixture: expected RED (exit 1) for a [no-bead] commit touching a code file, got $rc"; exit "$rc"; fi
printf '%s' "$out" | grep -q "src/app.py" || { echo "fixture: the code file was not named"; exit 1; }
printf '%s' "$out" | grep -q "\[no-bead\]" || { echo "fixture: the offending commit was not named"; exit 1; }
exit 0