---
name: planning
description: 'The scope-oscillation planning methodology (Jeffrey Emanuel) — the divergent-convergent refinement lenses the ac-plan-* pipeline skills draw on. This is a reference/methodology, NOT a direct entry point: to create a plan use ac-plan-init; to refine one use ac-plan-refine-internal (routine) or ac-plan-refine-external (high-stakes); for a final correctness pass use ac-plan-clean. Load this when you want the underlying lenses or are planning outside the pipeline.'
---

> **Generic skill — method only, zero app facts.** This skill is symlinked from
> agent-compounds and shared across consuming apps. It contains technique and
> patterns, not project specifics. **App specifics (project refs, schema names,
> domain rules, feature flows, env values) → read this app's
> `.claude/skills/CORE/SKILL.md`** (and the `AGENTS.md` summary it indexes).
> Do not add app-specific facts to this file — they belong in CORE.

# Planning Skill — methodology reference

Strategic planning for features and fixes using Jeffrey Emanuel's iterative
refinement methodology (scope oscillation).

> **This is the methodology layer, not the entry point.** The live pipeline owns
> the *doing*: `ac-plan-init` creates plans, `ac-plan-refine-internal` /
> `ac-plan-refine-external` refine them, `ac-plan-clean` does the correctness
> pass. This skill is the underlying *method* those stages draw on — load it for
> the scope-oscillation lenses, or when planning outside the pipeline. It is not
> auto-invoked for "plan this feature" (that routes to `ac-plan-init`).

## When to Load This Skill

- You want the scope-oscillation lenses themselves (the *how* behind the pipeline)
- Structured planning outside the `ac-plan-*` pipeline
- A pipeline stage (`ac-plan-init` / `ac-plan-refine-*`) cites this as its method

## Core Principle

> "Planning tokens are cheaper than implementation tokens."
> — Jeffrey Emanuel

Invest heavily in plan quality before writing code. 4-5 rounds of refinement typically reaches convergence where improvements become marginal.

---

## Methodology: Scope Oscillation

Each refinement round uses a **fundamentally different lens**, alternating between narrow/focused and wide/expansive thinking:

| Round | Name             | Lens                   | Key Question                         |
| ----- | ---------------- | ---------------------- | ------------------------------------ |
| 1     | **IN-THE-SMALL** | Microscopic, grounded  | Does this match reality?             |
| 2     | **IN-THE-LARGE** | Panoramic, systemic    | What are the weakest parts?          |
| 3     | **DIVERGE**      | Creative, expansive    | What else could we do?               |
| 4     | **CONVERGE**     | Adversarial, defensive | Imagine this failed—what went wrong? |
| 5     | **SYNTHESIS**    | Integrative, decisive  | What's the best combined version?    |

This prevents repetitive rounds that just tweak the same ideas. Each round genuinely comes from a different angle.

**For detailed methodology:** See `methodology.md`

---

## Resources

### Prompts

Located in `prompts/`:

| Prompt                    | Purpose                                              |
| ------------------------- | ---------------------------------------------------- |
| `context-gathering.md`    | 3 parallel code-explorer agents for codebase context |
| `round-1-accuracy.md`     | Verify plan against actual codebase                  |
| `round-2-architecture.md` | Analyze system-wide implications                     |
| `round-3-diverge.md`      | Generate alternatives, find blind spots              |
| `round-4-premortem.md`    | Anticipate failures, harden plan                     |
| `round-5-synthesis.md`    | Integrate insights from all rounds                   |

### Templates

Located in the project's plan-templates directory — path varies by app (`.claude/plans/templates/` or `_plans/templates/`); check the consuming app's CORE/AGENTS.md:

| Template            | Use For      |
| ------------------- | ------------ |
| `build-template.md` | New features |
| `fix-template.md`   | Bug fixes    |

---

## Quick Mode (3 Rounds)

For simpler plans, compress to:

1. **Round 1:** IN-THE-SMALL (Accuracy) — always run
2. **Round 2:** IN-THE-LARGE + Premortem (combined)
3. **Round 3:** SYNTHESIS (abbreviated)

---

## Skip Rules

- **Never skip Round 1** — accuracy is always critical
- **Never skip Synthesis** — integration prevents fragmented changes
- **Skip Round 3 (Diverge)** if plan is already comprehensive
- **Skip Round 4 (Premortem)** if plan is low-risk/reversible

---

## Pipeline integration (modern additions)

The live `ac-plan-*` chain applies three upgrades on top of the scope-oscillation core — each *preserves* the lens cycle, none replaces it:

1. **Clarify before Round 1** (`ac-plan-init`) — a short interview surfaces ambiguity and records an `## Assumptions` log *before* exploration, so the rounds refine a grounded draft rather than a wrong one (a wrong starting assumption compounds through every round).
2. **Per-task acceptance criteria** — each plan step/phase carries a **Done when:** verifiable check, so the implementer self-verifies instead of asserting "looks done".
3. **Explicit convergence verdict** (`ac-plan-refine-internal`) — each round is scored major/minor/cosmetic; refinement stops when two consecutive rounds are minor-or-cosmetic with no open Critical/High, instead of always running to MAX_ROUNDS. Operationalizes the "steady-state detection" this methodology has always described.

---

## Related Commands

| Command        | Uses This Skill For                      |
| -------------- | ---------------------------------------- |
| `/ac-plan-init`     | Initial plan creation using templates    |
| `/ac-plan-refine-internal` | Iterative multi-agent refinement to convergence |
| `/ac-plan-refine-external` | High-stakes refinement across external models |
| `/ac-plan-clean` | Final correctness/hygiene pass on a plan |

---

## Sources

- [Jeffrey Emanuel's Prompts](https://jeffreysprompts.com/)
- [Steve Yegge on Iterative Refinement](https://steve-yegge.medium.com/six-new-tips-for-better-coding-with-agents-d4e9c86e42a9)
- [Double Diamond Design Process](<https://en.wikipedia.org/wiki/Double_Diamond_(design_process_model)>)
