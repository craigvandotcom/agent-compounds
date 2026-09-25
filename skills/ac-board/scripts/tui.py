#!/usr/bin/env python3
"""tui.py — the ac-board terminal dashboard: one column, ANSI-16, built for a tall narrow
pane or a phone. Formats the SAME model.build() dict render.py does — never re-derives a
count. No emoji anywhere here (they are double-width); glyphs are single-width only.

Usage:  tui.py [secs]                     the live loop (default 15s); execed by
                                          `board.sh --watch [secs]`.
        tui.py --once --width N [--no-color] [--prev FILE] [--save-counts FILE]
                                          reads a model dict (model.build()'s JSON, i.e.
                                          `board.sh --json`'s output) on stdin, prints one
                                          frame, exits — the test seam. --prev/--save-counts
                                          chain the in-process delta memory across two calls.
Env:    NO_COLOR disables colour (same as --no-color).
"""
import datetime as dt, json, math, os, re, shutil, signal, subprocess, sys, time
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.realpath(__file__))
BOARD = os.path.join(HERE, "board.sh")
BARW = 10                 # PIPELINE bar cells per section
DELTA_MIN = 15            # a moved count shows its change this long
EIGHTHS = " ▏▎▍▌▋▊▉█"
STATE_COLOR = {"RUNNING": "32", "IDLE": "33", "STUCK": "31", "EMPTY": "2", "UNKNOWN": "31"}
GLYPH = {"red-pr": "▲", "reclaim": "↻", "implement": "▶", "refine-bead": "~",
         "beadify": "»", "polish-plan": "»", "approve-plan": "»", "pool": "+",
         "none": "✓", "fix-reads": "⚠"}
DIM, BOLD = "2", "1"


# ── small pure helpers — tui is a standalone view, so these are its own copies ──────────
def ts(s):
    if not s: return None
    s = re.sub(r"(\.\d{6})\d+", r"\1", str(s).strip().replace(" ", "T")).replace("Z", "+00:00")
    try: t = dt.datetime.fromisoformat(s)
    except ValueError: return None
    return t if t.tzinfo else t.replace(tzinfo=dt.timezone.utc)


def age(s, now):
    t = ts(s)
    if t is None: return "?"
    m = int((now - t).total_seconds() / 60)
    return f"{m}m" if m < 60 else f"{m // 60}h" if m < 48 * 60 else f"{m // 1440}d"


def clip(s, w):
    s = " ".join((s or "").split())
    if len(s) <= w: return s
    cut = s[:max(0, w - 1)]
    sp = cut.rfind(" ")
    if sp > w * 0.6: cut = cut[:sp]
    return cut.rstrip(" ,:;—-(") + "…"


def slug(title, w):
    """A gate title as a slug: `ACTION:`/`DECISION:` stripped, clipped at a word boundary."""
    return clip(re.sub(r"^(ACTION|DECISION):\s*", "", title or ""), w)


def plan_slug(name):
    """A plan's display name: its `YYYY-MM-DD-` and optional `HHMM-` prefix stripped."""
    return re.sub(r"^\d{4}-\d{2}-\d{2}-(?:\d{4}-)?", "", name or "")


def plural(n, word):
    return f"{n} {word}" + ("" if n == 1 else "s")


def spark(counts):
    top = max(counts) or 1
    return "".join("▁" if c == 0 else "▂▃▄▅▆▇█"[max(0, math.ceil(c / top * 7) - 1)] for c in counts)


def alloc(values, width):
    """Largest-remainder: cells per value, summing exactly to width; any v > 0 gets >= 1."""
    total = sum(values)
    if not values or total <= 0 or width <= 0: return [0] * len(values)
    raw = [v / total * width for v in values]
    base = [int(x) for x in raw]
    rem = width - sum(base)
    order = sorted(range(len(values)), key=lambda i: raw[i] - base[i], reverse=True)
    i = 0
    while rem > 0 and order:
        base[order[i % len(order)]] += 1; rem -= 1; i += 1
    for i, v in enumerate(values):
        if v > 0 and base[i] == 0:
            j = max(range(len(values)), key=lambda k: base[k])
            if base[j] > 1: base[j] -= 1; base[i] += 1
    return base


def bar6(done, total, cells=6):
    """A 6-cell eighth-block progress bar; `─` is the empty track."""
    if not total: return "─" * cells
    filled = max(0.0, min(1.0, done / total)) * cells
    full = int(filled)
    idx = round((filled - full) * 8)
    if idx == 8: full, idx = full + 1, 0
    s = "█" * min(full, cells)
    if full < cells and idx: s += EIGHTHS[idx]
    return (s + "─" * cells)[:cells]


def pack_badge(text, badge, w):
    """`text`, right-padded, `badge` right-aligned at column w; text clips first."""
    if not badge: return clip(text, w)
    room = w - len(badge) - 1
    if room < 1: return clip(text, w)
    t = clip(text, room)
    return t + " " * (w - len(t) - len(badge)) + badge


def colorer(on):
    def c(code, s):
        return f"\033[{code}m{s}\033[0m" if on and s else (s or "")
    return c


def delta(state, key, n, now):
    """`+2`/`-2` beside a count that moved within DELTA_MIN; '' otherwise. Mutates `state`
    (the in-process memory of previous counts — the same shape render.py's watch mode used
    to persist to a file; here it just lives in the loop's own variables)."""
    if not isinstance(n, int): return ""
    p = state.get(key)
    if p and p.get("n") == n:
        d, at = p["d"], p["at"]
    else:
        d, at = (n - p["n"] if p else 0), now.isoformat()
        state[key] = {"n": n, "d": d, "at": at}
    if not d: return ""
    at_t = ts(at)
    m = (now - at_t).total_seconds() / 60 if at_t else DELTA_MIN
    return f"{d:+d}" if m < DELTA_MIN else ""


# ── ON YOU: one row per ranked move ──────────────────────────────────────────────────────
def on_you_row(mv, w, now, c):
    amber = "33"
    rung = mv.get("rung")
    if rung in ("gate", "idle-gate"):
        glyph = "◆" if mv.get("gate_kind") == "decision" else "▲"
        text = slug(mv.get("title", ""), w - 4)
        badge_parts = ([f"⊘{mv['blocks']}"] if mv.get("blocks") else []) + [age(mv.get("created_at"), now)]
        line1 = pack_badge(f"{glyph} {text}", "  ".join(badge_parts), w)
        lines = [c(amber, line1)]
        if mv.get("route"): lines.append(c(DIM, f"  → {mv['route']}"))
        return lines
    glyph = GLYPH.get(rung, "»")
    if rung in ("beadify", "polish-plan", "approve-plan"):
        names = mv.get("names") or []
        text = f"{mv.get('verb', '')} {plan_slug(names[0])}" if len(names) == 1 else mv["subject"]
    elif rung == "pool":
        text = f"draft {plural(mv.get('pool', 0), 'proposal')}"
    else:
        text = mv["subject"]
    line1 = clip(f"{glyph} {text}", w)
    route = f"→ {mv['route']}" if mv.get("route") else ""
    if route and len(line1) + 2 + len(route) <= w:
        return [c(amber, line1 + "  " + route)]
    lines = [c(amber, line1)]
    if route: lines.append(c(DIM, "  " + route))
    return lines


# ── EPICS: one row per epic (next → open → most recently closed) ────────────────────────
def epic_row(glyph, e, w, now):
    holding = e.get("holding") or []
    agents_s = "⚠" if e.get("unclaimed_stale") else "●" * len(holding)
    if e.get("total"):
        tail = f"{bar6(e['done'], e['total'])} {e['done']}/{e['total']}"
    elif glyph == "✓":
        tail = age(e.get("closed_at"), now)
    else:
        tail = ""
    prefix, mid = f"{glyph} ", (f" {agents_s}" if agents_s else "")
    avail = w - len(prefix) - len(mid) - (len(tail) + 1 if tail else 0)
    etitle = clip(e.get("title", ""), max(4, avail))
    line = prefix + etitle + mid
    if tail: line += " " * max(1, w - len(line) - len(tail)) + tail
    return clip(line, w)


# ── the frame: one column, header → status → ON YOU → EPICS → PIPELINE → HEALTH ─────────
def build_frame(M, width, color_on, state, secs_left=None, footer=None):
    w = max(36, min(56, width))
    now = ts(M.get("now")) or (dt.datetime.fromisoformat(os.environ["AC_BOARD_NOW"])
                                if os.environ.get("AC_BOARD_NOW") else dt.datetime.now(dt.timezone.utc))
    c = colorer(color_on)
    lines = []

    # header — redraw-only-the-clock is the live loop's concern, not this pure builder
    hhmm = now.astimezone().strftime("%H:%M")
    left = f"{M.get('name', '?')} · {hhmm}"
    right = f"↻ {secs_left}s" if secs_left is not None else ""
    header = left + " " * max(1, w - len(left) - len(right)) + right if right else left
    lines.append(c(DIM, clip(header, w)))

    st = (M.get("verdict") or {}).get("state", "UNKNOWN")
    vline = (M.get("verdict") or {}).get("line", "")
    meaning = vline.split(" — ", 1)[1] if " — " in vline else vline.lstrip("? ").strip()
    bar_text = clip(f" {st} — {meaning} ", w)
    bar_text += " " * (w - len(bar_text))
    lines.append(c(f"7;{STATE_COLOR.get(st, '31')}", bar_text))

    # ON YOU
    moves = M.get("moves") or []
    lines.append("")
    if len(moves) == 1 and moves[0].get("rung") == "none":
        lines.append(c(BOLD, "ON YOU") + "  " + c("32", "✓ clear"))
    else:
        lines.append(c(BOLD, pack_badge("ON YOU", str(len(moves)), w)))
        for mv in moves[:8]:
            lines.extend(on_you_row(mv, w, now, c))
        if len(moves) > 8: lines.append(c(DIM, f"+ {len(moves) - 8} more"))

    # EPICS
    items = (M.get("epics") or {}).get("items") or []
    lines.append("")
    open_eps = [e for e in items if not e.get("closed_at")]
    done_sum = sum(e["done"] for e in open_eps if e.get("done") is not None)
    total_sum = sum(e["total"] for e in open_eps if e.get("total") is not None)
    closed7 = M.get("closed7")
    right = f"{done_sum}/{total_sum}  {spark(closed7) if closed7 else '?'} " \
            f"{sum(closed7) if closed7 else '?'}/7d"
    lines.append(c(BOLD, pack_badge("EPICS", right, w)))
    has_agent = lambda e: bool(e.get("holding")) or e.get("unclaimed_stale")
    next_eps = sorted([e for e in open_eps if not (e.get("done") or 0) and not has_agent(e)],
                       key=lambda e: (e["priority"] if e.get("priority") is not None else 999,
                                      e.get("created_at") or ""))[:2]
    next_ids = {e["id"] for e in next_eps}
    open_rows = sorted([e for e in open_eps if e["id"] not in next_ids],
                        key=lambda e: (e["done"] / e["total"]) if e.get("total") else 0)
    for e in next_eps: lines.append(epic_row("○", e, w, now))
    for e in open_rows: lines.append(epic_row("▶", e, w, now))
    mrc = M.get("most_recent_closed_epic")
    if mrc: lines.append(epic_row("✓", mrc, w, now))

    # PIPELINE — plans then beads, bars flush (no blank line between rows in a section)
    lines.append("")
    lines.append(c(BOLD, "PIPELINE"))
    plans, pool = M.get("plans") or [], M.get("pool") or 0
    FLOW = ("draft", "approved", "polished", "refined", "bead-ready")
    known = set(FLOW) | {"beadified"}
    counts = {"proposals": pool}
    for st_ in FLOW: counts[st_] = sum(1 for p in plans if p["stage"] == st_)
    other_n = sum(1 for p in plans if p["stage"] not in known)
    rows = [("proposals", counts["proposals"])]
    for st_ in FLOW:
        if counts[st_] or st_ in ("draft", "approved", "bead-ready"): rows.append((st_, counts[st_]))
    if other_n: rows.append(("other", other_n))
    total_plans = sum(n for _, n in rows)
    lines.append(pack_badge(" plans", str(total_plans), w))
    for (label, n), cellc in zip(rows, alloc([n for _, n in rows], BARW)):
        d = delta(state, f"plans.{label}", n, now)
        bar = c("34", "█" * cellc) + "░" * (BARW - cellc)
        lines.append(f" {label:<11}{bar}" + (" " + c("35", d) if d else ""))

    B = M.get("beads")
    if B:
        b_ref = B.get("blocked_refined") or 0
        b_unref = max(0, B["n_blocked"] - b_ref) if B.get("blocked_by") is not None else 0
        rows2 = [("unrefined", B["n_unrefined"] + b_unref, b_unref),
                 ("refined", B["n_ready"] + b_ref, b_ref),
                 ("building", B["n_in_progress"], 0)]
        heading_r = str(sum(n for _, n, _ in rows2)) + (f" · {B['n_deferred']} deferred" if B["n_deferred"] else "")
        lines.append(pack_badge(" beads", heading_r, w))
        for (label, n, dim_n), cellc in zip(rows2, alloc([n for _, n, _ in rows2], BARW)):
            dim_cells = alloc([n - dim_n, dim_n], cellc)[1] if n else 0
            bright = cellc - dim_cells
            col = "92" if label == "building" else "32"
            bar = c(col, "█" * bright) + c(DIM, "▒" * dim_cells) + "░" * (BARW - cellc)
            d = delta(state, f"beads.{label}", n, now)
            lines.append(f" {label:<11}{bar}" + (" " + c("35", d) if d else ""))
    else:
        lines.append(" beads       ?")

    # HEALTH
    lines.append("")
    prs = M.get("prs")
    red = [p for p in prs if p["ci"].startswith("CI ✗")] if prs is not None else []
    problems = []
    if red: problems.append(f"PR #{red[0]['number']} red")
    ci = M.get("ci")
    if ci and "✗" in ci: problems.append(f"CI {ci}")
    if M.get("mail") != "up": problems.append(f"mail {M.get('mail') or '?'}")
    if M.get("split"): problems.append(f"{M['split']} agents on another mailbox key")
    if B and B.get("stale"): problems.append(f"{B['stale']} stale in-progress")
    for x in M.get("failed") or []: problems.append(f"? {x}")
    checks_bad = []
    docket = M.get("docket") or {}
    for k, v in (("board-truth", M.get("truth")), ("reason-less", docket.get("reason_less")),
                 ("gate-incomplete", docket.get("gate_incomplete")), ("plan-gap", docket.get("plan_gap"))):
        vs = "?" if v is None else str(v)
        if vs != "0": checks_bad.append(f"{k} {vs}")
    prs_n = len(prs) if prs is not None else "?"
    ok = not problems and not checks_bad
    head = f"{'✓' if ok else '⚠'} CI · {prs_n} PRs · checks {'✓' if not checks_bad else '⚠'}"
    lines.append(c("32" if ok else "33", clip(head, w)))
    for x in problems + checks_bad:
        lines.append(c("33", clip(f"⚠ {x}", w)))

    if footer:
        lines.append("")
        lines.append(clip(footer, w))
    return lines


# ── footer: every other beads repo this machine deploys to, as `abbr glyph` pairs ───────
ABBR_GLYPH = {"RUNNING": ("32", "●"), "IDLE": ("33", "◐"), "STUCK": ("31", "■"),
              "EMPTY": ("2", "○"), "UNKNOWN": ("31", "?")}


def abbr(path):
    n = os.path.basename(path.rstrip("/"))
    if n.endswith("-app"): n = n[:-4]
    return "".join(p[0] for p in n.split("-") if p) or n[:3]


def fetch_footer(cache, color_on):
    if "paths" not in cache:
        try:
            out = subprocess.run([BOARD, "--others"], capture_output=True, text=True, timeout=20)
            cache["paths"] = [p for p in out.stdout.splitlines() if p.strip()]
        except subprocess.TimeoutExpired:
            cache["paths"] = []
    now = time.time()
    if now - cache.get("at", 0) >= 60 or "items" not in cache:
        def one(p):
            try:
                r = subprocess.run([BOARD, "--compact", "--json"], capture_output=True, text=True,
                                    cwd=p, timeout=20)
                return abbr(p), json.loads(r.stdout).get("verdict", {}).get("state", "UNKNOWN")
            except (subprocess.TimeoutExpired, ValueError):
                return abbr(p), "UNKNOWN"
        with ThreadPoolExecutor(max_workers=8) as ex:
            cache["items"] = list(ex.map(one, cache["paths"])) if cache["paths"] else []
        cache["at"] = now
    c = colorer(color_on)
    return " ".join(c(ABBR_GLYPH.get(s, ("31", "?"))[0], f"{a} {ABBR_GLYPH.get(s, ('31', '?'))[1]}")
                    for a, s in cache.get("items", []))


def fetch_model(compact=False):
    try:
        out = subprocess.run([BOARD, "--json"] + (["--compact"] if compact else []),
                              capture_output=True, text=True, timeout=45)
    except subprocess.TimeoutExpired:
        return None
    try: return json.loads(out.stdout)
    except ValueError: return None


def live_loop(secs):
    color_on = os.environ.get("NO_COLOR") is None
    state, foot_cache = {}, {}
    resize = {"go": False}
    signal.signal(signal.SIGWINCH, lambda *_: resize.__setitem__("go", True))
    sys.stdout.write("\033[?1049h\033[?25l"); sys.stdout.flush()  # alt screen, hide cursor

    def restore(*_):
        sys.stdout.write("\033[?25h\033[?1049l"); sys.stdout.flush(); sys.exit(0)
    signal.signal(signal.SIGINT, restore); signal.signal(signal.SIGTERM, restore)

    last_M = None
    try:
        while True:
            M = fetch_model()
            if M is not None: last_M = M
            draw = last_M
            cols = shutil.get_terminal_size((80, 24)).columns
            footer = fetch_footer(foot_cache, color_on) if draw else ""
            for left in range(secs, -1, -1):
                if resize["go"]:
                    resize["go"] = False
                    cols = shutil.get_terminal_size((80, 24)).columns
                frame = ("\n".join(build_frame(draw, cols, color_on, state, secs_left=left, footer=footer))
                         if draw else "board: waiting for a read…")
                sys.stdout.write("\033[H\033[J" + frame + "\n"); sys.stdout.flush()
                if left: time.sleep(1)
    finally:
        sys.stdout.write("\033[?25h\033[?1049l"); sys.stdout.flush()


def main():
    argv = sys.argv[1:]
    if "--once" in argv:
        width, color_on = 40, os.environ.get("NO_COLOR") is None
        prev_file = save_file = None
        i = 0
        while i < len(argv):
            a = argv[i]
            if a == "--width": width = int(argv[i + 1]); i += 2; continue
            if a == "--no-color": color_on = False; i += 1; continue
            if a == "--prev": prev_file = argv[i + 1]; i += 2; continue
            if a == "--save-counts": save_file = argv[i + 1]; i += 2; continue
            i += 1
        try:
            M = json.load(sys.stdin)
        except ValueError as e:
            print(f"tui.py --once: malformed model JSON on stdin: {e}", file=sys.stderr); sys.exit(1)
        state = {}
        if prev_file and os.path.isfile(prev_file):
            try:
                with open(prev_file, encoding="utf-8") as f: state = json.load(f)
            except ValueError: state = {}  # a corrupt --prev file just starts fresh
        print("\n".join(build_frame(M, width, color_on, state)))
        if save_file:
            with open(save_file, "w", encoding="utf-8") as f: json.dump(state, f)
        return
    secs = int(argv[0]) if argv and argv[0].lstrip("-").isdigit() else 15
    live_loop(secs)


if __name__ == "__main__":
    main()
