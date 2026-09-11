# ac-land Phase 3 — compound mechanics

<!-- mirror: ac-pipeline/references/disposition.md § the three-way rule · skill-builder/references/friction-capture.md § routing -- edit there first -->

## Loop-retro friction disposition (D3) — the full tier router

**ac-land Phase 3 is the SOLE tier router.** When Phase 0 read a non-empty loop-retro carrier,
classify **each** friction item into one of three tiers BEFORE the Step 0 `reflect` delegation
below, and execute T1/T2 here directly — `reflect` never re-decides a tier (it only writes the
T3 subset this router hands it). This is a **citing specialization** of `ac-pipeline/references/disposition.md`'s
core three-way rule (DISREGARD / AUTO / HUMAN — that page § "The three-way rule"): it
MAPS the tiers onto that fork and ADDS gates; it never redefines the fork.

| Tier | disposition.md route | What ac-land does here | Extra gate |
|---|---|---|---|
| **T1 bug/defect** | AUTO (rides a bead→CI gate; auto isn't final — §2) | `br create -t bug --labels origin:ac-land,unrefined` immediately — dedupe-first per 1a's rule (same file, § File Remaining Work) | none — **never rate-limited** (matches the Rule-0 bug lane); the T2 cap does NOT apply to bugs |
| **T2 high-impact improvement** | HUMAN (ungated policy change — §3) | `br create -t decision … -l origin:ac-land,human-gate,skill-improvement` via the existing mechanism below | **objective bar** + **one-per-land cap** |
| **T3 everything else** | AUTO additive-knowledge (§2), else DISREGARD (§1) | tag for the Step 0 reflect call → keyed observation (bd-jv33f.5), or drop if zero evidence | reversible memory observation only |

**Deletion mandate — supersession ranks equally with addition.** When a T1/T2/T3 item
SUPERSEDES or contradicts existing skill content (not just adds to it), the disposition
MUST also consider removing/demoting the stale content, not only filing the new lesson —
`skill-builder/references/promotion-ladder.md` ranks the two moves equally, never
addition-plus-optional-cleanup. Removal of unique content routes through the skill's
`MAINTENANCE.md` holding-pen (that doc's holding-zone rule), not an outright delete; a
verbatim duplicate may still hard-delete immediately.

**T3 sub-route — skill-scoped friction vs general lesson (W4.3).** Before handing a T3 item
to `reflect` in Step 0, tag it as either *skill-scoped friction* (about a specific skill's
operation — its `stage` names a skill, or the narrative clearly targets one) or a *general
lesson*. Skill-scoped friction's destination is `skills/<skill>/FRICTIONS.md`; general lessons
go to the substrate's general sink — `reflect` executes the write (see its Step 5 disposition
branch); this is only the classification tag ac-land hands across. Apply
`skill-builder/references/friction-capture.md` § Routing's ambiguity defaults **verbatim**:

- Uncertain, loop-mechanics-flavored → default sink is `ac-pipeline`'s `FRICTIONS.md`.
- Uncertain, general → the substrate's general sink (unchanged from today).
- Genuinely cross-cutting → primary skill's `FRICTIONS.md`, `see <id> in <primary>` pointer
  entry in each secondary skill's file (never a full copy).

Schema, per-skill template, and the dedup rule (reuse-id-and-bump-recurrence vs mint-new) are
`friction-capture.md`'s — don't restate them here; create the target `FRICTIONS.md` lazily
from that reference's template if absent.

**T2 objective bar** — an improvement clears iff EITHER:
- **recurrence evidenced** — a matching observation/lesson already exists in the substrate
  (`qmd search` hit), OR a matching open `skill-improvement` bead exists (the Save-for-later
  dedupe check, disposition.md § Save-for-later); OR
- **material per-run cost** — a named this-run cost: a confirmed defect, or a friction item
  marked `cost: material`.

**Per-land cap = 1.** If more than one candidate clears the bar, file the **highest-cost** one as
the single T2 improvement bead and **demote the rest to T3 observations** — their recurrence
still accrues for full-corpus ranking (nothing lost, just deferred). T1 bugs are exempt from
the cap.

**Ordering (the sole-reflect-call rule):** (1) classify every carrier item
into T1/T2/T3; (2) create T1 bug beads + the ≤1 T2 decision bead here — no `reflect`
involvement; (3) **loop-driven** (the Exit-Land prompt says the conductor spawns
reflect): SKIP the Step 0 `reflect` delegation — return the pre-classified T3 subset +
skill-scoped tags in your summary. **Standalone**: hand the T3 subset to the single
Step 0 `reflect` invocation below. Either way: one reflect per run, never two.
Absent/empty carrier → no tiering; Step 0 (standalone) runs as normal.

## Disposition — classify, then route by mode

Classify each surviving proposal per `ac-pipeline/references/disposition.md`:

- **DISREGARD** — no concrete, named waste this session → drop silently (most proposals).
- **AUTO** — pure knowledge (fact / rule / decision / recipe) → already captured by
  `reflect` in Step 0; nothing further here.
- **HUMAN** — system-file change (skills, AGENTS.md, CLAUDE.md, CORE, hooks, workflows) →
  route by mode below.

**Interactive session** → present + `AskUserQuestion` (next two subsections).

**Headless (loop-driven land)** → NEVER `AskUserQuestion` and **NEVER post proposals to
Slack** — a Slack card is not a decision's storage; Slack stays notification-only. File each
HUMAN item as a decision bead per `ac-pipeline/references/disposition.md` § Save-for-later, **dedupe
first** (same target file + gist as an open `skill-improvement` bead → comment on it
instead), then skip ahead to Commit Compound Changes:

```bash
br create -t decision -p 3 "Proposal: <title> (<target file>)" -l origin:ac-land,human-gate,skill-improvement \
  -d "## Decision memo
**Target:** <file path>
Gate-reason: fork — apply / apply-modified / drop is a policy change only the human ratifies
**Evidence (this session):** <what happened + concrete cost>
**Proposed change:**
<exact diff or content>
**Recommendation:** <apply / apply-modified / drop>"
```

It surfaces on the `ac-human` docket; the human decides there.

## Present upgrades to the user

Output each upgrade opportunity so the user can see the details:

```
## Upgrade N: <title>
**Severity:** Critical | High | Medium | Low
**Target:** <file path>
**Evidence:** <what happened this session>
**Proposed Change:**
<exact diff or content to add/modify/remove>
```

Group by severity (Critical first, Low last). Present ALL of them.

Then use `AskUserQuestion` with `multiSelect: true` to let the user pick interactively:

```
AskUserQuestion(
  questions: [{
    question: "Which system upgrades should I apply?",
    header: "Compound",
    multiSelect: true,
    options: [
      { label: "Upgrade 1: <title>", description: "Critical — <one-line summary>" },
      { label: "Upgrade 2: <title>", description: "High — <one-line summary>" },
      { label: "Upgrade 3: <title>", description: "Medium — <one-line summary>" },
      ...up to 4 options per question (AskUserQuestion limit)
    ]
  }]
)
```

**If more than 4 upgrades:** Split across multiple `AskUserQuestion` calls grouped by severity.
Critical+High in the first question, Medium+Low in the second. The user can always select
"Other" to provide custom input (skip all, apply all, etc.).

## Apply approved upgrades

> **Apply-path routing split (this inline path is the `skill-hotfix:` hotfix hatch).**
> This inline path exists for **same-session, user-APPROVED** upgrades — it applies them
> immediately and traceably (via the `skill-hotfix:` commit-prefix hatch, defined under
> Commit Compound Changes below) across **every** target class in the table below (skill
> files AND `AGENTS.md` / `CLAUDE.md` / `MEMORY.md`). **`dream` is PRIMARY** — but only
> for *proposal-originated* edits (unreviewed/accumulated edit proposals it emits and
> later applies in REVIEW mode). "dream is primary" does NOT make it a router for
> already-approved same-session work: that work legitimately stays here, on the hatch.
> This hatch owns approved same-session hotfixes for all four target classes; dream owns
> proposals. (Mirrored in `skills/dream/SKILL.md`.)

For each approved upgrade, apply the edit directly. Common targets:

| Target                | What Gets Updated                      |
| --------------------- | -------------------------------------- |
| `AGENTS.md`           | Workflow improvements, new conventions |
| `CLAUDE.md`           | Orchestrator context updates           |
| `.claude/skills/*.md` | Default lands in the skill's `references/`, its `FRICTIONS.md`, or the substrate's general sink — **never the SKILL.md spine by default.** Core insertion needs the promotion-ladder proof gate (N green runs / probe-verified fact / sign-off for conductor-core — `skill-builder/references/promotion-ladder.md`), not a default landing here. |
| `MEMORY.md`           | New patterns, gotchas, workflow notes  |

## Commit compound changes

**Commit-prefix is CONDITIONAL — `skill-hotfix:` for the approved-upgrade case, `chore:`
for routine-only.** This land-session compound commit carries BOTH routine
retrospective/memory-substrate saves (the common case, fires every land) AND any doctrine
edits the Apply-Approved-Upgrades hatch applied this session. **When ≥1 approved
doctrine/skill/memory upgrade was actually applied this session** (any of the four target
classes in the Apply-Approved-Upgrades table — skill files, `AGENTS.md`, `CLAUDE.md`,
`MEMORY.md`), **EMIT the commit with a `skill-hotfix:` prefix** so the out-of-band apply is
greppable by dream's Phase 5 dedupe (`git log --grep='^skill-hotfix' -- <target_file>`).
**A land with no approved upgrade (routine compound/reflect-only saves) keeps `chore:`** —
do NOT blanket-relabel every land-session commit, or you pollute the exact dedupe signal
dream keys on.

```bash
git add <specific files>
# Approved-upgrade case (≥1 hatch apply this session — any target class):
git commit -m "skill-hotfix: compound learnings + applied N system upgrades from retrospective

Co-Authored-By: Claude <noreply@anthropic.com>"
# Routine / no-upgrade case (compound + reflect saves only, no hatch apply):
#   git commit -m "chore: compound learnings from bead-work session ..."
git push
```

Advisory (not mandated): you MAY commit the Apply-Approved-Upgrades edits SEPARATELY from
routine compounding so the `skill-hotfix:` commit touches exactly the edited `target_file` —
a cleaner per-file signal for dream's `git log --grep='^skill-hotfix' -- <target_file>`.
Either one-commit-conditional or split-commit satisfies the convention.

Mark ledger task 6 `completed`; `TaskUpdate` task 7 `in_progress`.