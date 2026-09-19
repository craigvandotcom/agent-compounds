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

Six FAIL rules over the committed board:
  1. a line that is not JSON;
  2. an `id` that appears more than once;
  3. an OPEN bead created on or after the origin cutover (2026-08-23 — the date the
     hooks manifest's `_doc` records the origin axis becoming a hard gate) carrying no
     `origin:` label, or an OPEN implementable bead (task/bug/feature) carrying no
     `Probe:` line. The probe axis shares the origin axis's failure mode: the born-probe
     guard reads the `br create` COMMAND, so a body passed as `-d "$(cat file)"` or a
     heredoc makes it fail open, and this artifact read is the backstop.
  4. ANY row (either status, both lanes) whose `status` is outside the canon set
     (`skills/beads-standards/SKILL.md` § Status & priority canon: open / in_progress /
     blocked / deferred / closed / tombstone).
  5. staged lane only (skipped on a whole-board run, per Commit-scoped format rules
     below): a `WORKER:`-prefixed comment newly added to a changed id BY THIS COMMIT
     (its identity — the comment `id`, or `(created_at, text)` when no id is present —
     absent from that id's comment list at HEAD; identity is NEVER position, because br
     orders same-second comments in no fixed order) whose FIRST LINE does not match the
     canon grammar's three fields, `model=`/`actor=`/`tree=` (§ Worker-identity stamp) —
     shape only, never the fields' truth. A canon first line followed by note lines is
     green; a pre-existing (HEAD-era) receipt on an untouched comment of a changed bead,
     wherever it now sorts in the staged list, is never re-judged.
  6. staged lane only, same scope and same by-identity "new" test as rule 5, no
     whole-board fallback: a changed id whose staged `status` is `closed` and whose HEAD
     `status` was NOT `closed` — a close that genuinely happened in this commit —
     carrying no comment AMONG THOSE NEW IN THIS COMMIT whose text begins `GATE:`,
     `FRESH-VERIFY:`, or `TRIAGE-CLOSE:`. A landing record already on the row at HEAD
     (a stale receipt from an earlier close, later reopened) does not satisfy a new
     close. The close sensor is board-side (every close path, prose or script, human or
     system); it never asks WHO closed, only whether a NEW landing record exists.
     Board-side per the Decisions card; this is deliberately not fence lint.

Rules 3 (origin: label, Probe: line) skip closed beads — forward-only, no backfill, per
the origin-provenance ruling: enforcement started at the cutover and the past is not
relitigated. Rules 4 (status canon) and 5 (WORKER receipt shape) scan a row regardless of
its status: rule 4 because an off-canon status is corruption at any lifecycle stage, rule
5 because a receipt this commit newly writes onto a closed bead (a coordinator close-out
label, a late note) is still new content the commit is authoring. Rule 6 by construction
only ever fires on a row THIS commit closed. An empty or unreadable board exits 2
NOT-GATED, because a check that read nothing has proved nothing.
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
# canon status set — skills/beads-standards/SKILL.md § Status & priority canon
STATUS_CANON = {"open", "in_progress", "blocked", "deferred", "closed", "tombstone"}
# canon WORKER: grammar — skills/beads-standards/SKILL.md § Worker-identity stamp
WORKER_RE = re.compile(r"^WORKER: model=\S+ actor=\S+ tree=\S+$")


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
            check=False,  # non-zero (no such rev) is a normal fallback path below, not a crash
        )
    except (OSError, subprocess.SubprocessError):
        return None
    return proc.stdout if proc.returncode == 0 else None


def _comment_key(c):
    """Stable identity for a comment: prefer its `id`; fall back to
    (created_at, text) when no id is present. NEVER position — br orders
    comments by created_at with same-second ties in no fixed order
    (measured on ac-kqpw.5, ac-gcj.8, ac-1p7j.31), so slicing by count can
    mis-sort a legacy receipt as new or vice versa."""
    if not isinstance(c, dict):
        key = ("raw", repr(c))
    elif c.get("id") is not None:
        key = ("id", c["id"])
    else:
        key = ("ct", str(c.get("created_at") or ""), str(c.get("text") or ""))
    return key


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


def _staged_head_maps(root):
    """(staged_map, head_map) by id, or None when the diff cannot be determined
    (no git checkout, no HEAD yet) or when the staged blob equals HEAD's (no
    staged ledger change — a full run)."""
    staged = _git_show(root, f":{LEDGER_REL}")
    if staged is None:
        return None
    head = _git_show(root, f"HEAD:{LEDGER_REL}")
    if head is None:
        head = ""  # no HEAD yet, or the ledger is new-to-this-commit
    if staged == head:
        return None
    return _by_id(staged), _by_id(head)


def changed_bead_data(root):
    """(changed_ids, new_worker_comments, head_status) — changed_ids is the set of ids
    added or modified in the staged ledger vs HEAD's (None when undeterminable or no
    staged change; the caller's signal to apply the per-bead format rules to the whole
    board). new_worker_comments maps id -> the list of comments THIS COMMIT appends
    for that id — comments are append-only, so anything past HEAD's own comment
    count for that id is new; a pre-existing receipt on an untouched comment is
    never in this list. head_status maps id -> that id's status at HEAD (absent id ->
    None, i.e. the bead is new-to-this-commit). All three members are None together."""
    maps = _staged_head_maps(root)
    if maps is None:
        return None, None, None
    staged_map, head_map = maps
    changed_ids = {rid for rid, rec in staged_map.items()
                   if rid not in head_map or head_map[rid] != rec}
    new_comments = {}
    head_status = {}
    for rid in changed_ids:
        staged_comments = staged_map[rid].get("comments") or []
        head_rec = head_map.get(rid) or {}
        head_comments = head_rec.get("comments") or []
        head_keys = {_comment_key(c) for c in head_comments}
        new_comments[rid] = [c for c in staged_comments if _comment_key(c) not in head_keys]
        head_status[rid] = head_rec.get("status")
    return changed_ids, new_comments, head_status


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

    # None, None, None -> undeterminable, apply format rules to all (rules 5-6 stay off)
    changed_ids, new_worker_comments, head_status = changed_bead_data(root)

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
        status = rec.get("status")
        if status not in STATUS_CANON:
            violations.append(
                f"{board}:{lineno} — off-canon status is RED: bead '{rid}' has status "
                f"'{status}', outside the canon set {sorted(STATUS_CANON)}")
        if changed_ids is not None and rid in changed_ids:
            for comment in new_worker_comments.get(rid, []):
                text = str(comment.get("text") or "") if isinstance(comment, dict) else ""
                stripped = text.strip()
                if not stripped.startswith("WORKER:"):
                    continue
                first_line = stripped.splitlines()[0]
                if not WORKER_RE.match(first_line):
                    violations.append(
                        f"{board}:{lineno} — malformed WORKER receipt is RED: bead '{rid}' comment "
                        f"{stripped!r} does not match the canon grammar 'WORKER: model=<id> "
                        "actor=<id> tree=<sha>' on its first line")
            # Rule 6 — the landing record: a close that genuinely happened in this commit
            # (staged status closed, HEAD status was something else) leaves at least one
            # NEW comment (per the id/created_at+text key above, never a stale receipt
            # already on the row at HEAD) naming the evidence it closed on. Staged lane
            # only, same scope as rule 5 — no whole-board fallback (no backfill by doctrine).
            if status == "closed" and head_status.get(rid) != "closed":
                comments = new_worker_comments.get(rid, [])
                landed = any(
                    isinstance(c, dict) and str(c.get("text") or "").strip()
                    .startswith(("GATE:", "FRESH-VERIFY:", "TRIAGE-CLOSE:"))
                    for c in comments)
                if not landed:
                    violations.append(
                        f"{board}:{lineno} — closed bead '{rid}' carries no landing record is RED: "
                        "close through skills/ac-implement/scripts/close-gate.sh — see "
                        "ac-human/references/action-loop.md")
        if status != "open":
            continue  # closed beads are NEVER scanned for origin/probe — forward-only, no backfill
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
