# Disposition doctrine (shared)

Every stage that generates findings, lessons, or proposals faces the same fork: **apply it,
route it to the human, or drop it.** This page is the single statement of that rule, so the
answer stops being re-invented per skill. Domain instantiations stay local
(`review-consensus.md` for code findings, `ac-land` Phase 3 + `reflect` for lessons and
system upgrades, `ac-triage` for external signal) — they cite this and must not contradict it.

> **Loop-retro instantiation:** `ac-land` Phase 3 § "Loop-retro friction disposition (D3)" maps the loop's per-run friction items onto this fork (T1 bug → AUTO · T2 improvement → HUMAN, with an objective bar + one-per-land cap · T3 → AUTO memory-observation or DISREGARD) — a specialization that adds gates, never redefines the rule.

## The three-way rule

**1. Evidence bar first → DISREGARD.** No concrete, named cost this session (a specific
moment where time/tokens were lost, or an externally confirmed defect) → drop it silently.
Never file speculation "just in case" — the disregard step exists so the human isn't the
noise filter.

**2. AUTO — safe by construction, not by confidence.** Auto-apply when either holds:

- **Downstream validation exists.** The change rides a branch through tests / CI / review /
  merge — auto is safe because auto isn't final. (Why `review-consensus.md` defaults
  `AUTO_IMPLEMENT`.)
- **Additive + reversible knowledge.** Facts / rules / decision records / recipes into the
  git-tracked memory substrate change no behavior — worst case they sit unread. (Why
  `reflect` auto-writes them.)

Bias AUTO — mechanically-determined fixes belong in the pipeline, not at a human gate
(memory: `prefer-bug-lane-over-human-gate-for-mechanical-fixes`).

**3. HUMAN — ungated behavior change, or the call isn't the agent's to make.** Route to the
human when applying it would edit live agent policy with **no downstream gate** (SKILL.md,
AGENTS.md / CLAUDE.md, CORE, hooks, workflow doctrine — the next scheduled run simply obeys
it), or when the decision needs human values / authorization (genuine design forks,
sensitive-prod actions).

## Save-for-later (the HUMAN mechanics)

**HUMAN means a decision bead — full stop.** Per `bead-conventions.md` § Decision beads:
`-t decision`, labels `human-gate,skill-improvement` (for system-upgrade proposals), P3,
pre-staged memo (target file · session evidence · exact proposed diff · recommendation).
It surfaces on the `ac-human-session` docket and cannot be lost.

- **Headless:** never `AskUserQuestion`, and **never Slack as a decision's storage** — Slack
  is for milestone notifications only; a card that scrolls away is a dropped proposal.
- **Interactive:** you MAY ask live (deciding on the spot beats a round-trip); anything
  unanswered or deferred still becomes a bead before the session ends.
- **Dedupe before filing.** Retrospectives repeat across runs. Check open beads first:
  `br list --status=open --json | jq '[.[] | select(.labels | index("skill-improvement"))]'`
  — same target file + same gist → `br comments add` on the existing bead (note the
  recurrence; recurrence is signal), do NOT create a duplicate.
