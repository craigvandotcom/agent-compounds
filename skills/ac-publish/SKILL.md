---
name: ac-publish
description: 'The ac2 ship gate — obtain a proof via ac-prove, assert its REQUIRED JOBS ACTUALLY EXECUTED, then version, tag the proven SHA and hand off to ac-distribute; labels external escapes with a catch-stage on arrival. Triggers: "ac2 publish", "ship the ac2 batch", "release this batch". Invoked BY the ac2 batch boundary. NOT the legacy ceremony (ac-publish), NOT the proof itself (ac-prove), NOT the store upload (ac-distribute).'
---

# ac-publish — a proven batch in, a shipped release out

## I/O Contract

|                  |                                                                                  |
| ---------------- | -------------------------------------------------------------------------------- |
| **Input**        | A reviewed ac2 batch on the committed tree, and the ref `R` it ends at             |
| **Output**       | A tagged, promoted release at a PROVEN SHA — or an explicit refusal and no ship    |
| **Artifacts**    | The tag · the release report · beads for escapes, each catch-stage-labelled        |
| **Verification** | `ac-prove ensure --fix-forward`; executed-jobs; `needs-device-gate.sh --range`      |

Deliberately thin. It owns four things — the executed-jobs assertion, the needs-device
surface gate, the ship order, and the escape label — and delegates everything else by pointer.

## Phase 0 — mint the version, then prove

Refuse an open needs-device surface (§ below), then mint the version, propagate it and COMMIT
it — all before `ac-prove`. One bump per publish, never re-bumped downstream; propagation to
the native build surfaces is `references/version-bump.md`, the sole owner of that counter.

The ref `R` handed to the proof leg IS that bump commit, so **proven SHA = tagged SHA =
promoted artifact.** Bumping after the proof cannot be repaired downstream: the bump is a real
commit, `publish-checkpoint-gate.mjs` refuses a real commit between the checkpoint and the
release SHA, and `NEXT_PUBLIC_APP_VERSION` is read from `package.json` at BUILD time — so the
promoted artifact, its `X-Client-Version` header and its Sentry `client_version` all carry the
previous version while the tag claims the new one.

## The proof leg — call `ac-prove`, never re-derive it

    ac-prove ensure --fix-forward [+qa] --ref "$R"     # returns the PROVEN SHA

Freshness, dispatch, attribution, the Green Gate and the fix-forward loop are `ac-prove`'s, in
full: `skills/ac-prove/SKILL.md`. This skill re-implements none of it, and a second copy of CI
trust logic here would drift against the first the week it landed.

**Consume the RETURNED SHA, not your input `R`.** A fix-forward round commits, so the tip moves;
tagging your original ref after one ships a commit nothing proved.

## The one thing this gate adds: required jobs AND steps must have EXECUTED

A run's conclusion is a fact about the RUN, not about any job inside it, and the two diverge —
measured live on run `33103521929`: run-level `failure`, one job `success`. A required job
skipped by an `if:` or never scheduled leaves a green run with nothing behind it (the step
conclusion is literally `skipped`). And `quality-gate.yml` emits the SAME TWO JOB NAMES for
both tiers — a Tier-1 run passes job-level while the heavy steps skip; the step layer refuses
it (evidence + six step names: `references/executed-jobs.md`).

**So assert per-job AND per-step, by name, against the run you dispatched:**

```bash
# One required job name PER LINE, then a `# REQUIRED_STEPS` block of one required step name
# PER LINE — real names contain spaces and '·'; a word-split list asserts over fragments that
# match nothing. COMMITTED DATA (.github/required-jobs.txt), resolved via this skill's home.
CONTRACT="$(dirname "$(readlink -f .claude/skills/ac-publish/SKILL.md)")/../../.github/required-jobs.txt"
REQUIRED=$(awk '/^# REQUIRED_STEPS/{exit} /^#/ || /^$/{next} {print}' "$CONTRACT" 2>/dev/null)
REQUIRED_STEPS=$(awk '/^# REQUIRED_STEPS/{f=1; next} f && (/^#/ || /^$/){next} f{print}' "$CONTRACT" 2>/dev/null)
[ -n "$REQUIRED" ] || { echo "NOT-GATED: no required-job contract at $CONTRACT — nothing was asserted"; exit 2; }
[ -n "$REQUIRED_STEPS" ] || { echo "NOT-GATED: no required-step contract at $CONTRACT — nothing was asserted"; exit 2; }

# Layer 1 — jobs must have concluded success.
GREEN=$(gh run view "$RUN_ID" --json jobs \
          --jq '.jobs[] | select(.status=="completed" and .conclusion=="success") | .name')
MISSING=$(comm -23 <(printf '%s\n' "$REQUIRED" | sort) <(printf '%s\n' "$GREEN" | sort))
[ -z "$MISSING" ] || { echo "NOT-GATED: required job(s) did not execute green:"; printf '  %s\n' "$MISSING"; exit 2; }

# Layer 2 — steps must have concluded success; `skipped` (an `if:` guard) is NOT-GATED.
GREEN_STEPS=$(gh run view "$RUN_ID" --json jobs \
          --jq '[.jobs[] | .steps[]? | select(.conclusion=="success") | .name] | unique[]')
MISSING_STEPS=$(comm -23 <(printf '%s\n' "$REQUIRED_STEPS" | sort) <(printf '%s\n' "$GREEN_STEPS" | sort))
[ -z "$MISSING_STEPS" ] || { echo "NOT-GATED: required step(s) did not execute green:"; printf '  %s\n' "$MISSING_STEPS"; exit 2; }
```

- **Absent from the job/step list, or `skipped`/`cancelled`/`neutral`** — nothing was measured. `NOT-GATED`.
- **`REQUIRED`/`REQUIRED_STEPS` empty or unreadable** — ranges over an empty set, the exact green-over-nothing this leg exists to stop. Refuse `NOT-GATED`.
- **The REQUIRED_STEPS contract names all six substantive steps** — 'Unit + integration tests (vitest)', 'Build check (next build)', 'TypeScript check (tsc --noEmit)', 'Shadow divergence check', 'Supabase integration tests — real Postgres (workflow_dispatch only)', 'Apply migrations — db reset (workflow_dispatch only)'. A Tier-1 run skips the heavy four; the step layer refuses it by name.

`NOT-GATED` is never a pass and never a FAIL-and-continue: it is a stop. A dormant job reporting
green is the gate-audit class (canon: `skills/ac-pipeline/references/` § assurance-declarations)
— how a pipeline ships unproven code while every dashboard stays green.

## Open needs-device surfaces — refuse before tagging

A required-jobs-green run is not a device sitting. From the app checkout, before Phase 0:

    bash skills/ac-publish/scripts/needs-device-gate.sh --range "$FROM..$R"

Non-empty intersection with an OPEN `needs-device` bead, or an open needs-device bead
whose `## Delivers` + AC probes yield no paths (zero-path, fail-closed): refuse and name
the bead(s). Override is `NEEDS_DEVICE_GATE_OVERRIDE=<reason>` only — a named, logged
needs-device override; an unset variable is not one.

## QA placement — by pointer, never copied

Whether QA runs at this gate or was pulled earlier is decided by the verification-gate class
table in `skills/ac-pipeline/references/` — one selection brain, consulted, never restated.
A copy of that table here would be a second selection brain, and the two would disagree
silently. Pull QA earlier only when that table says so; then pass `+qa` to `ac-prove`.

## Ship, in this order

1. **Tag the PROVEN SHA explicitly, never `HEAD`.** Phase 0 and the proof leg are done, so this
   list opens on a proven SHA that already carries its own bump. `ac-prove` pushes evidence
   commits, so by the time this step runs `HEAD` has moved past the commit that was proven.
2. **Web — promote, do not rebuild.** The artifact the proof validated is the artifact that ships:
   an alias move over its staged build, never `vercel deploy --prod`. Mechanics: `references/web-promote.md`.
3. **Native and mobile — the binary must be PROVABLY the proven SHA.** The property that
   matters is PROVENANCE, not which machine compiled it: built from the **proven SHA**, from a
   **clean tree**, with the **required check-runs green on that SHA**. CI is the DEFAULT because
   it establishes all three structurally. A local build is a **declared exception**, legal only
   when it passes the SAME gate both lanes run (`scripts/ci/testflight-gate-check.sh`), whose
   bypass must be loud, named and logged — never a silent default.
   Hand the upload to `ac-distribute` (check-only on the bump).

   > This step once read "CI-built artifacts ONLY" — unenforceable in a consuming app whose CI
   > signing lane is intermittently broken, so it was ignored (an ignored rule is worse than
   > none), and it pushed every risky ship onto the local lane while that lane had NO gate at
   > all (body-compass, 2026-08-31: `ios-release.yml` gated on check-runs, `ship-testflight.sh`
   > had zero). State the property you actually need; make both lanes able to satisfy it.
4. **Verify identity, not version strings.** Confirm what production actually serves is the
   proven SHA. Two deployments can mint the same version.

## External escapes close the outer loop

A finding that arrives from OUTSIDE — production, a user, store review, a late QA pass — is
the only signal that can tell this factory it was wrong; everything else grades itself.

**Label it with its catch-stage ON ARRIVAL** from the closed set in `skills/beads-standards/SKILL.md`
(`prod-finding`, Sentry-normalized · `qa-finding` · `ci-finding`) — the label says which gate leaked;
**write it even when the fix lands immediately** — the fix may be in-batch, the label never is.

**File the escape as a bead, born probe-bearing** (create contract § Probe): an implementable
type carries `## Acceptance Criteria` with a ``Probe: `<command>` — tier: <slug>`` bullet; the
guard refuses a probe-less create, so a filer that cannot name one files `investigation`.

## Out of scope

CI trust logic (`ac-prove`, exclusively) · the store upload itself (`ac-distribute`) · QA
selection (the class table) · inbound triage — escapes are LABELLED here, worked elsewhere.
