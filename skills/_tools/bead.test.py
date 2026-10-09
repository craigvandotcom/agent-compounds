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
  touchers: `rg -l -F "db/foods" lib -g "!lib/db/foods.ts"` · owned by: ac-abcd
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

# `none (gate)`: a GATE-ONLY blocker (decision / human-gate / milestone — no artifact of
# its own); satisfied by the blocker being CLOSED, never a path (checker recheck
# 2026-09-27, evidence bd-pz8md/bd-1s800: "none" parsed as a literal absent artifact and
# was refused even though the blocker had long since closed).
cons_gate = bead.consumes("- ac-decision -> none (gate)")
check(len(cons_gate) == 1 and cons_gate[0]["gate"] is True
      and cons_gate[0]["artifact"] is None and cons_gate[0]["placeholder"] is False
      and cons_gate[0]["blocker"] == "ac-decision",
      "consumes: 'none (gate)' parses as a gate-only entry, never an artifact or a placeholder",
      cons_gate)
check(bead.consumes("- ac-decision -> NONE (GATE).")[0]["gate"] is True,
      "consumes: 'none (gate)' is case-insensitive and tolerates a trailing period")
check(bead.consumes("- ac-decision -> none")[0]["gate"] is False,
      "consumes: bare 'none' (no '(gate)' annotation) is an ordinary absent-artifact entry, not gate-only")

# A Consumes line may carry a trailing parenthetical note after the artifact — the
# artifact is the first whitespace-delimited token, the note is never part of the path
# (ac-m9y4.3 regression: bead.py took the whole remainder, so a present artifact with a
# note read as absent).
cons_noted = bead.consumes(
    "- ac-ftfz.7 -> skills/ac-pipeline/scripts/push.sh (this bead stops the lane pushing; see thread)\n"
    "- upstream -> ./present-artifact.md (landed)"
)
check(len(cons_noted) == 2, "consumes: trailing-note fixture parses two lines", cons_noted)
check(cons_noted[0]["blocker"] == "ac-ftfz.7"
      and cons_noted[0]["artifact"] == "skills/ac-pipeline/scripts/push.sh"
      and cons_noted[0]["placeholder"] is False,
      "consumes: a trailing parenthetical note is dropped from the artifact", cons_noted[0])
check(cons_noted[1]["blocker"] == "upstream"
      and cons_noted[1]["artifact"] == "./present-artifact.md"
      and cons_noted[1]["placeholder"] is False,
      "consumes: a short trailing note ('(landed)') is dropped too", cons_noted[1])

# A Consumes line may carry a `word:` LABEL before the artifact path (which app/Territory
# it belongs to) — the artifact is the first token after the arrow that is not a label
# (ac-m9y4 recheck 2026-09-27: `- bd-sp6n0.1 -> api: lib/haptics/feedback.ts` read
# artifact='api:', a false Consumes-artifact-absent refusal).
cons_labeled = bead.consumes(
    "- bd-sp6n0.1 -> api: lib/haptics/feedback.ts (exports selectionStart)\n"
    "- ac-14s1.9 -> example-app: ~/mission/software/example-app/.compounds/reviews/\n"
)
check(len(cons_labeled) == 2, "consumes: labeled-artifact fixture parses two lines", cons_labeled)
check(cons_labeled[0]["blocker"] == "bd-sp6n0.1"
      and cons_labeled[0]["artifact"] == "lib/haptics/feedback.ts",
      "consumes: a `word:` label before the path is skipped, the path is the artifact",
      cons_labeled[0])
check(cons_labeled[1]["blocker"] == "ac-14s1.9"
      and cons_labeled[1]["artifact"] == "~/mission/software/example-app/.compounds/reviews/",
      "consumes: a `word:` label before a cross-repo ~/ path is skipped too",
      cons_labeled[1])

# A multi-line Consumes bullet's own CONTINUATION prose (quoting an edge-verification
# `-> id (blocks)` aside in backticks) re-parses, line by line, as a bogus new entry —
# its "blocker" is just the sentence's leading word, never a real bead id. The left side
# of a REAL Consumes line is nothing but the id; any leftover text past the matched
# prefix means `malformed: True`, and the garbage word is never carried as `blocker`
# (ac-m9y4 recheck 2026-09-27: bd-18wpl.3/.4, bd-0qske — a garbage blocker id reached
# `br show`, which exited non-zero and read as a confusing NOT-GATED).
cons_continuation = bead.consumes(
    "- bd-18wpl.2 -> the early-emit mechanism in `runZonePipelineV5`, proven not to regress\n"
    "  time-to-zone (edge verified this session: `-> bd-18wpl.2 (blocks)`) — cutting over\n"
    "  before this lands would regress the headline benefit\n"
)
check(len(cons_continuation) == 2,
      "consumes: a continuation line re-parses as a second (bogus) entry", cons_continuation)
check(cons_continuation[0]["blocker"] == "bd-18wpl.2" and cons_continuation[0]["malformed"] is False,
      "consumes: the real bullet line is clean", cons_continuation[0])
check(cons_continuation[1]["blocker"] is None and cons_continuation[1]["malformed"] is True,
      "consumes: the continuation line's bogus 'blocker' (time-to-zone) is never carried — "
      "flagged malformed instead", cons_continuation[1])

check(bead.consumes("- ac-x.1 -> real/path.md")[0]["malformed"] is False,
      "consumes: an ordinary clean line is never flagged malformed")

# consumes_violations must REFUSE a malformed entry by name and never call resolve_blocker
# on its garbage "blocker" (the NOT-GATED-via-`br-show-exit-3` cascade this replaces).
def _resolve_blocker_must_not_be_called(bid):
    raise AssertionError(f"resolve_blocker must not be called for a malformed line (got {bid!r})")


import tempfile as _tempfile_early  # noqa: E402 (used once, ahead of the later `import tempfile as _tf`)

r_malformed = bead.consumes_violations(
    [cons_continuation[1]], _tempfile_early.mkdtemp(),
    resolve_blocker=_resolve_blocker_must_not_be_called,
)
check(len(r_malformed[0]) == 1 and "malformed" in r_malformed[0][0] and r_malformed[1] == [],
      "consumes_violations: a malformed line is REFUSED by name, never NOT-GATED via br show",
      r_malformed)

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

# --- extract_paths false tokens (checker recheck 2026-09-27) ----------------------------
# `foods.status` (a SQL column reference), `0.68` (a measured ratio) and `(bd-x.1` (a
# paren-wrapped bead id) all read as files before the fix: no `/`, no KNOWN extension, or
# only path-shaped because a leading `(` kept the bead-id-shape exclusion from firing.

check(bead.extract_paths("the cron that drains rows in `foods.status = 'analyzing'`") == [],
      "extract_paths: a bare word.word SQL column reference (no `/`, no known extension) "
      "is not a path")
check(bead.extract_paths("the live population moved from 0.68 to 0.71") == [],
      "extract_paths: a purely numeric decimal is never a path, known-extension digits "
      "included")
check(bead.extract_paths("blocked on the ruling (bd-x.1)") == [],
      "extract_paths: a paren-wrapped bead id — the leading `(` no longer defeats the "
      "bead-id-shape exclusion")
check(bead.extract_paths("see (lib/a.ts) for the change") == ["lib/a.ts"],
      "extract_paths: a paren-wrapped REAL path is recovered edge-stripped, not left "
      "carrying its wrapper")
check(bead.extract_paths("- view: S/SavedQueries/{00000000-0000-0000-00aa-000010003001}.xml")
      == ["S/SavedQueries/{00000000-0000-0000-00aa-000010003001}.xml"],
      "extract_paths: a braced pac-unpack filename ({guid}.xml) is one whole path")
check(bead.extract_paths("see {lib/a.ts} for the change") == ["lib/a.ts"],
      "extract_paths: an outer brace is still edge-stripped")
check(bead.extract_paths("today's count is 42.") == [],
      "extract_paths: an integer-with-trailing-period sentence is never a path")
check(bead.extract_paths("run .husky/pre-push, lib/db/foods.ts and ~/mission/x/y.md") ==
      sorted([".husky/pre-push", "lib/db/foods.ts", "~/mission/x/y.md"]),
      "extract_paths: today's accepted shapes (dot-leading, dir/dir/file.ext, cross-repo ~/) "
      "are unaffected by the extension/numeric/edge-punct rules")

check(bead._looks_like_file_path("foods.status") is False,
      "_looks_like_file_path: word.word with an unknown extension is rejected")
check(bead._looks_like_file_path("0.68") is False,
      "_looks_like_file_path: purely numeric is rejected even though '68' resembles digits")
check(bead._looks_like_file_path("lib/a.ts") is True,
      "_looks_like_file_path: a `/`-qualified token is accepted regardless of extension")
check(bead._looks_like_file_path("AGENTS.md") is True,
      "_looks_like_file_path: a repo-root token ending in a KNOWN extension is accepted")

# --- a bare repo-root MULTI-DOT config file (bd-ut5zw recheck 2026-09-27/28: the extension
# leg's first cut only ever matched ONE dot for a no-slash token, so `vitest.config.mts`
# read as `vitest.config` — extension "config", rejected, UNVERIFIABLE-DELIVERS on a bead
# whose only Delivers bullet was this exact real path) ------------------------------------

check(bead.extract_paths("- fix: vitest.config.mts") == ["vitest.config.mts"],
      "extract_paths: a bare repo-root file with a MIDDLE dot segment (vitest.config.mts) "
      "is captured whole, by its final (real) extension — not truncated at the first dot")
check(bead.extract_paths("see tailwind.config.ts and next.config.mjs") ==
      sorted(["tailwind.config.ts", "next.config.mjs"]),
      "extract_paths: other common bare multi-dot config files are captured whole too")
check(bead._looks_like_file_path("vitest.config.mts") is True,
      "_looks_like_file_path: the FINAL dot segment is what's checked against the known-"
      "extension list, never a middle one")

# --- a bare extensionless artifact name (Makefile, Dockerfile, ...) is path-shaped --------

check(bead.extract_paths("- lint: Makefile") == ["Makefile"],
      "extract_paths: a bare extensionless conventional file (Makefile) is a path")
check(bead.extract_paths("- image: Dockerfile and LICENSE") == ["Dockerfile", "LICENSE"],
      "extract_paths: other conventional extensionless files (Dockerfile, LICENSE) are paths")
check(bead.extract_paths("- ci: lib/a.ts and Makefile") == ["Makefile", "lib/a.ts"],
      "extract_paths: slash-bearing and known-extension shapes keep passing beside a bare Makefile")
check(bead.extract_paths("see the Makefile.") == ["Makefile"],
      "extract_paths: a trailing sentence period is edge-stripped off a bare Makefile")
check(bead.extract_paths("the makefile and some Readme words") == [],
      "extract_paths: only the exact conventional names are paths — other bare words stay prose")
check(bead.extract_paths("- x: Dockerfile.dev") == [],
      "extract_paths: a dotted variant with an unknown extension (Dockerfile.dev) is not widened in")
check(bead._looks_like_file_path("Makefile") is True and bead._looks_like_file_path("Makefiles") is False,
      "_looks_like_file_path: the extensionless leg is an exact-name set, never a pattern")

# --- VERSION and a bare dotfile are path-shaped (ac-9h9k); prose near them is not ---------

check(bead.extract_paths("- v: VERSION") == ["VERSION"],
      "extract_paths: a bare VERSION is a path")
check(bead.extract_paths("- i: .gitignore") == [".gitignore"],
      "extract_paths: a bare dotfile (.gitignore) is a path")
check(bead.extract_paths("- e: .env.example and .env.local") == [".env.example", ".env.local"],
      "extract_paths: a multi-segment dotfile (.env.example) is a path")
check(bead.extract_paths("update the VERSION and .gitignore.") == [".gitignore", "VERSION"],
      "extract_paths: a trailing sentence period is edge-stripped off a bare dotfile")
check(bead.extract_paths("- note: the version is fine") == []
      and bead.extract_paths("Version bump, version.") == [],
      "extract_paths: lower/title-case version is prose — VERSION is an exact-name match")
check(bead.extract_paths("wait... done. and .. here . there") == [],
      "extract_paths: an ellipsis, a lone `.` or `..` is never a path")
check(bead.extract_paths("every .md and .ts file, the .status column") == [],
      "extract_paths: a one-segment dotted word that is not a listed dotfile stays prose")
check(bead.extract_paths("under .claude/ only") == [],
      "extract_paths: a bare dot-directory with a trailing slash is not widened in")
check(bead.extract_paths("see .claude/settings.json") == [".claude/settings.json"],
      "extract_paths: a .hidden/path still resolves whole beside the new dotfile leg")

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
# parent_child_children / is_child_of — the epic <-> child parent-child edge, read from
# each side (ac-m9y4.9): the PARENT's own `dependents` list (a `br show <epic>` payload)
# and the CHILD's own `dependencies` list (routed through from_br_json, never a second
# normalisation of it).
# =====================================================================================

EPIC_SHOW = {
    "id": "ep-1",
    "dependents": [
        {"id": "ep-1.a", "dependency_type": "parent-child"},
        {"id": "ac-blocked", "dependency_type": "blocks"},
    ],
}
kids, kerr = bead.parent_child_children(EPIC_SHOW)
check(kerr is None and kids == ["ep-1.a"],
      "parent_child_children: only the parent-child dependents count", (kids, kerr))

kids_arr, kerr_arr = bead.parent_child_children([EPIC_SHOW])
check(kerr_arr is None and kids_arr == ["ep-1.a"],
      "parent_child_children: array-of-one unwraps like from_br_json", (kids_arr, kerr_arr))

kids_none, kerr_none = bead.parent_child_children({"id": "ep-2"})
check(kerr_none is None and kids_none == [],
      "parent_child_children: no dependents -> empty list, not an error", (kids_none, kerr_none))

kids_err, kerr_err = bead.parent_child_children(ERROR_ENVELOPE)
check(kids_err is None and kerr_err is not None and "br-read-failed" in kerr_err,
      "parent_child_children: an error envelope refuses", (kids_err, kerr_err))

is_child, cerr = bead.is_child_of(BR_JSON_WITH_DEP, "ac-m9y4")
check(cerr is None and is_child is True,
      "is_child_of: a forward parent-child dependency naming the epic -> True", (is_child, cerr))

not_child, ncerr = bead.is_child_of(BR_JSON_WITH_DEP, "some-other-epic")
check(ncerr is None and not_child is False,
      "is_child_of: naming a different epic -> False", (not_child, ncerr))

is_child_err, cerr_err = bead.is_child_of(ERROR_ENVELOPE, "ac-m9y4")
check(is_child_err is None and cerr_err is not None,
      "is_child_of: an error envelope refuses", (is_child_err, cerr_err))

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

# =====================================================================================
# `bead.py check` (ac-m9y4.2) — one refusing command over every rule a script can
# MEASURE. Each leg below is a fixture per shape the plan's D2 list names.
# =====================================================================================

import subprocess as _sp
import tempfile as _tf

# --- probe_shape_violation: the refused-probe-shape list ---------------------------

check(bead.probe_shape_violation('grep -c "TODO" file.py') is not None,
      "probe_shape_violation: bare grep -c always exits 0 on any match — banned")
check(bead.probe_shape_violation('test $(grep -o TODO file.py | wc -l) -eq 3') is None,
      "probe_shape_violation: grep WITHOUT -c, counted via wc -l, is NOT banned")

# checker recheck 2026-09-27: `grep -c` piped into an EXPLICIT comparison is a comparison,
# never a bare count read — only a `-c`/`--count` clause with NOTHING comparing its output
# is banned.
check(bead.probe_shape_violation('grep -cE "TODO" file.py | grep -qx 0') is None,
      "probe_shape_violation: grep -c piped into an explicit `grep -qx <N>` comparison is NOT banned")
check(bead.probe_shape_violation('rg -c PATTERN file.py | test -eq 3') is None,
      "probe_shape_violation: rg -c piped into an explicit `test -eq <N>` comparison is NOT banned")
check(bead.probe_shape_violation('grep -c "TODO" file.py | wc -l') is not None,
      "probe_shape_violation: grep -c piped into something OTHER than a comparison (wc -l alone) is still banned")
check(bead.probe_shape_violation('pnpm exec vitest run') is not None,
      "probe_shape_violation: bare pnpm exec vitest run (whole suite) is banned")
check(bead.probe_shape_violation('pnpm exec vitest run src/x.test.ts') is None,
      "probe_shape_violation: pnpm exec vitest run scoped to a file is NOT banned")
check(bead.probe_shape_violation('bash scripts/run-all-proofs.sh') is not None,
      "probe_shape_violation: run-all-proofs.sh is banned (the whole-suite CI script)")
check(bead.probe_shape_violation('./scripts/run-all-proofs.sh') is not None,
      "probe_shape_violation: a ./scripts/run-all-proofs.sh invocation is still banned")
# checker recheck 2026-09-27 (evidence: ac-tv83.14): a `jq` test STRING that names
# "run-all-proofs.sh" as a literal to assert AGAINST (never invokes it) is not a probe that
# runs the whole suite — only an unquoted invocation counts.
check(bead.probe_shape_violation(
      'test -f .claude/factory.json && jq -e \'.ship.prove | test("run-all-proofs.sh")\' '
      '.claude/factory.json >/dev/null') is None,
      "probe_shape_violation: 'run-all-proofs.sh' inside a quoted jq test string is not an invocation")
check(bead.probe_shape_violation('supabase db push --linked') is not None,
      "probe_shape_violation: a direct supabase invocation is banned")

# The `supabase` leg bans an INVOCATION of the CLI, never a bare substring — a probe
# naming a path (a migration file, a generated types file, an integration test name)
# that merely CONTAINS the word must pass clean (ac-m9y4 recheck 2026-09-27: 28 refused
# probes across two repos were a path mention, none an actual CLI call).
check(bead.probe_shape_violation(
      'grep -q "no email column" .claude/skills/CORE/supabase.md') is None,
      "probe_shape_violation: 'supabase' inside a file PATH is not an invocation")
check(bead.probe_shape_violation(
      "test -f supabase/migrations/20260101_x.sql") is None,
      "probe_shape_violation: a supabase/migrations/*.sql path mention is not an invocation")
check(bead.probe_shape_violation(
      "grep -q export lib/supabase/types.generated.ts") is None,
      "probe_shape_violation: a lib/supabase/*.ts path mention is not an invocation")
check(bead.probe_shape_violation(
      "grep -q 'globalSetup' vitest.integration.local.config.mts && "
      "npx vitest run --config vitest.integration.local.config.mts "
      "__tests__/supabase-integration/food-slug-allowlist.integration.test.ts") is None,
      "probe_shape_violation: a __tests__/supabase-integration/*.test.ts path mention "
      "(no CLI call) is not an invocation")
check(bead.probe_shape_violation('supabase db reset') is not None,
      "probe_shape_violation: a bare `supabase db reset` invocation is still banned")
check(bead.probe_shape_violation('npx supabase db push') is not None,
      "probe_shape_violation: `npx supabase db push` (npx wrapper) is still banned")
check(bead.probe_shape_violation('pnpm supabase db reset') is not None,
      "probe_shape_violation: `pnpm supabase db reset` (pnpm wrapper) is still banned")
check(bead.probe_shape_violation('pnpm exec supabase db reset') is not None,
      "probe_shape_violation: `pnpm exec supabase db reset` is still banned")
check(bead.probe_shape_violation('true && supabase db reset') is not None,
      "probe_shape_violation: `supabase` after a `&&` clause separator is still banned")
check(bead.probe_shape_violation('cd app; supabase db reset') is not None,
      "probe_shape_violation: `supabase` after a `;` clause separator is still banned")

# checker recheck 2026-09-27 (evidence: ac-tv83.14): a `(` inside a QUOTED search pattern
# is never a shell subshell/group open — a command word never sits inside a quoted string,
# so "supabase" following a literal `(` there is not an invocation.
check(bead.probe_shape_violation(
      "rg -q 'lookupCompoundRecipe\\(supabase, slug' app/") is None,
      "probe_shape_violation: 'supabase' after a literal '(' INSIDE a quoted rg pattern is not an invocation")
check(bead.probe_shape_violation(
      'grep -q "fn(supabase, x)" lib/recipe.ts') is None,
      "probe_shape_violation: 'supabase' after a '(' inside a double-quoted grep pattern is not an invocation")

check(bead.probe_shape_violation('pnpm db:reset') is not None,
      "probe_shape_violation: db:reset is banned (destructive)")
check(bead.probe_shape_violation('pnpm db:verify') is not None,
      "probe_shape_violation: db:verify is banned (whole-environment)")
check(bead.probe_shape_violation('echo done') is not None,
      "probe_shape_violation: an echo-only probe can never fail — banned")
check(bead.probe_shape_violation('echo a && echo b') is not None,
      "probe_shape_violation: every clause being echo is still echo-only")
check(bead.probe_shape_violation('test -f x.py && echo ok') is None,
      "probe_shape_violation: a real test clause beside an echo is NOT echo-only")
check(bead.probe_shape_violation('! grep -q "banned" x.py') is None,
      "probe_shape_violation: a negated grep (asserts absence) still runs something — not banned")
check(bead.probe_shape_violation('bash skills/_tools/x.test.sh') is None,
      "probe_shape_violation: an ordinary scoped test file is clean")

# --- run_probe: a timeout kills the WHOLE process group, not just the `sh` child --------
#
# A non-interactive `sh -c '... &'` keeps a backgrounded job in the SAME process group as
# `sh` itself — killing only `sh`'s own pid on timeout leaves it running as an orphan
# (ac-m9y4 recheck 2026-09-27: a `pnpm vitest` grandchild outlived its probe's own
# timeout by 140s). Prove it directly: background a long sleep, capture its pid, run a
# short-timeout probe that never returns on its own, then confirm the backgrounded pid is
# dead once run_probe has returned.

import time as _time_early  # noqa: E402 (used once, ahead of any later import)

_pg_dir = _tempfile_early.mkdtemp()
_pg_pidfile = os.path.join(_pg_dir, "leaked.pid")
_pg_cmd = f"(sleep 20 & echo $! > {_pg_pidfile}); sleep 20"
_pg_rc = bead.run_probe(_pg_cmd, timeout=1)
check(_pg_rc == 124, "run_probe: a probe exceeding its timeout returns 124", _pg_rc)

_time_early.sleep(0.5)  # let SIGKILL delivery + reaping settle
_pg_leaked_pid = None
if os.path.exists(_pg_pidfile):
    with open(_pg_pidfile) as _pg_fh:
        _pg_raw = _pg_fh.read().strip()
        _pg_leaked_pid = int(_pg_raw) if _pg_raw.isdigit() else None
_pg_still_alive = False
if _pg_leaked_pid:
    try:
        os.kill(_pg_leaked_pid, 0)
        _pg_still_alive = True
    except ProcessLookupError:
        _pg_still_alive = False
    except PermissionError:
        _pg_still_alive = True
check(_pg_leaked_pid is not None,
      "run_probe: the backgrounded grandchild's pid was captured (fixture sanity)",
      _pg_pidfile)
check(_pg_still_alive is False,
      "run_probe: a timeout kills the WHOLE process group — a backgrounded grandchild "
      "must not outlive it", (_pg_leaked_pid, _pg_still_alive))

# --- probe_red_violations: RED-at-HEAD, the human-gate exemption, NOT-EXECUTED ------

r_exempt = bead.probe_red_violations(["true"], True)
check(r_exempt == ([], [], r_exempt[2]) and any("skipped" in m for m in r_exempt[2]),
      "probe_red_violations: a human-gate bead is exempt from the probe rule entirely", r_exempt)

r_allgreen = bead.probe_red_violations(["true"], False)
check(any("RED" in m and "already GREEN" in m for m in r_allgreen[0]),
      "probe_red_violations: a probe that is already green at HEAD is refused", r_allgreen)

r_sibling = bead.probe_red_violations(["false", "true"], False)
check(r_sibling[0] == [],
      "probe_red_violations: at least one red executable probe among siblings is clean", r_sibling)

r_notexec = bead.probe_red_violations(["zzz-nonexistent-cmd-abc123 --flag"], False)
check(r_notexec[0] == [] and any("NOT-EXECUTED" in m for m in r_notexec[2]),
      "probe_red_violations: an unresolvable interpreter goes on the NOT-EXECUTED list, "
      "never a silent skip and never forced into a refusal", r_notexec)

# --- consumes_violations: on-disk existence, or promised by the blocker's Delivers -----

_ctmp = _tf.mkdtemp()
with open(os.path.join(_ctmp, "existing.py"), "w") as _fh:
    _fh.write("x = 1\n")

cons_ok = [{"raw": "- a -> existing.py", "blocker": "ac-a", "artifact": "existing.py", "placeholder": False}]
check(bead.consumes_violations(cons_ok, _ctmp) == ([], []),
      "consumes_violations: an artifact already on disk needs no blocker check")

cons_missing = [{"raw": "- a -> missing.py", "blocker": "ac-a", "artifact": "missing.py", "placeholder": False}]
check(bead.consumes_violations(cons_missing, _ctmp,
      resolve_blocker=lambda bid: ({"description": "## Delivers\n- missing.py\n"}, None)) == ([], []),
      "consumes_violations: an absent artifact PROMISED by the blocker's own Delivers passes")

r_notpromised = bead.consumes_violations(cons_missing, _ctmp,
    resolve_blocker=lambda bid: ({"description": "## Delivers\n- something-else.py\n"}, None))
check(len(r_notpromised[0]) == 1 and "missing.py" in r_notpromised[0][0],
      "consumes_violations: an absent artifact NOT promised by the blocker is refused", r_notpromised)

r_blockererr = bead.consumes_violations(cons_missing, _ctmp,
    resolve_blocker=lambda bid: (None, "br show exited 1: no such issue"))
check(r_blockererr[0] == [] and len(r_blockererr[1]) == 1,
      "consumes_violations: a blocker that cannot be read is NOT-GATED, never a silent pass", r_blockererr)

cons_placeholder = [{"raw": "- ac-vague -> <the artifact ac-other promises>",
                      "blocker": "ac-vague", "artifact": "<the artifact ac-other promises>",
                      "placeholder": True}]
r_ph = bead.consumes_violations(cons_placeholder, _ctmp)
check(len(r_ph[0]) == 1 and "placeholder" in r_ph[0][0],
      "consumes_violations: an unfilled <placeholder> artifact is always refused", r_ph)

# --- consumes_violations: 'none (gate)' — valid whether the blocker is open or closed --

cons_gate_entry = [{"raw": "- ac-decision -> none (gate)", "blocker": "ac-decision",
                     "artifact": None, "placeholder": False, "gate": True}]
r_gate_closed = bead.consumes_violations(cons_gate_entry, _ctmp,
    resolve_blocker=lambda bid: ({"status": "closed"}, None))
check(r_gate_closed == ([], []),
      "consumes_violations: a gate-only entry whose blocker is CLOSED is satisfied", r_gate_closed)

r_gate_open = bead.consumes_violations(cons_gate_entry, _ctmp,
    resolve_blocker=lambda bid: ({"status": "open"}, None))
check(r_gate_open == ([], []),
      "consumes_violations: a gate-only entry whose blocker is still OPEN is ALSO satisfied — "
      "the bead simply waits on the edge; flight-check/pick already honour it (checker "
      "recheck 2026-09-27)", r_gate_open)

r_gate_in_progress = bead.consumes_violations(cons_gate_entry, _ctmp,
    resolve_blocker=lambda bid: ({"status": "in_progress"}, None))
check(r_gate_in_progress == ([], []),
      "consumes_violations: a gate-only entry whose blocker is in_progress is satisfied too — "
      "every non-closed status is 'still waiting', never a Consumes-line defect",
      r_gate_in_progress)

r_gate_err = bead.consumes_violations(cons_gate_entry, _ctmp,
    resolve_blocker=lambda bid: (None, "br show exited 1: no such issue"))
check(r_gate_err[0] == [] and len(r_gate_err[1]) == 1,
      "consumes_violations: a gate-only entry whose blocker cannot be read AT ALL (garbage "
      "id, br down) is still NOT-GATED, never a silent pass", r_gate_err)

cons_gate_malformed = [{"raw": "- garbage prose -> none (gate)", "blocker": None,
                         "artifact": None, "placeholder": False, "gate": True, "malformed": True}]
r_gate_malformed = bead.consumes_violations(
    cons_gate_malformed, _ctmp, resolve_blocker=_resolve_blocker_must_not_be_called)
check(len(r_gate_malformed[0]) == 1 and "malformed" in r_gate_malformed[0][0],
      "consumes_violations: a malformed gate-only line is REFUSED by name, never NOT-GATED "
      "via br show", r_gate_malformed)

# --- delivers_symlink_violations: a symlink resolving outside the repo root ------------

_droot = _tf.mkdtemp()
_doutside = _tf.mkdtemp()
with open(os.path.join(_doutside, "shared.sh"), "w") as _fh:
    _fh.write("#!/bin/sh\n")
with open(os.path.join(_droot, "local.sh"), "w") as _fh:
    _fh.write("#!/bin/sh\n")
os.symlink(os.path.join(_doutside, "shared.sh"), os.path.join(_droot, "linked.sh"))

check(len(bead.delivers_symlink_violations([{"paths": ["linked.sh"]}], _droot)) == 1,
      "delivers_symlink_violations: a symlink resolving outside the repo root is refused")
check(bead.delivers_symlink_violations([{"paths": ["local.sh"]}], _droot) == [],
      "delivers_symlink_violations: an ordinary tracked (non-symlink) file is clean")
check(bead.delivers_symlink_violations(
      [{"paths": ["~/mission/software/example-app/AGENTS.md"]}], _droot) == [],
      "delivers_symlink_violations: a declared cross-repo ~/ path is exempt")

# --- origin_violation / refined_human_gate_violation — label rules ---------------------

check(bead.origin_violation(["origin:ac-beadify", "refined"]) is None,
      "origin_violation: exactly one origin: label is clean")
check(bead.origin_violation(["refined"]) is not None,
      "origin_violation: zero origin: labels is refused")
check(bead.origin_violation(["origin:ac-a", "origin:ac-b"]) is not None,
      "origin_violation: two origin: labels is refused — exactly one is required")

check(bead.refined_human_gate_violation(["refined", "human-gate"]) is not None,
      "refined_human_gate_violation: refined beside human-gate is refused")
check(bead.refined_human_gate_violation(["refined"]) is None,
      "refined_human_gate_violation: refined alone is clean")
check(bead.refined_human_gate_violation(["human-gate"]) is None,
      "refined_human_gate_violation: human-gate alone (not yet refined) is clean")

# --- task_feature_delivers_violation: NO-DELIVERS / UNVERIFIABLE-DELIVERS ---------------
# Moved into bead.py FROM stamp-refined.sh's own copy (checker recheck 2026-09-27,
# evidence bd-pz8md/bd-1s800): VALIDATE ran `bead.py check` alone, which lacked this leg,
# and passed a bead the restamp gate's own (now-retired) copy of the SAME rule then
# downgraded — one home now, read by both callers.

check(bead.task_feature_delivers_violation("decision", "## Intent\nno Delivers at all.\n") is None,
      "task_feature_delivers_violation: a non-task/feature issue_type (decision) is exempt")

NO_DELIVERS_DESC = "## Intent\nsomething.\n\n## Acceptance Criteria\n- x.\n"
r_nd = bead.task_feature_delivers_violation("task", NO_DELIVERS_DESC)
check(r_nd is not None and r_nd.startswith("NO-DELIVERS"),
      "task_feature_delivers_violation: a task with no '## Delivers' section at all is NO-DELIVERS", r_nd)

EMPTY_DELIVERS_DESC = "## Intent\nsomething.\n\n## Delivers\n\n## Consumes\n- none\n"
r_empty = bead.task_feature_delivers_violation("feature", EMPTY_DELIVERS_DESC)
check(r_empty is not None and r_empty.startswith("NO-DELIVERS"),
      "task_feature_delivers_violation: a feature whose '## Delivers' section is present but "
      "empty is NO-DELIVERS", r_empty)

PROSE_DELIVERS_DESC = ("## Intent\nsomething.\n\n## Delivers\n"
                       "- a documented outcome with no artifact path\n\n## Consumes\n- none\n")
r_prose = bead.task_feature_delivers_violation("task", PROSE_DELIVERS_DESC)
check(r_prose is not None and r_prose.startswith("UNVERIFIABLE-DELIVERS"),
      "task_feature_delivers_violation: a task whose '## Delivers' is prose-only "
      "(no path-shaped artifact) is UNVERIFIABLE-DELIVERS", r_prose)

TOUCHERS_ONLY_DESC = ("## Intent\nsomething.\n\n## Delivers\n"
                     "- a documented outcome\n"
                     "  touchers: `rg -l -F \"x\" .` -> 2 · owned by: bd-fixture\n"
                     "\n## Consumes\n- none\n")
r_touchers_only = bead.task_feature_delivers_violation("task", TOUCHERS_ONLY_DESC)
check(r_touchers_only is not None and r_touchers_only.startswith("UNVERIFIABLE-DELIVERS"),
      "task_feature_delivers_violation: a bullet's own touchers: line is excluded from the "
      "path search — its command's path mentions don't count as the delivered artifact",
      r_touchers_only)

REAL_DELIVERS_DESC = "## Intent\nsomething.\n\n## Delivers\n- lib/parser.sh\n\n## Consumes\n- none\n"
check(bead.task_feature_delivers_violation("task", REAL_DELIVERS_DESC) is None,
      "task_feature_delivers_violation: a task with a real path-shaped Delivers artifact is clean")
check(bead.task_feature_delivers_violation("bug", PROSE_DELIVERS_DESC) is None,
      "task_feature_delivers_violation: the leg stays scoped to task/feature; a bug is exempt "
      "even with a prose-only Delivers")

# --- probe_runs_something / probe_presence_code_violation: PROBE-PRESENCE --------------
# Moved into bead.py FROM stamp-refined.sh's own inline copy (checker recheck 2026-09-28,
# evidence org-uv40/org-gv6): VALIDATE ran `bead.py check` alone, which lacked this leg
# entirely, and passed beads the restamp gate's own (now-retired) copy of the SAME rule
# then refused — one home now, read by both callers.

check(bead.probe_runs_something("grep -q FIXED subject.txt") is False,
      "probe_runs_something: a bare grep read is inert")
check(bead.probe_runs_something("rg -q TOKEN doc.md") is False,
      "probe_runs_something: a bare rg read is inert")
check(bead.probe_runs_something("test -f subject.txt") is False,
      "probe_runs_something: a bare test -f existence predicate is inert")
check(bead.probe_runs_something("test -e a.txt && test -x b.sh") is False,
      "probe_runs_something: every clause an existence predicate is still inert")
check(bead.probe_runs_something("test -x p.sh && bash p.sh") is True,
      "probe_runs_something: the guarded form 'test -x p && bash p' counts — the second "
      "clause survives")
check(bead.probe_runs_something("pnpm test lib/parser.test.ts") is True,
      "probe_runs_something: a real harness invocation counts")

CODE_NO_RUN_DESC = ("## Intent\nsomething.\n\n## Acceptance Criteria\n- x.\n"
                     "  Probe: `test -f lib/parser.sh`\n\n## Delivers\n- lib/parser.sh\n")
r_ppv_refused = bead.probe_presence_code_violation(CODE_NO_RUN_DESC)
check(r_ppv_refused is not None and r_ppv_refused.startswith("nothing left to run"),
      "probe_presence_code_violation: a code Delivers whose only probe is a bare "
      "existence/grep read is refused", r_ppv_refused)

CODE_RUNS_DESC = ("## Intent\nsomething.\n\n## Acceptance Criteria\n- x.\n"
                   "  Probe: `test -x lib/parser.sh && bash lib/parser.sh`\n"
                   "\n## Delivers\n- lib/parser.sh\n")
check(bead.probe_presence_code_violation(CODE_RUNS_DESC) is None,
      "probe_presence_code_violation: a code Delivers with a probe that runs something is clean")

NO_CODE_DESC = ("## Intent\nsomething.\n\n## Acceptance Criteria\n- x.\n"
                "  Probe: `grep -q TOKEN doc.md`\n\n## Delivers\n- doc.md\n")
check(bead.probe_presence_code_violation(NO_CODE_DESC) is None,
      "probe_presence_code_violation: a non-code (prose/doc) Delivers is exempt regardless "
      "of probe shape")

CODE_TOUCHERS_ONLY_DESC = ("## Intent\nsomething.\n\n## Acceptance Criteria\n- x.\n"
                            "  Probe: `test -f doc.md`\n\n## Delivers\n"
                            "- a documented outcome\n"
                            "  touchers: `rg -l -F \"lib/parser.sh\" .` -> 1 · owned by: bd-fixture\n")
check(bead.probe_presence_code_violation(CODE_TOUCHERS_ONLY_DESC) is None,
      "probe_presence_code_violation: a code path mentioned only on a touchers: line "
      "is excluded — it is not the delivered artifact")

# --- sensitive_prod_check: derived by calling prod-write-tripwire.sh, live ------------

SIGNAL_DESC = "## Intent\nBackfill: one-off data-fix for prod rows in the users table.\n"
s_signal = bead.sensitive_prod_check(SIGNAL_DESC, [], 0, "ac-test")
check(s_signal[0] == 1,
      "sensitive_prod_check: a prod-write signal with no recorded verdict is refused", s_signal)

s_gated = bead.sensitive_prod_check(SIGNAL_DESC, ["sensitive-prod"], 1, "ac-test")
check(s_gated[0] == 0,
      "sensitive_prod_check: sensitive-prod label + a DECISION blocks edge clears the tripwire", s_gated)

CLEAN_DESC = "## Intent\nRename a helper function.\n"
s_clean = bead.sensitive_prod_check(CLEAN_DESC, [], 0, "ac-test")
check(s_clean[0] == 0, "sensitive_prod_check: no signal at all passes clean", s_clean)

# --- seams_missing_violation: a plan-less implementable bead owes `## Seams` -----------

SEAMS_BODY = ("## Intent\nsomething.\n\n## Acceptance Criteria\n- x.\n  Probe: `test -x lib/parser.sh && bash lib/parser.sh`\n"
              "\n## Delivers\n- lib/parser.sh\n")
SEAMS_ROW = "\n## Seams\n- lib/parser.sh · new — no touchers\n"
v_missing = bead.seams_missing_violation("task", False, ["origin:ac-triage"], SEAMS_BODY)
check(v_missing is not None and "[seams-missing]" in v_missing,
      "seams_missing_violation: a plan-less task with a Delivers path and no Seams is refused", v_missing)
check(bead.seams_missing_violation("task", False, ["origin:ac-triage"], SEAMS_BODY + SEAMS_ROW) is None,
      "seams_missing_violation: the same bead with a non-empty Seams section passes")
check(bead.seams_missing_violation("task", False, ["origin:ac-triage"], SEAMS_BODY + "\n## Seams\n\n") is not None,
      "seams_missing_violation: an empty Seams heading counts as missing")
check(bead.seams_missing_violation("task", False, ["origin:ac-beadify"], SEAMS_BODY) is None,
      "seams_missing_violation: origin:ac-beadify inherits its plan's Seams and is exempt")
check(bead.seams_missing_violation("epic", False, ["origin:ac-triage"], SEAMS_BODY) is None,
      "seams_missing_violation: an epic is exempt")
check(bead.seams_missing_violation("task", True, ["origin:ac-triage"], SEAMS_BODY) is None,
      "seams_missing_violation: a human-gate bead is exempt")
PROSE_DELIVERS = ("## Intent\nsomething.\n\n## Acceptance Criteria\n- x.\n  Probe: `test -x a && bash a`\n"
                  "\n## Delivers\n- a documented outcome with no path\n")
check(bead.seams_missing_violation("bug", False, ["origin:ac-triage"], PROSE_DELIVERS) is None,
      "seams_missing_violation: a bug whose Delivers is prose-only (path None) is exempt")

SEAMS_PSQL = ("## Intent\nRename a helper function.\n\n## Seams\n"
              "- lib/x.sql · reads — a psql backfill: one-off data-fix for prod rows in the users table\n")
s_seams = bead.sensitive_prod_check(SEAMS_PSQL, [], 0, "ac-test")
check(s_seams[0] == 0,
      "sensitive_prod_check: prod-write words inside the Seams section do not trip the tripwire", s_seams)
s_outside = bead.sensitive_prod_check(SEAMS_PSQL.replace("## Seams", "## Notes"), [], 0, "ac-test")
check(s_outside[0] == 1,
      "sensitive_prod_check: the same words outside a Seams section still trip it", s_outside)

# --- cmd_check (the CLI): end-to-end, each exit class -----------------------------------

BEAD_PY = os.path.join(HERE, "bead.py")


def _run_check(args, **kw):
    return _sp.run([sys.executable, BEAD_PY, "check", *args],
                    capture_output=True, text=True, timeout=60, cwd=HERE, **kw)


cli_missing = _run_check(["/nonexistent/bead-body.md"])
check(cli_missing.returncode == 2,
      "cmd_check CLI: an unreadable input is NOT-GATED (exit 2), never a pass", cli_missing.stderr)

_fd1, _body_ok = _tf.mkstemp(suffix=".md")
with os.fdopen(_fd1, "w") as _fh:
    _fh.write("## Acceptance Criteria\n- something.\n  Probe: `test -f /definitely/not/here.xyz`\n")
cli_ok = _run_check([_body_ok])
check(cli_ok.returncode == 0,
      "cmd_check CLI: a clean body with one currently-red probe passes",
      (cli_ok.returncode, cli_ok.stdout, cli_ok.stderr))
os.unlink(_body_ok)

_fd2, _body_green = _tf.mkstemp(suffix=".md")
with os.fdopen(_fd2, "w") as _fh:
    _fh.write("## Acceptance Criteria\n- something.\n  Probe: `true`\n")
cli_green = _run_check([_body_green])
check(cli_green.returncode == 1 and "REFUSED" in cli_green.stderr,
      "cmd_check CLI: a probe already green at HEAD is refused by name (exit 1)",
      (cli_green.returncode, cli_green.stderr))
os.unlink(_body_green)

_fd3, _body_banned = _tf.mkstemp(suffix=".md")
with os.fdopen(_fd3, "w") as _fh:
    _fh.write("## Acceptance Criteria\n- something.\n  Probe: `bash scripts/run-all-proofs.sh`\n")
cli_banned = _run_check([_body_banned])
check(cli_banned.returncode == 1 and "run-all-proofs" in cli_banned.stderr,
      "cmd_check CLI: a banned whole-suite probe shape is refused by name, never executed",
      (cli_banned.returncode, cli_banned.stderr))
os.unlink(_body_banned)

# --- parse_meta_header — the FILE FORM header bead-artifact.py export writes and ---------
# --- bead-schema.md's own "Example bead" carries verbatim -------------------------------

EXPORT_HEADER = ("# ac-x1 — a title\n"
                  "type: task · priority: 2 · labels: origin:ac-beadify,unrefined · base: abcd1234ef567890\n"
                  "\n## Intent\nsomething.\n")
check(bead.parse_meta_header(EXPORT_HEADER) == ("task", ["origin:ac-beadify", "unrefined"]),
      "parse_meta_header: bead-artifact.py export's own header shape (type · priority · labels · base)",
      bead.parse_meta_header(EXPORT_HEADER))

SCHEMA_HEADER = ("title: ac-x: a title\n"
                 "type: task · priority: 1 · parent: `ac-epic` · labels: none\n"
                 "\n## Intent\nsomething.\n")
check(bead.parse_meta_header(SCHEMA_HEADER) == ("task", []),
      "parse_meta_header: bead-schema.md's own Example-bead header shape (type · priority · parent · labels)",
      bead.parse_meta_header(SCHEMA_HEADER))

check(bead.parse_meta_header("## Intent\nno header here at all.\n") == (None, None),
      "parse_meta_header: a bare description with no header line returns (None, None), never a guess")

# --- cmd_check CLI, file mode WITH a meta header — origin/refined-human-gate and --------
# --- task/feature NO-DELIVERS now run for a file (the bug: they were always skipped) ----

_fd4, _body_meta_no_origin = _tf.mkstemp(suffix=".md")
with os.fdopen(_fd4, "w") as _fh:
    _fh.write("# ac-x2 — a title\ntype: task · priority: 2 · labels: none · base: 0000000000000000\n"
              "\n## Intent\nsomething.\n\n## Acceptance Criteria\n- x.\n  Probe: `test -f /nope.xyz`\n"
              "\n## Delivers\n- lib/parser.sh\n")
cli_meta_no_origin = _run_check([_body_meta_no_origin])
check(cli_meta_no_origin.returncode == 1 and "no origin:" in cli_meta_no_origin.stderr,
      "cmd_check CLI: file mode WITH a meta header runs origin_violation (the labels leg — "
      "previously skipped unconditionally for any file target)",
      (cli_meta_no_origin.returncode, cli_meta_no_origin.stderr))
os.unlink(_body_meta_no_origin)

_fd5, _body_meta_no_delivers = _tf.mkstemp(suffix=".md")
with os.fdopen(_fd5, "w") as _fh:
    _fh.write("# ac-x3 — a title\ntype: task · priority: 2 · labels: origin:ac-beadify · base: 0000000000000000\n"
              "\n## Intent\nsomething.\n\n## Acceptance Criteria\n- x.\n  Probe: `test -f /nope.xyz`\n")
cli_meta_no_delivers = _run_check([_body_meta_no_delivers])
check(cli_meta_no_delivers.returncode == 1 and "NO-DELIVERS" in cli_meta_no_delivers.stderr,
      "cmd_check CLI: file mode WITH a meta header runs task_feature_delivers_violation "
      "(the Delivers leg — previously skipped unconditionally for any file target)",
      (cli_meta_no_delivers.returncode, cli_meta_no_delivers.stderr))
os.unlink(_body_meta_no_delivers)

_fd6, _body_meta_clean = _tf.mkstemp(suffix=".md")
with os.fdopen(_fd6, "w") as _fh:
    _fh.write("# ac-x4 — a title\ntype: task · priority: 2 · labels: origin:ac-beadify · base: 0000000000000000\n"
              "\n## Intent\nsomething.\n\n## Acceptance Criteria\n- x.\n"
              "  Probe: `test -f /nope.xyz && bash /nope.xyz`\n"
              "\n## Delivers\n- lib/parser.sh\n")
cli_meta_clean = _run_check([_body_meta_clean])
check(cli_meta_clean.returncode == 0,
      "cmd_check CLI: file mode WITH a full meta header (origin present, Delivers present) "
      "passes clean on those legs — its probe also clears the new probe-presence leg "
      "('test -f p && bash p', not a bare existence read)",
      (cli_meta_clean.returncode, cli_meta_clean.stdout, cli_meta_clean.stderr))
check("file mode skipped: sensitive-prod" in cli_meta_clean.stdout,
      "cmd_check CLI: file mode names sensitive-prod as skipped on one line even WITH a "
      "meta header — its own DECISION-blocks count is a board-only dependency-edge lookup",
      cli_meta_clean.stdout)
os.unlink(_body_meta_clean)

_fd7, _body_no_meta = _tf.mkstemp(suffix=".md")
with os.fdopen(_fd7, "w") as _fh:
    _fh.write("## Acceptance Criteria\n- x.\n  Probe: `test -f /nope.xyz`\n")
cli_no_meta = _run_check([_body_no_meta])
check(cli_no_meta.returncode == 0,
      "cmd_check CLI: file mode with NO meta header still passes clean (origin/Delivers "
      "legs are skipped, never guessed at)",
      (cli_no_meta.returncode, cli_no_meta.stdout, cli_no_meta.stderr))
check("file mode skipped: origin/refined-human-gate" in cli_no_meta.stdout
      and "task/feature NO-DELIVERS" in cli_no_meta.stdout
      and "sensitive-prod" in cli_no_meta.stdout,
      "cmd_check CLI: file mode with no meta header names ALL three skipped legs on one line",
      cli_no_meta.stdout)
os.unlink(_body_no_meta)

print("---")
print(f"PASS={PASS} FAIL={FAIL}")
sys.exit(0 if FAIL == 0 else 1)
