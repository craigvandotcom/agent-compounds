# Shared board scan (the pipeline read layer)

**The single way to read pipeline state — beads + plans + backlog — into a structured
"board."** `ac-align`, `ac-tidy`, `ac-human-session`, and `ac-dashboard` all read THIS, then
apply their own lens. **Share the read; never the judgment.** The three scans are defined ONCE here so they
can't drift across the skills that consume them.

This file owns the *read* (what to scan, how to categorize). Each consumer owns the *lens*
(what to do with it) — see "Lenses" at the bottom.

---

## Phase 0 — init

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
```

Run scans A, B, C **in parallel** (they're independent).

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
| **ready (refined)** | in `br ready` AND does NOT have the `unrefined` label |
| **unrefined** | has the `unrefined` label (needs `/ac-bead-refine`) |
| **blocked** | `status=open`, NOT in `br ready` |
| **in_progress** | `status=in_progress` |
| **closed** | `status=closed`/`done` |

Surface these labels (consumers filter on them): `human-gate`, `dream-proposal`,
`triage,<src>`, finding labels (`qa-finding`/`review-finding`/`hygiene-finding`), `qa-blocker`.
For **epics** (dependent_count > 3 or "epic" in title): count total / ready / blocked / closed
children.

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

---

## The board snapshot (shape returned to the consumer)

```
beads:    { ready[], unrefined[], blocked[], in_progress[], epics[], byLabel{} }
plans:    { draft[], refined[], approved[], beadified[], loop_ready[] }
backlog:  { active[], pool[], candidates[] }   # candidates = status:candidate
```

## Lenses (who reads this board, for what)

| Consumer | Lens (its own judgment, NOT here) | Extra reads beyond the board |
|----------|-----------------------------------|------------------------------|
| **`ac-align`** | strategy fit · `pool → active` promotion · sequencing | `_strategy/` |
| **`ac-tidy`** | lifecycle reconciliation · archival · orphan/stale flags | bead↔plan cross-references |
| **`ac-human-session`** | human gates only (apply the loop boundary: drop ready beads, in-flight waves, `loop-ready` plans) | PRs (`gh pr list`), CI (`gh run list`), prod health, org-wide `human-gate` sweep |
| **`ac-dashboard`** | render-only — the WHOLE board, both sides of the loop boundary; no judgment, no writes, no prompts | wave branches (`git branch -r`), PRs (`gh pr list`), CI (`gh run list`) |

The board is the shared substrate; the lens is each skill's reason to exist. Don't move a lens
in here, and don't re-specify a scan out there.
