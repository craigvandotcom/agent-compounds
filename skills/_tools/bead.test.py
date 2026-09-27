#!/usr/bin/env python3
"""bead.test.py — fixture proof for bead.py, the one bead reader (ac-m9y4.1).

ASSURANCE-ROLE: test-harness
CALLER: scripts/run-all-proofs.sh (discovered by its *.test.py glob) and any local run.

Fixtures for `from_br_json` and `from_jsonl_row` are shaped after LIVE `br` output
(`.beads/issues.jsonl` and a real `br show --json` array-of-one), not invented: the plan's
own assumption is "`br show --json` and jsonl rows keep today's shapes", and this suite is
the detector named for that assumption alongside `scripts/br-contract.test.sh`.

Covers, one case per shape the bead's Intent names: sections; probes; Consumes (`->` and
the unicode arrow; a `<placeholder>`; `none`); Delivers (a repo-root file, a dot-leading
extensionless path, a cross-repo `~/` path, the `deleted-<kind>:` grammar, the touchers-line
exclusion, a dotted-child-bead-id false-positive); labels (list and comma-string); deps
(`dependency_type` from `br show`, `type`/`depends_on_id` from a jsonl row); `is_open`;
`gate_kind` (`DECISION:`, `HUMAN:`, `ACTION:`, and a plain title); the four adapters
(`from_br_json`, `from_jsonl_row`, `from_create_argv`, `from_markdown`).

Exit 0 = every case passed.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bead  # noqa: E402

PASS = FAIL = 0


def ok(n):
    global PASS
    PASS += 1
    print(f"ok   {n}")


def fail(n, d=""):
    global FAIL
    FAIL += 1
    print(f"FAIL {n}\n     {str(d)[:600]}")


def check(cond, n, d=""):
    ok(n) if cond else fail(n, d)


# =====================================================================================
# section() / probes()
# =====================================================================================

DESC = """## Intent
Why this matters.

## Acceptance Criteria
- The fix lands.
  Probe: `bash skills/_tools/x.test.sh` — tier: standing-harness
- A second AC.
  Probe: `grep -q foo bar.md` — tier: none

## Delivers
- lint.sh
- .husky/pre-push
- lib/db/foods.ts
  touchers: `rg -l -F "db/foods" lib -g "!lib/db/foods.ts"` → 1 · owned by: ac-abcd
- deleted-script: bin/old-tool.sh
- ~/mission/software/example-app/.claude/skills/CORE/SKILL.md

## Consumes
- ac-parent -> lib/db/foods.ts
- ac-other → docs/plan.md
- ac-vague -> <the artifact ac-other promises>
"""

check(bead.section(DESC, "Intent").strip() == "Why this matters.", "section: Intent body")
check(
    "The fix lands." in bead.section(DESC, "Acceptance Criteria"),
    "section: Acceptance Criteria body",
)
check(bead.section(DESC, "Nonexistent") == "", "section: missing heading -> empty string")

probe_list = bead.probes(DESC)
check(
    probe_list == ["bash skills/_tools/x.test.sh", "grep -q foo bar.md"],
    "probes: two Probe: lines in document order",
    probe_list,
)

# =====================================================================================
# Consumes: `->`, the unicode `→`, `none`, and a `<placeholder>`
# =====================================================================================

cons = bead.consumes(bead.section(DESC, "Consumes"))
check(len(cons) == 3, "consumes: three lines parsed", cons)
check(cons[0]["blocker"] == "ac-parent" and cons[0]["artifact"] == "lib/db/foods.ts"
      and cons[0]["placeholder"] is False, "consumes: `->` arrow", cons[0])
check(cons[1]["blocker"] == "ac-other" and cons[1]["artifact"] == "docs/plan.md"
      and cons[1]["placeholder"] is False, "consumes: unicode `→` arrow normalised", cons[1])
check(cons[2]["blocker"] == "ac-vague" and cons[2]["placeholder"] is True,
      "consumes: an unfilled <placeholder> artifact is flagged", cons[2])

check(bead.consumes("none") == [], "consumes: bare 'none' -> zero entries")
check(bead.consumes("None.") == [], "consumes: 'None.' (case + trailing period) -> zero entries")
check(bead.consumes("") == [], "consumes: empty body -> zero entries")

# =====================================================================================
# Delivers: repo-root file, dot-leading extensionless, cross-repo ~/, deleted-<kind>:,
# the touchers-line exclusion, and the dotted-child-bead-id false-positive
# =====================================================================================

dl = bead.delivers(DESC)
check(len(dl) == 5, "delivers: five Delivers bullets parsed", dl)
check(dl[0]["path"] == "lint.sh" and dl[0]["deleted_kind"] is None,
      "delivers: a bare repo-root file (no directory) is a path", dl[0])
check(dl[1]["path"] == ".husky/pre-push",
      "delivers: a dot-leading extensionless path is a path", dl[1])
check(dl[2]["path"] == "lib/db/foods.ts" and dl[2]["touchers"] is not None
      and "lib/db/foods.ts" not in dl[2]["touchers"].replace("db/foods.ts", "", 1),
      "delivers: the touchers: line is captured and excluded from its own path extraction",
      dl[2])
check(dl[3]["deleted_kind"] == "script" and dl[3]["path"] == "bin/old-tool.sh",
      "delivers: the deleted-<kind>: grammar names the kind and still names the path",
      dl[3])
check(dl[4]["path"] == "~/mission/software/example-app/.claude/skills/CORE/SKILL.md",
      "delivers: a cross-repo ~/ path is a path", dl[4])

check(bead.extract_paths("owned by: ac-2h8w.3") == [],
      "extract_paths: a dotted child-bead id is path-shaped but not a file — dropped")
check(bead.extract_paths("see AGENTS.md for context") == ["AGENTS.md"],
      "extract_paths: a bare repo-root file amid prose")
check(bead.is_cross_repo("~/mission/x") is True and bead.is_cross_repo("lib/x.ts") is False,
      "is_cross_repo: only a ~/-rooted path counts")

# A PLAN's own `## Deliverables` heading uses the SAME extractor (heading= override).
PLAN_DESC = "## Deliverables\n- skills/_tools/bead.py\n- skills/_tools/bead.test.py\n"
plan_dl = bead.delivers(PLAN_DESC, heading="Deliverables")
check([d["path"] for d in plan_dl] == ["skills/_tools/bead.py", "skills/_tools/bead.test.py"],
      "delivers: a PLAN's '## Deliverables' heading reuses the same extractor", plan_dl)

# =====================================================================================
# labels_of — a list (br show / jsonl) or a comma-joined string (an argv -l value)
# =====================================================================================

check(bead.labels_of(["origin:ac-beadify", "refined"]) == ["origin:ac-beadify", "refined"],
      "labels_of: list form")
check(bead.labels_of("origin:ac-beadify, refined") == ["origin:ac-beadify", "refined"],
      "labels_of: comma-joined string form")
check(bead.labels_of(None) == [], "labels_of: None -> empty list")

# =====================================================================================
# is_open / gate_kind
# =====================================================================================

check(bead.is_open("open") and bead.is_open("in_progress") and bead.is_open("blocked"),
      "is_open: open/in_progress/blocked all read as open")
check(bead.is_open("closed") is False, "is_open: closed is the sole terminal state")
check(bead.is_open("CLOSED") is False, "is_open: case-insensitive")

check(bead.gate_kind("DECISION: which provider") == "DECISION", "gate_kind: DECISION:")
check(bead.gate_kind("HUMAN: approve the release") == "DECISION",
      "gate_kind: HUMAN: maps to DECISION (docket.sh / lint 19 agree)")
check(bead.gate_kind("ACTION: flip the toggle") == "ACTION", "gate_kind: ACTION:")
check(bead.gate_kind("Refuse the refined stamp when...") is None,
      "gate_kind: a plain title (no gate prefix) -> None")

# =====================================================================================
# from_br_json — shaped after a real `br show --json` array-of-one, with dependencies
# carrying `dependency_type`/`id` (the shape flight-check.sh reads today)
# =====================================================================================

BR_JSON = [{
    "id": "ac-2h8w",
    "title": "Refuse the refined stamp when a DECISION ruling is newer...",
    "description": DESC,
    "status": "open",
    "issue_type": "task",
    "priority": 1,
    "labels": ["origin:ac-human", "refine-full", "refined"],
    "dependencies": [],
    "dependents": [
        {"id": "ac-m9y4.7", "title": "Move stamp-refined onto bead.py check...",
         "status": "open", "priority": 2, "dependency_type": "blocks"},
    ],
    "comments": [{"id": 1, "text": "hello"}],
}]
canon, err = bead.from_br_json(BR_JSON)
check(err is None and canon["id"] == "ac-2h8w" and canon["issue_type"] == "task",
      "from_br_json: array-of-one unwraps to the object", (canon, err))
check(canon["labels"] == ["origin:ac-human", "refine-full", "refined"],
      "from_br_json: labels pass through", canon["labels"])

BR_JSON_WITH_DEP = {
    "id": "ac-m9y4.1",
    "title": "Build bead.py",
    "description": "",
    "status": "open",
    "issue_type": "task",
    "labels": ["origin:ac-beadify"],
    "dependencies": [
        {"id": "ac-m9y4", "title": "epic", "status": "open", "priority": 2,
         "dependency_type": "parent-child"},
    ],
}
canon2, err2 = bead.from_br_json(BR_JSON_WITH_DEP)
check(err2 is None and canon2["dependencies"] == [{"id": "ac-m9y4", "dependency_type": "parent-child"}],
      "from_br_json: a forward dependency normalises dependency_type/id", (canon2, err2))

ERROR_ENVELOPE = {"error": {"code": "ISSUE_NOT_FOUND", "message": "no such issue"}}
canon3, err3 = bead.from_br_json(ERROR_ENVELOPE)
check(canon3 is None and err3 is not None and "br-read-failed" in err3,
      "from_br_json: an error envelope is a REFUSED read, never an empty bead", (canon3, err3))

EMPTY_ARRAY = []
canon4, err4 = bead.from_br_json(EMPTY_ARRAY)
check(canon4 is None and err4 is not None,
      "from_br_json: an empty array (id did not resolve) refuses", (canon4, err4))

# =====================================================================================
# from_jsonl_row — shaped after a real `.beads/issues.jsonl` row, with dependencies
# carrying `type`/`depends_on_id` (the normalisation the plan names)
# =====================================================================================

JSONL_ROW = {
    "id": "ac-048v.3",
    "title": "some child",
    "description": "",
    "status": "closed",
    "issue_type": "task",
    "labels": ["origin:ac-beadify", "refined"],
    "dependencies": [
        {"issue_id": "ac-048v.3", "depends_on_id": "ac-048v", "type": "parent-child",
         "created_at": "2026-09-25T20:26:52Z", "created_by": "example-user",
         "metadata": "{}", "thread_id": ""},
        {"issue_id": "ac-048v.3", "depends_on_id": "ac-048v.1", "type": "blocks",
         "created_at": "2026-09-25T20:26:54Z", "created_by": "example-user",
         "metadata": "{}", "thread_id": ""},
    ],
}
canon5, err5 = bead.from_jsonl_row(JSONL_ROW)
check(err5 is None and canon5["dependencies"] == [
    {"id": "ac-048v", "dependency_type": "parent-child"},
    {"id": "ac-048v.1", "dependency_type": "blocks"},
], "from_jsonl_row: type/depends_on_id normalises to dependency_type/id", (canon5, err5))
check(bead.is_open(canon5["status"]) is False,
      "from_jsonl_row + is_open compose: a closed jsonl row reads as not-open")

canon6, err6 = bead.from_jsonl_row("not a dict")
check(canon6 is None and err6 is not None, "from_jsonl_row: a non-object row refuses")

# =====================================================================================
# from_create_argv — a bead being FILED as a `br create` command
# =====================================================================================

ARGV = [
    "br", "create", "-t", "task",
    "--title", "ACTION: configure the offer",
    "-l", "origin:ac-human,human-gate",
    "-d", "Gate-reason: authorization\nwhat: flip it",
    "--parent", "ac-parent-epic",
]
c_argv = bead.from_create_argv(ARGV)
check(c_argv["title"] == "ACTION: configure the offer", "from_create_argv: --title")
check(c_argv["issue_type"] == "task", "from_create_argv: -t")
check(c_argv["labels"] == ["origin:ac-human", "human-gate"], "from_create_argv: -l (comma split)")
check(c_argv["parent"] == "ac-parent-epic", "from_create_argv: --parent")
check(bead.gate_kind(c_argv["title"]) == "ACTION",
      "from_create_argv composes with gate_kind: an ACTION: title")

ARGV_POSITIONAL = ["create", "Bare positional title", "-l", "origin:ac-triage"]
c_pos = bead.from_create_argv(ARGV_POSITIONAL)
check(c_pos["title"] == "Bare positional title",
      "from_create_argv: a positional (non-flag) token is the title when --title is absent")
check(c_pos["issue_type"] == "task",
      "from_create_argv: issue_type defaults to task (br's own default) when -t is absent")

# =====================================================================================
# from_markdown — a bead staged as a draft file
# =====================================================================================

MD = "# DECISION: which provider\n\nGate-reason: fork — ...\n\noptions:\n  a) X\n  b) Y\n"
c_md = bead.from_markdown(MD)
check(c_md["title"] == "DECISION: which provider", "from_markdown: '# Title' heading")
check(c_md["description"].startswith("Gate-reason:"),
      "from_markdown: the remainder (past the title line) is the description body")
check(bead.gate_kind(c_md["title"]) == "DECISION",
      "from_markdown composes with gate_kind: a DECISION: title")

MD_FIELD = "Title: HUMAN: approve the release\n\nGate-reason: authorization\n"
c_md2 = bead.from_markdown(MD_FIELD)
check(c_md2["title"] == "HUMAN: approve the release", "from_markdown: 'Title:' field form")

print("---")
print(f"PASS={PASS} FAIL={FAIL}")
sys.exit(0 if FAIL == 0 else 1)
