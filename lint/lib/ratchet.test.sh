#!/usr/bin/env bash
# ratchet.test.sh — the contract harness for lint/lib/ratchet.py.
#
#   PROBE: `DATE key  # why` parses; a comment/blank line is ignored; a
#           malformed line is a defect, not a crash; `base_ref()` honours
#           LINT_BASE_REF over the default, and falls back to HEAD^ when
#           nothing else resolves; `committed_keys()` is None for a path
#           absent at base (the seed case) and reads the key set (tolerant
#           of an undated pre-migration line) when present;
#           `shrink_only()` reports growth and nothing else.
set -uo pipefail
LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# --- 1 load_allowlist: DATE key, DATE key # why, comments/blanks ignored, ----
# --- a malformed line reported as a defect, never a crash -------------------
f="$work/one.txt"
cat > "$f" <<'TXT'
# header comment

2026-09-07 skills/a/references/x.md
2026-09-08 skills/b/references/y.md  # explained here
not-a-valid-line
TXT
out="$(PYTHONPATH="$LIB" python3 - "$f" <<'EOF'
import sys
import ratchet
entries, defects = ratchet.load_allowlist(sys.argv[1])
print("entries", entries)
print("defects", len(defects))
if defects:
    print("defect0", defects[0])
EOF
)"
if echo "$out" | grep -q "entries \[('2026-09-07', 'skills/a/references/x.md'), ('2026-09-08', 'skills/b/references/y.md')\]" \
   && echo "$out" | grep -q "defects 1" \
   && echo "$out" | grep -q "not-a-valid-line"; then
  ok "load_allowlist: parses DATE key [# why], comments/blanks ignored, malformed line is a defect"
else
  bad "load_allowlist: unexpected output"; echo "$out"
fi

# --- 2 keys(): key column only, in file order --------------------------------
out="$(PYTHONPATH="$LIB" python3 - "$f" <<'EOF'
import sys
import ratchet
print(ratchet.keys(sys.argv[1]))
EOF
)"
if [ "$out" = "['skills/a/references/x.md', 'skills/b/references/y.md']" ]; then
  ok "keys: key column only, in file order"
else
  bad "keys: expected the two keys in order, got: $out"
fi

# --- 3 base_ref(): LINT_BASE_REF env wins over the default -------------------
t="$work/repo"; mkdir -p "$t"
git -C "$t" init -q
git -C "$t" -c user.name=h -c user.email=h@x commit -q --allow-empty -m c1
C1=$(git -C "$t" rev-parse HEAD)
git -C "$t" -c user.name=h -c user.email=h@x commit -q --allow-empty -m c2
C2=$(git -C "$t" rev-parse HEAD)
git -C "$t" -c user.name=h -c user.email=h@x commit -q --allow-empty -m c3

out="$(LINT_BASE_REF="$C1" PYTHONPATH="$LIB" python3 - "$t" <<'EOF'
import sys
import ratchet
print(ratchet.base_ref(sys.argv[1]))
EOF
)"
if [ "$out" = "$C1" ]; then
  ok "base_ref: LINT_BASE_REF env resolved and used verbatim (a bare sha, no merge-base needed since it IS an ancestor)"
else
  bad "base_ref: expected $C1, got $out"
fi

# --- 4 base_ref(): no env, no default ref resolvable -> HEAD^ ----------------
out="$(PYTHONPATH="$LIB" python3 - "$t" <<'EOF'
import sys
import ratchet
print(ratchet.base_ref(sys.argv[1], default="origin/main"))
EOF
)"
if [ "$out" = "$C2" ]; then
  ok "base_ref: unresolvable default falls back to HEAD^"
else
  bad "base_ref: expected HEAD^ ($C2), got $out"
fi

# --- 5 committed_keys(): None when the path is absent at base (seed case) ----
out="$(PYTHONPATH="$LIB" python3 - "$t" "$C1" <<'EOF'
import sys
import ratchet
print(ratchet.committed_keys(sys.argv[1], sys.argv[2], "allow.txt"))
EOF
)"
if [ "$out" = "None" ]; then
  ok "committed_keys: None when the path did not exist at base (seed case)"
else
  bad "committed_keys: expected None, got $out"
fi

# --- 6 committed_keys(): reads the key set at base, tolerant of an undated ---
# --- pre-migration line (bare token, no date) --------------------------------
printf '%s\n' '# header' '2026-09-07 skills/a/x.md' 'bare-legacy-key' > "$t/allow.txt"
git -C "$t" add allow.txt
git -C "$t" -c user.name=h -c user.email=h@x commit -q -m "add allowlist"
BASE=$(git -C "$t" rev-parse HEAD)
out="$(PYTHONPATH="$LIB" python3 - "$t" "$BASE" <<'EOF'
import sys
import ratchet
print(sorted(ratchet.committed_keys(sys.argv[1], sys.argv[2], "allow.txt")))
EOF
)"
if [ "$out" = "['bare-legacy-key', 'skills/a/x.md']" ]; then
  ok "committed_keys: dated and pre-migration bare-token lines both read as keys"
else
  bad "committed_keys: expected both keys, got $out"
fi

# --- 7 shrink_only(): growth is current-minus-committed; None committed ------
# --- (the seed) reports no growth --------------------------------------------
out="$(PYTHONPATH="$LIB" python3 - <<'EOF'
import ratchet
print(sorted(ratchet.shrink_only(["a", "b", "c"], ["a", "b"])))
print(ratchet.shrink_only(["a", "b"], ["a", "b", "c"]))
print(ratchet.shrink_only(["a"], None))
EOF
)"
want="$(printf "['c']\n[]\n[]")"
if [ "$out" = "$want" ]; then
  ok "shrink_only: growth is current-minus-committed; a shrink or the seed case reports nothing"
else
  bad "shrink_only: unexpected output"; echo "$out"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "All ratchet.py contract cases passed."
  exit 0
fi
echo "$fails case(s) FAILED."
exit 1
