# Token Economics — the loading model, hard budgets, and the determinism framework

Read this when writing or refining a skill description, deciding what to cut from a
skill, or auditing the registry's context footprint. The compact operative version of
the framework lives in SKILL.md § Token Economy; this file holds the full payload:
mechanics, hard numbers, evidence, and sources.

Researched 2026-07-07 (Anthropic docs, Matt Pocock's writing-great-skills,
obra/superpowers wording tests, measured Claude Code behavior). Re-verify hard numbers
against current docs before relying on them for enforcement decisions.

---

## 1. The loading model — what costs tokens, when

| Stage | What loads | Cost profile |
|---|---|---|
| **Session start** | `name` + `description` of every model-invocable skill, injected into the system prompt | Paid in EVERY session, EVERY turn — the most expensive real estate in the system |
| **Invocation** | Full SKILL.md body, as a conversation message | Paid once per session — then **persists for the rest of the session**; every line is a recurring cost in each subsequent turn |
| **On demand** | `references/`, `workflows/` files | Zero until Read; effectively unbounded capacity |
| **Execution** | `scripts/` | Never loaded — executed; only script *output* costs tokens |

Consequences:
- Write body guidance that must hold throughout a run as **standing instructions**, not
  one-time steps — the body persists, so phrasing like "first, do X" decays into noise
  while "always X when Y" keeps working.
- References are free until read, so moving payload to `references/` costs nothing —
  **except reliability** (see §3): a pointer is the weakest enforcement mechanism.
- Anything deterministic enough to script should be a script: cheaper than prose AND
  more reliable than prose.

## 2. Hard budgets (violate these and skills silently break)

| Limit | Value | Failure mode when exceeded |
|---|---|---|
| `description` field | **1,024 chars max** (platform validation) | Rejected/truncated |
| Per-skill listing entry | ~1,536 chars (description + when_to_use) | Silently truncated in the listing |
| **Total skill-listing budget** | **~1% of context window; measured in practice at ~15,000 chars (~4k tokens)** | Least-used skills are **silently dropped from the listing — the model is told not to use unlisted skills, so an over-budget registry makes skills invisible.** The ultimate reliability failure: the skill never fires at all. |
| Post-compaction re-attach | ~5k tokens per invoked skill, ~25k shared, most-recent-first | Older invoked skills silently dropped after compaction |

**Registry rule:** the sum of all description lengths across every skill visible to a
session must stay under the listing budget. Check with
`validate-skill.sh --registry <skills-dir>`. Two levers when over budget:
1. Trim descriptions to trigger-only form (§4).
2. Set `disable-model-invocation: true` on skills only ever invoked by name (user
   command or pipeline orchestration) — removes their description from context
   entirely, zero standing cost, and frees budget so model-discoverable skills
   reliably stay listed. Verify the invocation path still reaches the skill before
   flipping this on an existing skill.

## 3. The determinism framework — classify tokens by the failure they prevent

**Root principle (this registry's standing rule): predictability is the virtue; token
cost is a symptom.** A skill exists to wrangle determinism out of a stochastic system.
The question is never "can this be shorter?" It is: **"what failure does this token
prevent, and does an equally strong or stronger mechanism exist for fewer tokens?"**
Cut only when the answer is yes.

### The enforcement hierarchy (strongest → weakest)

1. **Script / hook execution** — deterministic machinery; the behavior cannot not happen
2. **Inline instruction at point of use** — co-located with the moment it must fire
   (e.g. a `TaskUpdate` line at the exact phase boundary)
3. **Checkable completion criterion** — "every modified file accounted for", not "produce a list"
4. **Repetition / emphasis** — restating a rule at each decision point where it applies
5. **Prose rule at a distance** — a convention stated once, relied on globally
6. **Pointer to another file** — the model must choose to follow it; a variance lever

**The cut rule: a token may be removed only when its job passes to a mechanism at the
same level or higher.** Progressive disclosure moves content from level 2 to level 6 —
correct for payload only *some* runs need, wrong for enforcement content every run
needs. This is why pipeline skills legitimately run long: their length IS the
enforcement. The highest-value optimization is upward movement that also saves tokens:
a fragile bash procedure duplicated as prose → a bundled script (level 5 → level 1).

### The four buckets

| Bucket | Examples | Action |
|---|---|---|
| **Enforcement** | Run-ledger TaskCreate/TaskUpdate lines · explicit fully-written branches · exact AskUserQuestion option sets · point-of-use repetition · completion criteria · Remember blocks (standing-instruction re-anchors after a long body) · mandated output formats | **Keep.** Replace only with something *stronger* (script/hook), never merely cheaper. |
| **Discovery** | Frontmatter descriptions | **Trigger-only, front-loaded, hard-pruned** (§4). Over-budget descriptions cause silent skill invisibility; workflow summaries cause body-skipping. Cutting here *increases* reliability. |
| **Persuasion** | Rationale, incident anecdotes, "why this matters" | **Compress to rule + one-clause why.** The causal why binds behavior ("never `git add -A` — it stages build artifacts"); the date, bead ID, and minutes lost don't. Full narratives → `references/incidents.md` or the memory substrate. |
| **Sediment** | Same content twice in one file · dead paths for stacks the skill never meets · deprecation history in descriptions · JSON syntax around content the model already knows · stale layers nobody pruned | **Pure cut, no tradeoff.** Sediment is "the default fate of any skill without a pruning discipline." |

Cross-file verbatim duplication is a fifth, mixed case: deterministic today, but copies
drift under maintenance, and drifted copies give contradictory instructions —
nondeterminism of the worst kind. For **procedures**: extract to a script (upward move).
For **prose**: keep the restatement but mark it `<!-- mirror of _shared/x.md — edit
there first -->` so drift is managed instead of paying the pointer-weakness cost.

### The no-op test (sentence-level pruning)

For every sentence: *does it change behavior versus what the model would do anyway?*
If not, delete the whole sentence — don't trim words from it. Named failure modes to
hunt: **duplication** (synonyms renaming one branch), **sediment**, **sprawl** (every
line live but simply too long — judge per-line by this test, not by a line count),
**negation** ("don't think of an elephant" names the elephant — prompt the positive).

## 4. Description doctrine (the always-paid layer)

- **WHEN, never HOW.** Empirical (superpowers wording tests): when a description
  summarizes the workflow, the agent follows the summary and skips the body — an agent
  did ONE review where the skill mandated two. A lean description is what *protects* a
  deterministic body.
- **Front-load the strongest trigger** (truncation happens at the tail).
- **Third person, concrete nouns/verbs users actually say.** Be generous with trigger
  *keywords* (models undertrigger), ruthless with everything else: no workflow, no
  deprecation history, no identity restating the body, one trigger per branch —
  synonyms that rename a single branch are duplication.
- Descriptions earn harder pruning than the body: they're paid in every session of
  every consuming app, multiplied across the registry.

## 5. Empirically-grounded anti-patterns

| Anti-pattern | Evidence | Fix |
|---|---|---|
| Workflow summary in description | Agent follows summary, skips body (superpowers, tested) | Trigger-only description |
| Prohibition-based shaping ("don't include X") | Prohibition arm produced MORE unwanted content than no-guidance control (superpowers wording tests, fully separated distributions) | Positive recipe: state what TO produce |
| Nuance/exemption clauses on a working rule ("unless it matters") | One clause degraded a winning recipe "from consistent to noisy"; exemption clauses don't scope | One default, no menu; put real branches in the body as explicit paths |
| Explaining what the model already knows | ~3× token cost, zero behavior change | No-op test |
| Pointer + full restatement, unmanaged | Copies drift → contradictory instructions | Script it (procedures) or mirror-mark it (prose) |
| One-time-step phrasing in a persistent body | Instruction decays after step passes | Standing-instruction phrasing |
| `@`-linking files from a skill | Force-loads immediately, defeats on-demand loading | Plain path reference + when-to-read condition |

## 6. Sources

- Claude Code skills docs — loading lifecycle, listing budget, compaction behavior:
  https://code.claude.com/docs/en/skills
- Anthropic skill authoring best practices (conciseness, degrees of freedom, patterns):
  https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
- Anthropic engineering — progressive disclosure:
  https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills
- Matt Pocock, writing-great-skills (predictability as root virtue, two loads, leading
  words, no-op test, sediment/sprawl/negation):
  https://github.com/mattpocock/skills/blob/main/skills/productivity/writing-great-skills/SKILL.md
- Jesse Vincent / obra-superpowers (description wording tests, prohibition backfire,
  measured ~15k-char listing cliff): https://github.com/obra/superpowers +
  https://blog.fsck.com/2025/12/17/claude-code-skills-not-triggering/
- Simon Willison on skills-vs-MCP token economics:
  https://simonwillison.net/2025/Oct/16/claude-skills/
