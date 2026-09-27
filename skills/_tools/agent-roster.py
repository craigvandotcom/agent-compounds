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

`--snapshot DIR` writes `DIR/agents.json` (every agent, retired included, no
recency window, one row per name — the latest `last_active_ts` wins a same-name
collision across forked keys) and `DIR/reservations.json` (reservations still
open: `released_ts IS NULL` and unexpired), across the canonical key and its
forks, in the shape `br coordination status --agents --reservations` validates.
Prints both paths, one per line. Each file lands via write-temp-then-rename —
a read failure never leaves a partial file on disk.

Exit: 0 roster read (may be empty), 2 NOT-GATED (DB, sqlite3, project
root, or AGENTS.md key line missing/malformed) with the reason on stderr — the board
renders `?`, never a guessed count. `--snapshot` shares the same NOT-GATED discipline.
"""

import datetime
import json
import os
import re
import sqlite3
import subprocess
import sys
import tempfile


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
    # The server keeps storage.sqlite3 in its install dir: the XDG data dir today
    # (~/.local/share/mcp_agent_mail), ~/mcp_agent_mail on older installs. First one
    # present wins; neither present names the XDG path in the NOT-GATED reason.
    data_home = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    candidates = [os.path.join(data_home, "mcp_agent_mail", "storage.sqlite3"),
                  os.path.expanduser("~/mcp_agent_mail/storage.sqlite3")]
    return next((c for c in candidates if os.path.isfile(c)), candidates[0])


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


def parse_ts(ts):
    """A DB timestamp (naive UTC or already offset-aware) as an aware datetime, or None."""
    if ts is None:
        return None
    try:
        dt = datetime.datetime.fromisoformat(str(ts))
    except ValueError:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=datetime.timezone.utc)
    return dt


def iso_z(ts):
    """A DB timestamp as ISO-8601 UTC with a `Z` suffix, or None."""
    dt = parse_ts(ts)
    return None if dt is None else dt.isoformat().replace("+00:00", "Z")


def atomic_write_json(path, data):
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path) or ".", prefix=".agent-roster-", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(data, handle, indent=2)
            handle.write("\n")
        os.replace(tmp, path)
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def gate():
    """project_root() + project_key() + db_path(), the NOT-GATED checks every mode shares."""
    root = project_root()
    if not root:
        return None, None, None, "no project root"
    if not os.path.isdir(root):
        return None, None, None, f"project root unreadable at {root}"
    key, reason = project_key(root)
    if not key:
        return None, None, None, reason
    db = db_path()
    if not os.path.isfile(db):
        return None, None, None, f"no Agent Mail DB at {db}"
    return root, key, db, None


def snapshot(out_dir):
    _, key, db, reason = gate()
    if reason:
        print(f"agent-roster: NOT-GATED — {reason}", file=sys.stderr)
        return 2
    con = None
    try:
        con = sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=10)
        agent_rows = con.execute(
            "SELECT p.human_key, a.name, a.program, a.model, a.task_description, "
            "a.contact_policy, a.last_active_ts, a.inception_ts, a.retired_at "
            "FROM agents a JOIN projects p ON p.id = a.project_id "
            "WHERE p.human_key = ? OR p.human_key LIKE ?",
            (key, f"%/{key}"),
        ).fetchall()
        res_rows = con.execute(
            "SELECT r.id, a.name, r.path_pattern, r.exclusive, r.reason, r.created_ts, "
            "r.expires_ts, p.human_key "
            "FROM file_reservations r "
            "JOIN agents a ON a.id = r.agent_id "
            "JOIN projects p ON p.id = r.project_id "
            "WHERE (p.human_key = ? OR p.human_key LIKE ?) AND r.released_ts IS NULL",
            (key, f"%/{key}"),
        ).fetchall()
    except sqlite3.Error as exc:
        print(f"agent-roster: NOT-GATED — {exc}", file=sys.stderr)
        return 2
    finally:
        if con is not None:
            con.close()

    epoch = datetime.datetime.min.replace(tzinfo=datetime.timezone.utc)
    latest = {}
    for human_key, name, program, model, task_description, contact_policy, last_active, inception, retired_at in agent_rows:
        ts = parse_ts(last_active) or epoch
        if name not in latest or ts >= latest[name]["_ts"]:
            latest[name] = {
                "_ts": ts,
                "name": name, "program": program, "model": model,
                "task_description": task_description, "contact_policy": contact_policy,
                "last_active_ts": iso_z(last_active), "inception_ts": iso_z(inception),
                "retired_at": iso_z(retired_at), "project_key": human_key,
            }
    agents_out = [{k: v for k, v in row.items() if k != "_ts"} for row in latest.values()]

    now = datetime.datetime.now(datetime.timezone.utc)
    reservations_out = []
    for rid, holder, path_pattern, exclusive, res_reason, created_ts, expires_ts, human_key in res_rows:
        ets = parse_ts(expires_ts)
        if ets is not None and ets <= now:
            continue
        reservations_out.append({
            "id": rid, "holder": holder, "path_pattern": path_pattern,
            "exclusive": bool(exclusive), "reason": res_reason,
            "created_ts": iso_z(created_ts), "expires_ts": iso_z(expires_ts),
            "project_key": human_key,
        })

    try:
        os.makedirs(out_dir, exist_ok=True)
        agents_path = os.path.join(out_dir, "agents.json")
        reservations_path = os.path.join(out_dir, "reservations.json")
        atomic_write_json(agents_path, agents_out)
        atomic_write_json(reservations_path, reservations_out)
    except OSError as exc:
        print(f"agent-roster: NOT-GATED — cannot write snapshot to {out_dir}: {exc}", file=sys.stderr)
        return 2

    print(agents_path)
    print(reservations_path)
    return 0


def main():
    argv = sys.argv[1:]
    if argv:
        if len(argv) == 2 and argv[0] == "--snapshot":
            return snapshot(argv[1])
        print("agent-roster: NOT-GATED — usage: agent-roster.py [--snapshot DIR]", file=sys.stderr)
        return 2
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
