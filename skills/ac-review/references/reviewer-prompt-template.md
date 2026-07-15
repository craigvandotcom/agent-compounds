# Reviewer Prompt Template

The shared prompt for all Phase-2 panel reviewers. Spawn one Task **per spawned
dimension** (core four always; test-quality and contracts per their SKIP rules — see
`review-dimensions.md`), all in a **single message** (parallel). Fill the `{...}`
placeholders from the dimension's row in `review-dimensions.md`, and substitute
`{DIFF}`, `{ARTIFACTS_DIR}`, `{ROUND}` (`1` for the Phase-2 pass, `2` for a Phase-5.5
verification round), and `{N_OTHERS}` (panel size minus one — e.g. `5` for the full
six-dimension panel).

```
Task(subagent_type: "general-purpose", model: "sonnet", prompt: """
First: read AGENTS.md for project context, coding standards, and conventions.
{SKILL_HINT}

You are a {ROLE} reviewer. You compete with {N_OTHERS} other reviewers — only evidence-backed findings with file paths count.

## Diff to Review
```diff
{DIFF}
```

## Your Method

{METHOD}

## Examples of What to Look For (not exhaustive)

{CHECKLIST}

Use your judgment — these are starting points, not a complete list. If you spot something {ROLE}-relevant not listed here, report it.

## Output

Write findings as **JSON only** (no prose, no markdown around it) to
{ARTIFACTS_DIR}/round-{ROUND}-{ROLE}.json — it is machine-read for deterministic consensus:

{
  "reviewer": "{ROLE}",
  "round": {ROUND},
  "findings": [
    {
      "title": "<short title>",
      "severity": "Critical|High|Medium",
      "file": "path/to/file",
      "line": <line number>,
      "category": "<stable kebab-case defect-class slug — the consensus key>",
      "evidence": "<what you found>",
      "fix": "<specific change needed>",
      "auto_fixable": true
    }
  ]
}

- `category` is the **consensus key**: prefer your dimension's SLUGS list; pick the slug
  another reviewer would choose for the SAME underlying issue at the same file:line
  (e.g. `sql-injection`, `n+1-query`, `hollow-test`). Name the defect class, not your
  wording — that is how same-round and cross-round consensus are detected.
- Limit: top 7 findings. Skip Low severity. If nothing found, emit
  `{"reviewer":"{ROLE}","round":{ROUND},"findings":[]}`.
- Emit ONLY the JSON object — a parser reads this file; any prose breaks it.
""")
```

Notes:
- `{SKILL_HINT}` is optional — include only if the Phase-1 skill routing found a relevant skill for that dimension (e.g. `Read .claude/skills/<security-skill>/SKILL.md for security patterns.`). Omit the line otherwise.
- `{METHOD}` comes from the dimension's METHOD block in `review-dimensions.md` — it is the how-to-hunt doctrine, not more checklist items. Always include it.
- `{ROLE}` is the lowercase dimension name used both in the prose and the output filename (`round-{ROUND}-security.json`, `round-{ROUND}-test-quality.json`, etc.).
- After spawning, record the panel in `$ARTIFACTS_DIR/panel-round-{ROUND}.json` (SKILL.md Phase 2) so `consensus.py` validates against what was actually spawned.

## Measurement / analytics honesty (conditional add-on)

`ac-review` hardcodes 4 core reviewers (`consensus.py` and Phase 2 expect exactly 4) — this is
**not a 5th reviewer**. When the diff **instruments analytics events** or **produces
metrics/rates/reports a human will trust for decisions**, splice this checklist into the
**correctness** or **architecture** reviewer's `{CHECKLIST}` for that round (per-bead TDD proves
an event fires and each function's contract holds — it cannot prove the event fires *only* when
it should, *without leaking*, or that the measurement as a whole answers the intended question):

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
`ac-bead-refine` + every engineer's own tests) yet an honesty-briefed reviewer found a High
feedback-loop bug in one and `ac-review` found 6 High bugs across 5 of these classes in the
other (incl. a PII leak that falsified the app's own privacy claim). PostHog is the shared
stack across every app — this checklist recurs, it is not app-specific.
