#!/usr/bin/env bash
# 00-meta.test.sh — the fixture proving lint/checks/00-meta.py's contract.
#
#   PROBE: a check file missing either prevents or fixture, or a fixture
#           that does not go RED, is FAILED by 00-meta; a complete check
#           whose fixture fires is PASSED; an empty checks population is
#           NOT-GATED (exit 2), never a silent pass.
#
# ASSURANCE
#   PROBE:    bash lint/checks/00-meta.test.sh   (self-hosted; also scheduled
#             by scripts/run-all-proofs.sh, run by CI's `proofs` job)
#   SCHEDULE: scripts/run-all-proofs.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
META="$HERE/00-meta.py"
ROOT="$(cd "$HERE/../.." && pwd)"

fails=0
ok()   { echo "  ok    $1"; }
bad()  { echo "  FAIL  $1"; fails=$((fails + 1)); }

OUT="$(mktemp)"
trap 'rm -f "$OUT"' EXIT

run_meta() { # <tmp-root> -> prints exit code, captures output in $OUT
  python3 "$META" "$1" >"$OUT" 2>&1
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
trap 'rm -rf "$work"; rm -f "$OUT"' EXIT
mkdir -p "$work/lint/checks" "$work/fixtures"

GOOD_HDR="$(mktemp)"; printf '%s\n' \
  '# ---' \
  '# prevents: test stub - the good case' \
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
rc=$(run_meta "$work"); [ "$rc" = 0 ] && ok "GOOD case passes (exit 0)" || { cat "$OUT"; bad "GOOD case: expected 0, got $rc"; }

# --- cases MISSINGx2: each missing header field is failed by name ------------
for field in prevents fixture; do
  hdr="$(mktemp)"
  local_scoped="$work/lint/checks/01-missing-$field.py"
  mkdir -p "$work/fixtures/01-missing-$field"
  { echo '# ---'
    for f in prevents fixture; do
      [ "$f" = "$field" ] || printf '# %s: placeholder\n' "$f"
    done
    echo '# ---'
  } > "$hdr"
  write_stub "$local_scoped" "$hdr" "$RED_BODY"
  rc=$(run_meta "$work")
  if [ "$rc" = 1 ] && grep -q "'$field' missing" "$OUT"; then
    ok "missing $field -> failed, names the field"
  else
    bad "missing $field: expected exit 1 naming '$field', got $rc"
  fi
done

# --- case NOT-RED: fixture exists but the check passes against it ------------
mkdir -p "$work/fixtures/01-notred"
hdr="$(mktemp)"; printf '%s\n' \
  '# ---' '# prevents: test stub' '# fixture: fixtures/01-notred' '# ---' > "$hdr"
write_stub "$work/lint/checks/01-notred.py" "$hdr" "$CLEAN_BODY"
rc=$(run_meta "$work")
if [ "$rc" = 1 ] && grep -q "does NOT go RED" "$OUT"; then
  ok "fixture that does not go RED -> failed"
else
  bad "NOT-RED: expected exit 1 naming the RED leg, got $rc"
fi

# --- case EMPTY: no checks population -> NOT-GATED exit 2, never a pass ------
empty="$(mktemp -d)"
rc=$(run_meta "$empty")
if [ "$rc" = 2 ] && grep -qi "NOT-CHECKED" "$OUT"; then
  ok "empty checks population -> NOT-GATED exit 2"
else
  bad "EMPTY: expected exit 2 NOT-CHECKED, got $rc"
fi

# --- case REAL: the live tree's own population audits clean ------------------
rc=$(run_meta "$ROOT")
[ "$rc" = 0 ] && ok "real tree population audits clean" || { cat "$OUT"; bad "REAL: expected 0, got $rc"; }

echo
if [ "$fails" -eq 0 ]; then
  echo "All 00-meta contract cases passed."
  exit 0
fi
echo "$fails case(s) FAILED."
exit 1
