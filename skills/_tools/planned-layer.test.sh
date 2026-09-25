#!/usr/bin/env bash
# planned-layer.test.sh — proof harness for planned-layer.sh against a stub br (AC2_BR_CMD,
# same seam pick.test.sh uses) and a fixture plans directory (AC2_PLANS_DIR) — never the
# real board or this repo's own _plans/. Runs from any cwd; parks itself under a scratch
# git repo (planned-layer.sh requires one to resolve the plans directory).
#
# Coverage: list's unindexed row for a Delivers-less bead; the layer never includes a
# draft plan, a beadified plan or a closed bead; scan's delivers (exact path) and referrer
# (touchers.sh's own stem rule, over the subject's own files) matches, the latter whether
# or not the matched bead carries a touchers: line; check's REFUSED-then-OK round trip
# naming the undeclared id and its matched paths; an epic scan excludes its own children
# (dotted-id ∪ parent-child-edge union) while a same-path SIBLING bead still matches;
# NOT-GATED on a missing subject, a missing mode, and an unreadable check target.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/planned-layer.sh"
PA="$HERE/plan-approve.sh"
PASS=0; FAIL=0

expect() {
  if [ "$1" = "$2" ]; then PASS=$((PASS + 1))
  else FAIL=$((FAIL + 1)); printf '  FAIL  %s (want %s got %s)\n' "$3" "$2" "$1"; fi
}
expect_contains() {
  if printf '%s' "$1" | grep -qF "$2"; then PASS=$((PASS + 1))
  else FAIL=$((FAIL + 1)); printf '  FAIL  %s (output lacks %s)\n' "$3" "$2"; fi
}
expect_not_contains() {
  if printf '%s' "$1" | grep -qF "$2"; then FAIL=$((FAIL + 1)); printf '  FAIL  %s (output wrongly has %s)\n' "$3" "$2"
  else PASS=$((PASS + 1)); fi
}

W=$(mktemp -d /tmp/planned-layer-test-XXXXXX)
trap 'rm -rf "$W"' EXIT
cd "$W" || exit 2
git init -q .    # planned-layer.sh requires a git repo to resolve the plans directory

FIX="$W/fix"; mkdir -p "$FIX"
PLANS="$W/plans"; mkdir -p "$PLANS"
export FIX AC2_PLANS_DIR="$PLANS"
AC2_BR_CMD="$W/br"; export AC2_BR_CMD
cat > "$AC2_BR_CMD" <<'STUB'
#!/usr/bin/env bash
case "$1" in
  list) cat "$FIX/list.json" ;;
  show) id="$2"; [ -f "$FIX/show-$id.json" ] && cat "$FIX/show-$id.json" || echo '[]' ;;
  *) exit 9 ;;
esac
STUB
chmod +x "$AC2_BR_CMD"

mk_bead() {  # id type status title [delivers-body]
  local id="$1" itype="$2" status="$3" title="$4" delivers="${5-}" desc
  if [ -n "$delivers" ]; then desc=$(printf '## Delivers\n%s\n' "$delivers")
  else desc="no delivers section in this bead"; fi
  jq -n --arg id "$id" --arg t "$itype" --arg s "$status" --arg ti "$title" --arg d "$desc" \
    '{id:$id, title:$ti, description:$d, status:$s, issue_type:$t}'
}
write_board() { printf '%s\n' "$@" | jq -s '{issues: .}' > "$FIX/list.json"; }
write_show()  { printf '%s' "$2" > "$FIX/show-$1.json"; }

VISION_LINE='writes the vision back in plain prose'
SETTLED_CARD="- **A fork?**
  + options: a, b.
  + settled: a (Alex).
  + vision: \"$VISION_LINE\""

# An approvable plan (plan-approve.sh's own contract): Deliverables carries `deliv`, Seams
# names `seams_path` in full.
mk_approvable_plan() {
  local file="$1" deliv="$2" seams_path="$3"
  cat > "$file" <<EOF
---
status: draft
---
# $(basename "$file" .md)

## Vision

$VISION_LINE

## Deliverables

$deliv
  Done when: the named deliverable is present and its observable result is available.

## Decisions

$SETTLED_CARD

## Seams

| object | finding | disposition |
| --- | --- | --- |
| \`$seams_path\` | x | -> D1 |

## Out of scope

- nothing

## Success criterion

Some criterion.
EOF
}

# =========================================================================================
# A — list: unindexed, and the layer's plan half never includes draft or beadified
# =========================================================================================

write_board \
  "$(mk_bead bd-open1 task open 'Open bead one' '- D1 `lib/foo.js`')" \
  "$(mk_bead bd-noindex task open 'No Delivers bead' '')" \
  "$(mk_bead bd-closed1 task closed 'Closed bead one' '- D1 `lib/foo.js`')"

mk_approvable_plan "$PLANS/p-draft.md" '- D1 `lib/shared.js`' 'lib/shared.js'
# never approved — stays status: draft

mk_approvable_plan "$PLANS/p-beadified.md" '- D1 `lib/shared.js`' 'lib/shared.js'
bash "$PA" approve "$PLANS/p-beadified.md" "Alex" >/dev/null
sed -i.bak '1a beadified: some-epic' "$PLANS/p-beadified.md"; rm -f "$PLANS/p-beadified.md.bak"

mk_approvable_plan "$PLANS/p-approved.md" '- D1 `lib/shared.js`' 'lib/shared.js'
bash "$PA" approve "$PLANS/p-approved.md" "Alex" >/dev/null

OUT=$(bash "$SCRIPT" list); RC=$?
expect "$RC" 0 "list -> exit 0"
expect_contains "$OUT" "unindexed	bd-noindex" "a bead with no Delivers prints unindexed"
expect_contains "$OUT" "lib/foo.js" "an open bead's Delivers path appears in list"
expect_not_contains "$OUT" "bd-closed1" "a closed bead sharing a path never appears"
expect_contains "$OUT" "plans/p-approved.md" "an approved, not-beadified plan appears in list"
expect_not_contains "$OUT" "p-draft.md" "a draft plan never appears in list"
expect_not_contains "$OUT" "p-beadified.md" "a beadified plan never appears in list"

# =========================================================================================
# B — scan: delivers (exact path) + referrer (stem, with and without a touchers: line)
# =========================================================================================

rm -rf "$PLANS"/*.md   # isolate: the plan half is empty for this group
write_board \
  "$(mk_bead bd-open1 task open 'Open bead one' '- D1 `lib/foo.js`')" \
  "$(mk_bead bd-ref task open 'Referrer target, no touchers line' '- D1 `lib/widget.js`')" \
  "$(mk_bead bd-ref2 task open 'Referrer target, WITH a touchers line' \
     '- D1 `lib/gizmo.js`
  touchers: `rg -l -F "lib/gizmo" .` → 1 · owned by: bd-x')"

mkdir -p subject
cat > subject/ref.js <<'EOF'
// mentions lib/widget.js and lib/gizmo.js in prose, not as a Delivers path
EOF
cat > p-subject.md <<'EOF'
# Subject plan

## Deliverables

- D1 `lib/foo.js`
  Done when: x.
- D2 `subject/ref.js`
  Done when: x.
EOF

OUT=$(bash "$SCRIPT" scan p-subject.md); RC=$?
expect "$RC" 0 "scan -> exit 0"
expect_contains "$OUT" "$(printf 'lib/foo.js\tdelivers\tbd-open1')" "exact shared path -> delivers row"
expect_contains "$OUT" "$(printf 'lib/widget.js\treferrer\tbd-ref\t')" "subject file naming the stem -> referrer row (no touchers line on the bead)"
expect_contains "$OUT" "$(printf 'lib/gizmo.js\treferrer\tbd-ref2\t')" "referrer row holds whether or not the bead carries a touchers line"

# =========================================================================================
# C — check: REFUSED (undeclared, naming the id and its matched path) -> OK once declared
# =========================================================================================

OUT=$(bash "$SCRIPT" check p-subject.md); RC=$?
expect "$RC" 1 "undeclared overlap -> check exit 1"
expect_contains "$OUT" "REFUSED" "undeclared overlap -> REFUSED"
expect_contains "$OUT" "bd-open1" "REFUSED names the undeclared bead"
expect_contains "$OUT" "lib/foo.js" "REFUSED names the matched path"

cat >> p-subject.md <<'EOF'

## Planned layer

- bd-open1 · consumes — shares `lib/foo.js`
- bd-ref · independent — references the stem in subject/ref.js
- bd-ref2 · independent — references the stem in subject/ref.js
EOF

OUT=$(bash "$SCRIPT" check p-subject.md); RC=$?
expect "$RC" 0 "every matched id declared -> check exit 0"
expect_contains "$OUT" "OK:" "declared overlaps -> OK"

# =========================================================================================
# D — epic scan excludes its own children (dotted-id ∪ parent-child edge union); a
# same-path SIBLING bead still matches
# =========================================================================================

write_board \
  "$(mk_bead ep-1 epic open 'The epic itself')" \
  "$(mk_bead ep-1.a task open 'Epic child, dotted id' '- D1 `lib/childpath.js`')" \
  "$(mk_bead bd-sibling task open 'Unrelated sibling, same path' '- D1 `lib/childpath.js`')"
write_show ep-1 '[{"id":"ep-1","dependents":[{"id":"ep-1.a","dependency_type":"parent-child"}]}]'

OUT=$(bash "$SCRIPT" scan ep-1); RC=$?
expect "$RC" 0 "epic scan -> exit 0"
expect_not_contains "$OUT" $'\tep-1.a\t' "an epic's own child never appears as a matched row"
expect_not_contains "$OUT" $'\tep-1\t' "an epic never matches itself"
expect_contains "$OUT" "$(printf 'lib/childpath.js\tdelivers\tbd-sibling')" "a sibling sharing the child's path still matches"

# =========================================================================================
# E — NOT-GATED: a missing subject, a missing/unreadable check target, an unknown mode
# =========================================================================================

OUT=$(bash "$SCRIPT" scan 2>&1); RC=$?
expect "$RC" 2 "scan with no subject -> exit 2"
expect_contains "$OUT" "NOT-GATED" "scan with no subject -> NOT-GATED"

OUT=$(bash "$SCRIPT" check "$W/no-such-plan.md" 2>&1); RC=$?
expect "$RC" 2 "check on a missing plan -> exit 2"
expect_contains "$OUT" "NOT-GATED" "check on a missing plan -> NOT-GATED"

OUT=$(bash "$SCRIPT" bogus-mode 2>&1); RC=$?
expect "$RC" 2 "unknown mode -> exit 2"
expect_contains "$OUT" "NOT-GATED" "unknown mode -> NOT-GATED"

# =========================================================================================

printf 'planned-layer.test: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
