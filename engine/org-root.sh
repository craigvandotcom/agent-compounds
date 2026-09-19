#!/usr/bin/env bash
# org-root.sh — the ONE derivation of ORG_ROOT. Sourced, never executed.
#
# ORG_ROOT is the directory holding infrastructure/ beside the domain repos. Every
# rendered path that is not under AC_ROOT hangs off it, so getting it wrong does not
# fail — it writes plausible-looking garbage into every harness on the machine and is
# found weeks later by a 404.
#
# It used to be AC_ROOT's THIRD parent, repeated in engine/sync.sh, engine/exceptions.sh,
# and (as "five parents up") lint/lib/consumers.py. That is a spelled path wearing a
# derivation's clothes: it encodes the assumption that agent-compounds sits two
# directories deep inside the org (<org>/<domain-repo>/software/agent-compounds). On a
# flat layout like ~/code/agent-compounds the third parent is /Users, and the engine
# rendered `$HOME/Users/infrastructure/tools/src/lib/activity_logger.py` into a deploy
# target's PostToolUse hook — an absolute path resolving nowhere, firing on every tool
# call. `cd /Users` succeeded, so nothing downstream ever checked. lint checks 07 and 12
# went NOT-CHECKED for the same reason and reported it as "no consumer dir exists under
# /Users", which reads as an empty machine rather than a broken derivation.
#
# So: locate by MARKER, not by counting. Walk up from AC_ROOT for the first ancestor
# holding an infrastructure/ directory, which reproduces every supported layout —
#   Mac monorepo  ~/Repos/<org>/software/agent-compounds -> ~/Repos
#   three-repo    ~/mission/software/agent-compounds     -> ~
#   flat          ~/code/agent-compounds                 -> ~
# — and keeps working for a layout nobody has thought of yet. `org_root` in
# harness.config.json overrides the walk on a machine whose infrastructure lives
# somewhere it cannot see. Unresolvable is FATAL, never a guess: the whole point is
# that a plausible wrong answer here stays invisible.
#
# Callers must have set AC_ROOT and LAYOUT before sourcing. lint/lib/consumers.py
# carries the same walk in Python (a shell source is not reachable from there); the two
# are kept in step by scripts/org-root-derivation.test.sh, which exercises both.

expand_tilde() { case "$1" in "~"|"~/"*) echo "${HOME}${1#\~}" ;; *) echo "$1" ;; esac; }

resolve_org_root() {
  local explicit d
  explicit="$(expand_tilde "$(jq -r '.org_root // empty' "$LAYOUT")")"
  if [ -n "$explicit" ]; then
    [ -d "$explicit" ] || { echo "error: org_root $explicit (from $LAYOUT) is not a directory" >&2; exit 2; }
    (cd "$explicit" && pwd); return 0
  fi
  d="$AC_ROOT"
  while [ "$d" != "/" ]; do
    d="$(dirname "$d")"
    [ -d "$d/infrastructure" ] && { echo "$d"; return 0; }
  done
  echo "error: cannot locate ORG_ROOT — no ancestor of $AC_ROOT contains an infrastructure/ directory." >&2
  echo "       Clone the infrastructure repo beside the domain repos, or set \"org_root\" in $LAYOUT." >&2
  exit 2
}
