#!/usr/bin/env bash
# 26-readme-ghosts.test.sh — the contract harness for lint/checks/26-readme-ghosts.py.
#
#   PROBE: a plain-text skill-table row naming a missing skill FAILS with the
#           row named; a link-form row to a missing dir FAILS; all-real rows
#           PASS; a Dependency-table plain row is NOT a skill name; bold text
#           mid-row is prose, never extracted; a missing README is NOT-GATED.
#
# ASSURANCE
#   PROBE:    bash lint/checks/26-readme-ghosts.test.sh
#   SCHEDULE: scripts/run-all-harnesses.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/26-readme-ghosts.py"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

OUT="$(mktemp)"
run_check() { # <tmp-root> -> exit code; output in $OUT
  python3 "$CHECK" "$1" >"$OUT" 2>&1
  echo $?
}

work="$(mktemp -d)"
trap 'rm -rf "$work" "$OUT"' EXIT

build_tree() { # <root> <readme-body-file>
  mkdir -p "$1/skills/real-one"
  printf '# real-one\n' > "$1/skills/real-one/SKILL.md"
  cp "$2" "$1/README.md"
}

# --- 1 RED: plain-text ghost row -> exit 1, row named ------------------------
t="$work/red-plain"
printf '%s\n' \
  '| Skill | What it does |' \
  '|-------|-------------|' \
  '| **[real-one](./skills/real-one/)** | exists |' \
  '| **ghost-skill** | plain-text row naming an archived skill |' > "$work/r1.md"
build_tree "$t" "$work/r1.md"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "ghost-skill" "$OUT"; then
  ok "RED-PLAIN: plain-text ghost row failed, named"
else
  bad "RED-PLAIN: expected exit 1 naming ghost-skill, got $rc"; cat "$OUT"
fi

# --- 2 RED: link-form row to a missing dir -> exit 1, named ------------------
t="$work/red-link"
printf '%s\n' \
  '| Skill | What it does |' \
  '|-------|-------------|' \
  '| **[dead-link](./skills/dead-link/)** | link row to a removed dir |' > "$work/r2.md"
build_tree "$t" "$work/r2.md"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "dead-link" "$OUT"; then
  ok "RED-LINK: link-form ghost failed, named"
else
  bad "RED-LINK: expected exit 1 naming dead-link, got $rc"; cat "$OUT"
fi

# --- 3 GREEN: all rows real, dependency rows ignored -------------------------
t="$work/green"
printf '%s\n' \
  '| Skill | What it does |' \
  '|-------|-------------|' \
  '| **[real-one](./skills/real-one/)** | exists |' \
  '| **real-one** | plain-text row, real skill |' \
  '' \
  '| Agent | What it does |' \
  '|-------|-------------|' \
  '| **[researcher](./agents/researcher.md)** | stance |' \
  '' \
  '| Dependency | What it provides | Install |' \
  '|-----------|-----------------|---------|' \
  '| **openrouter** | CLI | install |' \
  '| **[agent-browser](https://example.com)** | CLI | npm |' > "$work/r3.md"
build_tree "$t" "$work/r3.md"
rc=$(run_check "$t")
if [ "$rc" = 0 ] && ! grep -q "openrouter" "$OUT"; then
  ok "GREEN: real rows pass; Agent/Dependency rows not governed"
else
  bad "GREEN: expected exit 0 without flagging openrouter, got $rc"; cat "$OUT"
fi

# --- 4 PROSE-BOLD: bold text mid-row is never a name -------------------------
t="$work/prose"
printf '%s\n' \
  '| Skill | What it does |' \
  '|-------|-------------|' \
  '| **real-one** | refuses any bead with **no probe, no bead** in its ACs |' > "$work/r4.md"
build_tree "$t" "$work/r4.md"
rc=$(run_check "$t")
if [ "$rc" = 0 ]; then
  ok "PROSE-BOLD: mid-row bold text not extracted"
else
  bad "PROSE-BOLD: expected exit 0, got $rc"; cat "$OUT"
fi

# --- 5 NOT-GATED: no README -> exit 2 ----------------------------------------
t="$work/empty"
mkdir -p "$t/skills/real-one"
printf '# real-one\n' > "$t/skills/real-one/SKILL.md"
rc=$(run_check "$t")
if [ "$rc" = 2 ] && grep -qi "NOT-CHECKED" "$OUT"; then
  ok "EMPTY: no README -> NOT-GATED exit 2"
else
  bad "EMPTY: expected exit 2 NOT-CHECKED, got $rc"; cat "$OUT"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "All 26-readme-ghosts contract cases passed."
  exit 0
fi
echo "$fails case(s) FAILED."
exit 1
