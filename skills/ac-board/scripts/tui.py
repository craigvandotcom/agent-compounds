#!/usr/bin/env python3
"""tui.py — the ac-board terminal dashboard: one column, ANSI-16, built for a tall narrow
pane or a phone. Formats the SAME model.build() dict render.py does — never re-derives a
count. No emoji anywhere here (they are double-width); glyphs are single-width only.

Usage:  tui.py [secs]                     the live loop (default 15s); execed by
                                          `board.sh --watch [secs]`.
        tui.py --once --width N [--height N] [--footer TEXT] [--no-color]
               [--prev FILE] [--save-counts FILE]
                                          reads a model dict (model.build()'s JSON, i.e.
                                          `board.sh --json`'s output) on stdin, prints one
                                          frame, exits — the test seam. --height forces the
                                          same trim a short pane gets (footer → HEALTH detail
                                          → ON YOU capped further); --footer feeds it a footer
                                          line, since --once never fetches one itself.
                                          --prev/--save-counts chain the in-process delta
                                          memory across two calls.
Env:    NO_COLOR disables colour (same as --no-color).
"""
import datetime as dt, json, math, os, re, shutil, signal, subprocess, sys, time
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.realpath(__file__))
BOARD = os.path.join(HERE, "board.sh")
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
    sp = max(cut.rfind(" "), cut.rfind("-"))
    if sp > w * 0.6: cut = cut[:sp]
    return cut.rstrip(" ,:;—-(") + "…"


def slug(title, w):
    """A gate title as a slug: `ACTION:`/`DECISION:` stripped, clipped at a word boundary."""
    return clip(re.sub(r"^(ACTION|DECISION):\s*", "", title or ""), w)


def plan_slug(name):
    """A plan's display name: its `YYYY-MM-DD-` and optional `HHMM-` prefix stripped."""
    return re.sub(r"^\d{4}-\d{2}-\d{2}-(?:\d{4}-)?", "", name or "")


def epic_slug(title):
    """An epic's display name: the text before its first `:` or ` — `, whichever comes first."""
    return re.split(r":\s+|\s—\s", title or "", maxsplit=1)[0].strip()


def age_from_epoch(mtime, now):
    if mtime is None: return ""
    return age(dt.datetime.fromtimestamp(mtime, dt.timezone.utc).isoformat(), now)


def resolve_now(M):
    return ts((M or {}).get("now")) or (dt.datetime.fromisoformat(os.environ["AC_BOARD_NOW"])
                                         if os.environ.get("AC_BOARD_NOW") else dt.datetime.now(dt.timezone.utc))


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


# ── ON YOU: one row per ranked move — one row per PLAN within a grouped plan move ────────
def expand_moves(moves):
    """A grouped plan move (`polish 2 plans`) becomes one entry per plan name; gates serving
    the same epic merge into one entry (`×n`, blocks summed, oldest age). Order is preserved."""
    out, by_epic = [], {}
    for mv in moves:
        if mv.get("rung") in ("gate", "idle-gate") and mv.get("epic"):  # one row per epic served
            first = by_epic.get(mv["epic"])
            if first:
                first["n"] = first.get("n", 1) + 1
                first["blocks"] = (first.get("blocks") or 0) + (mv.get("blocks") or 0)
                first["created_at"] = min(first["created_at"], mv["created_at"])
                continue
            mv = by_epic[mv["epic"]] = dict(mv)
            out.append(mv)
        elif mv.get("rung") in ("beadify", "polish-plan", "approve-plan"):
            for nm in (mv.get("names") or [""]):
                out.append({**mv, "names": [nm]})
        else:
            out.append(mv)
    return out


def on_you_row(mv, w, now, c, plan_mtime):
    """One line per move: glyph, the command to type, what it acts on, then the badge."""
    rung = mv.get("rung")
    if rung in ("gate", "idle-gate"):
        glyph = "◆" if mv.get("gate_kind") == "decision" else "▲"
        text = epic_slug(mv.get("epic")) or slug(mv.get("title", ""), w)
        if mv.get("n", 1) > 1: text += f" ×{mv['n']}"
        badge = "  ".join(([f"⊘{mv['blocks']}"] if mv.get("blocks") else []) + [age(mv.get("created_at"), now)])
    elif rung in ("beadify", "polish-plan", "approve-plan"):
        glyph, nm = GLYPH.get(rung, "»"), (mv.get("names") or [""])[0]
        text, badge = plan_slug(nm), age_from_epoch(plan_mtime.get(nm), now)
    else:
        glyph, badge = GLYPH.get(rung, "»"), ""
        text = {"pool": lambda: plural(mv.get("pool", 0), "proposal"),
                "refine-bead": lambda: plural(mv.get("n_unrefined", 0), "bead"),
                "implement": lambda: plural(mv.get("n_ready", 0), "ready bead"),
                "reclaim": lambda: plural(len(mv.get("bead_ids") or []), "bead"),
                "red-pr": lambda: "red PR"}.get(rung, lambda: mv.get("subject", ""))()
    head = " ".join(x for x in (glyph, mv.get("route"), text) if x)
    return [c("33", pack_badge(clip(head, w - len(badge) - 2 if badge else w), badge, w))]


def render_onyou(moves, w, now, c, plan_mtime, cap):
    """ON YOU: heading with the true count, up to `cap` items, `+ n more` past it."""
    if len(moves) == 1 and moves[0].get("rung") == "none":
        return [c(BOLD, "ON YOU") + "  " + c("32", "✓ clear")]
    lines = [c(BOLD, pack_badge("ON YOU", str(len(moves)), w))]
    shown = moves[:max(0, cap)]
    for mv in shown:
        lines.extend(on_you_row(mv, w, now, c, plan_mtime))
    hidden = len(moves) - len(shown)
    if hidden > 0: lines.append(c(DIM, f"+ {hidden} more"))
    return lines


# ── EPICS: one row per epic (next → open → most recently closed), columns aligned ───────
def epic_agents(e):
    return "⚠" if e.get("unclaimed_stale") else "●" * len(e.get("holding") or [])


def progress_rows(rows, w):
    """`next`/`open` rows: a title column fixed across all of them so the agent dots, the
    6-cell bar and done/total line up row to row — not each row's own leftover width.
    `rows` is a list of `(glyph, epic)`."""
    agent_w = max([1] + [len(epic_agents(e)) for _, e in rows])
    count_w = max([1] + [len(f"{e['done']}/{e['total']}") for _, e in rows if e.get("total")])
    title_w = max(4, w - 2 - 1 - agent_w - 1 - 6 - 1 - count_w)
    out = []
    for glyph, e in rows:
        etitle = clip(epic_slug(e.get("title", "")), title_w)
        a = epic_agents(e)
        bar = bar6(e["done"], e["total"]) if e.get("total") else "─" * 6
        dt_ = f"{e['done']}/{e['total']}" if e.get("total") else ""
        out.append(f"{glyph} {etitle:<{title_w}} {a:<{agent_w}} {bar} {dt_:>{count_w}}")
    return out


def closed_row(e, w, now):
    """The ✓ row: no bar, just its age — right-aligned to w, like a gate's."""
    etitle = clip(epic_slug(e.get("title", "")), w - 2)
    return pack_badge(f"✓ {etitle}", age(e.get("closed_at"), now), w)


def build_header(name, now, w, secs_left, color_on):
    """Line 1 alone — the live loop rewrites just this line, in place, every second; it is
    the "alive" signal between full refreshes."""
    c = colorer(color_on)
    hhmm = now.astimezone().strftime("%H:%M")
    left = f"{name} · {hhmm}"
    right = f"↻ {secs_left}s" if secs_left is not None else ""
    header = left + " " * max(1, w - len(left) - len(right)) + right if right else left
    return c(DIM, clip(header, w))


def pipeline_rows(rows, w, section, state, now, c, color_of):
    """`label  count bar` — bar cells are that row's share of the section, summing exactly
    to the width left after the label/count/a `+n` delta's room; no track glyph — unused
    cells are simply not drawn (a solid, touching silhouette, not a gauge). `rows` is
    `(label, n)` or `(label, n, dim_n)` — the blocked share of n, dimmed to `▒` at the
    right end. `color_of` is a bright-cell colour code, or `label -> code`."""
    if not rows: return []
    counts = [n for _, n, *_ in rows]
    count_w = max(2, max(len(str(n)) for n in counts))
    label_w = 11
    barw = max(1, w - 1 - label_w - count_w - 1 - 4)  # 4 = room for a " +12"-shaped delta
    cells = alloc(counts, barw)
    out = []
    for (label, n, *rest), cellc in zip(rows, cells):
        dim_n = rest[0] if rest else 0
        dim_cells = alloc([n - dim_n, dim_n], cellc)[1] if n and dim_n else 0
        bright = cellc - dim_cells
        col = color_of(label) if callable(color_of) else color_of
        bar = c(col, "█" * bright) + (c(DIM, "▒" * dim_cells) if dim_cells else "")
        d = delta(state, f"{section}.{label}", n, now)
        out.append(f" {label:<{label_w}}{n:>{count_w}} {bar}" + (" " + c("35", d) if d else ""))
    return out


# ── the frame: one column, header → status → ON YOU → EPICS → PIPELINE → HEALTH ─────────
def build_frame(M, width, color_on, state, secs_left=None, footer=None, height=None):
    w = max(36, min(67, width))
    now = resolve_now(M)
    c = colorer(color_on)

    header_lines = [build_header(M.get("name", "?"), now, w, secs_left, color_on)]
    st = (M.get("verdict") or {}).get("state", "UNKNOWN")
    reasons = (M.get("verdict") or {}).get("reasons") or []
    text = st
    for r in reasons:
        cand = text + " · " + r
        if len(cand) + 2 > w: break
        text = cand
    bar_text = clip(f" {text} ", w)
    bar_text += " " * (w - len(bar_text))
    header_lines.append(c(f"7;{STATE_COLOR.get(st, '31')}", bar_text))

    # ON YOU — one row per plan within a grouped plan move; `cap` shrinks under a height limit
    moves = expand_moves(M.get("moves") or [])
    plan_mtime = {p["name"]: p["mtime"] for p in (M.get("plans") or [])}

    # EPICS
    items = (M.get("epics") or {}).get("items") or []
    open_eps = [e for e in items if not e.get("closed_at")]
    done_sum = sum(e["done"] for e in open_eps if e.get("done") is not None)
    total_sum = sum(e["total"] for e in open_eps if e.get("total") is not None)
    closed7 = M.get("closed7")
    epics_right = f"{done_sum}/{total_sum}  {spark(closed7) if closed7 else '?'} " \
                  f"{sum(closed7) if closed7 else '?'}/7d"
    has_agent = lambda e: bool(e.get("holding")) or e.get("unclaimed_stale")
    next_eps = sorted([e for e in open_eps if not (e.get("done") or 0) and not has_agent(e)],
                       key=lambda e: (e["priority"] if e.get("priority") is not None else 999,
                                      e.get("created_at") or ""))[:2]
    next_ids = {e["id"] for e in next_eps}
    open_rows = sorted([e for e in open_eps if e["id"] not in next_ids],
                        key=lambda e: (e["done"] / e["total"]) if e.get("total") else 0)
    prog_rows = [("○", e) for e in next_eps] + [("▶", e) for e in open_rows]
    epics_lines = [c(BOLD, pack_badge("EPICS", epics_right, w))] + progress_rows(prog_rows, w)
    mrc = M.get("most_recent_closed_epic")
    if mrc: epics_lines.append(closed_row(mrc, w, now))

    # PIPELINE — plans then beads, bars flush (no blank line between rows in a section)
    plans, pool = M.get("plans") or [], M.get("pool") or 0
    FLOW = ("draft", "approved", "polished", "refined", "bead-ready")
    known = set(FLOW) | {"beadified"}
    counts = {"proposals": pool}
    for st_ in FLOW: counts[st_] = sum(1 for p in plans if p["stage"] == st_)
    other_n = sum(1 for p in plans if p["stage"] not in known)
    plan_rows = [("proposals", counts["proposals"])]
    for st_ in FLOW:
        if counts[st_] or st_ in ("draft", "approved", "bead-ready"): plan_rows.append((st_, counts[st_]))
    if other_n: plan_rows.append(("other", other_n))
    total_plans = sum(n for _, n in plan_rows)
    pipeline_lines = [c(BOLD, "PIPELINE"), pack_badge("plans", str(total_plans), w)]
    pipeline_lines += pipeline_rows(plan_rows, w, "plans", state, now, c, "34")

    B = M.get("beads")
    if B:
        b_ref = B.get("blocked_refined") or 0
        b_unref = max(0, B["n_blocked"] - b_ref) if B.get("blocked_by") is not None else 0
        beads_rows = [("unrefined", B["n_unrefined"] + b_unref, b_unref),
                      ("refined", B["n_ready"] + b_ref, b_ref),
                      ("building", B["n_in_progress"], 0)]
        heading_r = str(sum(n for _, n, _ in beads_rows)) + \
            (f" · {B['n_deferred']} deferred" if B["n_deferred"] else "")
        pipeline_lines.append(pack_badge("beads", heading_r, w))
        beads_color = lambda label: "92" if label == "building" else "32"  # building = bright green
        pipeline_lines += pipeline_rows(beads_rows, w, "beads", state, now, c, beads_color)
    else:
        pipeline_lines.append(" beads       ?")

    # HEALTH — CI's own glyph reflects CI alone; "none scheduled" is not a problem
    prs = M.get("prs")
    red = [p for p in prs if p["ci"].startswith("CI ✗")] if prs is not None else []
    problems = []
    if red: problems.append(f"PR #{red[0]['number']} red")
    ci = M.get("ci")
    ci_bad = ci is None or "✗" in (ci or "")
    ci_none = ci == "none scheduled"
    if ci_bad: problems.append(f"CI {ci or '?'}")
    ci_piece = (f"⚠ CI {ci or '?'}") if ci_bad else ("CI —" if ci_none else "✓ CI")
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
    head = f"{ci_piece} · {prs_n} PRs · checks {'✓' if not checks_bad else '⚠'}"
    health_head = [c("32" if ok else "33", clip(head, w))]
    health_detail = [c("33", clip(f"⚠ {x}", w)) for x in problems + checks_bad]

    footer_lines = ["", clip(footer, w)] if footer else []

    def assemble(cap, show_detail, show_footer):
        out = list(header_lines) + [""]
        out += render_onyou(moves, w, now, c, plan_mtime, cap)
        out += [""] + epics_lines
        out += [""] + pipeline_lines
        out += [""] + health_head
        if show_detail: out += health_detail
        if show_footer: out += footer_lines
        return out

    lines = assemble(8, True, True)
    if height is not None:
        if len(lines) > height: lines = assemble(8, True, False)
        if len(lines) > height: lines = assemble(8, False, False)
        cap = 8
        while len(lines) > height and cap > 0:
            cap -= 1
            lines = assemble(cap, False, False)
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

    def full_redraw(draw, cols, left, footer):
        frame = ("\n".join(build_frame(draw, cols, color_on, state, secs_left=left, footer=footer))
                  if draw else "board: waiting for a read…")
        sys.stdout.write("\033[H\033[J" + frame + "\n"); sys.stdout.flush()

    try:
        while True:
            M = fetch_model()
            if M is not None: last_M = M
            draw = last_M
            cols = shutil.get_terminal_size((80, 24)).columns
            footer = fetch_footer(foot_cache, color_on) if draw else ""
            header_now = resolve_now(draw) if draw else dt.datetime.now(dt.timezone.utc)
            name = draw.get("name", "?") if draw else "board"
            full_redraw(draw, cols, secs, footer)
            # between fetches, rewrite only line 1 — the ticking countdown is the alive signal
            for left in range(secs - 1, -1, -1):
                time.sleep(1)
                if resize["go"]:
                    resize["go"] = False
                    cols = shutil.get_terminal_size((80, 24)).columns
                    full_redraw(draw, cols, left, footer)
                    continue
                if draw:
                    hdr = build_header(name, header_now, cols, left, color_on)
                    sys.stdout.write(f"\033[1;1H{hdr}\033[K\n"); sys.stdout.flush()
    finally:
        sys.stdout.write("\033[?25h\033[?1049l"); sys.stdout.flush()


def main():
    argv = sys.argv[1:]
    if "--once" in argv:
        width, height, color_on = 40, None, os.environ.get("NO_COLOR") is None
        prev_file = save_file = footer = None
        i = 0
        while i < len(argv):
            a = argv[i]
            if a == "--width": width = int(argv[i + 1]); i += 2; continue
            if a == "--height": height = int(argv[i + 1]); i += 2; continue
            if a == "--no-color": color_on = False; i += 1; continue
            if a == "--prev": prev_file = argv[i + 1]; i += 2; continue
            if a == "--save-counts": save_file = argv[i + 1]; i += 2; continue
            if a == "--footer": footer = argv[i + 1]; i += 2; continue  # the height-trim test seam
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
        print("\n".join(build_frame(M, width, color_on, state, height=height, footer=footer)))
        if save_file:
            with open(save_file, "w", encoding="utf-8") as f: json.dump(state, f)
        return
    secs = int(argv[0]) if argv and argv[0].lstrip("-").isdigit() else 15
    live_loop(secs)


if __name__ == "__main__":
    main()
