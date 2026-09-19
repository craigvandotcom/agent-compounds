#!/usr/bin/env bash
# The NEAR-MISS for Check 36: a `br … --json` appearing only inside a quoted DIAGNOSTIC.
# Naming the readers you tried is not reading through them.
#
# This file must stay CLEAN; raw-caller.sh beside it must stay RED. A change that flips
# either one has broken the check.
set -uo pipefail

ungated() { echo "NOT-GATED: $1" >&2; exit 2; }

CLAIMS=$(br_call coordination status --json 2>/dev/null) || CLAIMS=""
[ -n "$CLAIMS" ] || ungated "neither 'br coordination status' nor 'br list --json' yielded claim state; liveness is unknown"

# Single quotes never interpolate, so a br token inside them is prose too.
echo 'run br list --json yourself if you want the raw envelope'

printf '%s\n' "$CLAIMS"
