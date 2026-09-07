#!/usr/bin/env bash
# 00-meta.test.sh — the fixture proving lint/checks/00-meta.py's contract.
#
#   PROBE: a check file missing any of id/prevents/scope/severity/fixture,
#           or a fixture that does not go RED, is FAILED by 00-meta; a
#           complete check whose fixture fires is PASSED; an empty checks
#           population is NOT-GATED (exit 2), never a silent pass.
#
# ASSURANCE
#   PROBE:    bash lint/checks/00-meta.test.sh   (self-hosted; also scheduled
#             by scripts/run-all-harnesses.sh, audited by lint.sh Check 20)
#   SCHEDULE: scripts/run-all-harnesses.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
META="$HERE/00-meta.py"
ROOT="$(cd "$HERE/../.." && pwd)"

fails=0
ok()   { echo "  ok    $1"; }
bad()  { echo "  FAIL  $1"; fails=$((fails + 1)); }

run_meta() { # <tmp-root> -> prints exit code, captures output in /tmp/00meta-out
  python3 "$META" "$1" >/tmp/00meta-out.txt 2>&1
  echo $?
}

write_stub() { # <path> <header-lines-file> <exit-code>
  { echo '#!/usr/bin/env python3'
    cat "$2"
    echo 'import sys'
    cat "$3"
  } > "$1"
}

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/lint/checks" "$work/fixtures"

GOOD_HDR="$(mktemp)"; printf '%s\n' \
  '# ---' \
  '# id: 01-good' \
  '# prevents: test stub - the good case' \
  '# scope: LIVE_TEXT' \
  '# severity: fail' \
  '# fixture: fixtures/01-good' \
  '# ---' > "$GOOD_HDR"
RED_BODY="$(mktemp)"; printf '%s\n' \
  '# stub: a real check would scan scope; the fixture is shaped to fire.' \
  'sys.exit(1)' > "$RED_BODY"
CLEAN_BODY="$(mktemp)"; printf '%s\n' \
  'sys.exit(0)' > "$CLEAN_BODY"

# --- case GOOD: complete header, fixture goes RED -> 00-meta passes ----------
mkdir -p "$work/fixtures/01-good"
printf '# broken: deliberate RED case\n' > "$work/fixtures/01-good/SKILL.md"
write_stub "$work/lint/checks/01-good.py" "$GOOD_HDR" "$RED_BODY"
rc=$(run_meta "$work"); [ "$rc" = 0 ] && ok "GOOD case passes (exit 0)" || { cat /tmp/00meta-out.txt; bad "GOOD case: expected 0, got $rc"; }

# --- cases MISSINGx5: each missing header field is failed by name ------------
for field in id prevents scope severity fixture; do
  hdr="$(mktemp)"
  local_scoped="$work/lint/checks/01-missing-$field.py"
  mkdir -p "$work/fixtures/01-missing-$field"
  { echo '# ---'
    for f in id prevents scope severity fixture; do
      [ "$f" = "$field" ] || printf '# %s: placeholder\n' "$f"
    done
    echo '# ---'
  } > "$hdr"
  write_stub "$local_scoped" "$hdr" "$RED_BODY"
  rc=$(run_meta "$work")
  if [ "$rc" = 1 ] && grep -q "'$field' missing" /tmp/00meta-out.txt; then
    ok "missing $field -> failed, names the field"
  else
    bad "missing $field: expected exit 1 naming '$field', got $rc"
  fi
done

# --- case BAD-SCOPE: scope naming no set in lib.scope ------------------------
hdr="$(mktemp)"; printf '%s\n' \
  '# ---' '# id: 01-badscope' '# prevents: test stub' \
  '# scope: NOT_A_SET' '# severity: fail' '# fixture: fixtures/01-good' '# ---' > "$hdr"
write_stub "$work/lint/checks/01-bad-scope.py" "$hdr" "$RED_BODY"
rc=$(run_meta "$work")
if [ "$rc" = 1 ] && grep -q "names no set in lib.scope" /tmp/00meta-out.txt; then
  ok "scope naming no scope set -> failed"
else
  bad "BAD-SCOPE: expected exit 1 naming lib.scope, got $rc"
fi

# --- case NOT-RED: fixture exists but the check passes against it ------------
mkdir -p "$work/fixtures/01-notred"
hdr="$(mktemp)"; printf '%s\n' \
  '# ---' '# id: 01-notred' '# prevents: test stub' \
  '# scope: LIVE_TEXT' '# severity: fail' '# fixture: fixtures/01-notred' '# ---' > "$hdr"
write_stub "$work/lint/checks/01-notred.py" "$hdr" "$CLEAN_BODY"
rc=$(run_meta "$work")
if [ "$rc" = 1 ] && grep -q "does NOT go RED" /tmp/00meta-out.txt; then
  ok "fixture that does not go RED -> failed"
else
  bad "NOT-RED: expected exit 1 naming the RED leg, got $rc"
fi

# --- case EMPTY: no checks population -> NOT-GATED exit 2, never a pass ------
empty="$(mktemp -d)"
rc=$(run_meta "$empty")
if [ "$rc" = 2 ] && grep -qi "NOT-CHECKED" /tmp/00meta-out.txt; then
  ok "empty checks population -> NOT-GATED exit 2"
else
  bad "EMPTY: expected exit 2 NOT-CHECKED, got $rc"
fi

# --- case REAL: the live tree's own population audits clean ------------------
rc=$(run_meta "$ROOT")
[ "$rc" = 0 ] && ok "real tree population audits clean" || { cat /tmp/00meta-out.txt; bad "REAL: expected 0, got $rc"; }

echo
if [ "$fails" -eq 0 ]; then
  echo "All 00-meta contract cases passed."
  exit 0
fi
echo "$fails case(s) FAILED."
exit 1
