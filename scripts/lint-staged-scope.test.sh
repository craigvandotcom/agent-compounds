#!/usr/bin/env bash
# lint-staged-scope.test.sh — proof harness for the pre-commit staged lane
# (lint/run.py --changed --staged; 2026-09-12 lint audit, items 1 + 4).
#
# Builds a throwaway registry-shaped repo in /tmp — never the real checkout —
# carrying a COPY of THIS repo's actual lint/run.py + lint/lib/*.py (so the
# exact code under review is what's exercised) plus two tiny demo checks. Two
# guarantees are under test:
#
#   1. The staged lane judges the INDEX, not the working tree: a dirty,
#      UNSTAGED sibling file that would trip a check must never fail a commit
#      that never staged it (measured: FRICTIONS.md:711), while a bad thing
#      that IS staged still fails — materialisation is not an amnesty.
#   2. A check whose own source file is staged always runs, even when that
#      file lands outside the check's declared `scope:` set (item 4), and a
#      genuine scope-set hit is still detected when the diff root and
#      `lib.scope`'s own root are two different-but-identical strings, via a
#      symlink alias (the 22-ledger-integrity skip class).
#
# Runs under bash. Exit 0 = every case passed.

set -uo pipefail

REGISTRY="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$REGISTRY/lint/run.py" ] || { echo "HARNESS FAIL: $REGISTRY/lint/run.py missing"; exit 1; }

PASS=0
FAIL=0
ok()  { PASS=$((PASS+1)); printf 'ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL %s\n' "$1"; }

W=/tmp/lint-staged-scope-proof
rm -rf "$W" "$W-alias"
mkdir -p "$W/lint/lib" "$W/lint/checks" "$W/skills/demo" "$W/skills/demo2"

# A COPY of the real runner + lib, so the exact code this bead touched runs —
# never the real checkout itself.
cp "$REGISTRY/lint/run.py" "$W/lint/run.py"
cp "$REGISTRY/lint/lib/scope.py" "$W/lint/lib/scope.py"
cp "$REGISTRY/lint/lib/frontmatter.py" "$W/lint/lib/frontmatter.py"
RUN_PY="$W/lint/run.py"

git init -q "$W"
git -C "$W" config user.email t@t.t
git -C "$W" config user.name t

# Check A: a real disk-scan check shaped like 27-instance-tokens — scope
# LIVE_TEXT, FAILs on a banned token. Exercises the MATERIALISATION half.
cat > "$W/lint/checks/50-demo-token.py" <<'PY'
#!/usr/bin/env python3
# ---
# id: 50-demo-token
# prevents: a banned token surviving in demo LIVE_TEXT
# scope: LIVE_TEXT
# severity: fail
# fixture: lint/checks/50-demo-token.py
# ---
import os
import sys
_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(_HERE))
from lib import scope  # noqa: E402


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else scope.ROOT
    if os.path.abspath(root) != scope.ROOT:
        os.environ["LINT_ROOT"] = os.path.abspath(root)
        import importlib
        importlib.reload(scope)
    hits = []
    for p in scope.scan(scope.LIVE_TEXT, root):
        with open(p, encoding="utf-8") as fh:
            if "BANNEDTOKEN" in fh.read():
                hits.append(p)
    if not scope.LIVE_TEXT:
        print("50-demo-token NOT-CHECKED: nothing scanned", file=sys.stderr)
        return 2
    if hits:
        print("FAIL 50-demo-token: " + ", ".join(hits))
        return 1
    print("ok: 50-demo-token clean")
    return 0


if __name__ == "__main__":
    sys.exit(main())
PY

# Check B: scope LEDGER, reports only whether it RAN. Exercises item 4's
# own-file and own-scope always-run guarantee without needing a real
# ledger-integrity contract.
cat > "$W/lint/checks/51-demo-ledger.py" <<'PY'
#!/usr/bin/env python3
# ---
# id: 51-demo-ledger
# prevents: demo — proves the runner always fires a check whose own file or
#   own scope is staged
# scope: LEDGER
# severity: fail
# fixture: lint/checks/51-demo-ledger.py
# ---
import sys


def main():
    print("ok: 51-demo-ledger RAN")
    return 0


if __name__ == "__main__":
    sys.exit(main())
PY

echo "hello" > "$W/skills/demo/SKILL.md"
echo "hello" > "$W/skills/demo2/SKILL.md"
git -C "$W" add -A
git -C "$W" commit -qm base >/dev/null

run_new() { ( cd "$W" && python3 "$RUN_PY" --root "$W" "$@" ); }
exit_of() { python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["checks"][0]["exit"])' 2>/dev/null; }
scope_of() { python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["checks"][0].get("skipped_scope") or "ran")' 2>/dev/null; }

# --- Case 1: a dirty UNSTAGED sibling must not fail the staged lane ---
git -C "$W" reset -q --hard >/dev/null
echo "hello v2 — a real, clean edit" > "$W/skills/demo/SKILL.md"   # staged: clean but genuinely changed
git -C "$W" add "$W/skills/demo/SKILL.md"
echo "BANNEDTOKEN here" >> "$W/skills/demo2/SKILL.md"   # UNSTAGED dirty sibling — never staged

out1=$(run_new --check 50 --changed --staged --json)
rc1=$(echo "$out1" | exit_of)
[ "$rc1" = "0" ] && ok "unstaged dirty sibling never leaks into the staged lane (rc=$rc1)" \
                  || bad "expected PASS (rc=0) with an unstaged sibling dirtied, got rc='$rc1': $out1"

# --- Case 2: the bad thing IS staged -> still fails, materialisation is not an amnesty ---
git -C "$W" add "$W/skills/demo2/SKILL.md"              # now stage the bad content too
out2=$(run_new --check 50 --changed --staged --json)
rc2=$(echo "$out2" | exit_of)
[ "$rc2" = "1" ] && ok "staged BANNEDTOKEN still FAILS once it is actually staged" \
                  || bad "expected FAIL (rc=1) once staged, got rc='$rc2': $out2"

# --- Case 3: a check's OWN FILE staged must always run, even off-scope ---
git -C "$W" reset -q --hard >/dev/null
printf '# touched\n' >> "$W/lint/checks/51-demo-ledger.py"
git -C "$W" add "$W/lint/checks/51-demo-ledger.py"      # NOT a LEDGER-scoped file
out3=$(run_new --check 51 --changed --staged --json)
res3=$(echo "$out3" | scope_of)
[ "$res3" = "ran" ] && ok "51-demo-ledger's own staged file always runs it (scope LEDGER notwithstanding)" \
                     || bad "expected the check to run on its own staged file, got '$res3': $out3"

# --- Case 4: a genuine scope hit must survive a root-alias mismatch ---
# Symlink alias: the diff root and lib.scope's own walked root are two different
# strings pointing at the same files (the 22-ledger-integrity skip class).
ln -s "$W" "$W-alias"
git -C "$W" reset -q --hard >/dev/null
echo "ledger note" > "$W/skills/demo2/FRICTIONS.md"
git -C "$W" add "$W/skills/demo2/FRICTIONS.md"
out4=$(cd "$W-alias" && python3 "$RUN_PY" --root "$W-alias" --check 51 --changed --staged --json)
res4=$(echo "$out4" | scope_of)
[ "$res4" = "ran" ] && ok "a genuine LEDGER hit is still detected through a symlink-aliased --root" \
                     || bad "expected the check to run despite the alias, got '$res4': $out4"

# --- Case 5: a pathspec-only `git commit -- path` (this repo's mandated commit
# pattern — never `git add`, never a bare `git commit` on a shared index) must
# still be visible to the staged lane. Git builds a TEMPORARY index for exactly
# that partial commit and points GIT_INDEX_FILE at it while hooks run; a real
# pre-commit hook that captures LINT_CALLER_GIT_INDEX_FILE before stripping the
# raw variable (hooks/pre-commit's own pattern) must let run.py see the change.
CAPTURE_OUT=/tmp/lint-staged-scope-proof-capture.json
rm -f "$CAPTURE_OUT"
cat > "$W/.git/hooks/pre-commit" <<HOOK
#!/usr/bin/env bash
set -uo pipefail
export LINT_CALLER_GIT_INDEX_FILE="\${GIT_INDEX_FILE:-}"
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES 2>/dev/null || true
python3 "$RUN_PY" --root "$W" --check 50 --changed --staged --json > "$CAPTURE_OUT" 2>/dev/null
exit 0
HOOK
chmod +x "$W/.git/hooks/pre-commit"

git -C "$W" reset -q --hard >/dev/null
echo "hello v3 — pathspec-only, never git-added" > "$W/skills/demo/SKILL.md"
git -C "$W" status --short "$W/skills/demo/SKILL.md" | grep -q '^ M' \
  || bad "setup: expected an UNSTAGED modification before the pathspec commit"
git -C "$W" commit -q -m "pathspec-only commit, no prior add" -- "$W/skills/demo/SKILL.md" >/dev/null
res5=$(scope_of < "$CAPTURE_OUT" 2>/dev/null)
[ "$res5" = "ran" ] && ok "a pathspec-only commit (no prior git add) is still visible to the staged lane" \
                     || bad "expected the check to run under a pathspec-only commit, got '$res5': $(cat "$CAPTURE_OUT" 2>/dev/null)"
rm -f "$CAPTURE_OUT"

echo "---"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
