#!/usr/bin/env python3
"""seams-merge.py — the MERGE step of `ac-polish seams`: union the readers' MAPS, derive the seams.

THREE LENSES ON ONE TARGET, ONE ARTIFACT, ONE DIGEST. A resolved target is an OBJECT; its edges
in time order are FLOWS; the interfaces those edges cross are BOUNDARIES. Each round one reader
per lens traces its subject and returns a map; this script unions each map with its own exact
key, writes all three below the marker, and derives the seams — per lens, then ACROSS lenses
by shared path, which rank first. The digest moves iff an edge is added or dropped in any map,
so polish-fixpoint.sh stamps exactly when a round of readers adds nothing to any of them.

  lens      subject                  key                       derived seams
  object    the datum, 7 stages      stage × path              hole · competing writers · unasserted edge
  flow      a process, its steps     flow × path               step with no sensor · failure not handled
  boundary  an interface, 2 sides    interface × side × path   assumption nothing asserts · half-mapped boundary

The flow map's steps and sensors are emitted at hand-off as the acceptance JOURNEY, so the plan
ships with the scenario that proves its fix. Reader diagnoses (judgement) merge on the paths
they cite and are ordered by reader count — salience, never a gate.

THE DIGEST SURFACE. Between rounds the artifact carries the COVERAGE GRID (file × lens:
rows | —), not the maps; the maps go to <state>/maps.md (the readers' <MAPS>) and the ledger.
So the gate's digest moves when a lens reaches a new file or the fence widens, and does NOT
move when a reader relabels a line in a file already covered — readers split on stage taxonomy
and do not cite stable lines, so keys cannot be the stop condition; coverage can. Per lens, two
consecutive clean rounds FREEZE the lens (round line `frozen=`): the orchestrator stops
spawning its reader; a widened fence unfreezes all. Hand-off writes the full maps back.

THE FENCE. The artifact's frontmatter lines `object:` · `flows:` · `boundaries:` · `files:` bound
each lens. `files:` is the closed set the readers sweep — the source files that name an object
term as a whole word, computed once before round 1 by `aim.sh files --terms` (which drops tests,
dev harnesses and the declaring type file) — and EVERY lens's row must sit in it; a flow or
boundary row must also share a word with a declared flow or interface name. Without a `files:`
line the older rule applies: an object row counts if its file names a term (`table.column`
needs both — aim.sh's toucher rule) and the far side of a boundary is never fenced. Rows outside
are dropped with the reason and never count as new edges, so a value copied into another store
cannot turn a column into a domain. A placeholder in a fence line, or an object term holding a
path, is NOT-GATED. Widening = add a term, recompute `files:`; the next round re-admits.

ASSURANCE (skills/ac-pipeline/references/assurance-declarations.md § The four fields):
  PROBE:      skills/ac-polish/scripts/seams-merge.test.py — RED/GREEN over every rule above
  SCHEDULE:   once per seams round (workflows/seams.md § MERGE) and once at hand-off; once
              per load round and at load-hand-off (workflows/load.md); and on every CI run
              via scripts/run-all-harnesses.sh
  MODE:       blocking — the artifact is written only by this script during a seams run
  ON-FAILURE: closed — a report that does not parse exits 2 NOT-GATED and writes nothing;
              a stale map exits 1 STALE before anything is read

Usage:
  seams-merge.py round   --state DIR --artifact PLAN --round N [--repo DIR] [--validate] REPORT...
  seams-merge.py handoff --state DIR --artifact PLAN [--keep _docs/seams/<object> --repo DIR]
    --keep writes the KEPT ASSET beside the plan's lifecycle: map.json (ledger + fence +
    traced_at + seams_load — the source of truth) and map.html rendered from it by
    seams-render.py (the N² grid with empty cells visible, flow steps with sensors, the
    boundary table). aim.sh status reads traced_at to announce drift.

  seams-merge.py load         --map MAP.JSON --state DIR --round N [--repo DIR] --validate REPORT
  seams-merge.py load-handoff --map MAP.JSON --state DIR
    The MERGE step of `ac-polish load` (workflows/load.md): three loads — time · trust ·
    money — on every edge of a KEPT seams map. The map is the fence: no new edges, ever.
    `load` reads the reader report (one `| edge | time | trust | money |` table whose edge
    column quotes the map's edge keys VERBATIM), runs the STALE GUARD first (any commit since
    the map's traced_at touching its files ends the run — re-run seams first), then validates
    every `measured` cell by re-running its oracle from the repo root; a nonzero exit or an
    empty output DROPS the cell, never silently. The fixpoint keys on (edge key, load) → cell
    content in <state>/load-ledger.json; a round that changed no cell and dropped none stamps
    via polish-fixpoint.sh --mode load on <state>/load.md. `load-handoff` copies the
    converged load.md beside the map and writes the counts into map.json as a `load` key
    beside seams_load — replaced, never appended.

Reader REPORT (one per reader; the file stem is the reader id):
  LENS: object | flow | boundary
  TARGET RESOLVED TO: ...
  MAP:        object   | stage | path:line | role | upstream | downstream | contract | found-by |
              flow     | flow | step | path:line | controller | sensor | on-failure | found-by |
              boundary | interface | side | path:line | producer | assumes | asserts | found-by |
              (producer: internal | user | external | tenant — classification, not a threat model)
  DIAGNOSIS:  | pattern | edges | what breaks silently | found-by |
Exit 0 ok · 2 NOT-GATED.
"""
import argparse
import json
import os
import re
import subprocess
import sys

MARKER = "<!-- seams-merge: everything below this line is generated -->"
STAGES = ["create", "transport", "store", "read", "update", "delete", "cleanup"]
CORE = {"create", "store", "read", "update", "delete", "cleanup"}
MUTATING = {"create", "update", "delete"}
LENSES = {
    "object":   {"cols": ["stage", "path:line", "role", "upstream", "downstream", "contract", "found-by"], "path_col": 1},
    "flow":     {"cols": ["flow", "step", "path:line", "controller", "sensor", "on-failure", "found-by"], "path_col": 2},
    "boundary": {"cols": ["interface", "side", "path:line", "producer", "assumes", "asserts", "found-by"], "path_col": 2},
}
DIAG_COLS = 4
PATH_RE = re.compile(r"[A-Za-z0-9_@\-\[\]().]+(?:/[A-Za-z0-9_@\-\[\]().]+)+\.[A-Za-z0-9]{1,6}")
FENCE_KEYS = {"object": "object", "flow": "flows", "boundary": "boundaries", "files": "files"}
WORD = r"[A-Za-z0-9_]"


def die2(msg):
    print(f"seams-merge: NOT-GATED {msg}", file=sys.stderr)
    sys.exit(2)


NONE_WORDS = {"none", "", "-", "—", "n/a", "no", "nothing", "unasserted", "untested", "unchecked", "unvalidated"}
UNHANDLED_WORDS = {"none", "swallow", "swallowed", "ignored", "ignore", "no", "nothing", "logged-only", "log-only"}


def first_word(cell):
    """The verdict word of a cell. Readers write `none on write — plain setItem inside try/catch`
    and `swallow — outer .catch logs only`: the fact is the first word, the rest is evidence.
    The images dogfood (2026-09-03) had 15 unasserted edges, 5 unsensed steps, 16 swallowed
    failures and 25 unchecked boundaries that an exact-match `none` counted as zero."""
    c = re.sub(r"^[`*\s]+", "", cell.strip()).lower()
    return re.split(r"[\s—–:(,;/]+", c)[0] if c else ""


def none_ish(cell):
    return first_word(cell) in NONE_WORDS


def unhandled(cell):
    w = first_word(cell)
    return w in UNHANDLED_WORDS or w.startswith("swallow")


def slug(cell):
    return re.sub(r"\s+", " ", cell.strip().strip("`* ").lower())


# ---------------------------------------------------------------- parsing
def split_row(line):
    line = line.strip()
    if not (line.startswith("|") and line.endswith("|")):
        return None
    inner = line[1:-1].replace("\\|", "\x00")
    return [c.replace("\x00", "\\|").strip() for c in inner.split("|")]


def is_separator(cells):
    return all(re.fullmatch(r":?-{2,}:?", c) for c in cells)


def norm_path(cell):
    m = PATH_RE.search(cell)
    return m.group(0).strip("`'\"") if m else None


def parse_report(path):
    try:
        text = open(path, encoding="utf-8").read()
    except OSError as e:
        die2(f"cannot read report {path}: {e}")
    out = {"reader": os.path.splitext(os.path.basename(path))[0], "lens": None, "resolved": "", "map": [], "diag": []}
    section, header_seen = None, False
    for raw in text.splitlines():
        s = raw.strip().strip("*").strip()
        low = s.lower()
        if low.startswith("lens:"):
            out["lens"] = slug(s.split(":", 1)[1])
            if out["lens"] not in LENSES:
                die2(f"{path}: LENS must be object, flow or boundary (got '{out['lens']}')")
            continue
        if low.startswith("target resolved to:"):
            out["resolved"] = s.split(":", 1)[1].strip(); continue
        if low.startswith("map:"):
            section, header_seen = "map", False; continue
        if low.startswith("diagnosis:"):
            section, header_seen = "diag", False; continue
        cells = split_row(raw)
        if cells is None or section is None or is_separator(cells):
            continue
        if section == "map":
            if out["lens"] is None:
                die2(f"{path}: MAP before LENS: — the lens must be declared first")
            spec = LENSES[out["lens"]]; want = len(spec["cols"])
        else:
            spec = None; want = DIAG_COLS
        if not header_seen:
            header_seen = True
            if len(cells) != want:
                die2(f"{path}: {section.upper()} table has {len(cells)} columns, expected {want} for lens {out['lens']}")
            continue
        if len(cells) != want:
            die2(f"{path}: {section.upper()} row has {len(cells)} cells, expected {want}: {raw[:80]}")
        if section == "map":
            row = dict(zip(spec["cols"], cells))
            p = norm_path(cells[spec["path_col"]])
            if not p:
                die2(f"{path}: MAP row names no path: {raw[:80]}")
            row["path"] = p
            if out["lens"] == "object":
                row["stage"] = slug(row["stage"])
                if row["stage"] not in STAGES:
                    die2(f"{path}: unknown stage '{row['stage']}' — stages are {' · '.join(STAGES)}")
                row["key"] = f"{row['stage']} × {p}"
            elif out["lens"] == "flow":
                row["key"] = f"{slug(row['flow'])} × {p}"
            else:
                row["key"] = f"{slug(row['interface'])} × {slug(row['side'])} × {p}"
            out["map"].append(row)
        else:
            pattern, edges, silent, found_by = cells
            if pattern.strip().upper() == "NONE":
                continue
            out["diag"].append({"pattern": pattern, "edges": edges, "silent": silent, "found_by": found_by})
    if out["lens"] is None:
        die2(f"{path}: no LENS: line — not a trace report")
    if section is None:
        die2(f"{path}: no MAP: section — not a trace report")
    return out


# ---------------------------------------------------------------- fence
def frontmatter(artifact):
    try:
        with open(artifact, encoding="utf-8") as f:
            text = f.read()
    except OSError as e:
        die2(f"artifact unreadable: {e}")
    if not text.startswith("---\n") or "\n---" not in text[4:]:
        return {}
    out = {}
    for line in text[4:].split("\n---", 1)[0].split("\n"):
        if ":" in line and not line.startswith((" ", "\t")):
            k, v = line.split(":", 1)
            out[k.strip()] = v.strip()
    return out


def parse_fence(fm):
    """One ` · `-separated term list per lens, from the artifact's frontmatter. An absent key
    leaves that lens unfenced; an empty value or a template placeholder is NOT-GATED."""
    fence = {}
    for lens, key in FENCE_KEYS.items():
        if key not in fm:
            continue
        v = fm[key]
        terms = [t.strip().strip("`") for t in re.split(r"\s(?:·|—)\s", v) if t.strip()]
        if not terms or re.search(r"<[^>]*>", v):
            die2(f"fence `{key}:` in the artifact frontmatter is empty or a placeholder — resolve the target "
                 "(workflows/seams.md § TARGET) before round 1")
        if lens == "object" and any("/" in x for x in terms):
            die2("fence `object:` holds a path — object terms are symbols only; the file list is the `files:` line "
                 "(aim.sh files --terms)")
        fence[lens] = set(terms) if lens == "files" else terms
    return fence


def names(text, term):
    return re.search(rf"(?<!{WORD}){re.escape(term)}(?!{WORD})", text) is not None


def tokens(cell):
    return {w for w in re.findall(r"[a-z0-9_]+", cell.lower()) if len(w) >= 3}


def outside_fence(lens, row, fence, repo, cache):
    """None when the row is inside its lens's fence, else the reason. With a `files:` line every
    lens's row must be in that set; flow · boundary rows must also share a word with a declared
    name. Without one: object rows must be in a file naming a term as a whole word (a
    `table.column` term needs both), flow · boundary rows only share a word — the far side's
    file is not checked."""
    files = fence.get("files")
    if files is not None and row["path"] not in files:
        return f"`{row['path']}` is not on the files: line"
    terms = fence.get(lens)
    if terms is None:
        return None
    if lens == "object":
        if files is not None:
            return None
        p = row["path"]
        if p not in cache:
            try:
                with open(os.path.join(repo, p), encoding="utf-8", errors="replace") as f:
                    cache[p] = f.read()
            except OSError:
                cache[p] = None
        text = cache[p]
        if text is None:
            return f"`{p}` is not readable under the repo"
        for t in terms:
            if all(names(text, part) for part in t.split(".")):
                return None
        return f"`{p}` names none of: " + " · ".join(terms)
    cell = row["flow"] if lens == "flow" else row["interface"]
    words = tokens(cell)
    for t in terms:
        if words & tokens(t):
            return None
    return f"`{cell}` shares no word with: " + " · ".join(terms)


# ---------------------------------------------------------------- state
def load_state(state_dir, must_exist):
    p = os.path.join(state_dir, "ledger.json")
    if not os.path.exists(p):
        if must_exist:
            die2(f"no ledger at {p} — run `round` first")
        return {"rounds": 0, "readers": {}, "edges": {l: {} for l in LENSES}, "diag": {}}
    try:
        return json.load(open(p, encoding="utf-8"))
    except (OSError, ValueError) as e:
        die2(f"ledger unreadable: {e}")


def save_state(state_dir, st):
    os.makedirs(state_dir, exist_ok=True)
    tmp = os.path.join(state_dir, "ledger.json.tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(st, f, indent=1, sort_keys=True)
    os.replace(tmp, os.path.join(state_dir, "ledger.json"))


# ---------------------------------------------------------------- validate
def run_found_by(found_by, repo):
    """Commands joined by ' · '. One fails iff it exits non-zero AND prints nothing. The row is
    dropped iff EVERY command fails."""
    cmds = [c.strip().strip("`").strip() for c in re.split(r"\s·\s", found_by) if c.strip()]
    results = []
    for c in cmds:
        c = c.replace("\\|", "|")
        try:
            r = subprocess.run(["bash", "-c", c], cwd=repo, capture_output=True, text=True, timeout=60)
            results.append({"command": c, "exit": r.returncode, "ok": r.returncode == 0 or bool(r.stdout.strip())})
        except subprocess.TimeoutExpired:
            results.append({"command": c, "exit": None, "ok": False})
    return results, (bool(results) and not any(x["ok"] for x in results))


# ---------------------------------------------------------------- artifact
def write_below_marker(artifact, body):
    try:
        text = open(artifact, encoding="utf-8").read()
    except OSError as e:
        die2(f"artifact unreadable: {e}")
    if MARKER not in text:
        die2(f"artifact has no marker line `{MARKER}` — create it from references/seams-plan-template.md")
    with open(artifact, "w", encoding="utf-8") as f:
        f.write(text.split(MARKER, 1)[0] + MARKER + "\n\n" + body.rstrip() + "\n")


def table(header, rows):
    out = ["| " + " | ".join(header) + " |", "|" + "---|" * len(header)]
    out += ["| " + " | ".join(r) + " |" for r in rows]
    return "\n".join(out)


def live(st, lens):
    return [e for e in st["edges"][lens].values() if not e["dropped"]]


def ordered(lens, edges):
    if lens == "object":
        return sorted(edges, key=lambda e: (STAGES.index(e["stage"]), e["path"]))
    return sorted(edges, key=lambda e: (e["first_round"], e["seq"]))


def rows_of(lens, edges, best=False):
    cols = LENSES[lens]["cols"]
    out = []
    for e in ordered(lens, edges):
        r = [e.get(c, "") for c in cols]   # a ledger written before a column existed still reads
        if lens == "object" and not best:
            r[5] = e.get("contract_first", e["contract"])
        out.append(r)
    return out


def map_body(st, best=False):
    parts = []
    for lens in LENSES:
        edges = live(st, lens)
        parts.append(f"### {lens} map — {len(edges)} edges\n\n" + table(LENSES[lens]["cols"], rows_of(lens, edges, best)))
    return "\n\n".join(parts)


# ---------------------------------------------------------------- derivation
def derive(st):
    """Returns list of (lens, pattern, where, silent, paths)."""
    out = []
    obj = live(st, "object")
    by_stage = {}
    for e in obj:
        by_stage.setdefault(e["stage"], []).append(e)
    for s in STAGES:
        if s in CORE and not by_stage.get(s):
            out.append(("object", "hole", f"stage `{s}` has no row", "nobody does this to the object", set()))
    for s in MUTATING:
        paths = sorted({e["path"] for e in by_stage.get(s, [])})
        if len(paths) >= 2:
            out.append(("object", "competing writers", f"`{s}`: " + " · ".join(f"`{p}`" for p in paths),
                        "no shared owner — last write wins, nothing asserts the shape", set(paths)))
    for e in ordered("object", obj):
        if none_ish(e["contract"]):
            out.append(("object", "unasserted edge", f"`{e['stage']}` · `{e['path:line']}`", "drift on this edge is silent — no type, assertion or test names it", {e["path"]}))
    for e in ordered("flow", live(st, "flow")):
        if none_ish(e["sensor"]):
            out.append(("flow", "step with no sensor", f"`{e['flow']}` · {e['step']} · `{e['path:line']}`", "the controller cannot tell whether this step happened", {e["path"]}))
        if unhandled(e["on-failure"]):
            out.append(("flow", "failure not handled", f"`{e['flow']}` · {e['step']} · `{e['path:line']}`", "a failure here leaves the process half-done with no compensation and no signal", {e["path"]}))
    bnd = live(st, "boundary")
    sides = {}
    for e in bnd:
        # side vocabulary: `both sides: gc byte-equality` counts as both; `consumer (evictor)` is a
        # consumer. Free text after the first word is evidence, not a new side.
        sw = first_word(e["side"])
        sides.setdefault(slug(e["interface"]), set()).update({"a", "b"} if sw.startswith("both") else {sw})
        if not none_ish(e["assumes"]) and none_ish(e["asserts"]):
            out.append(("boundary", "assumption nothing asserts", f"`{e['interface']}` · {e['side']} · `{e['path:line']}`", f"assumes {e['assumes']} — a change on the other side compiles and ships clean", {e["path"]}))
        # producer: internal | user | external | tenant — classification from the code, not a threat
        # model. Anything not internal with nothing asserting is the single highest-value security seam.
        if slug(e.get("producer", "")) not in ("internal", "") and not none_ish(e.get("producer", "")) and none_ish(e["asserts"]):
            out.append(("boundary", "untrusted input nothing validates", f"`{e['interface']}` · {e['side']} · producer {e['producer']} · `{e['path:line']}`", "input from outside the trust boundary reaches this code with no schema, guard or auth check", {e["path"]}))
    for i, ss in sides.items():
        if len(ss) < 2:
            out.append(("boundary", "half-mapped boundary", f"`{i}` — only the {next(iter(ss))} side is on the map", "the other side of this interface was not traced; its assumptions are unknown", set()))
    return out


def cross_lens(derived):
    by_path = {}
    for lens, pattern, where, silent, paths in derived:
        for p in paths:
            by_path.setdefault(p, {}).setdefault(lens, []).append(pattern)
    return sorted(((p, ls) for p, ls in by_path.items() if len(ls) >= 2), key=lambda x: (-len(x[1]), x[0]))


def journey(st):
    flows = {}
    for e in ordered("flow", live(st, "flow")):
        flows.setdefault(e["flow"], []).append(e)
    lines = []
    for name, steps in flows.items():
        lines.append(f"- **{name}**: " + " → ".join(
            f"{e['step']} (sensor: {e['sensor'] if not none_ish(e['sensor']) else 'NONE'})" for e in steps))
    return "\n".join(lines) if lines else "_no flow map — no journey derived_"


# ---------------------------------------------------------------- coverage (the digest surface)
def coverage(st, fence):
    """Per file × lens: does the lens have a live row in it. THIS is what the artifact carries
    between rounds and therefore what the gate's digest measures. A new stage / flow / side in a
    file a lens already touched is a LABEL — it lands in the maps and the ledger, and it does not
    move the stamp. A new file for a lens, or a file added to the fence, does. Readers do not
    cite a stable line for the same edge and split on stage taxonomy at the sub-object level
    (MotionFrame v3: 60 · 7 · 2 · 4 · 1 edges, 0 fenced, every late add in a file already
    mapped), so keys and lines cannot be the stop condition; file coverage can."""
    present = {l: sorted({e["path"] for e in live(st, l)}) for l in LENSES}
    files = sorted(set(fence.get("files") or []) | {p for ps in present.values() for p in ps})
    return files, present


def coverage_table(files, present, fence):
    rows = []
    for f in files:
        cells = ["rows" if f in present[l] else "—" for l in LENSES]
        rows.append([f"`{f}`" + ("" if f in (fence.get("files") or [f]) else " (not on files:)"), *cells])
    return table(["file", *LENSES], rows)


def freeze_update(st, present, files_line, rnd):
    """Per lens: rounds in which its coverage set was unchanged from the round before. A lens
    with TWO consecutive clean rounds (round >= 3) is frozen — the orchestrator stops spawning
    its reader. A change to the files line unfreezes everything (a widened fence is new ground).
    Returns (frozen lenses, lenses whose coverage changed this round)."""
    cov = st.setdefault("coverage", {"by_round": {}, "files_line_by_round": {}, "frozen": []})
    cov["by_round"][str(rnd)] = present
    cov["files_line_by_round"][str(rnd)] = files_line
    prev = cov["by_round"].get(str(rnd - 1))
    changed = [l for l in LENSES if prev is None or prev.get(l) != present[l]]
    widened = rnd > 1 and cov["files_line_by_round"].get(str(rnd - 1)) != files_line
    frozen = []
    if rnd >= 3 and not widened:
        p2 = cov["by_round"].get(str(rnd - 2))
        for l in LENSES:
            if l not in changed and p2 is not None and prev.get(l) == p2.get(l) \
               and cov["files_line_by_round"].get(str(rnd - 2)) == files_line:
                frozen.append(l)
    cov["frozen"] = frozen
    return frozen, changed, widened


# ---------------------------------------------------------------- commands
def cmd_round(a):
    if not a.reports:
        die2("round needs at least one REPORT file")
    st = load_state(a.state, must_exist=False)
    if a.round != st["rounds"] + 1:
        die2(f"--round {a.round} but ledger has {st['rounds']} rounds recorded — rounds are consecutive")
    reports = [parse_report(p) for p in a.reports]
    fence = parse_fence(frontmatter(a.artifact))
    repo = a.repo or os.getcwd()
    new, seen_again, dropped, fenced, cache = [], 0, [], [], {}
    for rep in reports:
        lens = rep["lens"]
        st["readers"][rep["reader"]] = {"round": a.round, "lens": lens, "resolved": rep["resolved"]}
        for seq, row in enumerate(rep["map"]):
            k = row["key"]
            why = outside_fence(lens, row, fence, repo, cache)
            if why:
                st["edges"][lens][k] = dict(row, first_round=a.round, seq=seq, readers=[rep["reader"]],
                                            dropped={"round": a.round, "reason": f"outside fence: {why}"},
                                            contract_disagreement=False)
                fenced.append((lens, k, why))
                continue
            e = st["edges"][lens].get(k)
            if e is None or e["dropped"]:
                e = dict(row, first_round=a.round, seq=seq, readers=[], dropped=None, contract_disagreement=False)
                if lens == "object":
                    e["contract_first"] = row["contract"]
                st["edges"][lens][k] = e
                new.append((lens, k))
            else:
                seen_again += 1
                if lens == "object":
                    if none_ish(e["contract"]) and not none_ish(row["contract"]):
                        e["contract"] = row["contract"]; e["contract_disagreement"] = True
                    elif not none_ish(e["contract"]) and none_ish(row["contract"]):
                        e["contract_disagreement"] = True
            if rep["reader"] not in e["readers"]:
                e["readers"].append(rep["reader"])
        for d in rep["diag"]:
            # Key on the cited PATHS only. Pattern text is free prose and never repeats across
            # readers (images dogfood: 60 diagnoses, 2 merged), so a key that includes it makes
            # the reader count — the salience signal — meaningless. Two readers pointing at the
            # same files are saying the same thing; the first pattern text stands, later ones
            # are kept beside it.
            cited = sorted({p.strip("`'\"") for p in PATH_RE.findall(d["edges"])})
            k = ",".join(cited) if cited else slug(d["pattern"])
            x = st["diag"].get(k)
            if x is None:
                x = dict(d, key=k, lens=lens, first_round=a.round, readers=[], cited=cited, also=[])
                st["diag"][k] = x
            elif slug(d["pattern"]) != slug(x["pattern"]) and slug(d["pattern"]) not in x.get("also", []):
                x.setdefault("also", []).append(slug(d["pattern"]))
            if rep["reader"] not in x["readers"]:
                x["readers"].append(rep["reader"])
    if a.validate:
        for lens, k in new:
            e = st["edges"][lens][k]
            results, fail = run_found_by(e["found-by"], repo)
            e["validated"] = {"round": a.round, "results": results}
            if fail:
                e["dropped"] = {"round": a.round, "reason": "no found-by command reproduced"}
                dropped.append((lens, k))
    st["rounds"] = a.round
    files, present = coverage(st, fence)
    files_line = sorted(fence.get("files") or [])
    frozen, changed, widened = freeze_update(st, present, files_line, a.round)
    save_state(a.state, st)
    maps_path = a.maps or os.path.join(a.state, "maps.md")
    with open(maps_path, "w", encoding="utf-8") as f:
        f.write(f"## Maps — round {a.round} · the readers' input, not the digest surface\n\n{map_body(st)}\n")
    # Nothing round-specific may appear here: this text IS the digest. Round number, frozen set
    # and counts go on the round line and in the ledger, never in the artifact.
    write_below_marker(a.artifact,
        f"## Coverage — the digest surface\n\n"
        f"_One row per file on the fence, one column per lens: `rows` when the lens has a live row in "
        f"that file, `—` when it declared the file absent. The gate stamps when this table is unchanged "
        f"at round ≥ 2 — every file walked by every lens and nothing new found. Stage, flow and side "
        f"labels live in the maps (`{os.path.relpath(maps_path, os.path.dirname(a.artifact))}`) and the "
        f"ledger, where a late relabel is a correction, not growth._\n\n"
        + coverage_table(files, present, fence))
    counts = {l: len(live(st, l)) for l in LENSES}
    derived = derive(st)
    print(f"seams-merge: round={a.round} readers={len(reports)} lenses={','.join(sorted({r['lens'] for r in reports}))} "
          f"new_edges={len(new) - len(dropped)} seen_again={seen_again} dropped={len(dropped)} fenced={len(fenced)} "
          + (f"files={len(fence['files'])} " if fence.get("files") is not None else "") +
          f"fence={','.join(l for l in LENSES if l in fence) or 'none'} "
          f"edges=object:{counts['object']},flow:{counts['flow']},boundary:{counts['boundary']} "
          f"coverage=" + ",".join(f"{l}:{len(present[l])}/{len(files)}" for l in LENSES) + " "
          f"coverage_delta={','.join(changed) or 'none'} frozen={','.join(frozen) or 'none'}"
          + (" widened=yes" if widened else "") + " "
          f"derived_seams={len(derived)} cross_lens={len(cross_lens(derived))}")
    for lens, k in new:
        if (lens, k) not in dropped:
            print(f"  + [{lens}] {k}")
    for lens, k in dropped:
        print(f"  - [{lens}] {k} dropped: no found-by reproduced")
    for lens, k, why in fenced:
        print(f"  ~ [{lens}] {k} fenced: {why}")
    return 0


def cmd_handoff(a):
    st = load_state(a.state, must_exist=True)
    derived = derive(st)
    cross = cross_lens(derived)
    cross_rows = [[f"`{p}`", " · ".join(f"{l}: {', '.join(sorted(set(ps)))}" for l, ps in sorted(ls.items())), str(len(ls))] for p, ls in cross]
    per_lens = [[lens, pattern, where, silent] for lens, pattern, where, silent, _ in derived]
    # Regroup by cited paths at hand-off as well, so a ledger keyed under the old pattern+paths
    # rule (images dogfood: 60 rows, 2 merged) gets the same reader counts as a new one.
    grouped = {}
    for x in st["diag"].values():
        gk = ",".join(x.get("cited") or []) or x["key"]
        g = grouped.get(gk)
        if g is None:
            grouped[gk] = dict(x, readers=list(x["readers"]))
        else:
            g["readers"] = sorted(set(g["readers"]) | set(x["readers"]))
            g["first_round"] = min(g["first_round"], x["first_round"])
    # Order by the MAPS, not by reader count: readers are told to extend, not repeat, so two
    # readers rarely restate a diagnosis (images dogfood: 3 of 54). A diagnosis that cites a
    # file the lenses already flag from several angles is the one to read first.
    lens_hits = {p: len(ls) for p, ls in cross}
    rd = sorted(grouped.values(), key=lambda x: (-max([lens_hits.get(p, 0) for p in x.get("cited") or []] or [0]),
                                                  -len(x["readers"]), x["first_round"], x["key"]))
    rd_rows = [[x["lens"], x["pattern"], x["edges"], x["silent"], x["found-by"] if "found-by" in x else x["found_by"], str(len(x["readers"]))] for x in rd]
    disagreements = [e for e in live(st, "object") if e.get("contract_disagreement")]
    counts = {l: len(live(st, l)) for l in LENSES}
    body = (f"## Maps — object {counts['object']} · flow {counts['flow']} · boundary {counts['boundary']} edges · "
            f"{len(st['readers'])} readers · {st['rounds']} rounds\n\n{map_body(st, best=True)}"
            + f"\n\n## Seams — seen by more than one lens ({len(cross)}) — fix these first\n\n"
            + table(["path", "what each lens sees", "lenses"], cross_rows)
            + f"\n\n## Seams — derived per lens ({len(per_lens)})\n\n"
            + table(["lens", "pattern", "where", "what breaks silently"], per_lens)
            + f"\n\n## Seams — reader diagnosis ({len(rd_rows)}), ordered by how many lenses flag the files it cites\n\n"
            + table(["lens", "pattern", "edges", "what breaks silently", "found-by", "readers"], rd_rows)
            + ("\n\n_Contract disagreements (one reader said none, another named one): "
               + " · ".join(f"`{e['key']}`" for e in disagreements) + "_" if disagreements else "")
            + f"\n\n## Journey — from the flow map, for ac-qa\n\n{journey(st)}"
            + "\n\n## Approach\n\n_Empty by design. `ac-plan` writes it with the human — usually: give this object one owner at each stage the map shows it lacks, and a sensor at each step the flow shows is blind._")
    write_below_marker(a.artifact, body)
    # THE NORTH STAR, as four numbers in the frontmatter: the plan's success criterion is these
    # re-derived after the fix, not a slogan. competing-writers counts mutating stages with >=2
    # paths; the other three count edges. Replaced on re-run, never appended.
    load = (f"competing-writers={sum(1 for l, p, *_ in derived if p == 'competing writers')} "
            f"unasserted-edges={sum(1 for l, p, *_ in derived if p == 'unasserted edge')} "
            f"unsensed-steps={sum(1 for l, p, *_ in derived if p == 'step with no sensor')} "
            f"unchecked-assumptions={sum(1 for l, p, *_ in derived if p == 'assumption nothing asserts')} "
            f"untrusted-inputs={sum(1 for l, p, *_ in derived if p == 'untrusted input nothing validates')} "
            f"holes={sum(1 for l, p, *_ in derived if p == 'hole')} edges={sum(counts.values())} readers={len(st['readers'])} rounds={st['rounds']}")
    text = open(a.artifact, encoding="utf-8").read()
    if text.startswith("---\n"):
        head, rest = text[4:].split("\n---", 1)
        lines = [l for l in head.split("\n") if not l.startswith("seams_load:")]
        lines.append(f"seams_load: {load}")
        with open(a.artifact, "w", encoding="utf-8") as f:
            f.write("---\n" + "\n".join(lines) + "\n---" + rest)
    print(f"seams-merge: handoff edges=object:{counts['object']},flow:{counts['flow']},boundary:{counts['boundary']} "
          f"derived={len(per_lens)} cross_lens={len(cross)} reader_diagnoses={len(rd_rows)} rounds={st['rounds']} readers={len(st['readers'])}")
    print(f"seams-merge: seams_load {load}")
    if a.keep:
        keep_map(a, st, load, cross_rows, disagreements)
    return 0


def keep_map(a, st, load, cross_rows, disagreements):
    """The kept asset — `_docs/seams/<object>/map.json` (the ledger + fence + traced_at + load
    counts; the source of truth) and `map.html` rendered from it by seams-render.py. The maps
    outlive the plan: the next engineer reads the html before a build, and a re-trace diffs the
    json. `traced_at` is the repo HEAD the maps were traced against — aim.sh status reads it."""
    fm = frontmatter(a.artifact)
    fence = parse_fence(fm)
    repo = a.repo or os.getcwd()
    try:
        sha = subprocess.run(["git", "-C", repo, "rev-parse", "HEAD"], capture_output=True, text=True, timeout=30).stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        sha = ""
    if not sha:
        die2("--keep needs the repo HEAD sha for traced_at (git rev-parse failed) — pass --repo")
    terms = fence.get("object") or []
    obj = re.sub(r"[^A-Za-z0-9_.-]+", "-", terms[0]).strip("-") if terms else "object"
    d = {
        "object": obj, "object_terms": terms, "files": sorted(fence.get("files") or []),
        "flows": fence.get("flow") or [], "boundaries": fence.get("boundary") or [],
        "traced_at": sha, "rounds": st["rounds"], "readers": len(st["readers"]),
        "verdict": fm.get("seams_verdict", "") or ("stamped" if fm.get("seams_fixpoint_sha256") else "unstamped"),
        "seams_load": dict(kv.split("=", 1) for kv in load.split()),
        "coverage_note": fm.get("seams_coverage", ""),
        "cross_lens": [[c.strip("`") for c in r] for r in cross_rows],
        "contract_disagreements": [e["key"] for e in disagreements],
        "edges": st["edges"], "diag": st["diag"], "reader_log": st["readers"],
        "coverage": st.get("coverage", {}),
    }
    os.makedirs(a.keep, exist_ok=True)
    jp = os.path.join(a.keep, "map.json")
    with open(jp, "w", encoding="utf-8") as f:
        json.dump(d, f, indent=1, ensure_ascii=False, sort_keys=True)
    render = os.path.join(os.path.dirname(os.path.abspath(__file__)), "seams-render.py")
    r = subprocess.run([sys.executable, render, jp, os.path.join(a.keep, "map.html")], capture_output=True, text=True)
    if r.returncode != 0:
        die2(f"map.json written but render failed: {(r.stderr or r.stdout).strip()[:200]}")
    print(f"seams-merge: kept {jp} · {os.path.join(a.keep, 'map.html')} (traced_at {sha[:12]})")


# ---------------------------------------------------------------- load (workflows/load.md)
LOADS = ["time", "trust", "money"]
CELL_FORMS = {"measured", "n/a", "unmeasured"}
LOAD_HDR = ["edge", "time", "trust", "money"]


def load_form(cell):
    """The form word of a load cell. Like first_word, but `n/a` must survive: the slash is
    part of the form, not a separator."""
    c = re.sub(r"^[`*\s]+", "", cell.strip()).lower()
    return re.split(r"[\s—–]+", c)[0] if c else ""


def load_json_map(path):
    """The kept seams map — the only input a load run takes. No map, no load run."""
    try:
        with open(path, encoding="utf-8") as f:
            d = json.load(f)
    except OSError as e:
        die2(f"cannot read map {path}: {e}")
    except ValueError as e:
        die2(f"map {path} is not valid JSON: {e}")
    if not isinstance(d.get("edges"), dict) or not d.get("edges"):
        die2(f"map {path} has no edges ledger — run seams `handoff --keep` first; load never traces, it fills")
    return d


def live_map_edges(d):
    """The map's live edges, keyed by the exact string the report must quote verbatim. A key
    under two lenses would make that quoting ambiguous — fail loud."""
    edges = {}
    for lens, ks in d.get("edges", {}).items():
        for k, e in ks.items():
            if e.get("dropped"):
                continue
            if k in edges:
                die2(f"map edge key `{k}` exists under two lenses — the load report cannot quote it verbatim")
            edges[k] = dict(e, lens=lens)
    if not edges:
        die2("map has no live edges — nothing for a load run to fill")
    return edges


def stale_guard(d, repo):
    """A load run fills a map that seams validated at traced_at. If any commit since touched a
    fenced file, the map no longer describes the code and every cell would be measured against
    a ghost — re-run seams first. Never proceed on a stale map (workflows/seams.md § Stale
    maps announce themselves)."""
    sha = d.get("traced_at")
    files = d.get("files") or []
    if not sha:
        die2("map.json has no traced_at — run seams `handoff --keep` first; load never proceeds without the sha the map was traced at")
    if not files:
        die2("map.json has no files fence — a load run needs the closed set to check drift against")
    try:
        r = subprocess.run(["git", "-C", repo, "log", "--oneline", f"{sha}..HEAD", "--", *files],
                           capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.TimeoutExpired) as e:
        die2(f"drift check failed: {e}")
    if r.returncode != 0:
        die2(f"drift check failed for traced_at {sha[:12]}: {(r.stderr or r.stdout).strip()[:200]} — pass --repo (the repo the map was traced against)")
    commits = [l for l in r.stdout.splitlines() if l.strip()]
    if commits:
        print(f"seams-merge: STALE — re-run seams first: {len(commits)} commit(s) since traced_at {sha[:12]} "
              f"touched the map's files; a load run never proceeds on a stale map", file=sys.stderr)
        for c in commits:
            print(f"  {c}", file=sys.stderr)
        sys.exit(1)


def oracle_of(cell):
    """The command after `oracle:` — the rest of the cell, stripped of wrapper backticks. One
    command, run verbatim from the repo root; a reader that joins two with ` · ` wrote a
    command that does not exist, and validation drops it like any other."""
    cmd = cell.split("oracle:", 1)[1]
    return cmd.strip().strip("`").strip().replace("\\|", "|")


def run_oracle(cmd, repo):
    """A measured cell's oracle must exit 0 AND print — a command that silently exits clean
    proves nothing was measured. Returns (ok, detail)."""
    try:
        r = subprocess.run(["bash", "-c", cmd], cwd=repo, capture_output=True, text=True, timeout=60)
    except subprocess.TimeoutExpired:
        return False, "timed out after 60s"
    if r.returncode != 0:
        return False, f"exit {r.returncode}"
    if not r.stdout.strip():
        return False, "empty output"
    return True, ""


def parse_load_report(path, edges):
    """The reader report: one markdown table, header exactly `| edge | time | trust | money |`,
    the edge column quoting the map's edge keys VERBATIM, every cell starting with `measured`
    (carrying `oracle:`) · `n/a` · `unmeasured`. Returns ({edge: {load: cell}}, fenced keys).
    Partial coverage is NOT-GATED — the stamp claims every edge carries every load."""
    try:
        text = open(path, encoding="utf-8").read()
    except OSError as e:
        die2(f"cannot read report {path}: {e}")
    cells, fenced, seen = {}, [], set()
    intable = False
    for raw in text.splitlines():
        row = split_row(raw)
        if row is None:
            intable = False
            continue
        if [c.lower() for c in row] == LOAD_HDR:
            intable = True
            continue
        if not intable or is_separator(row):
            continue
        if len(row) != 4:
            die2(f"{path}: LOAD row has {len(row)} cells, expected 4: {raw[:80]}")
        k = row[0].strip().strip("`").strip()
        if k not in edges:
            fenced.append(k)
            continue
        if k in seen:
            die2(f"{path}: edge `{k}` appears twice — one row per edge on the map")
        seen.add(k)
        cells[k] = {}
        for ld, cell in zip(LOADS, row[1:]):
            if not cell.strip():
                die2(f"{path}: `{k}` has an empty {ld} cell — every edge carries every load; a cell you cannot "
                     "back with a command is `unmeasured`")
            w = load_form(cell)
            if w not in CELL_FORMS:
                die2(f"{path}: `{k}` {ld} cell must start with measured, n/a or unmeasured (got '{w}'): {cell[:80]}")
            if w == "measured" and "oracle:" not in cell:
                die2(f"{path}: `{k}` {ld} is measured but carries no `oracle: <command>`: {cell[:80]}")
            cells[k][ld] = cell.strip()
    missing = [k for k in edges if k not in cells]
    if missing:
        die2(f"report covers {len(cells)} of {len(edges)} edges on the map — the round did not happen. Missing: "
             + " · ".join(f"`{k}`" for k in missing))
    return cells, fenced


def load_load_ledger(state_dir):
    p = os.path.join(state_dir, "load-ledger.json")
    if not os.path.exists(p):
        return {"rounds": 0, "cells": {}, "deltas": {}}
    try:
        return json.load(open(p, encoding="utf-8"))
    except (OSError, ValueError) as e:
        die2(f"load ledger unreadable: {e}")


def save_load_ledger(state_dir, led):
    os.makedirs(state_dir, exist_ok=True)
    p = os.path.join(state_dir, "load-ledger.json")
    tmp = p + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(led, f, indent=1, sort_keys=True)
    os.replace(tmp, p)


def write_load_md(state_dir, d, cl, counts, rnd):
    """<state>/load.md — what a human reads and what gets stamped. Regenerated whole each
    round from the merged ledger. NOTHING round-specific in it: the round number lives in the
    ledger, because this file's digest IS the fixpoint the gate stamps — a counter here would
    move it every round and the stamp would be unreachable (the seams rule: the text is the
    digest)."""
    rows = []
    for k in sorted(cl):
        r = []
        for ld in LOADS:
            e = cl[k].get(ld)
            cell = e["cell"] if e else "unmeasured"
            if e and e.get("dropped"):
                cell = f"{cell} — DROPPED round {e['round']} ({e['dropped']})"
            r.append(re.sub(r"(?<!\\)\|", r"\\|", cell))
        rows.append([f"`{k}`", *r])
    fm = ("---\n"
          f"unmeasured-time: {counts['unmeasured-time']}\n"
          f"unmeasured-trust: {counts['unmeasured-trust']}\n"
          f"unmeasured-money: {counts['unmeasured-money']}\n"
          f"edges: {counts['edges']}\n"
          f"traced-at: {d.get('traced_at', '')}\n"
          "---\n\n"
          f"# load — {d.get('object', 'object')}\n\n"
          "_Every live edge on the kept seams map, each with its three loads. A `measured` cell carries the "
          "oracle that re-ran it from the repo root; a DROPPED cell's oracle did not reproduce. `unmeasured` "
          "is the finding: the load is real and nothing measures it. The map is the fence — an edge not on "
          "it is a seams re-run, not a load finding._\n\n"
          + table(["edge", *LOADS], rows))
    with open(os.path.join(state_dir, "load.md"), "w", encoding="utf-8") as f:
        f.write(fm.rstrip() + "\n")


def cmd_load(a):
    d = load_json_map(a.map)
    repo = a.repo or os.getcwd()
    stale_guard(d, repo)
    edges = live_map_edges(d)
    led = load_load_ledger(a.state)
    if a.round != led.get("rounds", 0) + 1:
        die2(f"--round {a.round} but the load ledger has {led.get('rounds', 0)} rounds recorded — rounds are consecutive")
    cells, fenced = parse_load_report(a.validate, edges)
    # --validate: every measured cell's oracle re-runs from the repo root; nonzero exit OR
    # empty stdout drops the cell — recorded with the reason, never silently. n/a and
    # unmeasured carry no oracle and are never dropped.
    drops = {}
    for k in sorted(cells):
        for ld in LOADS:
            if load_form(cells[k][ld]) != "measured":
                continue
            cmd = oracle_of(cells[k][ld])
            ok, detail = run_oracle(cmd, repo)
            if not ok:
                drops[(k, ld)] = (cmd, detail)
    # Merge. The fixpoint keys on (edge key, load) -> cell content — exactly as quoted, never
    # on file:line or position. A changed cell or a dropped cell is the round's delta.
    changed, cl = [], led.setdefault("cells", {})
    for k in sorted(cells):
        per = cl.setdefault(k, {})
        for ld in LOADS:
            text = cells[k][ld]
            prev = per.get(ld)
            if prev is not None and prev.get("cell") != text:
                changed.append((k, ld))
            drop = drops.get((k, ld))
            per[ld] = {"cell": text, "round": a.round,
                       "dropped": (f"oracle did not reproduce ({drop[1]}): {drop[0]}" if drop else None)}
    led["rounds"] = a.round
    led.setdefault("deltas", {})[str(a.round)] = {"changed": len(changed), "dropped": len(drops)}
    led["map"] = os.path.abspath(a.map)
    led["traced_at"] = d.get("traced_at", "")
    # Counts re-derived from the merged state, never taken from the report. A dropped cell
    # counts as neither measured nor unmeasured — it is counted in dropped=.
    counts = {f"unmeasured-{ld}": 0 for ld in LOADS}
    for per in cl.values():
        for ld in LOADS:
            e = per.get(ld)
            if e and not e.get("dropped") and load_form(e["cell"]) == "unmeasured":
                counts[f"unmeasured-{ld}"] += 1
    counts["edges"] = len(edges)
    led["counts"] = counts
    save_load_ledger(a.state, led)
    write_load_md(a.state, d, cl, counts, a.round)
    print(f"seams-merge: load round={a.round} map={d.get('object', '?')} edges={len(edges)} "
          f"changed={len(changed)} dropped={len(drops)} "
          f"unmeasured-time={counts['unmeasured-time']} unmeasured-trust={counts['unmeasured-trust']} "
          f"unmeasured-money={counts['unmeasured-money']}")
    for (k, ld), (cmd, detail) in sorted(drops.items()):
        print(f"  - [{ld}] `{k}` dropped: oracle did not reproduce ({detail}): {cmd}")
    for k in fenced:
        print(f"  ~ `{k}` fenced: not on the map")
    return 0


def cmd_load_handoff(a):
    """Hand-off for a CONVERGED load run: the artifact beside its map, the counts in map.json.
    A round that changed or dropped any cell is not converged — handoff refuses, the same
    closed door the seams stamp keeps."""
    d = load_json_map(a.map)
    led = load_load_ledger(a.state)
    rounds = led.get("rounds", 0)
    last = led.get("deltas", {}).get(str(rounds))
    if not rounds or last is None:
        die2(f"no load run recorded in {a.state} — run `load` first; handoff is only for a run whose last round "
             "changed no cell and dropped none")
    if last.get("changed") or last.get("dropped"):
        die2(f"load round {rounds} is not converged: changed={last.get('changed', 0)} dropped={last.get('dropped', 0)} — "
             "handoff copies a stamped-ready load.md only; resume the reader, re-merge, then handoff")
    src = os.path.join(a.state, "load.md")
    if not os.path.exists(src):
        die2(f"no load.md at {src} — run `load` first")
    counts = led.get("counts") or {}
    if not all(k in counts for k in ("unmeasured-time", "unmeasured-trust", "unmeasured-money", "edges")):
        die2("load ledger carries no counts — run `load` first")
    # Destination: beside the map, in the dir keep_map named — _docs/seams/<object-slug>/. The
    # slug is keep_map's own derivation, recorded on the map it wrote.
    dest_dir = os.path.dirname(os.path.abspath(a.map))
    slug = d.get("object")
    if not slug:
        terms = d.get("object_terms") or []
        slug = re.sub(r"[^A-Za-z0-9_.-]+", "-", terms[0]).strip("-") if terms else "object"
    dest = os.path.join(dest_dir, "load.md")
    with open(src, "rb") as f:
        data = f.read()
    with open(dest, "wb") as f:
        f.write(data)
    # The counts into map.json, beside seams_load — replaced on re-run, never appended.
    d["load"] = {k: counts[k] for k in ("unmeasured-time", "unmeasured-trust", "unmeasured-money", "edges")}
    with open(a.map, "w", encoding="utf-8") as f:
        json.dump(d, f, indent=1, ensure_ascii=False, sort_keys=True)
    print(f"seams-merge: load-handoff wrote {dest} ({slug}) · map.json load "
          f"unmeasured-time={d['load']['unmeasured-time']} unmeasured-trust={d['load']['unmeasured-trust']} "
          f"unmeasured-money={d['load']['unmeasured-money']} edges={d['load']['edges']} rounds={rounds}")
    return 0


def main(argv):
    p = argparse.ArgumentParser(prog="seams-merge.py")
    sub = p.add_subparsers(dest="cmd")
    r = sub.add_parser("round"); r.add_argument("--state", required=True); r.add_argument("--artifact", required=True)
    r.add_argument("--round", type=int, required=True); r.add_argument("--repo"); r.add_argument("--validate", action="store_true")
    r.add_argument("--maps", metavar="PATH", help="where the full maps go each round (default <state>/maps.md) — the readers' <MAPS>; the artifact carries only the coverage grid")
    r.add_argument("reports", nargs="*", metavar="REPORT")
    h = sub.add_parser("handoff"); h.add_argument("--state", required=True); h.add_argument("--artifact", required=True)
    h.add_argument("--keep", metavar="DIR", help="also write DIR/map.json + DIR/map.html — the kept asset (_docs/seams/<object>/)")
    h.add_argument("--repo", help="repo root for traced_at (default: cwd)")
    l = sub.add_parser("load"); l.add_argument("--map", required=True, metavar="MAP.JSON", help="the kept seams map (_docs/seams/<object>/map.json)")
    l.add_argument("--state", required=True); l.add_argument("--round", type=int, required=True); l.add_argument("--repo")
    l.add_argument("--validate", required=True, metavar="REPORT",
                   help="the reader report (<STATE>/reports/r<N>-load.md); every measured cell's oracle re-runs from the repo root")
    lh = sub.add_parser("load-handoff"); lh.add_argument("--map", required=True, metavar="MAP.JSON")
    lh.add_argument("--state", required=True)
    try:
        a = p.parse_args(argv)
    except SystemExit:
        die2("bad arguments (see --help)")
    if a.cmd is None:
        die2("a subcommand is required: round | handoff | load | load-handoff")
    return {"round": cmd_round, "handoff": cmd_handoff, "load": cmd_load, "load-handoff": cmd_load_handoff}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
