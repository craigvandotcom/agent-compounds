#!/usr/bin/env bash
# return-hold.test.sh — proof harness for return-hold.sh against a stub br.
# Invariants: the hold lands as board state (human-gate label + Gate-reason
# line atop the body + released claim), a re-run is a no-op, and — the load-bearing case —
# a held bead is absent from pick.sh's claimable set, driven through the REAL
# pick.sh filter, not a re-implementation of it.
# Runs under bash and zsh:  bash <this> && zsh <this>       Exit 0 = all cases pass.

SELF_DIR=$(cd "$(dirname "$0")" && pwd)
HOLD="$SELF_DIR/return-hold.sh"
PICK="$SELF_DIR/pick.sh"
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
mkdir -p "$W/bin"
export FIX="$W/fix" AC2_BR_CMD="$W/bin/br"
export PATH="$W/bin:$PATH"
PASS=0; FAIL=0

# Stub board: show/ready serve fixtures; update/comments record their argv and
# mutate a tiny state dir so idempotency is observable.
cat > "$AC2_BR_CMD" <<'STUB'
#!/usr/bin/env bash
state="$FIX/state"
labels_f="$state-labels"
log="$FIX/calls.log"
cmd=$1; shift
record() { printf '%s' "$cmd" >>"$log"; for a in "$@"; do if [ -z "$a" ]; then printf ' <empty>' >>"$log"; else printf ' %s' "$a" >>"$log"; fi; done; printf '\n' >>"$log"; }
case $cmd in
  show)
    id=""; for a in "$@"; do case "$a" in --json) ;; *) id="$a" ;; esac; done
    if [ -f "$FIX/show-$id.json" ]; then cat "$FIX/show-$id.json"; else cat "$FIX/show.json"; fi ;;
  comments)
    sub=$1; shift
    case $sub in
      list) [ -f "$FIX/comments.txt" ] && cat "$FIX/comments.txt" || true ;;
      add)  record "$sub" "$@"
            f=""; prev=""; for a in "$@"; do
              if [ "$prev" = "-f" ] || [ "$prev" = "--file" ]; then f="$a"; fi; prev="$a"
            done
            [ -n "$f" ] && cat "$f" >>"$FIX/comments.txt" ;;
    esac ;;
  update)
    record "$@"
    for a in "$@"; do case "$a" in human-gate) printf 'human-gate\n' >>"$labels_f" ;; esac; done ;;
  ready) cat "$FIX/ready.json" ;;
  *) exit 9 ;;
esac
STUB
chmod +x "$AC2_BR_CMD"

reset() { rm -rf "$FIX"; mkdir -p "$FIX"; : >"$FIX/comments.txt"; : >"$FIX/state-labels"; : >"$FIX/calls.log"; }
show() { printf '[{"id":"%s","labels":%s,"status":"in_progress","assignee":"w1","description":"%s"}]' "$1" "$2" "${3-}" > "$FIX/show.json"; }
ready() { local IFS=,; printf '[%s]' "$*" > "$FIX/ready.json"; }
bead() {  # bead <id> <type> <priority> <created> <labels-json> [assignee] [title]
  printf '{"id":"%s","issue_type":"%s","priority":%s,"created_at":"%s","labels":%s,"status":"open","assignee":"%s","title":"%s"}' \
    "$1" "$2" "$3" "$4" "$5" "${6-}" "${7:-work $1}"
}
check() {  # check <name> <expected-stdout> <expected-exit> [cmd args…]
  local name=$1 want=$2 wrc=$3; shift 3
  got=$("$@" 2>"$W/err"); rc=$?
  if [ "$got" = "$want" ] && [ "$rc" = "$wrc" ]; then PASS=$((PASS + 1))
  else FAIL=$((FAIL + 1)); echo "FAIL $name: got '$got' rc=$rc, want '$want' rc=$wrc"; sed 's/^/  /' "$W/err"; fi
}
expect_log() {  # expect_log <name> <grep-pattern>
  if grep -q -- "$2" "$FIX/calls.log"; then PASS=$((PASS + 1))
  else FAIL=$((FAIL + 1)); echo "FAIL $1: calls.log lacks '$2'"; fi
}
refute_log() {  # refute_log <name> <grep-pattern>
  if grep -q -- "$2" "$FIX/calls.log"; then FAIL=$((FAIL + 1)); echo "FAIL $1: calls.log unexpectedly has '$2'"
  else PASS=$((PASS + 1)); fi
}

R='["refined"]'

# 1 — the hold lands as board state: label + released claim.
reset
show h-task "$R"
check "hold exits 0" "return-hold: h-task held (human-gate + 'Gate-reason: authorization'), claim released" 0 \
  bash "$HOLD" h-task --reason authorization --actor w1
expect_log "human-gate label applied" "update h-task --add-label human-gate"
expect_log "marker written atop the body" "update h-task --description Gate-reason: authorization — returned by w1"
refute_log "no marker comment" "comments add"
if grep -q -- "--status open" "$FIX/calls.log" && grep -q -- "--assignee <empty>" "$FIX/calls.log"; then PASS=$((PASS + 1))
else FAIL=$((FAIL + 1)); echo "FAIL claim released with open+empty-assignee"; fi
if grep -qF "<empty>" "$FIX/calls.log" && grep -q "^update h-task --description" "$FIX/calls.log"; then PASS=$((PASS + 1))
else FAIL=$((FAIL + 1)); echo "FAIL body update recorded"; fi

# 2 — re-run is a no-op: label and marker already present, still exit 0.
reset
show h-task '["refined","human-gate"]' 'Gate-reason: authorization — returned by w0\n\n## Intent'
: >"$FIX/calls.log"
check "re-run exits 0" "return-hold: h-task held (human-gate + 'Gate-reason: authorization'), claim released" 0 \
  bash "$HOLD" h-task --reason authorization --actor w1
refute_log "label not re-added" "add-label"
refute_log "marker not re-written" "--description"

# 3 — THE hole, closed: a held bead is absent from pick.sh's claimable set.
# The held bead is served by the REAL pick.sh filter, never a copy of it.
reset
show h-task '["refined","human-gate"]'
ready "$(bead h-task task 0 2026-09-20 '["refined","human-gate"]')" \
      "$(bead clean-task task 1 2026-09-21 "$R")"
check "pick skips the held bead" clean-task 0 bash "$PICK" --actor w2
reset
show h-task '["refined","human-gate"]'
ready "$(bead h-task task 0 2026-09-20 '["refined","human-gate"]')"
check "held alone is DRY" DRY 1 bash "$PICK" --actor w2

# 4 — argv discipline: id, reason and actor are all required.
check "missing reason refused" "" 1 bash "$HOLD" h-task --actor w1
check "missing actor refused" "" 1 bash "$HOLD" h-task --reason authorization
check "missing id refused" "" 1 bash "$HOLD" --reason authorization --actor w1
check "off-canon reason refused" "" 1 bash "$HOLD" h-task --reason "split — two workers bounced it" --actor w1

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
