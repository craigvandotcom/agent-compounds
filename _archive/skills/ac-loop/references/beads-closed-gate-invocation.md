# beads-closed-gate invocation — flag rationale

The loop's own pre-close gate (`ac-batch-close` no longer checks bead closure itself). The
script is `ac-pipeline/scripts/beads-closed-gate.sh` (fixture proof: `ac-pipeline/scripts/beads-closed-gate.test.sh` — run after ANY gate edit); both Phase 1 (orphan batch) and Phase 2 (plan
wave) invoke it identically at their step 6. This file holds only the **why** behind each flag —
the command, exit-code branches, and `post-merge`/nudge decision stay inline at both spine sites
(enforcement). Substitute this batch's ids/paths.

## Identity set — pass the UNION (bd-w504y)
Pass MY loop identity **plus** each delegated `ac-implement` identity from its summary. A
delegate's incremental/replacement claim under its own session name would otherwise be MISSED,
failing the gate **OPEN**. Threading `CLAIM_ASSIGNEE=<AGENT_NAME>` into the implement delegation
already funnels those claims to the loop identity, so the delegated identities are
belt-and-suspenders — pass them anyway.

## `--progress` (ac-514, completeness)
Pass this batch's `progress.md` so the completeness check runs. A multi-bead (N>1) batch whose
`progress.md` lacks a per-bead result entry or the `COMPLETED: n/N` tally **HARD-FAILS** the close
(names the missing bead ids); a single-bead batch only WARNs. Omitting `--progress` skips the
check entirely (pre-ac-514 behavior).

## Repeated `--progress` for parallel waves (ac-0wi)
For a PARALLEL wave whose children each wrote their OWN `progress.md`, pass ALL child files in ONE
call as REPEATED `--progress` flags — the completeness check unions the `### Bead <id>` entries
across every provided file and validates coverage against the whole in-scope set. A single child
file alone would false-fail for missing its siblings' beads. Do **NOT** glob.

## `KIND` — mixed-kind runs
Only `KIND=implement` progress files enter the completeness union. Refine and beadify children
ship no code and close no beads, so their files are reported and skipped — and they can never
mask an incomplete implement file, because their `### Bead` entries never join the union. A
prep file is also skipped BEFORE the existing-files counter, so a run whose children were all
prep cannot trip PROGRESS-NO-HEADER and false-block its own close. Absent `KIND` = implement.

## `--beads` batch-scoping (ac-0i1)
ALSO pass `--beads` with THIS batch's bead ids (comma-separated) so the completeness check scopes
to exactly this batch. The identity-lifetime default would re-demand per-bead entries (and
`--progress` files) for EARLIER batches' beads under the same loop identity, and mislabel a 1-bead
batch as multi-bead. The OPEN-bead check stays identity-wide (a genuinely-open bead from any batch
still blocks). Omit `--beads` only for a standalone single-batch run where identity == batch.

(Exit-code branches and the `post-merge`/nudge decision are enforcement — they stay inline at both
step-6 spine sites, not here, so there is one canonical copy of each acting instruction.)
