# Reviewer Prompt Template

<!-- mirror: ac-pipeline/references/delegation-contract.md § Child-spawn preamble -- edit there first -->

**Conductor: paste the block below VERBATIM at the head of EACH of the `Task(...)`
prompts in this file, above its `First: read AGENTS.md` line, substituting the child's
minted `AGENT_NAME`.** It is the child-side environment contract and a pointer to it is
explicitly insufficient (canon § Child-spawn preamble) — a preamble that stays in this
header and never enters the constructed prompt has not been delivered to any child.

ENVIRONMENT CONTRACT (non-negotiable):
- WAIT for your own long-running commands in-shell (foreground, generous Bash
  timeout, or a foreground until-loop). Never arm a Monitor on your own command
  and end your turn — if a completion event already fired, read it and CONTINUE.
- Agent Mail: CHECK whether you hold `mcp__mcp-agent-mail__*` tools — assume neither way.
  Usually you do NOT: then don't try to register, and your conductor owns reservations.
  Either way, export the `AGENT_NAME` it gave you in each commit's own shell.
- Touching beads (`br`/`bv`)? The canon is `beads-standards` (+ its
  reference/bead-conventions.md for pipeline contracts) — read before inventing usage.
- After every push: verify origin SHA == local HEAD before proceeding.
- A guard block (dcg / pre-commit) means CHANGE APPROACH, never bypass — the
  blocked + sanctioned shape list is `ac-pipeline/references/shell-guardrails.md`.
  Destructive commands (rm / find -delete) take FULLY-LITERAL paths: resolve,
  then paste literals; home/repo `rm -rf` never — `git rm` if tracked, else
  gitignore-and-flag or ask the human. Discard via scoped `git stash push -- <paths>`;
  read a pristine file via `git show <ref>:<path>`.
- Shared checkout: `git commit -- <your files>` the INSTANT its ACs verify —
  pathspec on the COMMIT, because scoping only the `add` still publishes the
  shared index. **Never `git add -A` / `git add .` / `git commit -a`** — they
  sweep a concurrent agent's staged work into your bead's commit, silently.
  Minimal working-tree dwell; run `br` from the bead-board repo root.
- Autonomous run: never AskUserQuestion — Exhaust Rule.
- Never file beads (`br create`): machinery goes in `friction:`, product in your return summary — the conductor is the run's only filer.
- Return a structured `friction:` block (stage/cost/lesson/class; `[]` if clean).

Two child prompts, both run by hand over a range the operator names (`ac-review
<range>`): the **reviewer prompt** — one Task per lens in `review-dimensions.md`
(correctness, test-quality, and the one risk lens the diff chooses), all in a single
message (parallel) — and the **verify round**, one fresh verifier per Critical/High
finding, run BEFORE any fix. Fill the `{...}` placeholders from the lens's block in
`review-dimensions.md`, and substitute `{DIFF_RANGE}` (the resolved diff range — a
point-sized string; reviewers run `git diff` on it themselves, the diff body is never
pasted — `ac-pipeline/references/delegation-contract.md` § Payloads point),
`{ARTIFACTS_DIR}` (`round-1-{ROLE}.json` is written there) and `{ROUND}` (`1` for the
review pass). Reviewers spawn as the **validator** stance (tier-resolved per harness; a
different stance from the implement workers, so the same weights re-reading their own
diff are not independent eyes).

```
Task(subagent_type: "validator", prompt: """
First: read AGENTS.md for project context, coding standards, and conventions.
{SKILL_HINT}

You are a {ROLE} reviewer. The bar: a finding is a **demonstrated failure in
ordinary operation**, or a **violated acceptance criterion**, with a **reproducing
command** anyone can re-run. "Could be bypassed" counts only against a real adversary —
user input, auth, external data, PII, money — never our own worker; and the probe may
not set up state a cooperative worker or a real user would not produce. Everything else
is not a finding. **An empty report is the expected result** — report nothing rather
than restate the bar.

## Diff to Review

1. Run: `git diff {DIFF_RANGE}`

## Your Method

{METHOD}

## What to Look For

{CHECKLIST}

## Output

Write findings as **JSON only** (no prose, no markdown around it) to
{ARTIFACTS_DIR}/round-{ROUND}-{ROLE}.json:

{
  "lens": "{ROLE}",
  "round": {ROUND},
  "payload_read": "git diff {DIFF_RANGE}",
  "findings": [
    {
      "bin": "defect|hardening",
      "title": "<short title>",
      "severity": "Critical|High",
      "file": "path/to/file",
      "line": <line number>,
      "category": "<short kebab-case label for the defect class>",
      "evidence": "<the demonstrated failure>",
      "reproduce": "<the exact command anyone can re-run>",
      "fix": "<specific change needed>"
    }
  ]
}

- **A `defect` requires `reproduce`.** Without a command anyone can re-run, the finding
  is `hardening` — a real-but-not-demonstrated idea, one line in the report, never a bead.
- Critical/High only. If nothing found, emit
  `{"lens":"{ROLE}","round":{ROUND},"findings":[]}`.
- Emit ONLY the JSON object — a parser reads this file; any prose breaks it.
""")
```

Notes:
- `{SKILL_HINT}` is optional — include only if project skill routing found a relevant skill for that lens (e.g. `Read .claude/skills/<security-skill>/SKILL.md for security patterns.`). Omit the line otherwise.
- `{METHOD}`, `{CHECKLIST}` and `{ROLE}` come from the lens's block in `review-dimensions.md` — `{ROLE}` is the lowercase lens name, used both in the prose and the output filename (`round-{ROUND}-correctness.json`, `round-{ROUND}-security.json`, etc.).

## Measurement / analytics honesty (conditional add-on)

When the diff **instruments analytics events** or **produces metrics/rates/reports a human
will trust for decisions**, splice this checklist into the **correctness** reviewer's
`{CHECKLIST}` for that round (per-bead TDD proves an event fires and each function's contract
holds — it cannot prove the event fires *only* when it should, *without leaking*, or that the
measurement as a whole answers the intended question):

**Measurement honesty (metrics/analysis code):**
1. **Denominator honesty** — what's excluded/exempted, and is every exclusion loud?
2. **Feedback loops** — does simulated/derived state feed back where real state would (drift,
   staleness), or does a shortcut quietly reuse ground-truth data?
3. **Join keys** — every cross-dataset join (paths/names/IDs) normalized on BOTH sides + a
   loud guard when a join yields zero matches against nonzero inputs.
4. **Guard swallowing** — do failure guards still emit their diagnosis artifact, or does an
   early throw destroy the evidence?
5. **Bias direction** — name which way each approximation biases the metric; conservative
   (overstating problems) OK, optimistic is a bug.

**Analytics `track()` call-sites (the 5 recurring failure modes):**
1. **CREATE vs EDIT** — a save/submit event fires on edits too unless explicitly gated.
2. **Shared component → wrong route** — a handler in a multi-page component emits everywhere;
   pass a context prop, fire only in the intended context.
3. **Payload leaks PII/health** — an `*_id` is often a content slug; send categorical *type*
   only. (Key-based `scrubPII` at the boundary is a backstop, not the guarantee — it misses
   innocent-looking content keys and nested objects.)
4. **Timing spans too many awaits** — stop the timer at the exact operation boundary.
5. **Fires on no-op / failure** — guard empty results; fire activation events at the
   API-success point, not inside a later try a downstream throw can drop.

Evidence: two independent waves shipped fully green (28 green unit tests + tsc clean; 3-reviewer
refine pass + every engineer's own tests) yet an honesty-briefed reviewer found a High
feedback-loop bug in one and `ac-review` found 6 High bugs across 5 of these classes in the
other (incl. a PII leak that falsified the app's own privacy claim). PostHog is the shared
stack across every app — this checklist recurs, it is not app-specific.

## The verify round (runs before any fix)

One fresh `Task` — same validator stance, and a different child from every reviewer — per
Critical/High finding. It runs **before any fix**, and only when at least one Critical/High
finding exists: **no Critical/High → no verify round**. Substitute `{FINDING}` (that
finding's JSON, verbatim), `{N}` (the finding's index), `{DIFF_RANGE}` and `{ARTIFACTS_DIR}`.

```
Task(subagent_type: "validator", prompt: """
First: read AGENTS.md for project context, coding standards, and conventions.

A reviewer reported the finding below. Your job is to REFUTE it, not to confirm it. Run
its reproducing command yourself. If you cannot reproduce it, say so — a clean
refutation is a successful outcome, not a failure.

{FINDING}

## Rules

1. **Run the command.** Paste its real output. A finding you did not re-run is not
   verified.
2. **Name the precondition's real-world source** — the actor, input, state or path that
   produces the precondition in ordinary operation. If the only source is a hostile setup,
   or our own worker producing a state a real user never produces, the finding does not
   clear the bar: refute it.
3. **Try to refute, hard.** Weaken the precondition; check the failure is caused by this
   diff, not an already-green probe or a sibling's change.
4. **Raise nothing new.** You may not add findings, severity or scope. A new problem you
   notice goes in `notes`, for the operator — never as a finding.

## Output

JSON only, no prose around it, to {ARTIFACTS_DIR}/verify-{N}.json:

{
  "finding": "<the finding's title>",
  "verdict": "confirmed|refuted",
  "command": "<what you ran>",
  "output": "<its real output>",
  "precondition_source": "<who or what produces it in ordinary operation>",
  "reason": "<why confirmed or refuted>",
  "notes": "<anything new you saw, or empty>"
}

- A `refuted` finding is **not** deleted: it stays in the report's Hardening section with
  your reason and the probe output, so the operator sees every refutation.
""")
```

