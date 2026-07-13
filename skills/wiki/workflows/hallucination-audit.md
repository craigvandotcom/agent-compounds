# Monthly hallucination audit

**Use when:** the monthly scheduled cadence (`infrastructure/jobs/monthly.json`,
"Wiki - Monthly Hallucination Audit") — not a manual/on-demand workflow, though it can be
run ad hoc ("audit the wiki for hallucinations", "run the hallucination audit").

**Why this exists:** the wiki's THE CITATION RULE (`../SKILL.md`) is enforced at *write*
time — an agent drafting or updating a page is supposed to cite every claim. This
workflow is the *read-time*, independent check that those citations still trace to real
content — the countermeasure named for the specific failure mode in
`references/research-basis.md`'s anti-patterns table: **hallucination laundering**
(the same process reads and writes the KB, so a hallucination can compound into "truth"
across successive edits). "While trust is established" (per
`infrastructure/plans/memory-wiki-upgrade.md` Phase 4 item 3) — this cadence exists
because the wiki is young; it is not assumed to be a permanent need, but it does not
retire itself either — a future decision to relax it is Craig's, made on evidence from
several clean audits, not a default.

**Relationship to other passes:** distinct from `garden.md`'s citation-audit pass (which
samples pages generally for citation *hygiene* — dead links, missing citations) and from
`dream`'s `references/lint-checks.md` check 11 (wiki↔facts contradiction — a *systematic*
sweep of every citation on every page, run weekly by the dream cycle). This workflow is
narrower and stricter: a small, truly random sample, traced by hand, monthly — the
adversarial spot-check that complements dream's exhaustive-but-shallower weekly pass.

## Steps

1. **Sample.** From every `status: draft` or `status: canonical` page across all live
   wiki domains (`neometa/wiki/` is the only live one today), extract every sentence
   carrying a `[[wikilink]]` citation. Assign each a stable index (page + line number) and
   pick **5 at random** (a simple seeded/uniform draw — the point is unbiased sampling,
   not statistical rigor at this volume). Record the sample list in the audit's output
   (page, line, claim text, cited slug) before tracing anything — committing to the
   sample first prevents post-hoc cherry-picking of easy-to-verify claims.
2. **Trace each claim to its cited source.** For each of the 5: open the cited
   `[[slug]]` (resolves to a `memory/auto/`, `alignment/decisions/`, or another
   `wiki/` note per the cross-home resolution `memory-lint.py` already proves for link
   *validity* — this step checks *content*, not just link existence). Read the source
   and judge: does it actually support the wiki page's claim, faithfully (not
   overstated, not understated, not a claim the source never made)?
3. **Classify each traced claim:**
   - **Traceable, faithful** — no action.
   - **Traceable, but the wiki page overstates/misstates it** — same disposition as
     dream's check 11 (wiki↔facts contradiction): a proposal to fix the wiki page's
     claim, never a silent self-edit.
   - **Untraceable** (the cited source doesn't actually say what the page claims, or the
     citation resolves to a page unrelated to the claim) — this is the hallucination-
     laundering signal. **Becomes a proposal bead**, per
     `[[rule-proposals-become-beads]]` — never an auto-edit, and never silently dropped
     from the report. File via the same mechanism as any dream/wiki proposal: `br
     create` in the repo the wiki page lives in (today, root — `neometa/wiki/` is
     inside the root repo), type `decision`, labels `human-gate,dream-proposal`,
     description naming the page/line/claim and why it's untraceable.
4. **Tighten the rules, don't just fix the instance.** If ≥1 of the 5 comes back
   untraceable, that is a signal about the *process*, not just that one page — ask
   whether the wiki skill's citation discipline (SKILL.md's THE CITATION RULE, the
   create-vs-update judgment, the `status: draft` review gate) needs a sharper edge, not
   just a one-off fix. Propose the skill edit the same way (a `skill-improvement`
   proposal → bead), don't hand-edit `SKILL.md` directly from this workflow.
5. **Record the run.** Whether the sample came back clean or not, this is a first-class
   valid outcome either way (mirrors the dream cycle's "a quiet week is not a failure"
   doctrine) — write a one-paragraph note (page: audit date, sample of 5 with
   disposition, any beads filed) somewhere durable so trend-over-time is visible later
   (e.g. append to a running log if/when this audit accumulates enough runs to warrant
   one — for the first several runs, the beads filed + this workflow's own git history
   are the record; don't build a dashboard for n<5 runs).

## Output

A report: the 5 sampled claims, each traced and classified, any proposal beads filed
(untraceable claims or overstated/misstated claims), and — if the sample surfaced a
process gap — a flagged follow-up on the wiki skill's own citation discipline (never a
direct self-edit of `SKILL.md` from inside this audit).
