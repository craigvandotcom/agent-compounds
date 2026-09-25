#!/usr/bin/env python3
"""agent-roster — active Agent Mail agents for this repo (read-only).

Prints one TAB-separated line per non-retired agent for the project whose
human_key is pinned in session-start.md:

    name<TAB>program<TAB>model<TAB>last_active_ts

preceded by one `#mail<TAB>up|down` line: whether the Agent Mail SERVER answers.
The roster reads the DB file, which outlives the server — without this line a dead
coordination channel renders as a healthy list of agents.

"Active" is the authoritative DB fact `retired_at IS NULL` — not a marker's
absence, which cannot tell a retired agent from a never-registered one — plus a
recency window: agents idle longer than AC_BOARD_AGENT_WINDOW_H hours (default
24) are dropped, so a stale registration is not read as a running agent.

Exit: 0 roster read (may be empty), 2 NOT-GATED (DB, sqlite3, project
root, or key pin unreadable/malformed) with the reason on stderr — the board
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


def pinned_human_key(root):
    current = root
    while True:
        pin = os.path.join(current, ".claude/hooks/session-start.md")
        try:
            os.lstat(pin)
        except FileNotFoundError:
            parent = os.path.dirname(current)
            if parent == current:
                return None, f"no human_key pin at or above project root {root}"
            current = parent
            continue
        except OSError as exc:
            return None, f"cannot inspect project key pin at {pin}: {exc}"
        try:
            with open(pin, encoding="utf-8") as handle:
                text = handle.read()
        except (OSError, UnicodeError) as exc:
            return None, f"cannot read project key pin at {pin}: {exc}"
        matches = re.findall(
            r'^\s*human_key:\s*"([^"\r\n]*)"\s*,?\s*$', text, re.MULTILINE
        )
        if not matches:
            if re.search(r"^\s*human_key:", text, re.MULTILINE):
                return None, f"malformed human_key pin at {pin}"
            return None, f"no human_key pin in {pin}"
        if len(matches) != 1:
            return None, f"expected one human_key pin at {pin}, found {len(matches)}"
        key = matches[0]
        if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9][A-Za-z0-9._-]*", key):
            return None, f'malformed human_key pin at {pin}: expected "<org>/<app-dir>"'
        return key, None


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
    key, reason = pinned_human_key(root)
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
            "SELECT a.name, a.program, a.model, a.last_active_ts "
            "FROM agents a JOIN projects p ON p.id = a.project_id "
            "WHERE a.retired_at IS NULL AND p.human_key = ? "
            "ORDER BY a.last_active_ts DESC",
            (key,),
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
