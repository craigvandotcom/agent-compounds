#!/bin/bash
# Ultimate Bug Scanner - Claude Code Hook
# Runs on every file save for UBS-supported languages (JS/TS, Python, C/C++, Rust, Go, Java, Ruby, Swift, C#)
#
# ASSURANCE-ROLE: orphan
# PENDING-DECISION: ac-on0y.6
# This file has ZERO wiring references anywhere — not in hooks/hooks.json, not in any app's
# settings.json (verified 2026-08-26, re-verified 2026-08-27). It does not run. The header
# above describes what it WOULD do if something invoked it, which is why an undeclared
# orphan reads as coverage. Wire it or delete it: that fork is ac-on0y.6's to rule, and
# lint Check 21's escape expires the moment that bead closes.

if [[ "$FILE_PATH" =~ \.(js|jsx|ts|tsx|mjs|cjs|py|pyw|pyi|c|cc|cpp|cxx|h|hh|hpp|hxx|rs|go|java|rb|cs|csx)$ ]]; then
  echo "🔬 Running bug scanner..."
  if ! command -v ubs >/dev/null 2>&1; then
    echo "⚠️  'ubs' not found in PATH; install it before using this hook." >&2
    exit 0
  fi
  ubs "${PROJECT_DIR}" --ci 2>&1 | head -50
fi
