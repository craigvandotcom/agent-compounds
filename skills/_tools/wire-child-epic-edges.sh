#!/usr/bin/env bash
# wire-child-epic-edges.sh — ONE-SHOT migration (WS-F, ac-epic-is-the-last-bead-nu5h.6).
#
# Migrates a board onto the epic-is-last-bead shape: for every OPEN epic, every OPEN
# DIRECT child carries a child→epic `blocks` edge. DIRECT = the dotted id's immediate
# parent (`bid.rsplit('.', 1)[0]`) UNION a direct parent-child edge. Grandchildren are
# deliberately excluded: `br` treats epic containment as blocking, so a
# grandchild→grand-epic edge is refused as a cycle (measured on bd-l6khg.15.3), and the
# D2 predicate only blesses pairs a parent-child edge already joins. Transitive
# readiness propagates through the chain the direct edges form. That pair
# (child→parent direction + the structural parent-child edge) is exactly the D2
# predicate (beads-standards), so the wired edges are legal on sight.
#
# Usage:
#   wire-child-epic-edges.sh [--check] <board-dir>
#     default  add each missing edge, print the edge list, then gate on `br dep cycles`
#     --check  exit 0 iff every open DIRECT child is edge-wired AND every open epic carries
#              probe-bearing ACs (element-4 PASS plus >= 1 `Probe:` line, the stamp floor);
#              names what is missing otherwise (bd-l6khg.15 is the known probe-less epic;
#              the script reports the rest)
#
# `br` resolves its board from the CWD, so every board read/write runs with cwd inside
# <board-dir>. CLOSED children are never wired: the terminal pick only waits on open ones.
#
# One-shot: deleted by the closeout of this epic's plan once the closeout mechanism
# (plan 2026-09-10-1654) lands.
#
# HARD TOOL LIMIT (measured 2026-09-12, br 0.5.12, WS-F migration): the `dependencies`
# table is PRIMARY KEY (issue_id, depends_on_id) and br enforces a single parent, so a
# child→epic `blocks` edge CANNOT coexist with the structural parent-child edge for the
# same pair — and `br dep add` reports `Dependency already exists` with EXIT 0 while
# writing nothing. Wire mode therefore treats that message as a REFUSAL (an exit-0
# no-op must never read as WIRED), and --check names the unwireable pairs. Wiring the
# BCA board needs br support for multi-type pairs (or a D2 re-read); until then this
# script is a truthful reporter, not a wire.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ELEMENT4_CHECK="$SCRIPT_DIR/element4-check.sh"

CHECK=0
if [ "${1:-}" = "--check" ]; then CHECK=1; shift; fi
BOARD="${1:-}"
[ -n "$BOARD" ] || { echo "usage: $(basename "$0") [--check] <board-dir>" >&2; exit 2; }
[ -d "$BOARD" ] || { echo "wire-child-epic-edges: no such board dir: $BOARD" >&2; exit 2; }

export RUST_LOG="${RUST_LOG:-error}"

board_json() { # <br args...> — run br inside the board dir, print stdout
  (cd "$BOARD" && br "$@")
}

# --- load the open board -------------------------------------------------------
OPEN_JSON="$(mktemp "${TMPDIR:-/tmp}/wire-edges-open.XXXXXX")"
trap 'rm -f "$OPEN_JSON"' EXIT
board_json list --status open --json >"$OPEN_JSON" \
  || { echo "wire-child-epic-edges: 'br list' refused in $BOARD" >&2; exit 2; }

MAP="$(mktemp "${TMPDIR:-/tmp}/wire-edges-map.XXXXXX")"
trap 'rm -f "$OPEN_JSON" "$MAP"' EXIT
python3 - "$OPEN_JSON" "$MAP" <<'EOF'
import json, sys
items = json.load(open(sys.argv[1]))
items = items.get('issues', items) if isinstance(items, dict) else items
open_ids = {b['id'] for b in items}
out = {'epics': {}, 'descs': {}}
for e in items:
    if e.get('issue_type') != 'epic':
        continue
    eid = e['id']
    kids = set()
    for b in items:
        bid = b['id']
        if bid == eid:
            continue
        if '.' in bid and bid.rsplit('.', 1)[0] == eid:
            kids.add(bid)
            continue
        for dep in (b.get('dependencies') or []):
            if dep.get('dependency_type') == 'parent-child' and dep.get('id') == eid:
                kids.add(bid)
    wired = set()
    for kid in kids:
        b = next((x for x in items if x['id'] == kid), None)
        for dep in ((b or {}).get('dependencies') or []):
            if dep.get('dependency_type') == 'blocks' and dep.get('id') == eid:
                wired.add(kid)
    out['epics'][eid] = {'kids': sorted(kids), 'wired': sorted(wired)}
    out['descs'][eid] = e.get('description') or ''
json.dump(out, open(sys.argv[2], 'w'))
EOF

EPICS=$(python3 -c "import json; print(chr(10).join(sorted(json.load(open('$MAP'))['epics'])))")
[ -n "$EPICS" ] || { echo "wire-child-epic-edges: no open epics in $BOARD" >&2; exit 2; }

missing_edges=0
probe_bare=()

while IFS= read -r epic; do
  [ -n "$epic" ] || continue
  kids=$(python3 -c "import json; print(chr(10).join(json.load(open('$MAP'))['epics']['$epic']['kids']))")
  wired=$(python3 -c "import json; print(chr(10).join(json.load(open('$MAP'))['epics']['$epic']['wired']))")
  while IFS= read -r kid; do
    [ -n "$kid" ] || continue
    if printf '%s\n' "$wired" | grep -qxF "$kid"; then
      [ "$CHECK" = 1 ] || printf 'wire-child-epic-edges: HAVE %s -> %s\n' "$kid" "$epic"
    else
      if [ "$CHECK" = 1 ]; then
        printf 'wire-child-epic-edges: MISSING-EDGE %s -> %s\n' "$kid" "$epic"
        missing_edges=$((missing_edges + 1))
      else
        add_out="$(board_json dep add "$kid" "$epic" -t blocks 2>&1)"; rc=$?
        if [ "$rc" -eq 0 ] && ! printf '%s\n' "$add_out" | grep -qi 'already exists'; then
          printf 'wire-child-epic-edges: WIRED %s -> %s\n' "$kid" "$epic"
        else
          echo "wire-child-epic-edges: FAILED to wire $kid -> $epic (br refused: ${add_out:-exit $rc})" >&2
          exit 1
        fi
      fi
    fi
  done <<< "$kids"

  # probe-bearing test: the registry gate's verdict plus the stamp's probe floor
  desc_tmp="$(mktemp "${TMPDIR:-/tmp}/wire-edges-desc.XXXXXX")"
  python3 -c "import json; open('$desc_tmp','w').write(json.load(open('$MAP'))['descs']['$epic'])"
  if bash "$ELEMENT4_CHECK" --file "$desc_tmp" --type epic >/dev/null 2>&1 \
     && grep -q 'Probe:' "$desc_tmp"; then
    [ "$CHECK" = 1 ] || printf 'wire-child-epic-edges: PROBED %s\n' "$epic"
  else
    printf 'wire-child-epic-edges: PROBELESS-EPIC %s\n' "$epic"
    probe_bare+=("$epic")
  fi
  rm -f "$desc_tmp"
done <<< "$EPICS"

if [ "$CHECK" = 1 ]; then
  if [ "$missing_edges" -eq 0 ] && [ "${#probe_bare[@]}" -eq 0 ]; then
    echo "wire-child-epic-edges: CHECK PASS — every open direct child edge-wired, every open epic probe-bearing"
    exit 0
  fi
  echo "wire-child-epic-edges: CHECK FAIL — $missing_edges missing edge(s), ${#probe_bare[@]} probeless epic(s)" >&2
  if [ "$missing_edges" -gt 0 ]; then
    echo "wire-child-epic-edges: NOTE — br 0.5.12 stores PRIMARY KEY (issue_id, depends_on_id): a blocks edge cannot coexist with the structural parent-child edge, so these pairs are unwireable until br supports multi-type pairs" >&2
  fi
  exit 1
fi

# wire mode lands the edges, then the cycles gate runs: a cycle is a refusal, not output
CYCLES_OUT="$(board_json dep cycles 2>&1)"; rc=$?
printf '%s\n' "$CYCLES_OUT"
[ "$rc" -eq 0 ] || { echo "wire-child-epic-edges: 'br dep cycles' refused" >&2; exit 1; }
printf '%s\n' "$CYCLES_OUT" | grep -qiE 'no .*cycles|0 cycles' \
  || { echo "wire-child-epic-edges: CYCLES PRESENT — refusing" >&2; exit 1; }
echo "wire-child-epic-edges: WIRE COMPLETE — cycles clean"
