# Shared verification gate — THE pass-selection brain

**Selects which verification passes run, at what depth, for any diff or scope.**
Primary executors: the `ac-ui-polish` + `ac-qa-browser` + `ac-qa-device` triad;
consumed by every ceremony that verifies (loop Verify stage, the merge/batch-close
smoke net § below, `ac-prove`, `ac-distribute`). One brain — selection is never
re-decided locally (Pass C, ac-gcj.7). Running all three
passes on every wave is waste — a one-line copy fix does not need a simulator
boot. This file decides, from the wave's diff, **which passes run and at what
depth**. It is the single source; conductors (`ac-loop`
Phase 1/2, `ac-merge`'s smoke net) consult it rather than re-deciding.

Reference it as `ac-pipeline/references/verification-gate.md`. Method only — zero app facts.

> **Companion docs.** *How* each pass runs (depth levels, journeys, findings=beads,
> the `QA_VALIDATION` schema) lives in `ac-pipeline/references/qa-shared.md`. This file owns *whether*
> and *how deep*. The two compose: this gate picks `{passes, depth}`; each pass
> executes its own method.

---

## ToC
- Two axes
- Step 1 — classify the diff
- Step 1b — reachability (can the selected harness SEE the change?)
- Step 2 — select passes + depth
- Journey registry
- Step 3 — override hooks (force, regardless of diff)
- Step 4 — emit the decision line (mandatory — never skip silently)
- Ceremony smoke net (ac-merge / ac-batch-close) — the one definition
- Format-first gate

## Two axes

Selection and depth are independent — don't conflate them:

- **Selection** — *which* of the three run → driven by **what plane the diff touched**.
- **Depth** — smoke / full / exhaustive (defined in `qa-shared.md`); for ui-polish,
  Scoped vs Whole-app → driven by **blast radius / risk**.

`ac-review` (code-correctness) is **not** in this triad — it is near-mandatory and
gated only on *effort*, not existence (see the table). The triad is the *runtime/visual*
verification; review is the *static* one. Both are pre-merge.

---

## Step 1 — classify the diff

Run against the batch's range: everything since the review-mark (the last commit that
touched `.claude/reviews/batch/` — same anchor as `ac-review`'s trunk-direct scope
detection; bootstrap fallback when no batch commit exists yet: the last `v*` tag).
Fail-safe: a class flips on when **any** file matches; ambiguity counts as a match,
never a skip.

```bash
# Review-mark anchor (identical computation to ac-review Phase 1 — keep in sync).
# Single-writer invariant (bd-kudrb): ONLY ac-batch-close's Act 3 commits to
# .claude/reviews/batch/. ac-review stages its findings report in the sibling
# .claude/reviews/pending/, which this probe deliberately cannot see — otherwise the
# probe returns a commit inside the range it is meant to bound and the gate silently
# under-scopes (no error, just fewer files classified).
REVIEW_MARK=$(git log -1 --format=%H -- .claude/reviews/batch/)
if [ -n "$REVIEW_MARK" ]; then
  RANGE="$REVIEW_MARK..HEAD"              # batch vs review-mark
else
  RANGE="$(git describe --tags --match 'v*' --abbrev=0)..HEAD"   # bootstrap: last v* tag
fi
FILES=$(git diff "$RANGE" --name-only)
NFILES=$(printf '%s\n' "$FILES" | grep -c . || true)

CLASS_NATIVE=0 CLASS_WEBUI=0 CLASS_WEBRT=0 CLASS_LOGIC=0 CLASS_RUNTIME=0

# Doc/test/CI files have NO runtime surface: exclude them ONCE here, then classify every
# surface-bearing class off $CODE_FILES (bd-55f7a: a lone `ios/App/fastlane/README.md` selected
# a full qa-device simulator pass; bd-mdbhr: `supabase/README.md` alone set CLASS_LOGIC=1,
# `hooks/README.md` CLASS_WEBRT=1). Same list as PAT_DOC_TEST_CI in journey-stamp-check.sh —
# keep in sync (`^\.beads/`/`^scripts/ci/` rationale: §Journey registry). EXACTLY ONE probe
# opts out and reads unfiltered $FILES — CLASS_WEBUI's design-token line, where markdown IS the
# surface. A second $FILES reader re-opens this hole; a blanket hoist breaks that opt-out.
PAT_DOC_TEST_CI='\.(md|mdx)$|\.test\.|\.spec\.|__tests__/|^\.github/|^docs/|^\.beads/|^scripts/ci/'
CODE_FILES=$(printf '%s\n' "$FILES" | grep -vE "$PAT_DOC_TEST_CI" || true)

# Native shell — plugins, native projects, capacitor config/deps. The package.json content
# check is deliberately OUTSIDE the exclusion (deps classify by content, not path).
printf '%s\n' "$CODE_FILES" | grep -qE '^ios/|^android/|capacitor\.config|cap-build|@capacitor' && CLASS_NATIVE=1
git diff "$RANGE" -- package.json | grep -qE '@capacitor|capacitor' && CLASS_NATIVE=1

# Web UI — visual / DOM surfaces (drives ui-polish + browser QA)
printf '%s\n' "$CODE_FILES" | grep -qE '\.(tsx|jsx|css)$' \
  && printf '%s\n' "$CODE_FILES" | grep -qE 'app/|components/|features/' && CLASS_WEBUI=1
# Design-token / spec changes are app-wide visual surface — THE deliberate opt-out:
# `design.md` is markdown by design, so this probe alone reads $FILES, not $CODE_FILES.
printf '%s\n' "$FILES" | grep -qE 'globals\.css|design\.md|tailwind\.config|@neometa/brand|tokens' && CLASS_WEBUI=1

# Web runtime — non-visual but affects browser behavior (routing/data/api/hooks/middleware)
printf '%s\n' "$CODE_FILES" | grep -qE 'app/api/|route\.(ts|js)$|middleware|hooks/|lib/.*(fetch|client|store|query)' && CLASS_WEBRT=1

# Backend / logic — server, utils, db (drives review; not QA on its own)
printf '%s\n' "$CODE_FILES" | grep -qE 'lib/|utils/|server|supabase/|migrations?/|\.sql$' && CLASS_LOGIC=1

# Any runtime code at all (i.e. NOT pure docs/test/CI) → review runs
printf '%s\n' "$CODE_FILES" | grep -q . && CLASS_RUNTIME=1
```

**Change classes:**

| Class | Means | Files like |
|-------|-------|-----------|
| `native` | native shell touched | `ios/`, `android/`, `capacitor.config`, plugin code, capacitor dep bump — **not** `.md` under `ios/`/`android/` |
| `webui` | visual / DOM surface | `.tsx/.jsx/.css` under `app/components/features`, design tokens, `globals.css` |
| `webrt` | web runtime behavior | API routes, middleware, data/fetch/store/query code |
| `logic` | backend / lib / db | `lib/`, `utils/`, `server`, `supabase/`, migrations, `.sql` |
| `runtime` | any non-doc/test/CI code | everything except `.md`, tests, `.github/`, `docs/` — proof harness for all 5 classes: `ac-pipeline/scripts/verification-gate-class.test.sh` (run it after ANY Step 1 edit) |

---

## Step 1b — reachability (can the selected harness SEE the change?)

Class-based selection alone can mandate a pass whose harness structurally **cannot observe**
the changed surface — and that pass then reports PASS. Observed (RUN 20260729-170058-3584):
paywall trial copy classified `webui`+`logic`, Step 3's payment override forced qa-browser at
`full`, but the copy sits behind an `isNativePlatform()` gate and cannot render in a browser at
all; 2 of 3 assertions returned `NOT_PROVABLE_IN_BROWSER` and the verdict still read PASS.

Before selecting, intersect the changed surface with what each harness can observe, using
§Journey registry fields already present: a journey whose `proof.required` is `sim-drive` or
`device-only`, or whose `surfaces` are native-only, is **out of reach of a browser pass** — as
is a native-gated code path inside an otherwise web-reachable journey. Out of reach ⇒ never
silently select-and-pass. Skip with a stated reason, or run it for the in-reach parts only; in
both cases (a) name the out-of-reach surface in Step 4's decision line — same
visible-not-silent rule as a skip — and (b) file a tracking bead for the residue. An
out-of-reach surface is UNVERIFIED and can never be discharged by a PASS
(`qa-shared.md` §Verdict files: that is `INCONCLUSIVE`, a third state).

---

## Step 2 — select passes + depth

| Wave touches… | ac-review | ac-ui-polish | ac-qa-browser | ac-qa-device |
|---|---|---|---|---|
| Docs / comments only (`!runtime`) | — | — | — | — |
| Tests / CI only (`!runtime`) | low effort | — | — | — |
| Backend logic / db, no UI (`logic`, `!webui !webrt`) | ✓ (effort ∝ risk) | — | smoke *if it feeds UI* | — |
| Web runtime only (`webrt`, `!webui`) | ✓ | — | **smoke/full** | — |
| Web UI (`webui`) | ✓ | **Scoped** | **smoke/full** | — |
| Native shell (`native`) | ✓ | Scoped *if `webui` too* | smoke | **✓** (Mac only) |
| Release / auth / payments / migration / version bump | ✓ high | Whole-app *if `webui`* | full | full (Mac) |

**Depth derivation** (take the highest that applies):

```
smoke       — single plane, ≤ ~5 files, one journey area
full        — multiple surfaces, cross-cutting change, several journeys, or > ~5 files
exhaustive  — release / version bump, or any file matching auth|session|payment|migration|\.sql
```

**ui-polish scope:** `Scoped` (changed surfaces only) by default; `Whole-app` only on
release or when design tokens / `design.md` / `globals.css` / brand changed (app-wide
visual blast).

**ui-polish execution mode (depth-gated fan-out):** at `smoke` depth (or a Scoped run
of ≤ ~3 routes) run the single-context inline path (`audit-and-elevate.md`). When this
gate selects ui-polish at **`full` or `exhaustive`** depth, run the per-route fan-out
(`ac-ui-polish/workflows/whole-app-workflow.md`) — over the wave's touched routes at
`full`, all routes at `exhaustive`/Whole-app. Gate selection at these depths is
**standing authorization** for that workflow's multi-agent opt-in (decision 2026-07-12);
manual ad-hoc invocations still require explicit opt-in.

**Native pass platform gate (reuse ac-merge semantics):** `ac-qa-device` requires
`uname = Darwin`. If `native` but not on a Mac → do **not** block; emit the
`mac-needed` note ("native-touching wave verified without device QA — run
`ac-qa-device` smoke from a Mac before the next TestFlight push").

**Registry-driven smoke selection (replaces "primary journey"):** the smoke pass's
journey list is not ad hoc — it's every journey in the registry (§Journey registry
below) whose `surfaces` intersects the wave's diff-classes (Step 1) AND whose
`criticality` ≥ `core`. Affected-only preserved: a journey whose surfaces the wave
didn't touch doesn't re-drive.

---

## Journey registry

**Canonical schema home** for journey frontmatter (`ac-pipeline` Invariant 9
points here). No new file kind — existing journey docs gain structured frontmatter.
Journey docs live at each app's `CORE/journeys/*.md` (consumer apps:
`.claude/skills/CORE/journeys/*.md`).

```yaml
---
journey: paywall
criticality: review-critical        # review-critical | commerce | core | peripheral
surfaces: [native, webui]           # this gate's diff-classes (Step 1) that touch it
mutates: true                       # writes app state (create/edit/delete, settings, transactions)?
proof:
  required: sim-drive               # sim-drive | browser-drive | device-only
  asserts:                          # the observable(s) that constitute PASS — behavior, not presence
    - "plan cards render LIVE store data (not placeholders)"
    - "purchase CTA ENABLED"
  device_only_steps:                # honest residue the sim can't prove
    - "StoreKit purchase completion (sandbox payment sheet)"
last_pass:                          # written ONLY by QA twins, never by hand
  build: "34"
  sha: "87e8a251"
  date: 2026-07-07
  platform: ios-simulator
---
```

Conventions: `criticality` is a ranked scale — `review-critical > commerce > core >
peripheral` — the order every `≥` comparison in this file uses. `criticality` and
`proof.required` are set by humans (plan/bead review); `last_pass` is machine-written
only by the QA twin that drove the journey, in the same run that emits `QA_VALIDATION`
(`qa-shared.md`) — never hand-edited otherwise. No frontmatter on a journey doc =
`peripheral` by default (adoption is incremental).

`mutates:` feeds the QA twins' lane split (`qa-shared.md` conductor/worker protocol):
`mutates: false` journeys are eligible for the browser twin's parallel lane; **absent ⇒
`true`** (serialize — fail-safe, since app test accounts are typically shared and a
misclassified parallel run races on data). Set by humans alongside `criticality`.

Staleness (store gate): `skills/_tools/journey-stamp-check.sh` re-uses Step 1's
class patterns over `last_pass.sha..ship-sha`, with one deliberate asymmetry — a
file matching no class counts as touching EVERY surface there (selection may err
loose; a store-submission gate errs strict: over-block, never under-block).

**The over-block only works if genuinely surface-less files are excluded first**
(2026-07-22). Measured failure: `.beads/issues.jsonl` is written by every `br close`
— it appeared in 50 of the last 50 commits — and, being unclassifiable, over-blocked
to *every* surface. So every bead operation marked every review-critical journey
STALE, and the store lane was permanently BLOCKED for a reason unrelated to code
risk. A QA drive could never hold: pass, stamp, close one bead, blocked again.
Excluding `^\.beads/` and `^scripts/ci/` restores the intended behaviour. Dependency
manifests (`package.json`, `pnpm-lock.yaml`) are deliberately NOT swept into that
exclusion — they are classified explicitly so the capacitor content check decides
their native-relevance, which the catch-all had been pre-empting (making that check
dead code).

**Enumeration tripwire (mechanical, no judgment):**

```bash
git diff "$RANGE" --diff-filter=A --name-only | grep -qE 'app/.*page\.(tsx|jsx)$' && ADDED_ROUTE=1
git diff "$RANGE" --name-only | grep -q 'CORE/journeys/.*\.md$' && TOUCHED_JOURNEY_DOC=1
```

`ADDED_ROUTE=1` and `TOUCHED_JOURNEY_DOC` unset → flag it in the Step 4 decision line
("wave adds a route with no matching journey-doc update — tag it in the registry").
Never blocks; pure file-pattern detection closing the hole where a new user-facing
surface ships untagged and silently unprotected — the failure one level up from the
registry itself.

---

## Step 3 — override hooks (force, regardless of diff)

- **Open `qa-blocker` bead on a plane** → force re-run that plane's QA. (Same bead
  that gates `ac-merge`.)
- **auth / session / payment / migration touched** → never smoke; min depth `full`,
  review at high effort.
- **Explicit human request** ("run a full device QA") → honor over the gate.

---

## Step 4 — emit the decision line (mandatory — never skip silently)

A skip must be *visible*, or a no-run reads as "verified". Print one line into the
conductor's report / Slack notify:

```
Verification plan: ran review(<effort>) + ui-polish(<scope>) + qa-browser(<depth>);
skipped qa-device — no native-shell files in diff.
```

State every skip and its reason. This is the *silent-failure → add-visibility* rule:
the gate decides what to skip, but it always says so. Also append the §Journey
registry enumeration-tripwire flag when it fires — same visible-not-silent treatment.

---

## Ceremony smoke net (ac-merge / ac-batch-close) — the one definition

The closing ceremony (`ac-batch-close`; `ac-merge` on the surviving PR path) runs a
**smoke**-only QA pass on the state that actually ships, using this same classifier.
Complementary, not redundant: the Verify stage proves pre-close code at gate-selected
depth; the ceremony re-proves post-change code at smoke (the diff can change between
verify and close). If a fresh gate-selected PASS exists for the current `HEAD` SHA,
note-and-skip; otherwise run the net below with the ceremony's own `<RANGE>`
(`main...HEAD` on the PR path; `$ANCHOR...HEAD` on the batch path). Both ceremonies
read THIS section — the conditions never fork (ac-gcj.5).

**Device twin (hybrid/native apps only) — three conditions, all must hold, else skip
silently:**

```bash
[ -d ios ] || SKIP_SIM_SMOKE=1                                  # 1. native app exists
git diff <RANGE> --name-only | grep -qE '^ios/|capacitor\.config|cap-build|@capacitor' \
  || git diff <RANGE> -- package.json | grep -qE '@capacitor|capacitor' \
  || SKIP_SIM_SMOKE=1                                           # 2. native-adjacent diff
[ "$(uname)" = "Darwin" ] || SKIP_SIM_SMOKE=mac-needed          # 3. simulators need Xcode
```

- **All hold** → load `ac-qa-device/SKILL.md`, run a **smoke** pass (build, launch, auth,
  then the journeys §Journey registry selects — surfaces ∩ diff-classes AND criticality
  ≥ `core`). ~2–3 min on a warm sim.
- **Smoke FAILS** → STOP before the ceremony proceeds. Report the `QA_VALIDATION` block
  (`platform: ios-simulator`) and ask: abort (fix first) vs proceed anyway (not
  recommended).
- **`mac-needed`** (native-touching diff, not on a Mac) → do NOT block; surface a loud
  report note: "native-touching change shipped without device QA — run `ac-qa-device`
  smoke from a Mac session before the next TestFlight push."

**Browser twin (any OS):** if the diff touched web UI
(`git diff <RANGE> --name-only | grep -qE '\.(tsx|jsx|css)$|app/|components/'`), load
`ac-qa-browser/SKILL.md`, run a **smoke** pass against the dev server. FAIL reports
`QA_VALIDATION` (`platform: browser-local`) and STOPs the same way; no `mac-needed`
escape. Either twin can also be run manually at any time ("run a device/browser QA
smoke"), independent of this net.

**QA-blocker check (beads projects, runs regardless of platform):**

```bash
br list --json --limit 1000 | jq '[.issues[] | select(.labels // [] | index("qa-blocker")) | select(.status != "closed")] | length'
```

Open `qa-blocker` beads are unresolved user-facing breaks — treat exactly like failing
required checks: STOP and ask (fix first vs proceed with explicit override). Valid
resolutions: fix the bug, or — if intended behavior — update the journey doc and close
the bead. Note: the net covers the **QA twins** only; `ac-ui-polish` is a Verify-stage
pass, never re-run at close.

---

## Format-first gate

**Canonical home for the format-first rule.** Consumers (`ac-merge`, `ac-hygiene`,
`ac-implement`, `ac-land`) carry the rule + a one-clause why and mirror-mark this
section — edit here first, then propagate.

**Format is the first step of every local quality gate, and it AUTO-FIXES.** CI's
Quality Gate runs `prettier --check .` over the whole repo as its *first* step; a
single unformatted file — even one you didn't touch that was already red on `main` —
fails the entire gate ~10 min into CI. Running `pnpm format` locally makes that
impossible for sub-second cost; if it rewrites pre-existing files, commit the
formatting (you're repairing a gate CI was already failing). Also **commit without
`--no-verify`** — the pre-commit `lint-staged` hook auto-formats staged files; only
the *push* uses `--no-verify` (to skip the heavy pre-push build). Never let CI catch
a formatting miss.
