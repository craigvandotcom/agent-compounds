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
check(bead.probe_shape_violation('pnpm exec vitest run') is not None,
      "probe_shape_violation: bare pnpm exec vitest run (whole suite) is banned")
check(bead.probe_shape_violation('pnpm exec vitest run src/x.test.ts') is None,
      "probe_shape_violation: pnpm exec vitest run scoped to a file is NOT banned")
check(bead.probe_shape_violation('bash scripts/run-all-proofs.sh') is not None,
      "probe_shape_violation: run-all-proofs.sh is banned (the whole-suite CI script)")
check(bead.probe_shape_violation('supabase db push --linked') is not None,
      "probe_shape_violation: a direct supabase invocation is banned")
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

print("---")
print(f"PASS={PASS} FAIL={FAIL}")
sys.exit(0 if FAIL == 0 else 1)
