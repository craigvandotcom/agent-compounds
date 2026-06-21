# Shared verification gate (ac-ui-polish + ac-qa-browser + ac-qa-device)

**The selection brain for the "verify the built app" triad.** Running all three
passes on every wave is waste — a one-line copy fix does not need a simulator
boot. This file decides, from the wave's diff, **which passes run and at what
depth**. It is the single source; conductors (`ac-pipeline` Verify stage, `ac-loop`
Phase 1/2, `ac-merge`'s smoke net) consult it rather than re-deciding.

Reference it as `_shared/verification-gate.md`. Method only — zero app facts.

> **Companion docs.** *How* each pass runs (depth levels, journeys, findings=beads,
> the `QA_VALIDATION` schema) lives in `_shared/qa-shared.md`. This file owns *whether*
> and *how deep*. The two compose: this gate picks `{passes, depth}`; each pass
> executes its own method.

---

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

Run against the wave's range (`main...HEAD` on the wave branch). Fail-safe: a class
flips on when **any** file matches; ambiguity counts as a match, never a skip.

```bash
RANGE="main...HEAD"                       # wave vs base
FILES=$(git diff "$RANGE" --name-only)
NFILES=$(printf '%s\n' "$FILES" | grep -c . || true)

CLASS_NATIVE=0 CLASS_WEBUI=0 CLASS_WEBRT=0 CLASS_LOGIC=0 CLASS_RUNTIME=0

# Native shell — plugins, native projects, capacitor config/deps
printf '%s\n' "$FILES" | grep -qE '^ios/|^android/|capacitor\.config|cap-build|@capacitor' && CLASS_NATIVE=1
git diff "$RANGE" -- package.json | grep -qE '@capacitor|capacitor' && CLASS_NATIVE=1

# Web UI — visual / DOM surfaces (drives ui-polish + browser QA)
printf '%s\n' "$FILES" | grep -qE '\.(tsx|jsx|css)$' \
  && printf '%s\n' "$FILES" | grep -qE 'app/|components/|features/' && CLASS_WEBUI=1
# Design-token / spec changes are app-wide visual surface
printf '%s\n' "$FILES" | grep -qE 'globals\.css|design\.md|tailwind\.config|@neometa/brand|tokens' && CLASS_WEBUI=1

# Web runtime — non-visual but affects browser behavior (routing/data/api/hooks/middleware)
printf '%s\n' "$FILES" | grep -qE 'app/api/|route\.(ts|js)$|middleware|hooks/|lib/.*(fetch|client|store|query)' && CLASS_WEBRT=1

# Backend / logic — server, utils, db (drives review; not QA on its own)
printf '%s\n' "$FILES" | grep -qE 'lib/|utils/|server|supabase/|migrations?/|\.sql$' && CLASS_LOGIC=1

# Any runtime code at all (i.e. NOT pure docs/test/CI) → review runs
printf '%s\n' "$FILES" | grep -qvE '\.(md|mdx)$|\.test\.|\.spec\.|__tests__/|^\.github/|^docs/' && CLASS_RUNTIME=1
```

**Change classes:**

| Class | Means | Files like |
|-------|-------|-----------|
| `native` | native shell touched | `ios/`, `android/`, `capacitor.config`, plugin code, capacitor dep bump |
| `webui` | visual / DOM surface | `.tsx/.jsx/.css` under `app/components/features`, design tokens, `globals.css` |
| `webrt` | web runtime behavior | API routes, middleware, data/fetch/store/query code |
| `logic` | backend / lib / db | `lib/`, `utils/`, `server`, `supabase/`, migrations, `.sql` |
| `runtime` | any non-doc/test/CI code | everything except `.md`, tests, `.github/`, `docs/` |

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

**Native pass platform gate (reuse ac-merge semantics):** `ac-qa-device` requires
`uname = Darwin`. If `native` but not on a Mac → do **not** block; emit the
`mac-needed` note ("native-touching wave verified without device QA — run
`ac-qa-device` smoke from a Mac before the next TestFlight push").

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
the gate decides what to skip, but it always says so.

---

## Relationship to ac-merge's smoke net

`ac-merge` runs a **smoke**-only QA pass on the **post-rebase** state — the exact thing
that merges — using this same classifier. That is complementary, not redundant: the
Verify stage proves the pre-land code at gate-selected depth; ac-merge re-proves the
post-rebase code at smoke (a rebase can change what merges). If a fresh gate-selected
PASS exists for the current `HEAD` SHA, ac-merge's net may note-and-skip; otherwise it
runs smoke. Both read this file so the classifier never forks.
```
