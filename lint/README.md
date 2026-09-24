# lint — the registry's own invariants and proofs

This is the self-lint for `agent-compounds`: small checks under `lint/checks/`
that guard things a careless edit could break silently — skill frontmatter
that stops parsing, a hook wired to a dead path, a bead template missing its
origin label, a growth ratchet that quietly widened. Each check owns one
invariant, declares what it scans and prevents, and proves against a fixture
it can go RED on — a check that can never fail is worse than no check.

## Two entry points

- `./lint.sh` — the invariant checks. A thin dispatcher onto `lint/run.py`,
  which discovers every `lint/checks/*`, runs the whole suite (no
  scope-to-diff selection), and prints one table.
- `bash scripts/run-all-proofs.sh` — every committed proof-test harness
  (`*.test.sh` / `*.test.py`, discovered repo-wide, incl. each check's own
  `lint/checks/NN-*.test.sh`). A proof that never runs is documentation.

## Lanes

- **pre-commit** (`hooks/pre-commit`): pinned `ruff` against the staged `.py`
  files, then `lint.sh --staged` — the whole suite against the STAGED index
  (what the commit would contain), never the working tree, with this
  machine's adopter-local inputs (board, instance tokens, `_archive/`, ...)
  linked into the snapshot read-only.
- **CI** (`.github/workflows/registry-lint.yml`): job `lint` runs
  `ruff check .`, `gitleaks`, then `bash lint.sh`; job `proofs` runs
  `run-all-proofs.sh` — separate jobs, separate checkouts.

## The check header contract

Every `lint/checks/` file (test harnesses excluded) opens with a `# ---` fenced
header carrying `prevents` and `fixture`. Enforced by `lint/checks/00-meta.py`:
the header must parse, both fields must be present, and the check must go RED
(exit 1) against its own `fixture` — a passing or skipping fixture is the
vacuous-check class.

## Exit codes

`0` pass · `1` findings/fail · `2` NOT-GATED (scanned nothing, an old
interpreter, or an incomplete checkout — never a pass) · `77` skip (its own
adopter-local input was absent), reported `NOT-FULLY-GATED`, never `ok`. `1`
outranks a bare `2`; skips alone never fail a run.

## Allowlists and the growth ratchet

One format, one library: `lint/lib/ratchet.py`. Every `lint/allowlists/*.txt`
line is `YYYY-MM-DD key  # why`; `shrink_only()` refuses a key present now but
absent from the file as committed at `base_ref()` (honours `LINT_BASE_REF`,
CI's pre-push/PR-base commit) — an allowlist may shrink or hold, never grow.

## Adding a check

Add `lint/checks/NN-name.py` (or `.sh`) with the header above, a RED fixture
(a static tree under `lint/fixtures/NN-name/`, or a `run.sh` there that builds
state and proves the RED — see an existing check for the shape that fits),
and `lint/checks/NN-name.test.sh` proving both legs. `00-meta.py` and
`run-all-proofs.sh` pick it up with no further registration.
