# Auto-act rubric — when the cycle may apply without a human gate

**Problem this solves.** Every dream proposal used to become a Slack approval card. A quiet
week still produced ~10 cards, most of them paste-ready memory ADDs scoring 10/10 — changes
a human cannot meaningfully second-guess ("should we *remember* this latency fact?"). The
gate's value is real for judgment-laden changes and ~zero for append-only facts. This rubric
splits the queue so Craig's attention lands only where his judgment changes the outcome.

**The principle (unchanged from the skill's hard rules):** Stage-1 autonomy is
**deterministic** hygiene only. The gate is the safe default; `auto` must be *earned* by
every clause of a deterministic predicate. No LLM judgment decides the tier — that would
re-introduce the very risk the gate exists for. The predicate is implemented, byte-for-byte,
in `infrastructure/dream-cycle/classify.py` (this doc is the spec; the script is the
enforcement — keep them in sync). The autonomy axis is **reversibility × judgment, not
cadence** — architecture: `neometa/alignment/decisions/2026-06-26-tiered-memory-autonomy.md`.

---

## The tiers

Two tiers earn `auto` (applied unattended by the daily queue job, reported in the digest);
everything else is `gated` (one-tap Slack Approve/Reject).

### `auto` · Tier-1 — additive: a pure ADD of a new memory note

A proposal is Tier-1 `auto` **iff ALL of these hold** (any failure → `gated`):

1. `status: pending` (already-decided proposals route elsewhere).
2. `category` ∈ {`fact`, `rule`} (a `lint-fix` that creates a brand-new note also qualifies).
3. `target_repo: root`.
4. `target_file` is under `infrastructure/memory/auto/` **and is not `MEMORY.md`** (the
   always-loaded hot lane is never auto-edited beyond its one new index line).
5. `judge.score ≥ 9` (high-confidence only; the ≥7 ship bar is for *existence*, ≥9 for *autonomy*).
6. The `target_file` **does not yet exist** — a pure ADD, never an edit to existing knowledge.

Why it is safe without a human: an append-only new note in the global substrate, git-revertible
in one commit, touching no skill, no L0/L1 hot-lane file, no code, no config, and no existing
knowledge it could contradict. The judge vetted it at ≥9. **The agent applies it** (writing
prose is judgment the script can't reproduce).

### `auto` · Tier-0 — mechanically re-derivable: a lint-fix the SCRIPT can recompute

A `lint-fix` whose correct result `classify.py` can re-derive from the filesystem and apply
**itself** — so zero trust is placed in the LLM's proposed content (the proposal only *flags*
that drift exists; the script is the authority). Tier-0 is the **only** way an edit to an
*existing* file auto-applies — earned by independent verification, not by clause-counting.

Tier-0 `auto` **iff**: `status: pending` · `category: lint-fix` · `target_repo: root` ·
`lint_subtype` ∈ the verifiable set · **and the script's re-derivation exactly matches the
proposal's paste-ready block** (else `gated`). No judge score required — verification replaces
judgment. Apply via `classify.py --apply-tier0` (it re-derives, re-verifies, writes, flips
status; refuses with exit 2 if it can't).

Verifiable `lint_subtype`s (start narrow; widen only with evidence):

| subtype | what it does | why lossless |
|---|---|---|
| `index-prune` | remove `MEMORY.md` index lines whose target `.md` no longer exists | the referenced file is already gone; the line is pure stale pointer |

Candidates to add later (each needs an independent re-derivation in the script first):
dead-wikilink *removal* (ambiguous — a dead link often marks a note worth writing, so it
stays gated for now), frontmatter-field normalization.

### `gated` — posted to Slack as a one-tap Approve/Reject card (the existing flow)

Everything else, explicitly including:

- **Lossy or judgment-laden hygiene** — near-duplicate *merges*, summarise/compress,
  contradiction resolution (Tier-2; these *delete information*, so never auto).
- **Edits to existing notes** that aren't a verified Tier-0 op.
- **`decision`s** — strategic commitments deserve Craig's eyes even as memory ADDs.
- **`skill-improvement` / `re-home`** — touch L2 skills or move knowledge across altitude.
- **Anything outside root memory** — app repos, agent-compounds, code, config.
- **judge < 9** (for the Tier-1 path) — shippable but not autonomous-grade.

When in doubt the predicate returns `gated`. A false-gate costs one extra tap; a false-auto
writes unreviewed content. The asymmetry is intentional.

---

## How the tiers are consumed (the daily queue job)

`_agent-pi/workflows/dream-daily.md` (02:00) is the apply engine:

1. **Classify** every pending proposal (`classify.py --dir <today>`). The reason field names
   the shape: `Tier-1 · …` or `Tier-0 · …`.
2. **Auto-tier → apply now** (no card): **Tier-1** — write the new note + its MEMORY.md index
   line, set `status: applied`. **Tier-0** — `classify.py --apply-tier0 <proposal>` (the
   script re-derives, re-verifies, writes, and flips status itself). Commit in root, push.
3. **Approved backlog → apply now:** any proposal already at `status: approved` (Craig
   tapped Approve on a prior card) is applied the same way — this closes the
   approve-but-never-applied gap.
4. **Gated + still pending → card:** `post-proposals.sh` posts the improved card (Why +
   judge score + plain-English action). `post-proposals.py` itself re-checks the predicate,
   so a manual run never posts an auto-tier item.
5. **Digest:** one summary card — *N auto-applied (listed) · M awaiting your decision · P
   approved→applied*.

## Status vocabulary

`pending` → (`approved` | `rejected` via Slack button) → `applied` (REVIEW or auto wrote the
target) — or `pending` → `applied` directly for the auto-tier. `applied` is the terminal
success state; it distinguishes "Craig approved it" from "it actually landed in the substrate".

## Tuning

Conservative on purpose for v1. Widen only with evidence: if `applied` auto-tier notes are
never reverted across several cycles, candidate loosenings (in rough order) — allow `re-home`
within root memory; allow small appends to existing notes; lower the score floor to 8. Each
loosening is itself a `dream` proposal (the cycle proposes upgrades to its own rubric), never
a silent edit. Inverse signal: if an auto-applied note ever gets reverted, tighten and record
why here.
