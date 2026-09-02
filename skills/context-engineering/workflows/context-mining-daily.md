# Context Mining - Daily Run

## THIS PROMPT IS YOUR TASK - EXECUTE IMMEDIATELY

You are invoked at 01:30 daily (root-level scheduled procedure — memory-wiki-upgrade
Phase 2c retired the persistent per-level agent pattern; identity now loads from
`skills/CORE/`, this is pure procedure) for context mining (Phase 2.v2). Execute this
workflow now.

Architecture: `neometa/alignment/decisions/2026-06-26-tiered-memory-autonomy.md` (Loop 1 —
Capture backstop + Loop 2 — Tier-0 daily hygiene). You are the **daily backstop**: in-session
`reflect` is the primary capture; you catch what it missed and run the cheap, lossless hygiene.

## Your Task

Mine the last 24 hours for uncaptured lessons, then emit the mechanical hygiene the 02:00
queue job can auto-apply.

### 1. Gather Git Changes
```bash
git log --all --since="24 hours ago" --oneline
```
Collect commits from infrastructure, neometa, content, software/* repos.

### 2. Reflect-gap detection (the capture backstop)
Some sessions do real work — or make a decision in pure conversation — and never run
`reflect`. A no-file-touch session leaves NO git signal, so step 1 can't see it. List the
substantive-but-unreflected sessions deterministically:
```bash
/usr/bin/python3 infrastructure/dream-cycle/reflect_gap.py --hours 24
```
After the mining agents return, mark what you mined so tomorrow's run does not pay for it
again — the ledger exists (`infrastructure/dream-cycle/mined-sessions.json`) but only fills
if you call it:
```bash
/usr/bin/python3 infrastructure/dream-cycle/reflect_gap.py --hours 24 --record
```
A session re-flags only if it gained new turns since (the ledger keys on `last_ts`), so this
is safe. Use `--remine` to deliberately re-list an already-mined session.

Each `GAP` line is a session that did work but captured nothing. **Mine those transcripts**
(read the `.jsonl` paths printed) for lessons — do NOT try to "re-run reflect" on them, the
live context is gone; the transcript is all that remains. Fold any lessons found into the
candidates from step 1. For sessions marked `headless`, read only the final assistant message; open the full
transcript only when that summary reports a surprise or a failure. Never skip one
outright — under-flagging loses a lesson.

### 3. Check Structured Memory
Review recent writes in:
- infrastructure/memory/auto/
- neometa/memory/auto/
- neometa/alignment/decisions/

### 4. Extract Signals
Find learning opportunities:
- Errors resolved → debugging patterns
- Decisions made → architecture choices
- Patterns repeated → automation candidates
- Facts discovered → system behaviors
- Rules formed → "always do X when Y"
- Recipes proven → reusable sequences

### 5. Deduplicate
For each candidate, check if already known:
```bash
qmd search "<pattern>"
```

### 6. Classify & Stage
For genuinely new lessons:
- Classify: {fact, rule, decision, skill-improvement, recipe} × {neoMeta, personal, global, app-local}
- Write to `infrastructure/context-mining/daily/<YYYY-MM-DD>/`
- Include evidence and outcome grounding

### 7. Tier-0 daily hygiene (mechanical, lossless — emit for the 02:00 auto-apply)
Substrate lint is split by reversibility (the decision doc): **semantic lint stays weekly**
(contradiction, staleness, near-duplicate *merges* — all Tier-2, gated). Only the **Tier-0
mechanical** checks run daily, because they are lossless and the script can re-derive them.

Today's Tier-0 check: **index drift** — a `MEMORY.md` line pointing at a note file that no
longer exists. Detect it per home:
```bash
for home in infrastructure/memory/auto neometa/memory/auto \
            neometa/software/*/memory/auto; do
  [ -f "$home/MEMORY.md" ] || continue
  # index slugs whose target file is absent = dangling lines
  # `command` prefixes are REQUIRED: on Craig's Mac `tr` is an alias for
  # `tmux new-session -A -s repos` and `grep` is a Claude Code function — bare `tr`
  # emits nothing in a non-TTY shell, which silently zeroes the left operand and makes
  # this check report "0 drift" unconditionally. Also drop `slug.md`: it is the
  # format-doc example on line 3 of most MEMORY.md files, not an index line.
  # The slug class MUST be `[a-zA-Z0-9_-]`: notes use snake_case (`feedback_*`,
  # `reference_*`, `project_*`) and camelCase symbols (`...-getZoneClassifierPrompt.md`).
  # A narrower class drops them from the LEFT operand — never drift-checked, and
  # phantom "orphans" under the reverse `comm -13`.
  comm -23 \
    <(command grep -oE '\(([a-zA-Z0-9_-]+\.md)\)' "$home/MEMORY.md" | command tr -d '()' \
        | command grep -vx 'slug.md' | sort -u) \
    <(ls "$home" | command grep -vE 'MEMORY|README' | sort -u)
done
```
Sanity-check before trusting a "0 drift" result: the left operand should be non-empty
(`… | wc -l` ≈ the number of index lines). An empty left operand means the pipeline broke,
not that the index is clean.
For each home with dangling lines, **emit an `index-prune` proposal** into today's dream
queue (`infrastructure/dream-cycle/proposals/<YYYY-MM-DD>/`) so the 02:00 job auto-applies it.
Frontmatter the classifier requires (`infrastructure/dream-cycle/classify.py` is the authority
— it re-derives and applies the prune itself, you only flag it):
```markdown
---
status: pending
category: lint-fix
lint_subtype: index-prune
target_repo: root            # only root-memory homes auto-apply; app-local → note it for the human
target_file: <home>/MEMORY.md
evidence: [dangling index lines: <slugs>]
---
## What
<paste the FULL re-derived MEMORY.md with the dangling lines removed, inside a ``` fence>
```
Only root-memory homes (`infrastructure/memory/auto/`) auto-apply; for an app-local home with
drift, surface it in the report for the human instead (repo-boundary + altitude rules).
If no home has drift, skip — emit nothing.

### 8. Generate Report
Save extraction summary to `infrastructure/health/reports/context-<date>.json`:
- Candidates found / Lessons extracted / Duplicates skipped
- Reflect-gaps: sessions scanned, gaps found, gaps mined
- Tier-0 hygiene: index-prune proposals emitted (homes + dangling slug counts)

### 9. Notify Slack — MANDATORY, DO THIS LAST, DO NOT SKIP
Actually run the CLI (don't describe it). `--status`: `healthy` normally; `degraded` if
gitleaks flagged anything or extraction errored.
```bash
infrastructure/tools/bin/slack-send --channel pi --card \
  --status <healthy|degraded> \
  --title "Context Mining — $(date +%Y-%m-%d)" \
  --field "Extracted=<N>" --field "Gaps mined=<N>" \
  --field "Dupes skipped=<N>" --field "Index-prunes=<N>" \
  --body "<one line: notable lesson + what the gap-scan caught, or 'nothing new'>" \
  --context "01:30 context mining · capture backstop + Tier-0 hygiene"
```
Confirm exit 0; retry once on error. The job is NOT complete until this posts.

## Security
- Run gitleaks check on any extracted content (transcripts are private — scrub before any
  lesson reaches the git-tracked queue)
- Never include secrets in lessons (this includes the Slack card body)
