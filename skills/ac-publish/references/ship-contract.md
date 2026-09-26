# ship-contract — the rules every ship command must satisfy

The ship block's commands are one contract, not free-form strings. The spine runs them;
this file is what each command is allowed to do and must guarantee. Generic rules only —
no app's own commands live here.

## The prove command

One command, one ref argument (`prove --ref <SHA>`, or `--ref` omitted for current HEAD):

- The **proven SHA is the LAST LINE of stdout**, and the command exits 0.
- Any non-zero exit is **FAIL** — never "stale", never a soft pass.
- A missing or unreadable prove command is **NOT-GATED**: the ship stops here. A gate
  that cannot verify never reads as a pass, and staleness is never guessed around.
- **The printed SHA is the only SHA used downstream.** Tagging, promotion and verification
  all consume the SHA the prove command returned — never your input ref, never HEAD. After
  any intermediate commit (a bump, an evidence write) the input ref is already stale; the
  printed answer is the fact.

### What a trusted proof is made of — freshness, attribution, the green gate

These three conditions inherit from the proof primitive (`ac-prove`) as generic rules:

1. **Freshness** — a freshness check passes for the ref: the latest trusted evidence line is
   an ancestor of the proven SHA, with only evidence commits between it and the ref.
2. **Attribution** — the trusted evidence line belongs to the run YOU dispatched. A newer
   line appended by someone else's concurrent run is not your proof.
3. **The green gate** — the dispatched run's own conclusion reads success. A run's
   conclusion is the receipt's provenance *and* its pass mark, and a receipt can exist on a
   RED run: existence alone is never proof of green.

Probe-first callers may accept condition 1 alone as a read-only baseline signal — but any
caller that acts on the answer (ships, tags, promotes) needs all three.

### Polling is bounded and foreground

Poll the proof inside the current session, with a bounded loop and a counted cap. Never
background a poller that outlives the session — a watcher that cannot resume silently turns
a failed run into waiting forever, and waiting forever into a report nobody reads.

### No fix-forward inside a run

If the proof FAILs mid-run, the run stops: do not commit fixes and re-prove within a running
ship. A fix is ordinary next work, filed and worked like any other; the next ship run re-runs
the whole prove step — label/version state from the failed run is **reused, not re-bumped**
(the untagged version walks into the next attempt). The prove command itself may not commit.

## Version — one bump, monotonic counters

- **One bump per ship.** If `version.read` is already greater than the latest tag, reuse it
  — never bump twice.
- **`version: null` means no bump and no tag.**
- **Build numbers are monotonic** — a build number only ever increments; every uploaded
  build carries the next value. The verification step (below) reads the uploaded number, so
  an increment-skipped upload is caught by reading, not by memory.

## Target rules — web promotes, never rebuilds

- **Web promotes the proven deployment.** The artifact the proof measured is the artifact
  that ships: find the staged production-target build keyed by the proven SHA and **promote**
  it to the live domain. A fresh build is a DIFFERENT artifact — it bakes different env vars
  and voids every gate above it, so there is nothing to run here but the promote.
- **Never promote a preview build.** A preview bakes preview env into public flags at build
  time; only a production-target staged build is a valid promote target, and the promote
  step confirms which one it is — URL naming is not evidence.
- **Verify identity, not version strings.** Confirm what production actually serves is the
  proven SHA (the alias's own deployment metadata), not a version string — two deployments
  can mint the same version.

## Target rules — native is provably the proven SHA

- **Native builds from a clean checkout of the proven SHA.** The property is provenance:
  built from the proven SHA, from a clean tree, with the required check runs green on that
  SHA. CI is the default because it establishes all three structurally; a local build is a
  **declared exception** that must pass the same gate the CI lane runs, logged loudly.
- **`verify` checks the uploaded build** — the embedded SHA and the build number inside the
  uploaded artifact, read back from the store, never assembled from local state.
- **Build numbers are monotonic** (see Version above); a re-upload after a failed upload
  increments too.

## The rules summary

| step     | must do                                                            |
|----------|--------------------------------------------------------------------|
| preflight | run every declared command first; any failure stops the ship      |
| prove    | return the proven SHA as stdout's last line; non-zero is FAIL      |
| version  | one bump per ship; `null` means no bump and no tag                 |
| promote  | move the proven artifact to its live surface, never rebuild it     |
| verify   | read back what actually shipped: the SHA it serves / embeds, monotonic build number |
