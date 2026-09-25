# Sanitized escaped data-fix fixture

This fixture is derived from the structure of the escaped production-write bead. Every
identifier and value is a placeholder; it contains no real table, row, project, or data.

## Intent

A catalog entry can drift from the controlled vocabulary. The `<catalog-table>` row
`<slug>` has `<field> = {<bad-value>}` persisted, and the repair is (c) a one-off data fix
for the affected row(s).

## Acceptance Criteria

- The `<slug>` row no longer persists the bare `<bad-value>` value — it carries the
  vocabulary term `<good-value>` — and the route taken is recorded with the before/after
  value.
  Probe: `bash skills/_tools/prod-write-tripwire.test.sh` — tier: standing-harness

## Delivers

- skills/_tools/prod-write-tripwire.sh

## Consumes

- none
