---
name: ac-plan-lab
accessory: true
description: 'Use to deeply pressure-test and elevate a written implementation PLAN, roadmap, or strategy (steps/timelines/resources) — two modes: GENIUS forensic first-principles critique (find flaws, stress-test assumptions, reconstruct) and ALIEN paradigm transcendence (escape the frame, cross-domain transplants, future-proof). A review gate in the planning chain. Triggers: ''genius review the plan'', ''pressure-test this plan'', ''find flaws in the plan'', ''forensic plan review'', ''transcend this plan'', ''push the plan deeper'', ''alien perspective on the plan'', ''escape local optima on this plan'', ''what is the plan missing''. For a raw idea or concept (no execution steps) use ac-idea-lab.'
---

# Plan Lab — deep analysis for implementation plans

Two modes for pressure-testing and elevating a written plan, roadmap, or strategy:

- **Genius** — forensic first-principles critique: understand the plan completely, then find the one critical flaw, stress-test every assumption (execution sequencing, resource realism, failure modes, milestones), and reconstruct a hardened version.
- **Alien** — paradigm transcendence: shed human cognitive defaults, dissolve the frame, transplant structures from other domains, and future-proof the plan beyond conventional analysis.

First: if an AGENTS.md file exists, read it for project context, architecture, and conventions.

## Pick the mode

If the trigger already implies a direction, go straight there — genius-review / pressure-test / find-flaws / forensic → **Genius**; transcend / push-deeper / alien / escape-local-optima → **Alien**. If it's ambiguous, ask:

```
AskUserQuestion:
  question: "Which direction for this plan?"
  header: "Mode"
  options:
    - label: "Genius — critique & harden"
      description: "Forensic first-principles review: execution sequencing, resource realism, failure modes, then reconstruct a hardened plan."
    - label: "Alien — transcend & future-proof"
      description: "Break the paradigm: dissolve the frame, transplant structures from other domains, design for future capabilities."
  multiSelect: false
```

Then **load and follow the chosen mode's reference in full**:

- Genius → read `references/genius.md`
- Alien → read `references/alien.md`

Two-stage pipeline when warranted: Genius first (perfect within the paradigm), then Alien (transcend it).

## Write back to the plan file (BOTH modes)

This is a gate in the planning chain, not a standalone chat exercise — the improved plan must land back in the plan file, or the next stage never sees it. After the chosen mode's Output steps 1–4:

1. **Edit the plan file in place** (Edit tool, not a rewrite) with the integrated changes — auto-applied critical items plus any user-selected ones. Append a brief findings section (or update it if present) so a future reader doesn't need this session's transcript:
   - Genius mode → `## Genius Review Findings`
   - Alien mode → `## Transcendence Findings`
2. **Update the plan's YAML frontmatter** — add or update the mode's stamp, preserving all other existing fields (`status`, `source_backlog`, `refinement_rounds`, etc.) as-is:
   - Genius → `genius_reviewed: YYYY-MM-DD`
   - Alien → `transcended: YYYY-MM-DD` (preserve any existing `genius_reviewed:`)
3. **Safety check and commit:**
   ```bash
   git status --short
   ```
   If any deletions (`D`) appear that you didn't intend, STOP and confirm with the user before proceeding.
Git discipline: `ac-pipeline/references/commit-discipline.md` — pathspec-only commits, no wildcard adds / stash, commit=push, deletion check. <!-- net-growth-ok: ac-gcj.7 Pass C canon binding -->

   ```bash
   git add "$PLAN_FILE"
   git commit -m "docs(plan): <genius review — {N} fixes | alien transcendence — {N} insights> integrated

   Plan: {PLAN_FILE}
   Auto-applied: {critical count}
   User-selected: {selected count}

   Co-Authored-By: Claude <noreply@anthropic.com>"
   git push
   ```

## When to Use

- Before committing to a major implementation effort
- When evaluating project plans, feature roadmaps, or strategic initiatives
- When something "feels right" but hasn't been stress-tested, or when timeline/resource constraints feel aggressive
- When conventional planning feels complete but insufficient, or the real leverage lives outside the current frame
- **Ordering:** runs AFTER `/ac-plan-refine-internal` / `/ac-plan-clean` (plan is already settled and hygienic) and BEFORE `/ac-beadify` (beads are cut from the pressure-tested version) — a review gate in the planning chain, not a detour. When running both modes, Genius precedes Alien.
