#!/usr/bin/env python3
"""agent-roster — active Agent Mail agents for this repo (read-only).

Prints one TAB-separated line per non-retired agent for the project whose
human_key is this repo:

    name<TAB>program<TAB>model<TAB>last_active_ts

"Active" is the authoritative DB fact `retired_at IS NULL` — not a marker's
absence, which cannot tell a retired agent from a never-registered one — plus a
recency window: agents idle longer than AC_BOARD_AGENT_WINDOW_H hours (default
24) are dropped, so a stale registration is not read as a running agent.

Exit: 0 roster read (may be empty), 2 NOT-GATED (DB, sqlite3, or project
unreadable) with the reason on stderr — the board renders `?`, never a
guessed count.
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
    if override and os.path.isfile(override):
        return override
    url = os.environ.get("DATABASE_URL", "")
    if url.startswith("sqlite"):
        p = url.split("///", 1)[-1]
        if p.startswith("/") and os.path.isfile(p):
            return p
    return os.path.expanduser("~/mcp_agent_mail/storage.sqlite3")


def slugify(path):
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", path.lower())).strip("-")


def main():
    root = project_root()
    if not root:
        print("agent-roster: NOT-GATED — no project root", file=sys.stderr)
        return 2
    db = db_path()
    if not os.path.isfile(db):
        print(f"agent-roster: NOT-GATED — no Agent Mail DB at {db}", file=sys.stderr)
        return 2
    keys = {root, os.path.basename(root), slugify(root)}
    con = None
    try:
        con = sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=10)
        rows = con.execute(
            "SELECT a.name, a.program, a.model, a.last_active_ts "
            "FROM agents a JOIN projects p ON p.id = a.project_id "
            "WHERE a.retired_at IS NULL "
            "AND (p.human_key IN (?, ?, ?) OR p.slug IN (?, ?, ?)) "
            "ORDER BY a.last_active_ts DESC",
            (*sorted(keys), *sorted(keys)),
        ).fetchall()
    except sqlite3.Error as exc:
        print(f"agent-roster: NOT-GATED — {exc}", file=sys.stderr)
        return 2
    finally:
        if con is not None:
            con.close()
    window_h = float(os.environ.get("AC_BOARD_AGENT_WINDOW_H", "24"))
    now = datetime.datetime.now(datetime.timezone.utc)
    for name, program, model, last_active in rows:
        if window_h > 0:
            try:
                ts = datetime.datetime.fromisoformat(str(last_active))
                if ts.tzinfo is None:
                    ts = ts.replace(tzinfo=datetime.timezone.utc)
                if (now - ts).total_seconds() > window_h * 3600:
                    continue
            except ValueError:
                pass
        print(f"{name}\t{program}\t{model}\t{last_active}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
