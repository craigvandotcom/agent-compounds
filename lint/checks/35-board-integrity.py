#!/usr/bin/env python3
# ---
# id: 35-board-integrity
# prevents: a duplicate board record (rule 2); a line that is not JSON (rule 1); an off-canon
#   status (rule 4); an OPEN post-cutover implementable bead sitting origin-less or probe-less
#   (rule 3); a malformed WORKER: receipt (rule 5); a closed bead whose landing record cites no
#   evidence (rule 6) — the create-time guards fail open on unparseable shell (a body passed as
#   `-d "$(cat file)"` or a heredoc blinds the born-probe check) and close-gate.sh's bypass leaves
#   no other sensor, so the committed board itself is the backstop every one of these rules reads.
# scope: HOOKS
# severity: fail
# fixture: lint/fixtures/35-board-integrity
# ---
"""35-board-integrity — the board stays well-formed, origin-tagged and receipt-honest.

Six FAIL rules, all scanning the WHOLE board on every run (no staged-vs-HEAD diff — the
board is adopter-local and gitignored, so there is nothing to diff against):

  1. a line that is not JSON.
  2. an `id` that appears more than once.
  3. an OPEN bead created on or after the origin cutover (`CUTOVER` below) carrying no
     `origin:` label, or an OPEN implementable bead (task/bug/feature) carrying no
     `Probe:` line. Forward-only, no backfill: closed beads and beads created before the
     cutover are never scanned.
  4. ANY row (either status, both lanes) whose `status` is outside the canon set
     (`skills/beads-standards/SKILL.md` § Status & priority canon: open / in_progress /
     blocked / deferred / closed / tombstone).
  5. a `WORKER:`-prefixed comment whose own `created_at` is on or after `RULE56_CUTOVER`
     (below) and whose first line does not match the canon grammar's three fields,
     `model=`/`actor=`/`tree=` (§ Worker-identity stamp) — shape only, never the fields'
     truth. A canon first line followed by note lines is green. Forward-only by the
     comment's own timestamp: a pre-existing malformed receipt from before the cutover is
     never re-judged.
  6. a CLOSED bead whose `closed_at` is on or after `RULE56_CUTOVER` and which carries no
     comment naming its evidence: `GATE: receipt` must cite `receipt-at: <stamp>` matching
     an `at: <stamp>` line on another comment of the same row; `GATE: decided` must cite
     `ruling-comment: #<id>` matching a same-row comment with that id whose text starts
     `DECISION (`; `FRESH-VERIFY:`/`TRIAGE-CLOSE:` must self-cite `tree: <sha>`. A bare
     landing comment with no citation resolving against the row is RED, not a pass — the
     record cites its evidence, or it is refused. Forward-only by the bead's own
     `closed_at`: a close that happened before the cutover is never re-judged.

Rules 1, 2 and 4 scan every row unconditionally — they catch corruption at any lifecycle
stage. Rules 3, 5 and 6 are each forward-only by their own cutover and their own
timestamp field (a bead's `created_at` for rule 3, a comment's `created_at` for rule 5, a
bead's `closed_at` for rule 6) — enforcement started at each cutover and the past is not
relitigated. An empty or unreadable board exits 2 NOT-GATED, because a check that read
nothing has proved nothing. The check REPORTS; it never repairs — mutating the board would
make this a second writer of the axes it enforces.

Exit: 0 clean (at least one record scanned), 1 findings, 2 read nothing,
77 skipped (no board file — adopter-local, gitignored).
"""

import importlib.util
import json
import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_REGISTRY_ROOT = os.path.dirname(os.path.dirname(_HERE))  # lint/checks -> lint -> root


def _load_guard(registry_root):
    spec = importlib.util.spec_from_file_location(
        "bead_capture_guard", os.path.join(registry_root, "hooks", "bead-capture-guard.py")
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


guard = _load_guard(_REGISTRY_ROOT)
PROBE = guard.PROBE  # the same shape the runtime capture guard scans for

CUTOVER = "2026-08-23"  # rule 3: origin axis became a hard gate (hooks/hooks.json _doc)
RULE56_CUTOVER = "2026-09-23"  # rule 5/6: forward-only from this date — earlier receipts/closes are never re-judged
IMPLEMENTABLE = ("task", "bug", "feature")  # element4's non-exempt types
# canon status set — skills/beads-standards/SKILL.md § Status & priority canon
STATUS_CANON = {"open", "in_progress", "blocked", "deferred", "closed", "tombstone"}
# canon WORKER: grammar — skills/beads-standards/SKILL.md § Worker-identity stamp
WORKER_RE = re.compile(r"^WORKER: model=\S+ actor=\S+ tree=\S+$")
# rule 6's evidence citations — the exact tokens close-gate.sh's landing text carries
RECEIPT_CITE_RE = re.compile(r"receipt-at:\s*([^\s;]+)")
DECIDED_CITE_RE = re.compile(r"ruling-comment:\s*#(\d+)")
TREE_CITE_RE = re.compile(r"tree:\s*([0-9a-f]{4,40})")
DECISION_LINE_RE = re.compile(r"^DECISION \(")

RULE_LABELS = {
    1: "rule 1 — line is not JSON",
    2: "rule 2 — duplicate id",
    3: f"rule 3 — open bead missing origin:/Probe: (created on/after {CUTOVER})",
    4: "rule 4 — status outside the canon set",
    5: f"rule 5 — malformed WORKER: receipt (on/after {RULE56_CUTOVER})",
    6: f"rule 6 — closed bead with no cited landing record (closed on/after {RULE56_CUTOVER})",
}
RULE_HINTS = {
    1: "repair: fix the line to valid JSON, or remove the row",
    2: "repair: give the row a unique id — ids must be unique across the whole board",
    3: "repair: br update <id> --add-label origin:<skill>  (and add a `Probe: `...`` line "
       "to the description for an implementable bead)",
    4: "repair: br update <id> --status <open|in_progress|blocked|deferred|closed|tombstone>",
    5: "repair: rewrite the comment's first line to the canon grammar: "
       "WORKER: model=<id> actor=<id> tree=<sha>",
    6: "repair: close through skills/ac-implement/scripts/close-gate.sh — a GATE:/"
       "FRESH-VERIFY:/TRIAGE-CLOSE: comment must cite its evidence (receipt-at / "
       "ruling-comment / tree)",
}


def board_path(root):
    return os.path.join(root, ".beads", "issues.jsonl")


def _landing_cited(landing, all_comments):
    """True when a single landing comment's citation resolves against another
    comment on the SAME row — the exact cross-check close-gate.sh's own landing
    text supports (receipt-at / ruling-comment / tree)."""
    if landing.startswith("GATE: receipt"):
        m = RECEIPT_CITE_RE.search(landing)
        if not m:
            return False
        stamp = m.group(1)
        return any(
            isinstance(c, dict)
            and re.search(rf"(?m)^at:\s*{re.escape(stamp)}\s*$", str(c.get("text") or ""))
            for c in all_comments
        )
    if landing.startswith("GATE: decided"):
        m = DECIDED_CITE_RE.search(landing)
        if not m:
            return False
        return any(
            isinstance(c, dict) and str(c.get("id")) == m.group(1)
            and DECISION_LINE_RE.match(str(c.get("text") or "").strip())
            for c in all_comments
        )
    if landing.startswith(("FRESH-VERIFY:", "TRIAGE-CLOSE:")):
        return bool(TREE_CITE_RE.search(landing))
    return False


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("LINT_ROOT", os.getcwd())
    board = board_path(root)
    rel = os.path.relpath(board, root)
    if not os.path.isfile(board):
        # The board is adopter-local and gitignored (it is each deployment's own work
        # ledger, not shipped registry content), so a checkout carrying none has
        # nothing to gate. Skip, never claim a pass. A board that EXISTS but is
        # unreadable or empty stays fail-closed below.
        print("35-board-integrity skipped: no board at .beads/issues.jsonl — the board is "
              "adopter-local (gitignored), nothing to gate")
        return 77
    try:
        with open(board, encoding="utf-8", errors="replace") as fh:
            lines = fh.read().splitlines()
    except OSError as exc:
        print(f"NOT-GATED: board unreadable: {exc} — a check that read nothing has proved nothing", file=sys.stderr)
        return 2
    if not lines:
        print("NOT-GATED: board is empty — a check that read nothing has proved nothing", file=sys.stderr)
        return 2

    violations = {n: [] for n in RULE_LABELS}
    seen_ids = {}
    scanned = 0
    for lineno, raw in enumerate(lines, 1):
        line = raw.strip()
        if not line:
            continue
        try:
            rec = json.loads(line)
        except ValueError:
            violations[1].append(f"{rel}:{lineno} — line is not JSON")
            continue
        if not isinstance(rec, dict) or "id" not in rec:
            violations[1].append(f"{rel}:{lineno} — record carries no 'id'")
            continue
        scanned += 1
        rid = rec.get("id")
        if rid in seen_ids:
            violations[2].append(f"{rel}:{lineno} — duplicate id '{rid}' (first seen at line {seen_ids[rid]})")
        else:
            seen_ids[rid] = lineno

        status = rec.get("status")
        if status not in STATUS_CANON:
            violations[4].append(
                f"{rel}:{lineno} — bead '{rid}' has status '{status}', outside the canon "
                f"set {sorted(STATUS_CANON)}")

        # rule 5 — every WORKER: comment on this row, forward-only by the comment's own
        # created_at against RULE56_CUTOVER; a pre-cutover receipt is never re-judged.
        for comment in rec.get("comments") or []:
            if not isinstance(comment, dict):
                continue
            text = str(comment.get("text") or "")
            stripped = text.strip()
            if not stripped.startswith("WORKER:"):
                continue
            if str(comment.get("created_at") or "")[:10] < RULE56_CUTOVER:
                continue
            first_line = stripped.splitlines()[0]
            if not WORKER_RE.match(first_line):
                violations[5].append(
                    f"{rel}:{lineno} — bead '{rid}' comment {stripped!r} does not match "
                    "the canon grammar 'WORKER: model=<id> actor=<id> tree=<sha>' on its "
                    "first line")

        # rule 6 — a close whose own closed_at is on/after RULE56_CUTOVER carries a
        # landing comment (GATE:/FRESH-VERIFY:/TRIAGE-CLOSE:) that cites its evidence.
        # Forward-only by the bead's own closed_at: a close that happened before the
        # cutover is never re-judged.
        if status == "closed" and str(rec.get("closed_at") or "")[:10] >= RULE56_CUTOVER:
            all_comments = rec.get("comments") or []
            landings = [
                str(c.get("text") or "").strip() for c in all_comments
                if isinstance(c, dict)
                and str(c.get("text") or "").strip().startswith(("GATE:", "FRESH-VERIFY:", "TRIAGE-CLOSE:"))
            ]
            if not landings:
                violations[6].append(
                    f"{rel}:{lineno} — closed bead '{rid}' carries no landing record; "
                    "close through skills/ac-implement/scripts/close-gate.sh — see "
                    "ac-human/references/action-loop.md")
            elif not any(_landing_cited(landing, all_comments) for landing in landings):
                violations[6].append(
                    f"{rel}:{lineno} — closed bead '{rid}' landing record cites no "
                    "evidence resolving against the row; close-gate.sh's own landing "
                    "text is bypassed — close through skills/ac-implement/scripts/close-gate.sh")

        # rule 3 — open beads only, forward-only by created_at, never scans closed rows.
        if status != "open":
            continue
        created = str(rec.get("created_at") or "")[:10]
        if created >= CUTOVER:
            labels = [str(label) for label in (rec.get("labels") or [])]
            if not any(label.startswith("origin:") for label in labels):
                violations[3].append(
                    f"{rel}:{lineno} — open bead '{rid}' created {created} (on/after origin "
                    f"cutover {CUTOVER}) carries no origin: label")
            if rec.get("issue_type") in IMPLEMENTABLE and not PROBE.search(rec.get("description") or ""):
                violations[3].append(
                    f"{rel}:{lineno} — open {rec.get('issue_type')} bead '{rid}' created "
                    f"{created} carries no Probe: line")

    if not any(violations.values()):
        print(f"35-board-integrity: {scanned} record(s) scanned — well-formed, ids unique, open "
              "post-cutover beads origin-tagged, implementable beads probe-bearing, WORKER "
              "receipts and close landing records clean since their cutovers")
        return 0

    print("FAIL 35-board-integrity: committed board violates a board-integrity rule:")
    for n in sorted(violations):
        items = violations[n]
        if not items:
            continue
        print(f"\n{RULE_LABELS[n]}:")
        for v in items:
            print(f"  - {v}")
        print(f"  {RULE_HINTS[n]}")
    return 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:  # fail loud: a crashed check is never a pass
        print(f"FAIL 35-board-integrity: crashed: {exc}", file=sys.stderr)
        sys.exit(1)
