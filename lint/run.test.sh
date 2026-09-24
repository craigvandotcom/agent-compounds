#!/usr/bin/env bash
# lint/run.test.sh — proof harness for the whole-suite staged lane
# (lint/run.py --staged; W3 of the 2026-09-23 lint-system-upgrade plan).
#
# Replaces scripts/lint-staged-scope.test.sh (2026-09-12 lint audit, items
# 1 + 4), whose guarantees asserted the `--changed` scope-to-diff selection
# W3 deletes outright. There is no selection any more: one run always means
# the whole suite, on this machine and in CI. This harness proves that, plus
# what replaces the old selection machinery's real value.
#
# Builds a throwaway registry-shaped repo in a mktemp dir — never the real
# checkout — carrying a COPY of THIS repo's actual lint/run.py + lint/lib/*.py
# (so the exact code under review is what's exercised) plus a handful of tiny
# demo checks. Guarantees under test:
#
#   1. A staged run executes EVERY discovered check — none skipped for scope,
#      regardless of what the commit touches or what `scope:` a check
#      declares (the class of bug that let a one-file commit skip check 32
#      when only engine/hooks.wiring.json changed).
#   2. The staged lane judges the INDEX, not the working tree: a dirty,
#      UNSTAGED sibling file that would trip a check must never fail a commit
#      that never staged it (measured: FRICTIONS.md:711), while a bad thing
#      that IS staged still fails — materialisation is not an amnesty.
#   3. A pathspec-scoped `git commit -F msg -- path` (this repo's mandated
#      commit pattern — never `git add`, never a bare `git commit` on a
#      shared index) is still visible to the staged lane.
#   4. Adopter-local (gitignored) inputs — `.beads/issues.jsonl`,
#      `lint/instance-tokens.local.txt`, `_archive/`, an untracked
#      FRICTIONS.md under skills/, `machine.json` — are linked into the
#      staged snapshot read-only, so a check reading one sees it rather than
#      an artifact of the snapshot's tracked-only contents; a file already
#      TRACKED is never double-linked over (checkout-index already wrote it).
#   5. Exit-code precedence: a run with one FAIL (1) and one NOT-GATED (2)
#      check exits 1 (findings outrank a bare NOT-GATED); a run selecting
#      only a lone skip (77) check exits 0 (a skip never fails a run alone).
#
# Runs under bash. Exit 0 = every case passed.

set -uo pipefail

REGISTRY="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$REGISTRY/lint/run.py" ] || { echo "HARNESS FAIL: $REGISTRY/lint/run.py missing"; exit 1; }

PASS=0
FAIL=0
ok()  { PASS=$((PASS+1)); printf 'ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL %s\n' "$1"; }

W="$(mktemp -d)"
trap 'rm -rf "$W" "${CAPTURE_OUT:-}"' EXIT
mkdir -p "$W/lint/lib" "$W/lint/checks" "$W/skills/demo" "$W/skills/demo2" "$W/engine"

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

# Check B: scope LEDGER (deliberately NOT the set the staged file below
# belongs to) — reports only whether it RAN. Proves whole-suite execution:
# with no selection left, this must run regardless of scope or which file
# is staged — the "engine/hooks.wiring.json alone still runs check 32" class.
cat > "$W/lint/checks/32-demo-hooks.py" <<'PY'
#!/usr/bin/env python3
# ---
# id: 32-demo-hooks
# prevents: demo — proves the whole suite runs regardless of declared scope
#   or which file a commit touches (there is no scope-to-diff selection)
# scope: LEDGER
# severity: fail
# fixture: lint/checks/32-demo-hooks.py
# ---
import sys


def main():
    print("ok: 32-demo-hooks RAN")
    return 0


if __name__ == "__main__":
    sys.exit(main())
PY

# Check C: reads the adopter-local inputs directly off its `root` argument —
# proves materialize_staged() links them into the snapshot.
cat > "$W/lint/checks/55-demo-adopter-local.py" <<'PY'
#!/usr/bin/env python3
# ---
# id: 55-demo-adopter-local
# prevents: demo — proves adopter-local (gitignored) inputs are visible in
#   the staged snapshot
# scope: ALL
# severity: fail
# fixture: lint/checks/55-demo-adopter-local.py
# ---
import os
import sys


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    missing = []
    for rel in (".beads/issues.jsonl", "lint/instance-tokens.local.txt",
                "_archive/skills/retired/SKILL.md",
                "skills/demo2/FRICTIONS.md", "machine.json"):
        if not os.path.isfile(os.path.join(root, rel)):
            missing.append(rel)
    if missing:
        print("FAIL 55-demo-adopter-local: missing in snapshot: " + ", ".join(missing))
        return 1
    print("ok: 55-demo-adopter-local — every adopter-local input visible")
    return 0


if __name__ == "__main__":
    sys.exit(main())
PY

# Check D: a NOT-GATED check (exits 2, scanned nothing) — exit-precedence case.
cat > "$W/lint/checks/56-demo-notgated.py" <<'PY'
#!/usr/bin/env python3
# ---
# id: 56-demo-notgated
# prevents: demo — always reports NOT-GATED
# scope: LEDGER
# severity: fail
# fixture: lint/checks/56-demo-notgated.py
# ---
import sys


def main():
    print("56-demo-notgated NOT-CHECKED: nothing scanned", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
PY

# Check E: an honest skip (exit 77) — must never fail a run alone.
cat > "$W/lint/checks/57-demo-skip.py" <<'PY'
#!/usr/bin/env python3
# ---
# id: 57-demo-skip
# prevents: demo — always reports an honest skip (its own adopter-local
#   input is absent)
# scope: LEDGER
# severity: fail
# fixture: lint/checks/57-demo-skip.py
# ---
import sys


def main():
    print("57-demo-skip skipped: demo input absent", file=sys.stderr)
    return 77


if __name__ == "__main__":
    sys.exit(main())
PY

echo "hello" > "$W/skills/demo/SKILL.md"
echo "hello" > "$W/skills/demo2/SKILL.md"
echo "{}" > "$W/engine/hooks.wiring.json"
git -C "$W" add \
  "$W/lint/checks/50-demo-token.py" "$W/lint/checks/32-demo-hooks.py" \
  "$W/lint/checks/55-demo-adopter-local.py" "$W/lint/checks/56-demo-notgated.py" \
  "$W/lint/checks/57-demo-skip.py" \
  "$W/skills/demo/SKILL.md" "$W/skills/demo2/SKILL.md" "$W/engine/hooks.wiring.json"
git -C "$W" commit -qm base >/dev/null

run_new() { ( cd "$W" && python3 "$RUN_PY" --root "$W" "$@" ); }
exit_of() { python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["checks"][0]["exit"])' 2>/dev/null; }
ids_of()  { python3 -c 'import json,sys; d=json.load(sys.stdin); print(",".join(sorted(c["id"] for c in d["checks"])))' 2>/dev/null; }

# --- Case 1: a staged run touching ONLY engine/hooks.wiring.json still runs
# EVERY discovered check, including the scope-LEDGER demo check named for
# check 32 — no selection reads `scope:` any more.
git -C "$W" reset -q --hard >/dev/null
echo '{"v": 2}' > "$W/engine/hooks.wiring.json"
git -C "$W" add "$W/engine/hooks.wiring.json"
out1=$(run_new --staged --json)
ids1=$(echo "$out1" | ids_of)
want1="32-demo-hooks,50-demo-token,55-demo-adopter-local,56-demo-notgated,57-demo-skip"
[ "$ids1" = "$want1" ] && ok "a staged commit touching only engine/hooks.wiring.json runs EVERY check (incl. 32-demo-hooks)" \
                         || bad "expected every check to run ($want1), got '$ids1': $out1"

# --- Case 2: an unstaged dirty sibling must not leak into the staged lane ---
git -C "$W" reset -q --hard >/dev/null
echo "hello v2 — a real, clean edit" > "$W/skills/demo/SKILL.md"
git -C "$W" add "$W/skills/demo/SKILL.md"
echo "BANNEDTOKEN here" >> "$W/skills/demo2/SKILL.md"   # UNSTAGED dirty sibling
out2=$(run_new --check 50 --staged --json)
rc2=$(echo "$out2" | exit_of)
[ "$rc2" = "0" ] && ok "unstaged dirty sibling never leaks into the staged lane (rc=$rc2)" \
                  || bad "expected PASS (rc=0) with an unstaged sibling dirtied, got rc='$rc2': $out2"

# --- Case 3: the bad thing IS staged -> still fails, materialisation is not an amnesty ---
git -C "$W" add "$W/skills/demo2/SKILL.md"
out3=$(run_new --check 50 --staged --json)
rc3=$(echo "$out3" | exit_of)
[ "$rc3" = "1" ] && ok "staged BANNEDTOKEN still FAILS once it is actually staged" \
                  || bad "expected FAIL (rc=1) once staged, got rc='$rc3': $out3"

# --- Case 4: a pathspec-only `git commit -- path` (never `git add`, never a
# bare `git commit` on a shared index) must still be visible to the staged
# lane — git builds a TEMPORARY index for exactly that partial commit.
git -C "$W" reset -q --hard >/dev/null
CAPTURE_OUT="$(mktemp)"
cat > "$W/.git/hooks/pre-commit" <<HOOK
#!/usr/bin/env bash
set -uo pipefail
export LINT_CALLER_GIT_INDEX_FILE="\${GIT_INDEX_FILE:-}"
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES 2>/dev/null || true
python3 "$RUN_PY" --root "$W" --check 32 --staged --json > "$CAPTURE_OUT" 2>/dev/null
exit 0
HOOK
chmod +x "$W/.git/hooks/pre-commit"
echo "hello v3 — pathspec-only, never git-added" > "$W/skills/demo/SKILL.md"
git -C "$W" status --short "$W/skills/demo/SKILL.md" | grep -q '^ M' \
  || bad "setup: expected an UNSTAGED modification before the pathspec commit"
git -C "$W" commit -q -m "pathspec-only commit, no prior add" -- "$W/skills/demo/SKILL.md" >/dev/null
res4=$(exit_of < "$CAPTURE_OUT" 2>/dev/null)
[ "$res4" = "0" ] && ok "a pathspec-only commit (no prior git add) is still visible to the staged lane" \
                   || bad "expected the check to run (rc=0) under a pathspec-only commit, got '$res4': $(cat "$CAPTURE_OUT" 2>/dev/null)"
rm -f "$CAPTURE_OUT"

# --- Case 5: adopter-local (gitignored) inputs are visible in the snapshot ---
mkdir -p "$W/.beads" "$W/_archive/skills/retired" "$W/skills/demo2"
echo '{"id":"x-1"}' > "$W/.beads/issues.jsonl"
echo "bannedword" > "$W/lint/instance-tokens.local.txt"
echo "# retired" > "$W/_archive/skills/retired/SKILL.md"
echo "# friction" > "$W/skills/demo2/FRICTIONS.md"
echo '{"org_root":"'"$W"'"}' > "$W/machine.json"
git -C "$W" reset -q --hard >/dev/null
echo "hello v4" > "$W/skills/demo/SKILL.md"
git -C "$W" add "$W/skills/demo/SKILL.md"
out5=$(run_new --check 55 --staged --json)
rc5=$(echo "$out5" | exit_of)
[ "$rc5" = "0" ] && ok "adopter-local inputs (.beads, instance tokens, _archive/, FRICTIONS.md, machine.json) are linked into the staged snapshot" \
                  || bad "expected every adopter-local input visible (rc=0), got rc='$rc5': $out5"

# --- Case 6: exit-code precedence — a FAIL (1) outranks a NOT-GATED (2) in
# the same run; a lone SKIP (77) never fails a run alone (exits 0). ---
git -C "$W" reset -q --hard >/dev/null
echo "BANNEDTOKEN staged for case 6" >> "$W/skills/demo2/SKILL.md"
git -C "$W" add "$W/skills/demo2/SKILL.md"
out6=$(run_new --check 50 --check 56 --staged --json)
rc6=$?
[ "$rc6" = "1" ] && ok "a FAIL check outranks a NOT-GATED check in the same run (rc=1)" \
                  || bad "expected rc=1 (FAIL outranks NOT-GATED), got rc='$rc6': $out6"

run_new --check 57 --staged >/dev/null 2>&1
rc7=$?
[ "$rc7" = "0" ] && ok "a lone SKIP (77) check never fails a run alone (rc=0)" \
                  || bad "expected rc=0 for a lone skip, got rc='$rc7'"

echo "---"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
