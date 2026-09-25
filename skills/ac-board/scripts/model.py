#!/usr/bin/env python3
"""model.py — every count the ac-board reads support, computed once (read-only).

`build(reads_dir, root, compact) -> dict` is the single source of truth: render.py (the
inline board) and tui.py (the terminal dashboard) both format the SAME dict, never
re-deriving a count from raw JSON. A read that cannot answer renders `?` upstream — here it
is `None` plus a name in `failed`; nothing is guessed.

Usage as a script:  model.py <reads-dir> <project-root> <compact 0|1>   — prints the dict as
JSON (board.sh --json's implementation).
Env:    AC_BOARD_NOW (ISO timestamp) pins "now" — the test seam; unset = the real clock.
"""
import datetime as dt, json, os, re, sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "../../ac-pipeline/scripts"))
from pull_order import PLAN_ORDER, PLAN_RUNG, blocks_counts, front, plan_stage, rank  # noqa: E402

LIVE_MIN = 60          # an agent active within this many minutes is live
STALE_H = 24           # an in-progress bead untouched this long is stale
GATE_LABELS = {"human-gate", "pipeline-proposal", "dream-proposal"}


def plural(n, word):
    return f"{n} {word}" + ("" if n == 1 else "s")


def gate_kind(b):
    t, title = b.get("issue_type"), b.get("title", "")
    if t in ("task", "decision"): return "action" if t == "task" else "decision"
    return "action" if title.startswith("ACTION:") else "decision"


def pr_ci(p):
    """A PR's CI line: `CI ✗ N failing: a, b …` / `CI … N running` / `CI ✓` / `no CI checks`."""
    checks = p.get("statusCheckRollup") or []
    bad = [c.get("name") or c.get("context") or "?" for c in checks
           if (c.get("conclusion") or c.get("state") or "").upper()
           in ("FAILURE", "ERROR", "TIMED_OUT", "CANCELLED", "ACTION_REQUIRED")]
    pend = sum(1 for c in checks if (c.get("status") or "COMPLETED").upper() != "COMPLETED"
               or (c.get("state") or "").upper() == "PENDING")
    if bad:
        return f"CI ✗ {len(bad)} failing: " + ", ".join(bad[:2]) + (" …" if len(bad) > 2 else "")
    if pend: return f"CI … {pend} running"
    return "CI ✓" if checks else "no CI checks"


def build(T, ROOT, COMPACT):
    NOW = (dt.datetime.fromisoformat(os.environ["AC_BOARD_NOW"]) if os.environ.get("AC_BOARD_NOW")
           else dt.datetime.now(dt.timezone.utc))
    failed = []  # reads that could not answer — each is named; nothing is guessed

    def slurp(path, **kw):
        with open(path, **kw) as f: return f.read()

    def read(name, cmd):
        """(stdout, ok) for a background read; a failure is recorded, never read as empty."""
        try:
            rc = int(slurp(f"{T}/{name}.rc").strip())
            out = slurp(f"{T}/{name}.out")
        except (OSError, ValueError):
            failed.append(f"{cmd}: did not run"); return "", False
        if rc != 0:
            err = slurp(f"{T}/{name}.err").strip().splitlines()
            why = "timed out" if rc == 124 else (err[0] if err else f"exit {rc}")
            failed.append(f"{cmd}: {why}"); return out, False
        return out, True

    def lines_of(nm, cmd):
        o, k = read(nm, cmd)
        return o.strip().splitlines(), k

    def ts(s):
        if not s: return None
        s = re.sub(r"(\.\d{6})\d+", r"\1", str(s).strip().replace(" ", "T")).replace("Z", "+00:00")
        try: t = dt.datetime.fromisoformat(s)
        except ValueError: return None
        return t if t.tzinfo else t.replace(tzinfo=dt.timezone.utc)

    def mins(s):
        t = ts(s)
        return None if t is None else (NOW - t).total_seconds() / 60

    def rows_of(raw):
        data = json.loads(raw)
        rows = data["issues"] if isinstance(data, dict) else data
        if not all(r.get("id") and r.get("status") and r.get("created_at") for r in rows):
            raise ValueError("row shape")
        return rows

    # ── beads (Scan A categories) ─────────────────────────────────────────
    beads = ready_ids = None
    raw, ok = read("beads", "br_call list")
    if ok:
        try: beads = rows_of(raw)
        except (ValueError, KeyError, TypeError) as e: failed.append(f"br_call list: {e}")
    raw, ok = read("ready", "br_call ready")
    if ok:
        try: ready_ids = {r["id"] for r in rows_of(raw)}
        except (ValueError, KeyError, TypeError) as e: failed.append(f"br_call ready: {e}")

    # The jsonl is the only source of edges, holders and closure dates.
    recs = jsonl = None
    try:
        jsonl = slurp(os.path.join(ROOT, ".beads/issues.jsonl"))
        recs = {r["id"]: r for r in (json.loads(l) for l in jsonl.splitlines() if l.strip())}
    except OSError:
        failed.append(".beads/issues.jsonl: unreadable")
    except (ValueError, KeyError) as e:
        failed.append(f".beads/issues.jsonl: {e}")

    labels = lambda b: set(b.get("labels") or [])
    is_open = lambda r: r.get("status") not in ("closed", "tombstone") and not r.get("closed_at")
    rec = lambda i: (recs or {}).get(i, {})

    def deferred(b):
        u = ts(b.get("defer_until"))
        return b["status"] == "deferred" or bool(u and u > NOW)

    gates, epics = [], []
    loop = {k: [] for k in ("in_progress", "blocked", "ready", "unrefined", "deferred", "other")}
    if beads is not None:
        for b in beads:
            if labels(b) & GATE_LABELS:
                if not deferred(b) and b["status"] in ("open", "blocked", "in_progress"): gates.append(b)
            elif b.get("issue_type") == "epic":
                epics.append(b)
            elif deferred(b):
                loop["deferred"].append(b)
            elif b["status"] == "in_progress":
                loop["in_progress"].append(b)
            elif b["status"] in ("open", "blocked") and ready_ids is not None and b["id"] not in ready_ids:
                loop["blocked"].append(b)
            elif b["status"] not in ("open", "blocked"):
                loop["other"].append(b)
            else:
                loop["ready" if "refined" in labels(b) else "unrefined"].append(b)
    gate_ids = {b["id"] for b in gates}
    live = [b for k in ("in_progress", "blocked", "ready", "unrefined", "other") for b in loop[k]]

    def blockers(bid):
        """Open `blocks` targets of a bead — what it is waiting on. None when edges unreadable."""
        if recs is None: return None
        return sorted(d["depends_on_id"] for d in rec(bid).get("dependencies") or []
                      if d.get("type") == "blocks" and is_open(rec(d["depends_on_id"])))

    BLOCKS = None if recs is None else blocks_counts(recs)  # open beads waiting on each id

    def epic_progress(eid):
        kids = [r for r in (recs or {}).values()
                if any(d.get("type") == "parent-child" and d.get("depends_on_id") == eid
                       for d in r.get("dependencies") or [])]
        return sum(1 for r in kids if not is_open(r)), len(kids), kids

    closed7 = None
    if recs is not None:
        today = NOW.astimezone().date()
        closed7 = [0] * 7
        for r in recs.values():
            t = ts(r.get("closed_at"))
            if t:
                d = (today - t.astimezone().date()).days
                if 0 <= d < 7: closed7[6 - d] += 1

    # ── plans (Scan B) + the backlog pool ───────────────────────────────────
    plans = []
    pdir = os.path.join(ROOT, "_plans")
    if os.path.isdir(pdir):
        for f in sorted(os.listdir(pdir)):
            p = os.path.join(pdir, f)
            if not f.endswith(".md") or f == "README.md" or not os.path.isfile(p): continue
            text = slurp(p, errors="replace")
            st = plan_stage(front(text))
            if st is None:  # the Scan B fallback ladder
                st = ("refined" if "## Refinement Log" in text else
                      "approved" if "Status: Approved" in text else
                      "beadified" if jsonl and f in jsonl else "draft")
            plans.append({"name": f[:-3], "stage": st, "mtime": os.path.getmtime(p)})
    pool_dir = os.path.join(ROOT, "_backlog/pool")
    pool = len([f for f in os.listdir(pool_dir) if f.endswith(".md") and f != "README.md"]
               ) if os.path.isdir(pool_dir) else 0

    # ── agents: who is live, and which bead each holds ──────────────────────
    agents = mail = None
    out, ok = read("roster", "agent-roster.py")
    ros = out.strip().splitlines()
    if ros and ros[0].startswith("#mail"): mail = ros[0].split("\t")[1]
    split = next((l.split("\t")[1] for l in ros if l.startswith("#split")), None)
    if ok: agents = [l.split("\t") for l in ros if l.strip() and not l.startswith("#")]
    live_names = None if agents is None else {
        a[0] for a in agents if len(a) > 3 and (mins(a[3]) or LIVE_MIN) < LIVE_MIN}
    holder = lambda b: b.get("assignee") or rec(b["id"]).get("assignee")
    held = None if live_names is None else [b for b in loop["in_progress"] if holder(b) in live_names]

    def agent_rows():
        if agents is None: return None
        rows = []
        for a in agents:
            nm = a[0]
            rows.append({"name": nm, "program": a[1] if len(a) > 1 else None,
                         "model": a[2] if len(a) > 2 else None,
                         "last_active": a[3] if len(a) > 3 else None,
                         "live": live_names is not None and nm in live_names,
                         "holds": next((b["id"] for b in loop["in_progress"] if holder(b) == nm), None)})
        return rows

    # ── verdict: one of four states, derived — never asserted ───────────────
    n_ready, n_unref, n_gates = len(loop["ready"]), len(loop["unrefined"]), len(gates)
    n_blocked, n_ip = len(loop["blocked"]), len(loop["in_progress"])

    def verdict():
        """(state, the rendered line, [reasons behind it])."""
        if beads is None or ready_ids is None:
            return "UNKNOWN", "? unknown — the bead reads failed", []
        you = [f"{n_gates} on you"] if n_gates else []
        if (n_ready or n_ip) and live_names is None:
            return "UNKNOWN", "? unknown — agent roster unreadable", [f"{n_ready} ready", f"{n_ip} in progress"]
        if held:
            return "RUNNING", "✅ RUNNING — agents are building", [f"{len(held)} working", f"{n_ready} ready"] + you
        if n_ready:
            return "IDLE", "🥵 IDLE — work waiting, no agent on it", [f"{n_ready} ready"] + you
        rest = ([f"{n_unref} unrefined"] if n_unref else  # the lead cause only
                [f"{n_blocked} blocked"] if n_blocked else [f"{n_ip} unclaimed"] if n_ip else [])
        if n_gates: return "STUCK", "⛔ STUCK — waiting on you", [plural(n_gates, "gate")] + rest
        if live: return "STUCK", "⛔ STUCK — nothing can move", rest
        return "EMPTY", "⏸ EMPTY — nothing planned", []

    v_state, v_line, v_reasons = verdict()

    if COMPACT:
        return {"name": os.path.basename(ROOT), "now": NOW.isoformat(), "compact": True,
                "verdict": {"state": v_state, "line": v_line, "reasons": v_reasons}, "failed": failed}

    # ── the remaining reads (full board only) ────────────────────────────────
    waves = None
    lines, ok = lines_of("waves", "git branch -r")
    if ok:
        waves = len([l for l in lines if l.strip()])
        err = slurp(f"{T}/waves.err").strip()
        if err: failed.append(err.splitlines()[-1])

    prs = None
    o, ok = read("prs", "gh pr list")
    if ok:
        try: prs = json.loads(o or "[]")
        except ValueError as e: failed.append(f"gh pr list: {e}")

    ci, _ = lines_of("ci", "Scan E (gh run list)")
    ci_line = next((l for l in ci if l.startswith("ci-gates:")), None)
    if ci_line is None: ci_s = None
    elif re.match(r"ci-gates:\s*0 scheduled", ci_line): ci_s = "none scheduled"
    else: ci_s = ci_line.split(":", 1)[1].strip()

    dk, _ = lines_of("docket", "Scan A docket-health")
    docket_line = next((l for l in dk if l.startswith("docket-health:")), "")
    if not docket_line: failed.insert(0, "docket-health ?")

    def docket(key):
        m = re.search(rf"(\d+) {key}|{key}:\s*(\d+)", docket_line)
        return int(m.group(1) or m.group(2)) if m else None

    tr, ok = lines_of("truth", "board-truth.sh")
    m = re.search(r"board-truth:\s*(\d+)", tr[0]) if ok and tr else None
    truth = int(m.group(1)) if m else None

    tg, tg_ok = lines_of("triage", "triage-gate.sh --status")  # empty = the repo declares no gate
    triage_value = tg[0].split(":", 1)[-1].strip() if tg else None

    tidy = {"status": "missing", "streak": None}
    try:  # tidy shadow streak: trailing `match: true` runs — 7 means tidy-scan may apply for real
        with open(os.path.join(ROOT, ".claude/state/tidy-runs.jsonl")) as fh:
            runs = [json.loads(l) for l in fh if l.strip()]
        streak = next((i for i, r in enumerate(reversed(runs)) if r.get("match") is not True), len(runs))
        tidy = {"status": "ok", "streak": streak}
    except FileNotFoundError:
        pass
    except (OSError, ValueError):
        tidy = {"status": "error", "streak": None}

    # ── beads: counts, notes, gate list ──────────────────────────────────────
    beads_out = None
    if beads is not None:
        total = len(live) + n_gates
        stale = sum(1 for b in loop["in_progress"]
                    if (mins(rec(b["id"]).get("updated_at") or b.get("updated_at")) or 0) > STALE_H * 60)
        unclaimed = sum(1 for b in loop["in_progress"] if live_names is not None and holder(b) not in live_names)
        held_up = None if recs is None else sum(1 for r in recs.values() if is_open(r)
                                                and set(blockers(r["id"]) or []) & gate_ids)
        no_memo = sum(1 for b in gates if not re.search(
            r"(evidence|consequence|recommendation):", b.get("description") or "", re.I))
        blocked_by = blocked_refined = None
        if recs is not None:
            unref_ids = {b["id"] for b in loop["unrefined"]}
            blocked_by, blocked_refined = {"gate": 0, "unrefined": 0, "work": 0}, 0
            for b in loop["blocked"]:
                bl = set(blockers(b["id"]) or [])
                blocked_by["gate" if bl & gate_ids else "unrefined" if bl & unref_ids else "work"] += 1
                if "refined" in labels(b): blocked_refined += 1
        orphans = None
        if recs is not None:
            epic_ids = {i for i, r in recs.items() if r.get("issue_type") == "epic"}
            orphans = sum(1 for b in live if not any(
                d.get("type") == "parent-child" and d.get("depends_on_id") in epic_ids
                for d in rec(b["id"]).get("dependencies") or []))
        gate_rows = [{"id": g["id"], "title": g.get("title", ""), "kind": gate_kind(g),
                      "blocks": (BLOCKS or {}).get(g["id"], 0) if BLOCKS is not None else None,
                      "created_at": g["created_at"]} for g in gates]
        beads_out = {
            "total": total, "n_in_progress": n_ip, "n_ready": n_ready, "n_gates": n_gates,
            "n_unrefined": n_unref, "n_blocked": n_blocked, "n_deferred": len(loop["deferred"]),
            "n_other": len(loop["other"]), "stale": stale, "unclaimed": unclaimed,
            "held_up": held_up, "no_memo": no_memo, "blocked_by": blocked_by,
            "blocked_refined": blocked_refined, "orphans": orphans,
            "in_progress": [{"id": b["id"], "holder": holder(b),
                              "live": (live_names is not None and holder(b) in live_names)}
                             for b in loop["in_progress"]],
            "gates": gate_rows,
        }

    # ── epics: progress, and which live agent holds an in-progress child ────
    epics_out, epics_ok = [], recs is not None
    for e in epics:
        if recs is None:
            epics_out.append({"id": e["id"], "title": e.get("title", ""), "priority": e.get("priority"),
                               "created_at": e.get("created_at"), "closed_at": e.get("closed_at"),
                               "done": None, "total": None, "holding": [], "unclaimed_stale": False})
            continue
        done, etotal, kids = epic_progress(e["id"])
        holding, unclaimed_stale = [], False
        for k in kids:
            if k.get("status") != "in_progress" or not is_open(k): continue
            h = k.get("assignee")
            if h and live_names is not None and h in live_names:
                holding.append(h)
            else:
                m = mins(k.get("updated_at"))
                if h is None or (live_names is not None and h not in live_names) or (m or 0) > STALE_H * 60:
                    unclaimed_stale = True
        epics_out.append({"id": e["id"], "title": e.get("title", ""), "priority": e.get("priority"),
                           "created_at": e.get("created_at"), "closed_at": e.get("closed_at"),
                           "done": done, "total": etotal, "holding": holding,
                           "unclaimed_stale": unclaimed_stale})
    # `beads` (br_call list) is open-issues-only, so a closed epic only ever shows up in the
    # jsonl — recs, not the `epics` list above.
    most_recent_closed = None
    if recs is not None:
        closed_epics = [r for r in recs.values() if r.get("issue_type") == "epic" and r.get("closed_at")]
        if closed_epics:
            mc = max(closed_epics, key=lambda e: e["closed_at"])
            most_recent_closed = {"id": mc["id"], "title": mc.get("title", ""), "closed_at": mc["closed_at"]}

    # ── ranked moves: the pull order, full list (render.py truncates to 3) ──
    def moves():
        if beads is None or ready_ids is None:
            return [{"rung": "fix-reads", "subject": "fix the failed reads", "detail": "see FLAGS", "route": ""}]
        m = []
        red = [p for p in prs or [] if pr_ci(p).startswith("CI ✗")]
        if red:
            m.append(((rank("red-pr"),), {"rung": "red-pr", "pr_number": red[0]["number"],
                      "subject": f"PR #{red[0]['number']} is red", "detail": pr_ci(red[0])[5:],
                      "route": f"gh pr checks {red[0]['number']}"}))
        unclaimed_ids = [b["id"] for b in loop["in_progress"] if live_names is not None and holder(b) not in live_names]
        if unclaimed_ids:
            m.append(((rank("reclaim"),), {"rung": "reclaim", "bead_ids": unclaimed_ids,
                      "subject": f"reclaim {plural(len(unclaimed_ids), 'unclaimed bead')}",
                      "detail": ", ".join(unclaimed_ids[:3]), "route": "/ac-tidy"}))
        if v_line.startswith("🥵"):
            m.append(((rank("implement"),), {"rung": "implement", "n_ready": n_ready,
                      "subject": plural(n_ready, "ready bead"), "detail": "no agent taking them",
                      "route": "/ac-implement"}))
        idle_entries = []
        for g in sorted(gates, key=lambda x: x["created_at"]):
            k = (BLOCKS or {}).get(g["id"], 0)
            entry = {"rung": "gate" if k else "idle-gate", "gate_id": g["id"], "title": g.get("title", ""),
                      "created_at": g["created_at"], "gate_kind": gate_kind(g), "blocks": k,
                      "subject": g["id"],
                      "detail": f"{gate_kind(g)} · unblocks {plural(k, 'bead')}" if k else gate_kind(g),
                      "route": "/ac-human"}
            if k: m.append(((rank("gate"), -k), entry))
            else: idle_entries.append(entry)
        if n_unref:
            m.append(((rank("refine-bead"),), {"rung": "refine-bead", "n_unrefined": n_unref,
                      "subject": f"refine {plural(n_unref, 'bead')}",
                      "detail": "" if n_ready else "nothing is ready without them",
                      "route": "/ac-polish bead"}))
        plan_move = {"bead-ready": ("beadify", "/ac-beadify"), "refined": ("rule on", "/ac-human"),
                     "polished": ("mark ready", "plan-approve.sh ready"), "approved": ("polish", "/ac-polish plan"),
                     "draft": ("approve", "/ac-human")}
        for i, st in enumerate(PLAN_ORDER):
            names = [p["name"] for p in plans if p["stage"] == st]
            if names:
                verb, route = plan_move[st]
                m.append(((rank(PLAN_RUNG[st]), i), {"rung": PLAN_RUNG[st], "stage": st, "verb": verb,
                          "names": names, "subject": f"{verb} {plural(len(names), 'plan')}",
                          "detail": ", ".join(names[:2]) + (" …" if len(names) > 2 else ""), "route": route}))
        for entry in idle_entries:
            m.append(((rank("idle-gate"),), entry))
        if pool:
            m.append(((rank("pool"),), {"rung": "pool", "pool": pool,
                      "subject": f"promote {plural(pool, 'pool idea')}", "detail": "", "route": "/ac-align"}))
        if not m:
            m.append(((0,), {"rung": "none", "subject": "nothing open", "detail": "plan the next wave",
                      "route": "/ac-align"} if v_line.startswith("⏸") else
                      {"rung": "none", "subject": "nothing needs you", "detail": "the loop is running",
                       "route": ""}))
        return [entry for _, entry in sorted(m, key=lambda x: x[0])]

    return {
        "name": os.path.basename(ROOT), "now": NOW.isoformat(), "compact": False,
        "verdict": {"state": v_state, "line": v_line, "reasons": v_reasons},
        "beads": beads_out,
        "epics": {"ok": epics_ok, "items": epics_out},
        "closed7": closed7,
        "most_recent_closed_epic": most_recent_closed,
        "plans": plans, "pool": pool,
        "agents": agent_rows(), "mail": mail, "split": split,
        "waves": waves,
        "prs": None if prs is None else [{"number": p.get("number"), "ci": pr_ci(p)} for p in prs],
        "ci": ci_s, "truth": truth,
        "docket": {"reason_less": docket("reason-less"), "gate_incomplete": docket("gate-incomplete"),
                   "plan_gap": docket("plan-gap")},
        "triage": {"ok": tg_ok, "value": triage_value},
        "tidy": tidy,
        "moves": moves(),
        "failed": failed,
    }


if __name__ == "__main__":
    print(json.dumps(build(sys.argv[1], sys.argv[2], sys.argv[3] == "1")))
