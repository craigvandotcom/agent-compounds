---
name: ac2-publish
description: 'The ac2 ship gate — obtain a proof via ac-prove, assert its REQUIRED JOBS ACTUALLY EXECUTED, then version, tag the proven SHA and hand off to ac-distribute; labels external escapes with a catch-stage on arrival. Triggers: "ac2 publish", "ship the ac2 batch", "release this batch". Invoked BY the ac2 batch boundary. NOT the legacy ceremony (ac-publish), NOT the proof itself (ac-prove), NOT the store upload (ac-distribute).'
---

# ac2-publish — a proven batch in, a shipped release out

## I/O Contract

|                  |                                                                                  |
| ---------------- | -------------------------------------------------------------------------------- |
| **Input**        | A reviewed ac2 batch on the committed tree, and the ref `R` it ends at             |
| **Output**       | A tagged, promoted release at a PROVEN SHA — or an explicit refusal and no ship    |
| **Artifacts**    | The tag · the release report · beads for escapes, each catch-stage-labelled        |
| **Verification** | `ac-prove ensure --fix-forward` for the proof; the executed-jobs assertion below   |

Deliberately thin. It owns three things — the executed-jobs assertion, the ship order, and the
escape label — and delegates everything else by pointer.

## The proof leg — call `ac-prove`, never re-derive it

    ac-prove ensure --fix-forward [+qa] --ref "$R"     # returns the PROVEN SHA

Freshness, dispatch, attribution, the Green Gate and the fix-forward loop are `ac-prove`'s, in
full: `skills/ac-prove/SKILL.md`. This skill re-implements none of it, and a second copy of CI
trust logic here would drift against the first the week it landed.

**Consume the RETURNED SHA, not your input `R`.** A fix-forward round commits, so the tip moves;
tagging your original ref after one ships a commit nothing proved.

## The one thing this gate adds: required jobs must have EXECUTED

A run's conclusion is a fact about the RUN. It is not a fact about any job inside it, and the
two diverge — measured live on `craigvandotcom/body-compass-app` run `33103521929`, whose
run-level `conclusion` is `failure` while one of its two jobs concluded `success`. The
dangerous direction is the mirror image: a required job that was skipped by an `if:`, or never
scheduled at all, leaves a green run with nothing behind it. A conclusion observed live on that
same run's steps is literally `skipped`.

**So assert per-job, by name, against the run you dispatched:**

```bash
# The app's CI contract: one required job name PER LINE — never a space-separated list.
# Real job names contain spaces ("Playwright e2e (24 specs) · route module-load smoke"),
# and word-splitting one silently asserts over fragments that match nothing.
REQUIRED=$(printf '%s\n' "<job>" "<job>")
[ -n "$REQUIRED" ] || { echo "NOT-GATED: no required-job list — nothing was asserted"; exit 2; }

GREEN=$(gh run view "$RUN_ID" --json jobs \
          --jq '.jobs[] | select(.status=="completed" and .conclusion=="success") | .name')
MISSING=$(comm -23 <(printf '%s\n' "$REQUIRED" | sort) <(printf '%s\n' "$GREEN" | sort))
[ -z "$MISSING" ] || {
  echo "NOT-GATED: required job(s) did not execute green in run $RUN_ID:"
  printf '  %s\n' "$MISSING"; exit 2
}
```

- **Absent from the job list** — the job never executed. `NOT-GATED`.
- **`conclusion` of `skipped` / `cancelled` / `neutral` / null** — nothing was measured. `NOT-GATED`.
- **`REQUIRED` empty or unreadable** — the assertion would range over an empty set, which is the
  exact green-over-nothing this leg exists to stop. Refuse `NOT-GATED` rather than assert nothing.

Executed against a live run before this shipped, all three ways: a green pass, a required job
that concluded `failure` refused by name, and an empty `REQUIRED` refused rather than asserting
over nothing. A gate whose commands nobody ran is a scar list with better formatting.

`NOT-GATED` is never a pass and never a FAIL-and-continue: it is a stop. A dormant job reporting
green is the gate-audit class — canon in `skills/ac-pipeline/references/` § assurance-declarations
— and it is how a pipeline ships unproven code while every dashboard stays green.

## QA placement — by pointer, never copied

Whether QA runs at this gate or was pulled earlier is decided by the verification-gate class
table in `skills/ac-pipeline/references/` — one selection brain, consulted, never restated.
A copy of that table here would be a second selection brain, and the two would disagree
silently. Pull QA earlier only when that table says so; then pass `+qa` to `ac-prove`.

## Ship, in this order

1. **Mint the version once.** One bump per publish, never re-bumped downstream; propagation to the native build surfaces is `references/version-bump.md`, the sole owner of that counter.
2. **Tag the PROVEN SHA explicitly, never `HEAD`.** `ac-prove` pushes evidence commits, so by
   the time this step runs `HEAD` has moved past the commit that was proven and reviewed.
3. **Web — promote, do not rebuild.** The artifact the proof validated is the artifact that ships:
   an alias move over its staged build, never `vercel deploy --prod`. Mechanics: `references/web-promote.md`.
4. **Native and mobile — CI-built artifacts ONLY.** The binary that ships is the one CI produced
   from the proven SHA. A locally-built artifact carries a local toolchain, local env and an
   unproven tree; it is a different artifact from the one the gate measured, and shipping it
   voids every leg above. Hand the upload to `ac-distribute` (check-only on the bump).
5. **Verify identity, not version strings.** Confirm what production actually serves is the
   proven SHA. Two deployments can mint the same version.

## External escapes close the outer loop

A finding that arrives from OUTSIDE — production, a user, store review, a late QA pass — is the
only signal that can tell this factory it was wrong. Everything else is the factory grading
itself.

**Label it with its catch-stage ON ARRIVAL**, from the closed set in
`skills/beads-standards/SKILL.md`: `prod-finding` (Sentry normalizes into this) · `qa-finding` ·
`ci-finding`. On arrival, because a stage inferred weeks later is a guess, and because the label
is what says which gate leaked. **Write the label even when the fix lands immediately** — the
fix may be in-batch, the label never is (ac2-pipeline Invariant 6).

## Out of scope

CI trust logic (`ac-prove` owns it, exclusively) · the store upload itself (`ac-distribute`) ·
QA selection (the class table) · inbound triage — escapes are LABELLED here, and worked
elsewhere.
