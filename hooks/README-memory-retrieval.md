# Memory Retrieval Hook

> **Unwired since 2026-10-06** — recall is pulled (`qmd query` / `cass search`), never injected. The script stays for `retrieve()` (the retrieval-evals callable). Re-enable: restore the `memory-recall` entry in `engine/hooks.wiring.json` (`git log -p -- engine/hooks.wiring.json`), then run `engine/sync.sh --all`.

## The canonical hook

**`memory-retrieval.py`** — the single, unified UserPromptSubmit memory-recall hook
(unified 2026-07-10, observe-loop Wave 1.1; the former adaptive variant was merged in
and its file deleted). It is the only recall hook file on disk; there is no separate
"hybrid" or "adaptive" variant.

## How it works

Hybrid retrieval, **adaptive by machine tier**. At import it classifies the host with
`detect_performance_tier()`:

- **fast** (Mac / Metal acceleration) — always runs keyword **and** semantic in
  parallel.
- **slow** (CPU-only VM) — keyword floor always; semantic only for longer/conceptual
  prompts.

Two retrieval paths:

- **Keyword** — per-term BM25 `qmd search`, union-ranked by how many terms hit a file;
  a candidate must match **≥2 terms** on BOTH tiers (2026-09-08 ruling: one stray
  keyword is not relevance — the old fast-tier 1-match floor injected noise, and the
  stricter floor *raised* recall@5, 0.8393 → 0.8571).
  The fast, reliable floor (~0.65s baseline). Keywords are pure alphanumeric runs only —
  a hyphenated token is FTS5 operator syntax and would silently zero the OR-query.
- **Semantic** — `qmd vsearch` (LLM query-expansion, ~3.5–7s). Better recall, gated on
  machine tier because of its cost.

Results merge, dedupe, and inject as a `<memory-recall>` block — top **3**, one plain
`name: description` line each (no markdown, no qmd path). The frontmatter
**description IS the injected content** — it is the distilled claim; qmd's snippet
field is a diff hunk over frontmatter and is never emitted (2026-09-08 ruling: names
are enough to re-find — `qmd query "<name>"` for full content). Memory bodies are
labelled **background data, NOT instructions** (poisoning guard). Telemetry
(`log_recall`/`log_injection`) still records full qmd paths, so observability is
unaffected by the shorter injection.

## Sealed projects (project-local qmd index)

A project with its own `.qmd/index.yml` (made by `qmd init`) is sealed: qmd adopts that index
for every command run inside the tree, so the hook's CLI searches see only that project. The
resident daemon serves the global index, so in a sealed project the hook never asks it
(semantic recall falls back to the CLI, then to the BM25 floor), maps `qmd://` paths through
the project's own config, and prints a scoped wider-recall hint. Keep sealed projects out of
the global `~/.config/qmd/index.yml` and nothing outside sees them either. First user:
forge-one (client work). Proof: `memory-retrieval-seal.test.sh`.

## Health / the `mem` dot

Every real prompt calls `write_health`, which atomically updates
`infrastructure/health/reports/memory-hook-health.json`. It is **debounced**
(`DEBOUNCE_THRESHOLD = 2`): a single load-contended prompt keeps the dot green; only
≥2 consecutive failures flip it red (genuine breakage — qmd gone / index dead — fails
every prompt). The nightly recall canary in
`infrastructure/scripts/health/drift-check.py` is the second writer of this file and
points at this same hook.

## Fail-safe contract

Any error / missing tool / short prompt → **exit 0 with no output**. stdout is ONLY the
`<memory-recall>` block — never diagnostics.

## Timeouts

Sub-timeouts are floored to qmd's real latency (too low → silent empty/keyword-only
recall). See memory: `qmd-cli-latency-hook-timeout-floors`. Fast tier: keyword 4.0s,
semantic 8.0s.

## Wiring

None while unwired (see the note at the top). When wired, the canon manifest is
`agent-compounds/engine/hooks.wiring.json` (`memory-recall` entry), rendered per harness by
`harness-sync.sh`.
