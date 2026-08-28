
**You are the conductor.** Agents provide focused lenses. You synthesize. You apply edits directly. Repeat until convergence.

Competitive framing: agents compete — only evidence-backed findings count. Codebase verification is mandatory.

---

## I/O Contract

|                  |                                                                                            |
| ---------------- | ------------------------------------------------------------------------------------------ |
| **Input**        | Approved plan file (from `/ac-plan-init`)                                                     |
| **Output**       | Refined plan (in-place edit), Refinement Log appended                                      |
Consensus + auto-apply cascade per `ac-pipeline/references/review-consensus.md` (cite, never fork).

| **Artifacts**    | Round findings in `$ARTIFACTS_DIR/round-{N}-{role}.md`, consensus registry                 |
| **Verification** | Convergence trend (fewer findings each round), plan committed                              |

## Phase 0: Initialize

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
```

### Identify Plan File

`PLAN_FILE`: Check argument, then `_plans/*.md`, then `PLAN.md` in project root. If none found, STOP: "No plan found. Provide a path or run /ac-plan-init first."

### Select Intensity Tier

Infer from the invocation prompt — **do NOT ask**:

- **Light** — user said "light", "quick", or "fast refine" → Sonnet agents, 2–4 rounds
- **Heavy** — user said "heavy", "thorough", "deep", "full", or "exhaustive" → 6 Opus agents, 3–6 rounds
- **Medium** — anything else (default) → 3 Opus agents, 2–4 rounds

### Configuration

```
TIER=<user selection>

# Tier-dependent settings:
# Light:  AGENT_MODEL=sonnet, AGENT_COUNT=3, PERSONAS=simple, MIN_ROUNDS=2, MAX_ROUNDS=4
# Medium: AGENT_MODEL=opus,   AGENT_COUNT=3, PERSONAS=simple, MIN_ROUNDS=2, MAX_ROUNDS=4
# Heavy:  AGENT_MODEL=opus,   AGENT_COUNT=6, PERSONAS=heavy,  MIN_ROUNDS=3, MAX_ROUNDS=6
# MIN_ROUNDS=2 is an ABSOLUTE floor across every tier (Craig's call, 2026-07-07) — light/medium
# are raised to it here; heavy's own floor of 3 already clears it, so heavy is unchanged.

CURRENT_ROUND=1
# Mint RUN_ID if the orchestrator didn't hand one down (contract: ac-pipeline/references/run-id.md
# mint-if-absent rule) — keeps standalone and orchestrated runs on the same formula.
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-$$}"
ARTIFACTS_DIR=/tmp/plan-refine-internal-${RUN_ID}   # RUN_ID carries the PID → no same-second collision (ac-pipeline/references/run-id.md)
```

```bash
mkdir -p "$ARTIFACTS_DIR"
```

### Initialize Consensus Registry

Create the cross-round tracking file for single-agent findings:

> **If `dcg` rejects this write, do NOT bypass it** — the guard blocks a redirect whose target path
> is variable-built. Sanctioned shapes (`tee`, the Write tool): `ac-pipeline/references/shell-guardrails.md`.

```bash
tee "$ARTIFACTS_DIR/consensus-registry.md" >/dev/null <<'EOF'
# Consensus Registry

Tracks single-agent findings across rounds. If a finding recurs in a later round, it achieves cross-round consensus and is auto-applied.

## Deferred Findings

<!-- Format: | Round | Agent | Severity | Summary | Section | -->
EOF
```

### Ensure on main

Plan refinement is doc work — always runs on main (branch policy: only code on wave branches):

```bash
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
  echo "On $CURRENT_BRANCH — switching to main before plan-refine commits"
  git checkout main
  git pull --rebase --autostash
fi
```

### Checkpoint Original Plan

Git discipline: `ac-pipeline/references/commit-discipline.md` — pathspec-only commits, no wildcard adds / stash, commit=push, deletion check.

```bash
git add "$PLAN_FILE" && git commit -m "docs(plan): checkpoint before plan-refine-internal

Co-Authored-By: Claude <noreply@anthropic.com>" || true
```

### Mark Active Work

Update the plan file's frontmatter to signal this skill is running:

```yaml
---
status: in_progress
working_skill: plan-refine-internal
working_since: YYYY-MM-DD
---
```

Preserve all other existing frontmatter fields.

### Signal Active Work (Agent Mail)

Use the agent name registered at session start (from `macro_start_session`). Compute `PLAN_REL` = path of `PLAN_FILE` relative to `PROJECT_ROOT` (e.g. `_plans/foo.md`).

> **Carry the registration_token (`ac-g93`).** Capture the
> `registration_token` returned by `macro_start_session` and thread it EXPLICITLY on EVERY
> privileged / mutating Agent Mail call below — file reservations
> (`file_reservation_paths` / `release_file_reservations` / `renew_file_reservations` /
> `force_release_file_reservation`) take it as `registration_token`, `send_message` / `reply_message`
> as `sender_token`. Do NOT rely on same-session auth carry — it is transport-conditional. Canonical
> note: `agent-mail/references/agent-identity.md` § Call-scoped facts.

**Reserve the plan file:**

```
mcp__mcp-agent-mail__file_reservation_paths(
  project_key: CANONICAL_PROJECT_KEY,   // canonical "neometa/<app-dir>" key — key-format + never-absolute rule: agent-mail/references/agent-identity.md § Project key format
  agent_name: <session agent name>,
  paths: [PLAN_REL],
  ttl_seconds: 14400,
  exclusive: true,
  reason: "plan-refine-internal — in progress"
)
```

**Broadcast WIP signal:**

```
mcp__mcp-agent-mail__send_message(
  project_key: CANONICAL_PROJECT_KEY,   // canonical "neometa/<app-dir>" key — key-format + never-absolute rule: agent-mail/references/agent-identity.md § Project key format
  sender_name: <session agent name>,
  to: [<session agent name>],
  subject: "WIP: plan-refine-internal — {PLAN_REL}",
  body_md: "Starting `plan-refine-internal` on `{PLAN_REL}`.",
  topic: "pipeline-wip"
)
```

### Create Workflow Tasks (run ledger)

**One task per major section — the ledger exists for CLARITY + ACCOUNTABILITY**, so every
section you'd report on gets its own line (not a 3-phase skeleton). Create the fixed tasks
below at Phase 0; **ADD a "Round N" task at the start of each review round** (rounds are
dynamic — 2 floor, up to each tier's `MAX_ROUNDS` — so the ledger grows to the real shape
instead of pre-committing to a round count or showing phantom rounds). `TaskUpdate` each to
`in_progress` when you start it and `completed` when done; put live detail in the description
(per round: finding counts + convergence verdict), so a glance at the ledger shows exactly
where the run is.

Ledger contract: `ac-pipeline/references/run-ledger.md` — one task per section, advance as you go; ledger = run position, never work items. If TaskCreate is unavailable (subagent / fan-out path), track the ledger inline in progress.md; this is a sanctioned equivalent, not a deviation.

```
# Fixed tasks — create upfront at Phase 0:
TaskCreate("Initialize — identify plan, select tier, checkpoint, consensus registry, agent-mail reservation")
TaskCreate("Conductor triage — classify remaining no-consensus + DESIGN_DECISION findings")
TaskCreate("Present decisions — surface DESIGN_DECISION/SCOPE_ESCALATION items to the user")
TaskCreate("Apply + update plan + commit — apply approved items, update frontmatter, commit + push")
TaskCreate("Report — refinement summary + loop-ready prompt")

# Per-round task — create ONE as each round begins (not upfront):
TaskCreate("Round {N} — {TIER} lens reviewers → synthesize → apply")
# On completion, TaskUpdate its description: "{C}/{H}/{M} findings, {n} auto-applied, convergence: {major|minor|cosmetic}"
```

With a 2-round run (the light/medium floor) that's 7 tasks; a 4-round light/medium run, 9; a
6-round heavy run, 11. **TaskUpdate("Initialize", in_progress)** now, and mark it `completed`
at the end of Phase 0.

---

## REFINEMENT LOOP: Phases 1-4

### Phase 1: Read Current Plan + Identify Skills

```
PLAN_CONTENT = Read(PLAN_FILE)
```

**Compaction recovery:** If PLAN_CONTENT contains a `## Refinement Log` section, parse the last `### Round N` entry to recover CURRENT_ROUND (set to N+1). Previous rounds' changes are already applied to the plan. Read any existing findings files in `ARTIFACTS_DIR` for context on the most recent round. If `$ARTIFACTS_DIR/consensus-registry.md` exists, read it to recover the deferred findings pool for cross-round consensus detection.

**Skill routing:** Scan plan content for domain keywords. Check `AGENTS.md` > "Available Skills" for relevant skills. Include a line in each subagent prompt: `"Domain skills relevant to this plan: <list>. Read the corresponding skill file when evaluating sections that touch those domains."`

### Phase 2: Parallel Subagent Review

<!-- mirror: ac-pipeline/references/delegation-contract.md § Child-spawn preamble -- edit there first -->

**Conductor: paste the block below VERBATIM at the head of EACH of the nine `Task(...)`
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
- A guard block (dcg / pre-commit) means CHANGE APPROACH, never bypass. To DISCARD
  a change: `git checkout HEAD -- <path>` AND unscoped `git stash` are both blocked —
  use scoped `git stash push -- <paths>`; to read a pristine file, `git show <ref>:<path>`.
  Destructive commands (rm / find -delete) take FULLY-LITERAL paths: resolve
  first (`ls -d`), then paste literals — never `$VAR`, `$( )`, or a loop var.
  /tmp literals + distinctive /tmp globs are allowed; home/repo `rm -rf` never
  is — `git rm` if tracked, else gitignore-and-flag or ask the human.
- Shared checkout: `git commit -- <your files>` the INSTANT its ACs verify —
  pathspec on the COMMIT, because scoping only the `add` still publishes the
  shared index. **Never `git add -A` / `git add .` / `git commit -a`** — they
  sweep a concurrent agent's staged work into your bead's commit, silently.
  Minimal working-tree dwell; run `br` from the bead-board repo root.
- Autonomous run: never AskUserQuestion — Exhaust Rule.
- Return a structured `friction:` block (stage/cost/lesson/class; `[]` if clean).

**Spawn all agents simultaneously in a single message.** Light/Medium -> 3 agents (simple personas). Heavy -> 6 agents (heavy personas).

Each agent has codebase access and should consider the **full pipeline context**: existing code, unimplemented beads (`br list` if beads exist), and other plans in `_plans/`. Flag conflicts, duplication, or sequencing issues with any of these — not just what's already merged.

Each agent receives the plan content and this output format:

```
For each issue: ## Issue N: Title | Severity: Critical/High/Medium | Section: X | Evidence: [file paths, line numbers] | Problem: X | Suggestion: X
```

**File output:** Each agent writes its complete findings to `ARTIFACTS_DIR/round-{CURRENT_ROUND}-{role}.md` using the Write tool. Conductor substitutes actual paths when spawning agents.

#### Simple Personas (Light + Medium tiers)

**Agent 1: Builder ({AGENT_MODEL})**

```
First: read AGENTS.md for project context.

You are a practical implementer and spec auditor. You compete with 2 other reviewers — only evidence-backed findings count. Can I build this tomorrow?

Check: steps complete and unambiguous, dependencies correctly ordered, every deliverable owned by exactly one phase, no gaps between what one phase produces and the next requires. Trace what each phase produces vs what the next phase consumes.

**Audit the plan's validation layer (test-first applies to plans, not just code):** the plan must carry a real `## Validation` section and per-step "Done when" checks. For each, name the exact check that would verify it (command, test, journey, observable) — a Done-when no one can name a check for is a finding. Verify the validation METHOD matches the work's plane (UI feature → browser-automation/journey validation, API → response-shape assertions, bug → reproduction script, perf → baseline metrics — the ac-plan-init Phase-2 table). If the plan claims a validation tool/baseline was "tasted", check the referenced baseline artifact exists; if the plan skipped taste-the-tools for a plane it touches, flag High.

You have codebase access. Read referenced files to confirm functions/types exist with claimed signatures. For each issue: quote the plan, show what code actually has, state what's needed.

Limit: top 5 issues. If you have additional Critical/High, add as one-liners. Under 400 words. Skip Low.
If nothing found, say so — don't invent issues.

Write your complete findings to {ARTIFACTS_DIR}/round-{CURRENT_ROUND}-builder.md using the Write tool.
```

Task(subagent_type: "general-purpose", model: "{AGENT_MODEL}", description: "Builder review")

**Agent 2: Breaker ({AGENT_MODEL})**

```
First: read AGENTS.md for project context.

You are an adversary and architect critic. You compete with 2 other reviewers — only evidence-backed findings count. What breaks?

Check: silent failures (wrong results, no error), race conditions on shared state, missing error paths, wrong abstractions, tight coupling. Show the scenario: given [precondition], when [action], then [bad outcome]. Check: do new fields survive existing read-modify-write cycles?

You have codebase access. Read write paths for shared data structures. Cite specific files and functions. Skip theoretical risks — every finding needs a concrete scenario.

Limit: top 5 issues. If you have additional Critical/High, add as one-liners. Under 400 words. Skip Low.
If nothing found, say so — don't invent issues.

Write your complete findings to {ARTIFACTS_DIR}/round-{CURRENT_ROUND}-breaker.md using the Write tool.
```

Task(subagent_type: "general-purpose", model: "{AGENT_MODEL}", description: "Breaker review")

**Agent 3: Trimmer ({AGENT_MODEL})**

```
First: read AGENTS.md for project context.

You are a simplifier and devil's advocate. You compete with 2 other reviewers — only evidence-backed findings count. What to cut, and is this the right approach?

Check: what can be deleted without losing core value, what's built for v3 but not needed now, where abstraction adds overhead without reuse, whether a fundamentally simpler approach achieves 90% of the value at 30% of the cost. If a fundamentally simpler approach exists, that's your highest-priority finding.

You have codebase access. Verify claimed constraints are real, not assumed. Your only verbs: remove, defer, inline, collapse. Challenge the approach itself — not just the details.

Limit: top 5 issues. If you have additional Critical/High, add as one-liners. Under 400 words. Skip Low.
If nothing found, say so — don't invent issues.

Write your complete findings to {ARTIFACTS_DIR}/round-{CURRENT_ROUND}-trimmer.md using the Write tool.
```

Task(subagent_type: "general-purpose", model: "{AGENT_MODEL}", description: "Trimmer review")

#### Heavy Personas (Heavy tier only — spawn these INSTEAD of simple personas)

**Agent 1: Architect (Opus)**

```
First: read AGENTS.md for project context.

You are a systems architect. You compete with 5 other reviewers -- only evidence-grounded findings matter.

Explore the plan's architecture with fresh eyes. Trace 2-3 key data flows end-to-end through actual source files. Look for structural flaws — wrong abstractions, misplaced responsibilities, tight coupling, dependency direction issues, integration boundaries. But trust your architectural intuition and follow whatever threads interest you.

You have codebase access. Read actual source files to verify the plan's claims. If the plan says "X calls Y", open both files and confirm. For each finding: what you checked, what you found, why it's a problem.

Limit: top 5 issues. Under 400 words. Skip Low.
If nothing found, say so — don't invent issues.

Write your complete findings to {ARTIFACTS_DIR}/round-{CURRENT_ROUND}-architect.md using the Write tool.
```

Task(subagent_type: "general-purpose", model: "opus", description: "Architect review")

**Agent 2: Adversary (Opus)**

```
First: read AGENTS.md for project context.

You are an adversarial reviewer. Your job is to BREAK this plan. You compete with 5 other reviewers -- only real, demonstrable breaks count.

Your job is to break this plan. Flip every assumption and see if the plan survives. Explore write paths to shared data structures, trace auth flows, look for silent failures and race conditions. But don't limit yourself — if you find a way to break it that isn't in any checklist, that's your best finding.

You have codebase access. Read the actual code to verify claims. Cite specific files and functions. Show the scenario: given [precondition], when [action], then [bad outcome].

Limit: top 5 issues. Under 400 words. Skip Low.
If nothing found, say so — don't invent issues.

Write your complete findings to {ARTIFACTS_DIR}/round-{CURRENT_ROUND}-adversary.md using the Write tool.
```

Task(subagent_type: "general-purpose", model: "opus", description: "Adversary review")

**Agent 3: Devil's Advocate (Opus)**

```
First: read AGENTS.md for project context.

You are a Devil's Advocate. Argue AGAINST this plan's fundamental approach -- not details, but core design decisions. Your strongest finding proves a foundational assumption is false.

Check: inversion test (for each major decision, argue the opposite), hidden constraints (are stated constraints actually real?), simpler alternatives (90% value at 30% cost?), assumption mapping (which beliefs are unvalidated?).

You have codebase access. Read referenced plans and actual code to verify claimed constraints are real, not assumed. Be intellectually honest -- if the approach is genuinely best, say so, then find the ONE thing it got wrong.

Limit: top 5 issues. Under 400 words. Skip Low.
If nothing found, say so — don't invent issues.

Write your complete findings to {ARTIFACTS_DIR}/round-{CURRENT_ROUND}-devils-advocate.md using the Write tool.
```

Task(subagent_type: "general-purpose", model: "opus", description: "Devil's Advocate review")

**Agent 4: Implementer (Opus)**

```
First: read AGENTS.md for project context.

You are implementing this plan tomorrow. You compete with 5 other reviewers -- only implementation-blocking findings count.

Check: blocking ambiguity (steps where you'd guess), hidden complexity (looks like 1 day but is 5), wrong sequencing, missing ownership (each new field/function/route owned by exactly ONE phase), practical shortcuts.

You have codebase access. Read EVERY file the plan references. Verify functions, types, utilities exist with claimed signatures. For each issue: quote the plan's claim, show what the code actually has, state what's needed.

Limit: top 5 issues. Under 400 words. Skip Low.
If nothing found, say so — don't invent issues.

Write your complete findings to {ARTIFACTS_DIR}/round-{CURRENT_ROUND}-implementer.md using the Write tool.
```

Task(subagent_type: "general-purpose", model: "opus", description: "Implementer review")

**Agent 5: Spec Auditor (Opus)**

```
First: read AGENTS.md for project context.

You are a specification completeness auditor. If you'd need to ask a question to implement it, that's a finding.

Check: gaps (trace each phase's inputs -- does a prior phase produce them?), contradictions (where do two sections disagree?), undefined behavior, phase ownership (every deliverable owned by exactly one phase), self-sufficiency (could someone implement with ONLY this document?).

You have codebase access. For each referenced function, type, or factory -- read the source. Verify it exists, is exported, has the claimed signature.

Limit: top 5 issues. Under 400 words. Skip Low.
If nothing found, say so — don't invent issues.

Write your complete findings to {ARTIFACTS_DIR}/round-{CURRENT_ROUND}-spec-auditor.md using the Write tool.
```

Task(subagent_type: "general-purpose", model: "opus", description: "Spec Auditor review")

**Agent 6: Simplifier (Opus)**

```
First: read AGENTS.md for project context.

You are a ruthless simplifier. Your only job: find what to CUT. If total complexity budget is 100, where is it being wasted?

Check: remove (delete without losing core value?), defer (built for v3 but not needed now?), inline (abstraction overhead without reuse?), collapse (merge multiple steps/phases?), complexity budget.

DO NOT suggest adding anything. Your only verbs: remove, simplify, defer, inline.

Limit: top 5 issues. Under 400 words. Skip Low.
If nothing found, say so — don't invent issues.

Write your complete findings to {ARTIFACTS_DIR}/round-{CURRENT_ROUND}-simplifier.md using the Write tool.
```

Task(subagent_type: "general-purpose", model: "opus", description: "Simplifier review")

### Phase 3: Synthesize and Apply

**THIS IS YOUR CORE WORK. Do not delegate synthesis.**

Read findings from files (all agents in parallel):

**Light/Medium:** Read builder, breaker, trimmer findings.
**Heavy:** Read architect, adversary, devils-advocate, implementer, spec-auditor, simplifier findings.

Synthesis principles:

- **Consensus is high-signal** — 2+ agents flagging the same issue is almost certainly real
- **Evidence over opinion** — cite file paths, not vague concerns
- **Simplifier/Trimmer counterbalances** — other agents tend to add; Trimmer/Simplifier cuts
- **Devil's Advocate + Simplifier agreement** (heavy) — strongest signal to cut/change
- **Critical/High first** — skip Medium unless trivial to fix

Produce a numbered change list. For each item: target section, what to change, new content, severity, and which agents flagged it.

### Auto-Apply Rules (DO NOT ask about these)

**Auto-apply a change if ANY condition is met:**

1. **Severity-based:** The issue is Critical or High severity — these are defects, not preferences
2. **Same-round consensus:** 2+ agents independently flagged the same issue (regardless of severity) — multi-agent agreement is high-signal
3. **Cross-round consensus:** A single-agent finding from THIS round matches a deferred finding in the consensus registry from a PREVIOUS round — recurrence across rounds is high-signal

**Apply these immediately using the Edit tool. Log them in the round summary as "Auto-applied" with the consensus type.**

### Design Decision Gate (applies before all auto-apply rules)

If a finding represents a choice with no objectively superior technical answer, resolve it yourself — pick the better option. Only tag as `DESIGN_DECISION` and defer if the decision would **noticeably affect the end-user experience** or **profoundly change the development approach**. Minor design choices (spacing, naming, style) — just pick the better option and auto-apply. `DESIGN_DECISION` items are deferred regardless of severity or consensus — they skip the registry and go directly to the user in Phase 5.

### Defer Remaining Findings (DO NOT ask user per-round)

After auto-applying, any remaining changes (Medium/Low severity AND only flagged by a single agent with no cross-round match) are added to the consensus registry — NOT presented to the user.

For each deferred finding, append to `$ARTIFACTS_DIR/consensus-registry.md`:

```markdown
| {CURRENT_ROUND} | {agent role} | {severity} | {one-line summary} | {plan section} |
```

These deferred findings serve two purposes:
- **Cross-round consensus detection:** If a later round's agent flags the same issue, it auto-applies
- **Final presentation:** Any findings that never achieve consensus are presented to the user once in Phase 5

**After applying edits, append a round summary to the plan file:**

```markdown
<!-- Append to end of PLAN_FILE. Create "## Refinement Log" heading if it doesn't exist. -->

### Round {CURRENT_ROUND} ({TIER}: {PERSONA_NAMES})

- **Changes:** {count} applied ({Critical count} Critical, {High count} High)
- **Key fixes:** {1-2 sentence summary of main changes}
- **Consensus:** {notable agreements or disagreements between agents}
- **Trajectory:** {assessment} -> {continue|finalize}
```

### Phase 4: Convergence Check

**First, record an explicit convergence verdict for this round** — don't just run to MAX_ROUNDS. Score the magnitude of *this round's applied changes*:

- **major** — a structural change (approach, phase ordering, a new risk that reshapes the plan). **Resets** the convergence count — the plan is still moving.
- **minor** — sharpening, added detail, small corrections.
- **cosmetic** — wording, formatting.

Log `convergence: {major|minor|cosmetic}` in the round entry. The plan has **steadied** when two consecutive rounds are minor-or-cosmetic with no open Critical/High — improvements are now marginal and further rounds burn tokens without changing the plan.

**Rule 1 (severity gate — overrides early-stop): if this round's agents found ANY Critical or High issues, you MUST run another round after applying fixes.** Fixes are unverified until the next round confirms no new Critical/High emerge.

**Rule 2 (the round floor): the `MIN_ROUNDS=2` floor is ABSOLUTE.** The major/minor/cosmetic
trend itself needs at least one later round in which the plan can prove it has actually
steadied, not just gone quiet once. A minor-or-cosmetic round 1 is not evidence the plan is
done; it is evidence one round isn't enough to tell. **One round is not sufficient** — even a
minor-or-cosmetic round 1 does NOT finalize before round 2; the "steadied" early exit is only
reachable once `CURRENT_ROUND >= MIN_ROUNDS`. Ceiling is each tier's `MAX_ROUNDS` (4 for
light/medium, 6 for heavy).

```
# The floor is checked FIRST and is absolute — nothing exits before MIN_ROUNDS=2.
IF CURRENT_ROUND < MIN_ROUNDS -> apply fixes, continue (increment CURRENT_ROUND)   # even on a minor/cosmetic-only round
IF two consecutive rounds are minor/cosmetic AND no Critical/High (only reachable at CURRENT_ROUND >= MIN_ROUNDS) -> finalize (converged — proceed to Phase 5)
IF agents found any Critical or High issues -> apply fixes, continue (increment CURRENT_ROUND, loop to Phase 1)
IF 3+ Medium issues across agents -> continue
IF only few Medium or no issues -> finalize (proceed to Phase 5)
IF CURRENT_ROUND >= MAX_ROUNDS -> force finalize (note unverified fixes in Refinement Log)
```

---

## Phase 5: Finalize

### Conductor Final Review (Triage)

Read the consensus registry. Collect all remaining items:

1. **No-consensus findings:** Single-agent findings that never recurred across rounds
2. **DESIGN_DECISION items:** Findings deferred during rounds as genuine design decisions

**If nothing remains:** Skip — just proceed to commit.

**Classify each remaining no-consensus finding:**

| Category | Criteria | Action |
|---|---|---|
| `AUTO_IMPLEMENT` | There is a clearly superior technical answer — better correctness, robustness, performance, or maintainability. The improvement is unambiguous. | Implement it now. |
| `DESIGN_DECISION` | No objectively superior answer AND the choice would **noticeably affect the end-user experience** or **profoundly change the development approach**. Minor design choices (spacing, naming, style) — just pick the better option and classify as `AUTO_IMPLEMENT`. | Defer to user. |
| `SCOPE_ESCALATION` | A technically superior option exists but requires profound structural change that constitutes a strategic commitment. | Defer to user with scope context. |

**Default bias: `AUTO_IMPLEMENT`.** Most findings have a correct answer — pick it.

**Apply all `AUTO_IMPLEMENT` items using the Edit tool.** Log each with rationale.

### Present Decisions to User (if any)

**If no `DESIGN_DECISION` or `SCOPE_ESCALATION` items remain:** Skip — proceed to commit.

**If items remain:**

```
AskUserQuestion(
  questions: [{
    question: "Auto-applied {N} fixes (severity + consensus + technical triage). {M} items need your decision:",
    header: "Decisions",
    multiSelect: true,
    options: [
      { label: "Change X: <title>", description: "DESIGN_DECISION — Round {R}, {severity} — {agent}: {section} — {one-line summary}" },
      { label: "Change Y: <title>", description: "SCOPE_ESCALATION — {severity} — {agent}: {section} — {one-line summary}. Scope: {what it entails}" }
    ]
  }]
)
```

**If more than 4 items:** Split across multiple `AskUserQuestion` calls.

**Apply any user-approved findings using the Edit tool.**

### Update Plan Frontmatter

Update the YAML frontmatter at the top of the plan file to reflect refinement state:

```yaml
---
status: refined
refinement_rounds: {CURRENT_ROUND}
refinement_tier: {TIER}
---
```

Preserve all other existing frontmatter fields (`source_backlog`, `approved_at`, etc.).

### Safety Check and Commit

```bash
git status --short
# If ANY deletions (D): STOP and confirm with user

git add "$PLAN_FILE"
git commit -m "docs(plan): {TIER} multi-agent refinement - {CURRENT_ROUND} rounds complete

Plan: {PLAN_FILE}
Tier: {TIER} ({AGENT_COUNT}x {AGENT_MODEL})
Rounds: {CURRENT_ROUND}

Co-Authored-By: Claude <noreply@anthropic.com>"
git push
```

### Cleanup

Remove the temp artifacts directory once the commit is done:

```bash
# Remove temp findings from /tmp (safe -- ARTIFACTS_DIR is always under /tmp)
find "$ARTIFACTS_DIR" -mindepth 1 -delete && rmdir "$ARTIFACTS_DIR" 2>/dev/null || true
```

### Release Active Work Signal (Agent Mail)

> **Same token-carry as the reserve step:** always pass the captured `registration_token`
> (`release_file_reservations`) / `sender_token` (`send_message`) — do not rely on same-session carry (`ac-g93`).

**Release reservation:**

```
mcp__mcp-agent-mail__release_file_reservations(
  project_key: CANONICAL_PROJECT_KEY,   // canonical "neometa/<app-dir>" key — key-format + never-absolute rule: agent-mail/references/agent-identity.md § Project key format
  agent_name: <session agent name>,
  paths: [PLAN_REL]
)
```

**Broadcast DONE signal:**

```
mcp__mcp-agent-mail__send_message(
  project_key: CANONICAL_PROJECT_KEY,   // canonical "neometa/<app-dir>" key — key-format + never-absolute rule: agent-mail/references/agent-identity.md § Project key format
  sender_name: <session agent name>,
  to: [<session agent name>],
  subject: "DONE: plan-refine-internal — {PLAN_REL}",
  body_md: "Completed `plan-refine-internal` on `{PLAN_REL}` ({CURRENT_ROUND} rounds, {TIER} tier).",
  topic: "pipeline-wip"
)
```

### Summary

```markdown
## Plan Refinement Complete ({TIER})

**Plan:** {PLAN_FILE}
**Tier:** {TIER} ({AGENT_COUNT}x {AGENT_MODEL})
**Rounds:** {CURRENT_ROUND}

### Convergence

Round  Crit  High  Med   Total  Applied  Deferred
  1     {n}   {n}   {n}   {n}     {n}       {n}
  2     {n}   {n}   {n}   {n}     {n}       {n}
  ...

R1  {▓▓░░░████}  {total}
R2  {░████}      {total}  {-N%}
R3  {██}         {total}  {-N%}

▓ Critical  ░ High  █ Medium

### Resolution

Found: {total} across {CURRENT_ROUND} rounds
  ├─ Auto-applied (severity):      {n}  {bars}
  ├─ Auto-applied (same-round):    {n}  {bars}
  ├─ Auto-applied (cross-round):   {n}  {bars}
  ├─ Auto-implemented (conductor):  {n}  {bars}
  ├─ User-approved:                {n}  {bars}
  └─ Discarded (no consensus):     {n}  {bars}

### Top Agent Contributions

- **{agent}:** {key finding pattern}
- **{agent}:** {key finding pattern}

**Stop reason:** {severity converged | MAX_ROUNDS | clean round}
```

**Present next step choice with `AskUserQuestion`:**

```
AskUserQuestion(
  questions: [{
    question: "Plan refinement complete ({CURRENT_ROUND} rounds, {TIER} tier). Mark as loop-ready?",
    header: "Loop-ready?",
    multiSelect: false,
    options: [
      { label: "Loop-ready — run plan-clean first (Recommended)", description: "Run /ac-plan-clean correctness check next — it stamps loop-ready at its finalize" },
      { label: "Loop-ready — skip clean", description: "Mark loop-ready now — the sign-off /ac-beadify's status gate accepts; run /ac-beadify on it when ready (nothing auto-consumes loop-ready plans)" },
      { label: "External multi-model refine", description: "Run /ac-plan-refine-external — multiple diverse AI models for deeper review before deciding" },
      { label: "Done for now", description: "Plan saved as 'refined' — mark loop-ready later when you're ready" }
    ]
  }]
)
```

**If user chose "Loop-ready — skip clean":** update the plan frontmatter and commit. (With
"run plan-clean first", leave status `refined` — `/ac-plan-clean` stamps loop-ready at its
finalize; stamping before the clean would sign off an unchecked document.)

```bash
# Update status to loop-ready (the sign-off /ac-beadify's status gate accepts)
# Edit the plan file's YAML frontmatter: status: loop-ready
git add "$PLAN_FILE"
git commit -m "docs(plan): mark loop-ready

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Remember

- YOU synthesize and apply edits directly — never delegate synthesis or spawn subagents for edits
- **Auto-apply Critical/High + same-round consensus + cross-round consensus — defer the rest**
- **Cross-round consensus:** single-agent findings that recur in later rounds are high-signal — auto-apply on match
- **Conductor triage before user** — remaining items get a final review: auto-implement clear technical improvements, only defer genuine design decisions (user-visible or development-transformative) and scope escalations to the user
- **Design decision gate every round** — choices that noticeably affect user experience or profoundly change development are deferred regardless of severity or consensus
- Trimmer/Simplifier counterbalances other agents — don't let them pile on complexity
- Evidence over opinion — findings need file citations, not speculation
- **Refinement checks codebase AND pipeline** — agents should flag conflicts or sequencing issues with other plans in `_plans/` and unimplemented beads (`br list`), not just existing code
- Findings files + consensus registry in ARTIFACTS_DIR persist through compaction — always read from files, not memory
- Refinement Log in plan file is your compaction recovery — parse it to know where you left off

---

_3-tier plan refinement (light/medium/heavy). For external multi-model: `/ac-plan-refine-external`._
