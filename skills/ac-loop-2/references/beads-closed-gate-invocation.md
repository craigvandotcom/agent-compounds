# beads-closed-gate invocation — flag rationale

The loop's own pre-close gate (`ac-batch-close` no longer checks bead closure itself). The
script is `ac-pipeline/scripts/beads-closed-gate.sh` (fixture proof:
`ac-pipeline/scripts/beads-closed-gate.test.sh` — run after ANY gate edit); ac-loop-2 invokes
it ONCE, at Phase 4 step 3, over the whole cycle. This file holds only the **why** behind each
flag — the command, exit-code branches, and `post-merge`/nudge decision stay inline at the
spine site (enforcement). Substitute this cycle's ids/paths.

## Identity set — pass the UNION (bd-w504y)
Pass MY conductor identity **plus** every lane-coordinator, build-worker, risk-queue and
repair-worker identity from their summaries. A child's incremental/replacement claim under its
own session name would otherwise be MISSED, failing the gate **OPEN**. Threading
`CLAIM_ASSIGNEE=<AGENT_NAME>` into every dispatch already funnels those claims to the conductor
identity, so the delegated identities are belt-and-suspenders — pass them anyway.

## `--progress` (ac-514, completeness)
Pass this cycle's `progress.md` so the completeness check runs. A multi-bead (N>1) batch whose
`progress.md` lacks a per-bead result entry or the `COMPLETED: n/N` tally **HARD-FAILS** the close
(names the missing bead ids); a single-bead batch only WARNs. Omitting `--progress` skips the
check entirely (pre-ac-514 behavior).

## Repeated `--progress` for the parallel build phase (ac-0wi)
Phase 2 always fans out, so every cycle hits this case: each lane coordinator (and each repair
worker that closed a bead) wrote its OWN `progress.md`. Pass ALL child files in ONE
call as REPEATED `--progress` flags — the completeness check unions the `### Bead <id>` entries
across every provided file and validates coverage against the whole in-scope set. A single child
file alone would false-fail for missing its siblings' beads. Do **NOT** glob.

## `KIND` — mixed-kind runs
Only `KIND=implement` progress files enter the completeness union. Refine and beadify children
ship no code and close no beads, so their files are reported and skipped — and they can never
mask an incomplete implement file, because their `### Bead` entries never join the union. A
prep file is also skipped BEFORE the existing-files counter, so a run whose children were all
prep cannot trip PROGRESS-NO-HEADER and false-block its own close. Absent `KIND` = implement.

## `--beads` cycle-scoping (ac-0i1)
ALSO pass `--beads` with THIS cycle's bead ids (comma-separated) so the completeness check scopes
to exactly this cycle. The identity-lifetime default would re-demand per-bead entries (and
`--progress` files) for an EARLIER cycle's beads under the same conductor identity, and mislabel a
1-bead cycle as multi-bead. The OPEN-bead check stays identity-wide (a genuinely-open bead from any
cycle still blocks). Omit `--beads` only when the identity has shipped exactly one cycle.

(Exit-code branches and the `post-merge`/nudge decision are enforcement — they stay inline at the
Phase 4 spine site, not here, so there is one canonical copy of each acting instruction.)
