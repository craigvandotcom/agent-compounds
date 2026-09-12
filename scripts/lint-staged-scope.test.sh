#!/usr/bin/env bash
# lint-staged-scope.test.sh — proof harness for the pre-commit staged lane
# (lint/run.py --changed --staged; 2026-09-12 lint audit, items 1 + 4).
#
# Builds a throwaway registry-shaped repo in /tmp — never the real checkout —
# carrying a COPY of THIS repo's actual lint/run.py + lint/lib/*.py (so the
# exact code under review is what's exercised) plus a handful of tiny demo
# checks. Guarantees under test:
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
#   3. A `scope:` header naming SEVERAL sets (whitespace/comma-separated) is
#      resolved as a UNION by the runner's own token-by-token lookup, not by
#      depending on some precomputed alias for that exact combination — a
#      change under only ONE of the named sets still selects the check, and a
#      change under NEITHER still skips it.
#   4. An unresolvable scope token is a LOUD runner error (NOT-GATED, exit 2,
#      naming the check and the bad token) — never a silent skip, whether or
#      not any file changed.
#   5. lint/config.json in the diff bypasses scope filtering for every OTHER
#      selected check (config can retune any check's thresholds at runtime),
#      while a check declaring `changed: skip` stays skipped regardless —
#      the config bypass is not a license to ignore that escape hatch.
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

# Check C: scope names TWO real sets (`LEDGER TEMPLATES`) that share no
# precomputed alias in lib.scope — proves the runner's own token-by-token
# union, not a hardcoded combination string.
cat > "$W/lint/checks/52-demo-multiscope.py" <<'PY'
#!/usr/bin/env python3
# ---
# id: 52-demo-multiscope
# prevents: demo — proves a multi-name `scope:` header resolves as a union
# scope: LEDGER TEMPLATES
# severity: fail
# fixture: lint/checks/52-demo-multiscope.py
# ---
import sys


def main():
    print("ok: 52-demo-multiscope RAN")
    return 0


if __name__ == "__main__":
    sys.exit(main())
PY

# Check D: an unresolvable scope token — must be a loud runner error, never a
# silent skip.
cat > "$W/lint/checks/53-demo-badscope.py" <<'PY'
#!/usr/bin/env python3
# ---
# id: 53-demo-badscope
# prevents: demo — proves an unresolvable scope name fails loudly
# scope: LIVE_TEXT NOT_A_REAL_SCOPE_NAME
# severity: fail
# fixture: lint/checks/53-demo-badscope.py
# ---
import sys


def main():
    print("ok: 53-demo-badscope RAN (should never print — the runner must error first)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
PY

# Check E: scope LEDGER, `changed: skip` — must stay skipped even when
# lint/config.json is in the diff (the config bypass is not a license to
# ignore an explicit changed:skip escape hatch).
cat > "$W/lint/checks/54-demo-changed-skip.py" <<'PY'
#!/usr/bin/env python3
# ---
# id: 54-demo-changed-skip
# prevents: demo — proves changed:skip survives the config-bypass rule
# scope: LEDGER
# changed: skip
# severity: fail
# fixture: lint/checks/54-demo-changed-skip.py
# ---
import sys


def main():
    print("ok: 54-demo-changed-skip RAN")
    return 0


if __name__ == "__main__":
    sys.exit(main())
PY

echo "hello" > "$W/skills/demo/SKILL.md"
echo "hello" > "$W/skills/demo2/SKILL.md"
mkdir -p "$W/templates"
echo "template" > "$W/templates/probe.md"
echo "{}" > "$W/lint/config.json"
git -C "$W" add \
  "$W/lint/checks/50-demo-token.py" "$W/lint/checks/51-demo-ledger.py" \
  "$W/lint/checks/52-demo-multiscope.py" "$W/lint/checks/53-demo-badscope.py" \
  "$W/lint/checks/54-demo-changed-skip.py" \
  "$W/skills/demo/SKILL.md" "$W/skills/demo2/SKILL.md" \
  "$W/templates/probe.md" "$W/lint/config.json"
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

# --- Case 6a: a multi-name `scope:` header (`LEDGER TEMPLATES`) is selected by
# a change under ONLY ONE of the named sets — the runner's own token-by-token
# union, not a hardcoded alias for this exact two-word combination (no such
# alias exists in lib.scope; only the real registry's six wired headers get
# one, purely for 00-meta.py's benefit — see lib/scope.py's own comment).
git -C "$W" reset -q --hard >/dev/null
echo "template v2" > "$W/templates/probe.md"
git -C "$W" add "$W/templates/probe.md"
out6a=$(run_new --check 52 --changed --staged --json)
res6a=$(echo "$out6a" | scope_of)
[ "$res6a" = "ran" ] && ok "multi-name scope 'LEDGER TEMPLATES' runs on a TEMPLATES-only hit" \
                      || bad "expected the check to run on a TEMPLATES hit, got '$res6a': $out6a"

# --- Case 6b: the same multi-name header is SKIPPED when the change is under
# NEITHER named set — the union must not degrade to "always run".
git -C "$W" reset -q --hard >/dev/null
echo "hello v4" > "$W/skills/demo/SKILL.md"
git -C "$W" add "$W/skills/demo/SKILL.md"
out6b=$(run_new --check 52 --changed --staged --json)
res6b=$(echo "$out6b" | scope_of)
[ "$res6b" = "LEDGER TEMPLATES" ] && ok "multi-name scope 'LEDGER TEMPLATES' skips a hit under neither set" \
                      || bad "expected skipped_scope='LEDGER TEMPLATES', got '$res6b': $out6b"

# --- Case 7: an unresolvable scope token is a LOUD runner error (NOT-GATED,
# exit 2, naming both the check and the bad token) — never a silent skip. No
# --json here: main() returns 2 before any JSON is ever printed on this path.
git -C "$W" reset -q --hard >/dev/null
echo "hello v5" > "$W/skills/demo/SKILL.md"
git -C "$W" add "$W/skills/demo/SKILL.md"
out7=$(run_new --check 53 --changed --staged 2>&1)
rc7=$?
if [ "$rc7" = "2" ] && printf '%s' "$out7" | grep -q "NOT-GATED" \
   && printf '%s' "$out7" | grep -q "NOT_A_REAL_SCOPE_NAME" \
   && printf '%s' "$out7" | grep -q "53-demo-badscope"; then
  ok "an unresolvable scope token is a loud NOT-GATED error (rc=2), naming the check and the bad token"
else
  bad "expected a loud NOT-GATED rc=2 naming the check + bad token, got rc='$rc7': $out7"
fi

# --- Case 8a: lint/config.json in the diff bypasses scope filtering for a
# check with no config-plumbing of its own — one file can retune several
# checks' thresholds at runtime, so its presence in the diff runs everything.
git -C "$W" reset -q --hard >/dev/null
echo '{"probe": true}' > "$W/lint/config.json"
git -C "$W" add "$W/lint/config.json"
out8a=$(run_new --check 51 --changed --staged --json)
res8a=$(echo "$out8a" | scope_of)
[ "$res8a" = "ran" ] && ok "lint/config.json in the diff runs a scope-LEDGER check with no LEDGER file staged" \
                      || bad "expected the config bypass to run the check, got '$res8a': $out8a"

# --- Case 8b: ...but a check declaring `changed: skip` stays skipped even
# when lint/config.json is in the diff — the bypass is not a license to
# override that explicit escape hatch.
out8b=$(run_new --check 54 --changed --staged --json)
res8b=$(echo "$out8b" | scope_of)
[ "$res8b" = "changed:skip" ] && ok "changed:skip still holds even with lint/config.json in the diff" \
                      || bad "expected skipped_scope='changed:skip', got '$res8b': $out8b"

echo "---"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
