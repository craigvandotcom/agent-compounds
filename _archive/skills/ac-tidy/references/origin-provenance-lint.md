# Origin Provenance Lint (Phase 2f Tier-3 addendum)

Pointed to from `SKILL.md` § 2f: Lifecycle Label Gap Lint, Report line.

**NIGHTLY (Tier 3) / INTERACTIVE (report):** flag every OPEN bead created on/after the
`origin:<skill>` cutover (`hooks/bead-capture-guard.py`) that carries no `origin:<skill>`
label. Beads from BEFORE the cutover are OUT OF SCOPE for this lint entirely — the
historical backlog has no recoverable signal and would drown the report in unfixable rows.

The cutover is a full TIMESTAMP, not a date. A date-only bound re-flags every bead filed
earlier on cutover day — beads that predate the guard and can never be fixed — so the same
rows would surface every night forever and train the reader to ignore the report.

A missing origin on a bead this new means the creation guard was bypassed (non-Claude
harness, unparseable shell) or a template is stale — a pipeline defect worth surfacing,
never papered over with an auto-stamped `origin:unknown`. **Never auto-label** — that
repair belongs to the origin check inside `skills/_tools/stamp-refined.sh` (the sole
sanctioned writer of `refined`), not this lint.

```bash
br list --json --limit 1000 | jq -r '
  .issues[]
  | select(.status == "open")
  | select((.created_at // .created // "") >= "2026-08-23T21:37:09Z")
  | select((.labels // []) as $l | ($l | any(startswith("origin:"))) | not)
  | .id'
```

Report: "Missing origin: {id} (created {created_at}) — no `origin:<skill>` label; guard
bypass or stale template, needs investigation."
