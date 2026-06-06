---
name: planning
description: Plan creation and iterative refinement using scope oscillation methodology
---

> **Generic skill — method only, zero app facts.** This skill is symlinked from
> agent-compounds and shared across consuming apps. It contains technique and
> patterns, not project specifics. **App specifics (project refs, schema names,
> domain rules, feature flows, env values) → read this app's
> `.claude/skills/CORE/SKILL.md`** (and the `AGENTS.md` summary it indexes).
> Do not add app-specific facts to this file — they belong in CORE.

# Planning Skill

Strategic planning for features and fixes using Jeffrey Emanuel's iterative refinement methodology.

## When to Load This Skill

- Creating implementation plans (`/plan-init`)
- Refining plans through review cycles (`/plan-review`)
- Any task requiring structured planning before implementation

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

Located in `.claude/plans/templates/`:

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

## Related Commands

| Command        | Uses This Skill For                      |
| -------------- | ---------------------------------------- |
| `/plan-init`   | Initial plan creation using templates    |
| `/plan-review` | Iterative refinement using round prompts |

---

## Sources

- [Jeffrey Emanuel's Prompts](https://jeffreysprompts.com/)
- [Steve Yegge on Iterative Refinement](https://steve-yegge.medium.com/six-new-tips-for-better-coding-with-agents-d4e9c86e42a9)
- [Double Diamond Design Process](<https://en.wikipedia.org/wiki/Double_Diamond_(design_process_model)>)
