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
enforcement — keep them in sync).

---

## The two tiers

### `auto` — applied unattended by the daily queue job, reported in the digest

A proposal is `auto` **iff ALL of these hold** (any failure → `gated`):

1. `status: pending` (already-decided proposals route elsewhere).
2. `category` ∈ {`fact`, `rule`, `lint-fix`} — **not** `decision`, `skill-improvement`, `re-home`.
3. `target_repo: root`.
4. `target_file` is under `infrastructure/memory/auto/` **and is not `MEMORY.md`** (the
   always-loaded hot lane is never auto-edited beyond its one new index line).
5. `judge.score ≥ 9` (high-confidence only; the ≥7 ship bar is for *existence*, ≥9 for *autonomy*).
6. The `target_file` **does not yet exist** — a pure ADD, never an edit to existing knowledge.

Why this set is safe to apply without a human: it is an append-only new note in the global
substrate, git-revertible in one commit, touching no skill, no L0/L1 hot-lane file, no code,
no config, and no existing knowledge it could contradict. The judge already vetted it at ≥9.

### `gated` — posted to Slack as a one-tap Approve/Reject card (the existing flow)

Everything else, explicitly including:

- **Edits to existing notes** (clause 6 fails) — they can contradict or reframe prior knowledge.
- **`decision`s** — strategic commitments deserve Craig's eyes even as memory ADDs.
- **`skill-improvement` / `re-home`** — touch L2 skills or move knowledge across altitude.
- **Anything outside root memory** — app repos, agent-compounds, code, config.
- **judge < 9** — shippable but not autonomous-grade.

When in doubt the predicate returns `gated`. A false-gate costs one extra tap; a false-auto
writes unreviewed content. The asymmetry is intentional.

---

## How the tiers are consumed (the daily queue job)

`_agent-pi/workflows/dream-daily.md` (02:00) is the apply engine:

1. **Classify** every pending proposal (`classify.py --dir <today>`).
2. **Auto-tier → apply now:** run the `dream` skill's REVIEW-apply steps on the `auto` set
   (write the new note + its MEMORY.md index line, set `status: applied`, commit in root,
   push). No card.
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
