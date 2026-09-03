#!/usr/bin/env python3
"""seams-merge.py — the MERGE step of `ac-polish seams`: union the readers' MAPS, derive the seams.

THE MAP IS THE ARTIFACT. Every reader traces the SAME object through the same stages and
returns a map — rows keyed by (stage, path). Two readers naming the same file at the same stage
are the same row: exact match, no fuzzy location logic. The union map is the artifact; its
digest moves iff an edge is added or dropped, so polish-fixpoint.sh stamps exactly when a round
of readers adds no edge — reachable, because the edges of one object are finite.

The seams are READ OFF the map, not hunted:
  hole                a core stage with no row
  competing writers   >=2 distinct paths at a mutating stage
  unasserted edge     contract == none
plus the readers' own diagnosis rows (shape divergence, dead state, duplication, what breaks
silently), merged by the edges they cite and counted by reader — a salience order, not a gate.

History: the hunt version (five dogfoods, 2026-09-02/03) never converged on a big object —
readers chose their own scope, findings had no bottom, and every fix after that (verifiers,
contamination rules, line-window keys, estimators) was machinery to manage an unbounded
search. The trace has a bottom. Delete > construct.

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
  TARGET RESOLVED TO: ...
  MAP:        | stage | path:line | role | upstream | downstream | contract | found-by |
  DIAGNOSIS:  | pattern | edges | what breaks silently | found-by |
Stages: create · transport · store · read · update · delete · cleanup (transport is optional).
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
MAP_COLS, DIAG_COLS = 7, 4
PATH_RE = re.compile(r"[A-Za-z0-9_@\-\[\]().]+(?:/[A-Za-z0-9_@\-\[\]().]+)+\.[A-Za-z0-9]{1,6}")


def die2(msg):
    print(f"seams-merge: NOT-GATED {msg}", file=sys.stderr)
    sys.exit(2)


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
    out = {"reader": os.path.splitext(os.path.basename(path))[0], "resolved": "", "map": [], "diag": []}
    section, header_seen = None, False
    for raw in text.splitlines():
        s = raw.strip().strip("*").strip()
        low = s.lower()
        if low.startswith("target resolved to:"):
            out["resolved"] = s.split(":", 1)[1].strip(); continue
        if low.startswith("map:"):
            section, header_seen = "map", False; continue
        if low.startswith("diagnosis:"):
            section, header_seen = "diag", False; continue
        cells = split_row(raw)
        if cells is None or section is None or is_separator(cells):
            continue
        want = MAP_COLS if section == "map" else DIAG_COLS
        if not header_seen:
            header_seen = True
            if len(cells) != want:
                die2(f"{path}: {section.upper()} table has {len(cells)} columns, expected {want}")
            continue
        if len(cells) != want:
            die2(f"{path}: {section.upper()} row has {len(cells)} cells, expected {want}: {raw[:80]}")
        if section == "map":
            stage, loc, role, up, down, contract, found_by = cells
            stage = stage.strip("`* ").lower()
            if stage not in STAGES:
                die2(f"{path}: unknown stage '{stage}' — stages are {' · '.join(STAGES)}")
            p = norm_path(loc)
            if not p:
                die2(f"{path}: MAP row at stage {stage} names no path: {loc[:60]}")
            out["map"].append({"stage": stage, "path": p, "loc": loc, "role": role, "upstream": up,
                               "downstream": down, "contract": contract, "found_by": found_by})
        else:
            pattern, edges, silent, found_by = cells
            if pattern.strip().upper() == "NONE":
                continue
            out["diag"].append({"pattern": pattern, "edges": edges, "silent": silent, "found_by": found_by})
    if section is None:
        die2(f"{path}: no MAP: section — not a trace report")
    return out


def is_none(contract):
    return contract.strip().strip("`").lower() in ("none", "", "-", "—")


# ---------------------------------------------------------------- state
def load_state(state_dir, must_exist):
    p = os.path.join(state_dir, "ledger.json")
    if not os.path.exists(p):
        if must_exist:
            die2(f"no ledger at {p} — run `round` first")
        return {"rounds": 0, "readers": {}, "edges": {}, "diag": {}}
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


def ekey(stage, path):
    return f"{stage} × {path}"


# ---------------------------------------------------------------- validate
def run_found_by(found_by, repo):
    """Several commands may be joined by ' · '. A command fails iff it exits non-zero AND prints
    nothing. The row is dropped iff EVERY command fails."""
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


def live_edges(st):
    return [e for e in st["edges"].values() if not e["dropped"]]


def ordered(edges):
    return sorted(edges, key=lambda e: (STAGES.index(e["stage"]), e["path"]))


def map_rows(edges, best_contract=False):
    """The LOOP artifact shows the first-seen contract so a contract upgrade never moves the
    digest (only an edge does); hand-off shows the best contract the ledger holds."""
    return [[e["stage"], e["loc"], e["role"], e["upstream"], e["downstream"],
             e["contract"] if best_contract else e.get("contract_first", e["contract"]), e["found_by"]]
            for e in ordered(edges)]


MAP_HDR = ["stage", "path:line", "role", "upstream", "downstream", "contract", "found-by"]


def write_loop_artifact(artifact, st):
    edges = live_edges(st)
    body = (f"## Map — {len(edges)} edges · first-seen text · the loop converges when a round adds no edge\n\n"
            + table(MAP_HDR, map_rows(edges)))
    write_below_marker(artifact, body)


# ---------------------------------------------------------------- diagnosis, derived
def derive(edges):
    by_stage = {}
    for e in edges:
        by_stage.setdefault(e["stage"], []).append(e)
    holes = [s for s in STAGES if s in CORE and not by_stage.get(s)]
    competing = {s: sorted({e["path"] for e in by_stage.get(s, [])}) for s in MUTATING
                 if len({e["path"] for e in by_stage.get(s, [])}) >= 2}
    unasserted = [e for e in ordered(edges) if is_none(e["contract"])]
    return holes, competing, unasserted


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
        st["readers"][rep["reader"]] = {"round": a.round, "resolved": rep["resolved"]}
        for row in rep["map"]:
            k = ekey(row["stage"], row["path"])
            e = st["edges"].get(k)
            if e is None or e["dropped"]:
                e = dict(key=k, first_round=a.round, readers=[], dropped=None, contract_disagreement=False,
                         contract_first=row["contract"], **row)
                st["edges"][k] = e
                new.append(k)
            else:
                seen_again += 1
                # a more specific contract wins over `none`; a disagreement is recorded, never hidden
                if is_none(e["contract"]) and not is_none(row["contract"]):
                    e["contract"] = row["contract"]; e["contract_disagreement"] = True
                elif not is_none(e["contract"]) and is_none(row["contract"]):
                    e["contract_disagreement"] = True
            if rep["reader"] not in e["readers"]:
                e["readers"].append(rep["reader"])
        for d in rep["diag"]:
            # Key on the cited PATHS only — resolving against edges known at that moment made the
            # key depend on reader order, so two readers citing the same files never merged.
            cited = sorted({p.strip("`'\"") for p in PATH_RE.findall(d["edges"])})
            k = d["pattern"].strip().lower() + " @ " + ",".join(cited)
            x = st["diag"].get(k)
            if x is None:
                x = dict(key=k, first_round=a.round, readers=[], cited=cited, **d)
                st["diag"][k] = x
            if rep["reader"] not in x["readers"]:
                x["readers"].append(rep["reader"])
    if a.validate:
        repo = a.repo or os.getcwd()
        for k in new:
            e = st["edges"][k]
            results, fail = run_found_by(e["found_by"], repo)
            e["validated"] = {"round": a.round, "results": results}
            if fail:
                e["dropped"] = {"round": a.round, "reason": "no found-by command reproduced"}
                dropped.append(k)
    st["rounds"] = a.round
    save_state(a.state, st)
    write_loop_artifact(a.artifact, st)
    edges = live_edges(st)
    holes, competing, unasserted = derive(edges)
    print(f"seams-merge: round={a.round} readers={len(reports)} new_edges={len(new) - len(dropped)} "
          f"seen_again={seen_again} dropped={len(dropped)} edges={len(edges)} "
          f"holes={','.join(holes) or '-'} competing={','.join(competing) or '-'} unasserted={len(unasserted)}")
    for k in new:
        if k not in dropped:
            print(f"  + {k}")
    for k in dropped:
        print(f"  - {k} dropped: no found-by reproduced")
    return 0


def cmd_handoff(a):
    st = load_state(a.state, must_exist=True)
    edges = live_edges(st)
    holes, competing, unasserted = derive(edges)
    derived = []
    for s in holes:
        derived.append(["hole", f"stage `{s}` has no row", "nobody does this to the object; whatever should happen at this stage does not"])
    for s, paths in competing.items():
        derived.append(["competing writers", f"`{s}`: " + " · ".join(f"`{p}`" for p in paths), "no shared owner — last write wins with nothing asserting the shape"])
    for e in unasserted:
        derived.append(["unasserted edge", f"`{e['stage']}` · `{e['loc']}`", "drift on this edge is silent — no type, assertion or test names it"])
    reader_rows = sorted(st["diag"].values(), key=lambda x: (-len(x["readers"]), x["first_round"], x["key"]))
    rr = [[x["pattern"], x["edges"], x["silent"], x["found_by"], str(len(x["readers"]))] for x in reader_rows]
    disagreements = [e for e in edges if e.get("contract_disagreement")]
    body = (f"## Map — {len(edges)} edges across {len({e['stage'] for e in edges})} stages · {len(st['readers'])} readers · {st['rounds']} rounds\n\n"
            + table(MAP_HDR, map_rows(edges, best_contract=True))
            + f"\n\n## Seams — derived from the map ({len(derived)})\n\n"
            + table(["pattern", "where", "what breaks silently"], derived)
            + f"\n\n## Seams — reader diagnosis ({len(rr)}), ordered by how many readers saw it\n\n"
            + table(["pattern", "edges", "what breaks silently", "found-by", "readers"], rr)
            + ("\n\n_Contract disagreements (one reader said none, another named one): "
               + " · ".join(f"`{e['key']}`" for e in disagreements) + "_" if disagreements else "")
            + "\n\n## Approach\n\n_Empty by design. `ac-plan` writes it with the human — usually: give this object one owner at each stage the map shows it lacks._")
    write_below_marker(a.artifact, body)
    print(f"seams-merge: handoff edges={len(edges)} holes={len(holes)} competing={len(competing)} unasserted={len(unasserted)} "
          f"reader_diagnoses={len(rr)} rounds={st['rounds']} readers={len(st['readers'])}")
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
