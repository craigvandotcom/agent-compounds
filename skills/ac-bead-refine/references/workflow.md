
**You are the conductor.** Three reviewers hunt independently. You synthesize, apply fixes, and iterate. Competitive framing: agents compete — only evidence-backed findings count.

---

## I/O Contract

|                  |                                                                                                  |
| ---------------- | ------------------------------------------------------------------------------------------------ |
| **Input**        | Open beads in `br` (from `/ac-beadify` or any other source). Scope, in precedence order: `TARGET_BEAD_IDS` (explicit list — what a fanned-out `ac-loop` child gets) › `EPIC_ID` › whole board |
| **Output**       | Refined beads ready for `/ac-implement` — **only ever the beads in `$ARTIFACTS_DIR/target-bead-ids.txt`** |
| **Artifacts**    | `$ARTIFACTS_DIR` is keyed **per child** (`/tmp/bead-refine-<agent>-<pid>[-<run-id>]`), never per run — siblings share a RUN_ID by design. Target list in `$ARTIFACTS_DIR/target-bead-ids.txt`, round findings in `$ARTIFACTS_DIR/round-{N}-{role}.md`, progress in `$ARTIFACTS_DIR/progress.md` |
| **Verification** | `br list --json`, `br dep cycles`, `br lint`, `br ready --json`                                  |

## Prerequisites

- At least one open bead exists in `br`
- beads_rust (`br`) and beads_viewer (`bv`) installed — verify with `which br && which bv`

## Phase 0: Initialize

**MANDATORY FIRST STEP: declare the run ledger (`ac-pipeline/references/run-ledger.md` — one task per section, advance as you go) with TaskCreate BEFORE starting.**

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
```

### Configuration

```
CURRENT_ROUND=1
MIN_ROUNDS=3          # ABSOLUTE floor — cross-round consensus needs recurrence opportunities; never finalize before this, even on consecutive zero-finding rounds
MAX_ROUNDS=5
```

#### `$ARTIFACTS_DIR` is keyed per-CHILD, never per-run (bd-baudw)

<!-- mirror: ac-pipeline/references/delegation-contract.md § Child-spawn preamble -- edit there first -->

**Conductor: paste the block below VERBATIM at the head of EACH of the three `Task(...)`
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

This skill is **fanned out**: `ac-loop` at `PARALLEL_WIDTH>1` spawns several
`ac-bead-refine` children on disjoint bead subsets, and by design hands every one of them
the **same `RUN_ID`** (RUN_ID identifies the loop *run*, not the child — `ac-loop/SKILL.md`
Phase 0 mints exactly one). It also hands them the same claim/batch id when there is one.
So **neither `RUN_ID` nor the claim id can separate siblings** — keying the dir on either
collapses N children onto one directory, where they clobber each other's
`beads-snapshot.json` and each other's round findings, silently, last-writer-wins. That
was a live, reproduced bug (two disjoint snapshots written in the same clock second),
and it made a child stamp `refined` onto beads it never reviewed.

The key is therefore a **child discriminator computed by the child itself**:

```bash
# 1. RUN_ID — the orchestrator's run scope; mint-if-absent per ac-pipeline/references/run-id.md.
#    Shared across siblings ON PURPOSE. It scopes, it does not discriminate.
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-$$}"

# 2. CHILD_ID — this child's OWN key. ALWAYS computed right here; NEVER read from the
#    environment and NEVER accepted from the delegation prompt, so a caller-supplied
#    RUN_ID (or an inherited CHILD_ID) cannot override it. Two independent
#    discriminators, deliberately — defence in depth on the same mechanism:
#      AGENT_NAME → this child's Agent Mail identity; distinct per child by the two-tier
#                   contract (agent-mail/references/agent-identity.md) and stable across compaction
#      $$         → this shell's PID; distinct even when AGENT_NAME is unset or duplicated
unset CHILD_ID 2>/dev/null || true
CHILD_ID="$(printf '%s' "${AGENT_NAME:-anon}" | command tr -cd 'A-Za-z0-9')-$$"

# 3. /tmp/<prefix>-<key>[-<run-id>] — the ac-pipeline/references/run-id.md invariant, key = CHILD_ID.
#    RUN_ID stays LAST so a run-scoped glob (/tmp/bead-refine-*-$RUN_ID) still gathers
#    every child of this run for ac-land.
ARTIFACTS_DIR="/tmp/bead-refine-${CHILD_ID}${RUN_ID:+-$RUN_ID}"
mkdir -p "$ARTIFACTS_DIR"
printf '%s\n' "$CHILD_ID" | tee "$ARTIFACTS_DIR/.child-id" >/dev/null
echo "ARTIFACTS_DIR=$ARTIFACTS_DIR"   # ← copy this RESOLVED LITERAL; see below
```

**Resolve once, then reuse the literal — never re-derive.** Every later bash call is a
fresh shell with a **different `$$`**, so re-running the formula would compute a *new*
directory and orphan this run's scratch. Immediately after the block above: paste the
resolved literal path into the Phase-0 `TaskCreate("Initialize …")` description and into
the `progress.md` header, and set `ARTIFACTS_DIR=<that literal>` at the top of every
subsequent bash call. This is the same discipline `ac-pipeline/references/run-id.md` already mandates for
the claim id ("recover it from the `.claim-id` file, or from a TaskCreate description that
baked in the literal resolved path").

**Never work around a collision by hand-suffixing `RUN_ID`** (`…-refineA` / `…-refineB` in
the delegation prompt). That workaround was needed before this key existed; it is now both
unnecessary and harmful — it breaks the `-$RUN_ID` glob ac-land uses to gather the run.
The safety lives in `CHILD_ID`, not in the prompt, so the prompt passes `RUN_ID` bare.

Proof: `bash skills/ac-pipeline/scripts/bead-refine-concurrent-dir.test.sh`.

#### dcg-safe writes (fully-literal redirect targets only)

The destructive-command-guard hook rule `core.filesystem:redirect-truncate-dynamic-path`
**blocks any `>` redirect whose target path is built from a variable** — and
`$ARTIFACTS_DIR` is necessarily a variable now that it carries a per-child discriminator,
so a literal `/tmp/...` redirect target is impossible to write down in advance. Every
truncating write below therefore goes through **`tee <path> >/dev/null`**: the path is an
*argument* (not a redirect target) and the only redirect is the fully-literal `/dev/null`.
Verified with `dcg test`: the `>` form is BLOCKED, the `tee` form is ALLOWED — including
inside a multi-statement compound command — and `>>` (append) is ALLOWED. **Do not "simplify"
these back to `>` — they will not run.**

A refused block is almost never the `tee` lines. The verdict is whole-command: one
non-compliant statement blocks every statement sent with it. Find that statement instead of
rewriting the `tee` calls. Assign and use `$ARTIFACTS_DIR` in the SAME bash call, and recover
it from `.claim-id` rather than re-deriving it. Diagnosis and every sanctioned shape:
`ac-pipeline/references/shell-guardrails.md` § What actually gets blocked.

### Initialize Consensus Registry

```bash
tee "$ARTIFACTS_DIR/consensus-registry.md" >/dev/null <<'EOF'
# Consensus Registry

Tracks single-agent findings across rounds. If a finding recurs in a later round, it achieves cross-round consensus and is auto-applied.

## Deferred Findings

<!-- Format: | Round | Agent | Severity | Bead | Summary | -->
EOF
```

### Compaction Recovery

Recover `ARTIFACTS_DIR` **first**, from the literal recorded in the Phase-0 task
description / `progress.md` header (never by re-deriving — `$$` has changed). Then: if
`$ARTIFACTS_DIR/progress.md` exists, parse the last `### Round N` entry to recover `CURRENT_ROUND` (set to N+1). Previous rounds' changes are already applied to beads. Read any existing findings files in `$ARTIFACTS_DIR` for context on the most recent round. If `$ARTIFACTS_DIR/consensus-registry.md` exists, read it to recover the deferred findings pool for cross-round consensus detection. `$ARTIFACTS_DIR/target-bead-ids.txt` (below) survives too — it, not the snapshot, remains the authority on what this child may stamp.

### Identify Plan File + Skills

Locate the original plan file if one exists (check `_plans/*.md`, ask user if unclear). Use it for cross-referencing during review when available; if no plan exists, proceed with bead-only review.

**Skill routing:** Read the beads (`br list --json`) and scan for domain keywords. Check `AGENTS.md` > "Available Skills" for relevant skills. Include skill paths in agent prompts.

### Gather Bead Snapshot

**Two files, and the first one is the authority.**

| file | role |
| --- | --- |
| `$ARTIFACTS_DIR/target-bead-ids.txt` | **AUTHORITATIVE.** Newline-delimited ids this child owns and may stamp. Written exactly once, here. Phase 5 stamps **this list and nothing else.** |
| `$ARTIFACTS_DIR/beads-snapshot.json` | Bead *content* for the reviewers, derived FROM that list. Convenience, never authority over scope. |

**Canonical snapshot shape (bd-lsnc0):** `beads-snapshot.json` is always
`{ "issues": [ …issue objects… ] }` — the same shape `br list --json` emits. All
downstream loops (parity gate, stamp) read **only** this file for bead content; they never
re-invoke `br show --json | jq` per id (multi-line descriptions break `jq -c '.[0]'`).

**zsh-safe array iteration:** never `for id in $UNQUOTED` (word-splits under zsh).
Build a real array via `while IFS= read -r` (portable bash 3.2 + zsh).

**zsh-safe variable names (bd-x8ios):** never assign to `status`, `path`, `argv`,
`pipestatus`, `options`, `signals`, `functions`, `commands`, or `aliases` — these are
read-only or magic-typed specials in zsh, the fleet's default shell, so the assignment
fails or silently rewrites the environment. Prefix instead (`bstatus`, `bpath`). Invisible
under bash, which is why it survived; guard: `bead-refine-concurrent-dir.test.sh` Case 5c
re-runs the stamp loop under real zsh.

Pick **exactly one** of the three scope modes below, in this precedence order.

#### Mode A — targeted (`TARGET_BEAD_IDS` set) — highest precedence

`ac-loop` fans refine children out over **disjoint subsets of unrelated beads** (orphan/bug
captures with no epic and no `parent-child` edge — `ac-loop/SKILL.md` § phase-pipelining
hookpoints (b)/(c)). Neither of the other two modes can express that subset, which is
exactly why a fanned-out child used to fall back to the whole board and then stamp beads
belonging to a sibling. When the delegation prompt supplies `TARGET_BEAD_IDS`
(newline- **or** comma-delimited), it is the scope — full stop:

```bash
TARGET_IDS=()
while IFS= read -r line; do
  [ -n "$line" ] && TARGET_IDS+=("$line")
done < <(printf '%s\n' "$TARGET_BEAD_IDS" | command tr ',' '\n' | command tr -d ' ' | grep -v '^$')

[ "${#TARGET_IDS[@]}" -gt 0 ] || { echo "FATAL: TARGET_BEAD_IDS set but empty" >&2; exit 2; }

printf '%s\n' "${TARGET_IDS[@]}" | tee "$ARTIFACTS_DIR/target-bead-ids.txt" >/dev/null

ID_FLAGS=()
for t in "${TARGET_IDS[@]}"; do ID_FLAGS+=(--id "$t"); done
br list --json "${ID_FLAGS[@]}" --all | tee "$ARTIFACTS_DIR/beads-snapshot.json" >/dev/null
```

#### Mode B — epic-scoped (`EPIC_ID` set)

Caller says "scoped to that epic" (e.g. from `ac-hygiene` or `ac-triage`'s per-run epic):
scope is the epic + its `parent-child` children. `br list --json` carries no
dependency-edge field, so derive the child set via `dep list`:

```bash
EPIC_ID=<the epic bead id>
CHILD_IDS=()
while IFS= read -r line; do
  [ -n "$line" ] && CHILD_IDS+=("$line")
done < <(br dep list "$EPIC_ID" --direction up -t parent-child --json | jq -r '.[].issue_id')

TARGET_IDS=("$EPIC_ID" "${CHILD_IDS[@]}")
printf '%s\n' "${TARGET_IDS[@]}" | tee "$ARTIFACTS_DIR/target-bead-ids.txt" >/dev/null

ID_FLAGS=()
for t in "${TARGET_IDS[@]}"; do ID_FLAGS+=(--id "$t"); done
br list --json "${ID_FLAGS[@]}" --all | tee "$ARTIFACTS_DIR/beads-snapshot.json" >/dev/null
```

#### Mode C — whole board (no `TARGET_BEAD_IDS`, no `EPIC_ID`)

The standalone/human default. **Only ever correct when this is the sole refine session in
flight** — if a conductor fanned you out and you land here, stop and ask for
`TARGET_BEAD_IDS` rather than claiming the whole board out from under your siblings.

```bash
br list --json --limit 1000 | tee "$ARTIFACTS_DIR/beads-snapshot.json" >/dev/null
jq -r '.issues[].id' "$ARTIFACTS_DIR/beads-snapshot.json" \
  | tee "$ARTIFACTS_DIR/target-bead-ids.txt" >/dev/null
```

#### Common to all three modes

```bash
# Dependency health
br dep cycles

# Full bead details for agent context — driven off the AUTHORITATIVE target list
IDS=()
while IFS= read -r line; do
  [ -n "$line" ] && IDS+=("$line")
done < "$ARTIFACTS_DIR/target-bead-ids.txt"

# NOTE: append via `tee -a`. `dcg` blocks a TRUNCATING redirect whose target path is
# variable-built (an APPEND redirect, brace-group included, probes ALLOWED under dcg 0.6.7 —
# `ac-pipeline/references/shell-guardrails.md`); the truncating init write on the line below was
# the single highest-recurrence instance of that block in the registry (3 of 4 refine children
# in one run, ~2 min + 2 retries each). `tee -a` remains the recommended shape here. Do NOT
# "fix" a block by decorating the command — sanctioned shapes: `ac-pipeline/references/shell-guardrails.md`.
printf '' | tee "$ARTIFACTS_DIR/beads-full-dump.txt" >/dev/null
for id in "${IDS[@]}"; do
  {
    echo "=== Bead $id ==="
    br show "$id"
    br comments "$id"
    echo ""
  } | tee -a "$ARTIFACTS_DIR/beads-full-dump.txt" >/dev/null
done

echo "SCOPE: ${#IDS[@]} bead(s) — $(command tr '\n' ' ' < "$ARTIFACTS_DIR/target-bead-ids.txt")"
```

Everything downstream (reviewer prompts, convergence, the final `refined`-stamp loop)
operates over this scope and no wider.

### Create Workflow Tasks (run ledger)

**One task per major section — the ledger exists for CLARITY + ACCOUNTABILITY**, so every
section you'd report on gets its own line (not a 3-phase skeleton). Create the fixed tasks
below at Phase 0; **ADD a "Round N" task at the start of each review round** (rounds are
dynamic — 3 floor, up to 5 — so the ledger grows to the real shape instead of pre-committing
to a round count or showing phantom rounds). `TaskUpdate` each to `in_progress` when you start
it and `completed` when done; put live detail in the description (per round: finding +
applied counts), so a glance at the ledger shows exactly where the run is.

```
# Fixed tasks — create upfront at Phase 0:
TaskCreate("Initialize — snapshot beads + dep-cycle check")
TaskCreate("Conductor triage — classify no-consensus + design-decision items")
TaskCreate("Present decisions to user")
TaskCreate("Stamp labels — remove unrefined, add refined")
TaskCreate("Verify structure — dep cycles, lint, ready")
TaskCreate("Report + handoff")

# Per-round task — create ONE as each round begins (not upfront):
TaskCreate("Round {N} — 3 reviewers → synthesize → apply → converge")
# On completion, TaskUpdate its description: "{C}/{H}/{M} findings, {n} applied, {n} deferred"
```

With a 3-round run that's 9 tasks; a 5-round run, 11. **TaskUpdate("Initialize", in_progress)**
now, and mark it `completed` at the end of Phase 0. **Bake the resolved literal
`ARTIFACTS_DIR` and the target-bead list into the "Initialize" task's description** — that
is the compaction-proof record of which dir and which beads are this child's (`$$` is gone
by the next bash call). This ledger tracks bead-refine's top-level
sections only — keep it ~6 fixed + rounds.

---

## REFINEMENT LOOP: Phases 1-4

### Phase 1: Spawn 3 Reviewers (parallel)

**All 3 agents in a single message for parallel execution.** Each agent writes findings to `$ARTIFACTS_DIR/round-{CURRENT_ROUND}-{role}.md`.

**Agent 1: Completeness Reviewer**

```
Task(subagent_type: "general-purpose", model: "sonnet", prompt: """
First: read AGENTS.md for project context, coding standards, and conventions.
{If relevant skills identified: "Read the relevant skill file for domain patterns (see AGENTS.md > Available Skills)."}

You are a completeness auditor. You compete with 2 other reviewers — only evidence-backed findings count.

## Your Task

Cross-reference every bead against the original plan (if available) to ensure NOTHING was lost or oversimplified. If no plan exists, audit beads for self-containment and completeness.

## Method

Read ALL beads ({paste ARTIFACTS_DIR/beads-full-dump.txt or inline}). If a plan file exists ({PLAN_FILE}), cross-reference plan sections against the beads — check that nothing was lost, oversimplified, or omitted. If no plan file is available, focus on bead-only completeness: missing acceptance criteria, missing edge cases, gaps in implementation context. **Visual-reference ACs:** if the source research doc/plan cites a `docs/design-refs/<surface>-<source>-reference.<ext>` image, check the bead's ACs against it directly — including geometry (shape, radius, spacing), not just prose intent; a bead whose AC dropped or paraphrased the reference's geometry is a finding, and a UI bead derived from a visual reference with no `docs/design-refs/` path in its ACs is a finding. Either way, check each bead for self-containment: could an engineer implement it without external context? **Name AND EXECUTE the check for every AC:** for each acceptance criterion, name the exact check that would verify it — the command to run, the file to grep, the test to write, the output to compare. Any AC you cannot name a concrete check for is a finding (verified-by-reading is not verified). **Then RUN it.** An AC that encodes a command must have that command executed against HEAD this round; a command that errors, targets a non-existent script/target, or cannot run is a finding — fix the AC or drop it, never stamp it. Verifying an AC's INTENT is not a substitute for running its literal check: two ACs shipped with commands that were wrong at HEAD (a non-existent capacitor build target; a `grep -c` line-count assertion every 404 in the app fails) because refine judged intent and never executed them — the same wrong build command then produced three separate false blockers (bd-g277q). Cost to disprove once actually run: ~5 minutes each. If an AC's command is genuinely unrunnable here (needs prod, a device, or a human), say so explicitly in the AC — an unrunnable check must be *labelled* unrunnable, never left looking executable. Named test anchors (files, describe blocks) must exist — grep before citing. **Seam-proof AC for bridge-crossing beads:** if a bead's scope crosses a bridge (native plugin boundary, external service, build-time↔runtime divide, **or any two-component seam INSIDE one runtime — write path↔read path, producer↔consumer, install↔serve**), tests-green alone is not done — it needs a seam-proof acceptance criterion: the named surface observed working (a journey drive, or an un-mocked test touching the seam itself). A bridge-crossing bead with no seam-proof AC is a finding. This is `ac-pipeline/references/anti-patterns.md` §3 *Unproven seam* — "mocks verify our logic; the bugs live at the boundary the mock removed" — and the boundary does not have to be a process boundary: bd-mfr1d (2026-07-30) wrote an asset into one cache while the serving path only ever opened a different one, both halves individually covered and green. So the AC must name a check that goes RED when EITHER side alone is reverted; two ACs each covering one half is the untested seam, not coverage. Use your judgment on what matters most.

## Output

Write findings to {ARTIFACTS_DIR}/round-{CURRENT_ROUND}-completeness.md

For each issue:
## Issue N: Title
**Severity:** Critical | High | Medium
**Bead:** <id> (or "Missing bead")
**Evidence:** What the plan says vs what the bead says (or doesn't)
**Fix:** Specific change — new bead, updated description, added acceptance criteria

Limit: top 5 issues. If additional Critical/High, add as one-liners. Under 500 words. Skip Low.
If nothing found, say so — don't invent issues.
""")
```

**Agent 2: Implementability Reviewer**

```
Task(subagent_type: "general-purpose", model: "sonnet", prompt: """
First: read AGENTS.md for project context, coding standards, and conventions.
{If relevant skills identified: "Read the relevant skill file for domain patterns (see AGENTS.md > Available Skills)."}

You are an implementer auditing these beads. You compete with 2 other reviewers — only implementation-blocking findings count.

## Your Task

Can an engineer cold-start on each bead tomorrow and implement it mechanically? If you'd need to ask a question, that's a finding.

## Method

Read ALL beads ({paste ARTIFACTS_DIR/beads-full-dump.txt or inline}) and put yourself in the implementer's seat. For each bead: could you cold-start on it tomorrow and build it mechanically? If you'd need to ask a question, that's a finding. Check scope clarity, dependency correctness, granularity, and whether you could write RED tests from just the acceptance criteria. You have codebase access — read referenced files to verify functions, types, and patterns actually exist as described. **Verify test file paths against the project test-directory map (AGENTS.md):** if a bead specifies a test file path, validate the directory matches the project's split before approving. Verify integration-test paths against the project's AGENTS.md — apps split test directories differently; never assume a layout. Verify file existence too — if the bead claims a file does or doesn't exist, check it. Incorrect spec paths cost ~5 min/bead in conductor pre-flight. Use your judgment on what blocks implementation.

**Verify the data-producer/consumer CHAIN, not just named artifacts.** Confirming a type/function exists and passes tests is NOT enough — when a bead's spec claims it will read, assemble, or transform data from a runtime component (a scorer, bus, accumulator, coordinator, queue, store), grep the LIVE codebase to confirm that component is actually wired into the runtime flow (producer → bus/transport → consumer), not just present as a class or passing tests in isolation. A type that exists and passes unit tests but is not plumbed into the live code path is a FALSE dependency: a spec built on it describes future state as if it were present state. Flag Critical if a bead's key acceptance criteria depend on a data source that exists only in a standalone module or test harness but is not connected to the runtime pipeline the bead runs in. Concrete cost: a 3-reviewer round certified bead bd-fsx "cold-startable" while its metrics-assembly AC depended on ScoringCore scorers that exist and pass their parity-harness (dump-formulas) tests but were never wired to the live MotionBus — the spec assumed the checkpointer accumulated metrics it never receives. The false-convergence surfaced only at implement-time pre-flight and forced a mid-implement scope split (skeleton + a new aggregation bead). Trace the chain end-to-end during refine, not after.

**Verify the bead I/O contract (`beads-standards/reference/bead-conventions.md` §Bead I/O contract).** Every implementable bead carries `## Delivers` + `## Consumes`. Check three things: (1) present — a missing `## Consumes` is a finding (absence ≠ `- none`; refine authors the contract for quick-capture beads, so propose the content, don't just flag); (2) concrete — each artifact is a greppable path/table/route/symbol, not "the auth work"; (3) edge-matched — every Consumes line's blocker ID has an actual dep edge (`br dep list <id>`), and that blocker's own `## Delivers` includes the named artifact; **and bead-level only — NO epic endpoints on any `blocks` edge** (`skills/beads-standards/SKILL.md` § Sequencing & parentage, I2). A dependency edge exists exactly where a bead's `Consumes` implies one, and both ends are non-epic beads: an edge with an epic on either end is an I2 violation (a finding — propose converting it to the bead↔bead edge, or dropping it if arrival-order-only). Containment is `parent-child`; sequencing is bead-level `blocks`. A contract failure here is what ac-implement's pre-dispatch premise check would bounce later — catch it now.

**Require `discovered-from:` on finding beads (`beads-standards/reference/bead-conventions.md` § provenance).** A finding bead — anything carrying `review-finding` (from `ac-review`'s Exhaust Rule), or a `bug`/`investigation`/`task` filed by `ac-triage`/QA/a conductor as a follow-up — must carry a `discovered-from: <originating-bead-id>` field naming what surfaced it. This is a refine check the stamp gate enforces (it did NOT exist in the rubric before). An **honest `discovered-from: unknown`** passes — the point is a deliberate, recorded answer, not a fabricated lineage; withhold `refined` only when the field is absent entirely on a finding-shaped bead, and propose `unknown` if the origin genuinely can't be reconstructed.

**Enforce the present-tree rule (`beads-standards/reference/bead-conventions.md` §Binding vs advisory).** Trace every claim in the BINDING sections (ACs, Delivers/Consumes, Test Scope, Anchors, Baselines, Territory, Declared RED, Sequence + risk, repro steps) to one of exactly two anchors: something that exists in the tree NOW (grep it), or something an upstream blocker's `## Delivers` explicitly promises. A binding claim resting on anything else — the bead's own dependents, components present-but-unwired, unpromised future state — is Critical (this is the bd-fsx / l73.11 class at its root). Where you find speculative how-to sitting in a binding section, the fix is usually demotion: move it under `## Approach (advisory)`, don't delete it. Do NOT flag advisory sections for staleness — they are allowed to rot; only the binding surface is load-bearing.

**Verify the implementation contract (`beads-standards/reference/bead-conventions.md` § Implementation contract).** Every implementable bead (`task`/`feature`/`bug`) carries all six elements. Missing or fabricated (unopened anchor, reasoned count, unbounded territory, missing test-tier, vague RED, empty-diff AC) is Critical — propose the content, don't just flag; refine authors whatever capture omitted. Re-open every cited `file:line` this round. A territory touching `supabase/migrations/**`, `lib/db/**`, or any SQL/RLS/RPC/GRANT surface that does not name `supabase-integration` under `### Test-tier exposure` is a finding. Epics/decisions/investigations are exempt.

## Output

Write findings to {ARTIFACTS_DIR}/round-{CURRENT_ROUND}-implementability.md

For each issue:
## Issue N: Title
**Severity:** Critical | High | Medium
**Bead:** <id>
**Evidence:** What's ambiguous/wrong/missing, with codebase citations
**Fix:** Specific change — clearer spec, split proposal, dependency fix

Limit: top 5 issues. If additional Critical/High, add as one-liners. Under 500 words. Skip Low.
If nothing found, say so — don't invent issues.
""")
```

**Agent 3: Structure Optimizer**

```
Task(subagent_type: "general-purpose", model: "sonnet", prompt: """
First: read AGENTS.md for project context, coding standards, and conventions.

You are a dependency graph and structure optimizer. You compete with 2 other reviewers — only structural improvements backed by evidence count.

## Your Task

Optimize the bead dependency graph, ordering, and granularity. Your only verbs: split, merge, reorder, add dep, remove dep.

## Method

1. Read ALL beads: {paste ARTIFACTS_DIR/beads-full-dump.txt or inline}
2. Check dependency graph:
   - Run `br dep cycles` mentally — any cycles?
   - Are there missing dependencies? (Bead A needs code from Bead B but no dep link)
   - Are there unnecessary dependencies? (Bead A depends on B but doesn't actually need it)
   - Is the critical path optimal? Could reordering unblock more parallel work?
   - **Inverted-scope check (read the AC *text*, not just the graph):** does a bead's acceptance criteria describe state or behavior that can only exist AFTER one of its own *dependents* ships, or that is ALREADY implemented in landed code? This is a topology-invisible defect — the graph looks acyclic, but the bead is hollow as ordered. Trace each AC to the file/type that owns it (you have codebase access — grep it). If the owning code lives in a downstream bead, the dependency is **backwards**: flag Critical and propose reversing the edge + repartitioning the ACs (move the behavior-owning ACs to the bead that owns the code; strike ACs whose code already shipped). Concrete cost: l73.11 (event source) blocked l73.12 (coordinator) but l73.11's headline ACs (stale-finalise, interruptionStartedAt persistence) were owned by l73.12 or already shipped in l73.8/l73.9 — missed in the prior refine pass, surfaced only at implement-time pre-flight, and cost a mid-session dependency-reversal refinement.
   - **Commit-safety check (apply beads in dependency order):** does every bead leave the branch green + shippable? A bead that removes-before-adding, or whose commit would leave `main` broken until a *later* bead lands, is mis-sequenced → flag High and propose a reorder (add-new-before-remove-old; migrations additive-first) or a feature-flag / short-lived sub-branch escape hatch.
3. Check granularity:
   - Beads that touch >5 files or span multiple concerns -> split candidate
   - Beads that are trivial (<30 min) with no dependents -> merge candidate
   - Beads that mix backend + frontend -> split candidate
   - **Split-coverage check (interface-preserving):** any split proposal must partition the original bead's `## Delivers` across the children — name which child delivers each artifact. A deliverable that lands in no child is silently dropped scope: flag Critical. Same for epic restructures: children's combined `## Delivers` must cover the epic's.
4. Check priority assignments:
   - P0 beads should be on the critical path
   - P2 beads should genuinely be deferrable
5. Check pipeline coherence: do any other beads in the dump (other waves/epics) or plans in `_plans/` conflict with or duplicate the current bead set?

## Output

Write findings to {ARTIFACTS_DIR}/round-{CURRENT_ROUND}-structure.md

For each issue:
## Issue N: Title
**Severity:** Critical | High | Medium
**Bead(s):** <id(s)>
**Evidence:** Current structure, what's wrong, why it matters
**Fix:** Specific structural change — split into X+Y, merge A+B, add/remove dep

Limit: top 5 issues. If additional Critical/High, add as one-liners. Under 500 words. Skip Low.
If nothing found, say so — don't invent issues.
""")
```

### Phase 2: Synthesize and Apply

**THIS IS YOUR CORE WORK. Do not delegate synthesis.**

Read all 3 findings files from `$ARTIFACTS_DIR`.

Synthesis principles:

- **Consensus is high-signal** — 2+ agents flagging the same bead is almost certainly real
- **Evidence over opinion** — findings need bead IDs and specific content citations
- **Structure Optimizer counterbalances** — Completeness wants to add, Structure wants to simplify
- **Critical/High first** — skip Medium unless trivial to fix

Produce a numbered change list. For each item: target bead(s), what to change, the fix.

**Auto-apply without asking. No user approval needed per-round — the convergence loop self-corrects.**

- **Critical/High:** Apply immediately — these are defects, regardless of how many agents flagged it
- **Same-round consensus (2+ agents):** Apply immediately — multi-agent agreement is high-signal
- **Cross-round consensus:** A single-agent finding from THIS round matches a deferred finding in the consensus registry from a PREVIOUS round — recurrence across rounds is high-signal. Apply immediately.
- **Design decision gate (applies before all auto-apply rules):** If a finding represents a choice with no objectively superior technical answer, resolve it yourself — pick the better option. Only tag as `DESIGN_DECISION` and defer if the decision would **noticeably affect the end-user experience** or **profoundly change the development approach**. Minor design choices (spacing, naming, style) — just pick the better option and auto-apply. `DESIGN_DECISION` items are deferred regardless of severity or consensus — they skip the registry and go directly to the user in Phase 5.
- **Medium/Low + single-agent + no cross-round match:** Defer to consensus registry. Do NOT skip silently.

For each deferred finding, append to `$ARTIFACTS_DIR/consensus-registry.md`:

```markdown
| {CURRENT_ROUND} | {agent role} | {severity} | {bead ID} | {one-line summary} |
```

**Log all applied and deferred changes in the round summary.**

**MANDATORY — stamp a persistent corrections record ON THE BEAD before stamping `refined`.** The
round summary lives in `$ARTIFACTS_DIR/progress.md`, which is ephemeral run scratch: it is swept
at land, so once the run ends there is NO record of what refine changed. Post it to the bead too:

```bash
br comments add <id> "refine-corrections: <N>
- <premise corrected / anchor re-pointed / blocker retracted / hazard added / AC command fixed>
- ..."
```

**Write this comment even when N is 0** — `refine-corrections: 0` is the required output for a
bead refine touched but did not change. A missing comment and a clean pass must not look identical:
absence is not a value, and a silent pass is indistinguishable from a skipped one. Measured
2026-08-01: a sample of `refine-full` beads found many with **no surviving refine record at all**,
making it impossible to tell whether refine caught anything or was pure ceremony — the step that
exists to stop unverified claims could not itself be verified. Counting corrections is what makes
refine's value measurable, and therefore what makes it safe to tune later.

Use these categories so the record is countable: `premise-false` · `anchor-drift` ·
`blocker-retracted` · `hazard-added` · `ac-command-fixed` · `scope-changed` · `none`.

**Execute-at-draft gate (mandatory).** Every AC command you author
or edit is EXECUTED against its literal target BEFORE it lands in the bead — paste the
run (command + exit/output) into the `refine-corrections` comment. An AC verified by
construction is unverified: baselines come from HEAD at execution time, targets are
greps never line coordinates, and each AC must be shown able to FAIL (bite-proof) when
it is the bead's sole evidence.

**Apply approved changes using `br` commands:**

```bash
# Update bead description/spec
br update <id> --description "Revised spec..."

# Add context, reasoning, edge cases as comments
br comments add <id> "Acceptance criteria update: ..."

# Fix dependency structure
br dep add <child-id> <depends-on-id>
br dep remove <child-id> <depends-on-id>

# Adopt-when-obvious (CONVENTION — NEVER a refined-blocker; §9 = Option B). When the §3
# routing map (beads-standards/reference/bead-conventions.md § Bead routing) makes a bead's epic parent
# obvious, refine MAY adopt it into that epic — but adoption is IDEMPOTENT, not
# mutex-guarded (an in_progress lock would hijack the claim namespace). Guard it:
#   1. Adopt ONLY a bead with NO existing parent (skip if it already has a parent-child edge).
#   2. Re-check `br show <id>` IMMEDIATELY before `br dep add` (TOCTOU — a parent may have
#      landed since the scan).
#   3. Verify single-parenthood AFTER (exactly one parent-child edge; never a second).
# Missing/ambiguous routing is fine — leave the bead unparented (ac-tidy flags the
# parentage gap later). Adoption NEVER gates the `refined` stamp.
if [ -z "$(br dep list <id> --direction down -t parent-child --json | jq -r '.[].issue_id')" ]; then
  # -t parent-child is MANDATORY — br dep add defaults to -t blocks, and a blocks edge with an
  # epic endpoint is an I2 violation (the finding then reads as BLOCKED in br ready).
  br dep add -t parent-child <id> <obvious-epic-id>   # only after the re-check confirms still-unparented
fi

# Adjust priority or labels
br update <id> --priority P0
br label add <id> "new-label"

# Split a bead that's too large
# Split rule: partition the original's ## Delivers across the children — nothing
# dropped (bead-conventions §Bead I/O contract); re-point downstream beads'
# Consumes lines at the new child IDs that now own those artifacts.
# Dedup first: br list --json | grep -i "<keyword>". Set -t (task/bug/investigation).
# Split children inherit the epic's domain <origin-label>; author must set it.
# unrefined routes each child back through refinement rather than treating it as refined.
br create "Split: first half" -t <type> --parent <epic-id> --priority P0 --labels <origin-label>,unrefined --description "..."
br create "Split: second half" -t <type> --parent <epic-id> --priority P0 --labels <origin-label>,unrefined --description "..."
br dep add <second-half-id> <first-half-id>
br close <original-id>
```

### Phase 3: Round Reporting

Append to `$ARTIFACTS_DIR/progress.md`:

```markdown
### Round {CURRENT_ROUND}

- **Findings:** {count} total ({Critical} Critical, {High} High, {Medium} Medium)
- **Changes applied:** {count} ({list bead IDs + brief change description})
- **Dependencies added/removed:** {count}
- **Structural changes:** {splits, new beads, merges — or "none"}
- **Consensus areas:** {where agents agreed}
- **Trajectory:** {assessment} -> {continue|finalize}
```

### Phase 4: Convergence Check

**Rule 1: if this round's agents found ANY Critical or High issues, you MUST run another round after applying fixes.** Fixes are unverified until the next round's agents confirm no new Critical/High issues emerge.

**Rule 2 (the round floor): the `MIN_ROUNDS=3` floor is ABSOLUTE.** Cross-round consensus —
the rule that promotes recurring single-agent findings — needs at least two later rounds in
which a deferral can recur. A clean round 1 is not evidence the bead set is clean; it is
evidence one round isn't enough. **Two rounds is not sufficient** — even two consecutive
zero-finding rounds do NOT finalize before round 3; the dry-panel early exit is only reachable
once `CURRENT_ROUND >= MIN_ROUNDS`. Ceiling is `MAX_ROUNDS=5`.

```
# The floor is checked FIRST and is absolute — nothing exits before round 3.
IF CURRENT_ROUND < MIN_ROUNDS -> apply fixes, continue (increment CURRENT_ROUND)   # even on back-to-back zero-finding rounds
IF two consecutive rounds found ZERO findings (only reachable at CURRENT_ROUND >= MIN_ROUNDS) -> finalize early (panel is dry — stop burning agents)
IF agents found any Critical or High issues -> apply fixes, continue (increment CURRENT_ROUND)
IF only Medium or no new issues -> finalize (proceed to Phase 5)
IF CURRENT_ROUND >= MAX_ROUNDS -> force finalize (note unverified fixes in progress.md)
IF this round found same issues as last round AND CURRENT_ROUND >= MIN_ROUNDS -> force finalize (agents are circling)
```

**Between rounds:** Include in next prompt: "Previous round findings are in {ARTIFACTS_DIR}/round-{N-1}-\*.md. Focus on areas NOT covered in previous rounds, plus verify previous fixes landed correctly."

**Loop back to Phase 1.**

---

## Phase 5: Finalize

### Conductor Final Review (Triage)

Read the consensus registry. Collect all remaining items:

1. **No-consensus findings:** Single-agent findings that never recurred across rounds
2. **DESIGN_DECISION items:** Findings deferred during rounds as genuine design decisions

**If nothing remains:** Skip — proceed to verification.

**Classify each remaining no-consensus finding:**

| Category | Criteria | Action |
|---|---|---|
| `AUTO_IMPLEMENT` | There is a clearly superior technical answer — better correctness, robustness, performance, or maintainability. The improvement is unambiguous. | Implement it now. |
| `DESIGN_DECISION` | No objectively superior answer AND the choice would **noticeably affect the end-user experience** or **profoundly change the development approach**. Minor design choices (spacing, naming, style) — just pick the better option and classify as `AUTO_IMPLEMENT`. | Defer to user. |
| `SCOPE_ESCALATION` | A technically superior option exists but requires profound structural change that constitutes a strategic commitment. | Defer to user with scope context. |

**Default bias: `AUTO_IMPLEMENT`.** Most findings have a correct answer — pick it.

**Apply all `AUTO_IMPLEMENT` items using `br` commands.** Log each with rationale.

### Present Decisions to User (if any)

**If no `DESIGN_DECISION` or `SCOPE_ESCALATION` items remain:** Skip — proceed to verification.

**If items remain:**

```
AskUserQuestion(
  questions: [{
    question: "Auto-applied {N} fixes (severity + consensus + technical triage). {M} items need your decision:",
    header: "Decisions",
    multiSelect: true,
    options: [
      { label: "Fix X: <title>", description: "DESIGN_DECISION — Round {R}, {severity} — {agent}: Bead {id} — {one-line summary}" },
      { label: "Fix Y: <title>", description: "SCOPE_ESCALATION — {severity} — {agent}: Bead {id} — {one-line summary}. Scope: {what it entails}" }
    ]
  }]
)
```

**If more than 4 items:** Split across multiple `AskUserQuestion` calls.

**Apply any user-approved findings using `br` commands.**

### Title/Label Parity Gate (decision beads MUST carry `human-gate`) — run BEFORE stamping

**Critical parity assertion, checked over the whole reviewed snapshot before any `refined` stamp.** Any bead titled `DECISION:` / `DESIGN_DECISION:` (case-insensitive prefix) OR typed `decision` that lacks the `human-gate` label is a Critical finding — the label is what every label-keyed gate reads (`issue_type=decision` alone gates nothing; memory `decision-beads-need-human-gate-label-at-filing`, `beads-standards` § human-gate). Fix it (add the label) BEFORE that bead can be stamped `refined` — a decision bead must never reach `refined` without its gate label. This is the backstop for producers (ac-review / ac-hygiene Exhaust Rule) that hand-roll a `br create` and drop the label; it has recurred 14+ times, caught only by reactive manual relabeling in refine passes — this gate makes the fix automatic.

```bash
# Add human-gate to any decision-typed OR DECISION:/DESIGN_DECISION:-titled reviewed bead
# missing it. Read rows from the Phase-0 beads-snapshot.json ONLY — never
# `br show "$id" --json | jq` per id (multi-line descriptions break jq; bd-lsnc0).
# Scope is still the target list (bd-baudw): this mutates beads, so it obeys the same
# "never touch an id outside target-bead-ids.txt" rule as the stamp loop below.
# SINGLE-PASS: jq emits the ids directly — never re-parse a row in the shell. Piping a row
# back through `echo` is the corrupter (ac-ewgr.1): zsh's echo expands the \n in br's JSON, so
# 30 of 34 open beads were dropped as "jq: Invalid string: control characters" — silent under
# bash, corrupting under zsh (the fleet's default). If a per-row loop is ever needed again,
# it is `printf '%s'`, never `echo`.
#
# FAIL-CLOSED (bd-br-json-control-chars-21ljf). This gate used to pipe jq straight into a
# `while read` and never looked at jq's exit status, so ANY parse failure delivered zero ids
# and the gate reported CLEAN without checking a single bead — a decision bead missing
# `human-gate` sailed through to `refined`. jq's status is now checked explicitly and an
# unreadable snapshot ABORTS Phase 5. An empty result is only trustworthy once the snapshot
# has been proven readable: see ac-pipeline/references/shell-guardrails.md § Empty is not clean.

# 1. Preflight — prove the snapshot parses AND is non-empty BEFORE trusting an empty result.
SNAP_N=$(jq -r '.issues | length' "$ARTIFACTS_DIR/beads-snapshot.json"); jq_exit=$?
if [ "$jq_exit" -ne 0 ] || ! printf '%s' "${SNAP_N:-}" | grep -qE '^[0-9]+$' || [ "$SNAP_N" -eq 0 ]; then
    printf 'FATAL: parity gate cannot read beads-snapshot.json (jq exit=%s, issues=%s) — ABORTING Phase 5; nothing stamped.\n' "$jq_exit" "${SNAP_N:-<none>}" >&2
    exit 2
fi

# 2. The gate itself — still SINGLE-PASS, but jq's status is captured before any loop runs.
PARITY_IDS=$(jq -r '.issues[]
       | select(.status == "open")
       | select((.issue_type == "decision")
                or (.title | ascii_upcase | test("^(DECISION|DESIGN_DECISION):")))
       | select((.labels | index("human-gate")) | not)
       | .id' "$ARTIFACTS_DIR/beads-snapshot.json"); jq_exit=$?
if [ "$jq_exit" -ne 0 ]; then
    printf 'FATAL: parity gate query failed (jq exit=%s) — ABORTING Phase 5; nothing stamped.\n' "$jq_exit" >&2
    exit 2
fi

printf '%s\n' "$PARITY_IDS" | while IFS= read -r id; do
    [ -n "$id" ] || continue
    grep -qxF "$id" "$ARTIFACTS_DIR/target-bead-ids.txt" || continue   # not mine — never touch it
    echo "PARITY FIX: $id is a decision bead missing human-gate — adding label"
    br label add "$id" "human-gate" 2>/dev/null
done
```

### Remove `unrefined`, Stamp `refined`

**On successful convergence (Phase 5 reached), remove the `unrefined` label AND add the `refined` label to all beads that were reviewed.** Readiness for implementation is presence of `refined`, not absence of `unrefined` (`skills/beads-standards/reference/bead-conventions.md`) — this stamp is this skill's exclusive output.

**BLOCKING PRE-STAMP GATE (both must hold, per bead):**
1. **A `refine-corrections:` comment exists on the bead** (see Phase 2 — `0` is a valid count,
   a MISSING comment is not). No comment → not refined; go back and write it.
2. **Every AC that encodes a command has had that command executed against HEAD this round**,
   or is explicitly labelled unrunnable-here. An AC whose command was never run is not verified.

These are gates, not advice: `refined` is the label the loop selects on, so a bead that reaches
it without them enters implementation carrying claims nobody checked.

**Also stamp the refine-PATH that produced the convergence** — `refine-full` for the
normal 3-reviewer × ≥3-round run this workflow codifies, or `refine-light` when the
formal light-path branch below applies (ALL four criteria; see SKILL.md § Light-path
and this section). The pair is eval-load-bearing and frozen under
`beads-standards` § LABEL-FREEZE.

### Light-path / `refine-light` (formal branch — bd-chd5p.6)

This skill **has a formal light branch**. `refine-light` is **not** an ad-hoc
carve-out: it may be stamped only when **ALL four** criteria in
`ac-bead-refine/SKILL.md` § Light-path hold (HARD GATE #1 first: RISK-TOUCH
persistence / async-multi-writer via `ac-pipeline/references/risk-classification.md` binding #5;
single-file; <24h same-run evidence vs `RUN_ID` start; independent adversarial
concurrence on `file:line`). Failing any one → full `MIN_ROUNDS` and `refine-full`.

Before stamping `refine-light`, paste into a bead comment (exact CLI:
`br comments add <id> "…"`):

1. mechanism `file:line`
2. evidence artifact path + ISO timestamp
3. independent concurrence one-liner (`PASS <file:line>`)

bd-9bvr2 closed `decided:ACCEPT` — do not re-open a human-gate on these criteria.

**Contract gate:** no implementable bead gets the stamp while its `## Delivers` / `## Consumes` is missing or vague (`beads-standards/reference/bead-conventions.md` §Bead I/O contract) — author or fix the contract first (refine authors it for quick-capture beads). The stamp asserts the I/O contract along with everything else; ac-implement's pre-dispatch premise check reads Consumes lines at face value.

**Test Scope gate (same standing as the contract gate — blocking, not a checklist wish):** no implementable bead gets the stamp while `## Test Scope` is missing, or while any anchor in it is unverified (`beads-standards/reference/bead-conventions.md` §Body template). Grep every named file/describe block against HEAD **this round** — never carry an anchor over from the filing (three beads in one refine run cited describe blocks that did not exist). Missing section → refine authors it, exactly as it authors the I/O contract for quick-capture beads; anchor that does not grep → fix or drop it before stamping. Beads arriving from the origin skills that do NOT pre-emit a test plan (`ac-triage`, `ac-review`'s Exhaust Rule, the `ac-qa-*` findings path) will need it authored here. A bead reaching `refined` with no verified test scope is what lets the engineer invent tests that cannot fail (bd-mfr1d, bd-ghj12 — 2026-07-30, both shipped broken with green suites).

**Implementation-contract gate (same standing):** no implementable bead gets the stamp while any of the six elements is missing or unverified (`beads-standards/reference/bead-conventions.md` § Implementation contract). Author whatever capture omitted (beadify pre-stamps territory + sequence; refine completes the rest). An unopened `file:line`, a reasoned count, a territory without `### Test-tier exposure`, or an AC an empty diff could satisfy → not refined.

**The stamp loop is authoritative on `target-bead-ids.txt`, NOT on the snapshot (bd-baudw).**
The snapshot is a shared-shaped file that a sibling child could once have overwritten; the
target list is this child's own scope, written once at Phase 0 and never re-derived. Stamping
off the snapshot is what let a child mark beads it never reviewed as agent-ready. The rule:
**an id absent from `target-bead-ids.txt` gets zero `br label` calls, ever** — no matter what
the snapshot says.

```bash
# Remove unrefined, add refined + the refine-path label — scoped to the beads THIS child
# was handed at Phase 0 (Mode A/B/C target list), never to whatever the snapshot contains.
# refine-full = normal 3-reviewer × ≥3-round; refine-light = formal light branch (ALL 4 criteria).
REFINE_PATH="refine-full"
# Set REFINE_PATH=refine-light only after HARD GATE + criteria 2–4 all hold (SKILL.md § Light-path).

[ -s "$ARTIFACTS_DIR/target-bead-ids.txt" ] || { echo "FATAL: no target list — Phase 0 did not run in THIS dir; do not stamp" >&2; exit 2; }

# Integrity gate: the snapshot must cover every target. A miss means the snapshot is stale
# or foreign (a sibling clobbered it) — rebuild it from the target list rather than trusting it.
MISSING=$(comm -23 \
  <(sort -u "$ARTIFACTS_DIR/target-bead-ids.txt") \
  <(jq -r '.issues[].id' "$ARTIFACTS_DIR/beads-snapshot.json" | sort -u))
if [ -n "$MISSING" ]; then
    echo "WARN: snapshot does not cover targets ($(echo "$MISSING" | command tr '\n' ' ')) — rebuilding from the target list"
    REBUILD_FLAGS=()
    while IFS= read -r t; do [ -n "$t" ] && REBUILD_FLAGS+=(--id "$t"); done < "$ARTIFACTS_DIR/target-bead-ids.txt"
    br list --json "${REBUILD_FLAGS[@]}" --all | tee "$ARTIFACTS_DIR/beads-snapshot.json" >/dev/null
fi

# FAIL-CLOSED counters (bd-br-json-control-chars-21ljf). Without them an unparseable or
# foreign snapshot resolved EVERY id to "unknown" and the loop printed N x `SKIP` — output a
# conductor skims as intentional. N targets in, zero resolved, is a broken snapshot, not a no-op.
TARGET_N=0; RESOLVED_N=0
while IFS= read -r id; do
    [ -n "$id" ] || continue
    TARGET_N=$((TARGET_N + 1))
    # bstatus comes from the (now target-consistent) snapshot; scope comes from the list.
    # NEVER name this `status` — it is a READ-ONLY special in zsh (alias for $?), so the
    # assignment aborts the loop on the fleet's default shell (bd-x8ios).
    bstatus=$(jq -r --arg id "$id" 'first(.issues[] | select(.id == $id) | .status) // "unknown"' "$ARTIFACTS_DIR/beads-snapshot.json"); jq_exit=$?
    if [ "$jq_exit" -ne 0 ]; then
        printf 'FATAL: stamp loop cannot parse beads-snapshot.json (jq exit=%s, at %s) — ABORTING; nothing further stamped.\n' "$jq_exit" "$id" >&2
        exit 2
    fi
    [ "$bstatus" = "unknown" ] || RESOLVED_N=$((RESOLVED_N + 1))
    [ "$bstatus" = "open" ] || { echo "SKIP $id (status=$bstatus)"; continue; }
    br label remove "$id" "unrefined" 2>/dev/null
    br label add "$id" "refined" 2>/dev/null
    br label add "$id" "$REFINE_PATH" 2>/dev/null
done < "$ARTIFACTS_DIR/target-bead-ids.txt"

if [ "$TARGET_N" -gt 0 ] && [ "$RESOLVED_N" -eq 0 ]; then
    printf 'FATAL: all %s target bead(s) resolved to status=unknown — the snapshot is stale, foreign or unparseable. ABORTING; nothing was stamped.\n' "$TARGET_N" >&2
    exit 2
fi
```

This signals to `/ac-human-session` and `/ac-implement` that these beads have been through refinement and are agent-ready — `/ac-implement`'s intake gate checks for `refined` explicitly.

### Verify Final Structure

```bash
br list --json
br dep cycles    # Must return clean
br lint          # Check for missing sections
br ready --json  # Show what's ready to implement
bv               # Visual TUI overview
```

### Quality Checklist

Verify:

- [ ] Beads are self-contained (no need to consult original plan — plan should already be archived)
- [ ] Dependencies correctly mapped (`br dep cycles` returns clean)
- [ ] Tasks appropriately granular for mechanical implementation
- [ ] Test requirements included in each bead — with a declared **test scope** (paths/globs for affected-tests), every anchor grep-verified against HEAD this round (enforced by the Test Scope gate above, not optional here)
- [ ] Each bead is independently **green + shippable**; bead order is **commit-safe** (add-before-remove; migrations additive-first)
- [ ] Comments explain reasoning/justification
- [ ] Acceptance criteria are clear and verifiable — AND checked for the two recurring
      false-convergence shapes: (1) every cited `file:line` anchor and quoted artifact
      (test body, response payload, field name, count) is RE-VERIFIED against HEAD this
      round, not carried over from the filing — a falsified premise closes or rewrites
      the bead, it is never smoothed over; (2) every AC can actually FAIL, and fails for
      the RIGHT reason — flag grep/pattern-shaped ACs (over-match/under-specify) and any
      AC asserting a numeric DOM property without first establishing the property is
      meaningful on that element type; demand a bite-proof (demonstrate the check RED)
      for any AC that is the sole evidence for a bead
- [ ] Title/label parity enforced — every `decision`-typed / `DECISION:`/`DESIGN_DECISION:`-titled reviewed bead carries `human-gate` BEFORE stamping
- [ ] Implementation contract complete on every implementable bead — all six elements present and verified this pass (`beads-standards/reference/bead-conventions.md` § Implementation contract), including `### Test-tier exposure`
- [ ] `unrefined` removed AND `refined` added to all reviewed beads

### Report

```markdown
## Bead Refinement Complete

**Rounds completed:** {CURRENT_ROUND}
**Stop reason:** {severity converged | MAX_ROUNDS | user decision}

### Convergence

Round  Completeness  Implementability  Structure  Total  Applied  Deferred
  1      {n}            {n}              {n}       {n}     {n}       {n}
  2      {n}            {n}              {n}       {n}     {n}       {n}
  3      {n}            {n}              {n}       {n}     {n}       {n}

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

### Bead Status

- Ready to implement: {count} (`br ready --json`)
- Total beads: {count}
- Blocked: {count}

### Next Steps

1. **Implement** -> `/ac-implement`
2. **Further refine** -> Run again with updated beads
3. **Review beads** -> `bv` for visual overview
```

**If called from `ac-loop` (autonomous run):** Skip the next-step question entirely. Print the summary above and exit — the loop chains directly to `ac-implement`. Detect loop context from the delegation prompt (look for "ac-loop", "autonomous", "headless", or `TARGET_BEADS=` in the invocation context).

**If called interactively (human present):** Present the next-step choice:

```
AskUserQuestion(
  questions: [{
    question: "Bead refinement complete. What's next?",
    header: "Next step",
    multiSelect: false,
    options: [
      { label: "Implement (Recommended)", description: "Run /ac-implement — sequential implementation with conductor + engineer sub-agents" },
      { label: "Further refine", description: "Run /ac-beadify again — another round of 3 parallel reviewers" },
      { label: "Review visually", description: "Open bv TUI for manual inspection before deciding" }
    ]
  }]
)
```

---

## Jeffrey's Standard

> "The beads should be so detailed that we never need to consult back to the original markdown plan document."

---

## Remember

- **YOU synthesize and apply fixes** — agents find issues, you decide and fix
- **Auto-apply Critical/High + same-round consensus + cross-round consensus — defer the rest**
- **Honor the round floor — it is ABSOLUTE** — never finalize before MIN_ROUNDS=3, not even on two consecutive zero-finding rounds (the dry-panel exit is only reachable at round ≥3); ceiling MAX_ROUNDS=5. Cross-round consensus needs the later rounds to exist
- **Cross-round consensus:** single-agent findings that recur in later rounds are high-signal — auto-apply on match
- **Conductor triage before user** — remaining items get a final review: auto-implement clear technical improvements, only defer genuine design decisions (user-visible or development-transformative) and scope escalations to the user
- **Design decision gate every round** — choices that noticeably affect user experience or profoundly change development are deferred regardless of severity or consensus
- **Competitive framing sharpens output** — agents know they compete for relevance
- **Structure Optimizer counterbalances** — prevents completeness reviewer from piling on complexity
- **Findings files + consensus registry survive compaction** — always read from `$ARTIFACTS_DIR`, not memory (recover the dir from the recorded LITERAL path, never by re-deriving — `$$` changes every bash call)
- **`$ARTIFACTS_DIR` is per-CHILD, `target-bead-ids.txt` is per-CHILD (bd-baudw)** — a conductor hands every sibling the same `RUN_ID` and claim id on purpose, so only the child's own discriminator (`AGENT_NAME`+`$$`) keeps two fan-out children apart. **Never** stamp off `beads-snapshot.json`; stamp off the target list. Never hand-suffix `RUN_ID` to dodge a collision
- **Progress file is compaction recovery** — parse it to know where you left off
- **3 agents per round > 1 pass repeated** — more perspectives, faster convergence
- **Evidence over opinion** — bead IDs and content citations, not vague concerns
- **Verify function signatures from source** — when a spec references a function call, check argument order against the actual implementation, not from memory or docs
- **Refinement checks codebase AND pipeline** — agents should flag conflicts with other beads/waves and plans in `_plans/`, not just existing code

---

_Bead refine: parallel agents iterate until severity-converged. For implementation: `/ac-implement`. For landing: `/ac-land`._
