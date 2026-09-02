#!/usr/bin/env python3
"""seams-merge.test.py — RED/GREEN proof harness for seams-merge.py.

ASSURANCE-ROLE: test-harness
CALLER: scripts/run-all-harnesses.sh (discovered by its *.test.py glob) and any local run.

Every rule the script claims is asserted against a fixture:
  match by location, not prose · a clean round leaves the artifact digest unchanged (the
  stamp condition) · contaminated readers add candidates but do not count · decline-only
  rows never enter the artifact · a later find outranks an earlier decline (contested) ·
  --validate drops a row whose commands all fail, keeps one with a negative check beside a
  positive · handoff splits at >=2 distinct counting readers, verifier confirms promote,
  a refute with a command archives · unparseable report -> NOT-GATED, nothing written.
Exit 0 = all cases pass.
"""
import hashlib
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "seams-merge.py")
MARKER = "<!-- seams-merge: everything below this line is generated -->"
PASS = FAIL = 0


def ok(name):
    global PASS; PASS += 1; print(f"ok   {name}")


def fail(name, detail=""):
    global FAIL; FAIL += 1; print(f"FAIL {name}\n     {detail[:400]}")


def run(*args, cwd=None):
    r = subprocess.run([sys.executable, SCRIPT, *args], capture_output=True, text=True, cwd=cwd)
    return r.returncode, r.stdout + r.stderr


def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()


def write(p, s):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, "w").write(s)


FH = "| class | seam | locations | what breaks silently | found-by | what notices |\n|---|---|---|---|---|---|\n"
DH = "| candidate | why not | command |\n|---|---|---|\n"


def report(resolved="x", seen="no", findings="", declined=""):
    return (f"TARGET RESOLVED TO: {resolved}\nARTIFACT SEEN: {seen}\n\nFINDINGS:\n{FH}{findings}\n"
            f"DECLINED:\n{DH}{declined}\n")


W = tempfile.mkdtemp(prefix="seams-merge-")
REPO = os.path.join(W, "repo"); os.makedirs(REPO)
write(os.path.join(REPO, "lib/a.ts"), "export const image_urls = 1\n")
write(os.path.join(REPO, "lib/b.ts"), "nothing here\n")
ART = os.path.join(W, "plan.md")
write(ART, f"---\nstatus: findings\n---\n\n# seams — t\n\n## Problem\n\np\n\n{MARKER}\n")
S = os.path.join(W, "state")

ROW_A = "| breaks today | third writer bypasses queue | `lib/a.ts:34` · `lib/b.ts:10` | lost write | `rg -n image_urls lib/a.ts` | none |\n"
ROW_A2 = "| breaks today | unqueued writer (same seam, other words) | `lib/b.ts:12` · `lib/a.ts:30` | drop | `rg -n image_urls lib/a.ts` | none |\n"
ROW_B = "| unasserted | cap literal | `app/x.tsx:5` | drift | `rg -n MAX lib/a.ts` | none |\n"
DEC_C = "| gc cron races upload | guarded by grace window | `rg -n GRACE app/api/gc.ts` |\n"

# --- 1. round 1: two readers, same seam in different words -> one candidate ------
write(os.path.join(W, "r1/A.md"), report(findings=ROW_A, declined=DEC_C))
write(os.path.join(W, "r1/B.md"), report(findings=ROW_A2 + ROW_B))
rc, out = run("round", "--state", S, "--artifact", ART, "--round", "1", os.path.join(W, "r1/A.md"), os.path.join(W, "r1/B.md"))
if rc == 0 and "new=2" in out and "matched=1" in out and "total=2" in out:
    ok("round 1: location-keyed match — 3 rows from 2 readers -> 2 candidates, 1 matched")
else:
    fail("round 1 merge", out)
art1 = open(ART).read()
if art1.count("\n| c0") == 2 and "third writer bypasses queue" in art1 and "cap literal" in art1 and "unqueued writer" not in art1:
    ok("artifact holds candidates in FIRST-SEEN text only")
else:
    fail("artifact text", art1)
if "gc cron races upload" not in art1 and "gc cron races upload" in open(os.path.join(S, "declined.md")).read():
    ok("decline-only row is in the sidecar, never the artifact")
else:
    fail("decline sidecar", art1)
d1 = sha(ART)

# --- 2. round 2: nothing new (re-finds + a decline of an existing row) -> digest unchanged ---
write(os.path.join(W, "r2/C.md"), report(findings=ROW_A, declined="| cap literal | agrees today | `rg -n MAX lib/a.ts` |\n"))
rc, out = run("round", "--state", S, "--artifact", ART, "--round", "2", os.path.join(W, "r2/C.md"))
if rc == 0 and "new=0" in out and sha(ART) == d1:
    ok("clean round: re-finds and declines leave the digest UNCHANGED (the stamp condition)")
else:
    fail("clean round digest", f"{out} same={sha(ART) == d1}")

# --- 3. round 3: contaminated reader adds a candidate but its hits do not count ---
ROW_D = "| breaks today | set primary never persists | `features/form.tsx:1349` | reverts | `grep -n primary features/form.tsx` | none |\n"
write(os.path.join(W, "r3/D.md"), report(seen="yes", findings=ROW_A + ROW_D))
rc, out = run("round", "--state", S, "--artifact", ART, "--round", "3", os.path.join(W, "r3/D.md"))
if rc == 0 and "new=1" in out and "contaminated=D" in out and "set primary never persists" in open(ART).read():
    ok("contaminated reader: candidate added, reader flagged")
else:
    fail("contaminated round", out)

# --- 4. rounds must be consecutive ------------------------------------------------
rc, out = run("round", "--state", S, "--artifact", ART, "--round", "5", os.path.join(W, "r3/D.md"))
if rc == 2 and "NOT-GATED" in out:
    ok("non-consecutive round -> NOT-GATED")
else:
    fail("round sequencing", out)

# --- 5. handoff: split at >=2 DISTINCT COUNTING readers; contested flag ------------
rc, out = run("handoff", "--state", S, "--artifact", ART)
final = open(ART).read()
if rc == 0 and "confirmed=1" in out and "seen_once=2" in out:
    ok("handoff: c001 (A,B,C) confirmed; c002 (B only, D's decline) and c003 (D, contaminated) seen once")
else:
    fail("handoff split", out)
if "contested" in final and "## Confirmed" in final and "## Seen once" in final and "## Approach" in final:
    ok("handoff: contested flag on the declined-then-found row; sections present")
else:
    fail("handoff sections", final)
if os.path.exists(os.path.join(S, "declined-archive.md")) and "gc cron races upload" in open(os.path.join(S, "declined-archive.md")).read():
    ok("handoff: declined archive written")
else:
    fail("archive")

# --- 6. verify: two confirms promote; a refute with a command archives ------------
S2 = os.path.join(W, "state2"); ART2 = os.path.join(W, "plan2.md")
write(ART2, f"---\n---\n\n## Problem\n\n{MARKER}\n")
write(os.path.join(W, "v/A.md"), report(findings=ROW_A + ROW_B))
run("round", "--state", S2, "--artifact", ART2, "--round", "1", os.path.join(W, "v/A.md"))
run("verify", "--state", S2, "--id", "c001", "--reader", "V1", "--verdict", "confirm")
run("verify", "--state", S2, "--id", "c001", "--reader", "V2", "--verdict", "confirm")
run("verify", "--state", S2, "--id", "c002", "--reader", "V1", "--verdict", "refute", "--command", "rg -n MAX lib/a.ts  # zero hits")
rc, out = run("handoff", "--state", S2, "--artifact", ART2)
if rc == 0 and "confirmed=1" in out and "seen_once=0" in out and "refuted=1" in out:
    ok("verify: confirmations promote a singleton; a refute with a command archives it")
else:
    fail("verify handoff", out)
rc, out = run("verify", "--state", S2, "--id", "c099", "--reader", "V1", "--verdict", "confirm")
if rc == 2:
    ok("verify on an unknown id -> NOT-GATED")
else:
    fail("verify unknown id", out)

# --- 7. --validate: all-fail drops; a negative check beside a positive survives ----
S3 = os.path.join(W, "state3"); ART3 = os.path.join(W, "plan3.md")
write(ART3, f"---\n---\n\n{MARKER}\n")
ROW_OK = "| breaks today | real | `lib/a.ts:1` | x | `rg -n image_urls lib/a.ts` · `rg -n nope lib/a.ts` (zero hits) | none |\n"
ROW_BAD = "| breaks today | fabricated | `lib/b.ts:1` | x | `rg -n image_urls lib/b.ts` | none |\n"
write(os.path.join(W, "val/A.md"), report(findings=ROW_OK + ROW_BAD))
rc, out = run("round", "--state", S3, "--artifact", ART3, "--round", "1", "--repo", REPO, "--validate", os.path.join(W, "val/A.md"))
a3 = open(ART3).read()
if rc == 0 and "dropped=1" in out and "real" in a3 and "fabricated" not in a3:
    ok("--validate: row with no reproducing command dropped; mixed positive/negative row kept")
else:
    fail("validate", out + a3)

# --- 7b. declined-then-found: the finding's text takes over the decline-only row ------
S3 = os.path.join(W, "state-df"); ART3 = os.path.join(W, "plan-df.md")
write(ART3, f"---\nstatus: findings\n---\n\n# seams — t\n\n## Problem\n\np\n\n{MARKER}\n")
write(os.path.join(W, "df/A.md"), report(declined="| z is fine | tested | `rg -n z lib/z.ts` |\n"))
run("round", "--state", S3, "--artifact", ART3, "--round", "1", os.path.join(W, "df/A.md"))
write(os.path.join(W, "df/B.md"), report(findings="| breaks today | z unguarded | `lib/z.ts:4` | lost | `rg -n z lib/z.ts` | none |\n"))
rc, out = run("round", "--state", S3, "--artifact", ART3, "--round", "2", os.path.join(W, "df/B.md"))
with open(ART3) as fh:
    art3 = fh.read()
if rc == 0 and "new=1" in out and "| breaks today | z unguarded |" in art3 and "z is fine" not in art3:
    ok("declined-then-found: the finding's text and class replace the decline-only row, counted as new")
else:
    fail("declined-then-found", out + art3)

# --- 7c. a small row is not a magnet: one shared file out of five is a different seam ---
S4 = os.path.join(W, "state-mag"); ART4 = os.path.join(W, "plan-mag.md")
write(ART4, f"---\nstatus: findings\n---\n\n# seams — t\n\n## Problem\n\np\n\n{MARKER}\n")
ROW_WIDE = "| unasserted | field left out of every whitelist | `lib/a.ts:1` · `lib/c.ts:2` · `lib/d.ts:3` · `lib/e.ts:4` · `lib/f.ts:5` | reverts | `rg -n x lib/c.ts` | none |\n"
write(os.path.join(W, "mag/A.md"), report(findings=ROW_A + ROW_WIDE))
rc, out = run("round", "--state", S4, "--artifact", ART4, "--round", "1", os.path.join(W, "mag/A.md"))
if rc == 0 and "new=2" in out and "total=2" in out:
    ok("location key: a 2-file row and a 5-file row sharing one file stay separate candidates")
else:
    fail("small-row magnet", out)

# --- 7d. the key is path:line — distinct seams inside ONE hot file stay distinct ---------
S5 = os.path.join(W, "state-line"); ART5 = os.path.join(W, "plan-line.md")
write(ART5, f"---\nstatus: findings\n---\n\n# seams — t\n\n## Problem\n\np\n\n{MARKER}\n")
ROW_L1 = "| breaks today | stream cleanup is a stale closure | `lib/a.ts:489` · `lib/a.ts:528` | leak | `rg -n image_urls lib/a.ts` | none |\n"
ROW_L1B = "| breaks today | cleanup never stops a track (same seam) | `lib/a.ts:528-530` · `lib/a.ts:489` · `lib/a.ts:1335` | leak | `rg -n image_urls lib/a.ts` | none |\n"
ROW_L2 = "| breaks today | armed after commit | `lib/a.ts:642` · `lib/b.ts:568` | dropped photo | `rg -n image_urls lib/a.ts` | none |\n"
ROW_L3 = "| unasserted | crop skips compression | `lib/a.ts:886` | bytes | `rg -n image_urls lib/a.ts` | none |\n"
write(os.path.join(W, "line/A.md"), report(findings=ROW_L1 + ROW_L2 + ROW_L3))
write(os.path.join(W, "line/B.md"), report(findings=ROW_L1B, declined="| whole file is fine | tested | `rg -n x lib/a.ts` |\n"))
rc, out = run("round", "--state", S5, "--artifact", ART5, "--round", "1", os.path.join(W, "line/A.md"), os.path.join(W, "line/B.md"))
with open(ART5) as fh:
    art5 = fh.read()
if rc == 0 and "new=3" in out and "matched=1" in out and "total=3" in out and "armed after commit" in art5 and "crop skips compression" in art5:
    ok("line key: three seams in one file are three candidates; a re-find within the window folds")
else:
    fail("line key", out + art5)
import json as _json
with open(os.path.join(S5, "ledger.json")) as fh:
    led5 = _json.load(fh)
c5 = led5["candidates"]["c001"]
# a neighbour is not the same seam: two lines near the stream rows, but a six-line row of its own
ROW_L4 = "| breaks today | lens state survives close | `lib/a.ts:425` · `lib/a.ts:430` · `lib/a.ts:500` · `lib/a.ts:525` · `lib/a.ts:628` · `lib/b.ts:909` | pinned lens | `rg -n image_urls lib/a.ts` | none |\n"
write(os.path.join(W, "line/C.md"), report(findings=ROW_L4))
rc, out = run("round", "--state", S5, "--artifact", ART5, "--round", "2", os.path.join(W, "line/C.md"))
if rc == 0 and "new=1" in out and "total=4" in out:
    ok("line key: a six-line neighbour sharing two nearby lines is a separate candidate (majority on BOTH sides)")
else:
    fail("neighbour fold", out)
if any(f.get("seam", "").startswith("cleanup never stops") for f in c5["finds"]) and any(d["reader"] == "B" for d in c5["declines"]):
    ok("line key: a fold keeps the folded seam text; a lineless decline attaches to the file's first row")
else:
    fail("fold text / lineless decline", _json.dumps(c5)[:400])

# --- 8. NOT-GATED paths write nothing ------------------------------------------------
S4 = os.path.join(W, "state4"); ART4 = os.path.join(W, "plan4.md"); write(ART4, f"---\n---\n{MARKER}\n")
write(os.path.join(W, "bad/A.md"), "just prose, no sections\n")
rc, out = run("round", "--state", S4, "--artifact", ART4, "--round", "1", os.path.join(W, "bad/A.md"))
if rc == 2 and "NOT-GATED" in out and not os.path.exists(os.path.join(S4, "ledger.json")):
    ok("unparseable report -> NOT-GATED, no ledger written")
else:
    fail("unparseable report", out)
write(os.path.join(W, "bad/B.md"), report(findings="| only | three | cells |\n"))
rc, out = run("round", "--state", S4, "--artifact", ART4, "--round", "1", os.path.join(W, "bad/B.md"))
if rc == 2 and "expected 6" in out:
    ok("wrong column count -> NOT-GATED with the count")
else:
    fail("column count", out)
write(os.path.join(W, "plan5.md"), "no marker here\n")
rc, out = run("round", "--state", S4, "--artifact", os.path.join(W, "plan5.md"), "--round", "1", os.path.join(W, "r1/A.md"))
if rc == 2 and "marker" in out:
    ok("artifact without the marker -> NOT-GATED")
else:
    fail("marker", out)
rc, out = run()
if rc == 2:
    ok("no subcommand -> NOT-GATED")
else:
    fail("no subcommand", out)

# --- 9. the script spawns nothing and declares assurance ------------------------------
src = open(SCRIPT).read()
if not any(t in src for t in ("subagent", "claude ", "codex ")):
    ok("seams-merge spawns nothing")
else:
    fail("spawn")
missing = [f for f in ("PROBE:", "SCHEDULE:", "MODE:", "ON-FAILURE:") if f not in src]
ok("4-field assurance declaration present") if not missing else fail("assurance", str(missing))

print("---"); print(f"PASS={PASS} FAIL={FAIL}")
sys.exit(0 if FAIL == 0 else 1)
