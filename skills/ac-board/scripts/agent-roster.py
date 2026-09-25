#!/usr/bin/env python3
"""agent-roster — active Agent Mail agents for this repo (read-only).

Prints one TAB-separated line per non-retired agent for the project keyed by
the `Agent Mail project key:` line in the repo's own AGENTS.md:

    name<TAB>program<TAB>model<TAB>last_active_ts

preceded by one `#mail<TAB>up|down` line: whether the Agent Mail SERVER answers.
The roster reads the DB file, which outlives the server — without this line a dead
coordination channel renders as a healthy list of agents. When live agents of this
repo sit under ANY other key (an absolute path, an old `org/` prefix), a
`#split<TAB>N<TAB>key,key` line follows: a forked mailbox is visible, never silent.

"Active" is the authoritative DB fact `retired_at IS NULL` — not a marker's
absence, which cannot tell a retired agent from a never-registered one — plus a
recency window: agents idle longer than AC_BOARD_AGENT_WINDOW_H hours (default
24) are dropped, so a stale registration is not read as a running agent.

Exit: 0 roster read (may be empty), 2 NOT-GATED (DB, sqlite3, project
root, or AGENTS.md key line missing/malformed) with the reason on stderr — the board
renders `?`, never a guessed count.
"""

import datetime
import os
import re
import sqlite3
import subprocess
import sys


def project_root():
    root = os.environ.get("PROJECT_ROOT")
    if root:
        return os.path.realpath(root)
    try:
        out = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, timeout=30,
        )
        if out.returncode == 0 and out.stdout.strip():
            return os.path.realpath(out.stdout.strip())
    except (OSError, subprocess.SubprocessError):
        pass
    return None


def db_path():
    override = os.environ.get("MCP_AGENT_MAIL_DB")
    if override:
        return override
    url = os.environ.get("DATABASE_URL", "")
    if url.startswith("sqlite"):
        p = url.split("///", 1)[-1]
        if p.startswith("/") and os.path.isfile(p):
            return p
    return os.path.expanduser("~/mcp_agent_mail/storage.sqlite3")


def project_key(root):
    path = os.path.join(root, "AGENTS.md")
    try:
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
    except (OSError, UnicodeError) as exc:
        return None, f"cannot read {path}: {exc}"
    keys = re.findall(r"^Agent Mail project key: `([^`\r\n]*)`\s*$", text, re.MULTILINE)
    if len(keys) != 1:
        return None, f"expected one 'Agent Mail project key: `<repo>`' line in {path}, found {len(keys)}"
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", keys[0]):
        return None, f"malformed project key in {path}: expected the repo name, no slash"
    return keys[0], None


def live(last_active, window_h, now):
    if window_h <= 0:
        return True
    try:
        ts = datetime.datetime.fromisoformat(str(last_active))
    except ValueError:
        return True
    if ts.tzinfo is None:
        ts = ts.replace(tzinfo=datetime.timezone.utc)
    return (now - ts).total_seconds() <= window_h * 3600


def mail_status():
    import urllib.request
    url = os.environ.get("MCP_AGENT_MAIL_URL", "http://127.0.0.1:8765").rstrip("/")
    try:
        with urllib.request.urlopen(url + "/health/liveness", timeout=3) as resp:
            return "up" if b"alive" in resp.read() else "down"
    except Exception:
        return "down"


def main():
    print(f"#mail\t{mail_status()}")
    root = project_root()
    if not root:
        print("agent-roster: NOT-GATED — no project root", file=sys.stderr)
        return 2
    if not os.path.isdir(root):
        print(f"agent-roster: NOT-GATED — project root unreadable at {root}", file=sys.stderr)
        return 2
    key, reason = project_key(root)
    if not key:
        print(f"agent-roster: NOT-GATED — {reason}", file=sys.stderr)
        return 2
    db = db_path()
    if not os.path.isfile(db):
        print(f"agent-roster: NOT-GATED — no Agent Mail DB at {db}", file=sys.stderr)
        return 2
    con = None
    try:
        con = sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=10)
        rows = con.execute(
            "SELECT p.human_key, a.name, a.program, a.model, a.last_active_ts "
            "FROM agents a JOIN projects p ON p.id = a.project_id "
            "WHERE a.retired_at IS NULL AND (p.human_key = ? OR p.human_key LIKE ?) "
            "ORDER BY a.last_active_ts DESC",
            (key, f"%/{key}"),
        ).fetchall()
    except sqlite3.Error as exc:
        print(f"agent-roster: NOT-GATED — {exc}", file=sys.stderr)
        return 2
    finally:
        if con is not None:
            con.close()
    window_h = float(os.environ.get("AC_BOARD_AGENT_WINDOW_H", "24"))
    now = datetime.datetime.now(datetime.timezone.utc)
    rows = [r for r in rows if live(r[4], window_h, now)]
    forks = [r for r in rows if r[0] != key]
    if forks:
        print(f"#split\t{len(forks)}\t{','.join(sorted({r[0] for r in forks}))}")
    for human_key, name, program, model, last_active in rows:
        if human_key == key:
            print(f"{name}\t{program}\t{model}\t{last_active}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
