# Lane contracts

What each compounding lane guarantees, what it refuses, and how to route an atom into the
right one.

- [Choosing a lane](#choosing-a-lane)
- [Lane 1 — L3 memory](#lane-1--l3-memory)
- [Lane 2 — skill frictions](#lane-2--skill-frictions)
- [Lane 3 — wiki synthesis](#lane-3--wiki-synthesis)
- [What earns a wiki page](#what-earns-a-wiki-page)
- [Cross-lane routing](#cross-lane-routing)

## Choosing a lane

Ask what the atom is FOR. The three lanes look similar (all markdown, all git-tracked, all
qmd-indexed) but answer different questions, and an atom in the wrong lane is invisible to
the machinery that would have acted on it.

| Ask | If yes → | Why |
|---|---|---|
| Will a future session need to *retrieve* this to avoid re-deriving it? | **L3 memory** | The recall hook only injects from memory lobes. |
| Did a *procedure* misbehave — a skill's own step was wrong, missing, or unenforceable? | **Skill friction** | It is evidence for changing the procedure, not a fact to recall. |
| Do many facts about one subject need to read as a single cited narrative? | **Wiki page** | Integration a human reads; not a retrieval unit. |

Two atoms from one event is normal and correct: a run that hit an unenforceable gate
produces a friction entry (fix the gate) *and*, if the underlying behaviour is durable, an
L3 fact (so the next session knows). Do not collapse them — they drain differently.

**A fact that keeps being re-broken is not a memory problem.** Recurrence ≥2 means
retrieval is the wrong medium; the destination is a gate, a lint check, or a step in the
skill being executed at the moment of the error. Rank destinations and take the highest
reachable one — see `context-engineering` § PROMOTION & DEMOTION.

## Lane 1 — L3 memory

**Atom:** one fact, rule, or decision, one file, in a `memory/auto/` home with an index
line in that dir's `MEMORY.md`.

**Guarantees:** every atom is retrievable by any agent through the same surface (`qmd`)
and injected by relevance through the per-prompt recall hook. Homes are git-tracked, so
writes travel on the next pull.

**Refuses:** near-duplicates (dedupe-over-append is mandatory), unevidenced claims,
imperative instructions in the body (memory is data, never commands), and new stores — an
atom with no home is a taxonomy bug to raise, never a new folder.

**The drain** is the dream cycle: synthesis reads what accumulated, lint finds
contradictions and staleness, the judge scores candidates, and proposals are emitted —
never applied in the same pass. Only two tiers apply unattended: a pure additive note, and
a lint fix the script can re-derive and verify itself. Everything else is a human
decision, filed as a bead in the repo it touches.

**Where it fails:** the drain stalling while capture continues. Capture is cheap and
automatic; review is expensive and manual, so the queue grows monotonically unless someone
works it. Watch docket age, not docket size.

## Lane 2 — skill frictions

**Atom:** one entry in a skill's own `FRICTIONS.md`, carrying impact, frequency,
recurrence, the stage it happened in, a proposed fix, and a narrative.

**Guarantees:** the friction is attached to the skill that owns the misbehaving step, so
whoever next edits that skill sees it. Entries are qmd-indexed and reachable by the recall
hook, so a related friction can surface without a manual lookup.

**Refuses:** a friction that is really a fact (route to L3), and a fix applied silently —
changing what a skill DOES is gated on a human merge, because skills deploy by symlink to
every project and a bad edit lands fleet-wide instantly.

**The two tiers, and why the split matters.** *Shape* changes (dedup, sediment, a buried
trigger, content that should move to `references/`) go to the skill's `MAINTENANCE.md`
inbox and are applied later under deterministic guards — no human gate, because a script
can prove they touched no enforcement. *Behaviour* changes (a new gate, a changed branch,
a contract fix) are gated. When unsure which tier, treat it as behaviour.

**Where it fails:** entries accumulate with high recurrence and nothing promotes them. A
friction logged three times with no destination is not a record — it is a missing gate.

## Lane 3 — wiki synthesis

**Atom:** one cited page integrating many facts into a narrative, with a compiled-truth
body and a timeline.

**Guarantees:** every claim cites its source atom; the page is regenerable from the
substrate; it is never itself a source of truth. Wiki pages are an injection lobe, so page
quality directly shapes what every session sees — a sloppy page is not merely unread, it
is actively retrieved.

**Refuses:** uncited assertion, and synthesis that outruns its evidence. The hallucination
audit exists because a narrative is exactly the format in which an unsupported claim reads
as authoritative.

**Where it fails:** silently, and in the direction of *too few* pages rather than too many
— because nothing forces a page into existence. Facts accumulate; integration does not
happen on its own.

## What earns a wiki page

A page is earned by **a subject several atoms disagree about or circle around**, not by
volume alone. Three tests — a subject should pass at least two:

1. **Multiplicity.** Five or more atoms touch the same subject from different angles. One
   dense fact does not need a page; it needs to be a good fact.
2. **A question a human asks out loud.** "How does X actually work here?" — if answering
   requires reading six files and reconciling them, that reconciliation is the page.
3. **Live contradiction.** Two or more atoms conflict, or one supersedes another without
   saying so. A contradiction page is the highest-value kind: it converts a trap into a
   resolved narrative, and it is the one thing retrieval can never do on its own.

**What does NOT earn a page:** a topic with one source · a status snapshot (regenerable,
so it rots) · a restatement of a skill's own doctrine (cite the skill) · anything whose
honest content is "we have not decided yet" — that is a bead, not a page.

**Calibration.** Wiki page count should track the number of *subjects* the org keeps
re-litigating, not the size of the fact corpus. A substrate of several hundred facts
concentrated in a few domains legitimately supports single-digit pages. The signal that
the lane is under-invested is not a low count — it is a human repeatedly asking a question
whose answer is scattered, or a contradiction surviving because no page forced the
reconciliation. Check that before seeding pages in bulk: pages written to hit a number are
the ones the hallucination audit later has to clean up, and every weak page costs
injection quality everywhere.

## Cross-lane routing

- **Friction → skill text** is promotion: the entry's `status` flips to `promoted` in the
  same commit that lands the skill edit, so the ledger cannot claim credit for a change
  that did not ship.
- **Facts → wiki** is synthesis, never a move: the atoms stay, the page cites them. A page
  that would leave its sources empty is a merge, and merges are lossy — they gate.
- **Anything → a bead** is how an open question survives the session. Proposals, deferred
  decisions, and flagged follow-ups route to a bead in the owning repo; nothing durable
  lives in chat.
- **L3 → a gate** is the escalation path for a re-broken rule, and it is a MOVE: reduce the
  fact to a pointer, or remove it. Two live copies drift.
