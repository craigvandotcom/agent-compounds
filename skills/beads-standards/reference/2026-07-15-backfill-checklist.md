# Backfill checklist — 2026-07-15 cross-project audit

One-time alignment pass, run **after** `beads-standards` SKILL.md defines the
standard (this file), so the backfill converges toward it rather than the audit's
raw findings becoming their own ad-hoc precedent. Not re-run on a schedule — file a
fresh finding-bead per repo if drift recurs; this list is a snapshot, not a
recurring job.

Each item below: what was found, and the fix command(s). Run per-repo (`.beads/`
db is local to each project) — `cd` into the repo before the `br` calls.

## ToC
- 1. Synonym merges
- 2. Nine DECISION-titled beads missing human-gate
- 3. bd-d6w79 — double-label contradiction
- 4. defer_until gaps
- 5. Casing/spelling variants — normalize to kebab-case
- Verification

## 1. Synonym merges

Every occurrence of a deprecated human-marker label merges to `human-gate`:

`human-only` · `human-blocked` · `human-required` · `craig-required` · `craig-context`

```bash
for old in human-only human-blocked human-required craig-required craig-context; do
  br label rename "$old" human-gate 2>/dev/null || true
done
```

Run in every repo with a `.beads/` — most won't have all five, `rename` on a
nonexistent label is a no-op-safe call (confirm with `br label list-all` before/after
if unsure).

## 2. Nine DECISION-titled beads missing `human-gate`

Title carries the `DECISION:` convention but the bead has no `human-gate` label — the
cockpit's label-only scan can't see these. Root repo (`org` prefix):

```bash
br label add org-487 human-gate
br label add org-z47 human-gate
br label add org-ld1 human-gate
br label add org-ycr human-gate
```

App repo(s) — bead ids `bd-06opv.12`, `bd-06opv.15`, `bd-06opv.16`, `bd-06opv.17`,
`bd-19o6g.6` (locate the owning repo via `br show <id>`'s `source_repo` field first,
`br` auto-discovers `.beads/*.db` from cwd so run from inside the right repo):

```bash
br label add bd-06opv.12 human-gate
br label add bd-06opv.15 human-gate
br label add bd-06opv.16 human-gate
br label add bd-06opv.17 human-gate
br label add bd-19o6g.6 human-gate
```

**After labelling, wire the mandatory dependency edge** (§ Human-gate template,
main skill) for each of these nine if it currently gates any downstream bead —
check with `br dep list <id> --direction down` first; a decision bead with
genuinely nothing downstream needs no edge, but verify rather than assume (this is
exactly the gap the audit surfaced: 30/31 open human-gate beads had zero downstream
reach because the wiring step was skipped at creation, not because none existed).

## 3. `bd-d6w79` — double-label contradiction

Carries two labels that assert opposite things (e.g. both a lifecycle-ready label and
an unrefined/blocked label — check `br show bd-d6w79 --json` for the current label
set before touching it, contradictions drift). Resolve by re-reading the bead's
actual state and keeping the label that matches reality; remove the other:

```bash
br show bd-d6w79 --json   # inspect current labels + description before deciding
br label remove bd-d6w79 <the-stale-one>
```

## 4. `defer_until` gaps

Two beads are `deferred` status with no `defer_until` set — a deferred bead with no
date is invisible to any "coming back on X" view and never resurfaces on its own:

```bash
br show repos-l9z --json   # confirm still deferred, read context for a sane date
br update repos-l9z --defer "<date>"

br show ac-ld7 --json
br update ac-ld7 --defer "<date>"
```

Pick the date from the bead's own context (a referenced milestone, a "revisit
after X ships" note) rather than an arbitrary +30d — if the bead gives no signal,
default to +30d and say so in a comment.

## 5. Casing/spelling variants — normalize to kebab-case

```bash
br label rename CORE core
br label rename follow-up followup        # or the reverse — pick ONE canonical form
                                            # per pair and note the choice in the
                                            # commit/comment so it doesn't re-drift
br label rename bug-fix bugfix
br label rename phase-2 phase2
br label rename app-store appstore
br label rename pre-flight preflight
br label rename browser-QA browser-qa
br label rename repo-agent-compounds repo:agent-compounds
```

**Note on `repo:agent-compounds` vs `repo-agent-compounds`:** the main skill's label
rule says "no slashes" for `wave/NNN`-style labels because `br` rejects `/` outright
— but `:` is accepted, so `repo:agent-compounds` is the valid form here (colon, not
slash); `repo-agent-compounds` is the one to retire. Verify which form actually
exists in each repo before renaming (`br label list-all`) — don't run a rename
against a label that isn't present, some rows above may only apply to specific repos.

## Verification

After running the applicable items in a repo:

```bash
br sync --flush-only
br label list-all | grep -iE "human-only|human-blocked|human-required|craig-required|craig-context"
# expect zero matches
git add .beads/issues.jsonl && git commit -m "chore(beads): backfill to beads-standards canon"
```
