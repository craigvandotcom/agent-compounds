#!/usr/bin/env bash
# The raw-read shape Check 36 exists to make a red commit: a `br … --json` read whose
# output is captured without routing through the envelope-aware helper (br_call / the
# python twin). A br failure with --json is a valid error envelope on STDOUT and an
# EMPTY stderr, so this read converts a dead read into empty data — and the gate
# downstream reads "no labels", "no beads", "nothing stale" — and passes.
data=$(br list --json --limit 0 2>/dev/null | jq -r '.issues[].id')
printf '%s\n' "$data"