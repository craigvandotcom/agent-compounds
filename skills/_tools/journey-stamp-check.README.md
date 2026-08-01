# \_tools/journey-stamp-check.sh

Mechanical staleness gate for **review-critical journeys**. Consumed by
`ac-distribute`'s store-release precondition (§5 decision 5 of
`_plans/2026-07-07-runtime-proof-doctrine.md`): the staleness rule (SHA-ancestry
AND no intervening surface diff) can't be eyeballed, so distribute invokes this
script in the app repo rather than trusting memory that "QA passed."

**Runs in the APP repo, not agent-compounds** — same distribution model as
`crawl-and-capture`: shipped with the registry, invoked by path from the
consuming app.

## What it checks

Parses the YAML frontmatter of every `<app>/.claude/skills/CORE/journeys/*.md`.
A doc with **no frontmatter** is `peripheral` by convention and ignored — only
journeys tagged `criticality: review-critical` gate anything. For each one:

| Verdict | Meaning |
|---------|---------|
| `MISSING` | no `last_pass` stamp recorded (or `sha` empty) |
| `STALE`   | `last_pass.sha` is not an ancestor of the ship SHA, OR a file in `last_pass.sha..<ship-sha>` touches one of the journey's declared `surfaces` |
| `OK`      | stamp is an ancestor and no intervening diff touched a declared surface |

Surface-touch detection reuses the diff classifier in
`ac-pipeline/references/verification-gate.md` Step 1 (native/webui/webrt/logic/runtime),
reimplemented as a path-pattern table at the top of the script. **Conservative
by design:** a changed file that matches none of the specific patterns still
counts as touching every surface — over-block, never under-block.

## Usage

```bash
skills/_tools/journey-stamp-check.sh \
  --app /path/to/app-repo \
  --sha <ship-commit-sha> \
  --lane store
```

| Flag    | Default   | Notes |
|---------|-----------|-------|
| `--app` | cwd       | path to the app repo (must contain `.claude/skills/CORE/journeys/`) |
| `--sha` | `HEAD`    | the commit being shipped |
| `--lane`| `store`   | `store` blocks on any MISSING/STALE review-critical journey; `testflight` never blocks — prints `WARN` lines instead |

## Output

One line per review-critical journey: `<VERDICT>  <journey>: <reason>` (or
`WARN  <journey>: <verdict> — <reason>` on the testflight lane). If no
review-critical journeys exist yet, prints a note and exits 0 — adoption is
incremental.

**Exit codes:** `0` clean, or lane=testflight regardless of findings · `1`
lane=store with ≥1 MISSING/STALE review-critical journey · `2` usage/setup
error (bad `--lane` value, `--app` not a git repo, etc.). A missing
`CORE/journeys/` directory is NOT an error — it means the app hasn't adopted
the registry yet; the script prints a note and exits 0.

## Requires

Plain bash (`set -euo pipefail`) + `git` + `awk`/`sed`/`grep`. No `yq`, no
Python — the frontmatter parser is a small hand-rolled scalar/block extractor,
not a general YAML parser (flow-style `surfaces: [a, b]` only; block-style
lists aren't supported — keep journey frontmatter to the documented shape in
`_plans/2026-07-07-runtime-proof-doctrine.md` §3b).

## Tuning the surface→path table

The path-pattern table at the top of the script is the one thing meant to be
hand-tuned per app if its layout diverges from the classifier's assumptions
(e.g. a monorepo with a nested `package.json`, or routes outside `app/`). Keep
it in sync with `ac-pipeline/references/verification-gate.md` by hand — there is no shared
source both files import from.
