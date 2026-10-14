#!/usr/bin/env python3
"""tui.py — the ac-board terminal dashboard (read-only). Formats the SAME model.build() dict
render.py does — never re-derives a count. No emoji anywhere here (they are double-width);
every glyph is single-width box drawing or a geometric glyph.

Layout: framed cards with tee-bracket headers (`┌─┤ PLANS ├───…───┐`), the ON YOU card drawn
in double line while moves are live, a stage-step ribbon, and tracked gauges (`█` this row's
share, `▒` the blocked share of it, `·` the unfilled track). A pane narrower than 80 columns
stacks the cards in one column at full width; 80 and wider pairs ON YOU · EPICS and PLANS ·
BEADS in a 2-column grid, with AGENTS & HEALTH across the bottom.

Usage:  tui.py [secs]                     the live loop (default 15s); execed by
                                          `board.sh --watch [secs]`. Re-execs itself in place
                                          when this file's mtime moves, so a running watcher
                                          never keeps old code across an edit or a commit.
        tui.py --once --width N [--height N] [--footer TEXT] [--no-color]
               [--prev FILE] [--save-counts FILE]
                                          reads a model dict (model.build()'s JSON, i.e.
                                          `board.sh --json`'s output) on stdin, prints one
                                          frame, exits — the test seam. --height forces the
                                          same trim a short pane gets (footer → HEALTH detail
                                          → the step ribbon → ON YOU capped down to 0);
                                          --footer feeds it a footer line, since --once never
                                          fetches one itself. --prev/--save-counts chain the
                                          in-process delta memory across two calls.
Env:    NO_COLOR disables colour (same as --no-color).
"""
import datetime as dt, json, math, os, re, shutil, signal, subprocess, sys, time
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.realpath(__file__))
BOARD = os.path.join(HERE, "board.sh")
DELTA_MIN = 15            # a moved count shows its change this long
EIGHTHS = " ▏▎▍▌▋▊▉█"

# ── palette: 256-colour, slate chrome + one hue per lane ───────────────────────────────
BORD, MUT, TRACK = "38;5;240", "38;5;245", "38;5;238"   # borders · muted text · dot track
BLUE, GREEN, AMBER = "38;5;75", "38;5;114", "38;5;215"  # beads/work · plans/healthy · on-you
RED, CYAN, MAG = "38;5;203", "38;5;117", "38;5;176"     # stuck/failed · epics/flow · deltas
BOLD, DIM = "1", "2"
STATE_COLOR = {"RUNNING": GREEN, "IDLE": AMBER, "STUCK": RED, "EMPTY": MUT, "UNKNOWN": RED}
REPO_STATE = {"RUNNING": ("running", GREEN), "IDLE": ("idle", AMBER), "STUCK": ("stuck", RED),
              "EMPTY": ("empty", MUT), "UNKNOWN": ("unknown", RED)}
GLYPH = {"red-pr": "▲", "reclaim": "↻", "implement": "▶", "refine-bead": "~",
         "beadify": "»", "polish-plan": "»", "approve-plan": "»", "pool": "+",
         "none": "✓", "fix-reads": "⚠"}
ANSI_RE = re.compile(r"\033\[[0-9;]*[a-zA-Z]")


# ── small pure helpers — tui is a standalone view, so these are its own copies ──────────
def vlen(s):
    """Visible width: escapes take no columns."""
    return len(ANSI_RE.sub("", s))


def trunc(s, n):
    """Hard-truncate to n visible columns, never cutting an escape sequence in half."""
    if vlen(s) <= n: return s
    out, seen, i = [], 0, 0
    while i < len(s) and seen < n:
        m = ANSI_RE.match(s, i)
        if m: out.append(m.group()); i = m.end(); continue
        out.append(s[i]); seen += 1; i += 1
    j = "".join(out)
    return j + "\033[0m" if "\033" in j else j


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
    """Plain-text clip to w columns — call it on text, never on a coloured string."""
    s = " ".join((s or "").split())
    if len(s) <= w: return s
    cut = s[:max(0, w - 1)]
    sp = max(cut.rfind(" "), cut.rfind("-"))
    if sp > w * 0.6: cut = cut[:sp]
    return cut.rstrip(" ,:;—-(") + "…"


def clip_path(s, w):
    """A path clipped from the LEFT — the filename is the part worth keeping."""
    s = (s or "").strip()
    return s if len(s) <= w else "…" + s[-(w - 1):]


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


def pack_parts(parts, w, sep=" · "):
    """Greedy: join parts with `sep`, starting a new line rather than overflowing w — so a
    narrow card loses no fact to a clip, it just spends another line."""
    lines = []
    for p in parts:
        if lines and len(lines[-1]) + len(sep) + len(p) <= w: lines[-1] += sep + p
        else: lines.append(p)
    return lines


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


# ── the frame: tee-bracket cards, stacked narrow or paired in a 2-column grid ───────────
def hdr_fill(cw, title, right=""):
    """Cells left for dashes in a card's tee-bracket header; < 1 means a badge will not fit."""
    t = f" {title} "
    return cw - 9 - len(t) - len(right) - 2 if right else cw - 5 - len(t)


def box(title, body, cw, c, right="", double=False, accent=None):
    """A framed card exactly `cw` visible columns wide: a tee-bracket header
    (`┌─┤ TITLE ├───┐`, or `┌─┤ TITLE ├───┤ RIGHT ├─┐`), `│ row │` rows, a corner bottom.
    `double` switches every glyph to double line (the focal card). A badge with no room in
    the header is dropped rather than squeezed, and a row is truncated, so the card never
    exceeds `cw`."""
    l, r, h, v, bl, br = ("╔", "╗", "═", "║", "╚", "╝") if double else ("┌", "┐", "─", "│", "└", "┘")
    lg, rg = ("╡", "╞") if double else ("┤", "├")
    t = f" {title} "
    if right and hdr_fill(cw, title, right) < 1: right = ""
    tail = f" {right} " if right else ""
    fill = max(1, cw - 9 - len(t) - len(tail)) if tail else max(1, cw - 5 - len(t))
    head = [c(BORD, l + h + lg), c(accent or BOLD, t), c(BORD, rg + h * fill)]
    if tail: head += [c(BORD, h + lg), c(accent or BOLD, tail), c(BORD, rg + h)]
    head.append(c(BORD, r))
    iw = cw - 4
    out = ["".join(head)]
    for row in body:
        row = trunc(row, iw)
        out.append(c(BORD, v) + " " + row + " " * (iw - vlen(row)) + " " + c(BORD, v))
    out.append(c(BORD, bl + h * (cw - 2) + br))
    return out


def pad_card(lines, n, c):
    """Grow a card to n lines by inserting blank interior rows before its own bottom border."""
    if len(lines) >= n or not lines: return lines
    v = "║" if ANSI_RE.sub("", lines[-1])[:1] == "╚" else "│"
    blank = c(BORD, v) + " " * (vlen(lines[-1]) - 2) + c(BORD, v)
    return lines[:-1] + [blank] * (n - len(lines)) + [lines[-1]]


def join_h(left, right, c, gap="  "):
    """Two cards side by side, the shorter padded so both bottom borders land together."""
    n = max(len(left), len(right))
    return [x + gap + y for x, y in zip(pad_card(left, n, c), pad_card(right, n, c))]


def build_header(name, now, w, secs_left, color_on, git=None):
    """Line 1 alone — the live loop rewrites just this line, in place, every second; it is
    the "alive" signal between full refreshes. `git` (telemetry's branch/dirty/ahead) rides
    between the name and the clock, so the working tree is visible without reading the board."""
    c = colorer(color_on)
    hhmm = now.astimezone().strftime("%H:%M")
    left = [c(MUT, name)]
    if git and git.get("branch"):
        left += [c(BORD, " · "), git_badge(git, c)]
    left += [c(BORD, " · "), c(MUT, hhmm)]
    head = "".join(left)
    right = c(MUT, f"↻ {secs_left}s") if secs_left is not None else ""
    if not right: return trunc(head, w)
    return trunc(head + " " * max(1, w - vlen(head) - vlen(right)) + right, w)


def git_badge(git, c):
    """`main ✓ clean` · `main ⚠ 3 dirty` · `main ✓ clean ↑2` — the tree in one glance."""
    out = c(CYAN, git["branch"])
    if git.get("dirty"): out += " " + c(AMBER, f"⚠ {git['dirty']} dirty")
    else: out += " " + c(GREEN, "✓ clean")
    if git.get("ahead"): out += " " + c(AMBER, f"↑{git['ahead']}")
    if git.get("behind"): out += " " + c(AMBER, f"↓{git['behind']}")
    return out


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


def on_you_row(mv, iw, now, c, plan_mtime):
    """One line per move: glyph, the command to type, what it acts on, then the badge."""
    rung = mv.get("rung")
    if rung in ("gate", "idle-gate"):
        glyph = "◆" if mv.get("gate_kind") == "decision" else "▲"
        gcol = MAG if mv.get("gate_kind") == "decision" else RED
        text = epic_slug(mv.get("epic")) or slug(mv.get("title", ""), iw)
        if mv.get("n", 1) > 1: text += f" ×{mv['n']}"
        badge = "  ".join(([f"⊘{mv['blocks']}"] if mv.get("blocks") else []) + [age(mv.get("created_at"), now)])
    elif rung in ("beadify", "polish-plan", "approve-plan"):
        glyph, gcol = GLYPH.get(rung, "»"), AMBER
        nm = (mv.get("names") or [""])[0]
        text, badge = plan_slug(nm), age_from_epoch(plan_mtime.get(nm), now)
    else:
        glyph, gcol, badge = GLYPH.get(rung, "»"), BLUE, ""
        text = {"pool": lambda: plural(mv.get("pool", 0), "proposal"),
                "refine-bead": lambda: plural(mv.get("n_unrefined", 0), "bead"),
                "implement": lambda: plural(mv.get("n_pick", 0), "ready bead"),
                "reclaim": lambda: plural(len(mv.get("bead_ids") or []), "bead"),
                "red-pr": lambda: "red PR"}.get(rung, lambda: mv.get("subject", ""))()
    route = mv.get("route") or ""
    rw = len(route) + 1 if route else 0
    body = pack_badge(text, badge, max(6, iw - 2 - rw))
    return c(gcol, glyph) + " " + (c(BLUE, route) + " " if route else "") + body


# ── EPICS: one row per epic (next → open → most recently closed), columns aligned ───────
def epic_agents(e):
    return "⚠" if e.get("unclaimed_stale") else "●" * len(e.get("holding") or [])


def progress_rows(rows, iw, c):
    """`next`/`open` rows: a title column fixed across all of them so the agent dots, the
    6-cell bar and done/total line up row to row — not each row's own leftover width.
    `rows` is a list of `(glyph, epic)`."""
    agent_w = max([1] + [len(epic_agents(e)) for _, e in rows])
    count_w = max([1] + [len(f"{e['done']}/{e['total']}") for _, e in rows if e.get("total")])
    title_w = max(4, iw - 2 - 1 - agent_w - 1 - 6 - 1 - count_w)
    out = []
    for glyph, e in rows:
        etitle = clip(epic_slug(e.get("title", "")), title_w)
        a = epic_agents(e)
        bar = bar6(e["done"], e["total"]) if e.get("total") else "─" * 6
        dt_ = f"{e['done']}/{e['total']}" if e.get("total") else ""
        out.append(c(MUT if glyph == "○" else CYAN, glyph) + " "
                   + f"{etitle:<{title_w}} " + c(AMBER if a == "⚠" else GREEN, a)
                   + " " * (agent_w - len(a)) + " "
                   + c(CYAN, bar) + " " + c(MUT, f"{dt_:>{count_w}}"))
    return out


def closed_row(e, iw, now, c):
    """The ✓ row: no bar, just its age — right-aligned to iw, like a gate's."""
    etitle = clip(epic_slug(e.get("title", "")), iw - 2)
    return c(GREEN, "✓ ") + c(MUT, pack_badge(etitle, age(e.get("closed_at"), now), iw - 2))


# ── PLANS / BEADS: a tracked gauge per stage — `█` share · `▒` blocked share · `·` track ──
def gauge_cells(n, total, barw, dim=0):
    """(█, ▒, ·) for one row of a tracked gauge — the three always sum to barw. A row with no
    share of a non-empty section is all track; a blocked share fills the row from its right."""
    if barw <= 0: return (0, 0, 0)
    if not n or not total: return (0, 0, barw)
    filled = min(barw, max(1, round(n / total * barw)))
    block = alloc([n - dim, dim], filled)[1] if dim else 0
    return (filled - block, block, barw - filled)


def gauge(cells, col, c):
    bright, block, track = cells
    return (c(col, "█" * bright) + (c(DIM, "▒" * block) if block else "")
            + c(TRACK, "·" * track))


def pipeline_rows(rows, iw, section, state, now, c, color_of):
    """`label  count  gauge` — each row's cells are its share of the section, so the whole
    section reads as one silhouette: `█` live, `▒` blocked (dimmed), `·` unfilled track.
    `rows` is `(label, n)` or `(label, n, dim_n)` — dim_n being the blocked share of n.
    `color_of` is a bright-cell colour code, or `label -> code`."""
    if not rows: return []
    counts = [n for _, n, *_ in rows]
    total = sum(counts)
    count_w = max(2, max(len(str(n)) for n in counts))
    label_w = 11
    barw = max(1, iw - 1 - label_w - count_w - 1 - 4)  # 4 = room for a " +12"-shaped delta
    out = []
    for label, n, *rest in rows:
        col = color_of(label) if callable(color_of) else color_of
        d = delta(state, f"{section}.{label}", n, now)
        out.append(f" {label:<{label_w}}{n:>{count_w}} "
                   + gauge(gauge_cells(n, total, barw, rest[0] if rest else 0), col, c)
                   + (" " + c(MAG, d) if d else ""))
    return out


# ── telemetry: the harness legend, sessions & tools, and the activity tail ──────────────
HARNESS_COLORS = (BLUE, GREEN, MAG, CYAN, AMBER)
LANE_COLOR = {"git": GREEN, "mail": AMBER, "bead": CYAN}   # a harness lane falls back to blue
SHORT_TOOL = {"subagent": "sub", "bash": "bash", "read": "read", "edit": "edit",
              "grep": "grep", "web": "web", "todo": "todo"}


def tel_of(M):
    """The telemetry block, or None when the read was not asked for / could not answer."""
    t = (M or {}).get("telemetry")
    return t if isinstance(t, dict) else None


def short_model(m):
    """`claude-opus-5-5` -> `opus-5-5` — the vendor prefix is the harness's own name."""
    return clip(re.sub(r"^claude-", "", (m or "").split("/")[-1]), 18)


def fmt_tokens(n):
    if not n: return "0"
    if n >= 1_000_000: return f"{n / 1e6:.1f}M"
    if n >= 1_000: return f"{n / 1e3:.0f}k"
    return str(n)


def legend_line(tel, agents, locks, c, w):
    """The harness legend: a coloured `■` pill per harness that ran here, then the locks.
    Falls back to plain text rather than truncating a coloured pill mid-escape."""
    parts = []
    for i, h in enumerate(tel.get("harnesses") or []):
        live = h.get("active_now") or 0
        model = short_model((h.get("models") or [None])[0])
        count = f"{live} live" if live else f"{h.get('sessions_24h', 0)}/24h"
        plain = h["harness"] + (f" · {model}" if model else "") + f" ({count})"
        parts.append((c(HARNESS_COLORS[i % len(HARNESS_COLORS)], "■") + c(MUT, " " + plain),
                      "■ " + plain))
    if locks:
        plain = f"{locks} lock" + ("" if locks == 1 else "s")
        parts.append((c(AMBER, "⊞") + c(MUT, " " + plain), "⊞ " + plain))
    elif not parts:
        live = [a for a in (agents or []) if a.get("live")]
        if not live: return None
        plain = f"{len(live)} live agent" + ("" if len(live) == 1 else "s")
        parts.append((c(GREEN, "●") + c(MUT, " " + plain), "● " + plain))
    line = c(BORD, "  ·  ").join(p for p, _ in parts)
    if vlen(line) <= w: return line
    plain = "  ·  ".join(p for _, p in parts)
    return c(MUT, plain if len(plain) <= w else clip(plain, w))


def sessions_card(cw, tel, c):
    """`SESSIONS & TOOLS` — a token gauge per harness, then cache efficiency and tool calls."""
    iw = cw - 4
    hs = tel.get("harnesses") or []
    label_w = max([8] + [len(h["harness"]) for h in hs])
    count_w, tok_w = 3, max([1] + [len(fmt_tokens(h.get("tokens"))) for h in hs])
    barw = max(4, iw - label_w - count_w - tok_w - 4)
    top = max([1] + [(h.get("tokens") or 0) for h in hs])
    body = []
    for h in hs:
        n = h.get("tokens") or 0
        body.append(c(BLUE, f"{h['harness']:<{label_w}}") + " "
                    + c(MUT, f"{h.get('sessions_24h', 0):>{count_w}}") + " "
                    + gauge(gauge_cells(n, top, barw), CYAN, c) + " "
                    + c(MUT, f"{fmt_tokens(n):>{tok_w}}"))
    pcts = [h.get("cache_hit_pct") for h in hs if h.get("cache_hit_pct") is not None]
    if pcts:
        pct = round(sum(pcts) / len(pcts))
        body.append(c(MUT, f"{'cache hit ' + str(pct) + '%':<{label_w + count_w + 2}}") + " "
                    + gauge(gauge_cells(pct, 100, barw + tok_w + 1), GREEN, c))
    t = tel.get("tools_24h") or {}
    parts = [f"tools {t.get('total', 0)}"] + [f"{SHORT_TOOL.get(k, k)} {n}" for k, n in t.get("top") or []]
    if t.get("errors"): parts.append(f"⚠ {t['errors']} error" + ("" if t["errors"] == 1 else "s"))
    for line in pack_parts(parts, iw): body.append(c(AMBER if "⚠" in line else MUT, line))
    return box("SESSIONS & TOOLS", body or [c(MUT, "no session in 24h")], cw, c,
               right=f"{sum(h.get('sessions_24h', 0) for h in hs)} sess", accent=CYAN)


def activity_card(cw, rows, c):
    """`tail -f activity.log` — the events across every lane, oldest first, newest last."""
    iw = cw - 4
    lane_w = max(len(r.get("lane") or "") for r in rows)
    actor_w = min(14, max(len(r.get("actor") or "") for r in rows))
    body = []
    for r in reversed(rows):
        t = ts(r.get("ts"))
        lane = r.get("lane") or "?"
        text_w = max(6, iw - lane_w - actor_w - 11)
        body.append(c(MUT, t.astimezone().strftime("%H:%M") if t else "--:--") + "  "
                    + c(LANE_COLOR.get(lane, BLUE), f"{lane:<{lane_w}}") + "  "
                    + c(MUT, f"{clip(r.get('actor') or '?', actor_w):<{actor_w}}") + "  "
                    + clip(r.get("text") or "", text_w))
    return box("tail -f activity.log", body, cw, c, accent=MUT)


def bv_lines(bv, iw, c):
    """The two graph facts worth a row: what unblocks the most, and what sits between."""
    out = []
    ks, bn = bv.get("keystone"), bv.get("bottleneck")
    if ks:
        out.append(c(CYAN, "◆ keystone  ")
                   + c(MUT, clip(f"{ks['id']} → unblocks {ks.get('unblocks') or 0}", iw - 12)))
    if bn:
        out.append(c(AMBER, "▲ bottleneck ")
                   + c(MUT, clip(f"{bn['id']} (centrality {bn.get('value') or 0:.0f})", iw - 13)))
    return out


def velocity_line(bv, iw, c):
    """`avg close 3.9d · 327/30d · 0 cycles` — bv's velocity, muted, as the EPICS footer."""
    bits = []
    if bv.get("avg_close_days") is not None: bits.append(f"avg close {bv['avg_close_days']}d")
    if bv.get("closed_30d") is not None: bits.append(f"{bv['closed_30d']}/30d")
    if bv.get("cycles") is not None:
        bits.append(f"{bv['cycles']} cycle" + ("" if bv["cycles"] == 1 else "s"))
    return [c(MUT, clip(" · ".join(bits), iw))] if bits else []


def build_frame(M, width, color_on, state, secs_left=None, footer=None, height=None):
    w = max(36, min(120, width))
    wide = w >= 80
    lw, rw = (w - 2) // 2, w - 2 - (w - 2) // 2     # the 2-column grid's card widths
    now = resolve_now(M)
    c = colorer(color_on)

    # ── header: name · branch ✓ clean · HH:MM … ↻ Ns, then the verdict banner ───────────
    st = (M.get("verdict") or {}).get("state", "UNKNOWN")
    reasons = (M.get("verdict") or {}).get("reasons") or []
    tel = tel_of(M)
    text = st
    for r in reasons:
        cand = text + " · " + r
        if len(cand) + 2 > w: break
        text = cand
    bar_text = clip(f" {text} ", w)
    header_lines = [build_header(M.get("name", "?"), now, w, secs_left, color_on,
                                 git=(tel or {}).get("git")),
                    c(f"7;{STATE_COLOR.get(st, RED)}", bar_text + " " * (w - len(bar_text)))]

    # ── ON YOU — one row per plan within a grouped plan move; `cap` shrinks under a height limit
    moves = expand_moves(M.get("moves") or [])
    plan_mtime = {p["name"]: p["mtime"] for p in (M.get("plans") or [])}
    clear = len(moves) == 1 and moves[0].get("rung") == "none"

    # ── EPICS ───────────────────────────────────────────────────────────────────────────
    items = (M.get("epics") or {}).get("items") or []
    open_eps = [e for e in items if not e.get("closed_at")]
    done_sum = sum(e["done"] for e in open_eps if e.get("done") is not None)
    total_sum = sum(e["total"] for e in open_eps if e.get("total") is not None)
    closed7 = M.get("closed7")
    epics_badge = f"{done_sum}/{total_sum}  " + (f"{spark(closed7)} {sum(closed7)}/7d" if closed7 else "?/7d")
    has_agent = lambda e: bool(e.get("holding")) or e.get("unclaimed_stale")
    next_eps = sorted([e for e in open_eps if not (e.get("done") or 0) and not has_agent(e)],
                       key=lambda e: (e["priority"] if e.get("priority") is not None else 999,
                                      e.get("created_at") or ""))[:2]
    next_ids = {e["id"] for e in next_eps}
    open_rows = sorted([e for e in open_eps if e["id"] not in next_ids],
                        key=lambda e: (e["done"] / e["total"]) if e.get("total") else 0)
    prog_rows = [("○", e) for e in next_eps] + [("▶", e) for e in open_rows]
    mrc = M.get("most_recent_closed_epic")

    # ── PLANS / BEADS — the flow, one tracked gauge per stage ───────────────────────────
    plans, pool = M.get("plans") or [], M.get("pool") or 0
    FLOW = ("draft", "approved", "polished", "refined", "bead-ready")
    known = set(FLOW) | {"beadified"}
    counts = {s: sum(1 for p in plans if p["stage"] == s) for s in FLOW}
    plan_rows = [("proposals", pool)]
    for s in FLOW:
        if counts[s] or s in ("draft", "approved", "bead-ready"): plan_rows.append((s, counts[s]))
    other_n = sum(1 for p in plans if p["stage"] not in known)
    if other_n: plan_rows.append(("other", other_n))
    B = M.get("beads")
    beads_rows = None
    if B:
        b_ref = B.get("blocked_refined") or 0
        b_unref = max(0, B["n_blocked"] - b_ref) if B.get("blocked_by") is not None else 0
        beads_rows = [("unrefined", B["n_unrefined"] + b_unref, b_unref),
                      ("refined", B["n_ready"] + b_ref, b_ref),
                      ("building", B["n_in_progress"], 0)]

    # ── the step ribbon: where the line is, and which stage is the bottleneck ───────────
    n_plan = sum(counts[s] for s in ("draft", "approved", "polished", "refined"))
    stages = [("pool", pool, BLUE), ("plan", n_plan, GREEN), ("bead-ready", counts["bead-ready"], CYAN),
              ("ready", (B or {}).get("n_ready") or 0, BLUE), ("building", (B or {}).get("n_in_progress") or 0, GREEN)]

    def stepper_line():
        # the bottleneck, downstream first: building → ready → bead-ready → plan → pool
        act = next((i for i in (4, 3, 2, 1, 0) if stages[i][1]), None)
        keep = [True] * len(stages)
        plain = lambda: [f"[ ▶ {l} {n} ]" if i == act else f"{l} {n}"
                         for i, (l, n, _) in enumerate(stages) if keep[i]]
        # drop the empty stages first, then the rest left to right — never the bottleneck itself
        order = ([i for i in range(len(stages)) if i != act and not stages[i][1]]
                 + [i for i in range(len(stages)) if i != act and stages[i][1]])
        for i in order:
            if sum(len(p) for p in plain()) + 3 * max(0, len(plain()) - 1) <= w: break
            keep[i] = False
        if sum(len(p) for p in plain()) + 3 * max(0, len(plain()) - 1) > w:
            return c(MUT, clip(" · ".join(plain()), w))
        return c(BORD, " · ").join(
            c(f"1;7;{stages[i][2]}", f"[ ▶ {stages[i][0]} {stages[i][1]} ]") if i == act
            else c(stages[i][2] if stages[i][1] else MUT, f"{stages[i][0]} {stages[i][1]}")
            for i in range(len(stages)) if keep[i])

    # ── AGENTS & HEALTH — live agents, then the health summary, then what is wrong ──────
    agents, prs = M.get("agents"), M.get("prs")
    waves = M.get("waves")
    if agents is None:
        machine_parts = ["agents: ?"]
    else:
        live = [a for a in agents if a.get("live")]
        machine_parts = [f"agents: {len(live)} live"]
        if live: machine_parts.append(f"{sum(1 for a in live if a.get('holds'))} working")
    machine_parts.append(f"waves: {waves if waves is not None else '?'}")
    t = M.get("tidy") or {}
    machine_parts.append("tidy: " + (
        ("ready to apply" if (t.get("streak") or 0) >= 7 else f"{t.get('streak')}/7 agree")
        if t.get("status") == "ok" else "?" if t.get("status") == "error" else "missing"))
    red = [p for p in prs if p["ci"].startswith("CI ✗")] if prs is not None else []
    problems = [f"PR #{red[0]['number']} red"] if red else []
    ci = M.get("ci")
    ci_bad = ci is None or "✗" in (ci or "")
    ci_piece = (f"⚠ CI {ci or '?'}") if ci_bad else ("CI —" if ci == "none scheduled" else "✓ CI")
    if ci_bad: problems.append(f"CI {ci or '?'}")
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
    ok = not problems and not checks_bad
    health_parts = [ci_piece, f"PRs: {len(prs) if prs is not None else '?'} open",
                    f"checks {'✓' if not checks_bad else '⚠'}"]

    # ── telemetry-derived strips: the harness legend bar, and the activity tail ─────────
    legend = (legend_line(tel, agents, len(tel.get("reservations") or []), c, w)
              if tel else None)
    activity = (tel.get("activity") or [])[:4] if tel else []

    # ── the cards, each rebuilt at the width its layout gives it ────────────────────────
    def onyou_card(cw, cap):
        iw = cw - 4
        if clear:
            return box("ON YOU", [c(GREEN, "✓ clear") + c(MUT, "  nothing needs you")],
                       cw, c, accent=GREEN)
        body = [on_you_row(mv, iw, now, c, plan_mtime) for mv in moves[:max(0, cap)]]
        if len(moves) > cap: body.append(c(MUT, f"+ {len(moves) - max(0, cap)} more"))
        return box("ON YOU", body, cw, c, right=str(len(moves)), double=True, accent=AMBER)

    def epics_card(cw):
        iw = cw - 4
        body = progress_rows(prog_rows, iw, c) if prog_rows else []
        if mrc: body.append(closed_row(mrc, iw, now, c))
        if not body: body = [c(MUT, "none open")]
        if tel and tel.get("bv"): body += velocity_line(tel["bv"], iw, c)
        if hdr_fill(cw, "EPICS", epics_badge) < 1:      # no room in the header: it becomes a row
            return box("EPICS", [c(MUT, clip(epics_badge, iw))] + body, cw, c, accent=CYAN)
        return box("EPICS", body, cw, c, right=epics_badge, accent=CYAN)

    def plans_card(cw):
        iw = cw - 4
        body = pipeline_rows(plan_rows, iw, "plans", state, now, c, BLUE)
        return box("PLANS", body or [c(MUT, "none")], cw, c,
                   right=f"{sum(n for _, n in plan_rows)} live", accent=GREEN)

    def beads_card(cw):
        iw = cw - 4
        if beads_rows is None:
            return box("BEADS", [c(MUT, "? the bead reads failed")], cw, c, accent=BLUE)
        badge = f"{sum(n for _, n, _ in beads_rows)} open" + \
            (f" · {B['n_deferred']} deferred" if B.get("n_deferred") else "")
        body = pipeline_rows(beads_rows, iw, "beads", state, now, c,
                             lambda label: GREEN if label == "building" else BLUE)
        if tel and tel.get("bv"): body += bv_lines(tel["bv"], iw, c)
        return box("BEADS", body, cw, c, right=badge, accent=BLUE)

    def health_card(cw, detail):
        iw = cw - 4
        body = []
        if detail and agents:
            for a in [x for x in agents if x.get("live")][:3]:
                nm = a.get("name") or "?"
                holds = a.get("holds") or "idle"
                model = (a.get("model") or "").split("/")[-1]
                # the program only when the model does not already say it (`claude` + `claude-opus-5-5`)
                prog = a.get("program") or ""
                prog = f" [{prog}]" if prog and not model.startswith(prog) else ""
                body.append(c(GREEN, "● ") + clip(f"{nm}  {holds}" + (f"  {model}" if model else "")
                                                  + prog, iw - 2))
        locks = (tel or {}).get("reservations") or []
        if detail and locks:
            for r in locks[:3]:
                body.append(c(AMBER, "⊞ ") + c(MUT, pack_badge(
                    clip(r.get("holder") or "?", 16) + "  "
                    + clip_path(r.get("path"), max(8, iw - 26)),
                    age(r.get("created_at"), now), iw - 2)))
            if len(locks) > 3:
                body.append(c(MUT, clip(f"⊞ +{len(locks) - 3} more lock"
                                        + ("" if len(locks) == 4 else "s"), iw)))
        body += [c(MUT, clip(l, iw)) for l in pack_parts(machine_parts, iw)]
        body += [c(GREEN if ok else AMBER, clip(l, iw)) for l in pack_parts(health_parts, iw)]
        if detail:
            body += [c(AMBER, clip(f"⚠ {x}", iw)) for x in problems + checks_bad]
        return box("AGENTS & HEALTH", body, cw, c, accent=AMBER)

    # ── assemble, then trim to --height: footer → health detail → ribbon → ON YOU cap ───
    if footer is None: footer_lines = []
    elif isinstance(footer, str): footer_lines = ["", c(MUT, clip(footer, w))]
    else: footer_lines = ["", footer_pills(footer, w, color_on)]

    def assemble(cap, detail, deco, foot):
        out = list(header_lines)
        if deco and legend: out.append(legend)
        if deco: out.append(stepper_line())
        out.append("")
        sess_on = bool(tel and (tel.get("harnesses") or (tel.get("tools_24h") or {}).get("total")))
        if wide:
            out += join_h(onyou_card(lw, cap), epics_card(rw), c)
            out += join_h(plans_card(lw), beads_card(rw), c)
            out.append("")
            out += (join_h(sessions_card(lw, tel, c), health_card(rw, detail), c)
                    if sess_on and detail else health_card(w, detail))
        else:
            cards = [onyou_card(w, cap), epics_card(w), plans_card(w), beads_card(w)]
            if sess_on and detail: cards.append(sessions_card(w, tel, c))
            cards.append(health_card(w, detail))
            for i, card in enumerate(cards):
                if i: out.append("")
                out += card
        if detail and activity:
            out.append("")
            out += activity_card(w, activity, c)
        return out + (footer_lines if foot else [])

    lines = assemble(8, True, True, True)
    if height is not None:
        if len(lines) > height: lines = assemble(8, True, True, False)
        if len(lines) > height: lines = assemble(8, False, True, False)
        if len(lines) > height: lines = assemble(8, False, False, False)
        cap = 8
        while len(lines) > height and cap > 0:
            cap -= 1
            lines = assemble(cap, False, False, False)
    return lines


# ── footer: every other beads repo this machine deploys to, as `name [state]` pills ─────
def abbr(path):
    n = os.path.basename(path.rstrip("/"))
    if n.endswith("-app"): n = n[:-4]
    return "".join(p[0] for p in n.split("-") if p) or n[:3]


def footer_pills(items, w, color_on):
    """Each sibling repo as `name [state]`, the state's own colour on the whole pill. Full
    names first; `abbr [state]` and finally dropping whole repos keep it inside `w`."""
    c = colorer(color_on)
    paint = lambda rows: "  ".join(c(col, f"{nm} [{st}]") for nm, st, col in rows)

    def rows_of(long):
        out = []
        for p, state in items:
            st, col = REPO_STATE.get(state, ("unknown", RED))
            out.append(((os.path.basename(p.rstrip("/")).removesuffix("-app") or p)
                        if long else abbr(p), st, col))
        return out
    rows = rows_of(True)
    if vlen(paint(rows)) > w: rows = rows_of(False)
    dropped = 0
    while rows and vlen(paint(rows)) + (4 if dropped else 0) > w:
        rows.pop(); dropped += 1
    return paint(rows) + (c(MUT, f"  +{dropped}") if dropped else "")


def fetch_footer(cache):
    """`[(path, state)]` for the sibling repos — the path list once, the states every 60s."""
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
                return p, json.loads(r.stdout).get("verdict", {}).get("state", "UNKNOWN")
            except (subprocess.TimeoutExpired, ValueError):
                return p, "UNKNOWN"
        with ThreadPoolExecutor(max_workers=8) as ex:
            cache["items"] = list(ex.map(one, cache["paths"])) if cache["paths"] else []
        cache["at"] = now
    return cache.get("items", [])


def fetch_model(compact=False):
    try:
        out = subprocess.run([BOARD, "--json"] + (["--compact"] if compact else []),
                              capture_output=True, text=True, timeout=45)
    except subprocess.TimeoutExpired:
        return None
    try: return json.loads(out.stdout)
    except ValueError: return None


def live_loop(secs):
    secs = int(secs)
    os.environ["AC_BOARD_SECS"] = str(secs)   # inherited by the self-exec above, so reload keeps it
    color_on = os.environ.get("NO_COLOR") is None
    state, foot_cache = {}, {}
    resize = {"go": False}
    signal.signal(signal.SIGWINCH, lambda *_: resize.__setitem__("go", True))
    sys.stdout.write("\033[?1049h\033[?25l"); sys.stdout.flush()  # alt screen, hide cursor

    def restore(*_):
        sys.stdout.write("\033[?25h\033[?1049l"); sys.stdout.flush(); sys.exit(0)
    signal.signal(signal.SIGINT, restore); signal.signal(signal.SIGTERM, restore)

    def self_mtime():
        try: return os.path.getmtime(__file__)
        except OSError: return None
    mtime = self_mtime()

    def maybe_reload():
        """This file was edited (or the commit landed) under us: hand the terminal back and
        exec the new code — a watcher must never keep rendering from a stale parser. The
        refresh interval rides in the environment, so argv here stays a constant list."""
        now_m = self_mtime()
        if now_m is None or now_m == mtime: return
        sys.stdout.write("\033[?25h\033[?1049l"); sys.stdout.flush()
        os.execv(sys.executable, [sys.executable, __file__])

    last_M = None

    def full_redraw(draw, cols, left, footer):
        frame = ("\n".join(build_frame(draw, cols, color_on, state, secs_left=left, footer=footer))
                  if draw else "board: waiting for a read…")
        sys.stdout.write("\033[H\033[J" + frame + "\n"); sys.stdout.flush()

    try:
        while True:
            maybe_reload()
            M = fetch_model()
            if M is not None: last_M = M
            draw = last_M
            cols = shutil.get_terminal_size((80, 24)).columns
            footer = fetch_footer(foot_cache) if draw else []
            header_now = resolve_now(draw) if draw else dt.datetime.now(dt.timezone.utc)
            name = draw.get("name", "?") if draw else "board"
            full_redraw(draw, cols, secs, footer)
            # between fetches, rewrite only line 1 — the ticking countdown is the alive signal
            for left in range(secs - 1, -1, -1):
                time.sleep(1)
                maybe_reload()
                if resize["go"]:
                    resize["go"] = False
                    cols = shutil.get_terminal_size((80, 24)).columns
                    full_redraw(draw, cols, left, footer)
                    continue
                if draw:
                    hdr = build_header(name, header_now, max(36, min(120, cols)), left, color_on,
                                       git=(tel_of(draw) or {}).get("git"))
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
    secs = int(argv[0]) if argv and argv[0].lstrip("-").isdigit() else \
        int(os.environ["AC_BOARD_SECS"]) if os.environ.get("AC_BOARD_SECS", "").isdigit() else 15
    live_loop(secs)


if __name__ == "__main__":
    main()
