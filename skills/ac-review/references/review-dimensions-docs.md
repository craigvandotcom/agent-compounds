# Review Dimensions — Docs-Only

The docs-lens panel. Spawned **instead of** the code four (correctness / security /
performance / architecture) when the diff touches **only non-code paths** — every changed
file under `_plans/`, `docs/`, `references/`, or a bare `*.md`, with **zero** hits under
`app|lib|scripts|supabase|features` (detection: SKILL.md § Assemble the Panel). A research
register, a plan, a study report, or a memory/skill doc has no runtime surface, so the
code-shaped lenses find nothing; these three review what a docs diff can actually get
wrong.

Each dimension fills the placeholders in `reviewer-prompt-template.md` exactly like the
code panel: spawn all three in parallel (one message, one Task call per lens), record them
in the **panel manifest** (`$ARTIFACTS_DIR/panel-round-{ROUND}.json`), and let
`consensus.py` reconcile — a spawned lens with no output file is a partial failure, never
a silent pass. No `{CMD_TEST}` / `{CMD_BUILD}` (there is no runtime to exercise); the
lenses read the diff and the cited sources.

**Rubric source — the org's own documentation-standards skills, not improvised taste.**
All three lenses judge the docs against the standards the org already declares:
- **`context-engineering`** — where knowledge lives, what loads when, the memory/CORE/skill
  layering, the save/route doctrine (the constitution for durable docs).
- **`skill-builder`** — SKILL.md structure, description-as-WHEN, token economics, reference
  layout, overlap/selectability rules.
- **wiki / memory doctrine** — the memory-substrate authoring conventions (fact shape,
  provenance, retirement triggers) and any project wiki standard.
A finding cites which declared standard the doc violates, not a reviewer's preference.

**SLUGS** are the suggested `category` values — the consensus key. Prefer these so
same-round and cross-round consensus can match; coin a new slug only for an unlisted
defect class.

---

## findings-integrity

- **ROLE:** `findings-integrity`
- **SKILL_HINT:** `Read the org documentation-standards skills for the rubric: context-engineering/SKILL.md, skill-builder/SKILL.md, and the memory/wiki doctrine. Judge claims against THESE, not taste.`
- **EVIDENCE:** The specific claim + where it should be sourced but isn't (or is mis-sourced)

**METHOD:**

Walk every assertion the diff makes — a finding, a metric, a "we decided X", a "the code
does Y" — and demand its citation: a file path, a bead id, a commit SHA, a prior decision,
a measured number. An uncited claim in a durable doc is a future landmine (the next reader
trusts it). Follow the claim to its cited source and confirm the source actually says it;
a citation that doesn't support the claim is worse than none. Hold durable docs to the
`context-engineering` provenance bar (facts carry their origin; decisions name their basis).

Discipline: a finding names the exact claim and the missing/broken citation — not "needs
more detail." Vague-completeness nits stay out.

**CHECKLIST:**

- Uncited factual claims (metrics, behaviors, "we found", "the code does")
- Citations that don't support the claim they're attached to (mis-sourced)
- Dangling references — a path/bead/SHA/plan that doesn't exist or has moved
- Decisions recorded without their basis/rationale (context-engineering provenance rule)
- Numbers/dates that contradict their own cited source

**SLUGS:** `uncited-claim`, `mis-sourced-citation`, `dangling-reference`,
`missing-provenance`, `unsupported-number`

---

## consistency

- **ROLE:** `consistency`
- **SKILL_HINT:** `Read context-engineering/SKILL.md + skill-builder/SKILL.md for the register/structure standards this lens enforces.`
- **EVIDENCE:** The two places that disagree (quote both) or the register/format the doc breaks

**METHOD:**

Read for internal coherence and standard conformance. Two failure classes: (1) the doc
contradicts itself or another doc in the set — a severity called "P1" in the summary and
"P3" in the table, a status/register/priority that drifts between sections, a claim that
negates one made earlier; (2) the doc breaks the declared documentation standard —
SKILL.md structure or description-as-WHEN (`skill-builder`), memory-fact shape, the
knowledge-placement/layering rules (`context-engineering`). Cross-reference sibling docs
in the same diff for contradictions across files, not just within one.

Discipline: quote both sides of a contradiction, or name the exact standard clause broken.
Style preferences that no declared standard mandates are not findings.

**CHECKLIST:**

- Severity / priority / status / register mismatches within a doc or across the diff
- Cross-doc contradictions (two docs in the set asserting incompatible things)
- Structure/format violations vs `skill-builder` (SKILL.md shape, description = WHEN)
- Knowledge placed in the wrong layer/home vs `context-engineering` (fact vs decision vs
  skill vs CORE)
- Terminology drift — the same concept named differently across sections

**SLUGS:** `severity-mismatch`, `cross-doc-contradiction`, `structure-violation`,
`wrong-knowledge-home`, `terminology-drift`

---

## discipline

- **ROLE:** `discipline`
- **SKILL_HINT:** `Read context-engineering/SKILL.md for the scope/routing doctrine (what belongs in this doc vs elsewhere).`
- **EVIDENCE:** The out-of-scope change + what mission the diff was supposed to be

**METHOD:**

Confirm the diff did **only** what its mission declared and nothing more. The classic
docs-wave failure is a fix (or a code/config change, a new decision, a scope expansion)
smuggled into a study/research/documentation mission — a study should observe, not mutate.
Check that additions land in the right home (a decision goes to the decisions register, not
buried in a plan; a durable fact goes to the memory substrate, not stranded in a report)
per `context-engineering` routing, and that the diff stayed within its stated boundary.

Discipline: name the specific out-of-scope change and the mission it violated. "Could be
tighter" is not a discipline finding.

**CHECKLIST:**

- Fixes / code / config changes snuck into a docs-or-study-only mission
- New decisions or facts introduced that belong in a routed home, not this doc
- Scope creep beyond the declared mission boundary
- Durable knowledge left stranded in an ephemeral doc instead of routed (context-engineering)

**SLUGS:** `out-of-scope-change`, `unrouted-knowledge`, `scope-creep`,
`mission-boundary-violation`
