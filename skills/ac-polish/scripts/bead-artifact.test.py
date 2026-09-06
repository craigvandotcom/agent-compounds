#!/usr/bin/env python3
"""bead-artifact.test.py — RED/GREEN proof harness for bead-artifact.py's edge sync.

ASSURANCE-ROLE: test-harness
CALLER: scripts/run-all-harnesses.sh (discovered by its *.test.py glob) and any local run.

The defect this covers: writeback landed BODIES and not EDGES, so a polish reader who added
a `## Consumes` line wrote a blocker the board never learned about (measured 2026-09-06 on
ac-wp8i.3 — three declared blockers, zero edges). Asserted here: the parser on two lines, on
`none`, on a bullet with no arrow, on a continuation line, on the unicode arrow, and past the
end of its own section · `missing_edges` in BOTH directions (an edge with no line is not a
missing edge — writeback is additive and must never remove one) · `blocking_deps` ignores
`parent-child` · end-to-end over a stubbed `br`: `dep add` is issued exactly once, for the
declared-but-unwired edge only, the unpaired edge is REPORTED and not removed, and the dry run
issues no write at all. `br` is a PATH stub throughout: this harness never touches a board.

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
{ printf '%s %s %s %s' "$1" "$2" "$3" "$4" | tr -d '\\n'; printf '\\n'; } >> "$BR_LOG"
if [ "$1 $2" = "list --json" ]; then echo '[]'; exit 0; fi
if [ "$1 $2" = "show --json" ]; then cat "$BR_FIXTURES/$3.json"; exit 0; fi
exit 0
"""
stub_path = os.path.join(BIN, "br")
write(stub_path, STUB)
os.chmod(stub_path, os.stat(stub_path).st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)


def bead(bead_id, title, deps):
    return {"id": bead_id, "title": title, "issue_type": "decision", "priority": 1,
            "labels": ["origin:ac-beadify"], "description": "stale — the artifact is the source",
            "dependencies": deps}


# ac-t1 carries an edge nobody declared (reported, never removed) plus its parent-child edge
# (never an edge to report). ac-t2 declares an edge nobody wired: the one dep add of this run.
# ac-t1 is a BARE OBJECT and ac-t2 a ONE-ELEMENT ARRAY — `br show --json` returns both shapes.
write(os.path.join(FIX, "ac-t1.json"),
      json.dumps(bead("ac-t1", "first", [{"id": "ac-t9", "dependency_type": "blocks"},
                                         {"id": "ac-epic", "dependency_type": "parent-child"}])))
write(os.path.join(FIX, "ac-t2.json"), json.dumps([bead("ac-t2", "second", [])]))

BLOCK = ("<!-- BEAD:{i} -->\n# {i} — {t}\ntype: decision · priority: 1 · labels: origin:ac-beadify\n\n"
         "## Intent\nfixture body.\n\n## Consumes\n{c}\n\n<!-- /BEAD:{i} -->\n\n")
ART = os.path.join(W, "artifact.md")
write(ART, BLOCK.format(i="ac-t1", t="first", c="- none")
      + BLOCK.format(i="ac-t2", t="second", c="- ac-t1 -> `the thing ac-t1 delivers`"))

ENV = dict(os.environ, PATH=BIN + os.pathsep + os.environ["PATH"], BR_LOG=LOG, BR_FIXTURES=FIX)


def run_writeback(*extra):
    write(LOG, "")
    r = subprocess.run([sys.executable, SCRIPT, "writeback", "--artifact", ART, *extra],
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
