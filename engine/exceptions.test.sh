#!/usr/bin/env bash
#
# exceptions.test.sh — the executable contract of engine/exceptions.sh.
#
# Pins the TECHNICAL half of the exclusion set: where it comes from, what shape it is
# rendered in, and its three states. The source is engine/machine.sh, driven here through
# its own AC_MACHINE_FILE fixture seam; every fixture is built inside one temp dir, so
# nothing outside $W is read or written.
#
#   --list   a public target renders by BASENAME under LOCKED; a private one does not;
#            a resolved-empty roster says "(none derived)"; an unresolved one says
#            UNRESOLVED and "NOT empty" and prints no LOCKED line at all
#   --json   resolved       -> targets[] of basenames (never paths), resolved: true, exit 0
#            resolved-empty -> targets: [], resolved: true, exit 0
#            unresolved     -> targets: null (NEVER []), resolved: false, reader_exit
#                              carrying 4 (not configured) / 2 (configured but wrong),
#                              and that same code as the script's own exit
#
# The unresolved-is-not-empty rule is the point of the last pair: `targets: null` means
# "unknown" and `targets: []` means "no constraints", and a view that reports the first
# as the second is a lie about what was checked.
#
# ASSURANCE
#   PROBE:    bash engine/exceptions.test.sh
#   SCHEDULE: scripts/run-all-proofs.sh
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXC="$HERE/exceptions.sh"
[ -f "$EXC" ] || { echo "exceptions.test.sh: $EXC is missing"; exit 2; }

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT

mkdir -p "$W/org/software/app-one" "$W/org/software/app-public" \
         "$W/org/software/app-both" "$W/org/not-a-target"

printf '{"org_root": "%s/org", "targets": [\n' "$W" > "$W/good.json"
printf '  {"path": "%s/org/software/app-one", "public": false},\n' "$W" >> "$W/good.json"
printf '  {"path": "%s/org/software/app-public", "public": true},\n' "$W" >> "$W/good.json"
printf '  {"path": "%s/org/software/app-both", "public": true, "packages": ["factory-core"]}\n' "$W" >> "$W/good.json"
printf ']}\n' >> "$W/good.json"

printf '{"org_root": "%s/org", "targets": [{"path": "%s/org/software/app-one", "public": false}]}\n' \
  "$W" "$W" > "$W/empty.json"
printf 'not json\n' > "$W/malformed.json"
ABSENT="$W/absent.json"

# --- --list: resolved, by NAME, public only ----------------------------------------------
# Target lines are indented and carry ` LOCKED:`; the section HEADER also says LOCKED, so
# every match here is anchored on the indent.
out="$(AC_MACHINE_FILE="$W/good.json" "$EXC" --list 2>&1)"; rc=$?
locked="$(printf '%s\n' "$out" | awk '/^  / && /LOCKED:/ { print $1 }' | sort | tr '\n' ' ')"
if [[ "$rc" = 0 && "$locked" = "app-both app-public " ]]; then
  ok "--list: public targets render by basename under LOCKED"
else
  bad "--list resolved: expected LOCKED for app-both and app-public, got rc=$rc"; printf '%s\n' "$out"
fi
if printf '%s\n' "$out" | grep -q "$W/"; then
  bad "--list: a full path leaked into the rendered view"
else
  ok "--list: no full path in the rendered view"
fi
if printf '%s\n' "$out" | grep -q 'app-one'; then
  bad "--list: a non-public target was rendered as an exclusion"
else
  ok "--list: a non-public target is not an exclusion"
fi

# --- --list: resolved-empty is not unresolved --------------------------------------------
out="$(AC_MACHINE_FILE="$W/empty.json" "$EXC" --list 2>&1)"; rc=$?
if [ "$rc" = 0 ] && printf '%s\n' "$out" | grep -q '(none derived)' \
   && ! printf '%s\n' "$out" | grep -q 'UNRESOLVED'; then
  ok "--list: resolved-empty says (none derived), not UNRESOLVED"
else
  bad "--list empty: expected (none derived) and no UNRESOLVED, got rc=$rc"; printf '%s\n' "$out"
fi

# --- --list: unresolved, both reader states, still exit 0 --------------------------------
for fixture in "$ABSENT:not configured" "$W/malformed.json:configured but wrong"; do
  f="${fixture%%:*}"; what="${fixture#*:}"
  out="$(AC_MACHINE_FILE="$f" "$EXC" --list 2>&1)"; rc=$?
  if [ "$rc" = 0 ] && printf '%s\n' "$out" | grep -q 'UNRESOLVED' \
     && printf '%s\n' "$out" | grep -q 'NOT empty' \
     && ! printf '%s\n' "$out" | grep -qE '^  [^ ].*LOCKED:'; then
    ok "--list: $what -> UNRESOLVED, NOT empty, no LOCKED line, exit 0"
  else
    bad "--list $what: expected UNRESOLVED/NOT empty/no LOCKED/exit 0, got rc=$rc"; printf '%s\n' "$out"
  fi
done

# --- --json: resolved, names not paths ---------------------------------------------------
j="$(AC_MACHINE_FILE="$W/good.json" "$EXC" --json 2>/dev/null)"; rc=$?
if [ "$rc" = 0 ] \
   && [ "$(printf '%s' "$j" | jq -c '.technical.targets')" = '["app-public","app-both"]' ] \
   && [ "$(printf '%s' "$j" | jq -r '.technical.resolved')" = true ]; then
  ok "--json: targets[] is the public basenames, resolved true, exit 0"
else
  bad "--json resolved: expected [\"app-public\",\"app-both\"] and resolved true, got rc=$rc"; printf '%s\n' "$j"
fi
if printf '%s' "$j" | jq -r '.technical.targets[]' | grep -q "$W/"; then
  bad "--json: a full path leaked into targets[]"
else
  ok "--json: no full path in targets[]"
fi

# --- --json: resolved-empty is [] with resolved true (the other half of the rule) --------
j="$(AC_MACHINE_FILE="$W/empty.json" "$EXC" --json 2>/dev/null)"; rc=$?
if [ "$rc" = 0 ] \
   && [ "$(printf '%s' "$j" | jq -c '.technical.targets')" = '[]' ] \
   && [ "$(printf '%s' "$j" | jq -r '.technical.resolved')" = true ]; then
  ok "--json: resolved-empty is [] with resolved true, exit 0"
else
  bad "--json empty: expected [] and resolved true, got rc=$rc"; printf '%s\n' "$j"
fi

# --- --json: unresolved is null, never [], and the reader's code is the exit code --------
for fixture in "$ABSENT:4:not configured" "$W/malformed.json:2:configured but wrong"; do
  f="${fixture%%:*}"; rest="${fixture#*:}"; want="${rest%%:*}"; what="${rest#*:}"
  j="$(AC_MACHINE_FILE="$f" "$EXC" --json 2>/dev/null)"; rc=$?
  if [ "$rc" = "$want" ] \
     && [ "$(printf '%s' "$j" | jq -r '.technical.resolved')" = false ] \
     && [ "$(printf '%s' "$j" | jq -c '.technical.targets')" = null ] \
     && [ "$(printf '%s' "$j" | jq -r '.technical.reader_exit')" = "$want" ] \
     && [ "$(printf '%s' "$j" | jq -r '.policy')" = 'full-set-everywhere' ]; then
    ok "--json: $what -> targets null (not []), reader_exit $want, exit $want"
  else
    bad "--json $what: expected null targets / reader_exit $want / exit $want, got rc=$rc"; printf '%s\n' "$j"
  fi
done

# --- usage ------------------------------------------------------------------------------
rc=0; "$EXC" --bogus >/dev/null 2>&1 || rc=$?
if [ "$rc" = 2 ]; then ok "usage: an unknown mode -> 2"; else bad "usage: expected 2, got $rc"; fi

echo
if [ "$fails" -eq 0 ]; then
  echo "exceptions.test.sh: pass"
  exit 0
fi
echo "exceptions.test.sh: $fails failure(s)"
exit 1
