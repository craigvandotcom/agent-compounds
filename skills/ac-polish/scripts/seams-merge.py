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

ASSURANCE (skills/ac-pipeline/references/assurance-declarations.md § The four fields):
  PROBE:      skills/ac-polish/scripts/seams-merge.test.py — RED/GREEN over every rule above
  SCHEDULE:   once per seams round (workflows/seams.md § MERGE) and once at hand-off; and on
              every CI run via scripts/run-all-harnesses.sh
  MODE:       blocking — the artifact is written only by this script during a seams run
  ON-FAILURE: closed — a report that does not parse exits 2 NOT-GATED and writes nothing

Usage:
  seams-merge.py round   --state DIR --artifact PLAN --round N [--repo DIR] [--validate] REPORT...
  seams-merge.py handoff --state DIR --artifact PLAN

Reader REPORT (one per reader; the file stem is the reader id):
  LENS: object | flow | boundary
  TARGET RESOLVED TO: ...
  MAP:        object   | stage | path:line | role | upstream | downstream | contract | found-by |
              flow     | flow | step | path:line | controller | sensor | on-failure | found-by |
              boundary | interface | side | path:line | assumes | asserts | found-by |
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
    "boundary": {"cols": ["interface", "side", "path:line", "assumes", "asserts", "found-by"], "path_col": 2},
}
DIAG_COLS = 4
PATH_RE = re.compile(r"[A-Za-z0-9_@\-\[\]().]+(?:/[A-Za-z0-9_@\-\[\]().]+)+\.[A-Za-z0-9]{1,6}")


def die2(msg):
    print(f"seams-merge: NOT-GATED {msg}", file=sys.stderr)
    sys.exit(2)


def none_ish(cell):
    return cell.strip().strip("`* ").lower() in ("none", "", "-", "—", "n/a")


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
        r = [e[c] for c in cols]
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
        if none_ish(e["on-failure"]) or slug(e["on-failure"]) in ("swallow", "swallowed", "ignored"):
            out.append(("flow", "failure not handled", f"`{e['flow']}` · {e['step']} · `{e['path:line']}`", "a failure here leaves the process half-done with no compensation and no signal", {e["path"]}))
    bnd = live(st, "boundary")
    sides = {}
    for e in bnd:
        sides.setdefault(slug(e["interface"]), set()).add(slug(e["side"]))
        if not none_ish(e["assumes"]) and none_ish(e["asserts"]):
            out.append(("boundary", "assumption nothing asserts", f"`{e['interface']}` · {e['side']} · `{e['path:line']}`", f"assumes {e['assumes']} — a change on the other side compiles and ships clean", {e["path"]}))
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


# ---------------------------------------------------------------- commands
def cmd_round(a):
    if not a.reports:
        die2("round needs at least one REPORT file")
    st = load_state(a.state, must_exist=False)
    if a.round != st["rounds"] + 1:
        die2(f"--round {a.round} but ledger has {st['rounds']} rounds recorded — rounds are consecutive")
    reports = [parse_report(p) for p in a.reports]
    new, seen_again, dropped = [], 0, []
    for rep in reports:
        lens = rep["lens"]
        st["readers"][rep["reader"]] = {"round": a.round, "lens": lens, "resolved": rep["resolved"]}
        for seq, row in enumerate(rep["map"]):
            k = row["key"]
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
            cited = sorted({p.strip("`'\"") for p in PATH_RE.findall(d["edges"])})
            k = slug(d["pattern"]) + " @ " + ",".join(cited)
            x = st["diag"].get(k)
            if x is None:
                x = dict(d, key=k, lens=lens, first_round=a.round, readers=[], cited=cited)
                st["diag"][k] = x
            if rep["reader"] not in x["readers"]:
                x["readers"].append(rep["reader"])
    if a.validate:
        repo = a.repo or os.getcwd()
        for lens, k in new:
            e = st["edges"][lens][k]
            results, fail = run_found_by(e["found-by"], repo)
            e["validated"] = {"round": a.round, "results": results}
            if fail:
                e["dropped"] = {"round": a.round, "reason": "no found-by command reproduced"}
                dropped.append((lens, k))
    st["rounds"] = a.round
    save_state(a.state, st)
    write_below_marker(a.artifact, f"## Maps — converge when a round adds no edge to any of them\n\n{map_body(st)}")
    counts = {l: len(live(st, l)) for l in LENSES}
    derived = derive(st)
    print(f"seams-merge: round={a.round} readers={len(reports)} lenses={','.join(sorted({r['lens'] for r in reports}))} "
          f"new_edges={len(new) - len(dropped)} seen_again={seen_again} dropped={len(dropped)} "
          f"edges=object:{counts['object']},flow:{counts['flow']},boundary:{counts['boundary']} "
          f"derived_seams={len(derived)} cross_lens={len(cross_lens(derived))}")
    for lens, k in new:
        if (lens, k) not in dropped:
            print(f"  + [{lens}] {k}")
    for lens, k in dropped:
        print(f"  - [{lens}] {k} dropped: no found-by reproduced")
    return 0


def cmd_handoff(a):
    st = load_state(a.state, must_exist=True)
    derived = derive(st)
    cross = cross_lens(derived)
    cross_rows = [[f"`{p}`", " · ".join(f"{l}: {', '.join(sorted(set(ps)))}" for l, ps in sorted(ls.items())), str(len(ls))] for p, ls in cross]
    per_lens = [[lens, pattern, where, silent] for lens, pattern, where, silent, _ in derived]
    rd = sorted(st["diag"].values(), key=lambda x: (-len(x["readers"]), x["first_round"], x["key"]))
    rd_rows = [[x["lens"], x["pattern"], x["edges"], x["silent"], x["found-by"] if "found-by" in x else x["found_by"], str(len(x["readers"]))] for x in rd]
    disagreements = [e for e in live(st, "object") if e.get("contract_disagreement")]
    counts = {l: len(live(st, l)) for l in LENSES}
    body = (f"## Maps — object {counts['object']} · flow {counts['flow']} · boundary {counts['boundary']} edges · "
            f"{len(st['readers'])} readers · {st['rounds']} rounds\n\n{map_body(st, best=True)}"
            + f"\n\n## Seams — seen by more than one lens ({len(cross)}) — fix these first\n\n"
            + table(["path", "what each lens sees", "lenses"], cross_rows)
            + f"\n\n## Seams — derived per lens ({len(per_lens)})\n\n"
            + table(["lens", "pattern", "where", "what breaks silently"], per_lens)
            + f"\n\n## Seams — reader diagnosis ({len(rd_rows)}), ordered by how many readers saw it\n\n"
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
    return 0


def main(argv):
    p = argparse.ArgumentParser(prog="seams-merge.py")
    sub = p.add_subparsers(dest="cmd")
    r = sub.add_parser("round"); r.add_argument("--state", required=True); r.add_argument("--artifact", required=True)
    r.add_argument("--round", type=int, required=True); r.add_argument("--repo"); r.add_argument("--validate", action="store_true")
    r.add_argument("reports", nargs="*", metavar="REPORT")
    h = sub.add_parser("handoff"); h.add_argument("--state", required=True); h.add_argument("--artifact", required=True)
    try:
        a = p.parse_args(argv)
    except SystemExit:
        die2("bad arguments (see --help)")
    if a.cmd is None:
        die2("a subcommand is required: round | handoff")
    return {"round": cmd_round, "handoff": cmd_handoff}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
