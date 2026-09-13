#!/usr/bin/env bash
# Static RED fixture for Check 37. The comment below is PROSE and must NOT trip the
# check — it quotes the very literal the check forbids, which is the point:
#   the old engine hardcoded $HOME/Repos/neometa/software/agent-compounds/hooks
# The code line beneath it is the violation.
AC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_DIR="$HOME/Repos/neometa/software/agent-compounds/hooks"
echo "$AC_ROOT $HOOKS_DIR"
