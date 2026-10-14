#!/usr/bin/env python3
"""telemetry.py — the ac-board's in-session telemetry (read-only).

One JSON object on stdout, exit 0: what each harness did in the last 24h, which files are
reserved right now, what the bead graph says, and the last few events across every lane.
board.sh runs it as a background read (`telemetry`); model.py folds the answer into the
board dict; tui.py draws it. Nothing here formats anything, and nothing here writes.

Usage:  telemetry.py <project-root>
Env:    MCP_AGENT_MAIL_DB  the Agent Mail store (default ~/mcp_agent_mail/storage.sqlite3)
        AC_BOARD_CACHE     where `bv`'s answer is cached against .beads/issues.jsonl's mtime
        AC_BOARD_NOW       pins "now" — the test seam; unset = the real clock

Every collector is guarded on its own: a missing database, binary or file empties that one
section and never raises. Warm budget is < 150ms — `bv` is mtime-cached, and the Claude Code
transcript scan reads only the tail of the 15 newest files, never a whole history.
"""
import contextlib as ctx, datetime as dt, glob, json, os, re, sqlite3, subprocess, sys
from concurrent.futures import ThreadPoolExecutor

HOME = os.path.expanduser("~")
DAY_MS = 86_400_000
LIVE_MS = 3_600_000          # an opencode/codex session touched within the hour is live
MAX_ACTIVITY = 6             # the tail -f card's depth
TAIL_BYTES = 2_000_000       # per Claude Code transcript, read from the end
MAX_TRANSCRIPTS = 15
TOOL_MAP = {"bash": "bash", "shell": "bash", "read": "read", "edit": "edit", "write": "edit",
            "multiedit": "edit", "notebookedit": "edit", "patch": "edit", "task": "subagent",
            "agent": "subagent", "grep": "grep", "glob": "grep", "list": "grep",
            "webfetch": "web", "websearch": "web", "todowrite": "todo"}
INTERESTING = {"subagent", "edit", "bash"}   # the tool calls worth a line in the activity tail
BINARIES = {"git", "bv"}                     # the only programs this script will run

# ── SQL: constant text, bound parameters only — nothing is built at the call site ───────
MAIL_SCOPE = ("p.archived_at IS NULL AND (p.human_key = ? OR p.human_key LIKE ?"
              " OR p.slug LIKE ?)")
MAIL_RESERVED = """SELECT a.name AS holder, a.program AS program, fr.path_pattern AS path,
                          fr.reason AS reason, fr.exclusive AS exclusive,
                          fr.created_ts AS created_at, fr.expires_ts AS expires_at
                     FROM file_reservations fr
                     JOIN agents a ON a.id = fr.agent_id
                     JOIN projects p ON p.id = fr.project_id
                    WHERE """ + MAIL_SCOPE + """
                      AND fr.released_ts IS NULL AND fr.expires_ts > ?
                    ORDER BY fr.created_ts DESC"""
MAIL_BATCHES = """SELECT a.name AS holder, fr.path_pattern AS path, fr.created_ts AS ts
                    FROM file_reservations fr
                    JOIN agents a ON a.id = fr.agent_id
                    JOIN projects p ON p.id = fr.project_id
                   WHERE """ + MAIL_SCOPE + """ AND fr.created_ts > ?
                   ORDER BY fr.created_ts DESC"""
MAIL_MESSAGES = """SELECT a.name AS sender, m.subject AS subject, m.created_ts AS ts
                     FROM messages m
                     JOIN agents a ON a.id = m.sender_id
                     JOIN projects p ON p.id = m.project_id
                    WHERE """ + MAIL_SCOPE + """ AND m.created_ts > ?
                    ORDER BY m.created_ts DESC LIMIT 4"""
OPENCODE_SESSIONS = """SELECT id, time_updated, cost, tokens_input, tokens_output,
                              tokens_reasoning, tokens_cache_read, tokens_cache_write,
                              CASE WHEN json_valid(model) THEN json_extract(model,'$.id') END AS model
                         FROM session_v2 WHERE directory = ? AND time_updated >= ?"""
OPENCODE_PARTS = """WITH recent AS (SELECT id FROM session_v2 WHERE directory = ?
                                        AND time_updated >= ?
                                     ORDER BY time_updated DESC LIMIT 20)
                    SELECT p.time_created AS ts, json_extract(p.data,'$.tool') AS tool,
                           json_extract(p.data,'$.state.status') AS status,
                           json_extract(p.data,'$.state.title') AS title,
                           json_extract(p.data,'$.state.input.description') AS description,
                           json_extract(p.data,'$.state.input.command') AS command
                      FROM part p JOIN recent r ON r.id = p.session_id
                     WHERE p.time_created >= ? AND json_extract(p.data,'$.type') = 'tool'
                     ORDER BY p.time_created DESC LIMIT 200"""


# ── time ────────────────────────────────────────────────────────────────────────────────
def now_utc():
    pin = os.environ.get("AC_BOARD_NOW")
    if pin:
        t = parse_ts(pin)
        if t: return t
    return dt.datetime.now(dt.timezone.utc)


def parse_ts(s):
    """An ISO or SQL timestamp (naive = UTC) as an aware datetime, or None."""
    if not s: return None
    s = str(s).strip()
    if s.endswith("Z"): s = s[:-1] + "+00:00"
    try: t = dt.datetime.fromisoformat(s)
    except ValueError:
        for f in ("%Y-%m-%d %H:%M:%S.%f", "%Y-%m-%d %H:%M:%S"):
            try: t = dt.datetime.strptime(s, f); break
            except ValueError: pass
        else: return None
    return t if t.tzinfo else t.replace(tzinfo=dt.timezone.utc)


def iso(t):
    """`2026-10-14T23:02:34Z` — the one timestamp shape every lane prints."""
    return None if t is None else t.astimezone(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def clip(s, n=110):
    s = " ".join(str(s or "").split())
    return s if len(s) <= n else s[:n - 1].rstrip() + "…"


def run(args, cwd, timeout):
    """stdout of one of this machine's own read-only probes, or None — never raises, never
    hangs past `timeout`. Only a known binary runs: nothing here is a user-supplied command."""
    if not args or args[0] not in BINARIES: return None
    try:
        p = subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=timeout)
        return p.stdout if p.returncode == 0 else None
    except (OSError, subprocess.SubprocessError):
        return None


def event(activity, ts, lane, actor, text):
    """Append one activity line — dropped unless its timestamp parses and it says something."""
    t = parse_ts(ts)
    if t is None or not text: return
    activity.append({"ts": iso(t), "_t": t, "lane": lane, "actor": actor or "?", "text": clip(text)})


# ── git: branch, working tree, and the last few commits ─────────────────────────────────
def git_telemetry(root, activity):
    out = {}
    status = run(["git", "status", "--porcelain", "-b"], root, 2)
    if status is not None:
        lines = status.splitlines()
        head = lines[0][3:] if lines and lines[0].startswith("## ") else ""
        m = re.search(r"\[(.+)\]", head)
        ab = m.group(1) if m else ""
        out = {"branch": head.split("...")[0].split(" ")[0] or None,
               "dirty": sum(1 for l in lines[1:] if l.strip()),
               "ahead": int(re.search(r"ahead (\d+)", ab).group(1)) if re.search(r"ahead (\d+)", ab) else 0,
               "behind": int(re.search(r"behind (\d+)", ab).group(1)) if re.search(r"behind (\d+)", ab) else 0}
    for line in (run(["git", "log", "-n", "4", "--format=%cI%x09%h%x09%s"], root, 2) or "").splitlines():
        parts = line.split("\t", 2)
        if len(parts) == 3: event(activity, parts[0], "git", parts[1], parts[2])
    return out


# ── Agent Mail: live file reservations, and what moved in the last day ──────────────────
def project_key(root):
    """The Agent Mail key declared in AGENTS.md — the key, never a path derived from it."""
    try:
        with open(os.path.join(root, "AGENTS.md"), errors="replace") as f:
            m = re.search(r"Agent Mail project key:\s*`([^`]+)`", f.read())
        return m.group(1).strip() if m else None
    except OSError:
        return None


def common_prefix(paths):
    """`skills/ac-board/scripts/*` for a batch reserved out of one directory, else ''."""
    dirs = [os.path.dirname(p) for p in paths if os.path.dirname(p)]
    if not dirs or len(dirs) != len(paths): return ""
    pre = os.path.commonprefix(dirs).rstrip("/")
    return f"{pre}/*" if pre else ""


def mail_telemetry(root, now, activity):
    db = os.environ.get("MCP_AGENT_MAIL_DB") or os.path.join(HOME, "mcp_agent_mail/storage.sqlite3")
    if not os.path.isfile(db): return []
    # the project this repo owns, matched three ways: the AGENTS.md key, or the root itself.
    # A keyless repo gets a sentinel no human_key or slug can end with, so one constant SQL
    # serves both cases and no SQL text is ever built at the call site.
    key = project_key(root) or "no-agent-mail-project-key"
    args = (root, f"%/{key}", f"%{key}")
    since = (now - dt.timedelta(days=1)).strftime("%Y-%m-%d %H:%M:%S")
    stamp = now.strftime("%Y-%m-%d %H:%M:%S")
    with ctx.closing(sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=2)) as con:
        con.row_factory = sqlite3.Row
        rows = con.execute(MAIL_RESERVED, args + (stamp,)).fetchall()
        reservations = [{"holder": r["holder"], "program": r["program"], "path": r["path"],
                         "reason": r["reason"], "exclusive": bool(r["exclusive"]),
                         "created_at": iso(parse_ts(r["created_at"])),
                         "expires_at": iso(parse_ts(r["expires_at"]))} for r in rows]

        # one line per batch: a session reserves a set of paths at one instant (to the second),
        # so group on that rather than repeating the same sentence six times.
        batches = {}
        for r in con.execute(MAIL_BATCHES, args + (since,)):
            batches.setdefault((r["holder"], (r["ts"] or "")[:19]), []).append(r["path"])
        mail_events = [(ts, holder, f"reserved {len(ps)} path{'' if len(ps) == 1 else 's'}"
                        + (f" ({common_prefix(ps) or clip(ps[0], 40)})" if ps else ""))
                       for (holder, ts), ps in batches.items()]
        for r in con.execute(MAIL_MESSAGES, args + (since,)):
            mail_events.append((r["ts"], r["sender"], f"mail · {r['subject']}"))
        mail_events.sort(key=lambda e: e[0], reverse=True)
        for ts, who, text in mail_events[:4]: event(activity, ts, "mail", who, text)
    return reservations


# ── bv: the bead graph's keystone, bottleneck, cycles and velocity ──────────────────────
def bv_telemetry(root):
    src = os.path.join(root, ".beads/issues.jsonl")
    try: mtime = os.path.getmtime(src)
    except OSError: mtime = None
    cache_dir, data = os.environ.get("AC_BOARD_CACHE"), None
    cache = os.path.join(cache_dir, "bv.json") if cache_dir else None
    if cache and mtime is not None:
        try:
            with open(cache) as f: c = json.load(f)
            if c.get("mtime") == mtime: data = c.get("data")
        except (OSError, ValueError): data = None
    if data is None:
        out = run(["bv", "--robot-insights"], root, 2.5)
        if out is None: return None
        try: data = json.loads(out)      # a malformed answer is a failed read, caught upstream
        except ValueError: return None
        if cache:
            try:
                os.makedirs(cache_dir, exist_ok=True)
                with open(cache, "w") as f: json.dump({"mtime": mtime, "data": data}, f)
            except OSError: pass
    top = lambda k: next((x for x in (data.get(k) or []) if (x.get("Value") or 0) > 0), None)
    ks, bn, vel = top("Keystones"), top("Bottlenecks"), data.get("Velocity") or {}
    num = lambda v: v if isinstance(v, (int, float)) else None
    return {
        "keystone": {"id": ks["ID"], "unblocks": num(ks.get("Value")), "title": ""} if ks else None,
        "bottleneck": {"id": bn["ID"], "value": round(num(bn.get("Value")) or 0, 1),
                       "title": ""} if bn else None,
        "cycles": len(data.get("Cycles") or []),
        "avg_close_days": (round(vel["avg_days_to_close"], 1)
                           if num(vel.get("avg_days_to_close")) is not None else None),
        "closed_30d": num(vel.get("closed_last_30_days")),
    }


# ── beads: the last few transitions, straight from the jsonl ────────────────────────────
def beads_jsonl(root):
    """`.beads/issues.jsonl` as a list of records — [] when it cannot be read."""
    try:
        with open(os.path.join(root, ".beads/issues.jsonl"), errors="replace") as f:
            return [json.loads(l) for l in f if l.strip()]
    except (OSError, ValueError):
        return []


def bead_activity(recs, now, activity):
    """The 4 newest bead transitions in the last day: closed, building, or waiting on you."""
    since = now - dt.timedelta(days=1)
    moves = []
    for r in recs:
        closed, updated = parse_ts(r.get("closed_at")), parse_ts(r.get("updated_at"))
        if closed and closed >= since: moves.append((closed, "closed", r))
        elif r.get("status") == "in_progress" and updated and updated >= since:
            moves.append((updated, "building", r))
        elif updated and updated >= since and "human-gate" in (r.get("labels") or []):
            moves.append((updated, "gate", r))
    moves.sort(key=lambda m: m[0], reverse=True)
    for t, verb, r in moves[:4]:
        event(activity, iso(t), "bead", r.get("id", "?"), f"{verb} · {clip(r.get('title') or r.get('id'), 70)}")


# ── harnesses: who ran, how much, and which tools ───────────────────────────────────────
def tally(tools, name):
    k = TOOL_MAP.get((name or "").strip().lower(), (name or "?").strip().lower() or "?")
    tools[k] = tools.get(k, 0) + 1
    return k


def opencode_telemetry(root, now_ms, tools, activity):
    db = os.path.join(HOME, ".local/share/opencode/opencode.db")
    if not os.path.isfile(db): return None
    since = now_ms - DAY_MS
    with ctx.closing(sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=2)) as con:
        con.row_factory = sqlite3.Row
        tables = {r[0] for r in con.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        # an older opencode store keeps its sessions in `session` — same shape, older name
        sessions_sql, parts_sql = ((OPENCODE_SESSIONS, OPENCODE_PARTS) if "session_v2" in tables
                                   else (OPENCODE_SESSIONS.replace("session_v2", "session"),
                                         OPENCODE_PARTS.replace("session_v2", "session")))
        rows = con.execute(sessions_sql, (root, since)).fetchall()
        s = lambda k: sum((r[k] or 0) for r in rows)
        cin, cread, cwrite = s("tokens_input"), s("tokens_cache_read"), s("tokens_cache_write")
        out = {"harness": "opencode", "sessions_24h": len(rows),
               "active_now": sum(1 for r in rows if (r["time_updated"] or 0) >= now_ms - LIVE_MS),
               "tokens": cin + s("tokens_output") + s("tokens_reasoning") + cread + cwrite,
               "cache_hit_pct": round(100 * cread / max(1, cin + cread + cwrite)),
               "cost_usd": round(s("cost"), 4) if any(r["cost"] for r in rows) else None,
               "models": sorted({r["model"] for r in rows if r["model"]})}
        if not rows: return None      # a harness that ran nothing here is not a row
        parts = con.execute(parts_sql, (root, since, since)).fetchall()
        for p in parts:
            k = tally(tools, p["tool"])
            if (p["status"] or "") == "error": tools["errors"] = tools.get("errors", 0) + 1
            if k in INTERESTING and len([a for a in activity if a["lane"] == "opencode"]) < 2:
                event(activity, p["ts"], "opencode", k,
                      p["title"] or p["description"] or p["command"] or p["tool"])
        return out


def claude_telemetry(root, now, tools, activity):
    """~/.claude/projects/<munged root>/*.jsonl — the tail of the newest 15 transcripts."""
    d = os.path.join(HOME, ".claude/projects", re.sub(r"[/. _]", "-", root))
    if not os.path.isdir(d): return None
    cutoff = now.timestamp() - 86400
    files = []
    for p in glob.glob(os.path.join(d, "*.jsonl")) + glob.glob(os.path.join(d, "*", "subagents", "*.jsonl")):
        try:
            m = os.path.getmtime(p)
        except OSError: continue
        if m >= cutoff: files.append((m, p))
    if not files: return None
    files.sort(reverse=True)
    tin = tout = tread = tcreate = 0
    models, seen = set(), 0
    for _, p in files[:MAX_TRANSCRIPTS]:
        try:
            size = os.path.getsize(p)
            with open(p, "rb") as f:
                f.seek(max(0, size - TAIL_BYTES))
                data = f.read()
        except OSError: continue
        for line in data.split(b"\n"):
            if b'"type":"assistant"' not in line: continue   # a cheap sieve before the parser
            try: o = json.loads(line)
            except ValueError: continue
            if o.get("type") != "assistant": continue
            ts = parse_ts(o.get("timestamp"))
            if ts is None or (now - ts).total_seconds() > 86400: continue
            seen += 1
            msg = o.get("message") or {}
            if msg.get("model"): models.add(msg["model"])
            u = msg.get("usage") or {}
            tin += u.get("input_tokens") or 0
            tout += u.get("output_tokens") or 0
            tread += u.get("cache_read_input_tokens") or 0
            tcreate += u.get("cache_creation_input_tokens") or 0
            for item in msg.get("content") or []:
                if not isinstance(item, dict) or item.get("type") != "tool_use": continue
                k = tally(tools, item.get("name"))
                inp = item.get("input") or {}
                if k in INTERESTING and len([a for a in activity if a["lane"] == "claude-code"]) < 2:
                    event(activity, o.get("timestamp"), "claude-code", k,
                          inp.get("description") or inp.get("file_path") or inp.get("command") or item.get("name"))
    if not seen: return None
    return {"harness": "claude-code", "sessions_24h": len(files),
            "active_now": sum(1 for m, _ in files if m >= now.timestamp() - 3600),
            "tokens": tin + tout + tread + tcreate,
            "cache_hit_pct": round(100 * tread / max(1, tin + tread + tcreate)),
            "cost_usd": None, "models": sorted(models)}


def codex_telemetry(root, now_ms, activity):
    dbs = [os.environ["CODEX_STATE_DB"]] if os.environ.get("CODEX_STATE_DB") else \
        sorted(glob.glob(os.path.join(HOME, ".codex/state_*.sqlite")),
               key=lambda p: os.path.getmtime(p) if os.path.exists(p) else 0, reverse=True)
    if not dbs or not os.path.isfile(dbs[0]): return None
    with ctx.closing(sqlite3.connect(f"file:{dbs[0]}?mode=ro", uri=True, timeout=2)) as con:
        con.row_factory = sqlite3.Row
        rows = con.execute("""SELECT id, updated_at_ms, tokens_used, model FROM threads
                               WHERE archived = 0 AND cwd = ? AND updated_at_ms >= ?""",
                           (root, now_ms - DAY_MS)).fetchall()
        if not rows: return None
        return {"harness": "codex", "sessions_24h": len(rows),
                "active_now": sum(1 for r in rows if (r["updated_at_ms"] or 0) >= now_ms - LIVE_MS),
                "tokens": sum(r["tokens_used"] or 0 for r in rows), "cache_hit_pct": None,
                "cost_usd": None, "models": sorted({r["model"] for r in rows if r["model"]})}


def grok_telemetry(root, now):
    """~/.grok/sessions/<quoted root>/ — one directory per session, named by workspace."""
    d = os.path.join(HOME, ".grok/sessions", root.replace("/", "%2F"))
    if not os.path.isdir(d): return None
    cutoff = now.timestamp() - 86400
    hits = 0
    for name in os.listdir(d):
        try: m = os.path.getmtime(os.path.join(d, name))
        except OSError: continue
        if m >= cutoff: hits += 1
    return None if not hits else {"harness": "grok", "sessions_24h": hits, "active_now": 0,
                                  "tokens": None, "cache_hit_pct": None, "cost_usd": None, "models": []}


def antigravity_telemetry(root, now):
    """~/.gemini/antigravity-cli — its summary table carries the workspace, so ask it."""
    db = os.path.join(HOME, ".gemini/antigravity-cli/conversation_summaries.db")
    if not os.path.isfile(db): return None
    with ctx.closing(sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=2)) as con:
        con.row_factory = sqlite3.Row
        since = (now - dt.timedelta(days=1)).strftime("%Y-%m-%d %H:%M:%S")
        rows = con.execute("""SELECT conversation_id, last_modified_time FROM conversation_summaries
                               WHERE workspace_uris LIKE ? AND last_modified_time >= ?""",
                           (f"%{root}%", since)).fetchall()
        if not rows: return None
        return {"harness": "antigravity", "sessions_24h": len(rows), "active_now": 0,
                "tokens": None, "cache_hit_pct": None, "cost_usd": None, "models": []}


# ── assemble ────────────────────────────────────────────────────────────────────────────
def guarded(fn, fallback=None):
    """A collector that cannot answer leaves its own section empty — it never raises."""
    try: return fn()
    except Exception: return fallback


def harness_telemetry(root, now, now_ms, tools, activity):
    """Every harness that ran here in the last day, newest-work first."""
    out = []
    for fn in (lambda: opencode_telemetry(root, now_ms, tools, activity),
               lambda: claude_telemetry(root, now, tools, activity),
               lambda: codex_telemetry(root, now_ms, activity),
               lambda: grok_telemetry(root, now),
               lambda: antigravity_telemetry(root, now)):
        h = guarded(fn)
        if h: out.append(h)
    return sorted(out, key=lambda h: (h["sessions_24h"], h["harness"]), reverse=True)


def collect(root):
    now = now_utc()
    now_ms = int(now.timestamp() * 1000)
    activity, tools = [], {}
    # the five slow reads are independent, so they run together: the wall time is the slowest
    # one (bv, ~60ms), not their sum. `tools` is written by one thread only.
    with ThreadPoolExecutor(max_workers=5) as ex:
        jobs = [ex.submit(guarded, lambda: git_telemetry(root, activity), {}),
                ex.submit(guarded, lambda: beads_jsonl(root), []),
                ex.submit(guarded, lambda: harness_telemetry(root, now, now_ms, tools, activity), []),
                ex.submit(guarded, lambda: mail_telemetry(root, now, activity), []),
                ex.submit(guarded, lambda: bv_telemetry(root), None)]
        git, recs, harnesses, reservations, bv = (j.result() for j in jobs)
    titles = {r.get("id"): r.get("title", "") for r in recs if r.get("id")}
    for k in ("keystone", "bottleneck"):
        if bv and bv.get(k): bv[k]["title"] = titles.get(bv[k]["id"], "")
    guarded(lambda: bead_activity(recs, now, activity))

    errors = tools.pop("errors", 0)
    top = sorted(tools.items(), key=lambda kv: kv[1], reverse=True)[:4]
    activity.sort(key=lambda a: a["_t"], reverse=True)
    for a in activity: a.pop("_t", None)
    return {"git": git, "reservations": reservations, "bv": bv, "harnesses": harnesses,
            "tools_24h": {"total": sum(tools.values()), "errors": errors, "top": [[k, n] for k, n in top]},
            "activity": activity[:MAX_ACTIVITY]}


def main():
    root = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.getcwd()
    try:
        out = collect(root)
    except Exception as e:                    # the board renders without telemetry, never not at all
        out = {"git": {}, "reservations": [], "bv": None, "harnesses": [],
               "tools_24h": {"total": 0, "errors": 0, "top": []},
               "activity": [{"ts": iso(now_utc()), "lane": "mail", "actor": "telemetry",
                             "text": clip(f"telemetry.py failed: {e}")}]}
    print(json.dumps(out))


if __name__ == "__main__":
    main()
