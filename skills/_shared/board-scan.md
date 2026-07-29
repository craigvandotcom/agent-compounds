# Shared board scan (the pipeline read layer)

**The single way to read pipeline state — beads + plans + backlog — into a structured
"board."** `ac-align`, `ac-tidy`, `ac-human-session`, `ac-dashboard`, and `ac-loop` (Phase 0
orient) all read THIS, then apply their own lens. **Share the read; never the judgment.** The four scans are defined ONCE here so they
can't drift across the skills that consume them.

This file owns the *read* (what to scan, how to categorize). Each consumer owns the *lens*
(what to do with it) — see "Lenses" at the bottom.

---

## Phase 0 — init

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
```

Run scans A, B, C, D **in parallel** (they're independent).

## Scan A — beads

```bash
br list  --json --limit 1000   # ALL beads → object {issues:[...], total, has_more, limit}
br ready --json                # unblocked + ready → a FLAT array
```

> **`br` JSON shape differs by subcommand — don't conflate them:**
> - `br list --json` returns a **paginated object** (`default limit 50`). Always pass
>   `--limit 1000` (or page on `has_more`) and iterate **`.issues[]`**, not `.[]`.
> - `br ready --json` returns a **bare array** — iterate **`.[]`**.
> Getting this wrong fails silently-ish (`jq: Cannot index array with string …`, or
> a truncated list at 50). Verified against `br` 2026-06.

Categorize every bead:

| Category | Test |
|----------|------|
| **ready (refined)** | in `br ready` AND has the `refined` label (presence, not absence of `unrefined` — `skills/_shared/bead-conventions.md`) |
| **unrefined** | lacks the `refined` label — has `unrefined`, or no lifecycle label at all (needs `/ac-bead-refine`) |
| **blocked** | `status=open`, NOT in `br ready` |
| **in_progress** | `status=in_progress` |
| **closed** | `status=closed`/`done` |

Surface these labels (consumers filter on them): `human-gate`, `dream-proposal`,
`triage,<src>`, finding labels (`qa-finding`/`review-finding`/`hygiene-finding`), `qa-blocker`.
For **epics** (dependent_count > 3 or "epic" in title): count total / ready / blocked / closed
children.

### Structural lint (parentage + edges)

Beyond the status categories above, Scan A also computes two structural lint classes —
defined ONCE here so `ac-tidy`, `ac-loop` Phase 0 orient, and standalone lint can't fork
on what "orphan" or "illegal edge" mean:

- **Parentage-gap orphan** — an open, non-epic bead with no epic parent (no `parent-child`
  edge to an epic). `human-gate` beads are EXCLUDED from this class (Arm 0 owns their
  parentage — wired at creation). This is the I1 sense of "orphan" (a bead with no home
  epic), distinct from `ac-tidy`'s older sense ("orphan = a bead referencing a plan file
  that no longer exists") — both are reported, they are different classes.
- **Authored epic-edge** — any `blocks` edge with an **epic endpoint** (either end an epic)
  is an I2 violation: epic order is derived from cross-epic bead edges, never authored
  directly (`skills/beads-standards/SKILL.md` § Sequencing & parentage). Report it ALWAYS;
  converting it into the right bead-level edge needs human judgment, so route the
  conversion to Tier 3 rather than auto-fixing.

**Edge queries read `.beads/issues.jsonl` directly.** `br list --json` (0.2.16) returns
the beads but NO dependency edges — parse the jsonl for the `blocks` / `parent-child`
relationships these two classes need.

## Scan B — plans

```bash
ls "$PROJECT_ROOT/_plans/"*.md 2>/dev/null
```

Skip `README.md`, `_done/`, `research/`, `templates/`, `checkpoints/`. Per plan, read
frontmatter:

- **status** — `draft | refined | approved | beadified | loop-ready`
- **loop-ready** — the autonomous hand-off flag (the loop owns these; humans don't sign them off again)
- **refinement_rounds** — frontmatter field, else count `### Round N` headings in the `## Refinement Log` (headings only)
- **source_backlog**, **mtime** (recency)
- **Fallback** (no frontmatter): `## Refinement Log` → `refined`; `Status: Approved` text → `approved`; referenced by a bead description → `beadified`; else `draft`. Flag the missing frontmatter for `/ac-tidy`.

## Scan C — backlog

```bash
find "$PROJECT_ROOT/_backlog" -name "*.md" \
  -not -name "_*" -not -name "ROADMAP.md" -not -name "BUSINESS-STRATEGY.md" \
  -not -path "*/_done/*" -not -path "*/_shipped/*" -not -path "*/complete/*" \
  -not -path "*/assets/*" -not -path "*/audits/*" \
  2>/dev/null
```

Per file, read frontmatter + count tasks:

- **folder** — `active/` (committed scope) · `pool/` (candidate) · legacy `v*/` (pre-migration → flag for the `{active,pool}` migration `ac-align` offers)
- **status** — `captured` · `candidate` (triage-promoted, awaiting human approval) · `planned` · `complete`
- **type / horizon / channel / source** (from the `ac-backlog` frontmatter schema)
- **unchecked task count** (`- [ ]`) vs checked (`- [x]`)
- Skip `status: complete` and items with zero unchecked tasks.

## Scan D — review coverage (the staleness probe)

**One directory, two DIFFERENT facts — conflating them is how a 7-day / 237-commit review
blackout stayed invisible (bd-zl1y5):**

- **Acceptance mark** — the last commit touching `.claude/reviews/batch/`, written by exactly
  one writer, `ac-batch-close` Act 3 (bd-kudrb). It records *"a batch was closed"*, **not**
  *"review has looked this far"*. Every legitimate non-close exit leaves it frozen while commits
  keep landing: an `ac-loop` **C2 hard stop** (correctly refuses to merge, so batch-close never
  runs), a C1/C3/C4 mid-batch exit, a crashed run, or any standalone `ac-review`. The mark going
  stale is therefore an **expected consequence of honouring a stop condition** — which is exactly
  why it must be *reported*, not trusted.
- **Coverage** — the union of the `**Range:** <sha>..<sha>` claims recorded by review artifacts
  in **whatever directory they landed in** (`.claude/reviews/` root, `pending/`, `publish/`,
  `batch/`). Directory-agnostic on purpose: root is `ac-review`'s *documented default* dest and
  writing into `batch/` from it is forbidden, so "the artifact wasn't in `batch/`" is never the
  defect. Coverage is the only honest answer to "what has actually been reviewed".

```bash
D="${ARTIFACTS_DIR:-$(mktemp -d)}"

# Acceptance mark + its gap (bootstrap: last v* tag, else the root commit).
MARK=$(git log -1 --format=%H -- .claude/reviews/batch/)
MARK_AGE_DAYS=-1
[ -n "$MARK" ] && MARK_AGE_DAYS=$(( ( $(date +%s) - $(git log -1 --format=%ct "$MARK") ) / 86400 ))
BASE=${MARK:-$(git describe --tags --match 'v*' --abbrev=0 2>/dev/null)}
[ -n "$BASE" ] || BASE=$(git rev-list --max-parents=0 HEAD | tail -1)
ACCEPT_GAP=$(git rev-list --count "$BASE..HEAD")

# Coverage. `git grep -h` (no xargs — empty input must not hang); anchored on `Range:` so only
# an EXPLICIT claim counts, and an unparseable/rewritten sha is dropped by `rev-list 2>/dev/null`.
# Both choices UNDER-credit coverage: this probe fails loud, never silently green.
git grep -hE 'Range:.*[0-9a-f]{7,}\.\.[0-9a-f]{7,}' -- .claude/reviews 2>/dev/null \
  | grep -oE '[0-9a-f]{7,40}\.\.[0-9a-f]{7,40}' | sort -u > "$D/ranges"
: > "$D/covered"
while IFS= read -r r; do git rev-list "$r" 2>/dev/null >> "$D/covered"; done < "$D/ranges"
sort -u "$D/covered" -o "$D/covered"
git rev-list "$BASE..HEAD" | sort -u > "$D/inrange"
comm -23 "$D/inrange" "$D/covered" > "$D/uncovered"
UNCOVERED=$(wc -l < "$D/uncovered" | tr -d ' ')
CODEISH=0   # the actionable subset — ONE git call, not one per commit
[ -s "$D/uncovered" ] && CODEISH=$(git log --no-walk --format='%s' --stdin < "$D/uncovered" \
  | grep -cE '^(feat|fix|perf|refactor|test)([(!]|:)' || true)
```

Verified under `bash` **and** `zsh`, and on all three degenerate inputs: no `.claude/reviews/`
at all (doc repos — `mark=none`, bootstraps to the root commit), artifacts with no `Range:` line,
and a range naming a sha this repo doesn't have.

**Staleness classification** (shared so consumers can't fork on what "stale" means):

| `staleness` | Condition |
|---|---|
| `ok` | `ACCEPT_GAP` ≤ 50 and `MARK_AGE_DAYS` ≤ 7 |
| `warn` | `ACCEPT_GAP` > 50 |
| `ALARM` | `ACCEPT_GAP` > 100, **or** `MARK_AGE_DAYS` > 7 (the same 7-day line `ac-review` § Standing weekly review already draws) |

---

## The board snapshot (shape returned to the consumer)

```
beads:    { ready[], unrefined[], blocked[], in_progress[], epics[], byLabel{} }
plans:    { draft[], refined[], approved[], beadified[], loop_ready[] }
backlog:  { active[], pool[], candidates[] }   # candidates = status:candidate
review:   { mark, mark_age_days, accept_gap, uncovered, codeish_uncovered, staleness }
```

> **A non-`ok` `staleness` is NEVER silent.** Every consumer must surface it in its own opening
> output — that is the entire reason this scan exists. A review blackout that can only be found
> by a later accident is the failure mode being fixed here, and a probe whose result is computed
> and then not printed reproduces it exactly.

## Lenses (who reads this board, for what)

| Consumer | Lens (its own judgment, NOT here) | Extra reads beyond the board |
|----------|-----------------------------------|------------------------------|
| **`ac-align`** | strategy fit · `pool → active` promotion · sequencing | `_strategy/` |
| **`ac-tidy`** | lifecycle reconciliation · archival · orphan/stale flags | bead↔plan cross-references |
| **`ac-human-session`** | human gates only (apply the loop boundary: drop ready beads, in-flight waves, `loop-ready` plans) | PRs (`gh pr list`), CI (`gh run list`), prod health, org-wide `human-gate` sweep |
| **`ac-dashboard`** | render-only — the WHOLE board, both sides of the loop boundary; no judgment, no writes, no prompts | wave branches (`git branch -r`), PRs (`gh pr list`), CI (`gh run list`) |
| **`ac-loop`** | Phase 0 orient — classify the actionable set (orphans · unrefined · plan waves · bug lane) + the parentage-gap/epic-edge structural lint, to drive the autonomous run; **print Scan D's staleness verdict, and on `ALARM` file/refresh a P1 review-blackout bead before selecting work** | `bv --robot-triage`, `loop-ready` plans, `.claude/legacy-branches.txt` |

The board is the shared substrate; the lens is each skill's reason to exist. Don't move a lens
in here, and don't re-specify a scan out there.
