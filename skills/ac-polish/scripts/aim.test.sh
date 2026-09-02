#!/usr/bin/env bash
# aim.test.sh — RED/GREEN proof harness for aim.sh.
#
# ASSURANCE-ROLE: test-harness
# CALLER: scripts/run-all-harnesses.sh (discovered by its *.test.sh glob) and any local run.
#
# Builds a throwaway repo with KNOWN churn and co-changes, so every number aim.sh prints has
# a ground truth to be checked against:
#   big.txt    changed 6 times alone (+init), 206 lines -> hotspot #1 (7 × 206)
#   a.txt/b.txt co-changed 4 times (+init), no import   -> the coupling pair that must appear
#   a.txt/c.txt co-changed 3 times (+init), c imports a -> filtered out (coupling is IN the code)
#   docs/x.md  changed 9 times                          -> excluded by default, never a hotspot
# Exit 0 = all cases pass.
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/aim.sh"
[ -x "$SCRIPT" ] || { echo "HARNESS FAIL: $SCRIPT missing or not executable"; exit 1; }

W=$(mktemp -d "${TMPDIR:-/tmp}/aim-XXXXXX")
trap 'rm -rf "$W"' EXIT
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf 'ok   %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf 'FAIL %s\n     %s\n' "$1" "${2:-}"; }

R="$W/repo"; mkdir -p "$R/docs"
g() { git -C "$R" -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@"; }
g init -q
commit() { g add -A >/dev/null; g commit -q -m "$1" >/dev/null; }

seq 1 200 > "$R/big.txt"; echo a > "$R/a.txt"; echo b > "$R/b.txt"; printf 'import a\n' > "$R/c.txt"; echo d > "$R/docs/x.md"
commit init
for i in 1 2 3 4 5 6; do echo "big $i" >> "$R/big.txt"; commit "big $i"; done
for i in 1 2 3 4; do echo "ab $i" >> "$R/a.txt"; echo "ab $i" >> "$R/b.txt"; commit "ab $i"; done
for i in 1 2 3; do echo "ac $i" >> "$R/a.txt"; echo "ac $i" >> "$R/c.txt"; commit "ac $i"; done
for i in 1 2 3 4 5 6 7 8 9; do echo "doc $i" >> "$R/docs/x.md"; commit "doc $i"; done
# 23 commits total

echo "shell: ${BASH_VERSION:+bash $BASH_VERSION}"

# --- 1. usage / NOT-GATED -----------------------------------------------------
out=$("$SCRIPT" --since 3d -C "$R" 2>&1); rc=$?
[ "$rc" = 2 ] && printf '%s' "$out" | grep -q NOT-GATED && ok "bad --since -> NOT-GATED" || fail "bad --since" "$out"
out=$("$SCRIPT" --top x -C "$R" 2>&1); rc=$?
[ "$rc" = 2 ] && ok "non-numeric --top -> NOT-GATED" || fail "non-numeric --top" "$out"
out=$("$SCRIPT" -C "$W" 2>&1); rc=$?
[ "$rc" = 2 ] && printf '%s' "$out" | grep -q "not a git repo" && ok "not a repo -> NOT-GATED" || fail "not a repo" "$out"

# --- 2. hotspots: ranking, exclusion, found-by ---------------------------------
out=$("$SCRIPT" --since all -C "$R" 2>&1); rc=$?
[ "$rc" = 0 ] || fail "aim exits 0 on a real repo" "$out"
first=$(printf '%s\n' "$out" | grep '^| 1 |' | head -1)
printf '%s' "$first" | grep -q '`big.txt`' && ok "hotspot #1 is the big churning file" || fail "hotspot #1" "$first"
printf '%s' "$first" | grep -q '| 7 | 206 | 1442 |' && ok "hotspot row carries commits × lines = score (7 × 206)" || fail "hotspot arithmetic" "$first"
printf '%s\n' "$out" | grep -q 'docs/x.md' && fail "excluded path leaked into hotspots" "$(printf '%s\n' "$out" | grep docs)" || ok "docs/ excluded by default"
printf '%s' "$first" | grep -q 'git log --no-merges --format=%h' && ok "hotspot row carries its found-by command" || fail "found-by missing" "$first"

# --- 3. coupling: threshold refusal below --min-commits -----------------------
out=$("$SCRIPT" --since all --min-commits 30 -C "$R" 2>&1)
printf '%s\n' "$out" | grep -q 'coupling: insufficient commits in window (23 < 30)' && ok "coupling refused below the commit threshold, with the numbers" || fail "threshold refusal" "$out"
printf '%s\n' "$out" | grep -q '^| `a.txt`' && fail "coupling table printed despite refusal" || ok "no coupling rows printed under refusal"

# --- 4. coupling: the pair appears, the imported pair is filtered -------------
out=$("$SCRIPT" --since all --min-commits 10 --min-cochange 3 -C "$R" 2>&1)
# init touches a, b and c together, so a/b co-changes 5× (4 + init); b.txt has 5 commits → ratio 5/5
printf '%s\n' "$out" | grep -q '^| `a.txt` | `b.txt` | 5 | 1.00 |' && ok "a/b co-changed 5× with ratio 5/min(8,5) appears" || fail "a/b pair" "$(printf '%s\n' "$out" | grep '^| `')"
coupling=$(printf '%s\n' "$out" | sed -n '/Temporal coupling/,$p')   # c.txt is a legitimate HOTSPOT row; only the coupling table must not show it
printf '%s\n' "$coupling" | grep -q '`c.txt`' && fail "a/c pair reported although c.txt imports a" "$(printf '%s\n' "$coupling" | grep c.txt)" || ok "a/c pair filtered — the coupling is in the code"
printf '%s\n' "$out" | grep '^| `a.txt` | `b.txt`' | grep -q 'git show --name-only' && ok "coupling row carries a reproducing found-by" || fail "coupling found-by" "$out"

# --- 5. --min-cochange above the pair count -> honest empty row ---------------
out=$("$SCRIPT" --since all --min-commits 10 --min-cochange 6 -C "$R" 2>&1)
printf '%s\n' "$out" | grep -q 'no pair reached --min-cochange 6' && ok "no qualifying pair -> says so, prints no fake row" || fail "empty coupling" "$out"

# --- 6. --since 1w on fresh commits includes them; header reports the window --
out=$("$SCRIPT" --since 1w --min-commits 10 -C "$R" 2>&1)
printf '%s\n' "$out" | grep -q '^# aim — window: 1w · commits: 23' && ok "window header reports since + commit count" || fail "header" "$(printf '%s\n' "$out" | head -1)"

# --- 7. the script spawns nothing and declares its assurance fields -----------
if grep -nE '(^|[^[:alnum:]_-])(claude|codex|droid)[[:space:]]|subagent' "$SCRIPT" >/dev/null; then fail "aim.sh invokes an agent"; else ok "aim.sh spawns nothing"; fi
miss=""; for f in PROBE: SCHEDULE: MODE: ON-FAILURE:; do grep -q "$f" "$SCRIPT" || miss="$miss $f"; done
[ -z "$miss" ] && ok "4-field assurance declaration present" || fail "assurance declaration missing:$miss"

echo "---"; echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
