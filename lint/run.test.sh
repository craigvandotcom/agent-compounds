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
#   6. The front door itself (`lint.sh`, not `lint/run.py`) survives a
#      literal top-level SyntaxError in the WORKING TREE's lint/run.py on a
#      `--staged` run: lint.sh's own first hop extracts the INDEX's
#      lint/run.py + lint/lib + lint/checks via git (never parses Python)
#      before ever touching the working tree's copy.
#
# Runs under bash. Exit 0 = every case passed.

set -uo pipefail

REGISTRY="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$REGISTRY/lint/run.py" ] || { echo "HARNESS FAIL: $REGISTRY/lint/run.py missing"; exit 1; }
[ -f "$REGISTRY/lint.sh" ] || { echo "HARNESS FAIL: $REGISTRY/lint.sh missing"; exit 1; }

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
cp "$REGISTRY/lint/lib/verdict.py" "$W/lint/lib/verdict.py"
cp "$REGISTRY/lint.sh" "$W/lint.sh"
RUN_PY="$W/lint/run.py"
LINT_SH="$W/lint.sh"

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
run_lintsh() { ( cd "$W" && bash "$LINT_SH" "$@" ); }
exit_of() { python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["checks"][0]["exit"])' 2>/dev/null; }
result_of() { python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["checks"][0]["result"])' 2>/dev/null; }
ids_of()  { python3 -c 'import json,sys; d=json.load(sys.stdin); print(",".join(sorted(c["id"] for c in d["checks"])))' 2>/dev/null; }
findings_of() { python3 -c 'import json,sys; d=json.load(sys.stdin); print("\n".join(d["checks"][0]["findings"]))' 2>/dev/null; }

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

# --- Case 8: an untracked check in the working tree is not part of the commit ---
printf '#!/usr/bin/env python3\nimport sys\nsys.exit(1)\n' > "$W/lint/checks/59-untracked.py"
out8=$(run_new --staged --json 2>/dev/null)
if echo "$out8" | grep -q '59-untracked'; then
  bad "an untracked check ran in the staged lane: $out8"
else
  ok "an untracked working-tree check never judges a staged commit"
fi
rm -f "$W/lint/checks/59-untracked.py"

# --- Case 9: a crash fails the run and its traceback is kept; an exit outside the
# 0/1/2/77 contract (a timeout, a killed process) fails the run too, never a pass ---
printf '#!/usr/bin/env python3\nraise RuntimeError("crash-marker")\n' > "$W/lint/checks/58-crash.py"
out9=$(run_new --check 58 --json 2>/dev/null); rc9=$?
if [ "$rc9" = "1" ] && echo "$out9" | grep -q 'crash-marker'; then
  ok "a crashing check fails the run (rc=1) and its traceback is reported"
else
  bad "expected rc=1 with the traceback, got rc='$rc9': $out9"
fi
rm -f "$W/lint/checks/58-crash.py"
printf '#!/usr/bin/env python3\nimport sys\nsys.exit(5)\n' > "$W/lint/checks/53-odd-exit.py"
out10=$(run_new --check 53 --json 2>/dev/null); rc10=$?
result10=$(echo "$out10" | result_of)
if [ "$rc10" = "1" ] && [ "$result10" = "error" ]; then
  ok "an exit outside the contract (5) rows as 'error' and fails the run (rc=1)"
else
  bad "expected rc=1 and result='error' for exit 5, got rc='$rc10' result='$result10': $out10"
fi
rm -f "$W/lint/checks/53-odd-exit.py"

# --- Case 11: a working-tree check absent from the staged snapshot (never
# `git add`-ed) is no longer silently dropped — a NOTICE names it ---
git -C "$W" reset -q --hard >/dev/null
printf '#!/usr/bin/env python3\nimport sys\nsys.exit(1)\n' > "$W/lint/checks/59-untracked.py"
out11=$(run_new --staged --json 2>&1 >/dev/null)
if echo "$out11" | grep -q 'NOTICE: not staged, not run:.*59-untracked'; then
  ok "an untracked check absent from the staged snapshot is named in a NOTICE"
else
  bad "expected a NOTICE naming 59-untracked, got: $out11"
fi
rm -f "$W/lint/checks/59-untracked.py"

# --- Case 12: a LINT_CALLER_GIT_INDEX_FILE naming a file that no longer
# exists is dropped with a NOTICE, and the staged snapshot is still built
# from the REAL index (not the empty tree a dangling GIT_INDEX_FILE would
# otherwise silently produce) — a staged check still sees the staged file ---
git -C "$W" reset -q --hard >/dev/null
echo "BANNEDTOKEN staged for case 12" >> "$W/skills/demo2/SKILL.md"
git -C "$W" add "$W/skills/demo2/SKILL.md"
CAP_OUT="$(mktemp)"; CAP_ERR="$(mktemp)"
LINT_CALLER_GIT_INDEX_FILE="$W/.git/nonexistent-caller-index" \
  run_new --check 50 --staged --json >"$CAP_OUT" 2>"$CAP_ERR"
notice12=$(grep -c 'NOTICE: LINT_CALLER_GIT_INDEX_FILE does not exist' "$CAP_ERR")
result12=$(result_of < "$CAP_OUT")
if [ "$notice12" -ge 1 ] && [ "$result12" = "fail" ]; then
  ok "a nonexistent LINT_CALLER_GIT_INDEX_FILE is dropped with a NOTICE, and a staged check still sees the staged file (built from the real index)"
else
  bad "expected a NOTICE + result=fail (staged content seen via the real index), got notice_count=$notice12 result='$result12': stderr=$(cat "$CAP_ERR") stdout=$(cat "$CAP_OUT")"
fi
rm -f "$CAP_OUT" "$CAP_ERR"

# --- Case 13: the staged snapshot lives under $XDG_CACHE_HOME/ac-lint (or
# ~/.cache/ac-lint as its fallback) — never /tmp (an orphan from a killed run
# would sit in a shared, quota-limited dir) and never nested inside the
# checkout (a snapshot nested under the checkout's own gitignored scratch
# space is still walked UP INTO by a check's `git ls-files` call: discovery
# finds the REAL repo and `--exclude-standard` reports an empty, ignored
# tree instead of failing outright — measured: this broke checks 27/28/30's
# fixture legs when the snapshot lived under `<root>/_scratch/`). ---
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/ac-lint"
git -C "$W" reset -q --hard >/dev/null
printf '#!/usr/bin/env python3\n# ---\n# id: 60-demo-root\n# prevents: demo -- reports its own resolved root so the harness can\n#   assert WHERE the staged snapshot lives\n# scope: LEDGER\n# severity: fail\n# fixture: lint/checks/60-demo-root.py\n# ---\nimport os, sys\nprint("ROOT:" + os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else "."))\nsys.exit(1)\n' > "$W/lint/checks/60-demo-root.py"
git -C "$W" add "$W/lint/checks/60-demo-root.py"
out13=$(run_new --check 60 --staged --json)
root13=$(echo "$out13" | findings_of | sed -n 's/^ROOT://p')
case "$root13" in
  "$CACHE_DIR"/*) ok "a staged run's snapshot lives under \$XDG_CACHE_HOME (or ~/.cache)'s ac-lint dir, never /tmp and never nested in the checkout (got: $root13)" ;;
  /tmp/*) bad "the staged snapshot is still under /tmp: $root13" ;;
  "$W"/*) bad "the staged snapshot is nested INSIDE the checkout (breaks TRACKED/COMMITTABLE checks' git ls-files fallback): $root13" ;;
  *) bad "expected the staged snapshot under $CACHE_DIR, got '$root13': $out13" ;;
esac
rm -f "$W/lint/checks/60-demo-root.py"

# --- Case 14: a broken WORKING-TREE lint/run.py never blocks a --staged run
# once a valid lint/run.py (and its lint/lib) is staged. The pre-commit gate
# (hooks/pre-commit -> lint.sh -> the WORKING-TREE lint/run.py) must judge a
# commit with the STAGED snapshot's own runner, not this process's possibly
# half-edited on-disk copy — the bug this bead fixes.
#
# The break lives inside run_check() (a runtime AttributeError, reached only
# if that function is actually CALLED) rather than a literal top-level
# SyntaxError: an unparseable syntax error stops `python3 lint/run.py` from
# launching at all, before ANY code in that same file — including a fix
# living in that file — gets a chance to run; no in-file delegation can
# rescue that. This proves the equivalent property for the code that DOES
# execute once argument parsing succeeds: the STAGED runner is what decides
# the commit, and the working tree's own (broken) check-execution path is
# never reached.
git -C "$W" reset -q --hard >/dev/null
git -C "$W" add "$W/lint/run.py" "$W/lint/lib/scope.py" "$W/lint/lib/frontmatter.py" "$W/lint/lib/verdict.py"
python3 - "$W/lint/run.py" <<'PYEOF'
import sys
path = sys.argv[1]
text = open(path).read()
marker = "proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, env=env)"
assert marker in text, "run_check()'s subprocess call moved — update case 14's break"
open(path, "w").write(text.replace(marker, marker.replace("subprocess.run(", "subprocess.rn_BROKEN(")))
PYEOF
out14=$(run_new --check 50 --staged --json 2>/dev/null); rc14=$?
res14=$(echo "$out14" | result_of)
if [ "$rc14" = "0" ] && [ "$res14" = "ok" ]; then
  ok "a broken WORKING-TREE lint/run.py never blocks a --staged run once a valid lint/run.py is staged"
else
  bad "expected rc=0 result=ok despite the broken working-tree runner, got rc='$rc14' result='$res14': $out14"
fi

# --- Case 15: the STAGED lint/run.py's own behaviour is what a --staged run
# shows, not the working tree's copy — the STAGED copy's label for one check
# is made observably different, and that (not the plain working-tree copy's
# label) is what appears.
git -C "$W" reset -q --hard >/dev/null
cp "$REGISTRY/lint/lib/scope.py" "$REGISTRY/lint/lib/frontmatter.py" "$REGISTRY/lint/lib/verdict.py" "$W/lint/lib/"
cp "$REGISTRY/lint/run.py" "$W/lint/run.py"
python3 - "$W/lint/run.py" <<'PYEOF'
import sys
path = sys.argv[1]
text = open(path).read()
marker = 'r["result"] = verdict.label(r["exit"])'
assert marker in text, "results-labeling line moved — update case 15's marker"
text = text.replace(
    marker,
    marker + '\n        if r["id"] == "50-demo-token":\n            r["result"] = "staged-marker"',
)
open(path, "w").write(text)
PYEOF
git -C "$W" add "$W/lint/run.py" "$W/lint/lib/scope.py" "$W/lint/lib/frontmatter.py" "$W/lint/lib/verdict.py"
cp "$REGISTRY/lint/run.py" "$W/lint/run.py"   # working tree reverts to the PLAIN copy; the index keeps the marker version
out15=$(run_new --check 50 --staged --json)
res15=$(echo "$out15" | result_of)
outctl15=$(run_new --check 50 --json)
resctl15=$(echo "$outctl15" | result_of)
if [ "$res15" = "staged-marker" ] && [ "$resctl15" = "ok" ]; then
  ok "a --staged run shows the STAGED lint/run.py's own (observably different) label, not the plain working-tree copy's"
else
  bad "expected staged='staged-marker' working-tree='ok', got staged='$res15' working-tree='$resctl15': $out15 / $outctl15"
fi

# --- Case 16: the FRONT DOOR itself (lint.sh, not lint/run.py) survives a
# literal top-level SyntaxError in the WORKING-TREE lint/run.py on a
# --staged run. Case 14 proves the equivalent property for code that DOES
# parse (a runtime break reachable only once argument parsing succeeds) and
# explains why a fix living INSIDE run.py can never rescue an unparseable
# file — python3 cannot even launch it, so no in-file delegation logic gets
# a turn. The fix for THIS case lives in lint.sh's own first hop (bash,
# which never parses run.py): it extracts the INDEX's lint/run.py +
# lint/lib + lint/checks via git before the working tree's (possibly
# broken) run.py is ever exec'd — this case is why it drives lint.sh
# directly rather than lint/run.py.
git -C "$W" reset -q --hard >/dev/null
cp "$REGISTRY/lint/run.py" "$W/lint/run.py"
cp "$REGISTRY/lint/lib/scope.py" "$REGISTRY/lint/lib/frontmatter.py" "$REGISTRY/lint/lib/verdict.py" "$W/lint/lib/"
git -C "$W" add "$W/lint/run.py" "$W/lint/lib/scope.py" "$W/lint/lib/frontmatter.py" "$W/lint/lib/verdict.py"
printf '\ndef broken(:\n' >> "$W/lint/run.py"   # literal top-level SyntaxError in the WORKING TREE only, never staged
if python3 -c "import ast; ast.parse(open('$W/lint/run.py').read())" 2>/dev/null; then
  bad "case 16 setup: expected the working-tree lint/run.py to be unparseable"
fi
out16=$(run_lintsh --check 50 --staged --json 2>/dev/null); rc16=$?
res16=$(echo "$out16" | result_of)
if [ "$rc16" = "0" ] && [ "$res16" = "ok" ]; then
  ok "bash lint.sh --staged survives a literal SyntaxError in the WORKING-TREE lint/run.py once a valid lint/run.py is staged"
else
  bad "expected rc=0 result=ok despite the syntax-broken working-tree runner, got rc='$rc16' result='$res16': $out16"
fi

echo "---"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
