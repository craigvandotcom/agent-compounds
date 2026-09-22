#!/usr/bin/env bash
# triage-gate.test.sh — proof harness for triage-gate.sh. Stubbed sources, model and br; no
# network, no real beads. Exit 0 = every case passes.

GATE="$(cd "$(dirname "$0")" && pwd)/triage-gate.sh"
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
PASS=0; FAIL=0
ok()   { PASS=$((PASS + 1)); }
bad()  { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }

# A throwaway repo; each source's behaviour is a file the case writes: <src>.out (items),
# <src>.rc (exit code), <src>.sleep (seconds to hang).
setup() {
  rm -rf "$W/repo" "$W/state" "$W/br.log" "$W/model.log" "$W/beads"
  mkdir -p "$W/repo" "$W/state" "$W/beads"
  git -C "$W/repo" init -q
  cat >"$W/src.sh" <<'SH'
#!/usr/bin/env bash
d=$(dirname "$0"); s=$1
[ -f "$d/$s.sleep" ] && sleep "$(cat "$d/$s.sleep")"
[ -f "$d/$s.out" ] && cat "$d/$s.out"
[ -f "$d/$s.rc" ] && { echo "$s is down" >&2; exit "$(cat "$d/$s.rc")"; }
exit 0
SH
  chmod +x "$W/src.sh"
  find "$W" -maxdepth 1 \( -name 'alpha.*' -o -name 'beta.*' \) -delete  # never a glob: zsh aborts on no match
  printf '# fixture\n```triage-gate\n# name timeout command\nalpha 5 %s alpha\nbeta 2 %s beta\n```\n' \
    "$W/src.sh" "$W/src.sh" >"$W/triage.md"
  # br stub: one file per bead in $W/beads; logs every call.
  cat >"$W/br" <<SH
#!/usr/bin/env bash
echo "\$*" >>"$W/br.log"
case "\$1" in
  list)   m=\$3; ids=\$(grep -l -- "\$m" "$W"/beads/* 2>/dev/null | xargs -rn1 basename)
          printf '{"issues":['; sep=; for i in \$ids; do printf '%s{"id":"%s"}' "\$sep" "\$i"; sep=,; done; printf ']}\n' ;;
  create) n=\$(ls "$W/beads" | wc -l); printf '%s' "\$*" >"$W/beads/ops-\$n" ;;
  comments) : ;;
esac
SH
  chmod +x "$W/br"
  cat >"$W/model" <<SH
#!/usr/bin/env bash
cat "\$1" >>"$W/model.log"; echo --- >>"$W/model.log"
exit "\$(cat "$W/model.rc" 2>/dev/null || echo 0)"
SH
  chmod +x "$W/model"; rm -f "$W/model.rc"
}
gate() {
  (cd "$W/repo" && TRIAGE_GATE_CONFIG="$W/triage.md" TRIAGE_GATE_STATE="$W/state" \
    TRIAGE_GATE_MODEL="$W/model" AC2_BR_CMD="$W/br" TRIAGE_GATE_COMMENT_EVERY_H=0 \
    bash "$GATE" "$@" >"$W/gate.out" 2>&1); echo $?
}
calls() { grep -c "^$1" "$W/br.log" 2>/dev/null || echo 0; }

# 1. all clean → no model, exit 0, heartbeat written
setup
rc=$(gate)
if [ "$rc" = 0 ]; then ok; else bad "clean exits 0 (got $rc)"; fi
if [ ! -s "$W/model.log" ]; then ok; else bad "clean starts no model"; fi
if jq -e ".exit == 0" "$W/state/heartbeat.json" >/dev/null; then ok; else bad "clean writes heartbeat"; fi

# 2. one finding → model gets only that item; next run does not re-escalate
setup
printf 'k1\tfirst issue\n' >"$W/alpha.out"
rc=$(gate)
if [ "$rc" = 0 ]; then ok; else bad "finding exits 0 (got $rc)"; fi
if [ "$(grep -c . "$W/model.log")" = 2 ] && grep -q "^alpha	k1	first issue$" "$W/model.log"; then ok; else bad "model got exactly the one item"; fi
: >"$W/model.log"; rc=$(gate)
if [ ! -s "$W/model.log" ] && [ "$rc" = 0 ]; then ok; else bad "seen item is not re-escalated"; fi
printf 'k1\tfirst issue\nk2\tsecond\n' >"$W/alpha.out"; rc=$(gate)
if grep -q "k2" "$W/model.log" && ! grep -q "k1" "$W/model.log"; then ok; else bad "only the new key escalates"; fi

# 3. a key that leaves the source and returns is new again
: >"$W/alpha.out"; gate >/dev/null
printf 'k1\tfirst issue\n' >"$W/alpha.out"; : >"$W/model.log"; gate >/dev/null
if grep -q "k1" "$W/model.log"; then ok; else bad "recurrence escalates again"; fi

# 4. model fails → exit 1, item stays unseen, resurfaces next run
setup
printf 'k9\tboom\n' >"$W/alpha.out"; echo 1 >"$W/model.rc"
rc=$(gate)
if [ "$rc" = 1 ]; then ok; else bad "model failure exits 1 (got $rc)"; fi
if ! grep -q k9 "$W/state/seen/alpha"; then ok; else bad "failed item not marked seen"; fi
rm -f "$W/model.rc"; : >"$W/model.log"; rc=$(gate)
if [ "$rc" = 0 ] && grep -q k9 "$W/model.log" && grep -q k9 "$W/state/seen/alpha"; then ok; else bad "failed item resurfaces and lands"; fi

# 5. source error twice → one ops bead, then a comment; recovery comments once
setup
echo 2 >"$W/beta.rc"
rc=$(gate)
if [ "$rc" = 0 ]; then ok; else bad "down source exits 0 (got $rc)"; fi
if [ "$(calls create)" = 1 ]; then ok; else bad "first outage files one ops bead"; fi
if grep -q "beta is down" "$W"/beads/*; then ok; else bad "ops bead carries the reason"; fi
rc=$(gate)
if [ "$(calls create)" = 1 ] && [ "$(calls comments)" = 1 ]; then ok; else bad "second outage comments, files nothing"; fi
if [ ! -s "$W/model.log" ]; then ok; else bad "down source never starts the model"; fi
rm -f "$W/beta.rc"; gate >/dev/null
if [ "$(calls comments)" = 2 ] && [ ! -f "$W/state/down/beta" ]; then ok; else bad "recovery comments once"; fi

# 6. br failing while a source is down → exit 2
setup
echo 2 >"$W/beta.rc"; printf '#!/bin/sh\nexit 1\n' >"$W/br"
rc=$(gate)
if [ "$rc" = 2 ]; then ok; else bad "unrecordable outage exits 2 (got $rc)"; fi

# 7. lock held → exit 3, nothing runs
setup
printf 'k1\tx\n' >"$W/alpha.out"
mkdir -p "$W/state"; ( flock 9; sleep 3 ) 9>"$W/state/lock" & sleep 0.3
rc=$(gate)
if [ "$rc" = 3 ]; then ok; else bad "held lock exits 3 (got $rc)"; fi
if [ ! -s "$W/model.log" ]; then ok; else bad "held lock starts no model"; fi
wait

# 8. timeout → could-not-check with the timeout named
setup
echo 5 >"$W/beta.sleep"
rc=$(gate)
if [ "$rc" = 0 ] && grep -q "beta: ✗ could-not-check (timed out after 2s)" "$W/gate.out"; then ok; else bad "timeout is could-not-check (got $rc)"; fi
if [ "$(calls create)" = 1 ]; then ok; else bad "timeout files an ops bead"; fi

# 9. --no-escalate and --seed
setup
printf 'k1\tx\n' >"$W/alpha.out"
echo 2 >"$W/beta.rc"; gate --no-escalate >/dev/null; rm -f "$W/beta.rc"
if [ ! -s "$W/model.log" ] && ! grep -q k1 "$W/state/seen/alpha"; then ok; else bad "--no-escalate starts no model, marks nothing"; fi
if [ "$(calls create)" = 0 ]; then ok; else bad "--no-escalate files no ops bead"; fi
gate --seed >/dev/null; gate >/dev/null
if [ ! -s "$W/model.log" ] && grep -q k1 "$W/state/seen/alpha"; then ok; else bad "--seed marks current items seen"; fi

# 10. missing fence → exit 64
setup
echo "no fence" >"$W/triage.md"
rc=$(gate)
if [ "$rc" = 64 ]; then ok; else bad "missing fence exits 64 (got $rc)"; fi

# 11. --status: silent without a fence, never-ran, fresh, silent, down source; never writes
st() { gate --status >/dev/null; cat "$W/gate.out"; }
if [ -z "$(st)" ]; then ok; else bad "--status prints nothing when no gate is declared"; fi
setup
if [ "$(st)" = "triage: ⚠ never ran" ] && [ ! -e "$W/state/lock" ]; then ok; else bad "--status: never ran, no lock taken"; fi
gate >/dev/null
case "$(st)" in "triage: ✓ 0m ago") ok ;; *) bad "--status fresh (got '$(st)')" ;; esac
jq '.ts = "2000-01-01T00:00:00Z"' "$W/state/heartbeat.json" >"$W/hb" && mv "$W/hb" "$W/state/heartbeat.json"
case "$(st)" in "triage: ⚠ silent "*) ok ;; *) bad "--status stale → silent (got '$(st)')" ;; esac
echo 2 >"$W/beta.rc"; gate >/dev/null; rm -f "$W/beta.rc"
case "$(st)" in *"down: beta") ok ;; *) bad "--status names a down source (got '$(st)')" ;; esac

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" = 0 ]
