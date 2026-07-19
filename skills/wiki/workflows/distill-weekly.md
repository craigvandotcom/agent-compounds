# Weekly distillation

**Use when:** the weekly review's distillation cadence — folding the week's decisions
into `STRATEGY.md`'s decisions log and refreshing `NOW.md`. Hooks into the existing
weekly-review workflow; this file is the wiki-side half of that cadence, not a
replacement for it.

**Where this hooks in:** `.claude/skills/strategist/workflows/weekly-review.md` step 10
("Capture Lessons") already routes strategic-pattern synthesis into the review's own
Alignment Check section (step 6) rather than forcing it into a fact file, and notes:
"from Phase 3 onward, the weekly distillation cadence additionally feeds
`alignment/STRATEGY.md`'s decisions log." This workflow is that promise, made concrete.

## Steps

1. **Read the week's review.** `alignment/reviews/weekly/<this-week>.md` (already
   written by weekly-review.md's own steps 1-9) — the Alignment Check section (step 6)
   is the primary source: the ONE-lever-per-channel calls, ship-event decisions, stage
   advancements.
2. **Extract decisions log entries.** Any Alignment Check item that is a genuine
   decision (a choice + rationale + consequence, not just a status note) → append to
   `alignment/STRATEGY.md`'s decisions log, dated, one entry per decision. Don't
   rewrite prior entries — append-only, same discipline as canonical facts.
3. **Refresh NOW.md.** Update against "stale lines are worse than missing lines" (the
   rule NOW.md already carries) — remove anything the week's review superseded, add
   what's now current. This is an edit-in-place, not an append.
4. **Fix `neometa/alignment/README.md`'s front door** if this week's changes created a
   new dead reference (the org-level file — distinct from the root `alignment/` debris
   already removed in Phase 2c). Check its links resolve.
5. **Wiki-page touch-check.** Does this week's decisions-log addition change or
   contradict a claim on any existing `neometa/wiki/` page? If yes → that page needs an
   update (route through `garden.md`'s dedupe/citation passes, or `seed-page.md` if the
   decision opens a genuinely new concept with no page yet). Update means appending a
   dated Timeline entry (below the page's `--- <!-- timeline -->` divider) recording what
   changed and why, then revising Compiled Truth from it — never a silent in-place
   rewrite of the ratified prose. If no wiki page exists yet to house it, don't force
   one — STRATEGY.md's decisions log is itself a valid, already durable home; only
   promote to a wiki page when the material has outgrown a log entry (recurring +
   stable + broadly applicable — same bar as any L3→L2 promotion, context-engineering
   PROMOTION & DEMOTION).

## Output

STRATEGY.md decisions log has this week's entries; NOW.md is current; any wiki pages
touched have a new Timeline entry (never a silent rewrite) and are flagged `status:
draft` again if their canonical claims changed (re-review needed) or left `canonical`
if only a citation/related-link was added.
