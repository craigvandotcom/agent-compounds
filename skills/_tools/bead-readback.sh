#!/usr/bin/env bash
# bead-readback.sh — the ONE read-back gate after ac-beadify writes bead bodies to the board.
#
# Canon: skills/ac-beadify/SKILL.md step 6 and references/bead-schema.md § Filing. Every bead
# body the compile wrote is read BACK from the board (`br show <id> --json`) and graded there —
# never from the local file the writer meant to send:
#
#   UNRESOLVED  the board description still carries a `__EPIC__` / `__B<n>__` placeholder
#   DRIFT       the board description differs from the resolved file it was written from
#               (trailing newlines ignored: `-d "$(cat f)"` strips them, --description-file
#               keeps them verbatim)
#   PARITY      `## Consumes` blocker ids parsed from the BOARD description differ from the
#               bead's `blocks` edges on the board, in either direction
#
# WHY (measured 2026-09-28, easy-mode epic bd-wyun, commit f07d607): the filing script created
# beads with placeholder bodies, resolved them into resolved/*.md, and wrote each back with
# `br update "${ID[$b]}" -d "$(cat resolved/$b.md)"`. The resolver looped `for b in B11 … B1`
# without `local b`, so it clobbered the caller's `$b` to B1 and every rewrite landed on the B1
# bead with B1's own body — rc 0 each time, and 10 of 12 bodies kept their placeholders. `br`
# itself persisted every write it was given (repro: a scratch .beads, same bodies; none was
# shorter than half its current length, so br's --force destructive-rewrite rule never fired).
# The script's parity check parsed Consumes from the LOCAL resolved files, so it printed
# `parity: OK`; ac-polish found 47 occurrences only at writeback. A read-back of the board is
# the only check that sees what the writer actually did.
#
# ASSURANCE (ac-pipeline/references/assurance-declarations.md § The four fields):
#   PROBE:      skills/_tools/bead-readback.test.sh — the 2026-09-28 clobber reproduced against
#               a real br in a throwaway .beads, plus DRIFT, PARITY and NOT-GATED
#   SCHEDULE:   every ac-beadify compile, after the last body write and edge; on every CI run
#               via scripts/run-all-proofs.sh
#   MODE:       blocking
#   ON-FAILURE: closed   (an unreadable bead or file is NOT-GATED, never OK)
#
# Usage:   bead-readback.sh check <id>=<resolved-file> [<id>=<resolved-file> …]
# Output:  one `readback: <CLASS> <id> …` line per finding, then `readback: OK <n> beads` or
#          `readback: FAIL <n> findings`.
# Exit:    0 clean · 1 findings · 2 NOT-GATED (bad usage, missing file, br read refused)
# Env:     AC2_BR_CMD — the br binary (default: br), honoured through br_call.

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=br-call.sh
. "$HERE/br-call.sh"
export RUST_LOG="${RUST_LOG:-error}"

usage() { echo "usage: bead-readback.sh check <id>=<resolved-file> [...]" >&2; exit 2; }
[ "${1-}" = check ] || usage
shift
[ $# -gt 0 ] || usage

findings=0 n=0
for pair in "$@"; do
  id="${pair%%=*}" file="${pair#*=}"
  { [ -n "$id" ] && [ "$id" != "$pair" ] && [ -n "$file" ]; } || usage
  [ -r "$file" ] || { echo "readback: NOT-GATED $id — resolved file unreadable: $file" >&2; exit 2; }
  json=$(br_call show "$id" --json) || { echo "readback: NOT-GATED $id — br show refused" >&2; exit 2; }
  out=$(printf '%s' "$json" | python3 -c '
import json, re, sys
id_, path = sys.argv[1], sys.argv[2]
d = json.load(sys.stdin)
d = d[0] if isinstance(d, list) and d else d
if not isinstance(d, dict) or d.get("id") != id_:
    print("NOT-GATED %s — br show returned no such bead" % id_); sys.exit(2)
board = d.get("description") or ""
want = open(path, encoding="utf-8").read()
ph = re.findall(r"__(?:B\d+|EPIC)__", board)
if ph:
    print("UNRESOLVED %s — %d placeholder(s) on the board: %s" % (id_, len(ph), " ".join(sorted(set(ph)))))
if board.rstrip("\n") != want.rstrip("\n"):
    print("DRIFT %s — board description (%d chars) differs from %s (%d chars)" % (id_, len(board), path, len(want)))
m = re.search(r"^## Consumes[^\n]*\n(.*?)(?=^## |\Z)", board, re.M | re.S)
cons = set(re.findall(r"^\s*-\s+(\S+)\s+->\s", m.group(1), re.M)) if m else set()
edges = {x.get("depends_on_id") or x.get("id") for x in (d.get("dependencies") or [])
         if (x.get("dependency_type") or x.get("type")) == "blocks"}
if cons != edges:
    print("PARITY %s — board Consumes cites %s, board blocks edges %s" % (id_, sorted(cons), sorted(edges)))
' "$id" "$file")
  rc=$?
  [ "$rc" -eq 2 ] && { echo "readback: $out" >&2; exit 2; }
  [ "$rc" -eq 0 ] || { echo "readback: NOT-GATED $id — parse failed" >&2; exit 2; }
  n=$((n + 1))
  if [ -n "$out" ]; then
    printf '%s\n' "$out" | sed 's/^/readback: /'
    findings=$((findings + $(printf '%s\n' "$out" | wc -l)))
  fi
done

if [ "$findings" -gt 0 ]; then echo "readback: FAIL $findings findings"; exit 1; fi
echo "readback: OK $n beads"
