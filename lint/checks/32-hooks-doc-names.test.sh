#!/usr/bin/env bash
# 32-hooks-doc-names.test.sh — the fixture proving Check 32's contract.
#
#   PROBE: _doc/BACKSTOP prose naming a missing ac- skill or a dead skills/
#           path is RED naming the field; a live reference resolves GREEN;
#           file names (ac-x.js) and bead ids (ac-x.y) are never read as
#           skill references; structured PENDING-DECISION fields are out of
#           scope; an empty scan is NOT-GATED (exit 2); the real hooks.json
#           is green.
#
# ASSURANCE
#   PROBE:    bash lint/checks/32-hooks-doc-names.test.sh
#   SCHEDULE: scripts/run-all-harnesses.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/32-hooks-doc-names.py"
ROOT="$(cd "$HERE/../.." && pwd)"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

run_check() { # <tmp-root> <out-file> -> exit code
  python3 "$CHECK" "$1" > "$2" 2>&1
  echo $?
}

write_manifest() { # <root> <doc-text> <backstop-text> <pending-text>
  local root="$1" doc="$2" backstop="$3" pending="$4"
  mkdir -p "$root/hooks" "$root/skills/real"
  printf -- '---\nname: real\ndescription: "the one live skill"\n---\n\n# real\n' > "$root/skills/real/SKILL.md"
  printf '%s' "$(cat <<EOF
{
  "wiring": [
    {
      "id": "demo",
      "_doc": "$doc",
      "assurance": {"PROBE": "p", "SCHEDULE": "s", "MODE": "advisory", "ON-FAILURE": "open", "BACKSTOP": "$backstop", "PENDING-DECISION": "$pending"}
    }
  ]
}
EOF
)" > "$root/hooks/hooks.json"
}

# --- RED: _doc naming a missing ac- skill --------------------------------------
w="$(mktemp -d)"
write_manifest "$w" "Fails open because the ac-missing-skill stamp-gate is the backstop." "the live backstop." "ac-on0y.5"
rc=$(run_check "$w" /tmp/32hd-out.txt)
if [ "$rc" = 1 ] && grep -q "'ac-missing-skill' names no live" /tmp/32hd-out.txt; then
  ok "RED: missing ac- skill -> exit 1 naming the field"
else
  bad "RED case: expected 1 naming ac-missing-skill, got $rc"; cat /tmp/32hd-out.txt
fi
rm -rf "$w"

# --- RED: BACKSTOP naming a missing skill --------------------------------------
w="$(mktemp -d)"
write_manifest "$w" "All live references here." "the ac-ghost-backstop catches it." "ac-on0y.5"
rc=$(run_check "$w" /tmp/32hd-out.txt)
if [ "$rc" = 1 ] && grep -q "assurance/BACKSTOP: skill reference 'ac-ghost-backstop'" /tmp/32hd-out.txt; then
  ok "RED: BACKSTOP missing skill -> exit 1 naming the field"
else
  bad "BACKSTOP case: expected 1, got $rc"; cat /tmp/32hd-out.txt
fi
rm -rf "$w"

# --- RED: dead skills/ path reference ------------------------------------------
w="$(mktemp -d)"
write_manifest "$w" "Docs live at skills/nope/SKILL.md." "the live backstop." "ac-on0y.5"
rc=$(run_check "$w" /tmp/32hd-out.txt)
if [ "$rc" = 1 ] && grep -q "'skills/nope/SKILL.md' does not exist" /tmp/32hd-out.txt; then
  ok "RED: dead skills/ path -> exit 1"
else
  bad "PATH case: expected 1, got $rc"; cat /tmp/32hd-out.txt
fi
rm -rf "$w"

# --- GREEN: live references resolve; file names and bead ids stay quiet --------
w="$(mktemp -d)"
write_manifest "$w" "Renders to plugins/ac-demo.js; re-filed as bead ac-on0y.5; see skills/real/SKILL.md." "skills/real/SKILL.md carries it." "ac-on0y.5"
rc=$(run_check "$w" /tmp/32hd-out.txt)
if [ "$rc" = 0 ]; then
  ok "GREEN: live refs resolve; ac-demo.js and ac-on0y.5 not read as skills"
else
  bad "GREEN case: expected 0, got $rc"; cat /tmp/32hd-out.txt
fi
rm -rf "$w"

# --- OUT OF SCOPE: a PENDING-DECISION bead id never fails the check ------------
w="$(mktemp -d)"
write_manifest "$w" "All live references here." "the live backstop." "ac-dcg-fails-closed-u7hj"
rc=$(run_check "$w" /tmp/32hd-out.txt)
if [ "$rc" = 0 ]; then
  ok "SCOPE: PENDING-DECISION bead id out of scope -> exit 0"
else
  bad "SCOPE case: expected 0, got $rc"; cat /tmp/32hd-out.txt
fi
rm -rf "$w"

# --- EMPTY: no manifest -> NOT-GATED exit 2 ------------------------------------
w="$(mktemp -d)"
rc=$(run_check "$w" /tmp/32hd-out.txt)
if [ "$rc" = 2 ] && grep -qi "NOT-CHECKED" /tmp/32hd-out.txt; then
  ok "EMPTY: no manifest -> NOT-GATED exit 2"
else
  bad "EMPTY case: expected 2 NOT-CHECKED, got $rc"; cat /tmp/32hd-out.txt
fi
rm -rf "$w"

# --- REAL: the live hooks.json resolves clean ----------------------------------
rc=$(python3 "$CHECK" >/tmp/32hd-out.txt 2>&1; echo $?)
if [ "$rc" = 0 ]; then
  ok "REAL: live hooks.json -> exit 0"
else
  bad "REAL: expected 0, got $rc"; cat /tmp/32hd-out.txt
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "All 32-hooks-doc-names contract cases passed."
  exit 0
fi
echo "$fails case(s) FAILED."
exit 1
