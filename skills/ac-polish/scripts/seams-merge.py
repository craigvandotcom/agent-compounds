#!/usr/bin/env python3
"""seams-merge.py — the MERGE step of `ac-polish seams`, as a script.

The dogfood run (BCA, 2026-09-02, 9 rounds) hand-wrote a merge script per round, hit a dcg
block and an anchor bug doing it, and could never stamp because the artifact accumulated
declines, hit counts and promotions — three things that move the digest without a new
finding. This script fixes the contract, not the prose:

  * The LOOP ARTIFACT holds CANDIDATE ROWS ONLY, in first-seen text, in id order. Its digest
    changes iff a candidate is added or dropped — so polish-fixpoint.sh stamps exactly when
    discovery converges: a round of K blind readers that adds nothing.
  * Hits, declines, verifications and contamination live in <state>/ledger.json.
  * Decline-only candidates live in <state>/declined.md, never in the artifact.
  * `handoff` computes the split ONCE, after the stamp: Confirmed (>=2 distinct
    uncontaminated readers, or verifier confirmations), Seen once, refuted -> archive.

Rows are keyed by LOCATION: two rows match when the files they cite overlap by at least half of the larger set
of the smaller set. Prose is never compared. A reader that reports ARTIFACT SEEN: yes still
adds candidates but its finds do not count toward consensus.

ASSURANCE (skills/ac-pipeline/references/assurance-declarations.md § The four fields):
  PROBE:      skills/ac-polish/scripts/seams-merge.test.py — every rule above, RED/GREEN
  SCHEDULE:   once per seams round (workflows/seams.md § MERGE) and once at hand-off; and on
              every CI run via scripts/run-all-harnesses.sh
  MODE:       blocking — the artifact is written only by this script during a seams run
  ON-FAILURE: closed — a report that does not parse, or a state that does not load, exits 2
              NOT-GATED and writes nothing

Usage:
  seams-merge.py round   --state DIR --artifact PLAN --round N [--repo DIR] [--validate] REPORT...
  seams-merge.py verify  --state DIR --id ID --reader NAME --verdict confirm|refute [--command CMD]
  seams-merge.py handoff --state DIR --artifact PLAN

Reader REPORT files (one per blind reader; the file's stem is the reader id) carry:
  TARGET RESOLVED TO: ...
  ARTIFACT SEEN: yes|no
  FINDINGS:  a markdown table  | class | seam | locations | what breaks silently | found-by | what notices |
  DECLINED:  a markdown table  | candidate | why not | command |
Exit 0 ok · 2 NOT-GATED (usage, unparseable report, missing state).
"""
import argparse
import json
import math
import os
import re
import subprocess
import sys

MARKER = "<!-- seams-merge: everything below this line is generated -->"
FIND_COLS = 6
DECL_COLS = 3
PATH_RE = re.compile(r"[A-Za-z0-9_@\-\[\]().]+(?:/[A-Za-z0-9_@\-\[\]().]+)+\.[A-Za-z0-9]{1,6}|[A-Za-z0-9_\-]+\.(?:tsx?|jsx?|py|sh|sql|md|json)\b")


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


def parse_report(path):
    """Returns dict(reader, resolved, contaminated, findings[], declined[])."""
    try:
        text = open(path, encoding="utf-8").read()
    except OSError as e:
        die2(f"cannot read report {path}: {e}")
    reader = os.path.splitext(os.path.basename(path))[0]
    out = {"reader": reader, "resolved": "", "contaminated": False, "findings": [], "declined": []}
    section = None
    header_seen = False
    for raw in text.splitlines():
        s = raw.strip().strip("*").strip()
        low = s.lower()
        if low.startswith("target resolved to:"):
            out["resolved"] = s.split(":", 1)[1].strip()
            continue
        if low.startswith("artifact seen:"):
            out["contaminated"] = "yes" in low.split(":", 1)[1]
            continue
        if low.startswith("findings:"):
            section, header_seen = "findings", False
            continue
        if low.startswith("declined:"):
            section, header_seen = "declined", False
            continue
        cells = split_row(raw)
        if cells is None or section is None:
            continue
        if is_separator(cells):
            continue
        want = FIND_COLS if section == "findings" else DECL_COLS
        if not header_seen:
            header_seen = True  # the column header row
            if len(cells) != want:
                die2(f"{path}: {section.upper()} table has {len(cells)} columns, expected {want}")
            continue
        if len(cells) != want:
            die2(f"{path}: {section.upper()} row has {len(cells)} cells, expected {want}: {raw[:80]}")
        if section == "findings":
            cls, seam, loc, silent, found_by, notices = cells
            if seam.strip().upper() == "NONE":
                continue
            out["findings"].append({"class": cls, "seam": seam, "locations": loc,
                                    "silent": silent, "found_by": found_by, "notices": notices})
        else:
            cand, why, cmd = cells
            out["declined"].append({"candidate": cand, "why": why, "command": cmd})
    if section is None:
        die2(f"{path}: no FINDINGS: or DECLINED: section — not a reader report")
    return out


def files_of(text):
    found = set()
    for m in PATH_RE.finditer(text):
        p = m.group(0)
        p = re.sub(r":\d+(-\d+)?$", "", p)
        found.add(p.strip("`'\""))
    return found


def overlaps(a, b):
    if not a or not b:
        return False
    need = max(1, math.ceil(max(len(a), len(b)) / 2))  # half the LARGER set: a two-file row must not swallow every finding that cites one of its files
    return len(a & b) >= need


# ---------------------------------------------------------------- state
def load_state(state_dir, must_exist):
    p = os.path.join(state_dir, "ledger.json")
    if not os.path.exists(p):
        if must_exist:
            die2(f"no ledger at {p} — run `round` first")
        return {"next_id": 1, "rounds": 0, "readers": {}, "candidates": {}}
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


def cid(n):
    return f"c{n:03d}"


# ---------------------------------------------------------------- validate
def run_found_by(found_by, repo):
    """A found-by cell may carry several commands joined by ' · '. A command FAILS iff it exits
    non-zero AND prints nothing (rg/grep with no match). The row is dropped iff EVERY command
    fails — a negative check ("zero hits") beside a positive one must not sink the row."""
    cmds = [c.strip().strip("`").strip() for c in re.split(r"\s·\s", found_by) if c.strip()]
    results = []
    for c in cmds:
        c = c.replace("\\|", "|")
        try:
            r = subprocess.run(["bash", "-c", c], cwd=repo, capture_output=True, text=True, timeout=60)
            ok = r.returncode == 0 or bool(r.stdout.strip())
            results.append({"command": c, "exit": r.returncode, "lines": len(r.stdout.splitlines()), "ok": ok})
        except subprocess.TimeoutExpired:
            results.append({"command": c, "exit": None, "lines": 0, "ok": False})
    return results, (bool(results) and not any(x["ok"] for x in results))


# ---------------------------------------------------------------- artifact
def write_below_marker(artifact, body):
    try:
        text = open(artifact, encoding="utf-8").read()
    except OSError as e:
        die2(f"artifact unreadable: {e}")
    if MARKER not in text:
        die2(f"artifact has no marker line `{MARKER}` — create it from references/seams-plan-template.md")
    head = text.split(MARKER, 1)[0]
    with open(artifact, "w", encoding="utf-8") as f:
        f.write(head + MARKER + "\n\n" + body.rstrip() + "\n")


def row_cells(c):
    return [c["class"], c["seam"], c["locations"], c["silent"], c["found_by"], c["notices"]]


def table(header, rows):
    out = ["| " + " | ".join(header) + " |", "|" + "---|" * len(header)]
    out += ["| " + " | ".join(r) + " |" for r in rows]
    return "\n".join(out)


def live_candidates(st):
    return [c for _, c in sorted(st["candidates"].items()) if not c["dropped"] and c["finds"]]


def write_loop_artifact(artifact, st):
    live = live_candidates(st)
    body = (f"## Candidates — {len(live)} rows · in first-seen text · discovery converges when a round adds none\n\n"
            + table(["id", "class", "seam", "locations", "what breaks silently", "found-by", "what notices"],
                    [[c["id"]] + row_cells(c) for c in live]))
    write_below_marker(artifact, body)


def write_declined_sidecar(state_dir, st, final=False):
    rows = []
    for _, c in sorted(st["candidates"].items()):
        if c["finds"] and not c["dropped"] and not final:
            continue
        for d in c["declines"]:
            rows.append([c["seam"] or d.get("candidate", ""), d["why"], d["command"]])
        if c["dropped"]:
            rows.append([c["seam"], f"dropped in round {c['dropped']['round']}: {c['dropped']['reason']}", c["found_by"]])
    name = "declined-archive.md" if final else "declined.md"
    with open(os.path.join(state_dir, name), "w", encoding="utf-8") as f:
        f.write(("# Declined — archived at hand-off\n\n" if final else "# Declined — sidecar, outside the digest\n\n")
                + table(["candidate", "why not", "command"], rows) + "\n")


# ---------------------------------------------------------------- commands
def cmd_round(a):
    if not a.reports:
        die2("round needs at least one REPORT file")
    st = load_state(a.state, must_exist=False)
    if a.round != st["rounds"] + 1:
        die2(f"--round {a.round} but ledger has {st['rounds']} rounds recorded — rounds are consecutive")
    reports = [parse_report(p) for p in a.reports]
    new, matched = [], 0
    for rep in reports:
        st["readers"][rep["reader"]] = {"round": a.round, "contaminated": rep["contaminated"], "resolved": rep["resolved"]}
        for f in rep["findings"]:
            files = files_of(f["locations"])
            hit = next((c for c in st["candidates"].values() if not c["dropped"] and overlaps(set(c["files"]), files)), None)
            if hit is None:
                i = cid(st["next_id"]); st["next_id"] += 1
                hit = dict(id=i, files=sorted(files), first_round=a.round, finds=[], declines=[], verifications=[], dropped=None, **f)
                st["candidates"][i] = hit
                new.append(i)
            elif not hit["finds"]:
                # a decline-only row: this finding is its first-seen text, and it enters the artifact as new
                hit.update(f); hit["files"] = sorted(files); hit.pop("validated", None)
                new.append(hit["id"])
            else:
                matched += 1
            hit["finds"].append({"reader": rep["reader"], "round": a.round, "counts": not rep["contaminated"]})
        for d in rep["declined"]:
            files = files_of(d["candidate"] + " " + d["command"])
            hit = next((c for c in st["candidates"].values() if not c["dropped"] and overlaps(set(c["files"]), files)), None)
            if hit is None:
                i = cid(st["next_id"]); st["next_id"] += 1
                hit = dict(id=i, files=sorted(files), first_round=a.round, finds=[], declines=[], verifications=[], dropped=None,
                           **{"class": "", "seam": d["candidate"], "locations": "", "silent": "", "found_by": d["command"], "notices": ""})
                st["candidates"][i] = hit
            hit["declines"].append({"reader": rep["reader"], "round": a.round, "why": d["why"], "command": d["command"], "candidate": d["candidate"]})
    dropped = []
    if a.validate:
        repo = a.repo or os.getcwd()
        for c in live_candidates(st):
            if c["id"] not in new and a.round > 1 and c.get("validated"):
                continue  # a row proves itself once; re-running every round is spend without signal
            results, fail = run_found_by(c["found_by"], repo)
            c["validated"] = {"round": a.round, "results": results}
            if fail:
                c["dropped"] = {"round": a.round, "reason": "no found-by command reproduced"}
                dropped.append(c["id"])
    st["rounds"] = a.round
    save_state(a.state, st)
    write_loop_artifact(a.artifact, st)
    write_declined_sidecar(a.state, st)
    contaminated = [r["reader"] for r in reports if r["contaminated"]]
    live = live_candidates(st)
    print(f"seams-merge: round={a.round} readers={len(reports)} new={len(new) - len([i for i in new if i in dropped])} "
          f"matched={matched} dropped={len(dropped)} total={len(live)} contaminated={','.join(contaminated) or '-'}")
    for i in new:
        c = st["candidates"][i]
        if c["finds"] and not c["dropped"]:
            print(f"  + {i} [{c['class']}] {c['seam'][:90]}")
    for i in dropped:
        print(f"  - {i} dropped: no found-by reproduced")
    return 0


def cmd_verify(a):
    st = load_state(a.state, must_exist=True)
    c = st["candidates"].get(a.id)
    if c is None or c["dropped"]:
        die2(f"no live candidate {a.id}")
    c["verifications"].append({"reader": a.reader, "verdict": a.verdict, "command": a.command or ""})
    save_state(a.state, st)
    print(f"seams-merge: verify {a.id} {a.verdict} by {a.reader}")
    return 0


def cmd_handoff(a):
    st = load_state(a.state, must_exist=True)
    confirmed, seen_once, refuted = [], [], []
    for c in live_candidates(st):
        distinct = {f["reader"] for f in c["finds"] if f["counts"]}
        confirms = {v["reader"] for v in c["verifications"] if v["verdict"] == "confirm"}
        refutes = [v for v in c["verifications"] if v["verdict"] == "refute" and v["command"]]
        if refutes:
            refuted.append((c, refutes[0])); continue
        hits = len(distinct | confirms)
        flag = " · contested" if c["declines"] else ""
        row = [f"**{c['class']}**{flag}" if c["class"] else flag.strip(" ·"), c["seam"], c["locations"], c["silent"], c["found_by"], c["notices"]]
        (confirmed if hits >= 2 else seen_once).append(row)
    hdr = ["class", "seam", "locations", "what breaks silently", "found-by", "what notices"]
    body = (f"## Confirmed — two or more independent readers ({len(confirmed)})\n\n" + table(hdr, confirmed)
            + f"\n\n## Seen once — one reader; a true fact lacking a second opinion ({len(seen_once)})\n\n"
            + "_The human promotes or drops these at approval._\n\n" + table(hdr, seen_once)
            + "\n\n## Declined — only the rows that constrain the Approach\n\n"
            + f"_Every other declined row is archived at `{os.path.join(a.state, 'declined-archive.md')}`._\n\n"
            + table(["candidate", "why not", "command"], [])
            + "\n\n## Approach\n\n_Empty by design. `ac-plan` writes it with the human — one decision for the whole object._")
    write_below_marker(a.artifact, body)
    for c, r in refuted:
        c["declines"].append({"reader": r["reader"], "round": st["rounds"], "why": "refuted by verifier", "command": r["command"], "candidate": c["seam"]})
        c["dropped"] = {"round": st["rounds"], "reason": f"refuted by {r['reader']}"}
    write_declined_sidecar(a.state, st, final=True)
    save_state(a.state, st)
    print(f"seams-merge: handoff confirmed={len(confirmed)} seen_once={len(seen_once)} refuted={len(refuted)} "
          f"rounds={st['rounds']} readers={len(st['readers'])} contaminated={sum(1 for r in st['readers'].values() if r['contaminated'])}")
    return 0


def main(argv):
    p = argparse.ArgumentParser(prog="seams-merge.py", add_help=True)
    sub = p.add_subparsers(dest="cmd")
    r = sub.add_parser("round"); r.add_argument("--state", required=True); r.add_argument("--artifact", required=True)
    r.add_argument("--round", type=int, required=True); r.add_argument("--repo"); r.add_argument("--validate", action="store_true")
    r.add_argument("reports", nargs="*", metavar="REPORT")
    v = sub.add_parser("verify"); v.add_argument("--state", required=True); v.add_argument("--id", required=True)
    v.add_argument("--reader", required=True); v.add_argument("--verdict", choices=["confirm", "refute"], required=True); v.add_argument("--command")
    h = sub.add_parser("handoff"); h.add_argument("--state", required=True); h.add_argument("--artifact", required=True)
    try:
        a = p.parse_args(argv)
    except SystemExit:
        die2("bad arguments (see --help)")
    if a.cmd is None:
        die2("a subcommand is required: round | verify | handoff")
    return {"round": cmd_round, "verify": cmd_verify, "handoff": cmd_handoff}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
