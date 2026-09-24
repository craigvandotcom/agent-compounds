#!/usr/bin/env bash
# 28-citations.test.sh — the contract harness for lint/checks/28-citations.py.
#
#   Five citation forms share one test suite: invoke (/ac-x), path (three
#   grammar forms + wiring prose), stance (subagent spawn language), bare-ac
#   (wiring prose only) and the inverse (orphan references). Every case
#   builds its own throwaway tree so assertions cannot drift with the live
#   registry's citations. The committed static fixture proves the RED leg
#   00-meta.py requires; every other case proves a specific form or a
#   specific allowlist/ratchet rule.
#
# ASSURANCE
#   PROBE:    bash lint/checks/28-citations.test.sh
#   SCHEDULE: scripts/run-all-proofs.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/28-citations.py"
ROOT="$(cd "$HERE/../.." && pwd)"

FAILURES=0
pass() { echo "  PASS $1"; }
fail() { echo "  FAIL $1 (rc=$RC want=$2)"; echo "$OUT"; FAILURES=$((FAILURES + 1)); }
# <label> <want-rc> [grep-pattern] — asserts the last `run`'s $RC/$OUT
case_() {
  if [ "$RC" = "$2" ] && { [ -z "${3:-}" ] || echo "$OUT" | grep -q "$3"; }; then
    pass "$1"
  else
    fail "$1" "$2"
  fi
}

[ -f "$CHECK" ] || { echo "HARNESS FAIL: missing $CHECK"; exit 1; }

new_tree() { mktemp -d "${TMPDIR:-/tmp}/c28c-XXXXXX"; }
mk() { mkdir -p "$(dirname "$1")" && cat > "$1"; }
run() { OUT="$(python3 "$CHECK" "${1:-$TREE}" 2>&1)"; RC=$?; }

mkroot() { # <dir> — a minimal agents/ roster (researcher, implementer) any case can extend
  local d="$1"
  mkdir -p "$d/agents"
  printf -- '---\nname: researcher\ntier: coordinator\n---\nbody\n' > "$d/agents/researcher.md"
  printf -- '---\nname: implementer\ntier: worker\n---\nbody\n' > "$d/agents/implementer.md"
}

write_manifest() { # <root> <doc> <backstop> <pending> — engine/hooks.wiring.json + skills/real/
  local root="$1" doc="$2" backstop="$3" pending="$4"
  mkdir -p "$root/engine" "$root/skills/real"
  printf -- '---\nname: real\ndescription: "the one live skill"\n---\n\n# real\n' \
    > "$root/skills/real/SKILL.md"
  cat > "$root/engine/hooks.wiring.json" <<EOF
{"wiring": [{"id": "demo", "_doc": "$doc",
  "assurance": {"PROBE": "p", "SCHEDULE": "s", "MODE": "advisory", "ON-FAILURE": "open",
                "BACKSTOP": "$backstop", "PENDING-DECISION": "$pending"}}]}
EOF
}

build_inverse_tree() { # <root> — skill-a points at used.md (scoped); orphan.md points at nothing
  mkroot "$1"
  mkdir -p "$1/skills/skill-a/references"
  printf '%s\n' '# skill-a' '' 'Use `references/used.md` for the recipe.' \
    > "$1/skills/skill-a/SKILL.md"
  printf '# used\n' > "$1/skills/skill-a/references/used.md"
  printf '# orphan\n' > "$1/skills/skill-a/references/orphan.md"
}

T="$(new_tree)"; trap 'rm -rf "$T"' EXIT

# --- committed static fixture — the RED leg 00-meta.py's fixture contract needs --
run "$ROOT/lint/fixtures/28-citations"
case_ "FIXTURE: committed static fixture -> exit 1, missing path named" 1 \
  "skills/demo/SKILL.md:8 cites 'skills/demo/references/missing.md'"

# --- invoke form (from check 2) ---------------------------------------------
TREE="$T/invoke-red"; mkroot "$TREE"
mk "$TREE/skills/real-skill/SKILL.md" <<'EOF'
Run `/ac-plan` first; `/ac-ghost-skill` does not exist as a dir.
Glob only: `/ac-nonexistent-glob-*` is a shorthand, not an invocation.
Path segments are not invocations: `/tmp/ac-claim.txt` and `scripts/ac-thing.sh`.
Sed address `/ac-example-bead:start` is not a skill call.
EOF
mkdir -p "$TREE/skills/ac-plan"
run
case_ "INVOKE RED: /ac-ghost-skill has no skills/ dir" 1 \
  "invoke: /ac-ghost-skill referenced but skills/ac-ghost-skill/ does not exist"

TREE="$T/invoke-green"; mkroot "$TREE"
mk "$TREE/skills/clean/SKILL.md" <<'EOF'
See /tmp/ac-claim.txt, scripts/ac-thing.sh, /ac-example-bead:start, /ac-never-made-*.
EOF
run
case_ "INVOKE GREEN: path segments / glob shorthand / sed address do not fire" 0

# --- path form (from check 28) ----------------------------------------------
TREE="$T/path-red"; mkroot "$TREE"
mk "$TREE/skills/demo/SKILL.md" <<'EOF'
See `skills/demo/references/missing.md` for the detail.
EOF
mk "$TREE/skills/demo/references/other.md" <<'EOF'
present
EOF
run
case_ "PATH RED: a citation to a nonexistent file fails, named" 1 \
  "path:.*cites 'skills/demo/references/missing.md' — no such file"

TREE="$T/path-form2"; mkroot "$TREE"
mk "$TREE/skills/citer/SKILL.md" <<'EOF'
See `demo/references/real.md`.
EOF
mk "$TREE/skills/demo/references/real.md" <<'EOF'
present
EOF
run
case_ "PATH GREEN: form-2 <skill>/references/<f> resolves via skills/" 0

# allowlist keys below deliberately avoid the skills/**/references-shaped
# form (that shape reads as an ORPHAN admission — see is_governed_shape) so
# these two cases test the PATH admission class cleanly.
TREE="$T/path-allow"; mkroot "$TREE"; mkdir -p "$TREE/lint/allowlists" "$TREE/hooks"
mk "$TREE/skills/demo/SKILL.md" <<'EOF'
See `hooks/gone-script.sh`.
EOF
mk "$TREE/lint/allowlists/28-citations.txt" <<EOF
2026-09-07 hooks/gone-script.sh
EOF
run
case_ "PATH ALLOWLIST: a dated allowlist entry admits its dangling path" 0

TREE="$T/path-shrink"; mkroot "$TREE"; mkdir -p "$TREE/lint/allowlists" "$TREE/hooks"
mk "$TREE/skills/demo/SKILL.md" <<'EOF'
# demo — no citations here, just enough live text to be scanned.
EOF
mk "$TREE/hooks/real-script.sh" <<'EOF'
#!/bin/sh
EOF
mk "$TREE/lint/allowlists/28-citations.txt" <<EOF
2026-09-07 hooks/real-script.sh
EOF
run
case_ "PATH SHRINK: a stale allowlist entry (path now resolves) fails shrink-only" 1 "delete the line"

TREE="$T/path-false-positive"; mkroot "$TREE"
mk "$TREE/skills/demo/SKILL.md" <<'EOF'
Longer-path form: `.claude/skills/elsewhere/SKILL.md`.
Archive form: `_archive/skills/demo/SKILL.md`.
Full skill-name citation: `ac-demo/references/real.md`.
Dir-only: `skills/other` and bare `lint.sh`.
EOF
mk "$TREE/skills/ac-demo/references/real.md" <<'EOF'
present
EOF
mk "$TREE/skills/demo/references/real.md" <<'EOF'
present
EOF
run
case_ "PATH GREEN: longer-path, archive, substring and dir-only forms are not citations" 0

TREE="$T/path-corpus"; mkroot "$TREE"; mkdir -p "$TREE/skills/skill-builder/references"
mk "$TREE/skills/skill-builder/references/trigger-corpus.md" <<'EOF'
Cites `skills/nothing/references/absent.md` freely.
EOF
mk "$TREE/skills/skill-builder/SKILL.md" <<'EOF'
See `references/trigger-corpus.md` for the pattern catalog.
EOF
mk "$TREE/skills/demo/SKILL.md" <<'EOF'
See `skills/demo/references/real.md`.
EOF
mk "$TREE/skills/demo/references/real.md" <<'EOF'
present
EOF
run
case_ "PATH GREEN: the trigger corpus is exempt from path resolution" 0

TREE="$T/path-malformed"; mkroot "$TREE"; mkdir -p "$TREE/lint/allowlists"
mk "$TREE/skills/demo/SKILL.md" <<'EOF'
See `skills/demo/references/real.md`.
EOF
mk "$TREE/skills/demo/references/real.md" <<'EOF'
present
EOF
mk "$TREE/lint/allowlists/28-citations.txt" <<EOF
skills/gone/references/old.md
EOF
run
case_ "PATH RED: an undated allowlist line is a malformed-entry defect" 1 'not `YYYY-MM-DD key'

TREE="$T/path-form3-ok"; mkroot "$TREE"; mkdir -p "$TREE/engine"
mk "$TREE/skills/demo/SKILL.md" <<'EOF'
See `engine/wiring.json` for the manifest.
EOF
mk "$TREE/engine/wiring.json" <<'EOF'
{}
EOF
run
case_ "PATH GREEN: a root-relative top-level-dir citation (engine/wiring.json) resolves" 0

TREE="$T/path-form3-red"; mkroot "$TREE"; mkdir -p "$TREE/engine"
mk "$TREE/skills/demo/SKILL.md" <<'EOF'
See `engine/missing.json` for the manifest.
EOF
run
case_ "PATH RED: a missing root-relative top-level-dir citation fails, named" 1 "engine/missing.json"

TREE="$T/path-form3-any-skill"; mkroot "$TREE"
mkdir -p "$TREE/tools" "$TREE/skills/citer" "$TREE/skills/owner/tools"
mk "$TREE/skills/citer/SKILL.md" <<'EOF'
Run `tools/build.sh` first.
EOF
mk "$TREE/skills/owner/tools/build.sh" <<'EOF'
#!/bin/sh
EOF
run
case_ "PATH GREEN: a bare top-level-dir citation resolves against any skill's own subdirectory" 0

TREE="$T/path-form3-ambiguous"; mkroot "$TREE"; mkdir -p "$TREE/scripts"
for s in a b c; do mkdir -p "$TREE/skills/$s/scripts"; done
mk "$TREE/skills/demo/SKILL.md" <<'EOF'
See `scripts/does-not-exist-anywhere.sh` for the example.
EOF
run
case_ "PATH GREEN: a top-level dir recurring under >=3 skills is excluded from form 3" 0

# --- stance form (from check 33) --------------------------------------------
TREE="$T/stance-decorated"; mkroot "$TREE"
mk "$TREE/skills/demo/SKILL.md" <<'EOF'
dispatch to the `browser-tester` subagents
EOF
run
case_ "STANCE RED: a backticked phantom stance fails" 1 "stance:.*browser-tester"

TREE="$T/stance-machine"; mkroot "$TREE"
mk "$TREE/skills/demo/SKILL.md" <<'EOF'
Task(subagent_type: "phantom-agent", prompt: "x")
EOF
run
case_ "STANCE RED: a machine spawn call to a phantom stance fails" 1 \
  'stance:.*subagent_type "phantom-agent"'

TREE="$T/stance-green"; mkroot "$TREE"
mk "$TREE/skills/demo/SKILL.md" <<'EOF'
- `implementer` subagents do the work
- subagent_type: "general-purpose" is a harness built-in
EOF
mk "$TREE/skills/demo/FRICTIONS.md" <<'EOF'
the old `browser-tester` subagent is history
EOF
run
case_ "STANCE GREEN: roster + built-ins resolve, FRICTIONS.md exempt" 0

# --- bare-ac form + wiring-prose path form (from check 32, case-count leg dropped) --
TREE="$T/bareac-doc-red"; mkroot "$TREE"
write_manifest "$TREE" "Fails open because the ac-missing-skill stamp-gate is the backstop." \
  "the live backstop." "ac-on0y.5"
run
case_ "BARE-AC RED: _doc naming a missing ac- skill fails, named" 1 "bare-ac:.*'ac-missing-skill' names no live"

TREE="$T/bareac-backstop-red"; mkroot "$TREE"
write_manifest "$TREE" "All live references here." "the ac-ghost-backstop catches it." "ac-on0y.5"
run
case_ "BARE-AC RED: BACKSTOP naming a missing skill fails, named" 1 "bare-ac:.*'ac-ghost-backstop'"

TREE="$T/manifest-path-red"; mkroot "$TREE"
write_manifest "$TREE" "Docs live at skills/nope/SKILL.md." "the live backstop." "ac-on0y.5"
run
case_ "PATH RED: a dead skills/ path reference in wiring prose fails" 1 \
  "path:.*cites 'skills/nope/SKILL.md' — no such file"

TREE="$T/bareac-green"; mkroot "$TREE"
write_manifest "$TREE" \
  "Renders to plugins/ac-demo.js; re-filed as bead ac-on0y.5; see skills/real/SKILL.md." \
  "skills/real/SKILL.md carries it." "ac-on0y.5"
run
case_ "BARE-AC/PATH GREEN: live refs resolve; ac-demo.js and ac-on0y.5 are not read as skills" 0

TREE="$T/pending-decision-scope"; mkroot "$TREE"
write_manifest "$TREE" "All live references here." "the live backstop." "ac-dcg-fails-closed-u7hj"
run
case_ "SCOPE: a PENDING-DECISION bead id is never read as a skill reference" 0

# --- inverse form (from check 31) -------------------------------------------
TREE="$T/inverse-red"; build_inverse_tree "$TREE"
run
case_ "INVERSE RED: an unreferenced reference file fails, named" 1 \
  "inverse: skills/skill-a/references/orphan.md is an orphan"

TREE="$T/inverse-green"; build_inverse_tree "$TREE"
mkdir -p "$TREE/skills/skill-b"
printf '%s\n' '# skill-b' '' 'Read skills/skill-a/references/orphan.md for the details.' \
  > "$TREE/skills/skill-b/SKILL.md"
run
case_ "INVERSE GREEN: a full-path pointer from another skill keeps the file alive" 0

TREE="$T/inverse-allow"; build_inverse_tree "$TREE"; mkdir -p "$TREE/lint/allowlists"
{ echo "# dated allowlist"
  echo "2026-09-07 skills/skill-a/references/orphan.md"
} > "$TREE/lint/allowlists/28-citations.txt"
run
case_ "INVERSE ALLOWLIST: an allowlisted orphan passes; ratchet notes it is a seed" 0 \
  "this is the seed\|no resolvable base ref"

TREE="$T/inverse-shrink"; build_inverse_tree "$TREE"
mkdir -p "$TREE/skills/skill-b" "$TREE/lint/allowlists"
printf '%s\n' '# skill-b' '' 'Read skills/skill-a/references/orphan.md now.' \
  > "$TREE/skills/skill-b/SKILL.md"
{ echo "# dated allowlist"
  echo "2026-09-07 skills/skill-a/references/orphan.md"
} > "$TREE/lint/allowlists/28-citations.txt"
run
case_ "INVERSE SHRINK: an entry whose file gained a reader is refused" 1 "no longer an orphan"

TREE="$T/inverse-growth"; build_inverse_tree "$TREE"; mkdir -p "$TREE/lint/allowlists"
echo "# dated allowlist" > "$TREE/lint/allowlists/28-citations.txt"
git -C "$TREE" init -q
git -C "$TREE" -c user.name=h -c user.email=h@x add -A
git -C "$TREE" -c user.name=h -c user.email=h@x commit -qm base
BASE_SHA=$(git -C "$TREE" rev-parse HEAD)
git -C "$TREE" update-ref refs/remotes/origin/main "$BASE_SHA"
{ echo "# dated allowlist"
  echo "2026-09-07 skills/skill-a/references/orphan.md"
} > "$TREE/lint/allowlists/28-citations.txt"
run
case_ "INVERSE GROWTH: an entry added vs the committed base is refused" 1 "allowlist GREW"

TREE="$T/inverse-slug"; mkroot "$TREE"; mkdir -p "$TREE/skills/catalog/references"
printf '%s\n' '# catalog' '' '| Prompt | Use when |' '| --- | --- |' \
  '| `bug-hunter` | Standard bug hunt |' \
  > "$TREE/skills/catalog/SKILL.md"
printf '# bug-hunter\n' > "$TREE/skills/catalog/references/bug-hunter.md"
run
case_ "INVERSE GREEN: a bare-stem inline-code citation (\`bug-hunter\`) keeps the file alive" 0

TREE="$T/inverse-slug-boundary"; mkroot "$TREE"; mkdir -p "$TREE/skills/catalog/references"
printf '%s\n' '# catalog' '' 'See `bug-hunter-alien` for the exotic variant.' \
  > "$TREE/skills/catalog/SKILL.md"
printf '# bug-hunter\n' > "$TREE/skills/catalog/references/bug-hunter.md"
run
case_ "INVERSE RED: a longer sibling stem does not false-match a shorter one" 1 \
  "inverse: skills/catalog/references/bug-hunter.md is an orphan"

TREE="$T/inverse-glob"; mkroot "$TREE"; mkdir -p "$TREE/skills/catalog/references"
printf '%s\n' '# catalog' '' \
  '| Category | Files |' '| --- | --- |' \
  '| Query Performance | `references/query-*.md` (2) |' \
  > "$TREE/skills/catalog/SKILL.md"
printf '# missing-indexes\n' > "$TREE/skills/catalog/references/query-missing-indexes.md"
printf '# covering-indexes\n' > "$TREE/skills/catalog/references/query-covering-indexes.md"
run
case_ "INVERSE GREEN: a glob-pattern citation covers every matching file" 0

TREE="$T/inverse-glob-miss"; mkroot "$TREE"; mkdir -p "$TREE/skills/catalog/references"
printf '%s\n' '# catalog' '' 'See `references/conn-*.md` for connection docs.' \
  > "$TREE/skills/catalog/SKILL.md"
printf '# missing-indexes\n' > "$TREE/skills/catalog/references/query-missing-indexes.md"
run
case_ "INVERSE RED: a non-matching glob does not rescue an unrelated file" 1 \
  "inverse: skills/catalog/references/query-missing-indexes.md is an orphan"

# --- NOT-GATED and the real registry ----------------------------------------
TREE="$T/empty"; mkdir -p "$TREE"
run
case_ "NOT-GATED: an empty root (no live text, no manifest) -> exit 2" 2 "NOT-CHECKED"

run "$ROOT"
case_ "REAL: the live registry resolves clean across every citation form" 0

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "28-citations.test.sh: all cases passed"
  exit 0
fi
echo "28-citations.test.sh: $FAILURES case(s) FAILED"
exit 1
