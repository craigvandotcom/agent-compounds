#!/usr/bin/env bash
# 30-trigger-collisions.test.sh — the fixture proving Check 30's contract.
#
#   PROBE: two skills quoting the same trigger phrase is RED naming both
#           skills; separating the phrases is GREEN; the same phrase twice in
#           ONE description is not a collision; the single-quote/double-quote
#           crossing artifact does not collide; an empty scan is NOT-GATED
#           (exit 2); the real tree is green.
#
# ASSURANCE
#   PROBE:    bash lint/checks/30-trigger-collisions.test.sh
#   SCHEDULE: scripts/run-all-proofs.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/30-trigger-collisions.py"
ROOT="$(cd "$HERE/../.." && pwd)"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

OUT="$(mktemp)"
trap 'rm -f "$OUT"' EXIT

run_check() { # <tmp-root> <out-file> -> exit code
  python3 "$CHECK" "$1" > "$2" 2>&1
  echo $?
}

# --- RED: two descriptions sharing a trigger phrase ---------------------------
w="$(mktemp -d)"; mkdir -p "$w/skills/aa" "$w/skills/bb"
printf -- "---\nname: aa\ndescription: 'Triggers on \"frobnicate the widget\".'\n---\n\n# aa\n" > "$w/skills/aa/SKILL.md"
printf -- "---\nname: bb\ndescription: 'Triggers on \"frobnicate the widget\" too.'\n---\n\n# bb\n" > "$w/skills/bb/SKILL.md"
rc=$(run_check "$w" "$OUT")
if [ "$rc" = 1 ] && grep -q "'frobnicate the widget' is quoted by aa, bb" "$OUT"; then
  ok "RED: shared phrase -> exit 1 naming both skills"
else
  bad "RED case: expected 1 naming aa,bb — got $rc"; cat "$OUT"
fi
rm -rf "$w"

# --- GREEN: the same phrases, separated ---------------------------------------
w="$(mktemp -d)"; mkdir -p "$w/skills/aa" "$w/skills/bb"
printf -- "---\nname: aa\ndescription: 'Triggers on \"frobnicate the widget\".'\n---\n\n# aa\n" > "$w/skills/aa/SKILL.md"
printf -- "---\nname: bb\ndescription: 'Triggers on \"clean the widget\".'\n---\n\n# bb\n" > "$w/skills/bb/SKILL.md"
rc=$(run_check "$w" "$OUT")
if [ "$rc" = 0 ]; then
  ok "GREEN: separated phrases -> exit 0"
else
  bad "GREEN case: expected 0, got $rc"; cat "$OUT"
fi
rm -rf "$w"

# --- NOT-A-COLLISION: same phrase twice in ONE description --------------------
w="$(mktemp -d)"; mkdir -p "$w/skills/aa" "$w/skills/bb"
printf -- "---\nname: aa\ndescription: 'Triggers on \"frobnicate the widget\"; also \"frobnicate the widget\" again.'\n---\n\n# aa\n" > "$w/skills/aa/SKILL.md"
printf -- "---\nname: bb\ndescription: 'Triggers on something else entirely.'\n---\n\n# bb\n" > "$w/skills/bb/SKILL.md"
rc=$(run_check "$w" "$OUT")
if [ "$rc" = 0 ]; then
  ok "SELF-QUOTE: phrase twice in one description -> not a collision"
else
  bad "SELF-QUOTE case: expected 0, got $rc"; cat "$OUT"
fi
rm -rf "$w"

# --- ARTIFACT: single-quote span crossing double quotes does not collide ------
w="$(mktemp -d)"; mkdir -p "$w/skills/aa" "$w/skills/bb"
python3 - "$w" <<'PYEOF'
import sys, pathlib
w = sys.argv[1]
# YAML single-quoted scalars with doubled-quote apostrophes — the exact shape
# ac-human's docket/board descriptions carry on the real tree.
for skill, tail in (("aa", " and others."), ("bb", " too.")):
    d = "Asks \"what''s the factory doing\" " + tail
    body = f"---\nname: {skill}\ndescription: '{d}'\n---\n\n# {skill}\n"
    pathlib.Path(w, "skills", skill, "SKILL.md").write_text(body)
PYEOF
rc=$(run_check "$w" "$OUT")
# Both descriptions quote the SAME double-quoted phrase, so that phrase's
# collision legitimately fires; the single-quote ARTIFACT tokens (the ', "what
# crossing spans) must never appear as findings — they are parse noise, and
# before the tokenizer dropped them they turned one real collision into three.
if [ "$rc" = 1 ] && grep -q "what's the factory doing" "$OUT" && ! grep -q "', \"what" "$OUT"; then
  ok "ARTIFACT: crossing spans dropped; the real double-quoted collision is what fires"
else
  bad "ARTIFACT case: expected the clean double-quoted collision, got $rc"; cat "$OUT"
fi
rm -rf "$w"

# --- EMPTY: no skill descriptions -> NOT-GATED exit 2 -------------------------
w="$(mktemp -d)"
rc=$(run_check "$w" "$OUT")
if [ "$rc" = 2 ] && grep -qi "NOT-CHECKED" "$OUT"; then
  ok "EMPTY: no descriptions -> NOT-GATED exit 2"
else
  bad "EMPTY case: expected 2 NOT-CHECKED, got $rc"; cat "$OUT"
fi
rm -rf "$w"

# --- REAL: the live tree is green -----------------------------------------------
rc=$(bash "$ROOT/lint.sh" --check 30 >"$OUT" 2>&1; echo $?)
if [ "$rc" = 0 ]; then
  ok "REAL: bash lint.sh --check 30 -> exit 0"
else
  bad "REAL: expected 0, got $rc"; cat "$OUT"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "All 30-trigger-collisions contract cases passed."
  exit 0
fi
echo "$fails case(s) FAILED."
exit 1
