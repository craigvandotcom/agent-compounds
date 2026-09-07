#!/usr/bin/env bash
# 27-instance-tokens.test.sh — the fixture proving Check 27's contract.
#
#   PROBE: an instance token in skills/ LIVE_TEXT outside the allowlist is
#           RED; the same hit carried by the allowlist is GREEN; ledgers are
#           exempt through the scope model; the allowlist only shrinks (a
#           post-seed entry, a stale entry or a missing seed header is RED);
#           an empty scan is NOT-GATED (exit 2), never a silent pass; the
#           real tree is green via its seeded allowlist.
#
# ASSURANCE
#   PROBE:    bash lint/checks/27-instance-tokens.test.sh
#   SCHEDULE: scripts/run-all-harnesses.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/27-instance-tokens.py"
ROOT="$(cd "$HERE/../.." && pwd)"
SEED="2026-09-07"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

run_check() { # <tmp-root> <out-file> -> prints exit code
  python3 "$CHECK" "$1" > "$2" 2>&1
  echo $?
}

fresh_root() { # -> tmp dir with lint/allowlists dir
  local w
  w="$(mktemp -d)"
  mkdir -p "$w/lint/allowlists"
  printf '%s\n' "$w"
}

write_allowlist() { # <root> <header-or-empty> <entry-lines...>
  local root="$1" header="$2"; shift 2
  { [ -n "$header" ] && printf '%s\n' "$header"
    printf '%s\n' "$@"
  } > "$root/lint/allowlists/27-instance-tokens.txt"
}

carrier_tree() { # <root> — a skills/ file carrying an app name
  mkdir -p "$1/skills/demo"
  printf 'talks about body-compass here\n' > "$1/skills/demo/SKILL.md"
}

# --- RED: live file carrying an app name outside the allowlist ----------------
w="$(fresh_root)"; carrier_tree "$w"
rc=$(run_check "$w" /tmp/27it-out.txt)
if [ "$rc" = 1 ] && grep -q "instance token 'body-compass' in skills/demo/SKILL.md" /tmp/27it-out.txt; then
  ok "RED: uncovered token hit -> exit 1 naming the file"
else
  bad "RED case: expected 1 naming skills/demo/SKILL.md, got $rc"; cat /tmp/27it-out.txt
fi
rm -rf "$w"

# --- GREEN: the same hit carried by the allowlist -----------------------------
w="$(fresh_root)"; carrier_tree "$w"
write_allowlist "$w" "# seeded: $SEED" "$SEED | body-compass | skills/demo/SKILL.md"
rc=$(run_check "$w" /tmp/27it-out.txt)
if [ "$rc" = 0 ] && grep -q "all carried by the seeded allowlist" /tmp/27it-out.txt; then
  ok "GREEN: allowlisted hit -> exit 0"
else
  bad "GREEN case: expected 0, got $rc"; cat /tmp/27it-out.txt
fi
rm -rf "$w"

# --- LEDGER EXEMPT: FRICTIONS.md carrier never reaches the scan ---------------
w="$(fresh_root)"; carrier_tree "$w"
mkdir -p "$w/skills/demo"
printf 'named the app body-compass in a dated entry\n' > "$w/skills/demo/FRICTIONS.md"
write_allowlist "$w" "# seeded: $SEED" "$SEED | body-compass | skills/demo/SKILL.md"
rc=$(run_check "$w" /tmp/27it-out.txt)
if [ "$rc" = 0 ]; then
  ok "LEDGER: FRICTIONS.md carrier exempt via the scope model -> exit 0"
else
  bad "LEDGER case: expected 0 (ledger never scanned), got $rc"; cat /tmp/27it-out.txt
fi
rm -rf "$w"

# --- SHRINK-ONLY GROWTH: entry dated after the seed is refused ----------------
w="$(fresh_root)"; carrier_tree "$w"
write_allowlist "$w" "# seeded: $SEED" \
  "$SEED | body-compass | skills/demo/SKILL.md" \
  "2099-01-01 | body-compass | skills/other/SKILL.md"
rc=$(run_check "$w" /tmp/27it-out.txt)
if [ "$rc" = 1 ] && grep -q "allowlist GROWTH" /tmp/27it-out.txt; then
  ok "SHRINK-ONLY: post-seed entry -> exit 1 naming GROWTH"
else
  bad "GROWTH case: expected 1 naming GROWTH, got $rc"; cat /tmp/27it-out.txt
fi
rm -rf "$w"

# --- SHRINK-ONLY STALE: entry matching no live hit is refused -----------------
w="$(fresh_root)"; carrier_tree "$w"
write_allowlist "$w" "# seeded: $SEED" \
  "$SEED | body-compass | skills/demo/SKILL.md" \
  "$SEED | unsit | skills/demo/SKILL.md"
rc=$(run_check "$w" /tmp/27it-out.txt)
if [ "$rc" = 1 ] && grep -q "allowlist STALE" /tmp/27it-out.txt; then
  ok "SHRINK-ONLY: stale entry -> exit 1 naming STALE"
else
  bad "STALE case: expected 1 naming STALE, got $rc"; cat /tmp/27it-out.txt
fi
rm -rf "$w"

# --- MALFORMED: no seeded header fails loud, never green ----------------------
w="$(fresh_root)"; carrier_tree "$w"
write_allowlist "$w" "" "$SEED | body-compass | skills/demo/SKILL.md"
rc=$(run_check "$w" /tmp/27it-out.txt)
if [ "$rc" = 1 ] && grep -q "no '# seeded: YYYY-MM-DD' header" /tmp/27it-out.txt; then
  ok "MALFORMED: missing seed header -> exit 1"
else
  bad "MALFORMED case: expected 1 naming the seed header, got $rc"; cat /tmp/27it-out.txt
fi
rm -rf "$w"

# --- EMPTY: no skills/ LIVE_TEXT -> NOT-GATED exit 2, never a pass ------------
w="$(fresh_root)"
rc=$(run_check "$w" /tmp/27it-out.txt)
if [ "$rc" = 2 ] && grep -qi "NOT-CHECKED" /tmp/27it-out.txt; then
  ok "EMPTY: no skills/ LIVE_TEXT -> NOT-GATED exit 2"
else
  bad "EMPTY case: expected 2 NOT-CHECKED, got $rc"; cat /tmp/27it-out.txt
fi
rm -rf "$w"

# --- REAL: the live tree is green via its seeded allowlist --------------------
rc=$(bash "$ROOT/lint.sh" --check 27 >/tmp/27it-out.txt 2>&1; echo $?)
if [ "$rc" = 0 ]; then
  ok "REAL: bash lint.sh --check 27 -> exit 0"
else
  bad "REAL: expected 0, got $rc"; cat /tmp/27it-out.txt
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "All 27-instance-tokens contract cases passed."
  exit 0
fi
echo "$fails case(s) FAILED."
exit 1
