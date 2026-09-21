# Context Mining - Daily Run

## THIS PROMPT IS YOUR TASK - EXECUTE IMMEDIATELY

You are invoked at 01:30 daily (root-level scheduled procedure — memory-wiki-upgrade
Phase 2c retired the persistent per-level agent pattern; identity now loads from
`skills/CORE/`, this is pure procedure) for context mining (Phase 2.v2). Execute this
workflow now.

Architecture: `<org>/alignment/decisions/2026-06-26-tiered-memory-autonomy.md` (Loop 1 —
Capture backstop + Loop 2 — Tier-0 daily hygiene). You are the **daily backstop**: in-session
`reflect` is the primary capture; you catch what it missed and run the cheap, lossless hygiene.

## Your Task

Mine the last 24 hours for uncaptured lessons, then emit the mechanical hygiene the 02:00
queue job can auto-apply.

### 1. Gather Git Changes
```bash
git log --all --since="24 hours ago" --oneline
```
Collect commits from every repo in scope (global tooling, org, content, software).

### 2. Reflect-gap detection (the capture backstop)
Some sessions do real work — or make a decision in pure conversation — and never run
`reflect`. A no-file-touch session leaves NO git signal, so step 1 can't see it. List the
substantive-but-unreflected sessions deterministically (your deployment's own script —
build one against your session-transcript store; path below is a placeholder):
```bash
python3 <your-deployment>/dream-cycle/reflect_gap.py --hours 24
```
After the mining agents return, mark what you mined so tomorrow's run does not pay for it
again — the ledger exists (`<your-deployment>/dream-cycle/mined-sessions.json`) but only fills
if you call it:
```bash
python3 <your-deployment>/dream-cycle/reflect_gap.py --hours 24 --record
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
Review recent writes in the live memory homes (resolve the actual paths from the
deployment's instance-map — placeholders below, never literals):
- the global memory home
- the org memory home (`<org>/memory/`)
- `<org>/alignment/decisions/`

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

### 6. Classify & Apply
For genuinely new lessons:
- Classify: {fact, rule, decision, skill-improvement, recipe} × {org, personal, global, app-local}
- Write the note into its live memory home and add its `MEMORY.md` index line in the same
  step: `global`/`personal` → the global home · `org` →
  the org home · `app-local` → the app's own memory home, committed inside that repo.
- Never write a lesson to `<your-deployment>/context-mining/daily/<YYYY-MM-DD>/`. Nothing reads
  it — retrieval queries the memory + wiki lobes, so a note left there never injects
  (memory `context-mining-staging-dir-is-write-only`). That dir holds `INDEX.md` only.
- Include evidence and outcome grounding

### 7. Tier-0 daily hygiene (mechanical, lossless — emit for the 02:00 auto-apply)
Substrate lint is split by reversibility (the decision doc): **semantic lint stays weekly**
(contradiction, staleness, near-duplicate *merges* — all Tier-2, gated). Only the **Tier-0
mechanical** checks run daily, because they are lossless and the script can re-derive them.

Today's Tier-0 check: **index drift** — a `MEMORY.md` line pointing at a note file that no
longer exists. Detect it per home:
```bash
# Homes are placeholders — resolve the global home, the org home, and each app
# repo's home from the deployment's instance-map first. DO NOT resolve app homes by
# reading a `factory.json` `memory.root` without first confirming that file exists:
# on omarchine it does not, the convention is `<app>/memory/auto/`, and a run that
# looks for the missing key silently sweeps ZERO app homes and still reports "0 drift"
# across the board. Glob for the real `MEMORY.md` files and count them before trusting
# any result:
#   find <org>/software -maxdepth 4 -path '*/memory/auto/MEMORY.md' -not -path '*/node_modules/*'
# Expect ~8 app homes here (2026-09-21). Zero app homes found is a BUG, not a clean sweep.
for home in <global-memory-home> <org-memory-home> \
            <org>/software/*/memory/auto; do
  [ -f "$home/MEMORY.md" ] || continue
  # index slugs whose target file is absent = dangling lines
  # `command` prefixes are REQUIRED: on the operator's Mac `tr` is an alias for
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
Sanity-check before trusting a "0 drift" result — and make it an EXACT equality, not a
smell test. "Non-empty" is too weak: on 2026-09-15 this check read 293 slugs against a
337-line index and reported 0 drift, then read 337 and reported 17 six minutes later on
the same bytes. A plausible-looking undercount passes "non-empty" and silently hides real
drift. Assert the invariant instead, and refuse the result if it fails:
```bash
lines=$(command grep -c '^- \[' "$home/MEMORY.md")   # index bullets
slugs=$(… the left operand … | wc -l)                 # slugs the pipeline extracted
[ "$slugs" -eq "$lines" ] || echo "BROKEN: extracted $slugs of $lines index lines — do NOT trust the drift count"
```

**Before pruning, prove the content is actually gone.** A dangling index line means the
FILE is absent, not that the LESSON is lost — the prune is only lossless if no copy
survives. Check all three, per slug:
`<your-deployment>/context-mining/daily/*/<slug>.md` (staged, never promoted) · `$home/_archive/`
· `git log -- <memory-home>/auto/<slug>.md`. A slug with a surviving body is a **promotion**, not a
prune: move it into the home (the index line is already correct) and leave it out of the
proposal. On 2026-09-15, 5 of 17 dangling slugs still had their bodies in the 2026-08-25
staging dir — pruning those would have destroyed five real lessons under a "lossless" label.

For each home with genuinely dead lines, **emit an `index-prune` proposal** into today's dream
queue (`<your-deployment>/dream-cycle/proposals/<YYYY-MM-DD>/`) so the 02:00 job auto-applies it.
Frontmatter the classifier requires (`<your-deployment>/dream-cycle/classify.py` is the authority
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
Only root-memory homes (the global home) auto-apply; for an app-local home with
drift, surface it in the report for the human instead (repo-boundary + altitude rules).
If no home has drift, skip — emit nothing.

Second Tier-0 check: **staged-lesson orphans** — a staged note with no live twin never reached
a home. Sweep the last 7 days only — **by directory date, never `find -mtime`**: a git
checkout or submodule op bulk-resets every mtime, and `-mtime -7` then returns the WHOLE
backlog as if it were today's staging (memory `mtime-is-not-an-activity-timestamp`).
```bash
# NOTE: zsh's `[` rejects `>` for string compare ("condition expected: >") — use awk.
cut=$(date -v-7d +%F)   # macOS; GNU: date -d '7 days ago' +%F
base=<your-deployment>/context-mining/daily
for day in $(ls "$base" | awk -v c="$cut" '$0 >= c'); do
  find "$base/$day" -name '*.md' ! -name 'INDEX.md'
done
```
A hit whose basename exists in any memory home (or its `_archive/`) is a leftover copy —
delete it. Otherwise promote it: route by `domain:` per step 6, add the `MEMORY.md` index
line, delete the staged copy, record it in today's `INDEX.md`. Reporting an orphan without
promoting it keeps it.

Older orphans are a backlog, not daily hygiene: bulk promotion is lossy (no dedup against
today's substrate) and would swamp retrieval. Count them, report the count, promote none.

### 8. Generate Report
Save extraction summary to `<your-deployment>/health/reports/context-<date>.json`:
- Candidates found / Lessons extracted / Duplicates skipped
- Reflect-gaps: sessions scanned, gaps found, gaps mined
- Tier-0 hygiene: index-prune proposals emitted (homes + dangling slug counts); staged
  orphans promoted, and the older backlog count carried for the human

### 9. Notify — MANDATORY, DO THIS LAST, DO NOT SKIP
If you have a notification tool wired, actually run it (don't describe it) — this example
assumes a Slack card CLI at `<your-deployment>/tools/bin/slack-send`; substitute your own.
`--status`: `healthy` normally; `degraded` if gitleaks flagged anything or extraction errored.
```bash
<your-deployment>/tools/bin/slack-send --channel pi --card \
  --status <healthy|degraded> \
  --title "Context Mining — $(date +%Y-%m-%d)" \
  --field "Extracted=<N>" --field "Gaps mined=<N>" \
  --field "Dupes skipped=<N>" --field "Index-prunes=<N>" \
  --body "<one line: notable lesson + what the gap-scan caught, or 'nothing new'>" \
  --context "01:30 context mining · capture backstop + Tier-0 hygiene"
```
If wired, confirm exit 0 and retry once on error — the job is not complete until this posts.

## Security
- Run gitleaks check on any extracted content (transcripts are private — scrub before any
  lesson reaches the git-tracked queue)
- Never include secrets in lessons (this includes the Slack card body)
