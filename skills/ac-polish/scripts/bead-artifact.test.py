#!/usr/bin/env python3
"""bead-artifact.test.py — RED/GREEN proof harness for bead-artifact.py's edge sync.

ASSURANCE-ROLE: test-harness
CALLER: scripts/run-all-proofs.sh (discovered by its *.test.py glob) and any local run.

The defect this covers: writeback landed BODIES and not EDGES, so a polish reader who added
a `## Consumes` line wrote a blocker the board never learned about (measured 2026-09-06 on
ac-wp8i.3 — three declared blockers, zero edges). Asserted here: the parser on two lines, on
`none`, on a bullet with no arrow, on a continuation line, on the unicode arrow, and past the
end of its own section · `missing_edges` in BOTH directions (an edge with no line is not a
missing edge — writeback is additive and must never remove one) · `blocking_deps` ignores
`parent-child` · end-to-end over a stubbed `br`: `dep add` is issued exactly once, for the
declared-but-unwired edge only, the unpaired edge is REPORTED and not removed, and the dry run
issues no write at all. Two further fail-closed contracts ride the same stub: a `show --json`
response that is an ERROR ENVELOPE is a refused read (br-read-failed), never "a bead with no
labels" — the writeback REFUSES and names it · and the description write goes through
`--description-file`, passing `--force` ONLY on a shrink and printing the shrink per bead.
`br` is a PATH stub throughout: this harness never touches a board.

Fixtures are typed `decision` so the RESTAMP SWEEP skips them: a proof test must not invoke
stamp-refined.sh, whose writes are the other gate's to make.

Exit 0 = all cases pass.
"""
import importlib.util
import json
import os
import stat
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "bead-artifact.py")
PASS = FAIL = 0


def ok(n):
    global PASS; PASS += 1; print(f"ok   {n}")


def fail(n, d=""):
    global FAIL; FAIL += 1; print(f"FAIL {n}\n     {str(d)[:600]}")


def write(path, text):
    with open(path, "w") as fh:
        fh.write(text)


def read(path):
    with open(path) as fh:
        return fh.read()


def load(path):
    spec = importlib.util.spec_from_file_location("bead_artifact", path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


if not os.path.exists(SCRIPT):
    print(f"HARNESS FAIL: {SCRIPT} missing"); sys.exit(1)
ba = load(SCRIPT)

# --- 1. parse_consumes: the pure reader of the declared edges -------------------------------
TWO = """## Intent
Something.

## Consumes
- ac-a1 -> `skills/x/y.md` (the section this bead edits)
- ac-a2 -> the receipt contract
"""
if ba.parse_consumes(TWO) == ["ac-a1", "ac-a2"]:
    ok("parse_consumes: two lines -> both blocker ids, in order")
else:
    fail("parse_consumes two", ba.parse_consumes(TWO))

for label, body in (
    ("bulleted", "## Consumes\n- none\n"),
    ("bare", "## Consumes\nnone\n"),
    ("annotated", "## Consumes\n- none (both blockers are closed and landed)\n"),
):
    got = ba.parse_consumes(body)
    ok(f"parse_consumes: `none` ({label}) -> no edges") if got == [] else fail(f"none {label}", got)

STRAY = """## Consumes
- ac-b1 -> `lib/one.ts`
- skills/_shared/agent-identity.md §Tier 1
  wrapped continuation of the line above -> not a new line
- ac-b1 -> `lib/one.ts` again
"""
if ba.parse_consumes(STRAY) == ["ac-b1"]:
    ok("parse_consumes: a bullet with no arrow, a continuation, and a repeat add no edges")
else:
    fail("parse_consumes stray", ba.parse_consumes(STRAY))

if ba.parse_consumes("## Consumes\n- ac-c1 → `path/a.md`\n") == ["ac-c1"]:
    ok("parse_consumes: the unicode arrow live beads carry is read too")
else:
    fail("parse_consumes unicode", ba.parse_consumes("## Consumes\n- ac-c1 → `path/a.md`\n"))

BOUNDED = """## Consumes
- ac-d1 -> `a.md`

## Approach (advisory)
- ac-NOT-A-BLOCKER -> prose that merely looks like a line
"""
if ba.parse_consumes(BOUNDED) == ["ac-d1"]:
    ok("parse_consumes: an arrow bullet in a LATER section is not a Consumes line")
else:
    fail("parse_consumes bounded", ba.parse_consumes(BOUNDED))

if ba.parse_consumes("## Intent\nno consumes section at all\n") == [] and ba.parse_consumes("") == []:
    ok("parse_consumes: no section (and an empty body) -> no edges, no crash")
else:
    fail("parse_consumes empty")

# --- 2. missing_edges: one direction, and only one -------------------------------------------
if ba.missing_edges(["a", "b", "c"], ["b"]) == ["a", "c"]:
    ok("missing_edges: declared blockers with no edge come back, in order")
else:
    fail("missing_edges forward", ba.missing_edges(["a", "b", "c"], ["b"]))
if ba.missing_edges(["a"], ["a", "z"]) == []:
    ok("missing_edges: an EDGE with no line is not a missing edge (additive only, never a remove)")
else:
    fail("missing_edges reverse", ba.missing_edges(["a"], ["a", "z"]))
if ba.missing_edges([], ["z"]) == [] and ba.missing_edges(["z"], []) == ["z"]:
    ok("missing_edges: both empty cases behave (nothing declared vs nothing wired)")
else:
    fail("missing_edges empty")

if ba.blocking_deps({"dependencies": [
        {"id": "ac-p", "dependency_type": "parent-child"},
        {"id": "ac-r", "dependency_type": "related"},
        {"id": "ac-b", "dependency_type": "blocks"}]}) == ["ac-b"]:
    ok("blocking_deps: parent-child and related are not blockers, so they are never unpaired edges")
else:
    fail("blocking_deps", ba.blocking_deps({}))
if ba.blocking_deps({}) == []:
    ok("blocking_deps: a bead with no dependencies key -> no edges")
else:
    fail("blocking_deps empty", ba.blocking_deps({}))

SRC = read(SCRIPT)
if 'dep", "remove' in SRC or '"remove"' in SRC:
    fail("the writeback can REMOVE an edge — additive only is the contract")
else:
    ok("bead-artifact.py contains no edge-removal call at all")

# --- 3. end to end over a stubbed `br` --------------------------------------------------------
W = tempfile.mkdtemp(prefix="bead-artifact-")
BIN, FIX = os.path.join(W, "bin"), os.path.join(W, "fixtures")
os.makedirs(BIN); os.makedirs(FIX)
LOG = os.path.join(W, "br.log")

STUB = """#!/usr/bin/env bash
{ printf '%s' "$1"; for a in "${@:2}"; do printf ' %s' "$a"; done; printf '\\n'; } >> "$BR_LOG"
if [ "$1 $2" = "list --json" ]; then echo '[]'; exit 0; fi
if [ "$1 $2" = "show --json" ]; then cat "$BR_FIXTURES/$3.json"; exit 0; fi
exit 0
"""
stub_path = os.path.join(BIN, "br")
write(stub_path, STUB)
os.chmod(stub_path, os.stat(stub_path).st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)


def bead(bead_id, title, deps, status="open"):
    return {"id": bead_id, "title": title, "issue_type": "decision", "priority": 1, "status": status,
            "labels": ["origin:ac-beadify"], "description": "stale — the artifact is the source",
            "dependencies": deps}


def base(bead_id, title):
    """The export snapshot: sha256 of live title+body, as the artifact's `base:` field carries it."""
    return ba.base_digest(bead(bead_id, title, []))


# ac-t1 carries an edge nobody declared (reported, never removed) plus its parent-child edge
# (never an edge to report). ac-t2 declares an edge nobody wired: the one dep add of this run.
# ac-t1 is a BARE OBJECT and ac-t2 a ONE-ELEMENT ARRAY — `br show --json` returns both shapes.
write(os.path.join(FIX, "ac-t1.json"),
      json.dumps(bead("ac-t1", "first", [{"id": "ac-t9", "dependency_type": "blocks"},
                                         {"id": "ac-epic", "dependency_type": "parent-child"}])))
write(os.path.join(FIX, "ac-t2.json"), json.dumps([bead("ac-t2", "second", [])]))

BLOCK = ("<!-- BEAD:{i} -->\n# {i} — {t}\ntype: decision · priority: 1 · labels: origin:ac-beadify · base: {b}\n\n"
         "## Intent\nfixture body.\n\n## Consumes\n{c}\n\n<!-- /BEAD:{i} -->\n\n")


def block(i, t, c, b=None):
    return BLOCK.format(i=i, t=t, c=c, b=b or base(i, t))


ART = os.path.join(W, "artifact.md")
write(ART, block("ac-t1", "first", "- none")
      + block("ac-t2", "second", "- ac-t1 -> `the thing ac-t1 delivers`"))

if ba.artifact_labels("type: decision · priority: 1 · labels: origin:ac-beadify,x · base: 0123456789abcdef") \
        == {"origin:ac-beadify", "x"}:
    ok("artifact_labels: the trailing `base:` field is not read as a label")
else:
    fail("artifact_labels base", ba.artifact_labels("labels: a · base: 0123456789abcdef"))

ENV = dict(os.environ, PATH=BIN + os.pathsep + os.environ["PATH"], BR_LOG=LOG, BR_FIXTURES=FIX)


def run_writeback(*extra, artifact=ART):
    write(LOG, "")
    r = subprocess.run([sys.executable, SCRIPT, "writeback", "--artifact", artifact, *extra],
                       capture_output=True, text=True, cwd=W, env=ENV)
    return r.returncode, r.stdout + r.stderr, read(LOG).splitlines()

rc, out, log = run_writeback()
if rc == 0 and "bead-artifact: DRY  EDGES would add 1: ac-t2->ac-t1; " \
        "1 edge(s) without a Consumes line: ac-t1->ac-t9" in out:
    ok("dry run: names the edge it WOULD add and the edge with no line, on one line")
else:
    fail("dry EDGES line", out)
if not [ln for ln in log if ln.startswith("dep ") or ln.startswith("update ")]:
    ok("dry run: not one dep add and not one update reached `br`")
else:
    fail("dry run wrote", log)

rc, out, log = run_writeback("--apply")
if rc == 0 and "bead-artifact: EDGES — added 1; 1 edge(s) without a Consumes line: ac-t1->ac-t9" in out:
    ok("--apply: EDGES line reports 1 added and names the unpaired edge")
else:
    fail("apply EDGES line", f"rc={rc}\n{out}")
deps = [ln for ln in log if ln.startswith("dep ")]
if deps == ["dep add ac-t2 ac-t1"]:
    ok("--apply: exactly one `br dep add`, in <blocked> <blocker> order, for the declared edge")
else:
    fail("dep add calls", deps)
# `--force` is the LAST argv element, but an inline --description value carries newlines,
# so the stub's line-oriented log splits one invocation across physical lines and the flag
# need not land on the line that STARTS with "update ". Assert on the flag's presence
# anywhere in the log, which holds under both the file and the inline description form.
if not any(ln.endswith("--force") for ln in log):
    ok("--apply: a GROW (artifact body longer than the live body) passes no --force — force is shrink-only")
else:
    fail("grow force", [ln for ln in log if ln.endswith("--force")])
if not [ln for ln in log if "remove" in ln] and "dep add ac-t1" not in "\n".join(log):
    ok("--apply: the unpaired edge was reported and left alone — nothing was removed")
else:
    fail("edge removed", log)
if "WRITEBACK COMPLETE" in out and "RESTAMP SWEEP — no implementable beads" in out:
    ok("--apply: bodies landed, then the sweep ran (and skipped the decision fixtures)")
else:
    fail("writeback tail", out)
if out.index("bead-artifact: EDGES") > out.index("bead-artifact: WROTE") \
        and out.index("bead-artifact: EDGES") < out.index("RESTAMP SWEEP"):
    ok("--apply: edges land AFTER the bodies and BEFORE the restamp sweep")
else:
    fail("edge sync ordering", out)

# a `show --json` response that is an ERROR ENVELOPE is a refused read (rc 0, empty stderr,
# valid JSON on stdout) — never "a bead with nothing on it" for polish to proceed on air.
write(os.path.join(FIX, "ac-err.json"),
      json.dumps({"error": {"code": "NOT_FOUND", "message": "no such issue: ac-err"}}))
ERR_ART = os.path.join(W, "artifact-err.md")
write(ERR_ART, block("ac-err", "err", "- none", b="0" * 16))
rc, out, log = run_writeback("--apply", artifact=ERR_ART)
if rc == 1 and "br-read-failed" in out and "ac-err" in out and "REFUSED" in out:
    ok("failed read: an error envelope is a refused read (br-read-failed), not a bead with no labels")
else:
    fail("failed read", f"rc={rc}\n{out}")

# a SHRINK — the live body longer than the artifact body — passes --force (br 0.5.10+
# REFUSES a destructive rewrite without it) and prints the shrink per bead. A grow or an
# equal-length rewrite must NOT carry --force.
LONG = bead("ac-t3", "third", [])
LONG["description"] = "x" * 400
write(os.path.join(FIX, "ac-t3.json"), json.dumps([LONG]))
ART3 = os.path.join(W, "artifact-shrink.md")
write(ART3, block("ac-t3", "third", "- none", b=ba.base_digest(LONG)))
rc, out, log = run_writeback("--apply", artifact=ART3)
upd = [ln for ln in log if ln.startswith("update ")]
if rc == 0 and upd and any(ln.endswith("--force") for ln in log) \
        and "WROTE ac-t3" in out and "shrink=" in out:
    ok("shrink: --force rides the update ONLY when the new body is shorter, and the shrink is printed per bead")
else:
    fail("shrink force", f"rc={rc}\nupd={upd}\n{out}")

# FRESHNESS: a bead whose live body differs from the export snapshot was edited by someone
# else in between. The whole set is REFUSED before a single write — never a stale overwrite.
MOVED = bead("ac-t4", "fourth", [])
MOVED["description"] = "edited by another session after export"
write(os.path.join(FIX, "ac-t4.json"), json.dumps(MOVED))
ART4 = os.path.join(W, "artifact-stale.md")
write(ART4, block("ac-t1", "first", "- none") + block("ac-t4", "fourth", "- none"))
rc, out, log = run_writeback("--apply", artifact=ART4)
if rc == 1 and "REFUSED stale-artifact" in out and "STALE ac-t4" in out and "moved since export" in out \
        and not [ln for ln in log if ln.startswith("update ")]:
    ok("freshness: one moved bead refuses the whole writeback, names it, and nothing is written (not even ac-t1)")
else:
    fail("freshness moved", f"rc={rc}\n{out}\nlog={log}")

# a block with no `base:` is an artifact from before the snapshot existed — refused, re-export
ART5 = os.path.join(W, "artifact-nobase.md")
write(ART5, "<!-- BEAD:ac-t1 -->\n# ac-t1 — first\ntype: decision · priority: 1 · labels: origin:ac-beadify\n\n"
            "## Intent\nfixture body.\n\n## Consumes\n- none\n\n<!-- /BEAD:ac-t1 -->\n")
rc, out, log = run_writeback("--apply", artifact=ART5)
if rc == 1 and "no `base:` snapshot" in out and not [ln for ln in log if ln.startswith("update ")]:
    ok("freshness: an artifact with no `base:` snapshot is refused, nothing written")
else:
    fail("freshness nobase", f"rc={rc}\n{out}")

# CLOSED beads are records. Writeback refuses one that closed since export; export refuses one
# named in --ids and writes no artifact at all.
CLOSED = bead("ac-t6", "sixth", [], status="closed")
write(os.path.join(FIX, "ac-t6.json"), json.dumps(CLOSED))
ART6 = os.path.join(W, "artifact-closed.md")
write(ART6, block("ac-t6", "sixth", "- none"))
rc, out, log = run_writeback("--apply", artifact=ART6)
if rc == 1 and "closed since export" in out and not [ln for ln in log if ln.startswith("update ")]:
    ok("closed: writeback refuses a bead that closed since export, nothing written")
else:
    fail("closed writeback", f"rc={rc}\n{out}")
OUTDIR = os.path.join(W, "export-closed")
r = subprocess.run([sys.executable, SCRIPT, "export", "--out", OUTDIR, "--ids", "ac-t1,ac-t6"],
                   capture_output=True, text=True, cwd=W, env=ENV)
if r.returncode == 1 and "ac-t6" in r.stderr and "closed" in r.stderr \
        and not os.path.exists(os.path.join(OUTDIR, "artifact.md")):
    ok("closed: export refuses a closed id and writes NO artifact (the open sibling is not exported alone)")
else:
    fail("closed export", f"rc={r.returncode}\n{r.stdout}{r.stderr}")
OUTDIR2 = os.path.join(W, "export-open")
r = subprocess.run([sys.executable, SCRIPT, "export", "--out", OUTDIR2, "--ids", "ac-t1"],
                   capture_output=True, text=True, cwd=W, env=ENV)
exported = read(os.path.join(OUTDIR2, "artifact.md")) if r.returncode == 0 else ""
if r.returncode == 0 and f"· base: {base('ac-t1', 'first')}" in exported:
    ok("export: every block carries `base:`, the live title+body digest writeback checks against")
else:
    fail("export base", f"rc={r.returncode}\n{r.stdout}{r.stderr}\n{exported[:300]}")

# a dep add that fails is a WRITEBACK failure: a Consumes line whose edge does not exist is a lie
FAILSTUB = STUB.replace('if [ "$1 $2" = "list --json" ]',
                        'if [ "$1 $2" = "dep add" ]; then echo "br: no such issue" >&2; exit 1; fi\n'
                        'if [ "$1 $2" = "list --json" ]')
write(stub_path, FAILSTUB)
rc, out, log = run_writeback("--apply")
if rc == 1 and "REFUSED" in out and "dep add ac-t1 exited 1" in out:
    ok("a failed `br dep add` counts in the writeback failure count and exits 1")
else:
    fail("dep add failure", f"rc={rc}\n{out}")

print("---"); print(f"PASS={PASS} FAIL={FAIL}")
sys.exit(0 if FAIL == 0 else 1)
