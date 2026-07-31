#!/usr/bin/env bash
# Is DCG_CONFIG honoured at all? Use a policy override as the discriminator:
# a rule that BLOCKS by default should downgrade to a warning under
# [policy] default_mode = "warn". Fixture lives in a file so the scanned
# command line never contains the literal.
D="$(dirname "$0")"
DCG="$HOME/.local/bin/dcg"
mkdir -p "$D/fixtures"

# a command dcg blocks by default (core.git:checkout-discard)
printf '{"tool_name":"Bash","tool_input":{"command":"git %s -- lib/foo.ts"}}' "checkout" \
  > "$D/fixtures/blocked.json"

cat > "$D/warn.toml" <<'TOML'
[policy]
default_mode = "warn"
TOML

verdict() { # $1 = optional config
  local out
  if [ -n "$1" ]; then out="$(DCG_CONFIG="$1" "$DCG" < "$D/fixtures/blocked.json" 2>&1)"
  else out="$("$DCG" < "$D/fixtures/blocked.json" 2>&1)"; fi
  if printf '%s' "$out" | grep -q BLOCKED; then echo BLOCKED
  elif printf '%s' "$out" | grep -qi warn; then echo WARNING
  else echo SILENT; fi
}

echo "no config       : $(verdict '')"
echo "DCG_CONFIG=warn : $(verdict "$D/warn.toml")"
echo
echo "If both say BLOCKED, DCG_CONFIG is NOT being honoured by this build/invocation."
