#!/usr/bin/env python3
# ---
# id: 35-board-integrity
# prevents: a duplicate board record, a line that is not JSON, or a THIS-COMMIT origin-less /
#   probe-less post-cutover OPEN implementable bead sitting in the committed board unsensed — the
#   create-time guards fail open on unparseable shell (a body passed as `-d "$(cat file)"` or a
#   heredoc blinds the born-probe check), and the only repair between create and refine is a
#   backstop a bead only reaches if someone refines it. Format rules are commit-scoped so a
#   pre-existing malformed bead never blocks an unrelated commit to the ledger.
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
     `origin:` label, or an OPEN implementable bead (task/bug/feature) carrying no
     `Probe:` line. The probe axis shares the origin axis's failure mode: the born-probe
     guard reads the `br create` COMMAND, so a body passed as `-d "$(cat file)"` or a
     heredoc makes it fail open, and this artifact read is the backstop.

Closed beads are NEVER scanned — forward-only, no backfill, per the origin-provenance
ruling: enforcement started at the cutover and the past is not relitigated. An empty or
unreadable board exits 2 NOT-GATED, because a check that read nothing has proved nothing.
The check REPORTS; it never repairs — mutating the board would make this a second writer
of the origin axis (decision D-2).

Commit-scoped format rules (2026-09-12 lint audit): the whole-board rules above (valid
JSON, unique ids) always scan every line — they catch real corruption and a bead another
session wrote badly must never hide behind them. The per-bead FORMAT rules (origin: label,
Probe: line) are scoped to the ids THIS commit adds or changes whenever that can be
determined: `git show :.beads/issues.jsonl` (the staged blob) is diffed by id against
`git show HEAD:.beads/issues.jsonl` (the last commit). A bead nobody touched this commit
cannot fail it. When there is no git checkout, no HEAD yet, or the staged blob equals
HEAD's (a full run, not a commit touching the ledger), the diff is undeterminable and the
format rules fall back to today's whole-board scope — CI's bare `bash lint.sh` still
reports the whole backlog.

Exit: 0 clean (at least one record scanned), 1 findings, 2 read nothing.
"""

import json
import os
import re
import subprocess
import sys

CUTOVER = "2026-08-23"  # origin axis became a hard gate (hooks/hooks.json _doc)
IMPLEMENTABLE = ("task", "bug", "feature")  # element4's non-exempt types
PROBE = re.compile(r"Probe:\s*`[^`]+`[^\n]*\btier:")  # same shape the capture guard uses
LEDGER_REL = ".beads/issues.jsonl"


def board_path(root):
    return os.path.join(root, ".beads", "issues.jsonl")


def _git_show(root, rev_path):
    """`git show <rev_path>` from cwd=root, or None on any failure (not a git
    checkout, no such rev, git unavailable) — the caller's cue to fall back to
    whole-board scope, never a crash and never a silent wrong answer."""
    try:
        proc = subprocess.run(
            ["git", "show", rev_path], cwd=root,
            capture_output=True, text=True, timeout=10,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    return proc.stdout if proc.returncode == 0 else None


def _by_id(text):
    out = {}
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            rec = json.loads(line)
        except ValueError:
            continue
        if isinstance(rec, dict) and "id" in rec:
            out[rec["id"]] = rec
    return out


def changed_bead_ids(root):
    """Ids added or modified in the staged ledger vs HEAD's, or None when this
    cannot be determined (no git checkout, no HEAD yet) or when the staged
    blob equals HEAD's (no staged ledger change — a full run). None is the
    caller's signal to apply the per-bead format rules to the whole board."""
    staged = _git_show(root, f":{LEDGER_REL}")
    if staged is None:
        return None
    head = _git_show(root, f"HEAD:{LEDGER_REL}")
    if head is None:
        head = ""  # no HEAD yet, or the ledger is new-to-this-commit
    if staged == head:
        return None
    head_map, staged_map = _by_id(head), _by_id(staged)
    return {rid for rid, rec in staged_map.items()
            if rid not in head_map or head_map[rid] != rec}


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("LINT_ROOT", os.getcwd())
    board = board_path(root)
    if not os.path.isfile(board):
        print("NOT-GATED: no board at .beads/issues.jsonl — a check that read nothing has proved "
              "nothing", file=sys.stderr)
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

    changed_ids = changed_bead_ids(root)  # None -> undeterminable, apply format rules to all

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
        if created >= CUTOVER and (changed_ids is None or rid in changed_ids):
            labels = [str(label) for label in (rec.get("labels") or [])]
            if not any(label.startswith("origin:") for label in labels):
                violations.append(
                    f"{board}:{lineno} — open bead '{rid}' created {created} (on/after origin cutover "
                    f"{CUTOVER}) carries no origin: label")
            if rec.get("issue_type") in IMPLEMENTABLE and not PROBE.search(rec.get("description") or ""):
                violations.append(
                    f"{board}:{lineno} — open {rec.get('issue_type')} bead '{rid}' created {created} "
                    "carries no Probe: line")

    if not violations:
        print(f"35-board-integrity: {scanned} record(s) scanned — well-formed, ids unique, open "
              "post-cutover beads origin-tagged and implementable beads probe-bearing")
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
