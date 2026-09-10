#!/usr/bin/env python3
# ---
# id: 35-board-integrity
# prevents: a duplicate board record, a line that is not JSON, or an origin-less post-cutover OPEN bead sitting in the committed board unsensed — the create-time origin guards fail open on unparseable shell, and the only repair between create and refine is a backstop a bead only reaches if someone refines it
# scope: HOOKS
# severity: fail
# fixture: lint/fixtures/35-board-integrity
# ---
"""35-board-integrity — the committed board stays well-formed and origin-tagged (ac-heyt.9).

The origin axis has two enforcers — the runtime capture guard and Check 19 — both at
CREATE time and both fail-open on unparseable shell. This check puts a sensor at the one
door every board change already walks through: the pre-commit chain runs `lint.sh
--changed`, and `.beads/issues.jsonl` is in HOOKS scope, so the LEDGER COMMIT ITSELF is
the gate.

Three FAIL rules over the committed board:
  1. a line that is not JSON;
  2. an `id` that appears more than once;
  3. an OPEN bead created on or after the origin cutover (2026-08-23 — the date the
     hooks manifest's `_doc` records the origin axis becoming a hard gate) carrying no
     `origin:` label.

Closed beads are NEVER scanned — forward-only, no backfill, per the origin-provenance
ruling: enforcement started at the cutover and the past is not relitigated. An empty or
unreadable board exits 2 NOT-GATED, because a check that read nothing has proved nothing.
The check REPORTS; it never repairs — mutating the board would make this a second writer
of the origin axis (decision D-2).

Exit: 0 clean (at least one record scanned), 1 findings, 2 read nothing.
"""

import json
import os
import sys

CUTOVER = "2026-08-23"  # origin axis became a hard gate (hooks/hooks.json _doc)


def board_path(root):
    return os.path.join(root, ".beads", "issues.jsonl")


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("LINT_ROOT", os.getcwd())
    board = board_path(root)
    if not os.path.isfile(board):
        print("NOT-GATED: no board at .beads/issues.jsonl — a check that read nothing has proved nothing", file=sys.stderr)
        return 2
    try:
        with open(board, encoding="utf-8", errors="replace") as fh:
            lines = fh.read().splitlines()
    except OSError as exc:
        print(f"NOT-GATED: board unreadable: {exc} — a check that read nothing has proved nothing", file=sys.stderr)
        return 2
    if not lines:
        print("NOT-GATED: board is empty — a check that read nothing has proved nothing", file=sys.stderr)
        return 2

    violations = []
    seen_ids = {}
    scanned = 0
    for lineno, raw in enumerate(lines, 1):
        line = raw.strip()
        if not line:
            continue
        try:
            rec = json.loads(line)
        except ValueError:
            violations.append(f"{board}:{lineno} — line is not JSON")
            continue
        if not isinstance(rec, dict) or "id" not in rec:
            violations.append(f"{board}:{lineno} — record carries no 'id'")
            continue
        scanned += 1
        rid = rec.get("id")
        if rid in seen_ids:
            violations.append(f"{board}:{lineno} — duplicate id '{rid}' (first seen at line {seen_ids[rid]})")
        else:
            seen_ids[rid] = lineno
        if rec.get("status") != "open":
            continue  # closed beads are NEVER scanned — forward-only, no backfill
        created = str(rec.get("created_at") or "")[:10]
        if created >= CUTOVER:
            labels = [str(l) for l in (rec.get("labels") or [])]
            if not any(l.startswith("origin:") for l in labels):
                violations.append(
                    f"{board}:{lineno} — open bead '{rid}' created {created} (on/after origin cutover {CUTOVER}) carries no origin: label")

    if not violations:
        print(f"35-board-integrity: {scanned} record(s) scanned — well-formed, ids unique, open post-cutover beads origin-tagged")
        return 0
    print("FAIL 35-board-integrity: committed board violates a board-integrity rule:")
    for v in violations:
        print(f"  - {v}")
    return 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:  # fail loud: a crashed check is never a pass
        print(f"FAIL 35-board-integrity: crashed: {exc}", file=sys.stderr)
        sys.exit(1)