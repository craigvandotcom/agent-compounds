#!/usr/bin/env bash
#
# run.sh — the RED fixture for lint/checks/38-machine-file-untracked.py.
#
# 00-meta's contract (inverted): exit 0 when the check went RED as required,
# 1 when the check passed its RED case, >=2 when the fixture could not build.
#
# The check's subject is GIT STATE, not a static tree: a committed tree can only
# ever show machine.json absent, so the RED must be BUILT. This makes a throwaway
# repo, force-adds an ignored machine.json and commits it — exactly the accident
# the .gitignore rule and this check exist to catch — then requires the real check
# to exit 1 and name the file as TRACKED.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/../../checks/38-machine-file-untracked.py"
[ -f "$CHECK" ] || { echo "fixture cannot build: $CHECK missing"; exit 2; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

git init -q -b main "$work"
git -C "$work" config user.email fixture@example.invalid
git -C "$work" config user.name fixture

# The ignore rule, present in the fixture too: the point is that -f defeats it.
printf 'machine.json\n' > "$work/.gitignore"
mkdir -p "$work/lint"
printf '#!/usr/bin/env python3\n' > "$work/lint/.keep"

printf '{"org_root": "/fixture/org", "targets": [], "harnesses": {}}\n' > "$work/machine.json"
git -C "$work" add .gitignore lint/.keep
git -C "$work" commit -qm "base without the machine file"
# Force-add the ignored file and commit it — the exact defect.
git -C "$work" add -f machine.json
git -C "$work" commit -qm "publish the machine file by accident"

# The check must see the fixture repo, not any inherited GIT_* redirection.
out="$(env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE \
  python3 "$CHECK" "$work" 2>&1)"
rc=$?
printf '%s\n' "$out" | sed 's/^/  fixture: /'

if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -q 'TRACKED'; then
  echo "fixture: RED demonstrated — the committed machine.json was named as TRACKED"
  exit 0
fi
if [ "$rc" -eq 1 ]; then
  echo "fixture: check went RED but did not name the file as TRACKED"
  exit 1
fi
echo "fixture: check did NOT go RED (exit $rc) — it passed its own RED case"
exit 1
