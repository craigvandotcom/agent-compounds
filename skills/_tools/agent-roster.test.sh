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
  task_description TEXT NOT NULL DEFAULT '',
  contact_policy TEXT NOT NULL DEFAULT 'open',
  inception_ts TEXT NOT NULL DEFAULT '2026-01-01 00:00:00.000000',
  retired_at TEXT,
  last_active_ts TEXT NOT NULL
);
CREATE TABLE file_reservations (
  id INTEGER PRIMARY KEY,
  project_id INTEGER NOT NULL,
  agent_id INTEGER NOT NULL,
  path_pattern TEXT NOT NULL,
  exclusive INTEGER NOT NULL,
  reason TEXT NOT NULL,
  created_ts TEXT NOT NULL,
  expires_ts TEXT NOT NULL,
  released_ts TEXT
);
""")
projects = [
    (1, "example-app", "example-app"),
    (2, project_root, "tmp-example-app"),
    (3, "acme/example-app", "acme-example-app"),
    (4, "other-app", "other-app"),
]
now = datetime.datetime.now(datetime.timezone.utc).isoformat()
past = (datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=2)).isoformat()
future = (datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(hours=2)).isoformat()
agents = [
    (1, 1, "CanonicalAgent", "opencode", "space-bunny-free", now, None),
    (2, 2, "AbsoluteAgent", "opencode", "space-bunny-free", now, None),
    (3, 3, "PrefixedAgent", "claude-code", "opus", now, None),
    (4, 4, "OtherAgent", "claude-code", "opus", now, None),
    (5, 1, "RetiredAgent", "opencode", "space-bunny-free", past, now),
]
con.executemany("INSERT INTO projects(id, human_key, slug) VALUES (?, ?, ?)", projects)
con.executemany(
    "INSERT INTO agents(id, project_id, name, program, model, last_active_ts, retired_at) "
    "VALUES (?, ?, ?, ?, ?, ?, ?)",
    agents,
)
reservations = [
    # id, project_id, agent_id, path_pattern, exclusive, reason, created_ts, expires_ts, released_ts
    (1, 1, 1, "active/*", 1, "in progress", past, future, None),          # active, canonical
    (2, 3, 3, "forked/*", 1, "in progress", past, future, None),          # active, fork key
    (3, 1, 1, "released/*", 1, "done", past, future, now),                # released -> excluded
    (4, 1, 1, "expired/*", 0, "timed out", past, past, None),             # expired -> excluded
]
con.executemany(
    "INSERT INTO file_reservations(id, project_id, agent_id, path_pattern, exclusive, "
    "reason, created_ts, expires_ts, released_ts) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
    reservations,
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

# ── --snapshot DIR ───────────────────────────────────────────────────────────
snap_dir="$W/snap"
snap_out=$(PROJECT_ROOT="$W/example-app" \
  MCP_AGENT_MAIL_DB="$W/mail.sqlite3" \
  MCP_AGENT_MAIL_URL="http://127.0.0.1:1" \
  python3 "$ROSTER" --snapshot "$snap_dir" 2>"$W/snap.err")
snap_rc=$?
if [ "$snap_rc" -eq 0 ]; then expect pass "snapshot mode exits 0"; else expect fail "snapshot mode exits 0 (got $snap_rc): $(<"$W/snap.err")"; fi
agents_json="$snap_dir/agents.json"
reservations_json="$snap_dir/reservations.json"
if contains "$snap_out" "$agents_json" && contains "$snap_out" "$reservations_json"; then
  expect pass "snapshot prints both paths"
else
  expect fail "snapshot prints both paths: $snap_out"
fi

json_has() {  # json_has <file> <python-expr-on-loaded-data -> bool>
  python3 -c "
import json, sys
data = json.load(open(sys.argv[1]))
sys.exit(0 if ($2) else 1)
" "$1" "$2" 2>/dev/null
}

if [ -f "$agents_json" ] && json_has "$agents_json" \
  "any(a['name'] == 'RetiredAgent' and a['retired_at'] for a in data)"; then
  expect pass "snapshot includes the retired agent with retired_at set"
else
  expect fail "snapshot includes the retired agent with retired_at set"
fi
if [ -f "$agents_json" ] && json_has "$agents_json" \
  "any(a['name'] == 'PrefixedAgent' for a in data)"; then
  expect pass "snapshot includes the fork-key agent"
else
  expect fail "snapshot includes the fork-key agent"
fi
if [ -f "$agents_json" ] && json_has "$agents_json" \
  "all(k in a for k in ('name','program','model','task_description','contact_policy','last_active_ts','inception_ts','retired_at','project_key') for a in data)"; then
  expect pass "agent rows carry every required field"
else
  expect fail "agent rows carry every required field"
fi
if [ -f "$reservations_json" ] && json_has "$reservations_json" \
  "any(r['holder'] == 'CanonicalAgent' and r['path_pattern'] == 'active/*' for r in data)"; then
  expect pass "reservation rows carry holder"
else
  expect fail "reservation rows carry holder"
fi
if [ -f "$reservations_json" ] && json_has "$reservations_json" \
  "any(r['holder'] == 'PrefixedAgent' for r in data)"; then
  expect pass "reservation rows span the fork key too"
else
  expect fail "reservation rows span the fork key too"
fi
if [ -f "$reservations_json" ] && json_has "$reservations_json" \
  "not any(r['path_pattern'] in ('released/*', 'expired/*') for r in data)"; then
  expect pass "released/expired reservations are excluded"
else
  expect fail "released/expired reservations are excluded"
fi

# The load-bearing check: feed both files to the REAL br binary.
if ! command -v br >/dev/null 2>&1; then
  expect fail "br coordination status accepts the snapshot (br not on PATH)"
else
  br_root="$W/br-workspace"
  mkdir -p "$br_root"
  br_db="$br_root/test.db"
  (cd "$br_root" && br init --prefix zz --db "$br_db" >/dev/null 2>"$W/br-init.err")
  br_rc=$?
  br_status=$(br --db "$br_db" coordination status --json \
    --agents "$agents_json" --reservations "$reservations_json" 2>"$W/br-status.err")
  br_status_rc=$?
  if [ "$br_rc" -eq 0 ] && [ "$br_status_rc" -eq 0 ] \
    && printf '%s' "$br_status" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if 'claims' in d else 1)" 2>/dev/null \
    && ! contains "$br_status" "VALIDATION_FAILED"; then
    expect pass "br coordination status accepts the snapshot"
  else
    expect fail "br coordination status accepts the snapshot: init_rc=$br_rc status_rc=$br_status_rc $br_status"
  fi
fi

printf 'agent-roster.test.sh: %d/%d passed\n' "$((CASES - FAILURES))" "$CASES"
[ "$FAILURES" -eq 0 ]
