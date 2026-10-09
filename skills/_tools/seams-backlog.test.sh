#!/usr/bin/env bash
# seams-backlog.test.sh — fixture tests for skills/_tools/seams-backlog.sh.
#
# The boards are fixtures: a stub `br` answers `list --json --limit 0` from ./board.json in the
# repo it runs in. One matching bead plus one near-miss per filter leg, so a query that lists
# everything and a query that lists nothing both fail. Run: bash skills/_tools/seams-backlog.test.sh
# Discovered by scripts/run-all-proofs.sh (glob over *.test.sh).
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL="$DIR/seams-backlog.sh"
FAILURES=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILURES=$((FAILURES + 1)); }
[ -f "$TOOL" ] || { echo "HARNESS FAIL: missing $TOOL"; exit 1; }

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
cat >"$WORK/br" <<'BR'
#!/usr/bin/env bash
if [ -f ./board.down ]; then
  printf '%s' '{"error":{"code":"DB_LOCKED","message":"database is locked","retryable":true}}'; exit 3
fi
cat ./board.json
BR
chmod +x "$WORK/br"
export AC2_BR_CMD="$WORK/br"

mkrepo() { mkdir -p "$WORK/$1/.beads"; printf '%s' "$2" >"$WORK/$1/board.json"; }

DELIVERS=$'## Delivers\n- tool: skills/_tools/x.sh\n'
mk() {  # mk <id> <status> <type> <labels-json> <description>
  python3 - "$@" <<'PY'
import json, sys
i, status, typ, labels, desc = sys.argv[1:6]
print(json.dumps({"id": i, "status": status, "issue_type": typ, "labels": json.loads(labels), "description": desc}))
PY
}
board() { python3 -c 'import json,sys; print(json.dumps({"issues":[json.loads(l) for l in sys.stdin if l.strip()],"total":0}))'; }

R='["refined"]'
{
  mk hit open task "$R" "## Intent
x

$DELIVERS"
  mk hit-blocked blocked bug "$R" "$DELIVERS"
  mk closed closed task "$R" "$DELIVERS"
  mk unrefined open task '[]' "$DELIVERS"
  mk gated open task '["refined","human-gate"]' "$DELIVERS"
  mk beadified open task '["refined","origin:ac-beadify"]' "$DELIVERS"
  mk epic open epic "$R" "$DELIVERS"
  mk nodelivers open task "$R" "## Intent
x
"
  mk seamed open task "$R" "$DELIVERS
## Seams
- skills/_tools/x.sh · none — rg lists 3 files, all covered
"
} | board >"$WORK/board.all"
mkrepo repo-a "$(cat "$WORK/board.all")"
mkrepo repo-b '{"issues":[],"total":0}'

echo "Case 1: lists exactly the matching beads, once each, with their repo"
out=$(SEAMS_BACKLOG_REPOS=$"$WORK/repo-a"$'\n'"$WORK/repo-b" bash "$TOOL" 2>/dev/null); rc=$?
exp=$(printf '%s\thit\n%s\thit-blocked' "$WORK/repo-a" "$WORK/repo-a")
if [ "$rc" -eq 0 ] && [ "$out" = "$exp" ]; then pass "only hit and hit-blocked listed"; else fail "rc=$rc out=[$out]"; fi

echo "Case 2: --zero exits 1 while a match remains"
SEAMS_BACKLOG_REPOS="$WORK/repo-a" bash "$TOOL" --zero >/dev/null 2>&1; rc=$?
[ "$rc" -eq 1 ] && pass "exit 1" || fail "rc=$rc"

echo "Case 3: --zero exits 0 once the Seams section is written"
mkrepo repo-c "$(python3 - "$WORK/board.all" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
for i in d["issues"]:
    if i["id"] in ("hit", "hit-blocked"):
        i["description"] += "\n## Seams\n- skills/_tools/x.sh · new — no touchers\n"
print(json.dumps(d))
PY
)"
SEAMS_BACKLOG_REPOS="$WORK/repo-c" bash "$TOOL" --zero >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && pass "exit 0" || fail "rc=$rc"

echo "Case 4: an unreadable board is NOT-GATED, never a zero"
mkrepo repo-d '{"issues":[],"total":0}'; : >"$WORK/repo-d/board.down"
SEAMS_BACKLOG_REPOS="$WORK/repo-d" bash "$TOOL" --zero >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] && pass "exit 2" || fail "rc=$rc"

echo "Case 5: no repository with .beads/ is NOT-GATED"
mkdir -p "$WORK/empty"
SEAMS_BACKLOG_REPOS="$WORK/empty" bash "$TOOL" --zero >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] && pass "exit 2" || fail "rc=$rc"

echo "Case 6: an unknown flag is a usage error"
bash "$TOOL" --bogus >/dev/null 2>&1; rc=$?
[ "$rc" -eq 64 ] && pass "exit 64" || fail "rc=$rc"

[ "$FAILURES" -eq 0 ] && { echo "seams-backlog.test.sh: all cases passed"; exit 0; }
echo "seams-backlog.test.sh: $FAILURES failure(s)"; exit 1
