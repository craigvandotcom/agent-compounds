# Risk classification — files-touched, never self-label

**Canonical path:** `agent-compounds/skills/ac-pipeline/references/risk-classification.md`
(apps symlink under `.agents/skills/_shared/` / `.claude/skills/_shared/`).

Consumers: **ac-loop**, **ac-batch-close**, **ac-review**, **ac-bead-refine**.
Every risk-gated decision keys on **files touched**, computed over a git range
or an explicit file set — **never** on a batch's self-declared kind/label.

Evidence (loop-retro 20260716-090110-36065): the three pre-merge Criticals were
all on batches that self-labeled low-risk. A gate keyed on declared kind would
have let all three accumulate or shrink-panel.

---

## ToC
- Over-inclusive bias
- §1 RISK-TOUCH globs
- §2 Test-path exclusion (mandatory)
- §3 ZERO-RUNTIME batch
- §4 Classifier method
- §5 Per-caller bindings
- §6 Fixtures (examples)
- Maintenance

## Over-inclusive bias

**When unsure, a path belongs in RISK-TOUCH.** False-risky costs one un-shrunk
panel or one un-accumulated ceremony; false-safe ships a Critical. Prefer
over-classification of inert helpers over under-classification of writers.

---

## §1 RISK-TOUCH globs

Any path matching one of these globs is a **RISK-TOUCH** candidate (subject to
test-path exclusion in §2). Literal list:

| Glob | Notes |
| ---- | ----- |
| `supabase/migrations/**` | schema / RLS / grants |
| `app/(auth)/**` | route group — `**/auth/**` does **not** match `(auth)` parens |
| `app/api/**/route.ts` | API route handlers |
| `lib/api/**` | API client / server helpers |
| `middleware.ts` | edge middleware (any depth basename) |
| `lib/db/**` | data access |
| `lib/supabase/**` | supabase clients |
| `lib/data/repos/**` | repo seam |
| `lib/services/**` | service layer |
| `lib/*.ts` | top-level lib (e.g. `lib/background-zoning.ts`); over-classifies inert helpers — fail-safe |
| `lib/hooks/**` | hooks |
| `features/**` | feature modules |
| `**/paywall/**` | paywall surfaces |
| `**/subscription/**` | subscription surfaces |
| `**/curate*` | curator tooling / surfaces |
| `ios/**` | native iOS |
| `android/**` | native Android |
| `*.plist` | native plists |

Absence of any match after §2 = non-risk.

---

## §2 Test-path exclusion (mandatory)

Paths matching **either**:

- `**/__tests__/**`
- `**/*.{test,spec}.*`

are **never** RISK-TOUCH, even when they also match a RISK-TOUCH glob
(e.g. `features/foo/__tests__/bar.test.ts` matches `features/**` but is excluded).

**Formula:**

```text
RISK = matches(RISK-TOUCH) AND NOT matches(test-path)
```

Co-located tests stay eligible for ZERO-RUNTIME fast lanes and panel shrink.

---

## §3 ZERO-RUNTIME batch

A batch is **ZERO-RUNTIME** only when **every** path in the classified set is
limited to:

| Allow | Examples |
| ----- | -------- |
| Docs | `*.md` |
| Tests | `**/__tests__/**`, `**/*.{test,spec}.*` |
| Beads ledger | `.beads/**` |
| Inert config only | `.prettierrc*`, `.editorconfig`, `.gitignore`, lint-rule config |

**Explicitly NOT inert** (any of these disqualifies ZERO-RUNTIME):

- `next.config.*`
- `tailwind.config.*`
- `middleware.ts`
- env-schema files
- feature-flag files
- any non-test / non-doc runtime source (`.ts`/`.tsx`/`.js`/`.jsx` outside the
  test-path patterns)

A test that *guards* runtime behavior still classifies ZERO-RUNTIME; the
test-quality panel body still runs when any test file is present (see
ac-review panel scaling).

---

## §4 Classifier method

### Git-range callers

1. `git diff --name-only <range>` → path list
2. Match each path against RISK-TOUCH globs (§1)
3. Apply test-path exclusion (§2)
4. Optionally check ZERO-RUNTIME allowlist (§3) over the full path list

### File-set callers

Same steps 2–4 over the supplied file set (no git range).

---

## §5 Per-caller bindings

Five bindings — **3 git-range + 2 file-set**. Callers reference these by name;
do not invent alternate windows.

### 1. ac-batch-close (git-range)

Ceremony batch range:

| Batch shape | Range |
| ----------- | ----- |
| **pool-only** | union of `in_flight` members' `pre_sha..close_sha` |
| **mixed** (pool + risk sidecar) | that union **∪** risk bead's `pre_sha..close_sha` |
| **planned-wave / pure risk-solo** | that batch's own range |

### 2. Item 1 pool line-floor / batch scope (git-range)

Union of **pending** members' stored `pre_sha..close_sha`.

**Not** raw `<last-ceremony-anchor>..HEAD` — that window diverges from pool
membership when waves or other ceremonies interleave. Soft-8 / hard-10 / 3h
count beads from **pool state** (ID count + timestamps), not from a git range.

### 3. Item 1 per-close risk gate (git-range)

The bead's own `pre_sha..close_sha` (pathspec commit(s) for that bead only —
same object later stored in the pool).

**Not** open-ended `..HEAD` (under width-N fan-out, sibling commits would
otherwise pollute the window). RISK-TOUCH → do not accumulate; fire immediately
(Item 1 risk override).

### 4. Item 5 single-bug (file-set)

File set from the bug's root-cause trace (trace precedes the fix).

### 5. Item 4 light-path hard gate (file-set)

File set of the bead under refine (same files the refine stamp will cite).

---

## §6 Fixtures (examples)

| Diff content | Classification |
| ------------ | -------------- |
| `lib/db/foods.ts` | **risky** (matches `lib/db/**`) |
| `*.md`-only | **zero-runtime** (docs allowlist; no RISK-TOUCH) |
| `features/foo/__tests__/bar.test.ts`-only | **zero-runtime** — not RISK-TOUCH despite `features/**` (test-path exclusion) |

---

## Maintenance

- Edit this file only; consumers link here by path, never copy the glob list.
- Bias remains over-inclusive: new runtime write/auth/native surfaces default
  into RISK-TOUCH when discovered.
- Plan authority: `_plans/_done/2026-07-18-1130-loop-efficiency-pass.md` Item 0
  (bd-chd5p.1).
