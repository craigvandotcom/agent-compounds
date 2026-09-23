#!/usr/bin/env bash
# scope.test.sh — LIVE_TEXT and HARNESSES hold what a commit could contain, never a
# gitignored copy of the tree.
set -uo pipefail
LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

git -C "$T" init -q
mkdir -p "$T/skills/a" "$T/skills/new" "$T/_scratch/snap/skills/a"
echo "_scratch/" > "$T/.gitignore"
echo x > "$T/skills/a/SKILL.md"; echo x > "$T/skills/a/a.test.sh"
echo x > "$T/skills/new/SKILL.md"                      # untracked, not ignored
cp "$T/skills/a/"* "$T/_scratch/snap/skills/a/"        # ignored copy
git -C "$T" add .gitignore skills/a

LINT_ROOT="$T" PYTHONPATH="$LIB" python3 - <<'EOF'
import sys, scope
want_live = {"skills/a/SKILL.md", "skills/new/SKILL.md"}
fails = []
if scope.LIVE_TEXT != want_live: fails.append(f"LIVE_TEXT {sorted(scope.LIVE_TEXT)}")
if scope.HARNESSES != {"skills/a/a.test.sh"}: fails.append(f"HARNESSES {sorted(scope.HARNESSES)}")
for f in fails: print("FAIL", f)
print("scope.test.sh:", "FAIL" if fails else "ok")
sys.exit(1 if fails else 0)
EOF
