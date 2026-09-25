#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROSTER="$SCRIPT_DIR/agent-roster.py"
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
FAILURES=0
CASES=0

expect() {
  CASES=$((CASES + 1))
  if [ "$1" = pass ]; then
    printf 'ok   %s\n' "$2"
  else
    printf 'FAIL %s\n' "$2"
    FAILURES=$((FAILURES + 1))
  fi
}

contains() {
  case "$1" in
    *"$2"*) return 0 ;;
    *) return 1 ;;
  esac
}

mkdir -p "$W/example-app" "$W/missing" "$W/slashed"
printf '# x\n\nAgent Mail project key: `example-app`\n' >"$W/example-app/AGENTS.md"
printf 'Agent Mail project key: `acme/example-app`\n' >"$W/slashed/AGENTS.md"

python3 - "$W/mail.sqlite3" "$W/example-app" <<'PY'
import datetime
import sqlite3
import sys

db, project_root = sys.argv[1:]
con = sqlite3.connect(db)
con.executescript("""
CREATE TABLE projects (id INTEGER PRIMARY KEY, human_key TEXT NOT NULL, slug TEXT NOT NULL);
CREATE TABLE agents (
  id INTEGER PRIMARY KEY,
  project_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  program TEXT NOT NULL,
  model TEXT NOT NULL,
  retired_at TEXT,
  last_active_ts TEXT NOT NULL
);
""")
projects = [
    (1, "example-app", "example-app"),
    (2, project_root, "tmp-example-app"),
    (3, "acme/example-app", "acme-example-app"),
    (4, "other-app", "other-app"),
]
now = datetime.datetime.now(datetime.timezone.utc).isoformat()
agents = [
    (1, 1, "CanonicalAgent", "opencode", "space-bunny-free", now),
    (2, 2, "AbsoluteAgent", "opencode", "space-bunny-free", now),
    (3, 3, "PrefixedAgent", "claude-code", "opus", now),
    (4, 4, "OtherAgent", "claude-code", "opus", now),
]
con.executemany("INSERT INTO projects(id, human_key, slug) VALUES (?, ?, ?)", projects)
con.executemany(
    "INSERT INTO agents(id, project_id, name, program, model, last_active_ts) "
    "VALUES (?, ?, ?, ?, ?, ?)",
    agents,
)
con.commit()
con.close()
PY

output=$(PROJECT_ROOT="$W/example-app" \
  MCP_AGENT_MAIL_DB="$W/mail.sqlite3" \
  MCP_AGENT_MAIL_URL="http://127.0.0.1:1" \
  python3 "$ROSTER" 2>"$W/example.err")
rc=$?
if [ "$rc" -eq 0 ]; then expect pass "keyed roster exits 0"; else expect fail "keyed roster exits 0 (got $rc)"; fi
if contains "$output" $'CanonicalAgent\t'; then expect pass "canonical agent appears"; else expect fail "canonical agent appears: $output"; fi
if contains "$output" $'AbsoluteAgent\t' || contains "$output" $'PrefixedAgent\t'; then expect fail "forked-key agents stay off the roster"; else expect pass "forked-key agents stay off the roster"; fi
if contains "$output" $'#split\t2\t'; then expect pass "split line counts both forks"; else expect fail "split line counts both forks: $output"; fi
if contains "$output" "OtherAgent"; then expect fail "unrelated repo is ignored"; else expect pass "unrelated repo is ignored"; fi
if contains "$output" $'#mail\t'; then expect pass "health line is preserved"; else expect fail "health line is preserved: $output"; fi

missing_output=$(PROJECT_ROOT="$W/missing" \
  MCP_AGENT_MAIL_DB="$W/mail.sqlite3" \
  MCP_AGENT_MAIL_URL="http://127.0.0.1:1" \
  python3 "$ROSTER" 2>"$W/missing.err")
missing_rc=$?
if [ "$missing_rc" -eq 2 ]; then expect pass "missing pin exits 2"; else expect fail "missing pin exits 2 (got $missing_rc)"; fi
if contains "$(<"$W/missing.err")" "NOT-GATED"; then expect pass "missing pin reports NOT-GATED"; else expect fail "missing pin reports NOT-GATED: $(<"$W/missing.err")"; fi

slashed_rc=0
PROJECT_ROOT="$W/slashed" MCP_AGENT_MAIL_DB="$W/mail.sqlite3" MCP_AGENT_MAIL_URL="http://127.0.0.1:1" \
  python3 "$ROSTER" >/dev/null 2>"$W/slashed.err" || slashed_rc=$?
if [ "$slashed_rc" -eq 2 ]; then expect pass "org-prefixed key exits 2"; else expect fail "org-prefixed key exits 2 (got $slashed_rc)"; fi

printf 'agent-roster.test.sh: %d/%d passed\n' "$((CASES - FAILURES))" "$CASES"
[ "$FAILURES" -eq 0 ]
