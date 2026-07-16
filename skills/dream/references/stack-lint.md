# Hot-lane lint — the L0–L2 semantic checklist (dream Phase 3)

Sweep targets: the **hot lane** — every-turn context across the stack. L0 entry files
(`AGENTS.md` / `CLAUDE.md` at repo-root, `neometa/`, `neometa/software/`, and each app),
L1 CORE (`.claude/skills/CORE/SKILL.md` where present), L2 skills + agents (the
agent-compounds registry and its projections), and the hook-injected files that ride the
hot lane every prompt (`hooks/delegation-reminder.md`, session-start, etc.). The memory
substrate (L3) is a **read-only citation target** here — its own hygiene is
`lint-checks.md` (the sibling substrate sweep); this file never rewrites a memory note.

Every finding → **a GATED proposal**. This is the load-bearing rule of the hot lane:
**L0–L2 changes never auto-apply**, regardless of how mechanical they look
(`context-engineering` PLACEMENT: "L0–L2 changes are gated, rare"). A stale line in a
hot-lane file propagates to *every* session, so the blast radius earns a human read
before any edit. Emit each finding as a proposal (`category: lint-fix`, or `re-home` when
the fix is *relocating* content to a lower layer/altitude) and let Phase 4 judge it like
everything else. Never edit a hot-lane file inside the lint phase.

**Mechanical counterpart:** `infrastructure/tools/bin/hot-lane-lint` (run it first). It
owns the *binary* checks — a referenced pointer path that doesn't exist, a broken
projection symlink, the regeneration test (`harness-sync.sh --all --check`), and the
budget/roster warnings (L0 >150 lines, CORE >200, roster-vs-disk, app-list drift, missing
recall hook). This file owns the checks that need a *reading agent's judgment* and can't
be reduced to a grep. Run the mechanical pass, fold its `--json` findings into the cycle
`INDEX.md`, then do the semantic sweep below on top. **Source standard for both:**
`../../context-engineering/references/conformance-checklist.md` (§L0 / §L1 / §L2 / §Hooks
/ §Projections / §Cross-cutting) — alignment is *maintained* here, never re-established.

Karpathy's lint framing (same as the substrate sweep): this is the step teams skip and
the one that stops compounding errors. Hot-lane rot is silent — nothing breaks, every
session just quietly reads a lie.

## Semantic vs mechanical (where the line is)

The mechanical pass proves a pointer *resolves*; the semantic pass judges whether the
line *should be there at all*. `hot-lane-lint` can tell you `AGENTS.md` is 169 lines; only
a reading agent can tell you *which* 30 lines are a domain playbook that belongs in a
skill. Budget most of the lint phase here — the grep half is seconds.

## Checks

Each check is a judgment a reading agent makes against the live tree, top to bottom.
Cite file+line for every finding (the conformance-checklist contract). Every finding is
**gated** — see the header; the reminder is not repeated per check.

1. **Altitude** — L0/L1 content sitting at the wrong *layer or scope*. A domain playbook,
   a weekly-changing detail, an incident write-up, an OAuth-gotcha section, a
   step-by-step workflow living in an entry file or CORE is a violation (§L0: "pointers,
   not content … an OAuth gotcha section is a violation"; §L1: "no learnings
   accumulating"). Two directions, both bugs: content raised **too high** (an
   app-specific quirk in `software/AGENTS.md` → pollutes every project's context) and
   content that should sink a *layer* (a procedure in L0 that a skill's `workflows/`
   should hold). Propose: move the payload to its named destination on the PLACEMENT
   ladder, leave a one-line pointer if the trigger isn't self-evident (the
   trigger/payload split — promote the pointer, never the payload). Distinct from the
   substrate sweep's cross-altitude check (that dedupes *facts*; this relocates
   *instructions* off the hot lane). Reference: `context-engineering` PLACEMENT +
   ALTITUDE (check 6 below cites the rungs).

2. **No learnings in the hot lane** — an accumulated learning, gotcha, "we discovered
   that…", or dated incident note living in an L0 file, a CORE, or a hook-injected file
   (`delegation-reminder.md` and friends). These are L3 memory content that drifted up
   (§L1: "no learnings accumulating (cold-lane content)"; §Hooks: injected-every-prompt
   files are hot-lane context — B6 found one mandating a deactivated memory system and
   retired agents *months* after both changed). The tell: a line that reads like
   experience rather than identity/convention. Propose: route it through WRITE to the
   memory substrate (PLACEMENT rung 0 — "≈all dream output"), leave nothing behind but a
   pointer if the hot lane genuinely needs to know it exists. This is the check that most
   directly protects the every-session context from becoming a changelog.

3. **Skill selectability** — a skill or agent `description:` that states **HOW** (a
   workflow summary, an implementation note) instead of **WHEN** (the triggers). It fails
   the **selectability test**: a cold agent reading *only* the description, with no other
   context, must pick this skill correctly for the situations it owns and not for others
   (§L2). Read the description cold and ask "from this alone, would I know to invoke it —
   and would I know *not* to when it doesn't apply?". A description that's a mini-README,
   that leads with mechanism, or whose triggers overlap another skill's, is a finding.
   Propose: a rewrite that front-loads triggers (keywords, task shapes, lifecycle moments)
   and moves the how into the body. The registry description budget is mechanical
   (`hot-lane-lint` / `validate-skill.sh --registry`); *quality* of the trigger is here.

4. **Task overlap** — two skills, or two agents, or a skill and an agent, claiming the
   **same task** (§L2: "No two entries claim the same task — check against the registry";
   Agents: "no agent duplicating a skill's domain"). Check each candidate against the
   full registry (`agent-compounds/README.md` + the skills/agents dirs), not just its
   neighbours. Overlap is a selectability bug one level up: if two descriptions both fit a
   situation, the cold agent can't choose. Propose: merge, or draw a sharp boundary in
   both descriptions (name the sibling and the split), or retire the redundant one.
   Watch specifically for an **agent** that has absorbed domain knowledge a skill already
   owns (fat skills, thin agents — the agent should carry stance + tools + model only).

5. **Stale claims** — a "current"/"now"/"as of" statement in an L0–L2 file that the live
   tree contradicts, or a superseded statement not marked as such (§Cross-cutting: "Any
   superseded statement is edited in place or explicitly marked superseded — stale
   'current' claims … are violations"; "Claims about sizes, paths, and behaviors verified
   against disk, not inherited"). Cross-check every load-bearing claim against reality:
   does the portfolio table match the apps that exist, does "run X first" name a live
   command, does a cited line count still hold, is a "scaffolded/retired" status still
   true. A path cited explicitly as *history* (retired/archived/superseded) is legitimate
   and not a finding — the mechanical pass already skips those lines; here, judge whether
   an *unmarked* claim has quietly gone false. Propose: edit in place to the current
   truth, or add the explicit `superseded` marker (decay, don't silently delete).

6. **Placement-ladder violations** — content that sits in a layer the PLACEMENT ladder
   would route elsewhere, judged against the ladder itself rather than restated here.
   Walk the rungs in `context-engineering` SKILL.md §PLACEMENT (rung 0 → L3 memory; rung 1
   → skill; rung 1h → hook; rung 2 → L0/CORE; rung 3 → subagent prompt) and its overrides
   (trigger/payload split; volatility → pointer + L3; L0-vs-CORE leak rule). A finding is
   any hot-lane line that *could drop a rung* and still be present when needed — the
   ladder's own "cleanup rubric: every always-on line earns its rung or sinks". Common
   shapes: agnostic content stuck in a per-agent CORE (a leak — invisible to other
   agents); a volatile-but-relevant value hardcoded high instead of pointer-high /
   content-in-L3; a deterministic-trigger rule narrated in prose that a hook should carry.
   Propose: the specific lower rung + the pointer to leave behind. **Cite the rungs; do
   not re-derive them** — `context-engineering` is the single source and changes there.

## How this composes with the rest of Phase 3

- Run `hot-lane-lint` (mechanical) first; its HARD failures are genuine breakage (fix via
  a proposal too, but they're unambiguous), its WARNs (budget/roster/drift/regen) seed the
  altitude and stale-claim reads above with concrete line numbers.
- Then sweep checks 1–6 by *reading* the hot-lane files the mechanical pass flagged, plus
  a rotation of the ones it didn't (a green mechanical pass is not a green semantic pass).
- Every finding → a gated proposal in today's `proposals/<date>/`, judged in Phase 4.
  Fold both the mechanical `--json` summary and the semantic findings into `INDEX.md`.

The substrate sweep (`lint-checks.md`) and this hot-lane sweep are the two halves of
Phase 3: that one keeps the *cold* lane (memory) honest, this one keeps the *hot* lane
(every-turn context) honest. Neither auto-applies to L0–L2; both decay rather than erase.
