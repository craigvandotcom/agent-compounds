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

mkdir -p "$W/pinned/.claude/hooks" "$W/pinned/work" "$W/missing"
printf '%s\n' 'human_key: "acme/example-app"' >"$W/pinned/.claude/hooks/session-start.md"

python3 - "$W/mail.sqlite3" "$W/pinned" <<'PY'
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
    (1, "acme/example-app", "acme-example-app"),
    (2, project_root, "tmp-pinned"),
]
now = datetime.datetime.now(datetime.timezone.utc).isoformat()
agents = [
    (1, 1, "CanonicalAgent", "opencode", "space-bunny-free", now),
    (2, 2, "AbsoluteAgent", "opencode", "space-bunny-free", now),
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

output=$(PROJECT_ROOT="$W/pinned/work" \
  MCP_AGENT_MAIL_DB="$W/mail.sqlite3" \
  MCP_AGENT_MAIL_URL="http://127.0.0.1:1" \
  python3 "$ROSTER" 2>"$W/pinned.err")
rc=$?
if [ "$rc" -eq 0 ]; then expect pass "pinned project roster exits 0"; else expect fail "pinned project roster exits 0 (got $rc)"; fi
if contains "$output" $'CanonicalAgent\t'; then expect pass "canonical agent appears"; else expect fail "canonical agent appears: $output"; fi
if contains "$output" "AbsoluteAgent"; then expect fail "absolute-path agent is excluded"; else expect pass "absolute-path agent is excluded"; fi
if contains "$output" $'#mail\t'; then expect pass "health line is preserved"; else expect fail "health line is preserved: $output"; fi

missing_output=$(PROJECT_ROOT="$W/missing" \
  MCP_AGENT_MAIL_DB="$W/mail.sqlite3" \
  MCP_AGENT_MAIL_URL="http://127.0.0.1:1" \
  python3 "$ROSTER" 2>"$W/missing.err")
missing_rc=$?
if [ "$missing_rc" -eq 2 ]; then expect pass "missing pin exits 2"; else expect fail "missing pin exits 2 (got $missing_rc)"; fi
if contains "$(<"$W/missing.err")" "NOT-GATED"; then expect pass "missing pin reports NOT-GATED"; else expect fail "missing pin reports NOT-GATED: $(<"$W/missing.err")"; fi

printf 'agent-roster.test.sh: %d/%d passed\n' "$((CASES - FAILURES))" "$CASES"
[ "$FAILURES" -eq 0 ]
