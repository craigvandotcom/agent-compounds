#!/usr/bin/env python3
"""seams-merge.test.py — RED/GREEN proof harness for seams-merge.py (the trace version).

ASSURANCE-ROLE: test-harness
CALLER: scripts/run-all-harnesses.sh (discovered by its *.test.py glob) and any local run.

Rules asserted: edges key on (stage, path) exactly · a round that adds no edge leaves the
digest unchanged (the stamp condition) · first-seen text kept, readers accumulated · a named
contract beats `none` and the disagreement is recorded · holes / competing writers / unasserted
edges are DERIVED · reader diagnoses merge on cited edges and count readers · --validate drops
an edge no command reproduces · unknown stage / bad shape / no marker -> NOT-GATED, nothing
written · consecutive rounds enforced · no spawn, assurance block present. Exit 0 = all pass.
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


def ok(n):
    global PASS; PASS += 1; print(f"ok   {n}")


def fail(n, d=""):
    global FAIL; FAIL += 1; print(f"FAIL {n}\n     {d[:500]}")


def run(*args):
    r = subprocess.run([sys.executable, SCRIPT, *args], capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr


def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()


def write(p, s):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, "w").write(s)


MH = "| stage | path:line | role | upstream | downstream | contract | found-by |\n|---|---|---|---|---|---|---|\n"
DH = "| pattern | edges | what breaks silently | found-by |\n|---|---|---|---|\n"


def report(map_rows="", diag_rows="", resolved="foods.image_urls"):
    return f"TARGET RESOLVED TO: {resolved}\n\nMAP:\n{MH}{map_rows}\nDIAGNOSIS:\n{DH}{diag_rows}\n"


W = tempfile.mkdtemp(prefix="seams-trace-")
REPO = os.path.join(W, "repo"); os.makedirs(os.path.join(REPO, "lib"))
write(os.path.join(REPO, "lib/a.ts"), "export const image_urls = 1\n")
ART = os.path.join(W, "plan.md"); write(ART, f"---\nstatus: findings\n---\n\n## Problem\n\np\n\n{MARKER}\n")
S = os.path.join(W, "state")

CREATE = "| create | `lib/db/foods.ts:139` | addFood inserts the row | camera blob | dashboard | `lib/db/__tests__/foods.test.ts` | `rg -n addFood lib/db/foods.ts` |\n"
CREATE2 = "| create | `lib/db/foods.ts:141` | insert (same file, other line, other words) | form | page | none | `rg -n addFood lib/db/foods.ts` |\n"
STORE = "| store | `supabase/migrations/006.sql:3` | image_urls TEXT[] | addFood | readers | none | `rg -n image_urls supabase` |\n"
READ = "| read | `lib/db/foods.ts:41` | fallback to photo_url | store | EntryCard | none | `rg -n photo_url lib/db/foods.ts` |\n"
UPD1 = "| update | `lib/services/image-upload.ts:218` | queued merge | camera | store | `__tests__/unit/image-upload-concurrent.test.ts` | `rg -n enqueueUpload lib/services` |\n"
UPD2 = "| update | `lib/services/image-auto-save.ts:34` | blind update, no queue | gallery delete | store | none | `rg -n foodsRepo.update lib/services/image-auto-save.ts` |\n"
DEL = "| delete | `lib/db/foods.ts:456` | deleteFood, row only | page | — | `__tests__/features/foods/food-delete.test.tsx` | `rg -n deleteFood lib/db/foods.ts` |\n"
DIAG_A = "| shape divergence | `lib/db/foods.ts:41` · `lib/services/image-upload.ts:218` | two shapes for one column | `rg -n 'photo_url\\|image_urls' lib` |\n"
DIAG_A2 = "| shape divergence | `lib/services/image-upload.ts:218` · `lib/db/foods.ts:41` | same thing, other order | `rg -n image_urls lib` |\n"

# --- 1. round 1: two readers, same edge in different words -> one edge; diagnoses merge ----
write(f"{W}/r1/A.md", report(CREATE + STORE + READ + UPD1 + UPD2, DIAG_A))
write(f"{W}/r1/B.md", report(CREATE2 + STORE + DEL, DIAG_A2))
rc, out = run("round", "--state", S, "--artifact", ART, "--round", "1", f"{W}/r1/A.md", f"{W}/r1/B.md")
if rc == 0 and "new_edges=6" in out and "seen_again=2" in out and "edges=6" in out:
    ok("round 1: 8 rows from 2 readers -> 6 edges keyed on stage × path (create and store seen twice)")
else:
    fail("round 1 merge", out)
art = open(ART).read()
if "addFood inserts the row" in art and "other words" not in art and art.count("\n| ") == 7:
    ok("artifact holds FIRST-SEEN text, one row per edge, header + 6 rows")
else:
    fail("artifact text", art)
if "holes=cleanup" in out and "competing=update" in out and "unasserted=3" in out:
    ok("round output derives holes (cleanup), competing writers (update), unasserted edges (3)")
else:
    fail("derived diagnosis", out)
d1 = sha(ART)

# --- 2. round 2: same edges re-found, a contract named where round 1 said none -> digest unchanged
write(f"{W}/r2/C.md", report(STORE.replace("| none |", "| `supabase/__tests__/schema.test.ts` |") + READ, ""))
rc, out = run("round", "--state", S, "--artifact", ART, "--round", "2", f"{W}/r2/C.md")
if rc == 0 and "new_edges=0" in out and sha(ART) == d1:
    ok("clean round: re-found edges leave the digest UNCHANGED (the stamp condition)")
else:
    fail("clean round digest", f"{out} same={sha(ART) == d1}")
import json
led = json.load(open(f"{S}/ledger.json"))
e = led["edges"]["store × supabase/migrations/006.sql"]
if e["contract_disagreement"] and "schema.test" in e["contract"] and sorted(e["readers"]) == ["A", "B", "C"]:
    ok("a named contract beats `none`, the disagreement is recorded, readers accumulate")
else:
    fail("contract merge", json.dumps(e)[:300])
if led["diag"] and len(next(iter(led["diag"].values()))["readers"]) == 2:
    ok("reader diagnoses citing the same edges merge and count 2 readers")
else:
    fail("diag merge", json.dumps(led["diag"])[:300])

# --- 3. round 3 adds the missing cleanup edge -> digest moves, hole closes ------------------
CLEAN = "| cleanup | `app/api/cron/gc-storage-objects/route.ts:179` | GC sweeps unreferenced blobs | store | bucket | `app/api/cron/gc-storage-objects/__tests__/route.test.ts` | `rg -n image_urls app/api/cron` |\n"
write(f"{W}/r3/D.md", report(CLEAN, ""))
rc, out = run("round", "--state", S, "--artifact", ART, "--round", "3", f"{W}/r3/D.md")
if rc == 0 and "new_edges=1" in out and "holes=-" in out and sha(ART) != d1:
    ok("a new edge moves the digest and closes the hole")
else:
    fail("new edge", out)

# --- 4. rounds must be consecutive ---------------------------------------------------------
rc, out = run("round", "--state", S, "--artifact", ART, "--round", "9", f"{W}/r3/D.md")
if rc == 2 and "NOT-GATED" in out:
    ok("non-consecutive round -> NOT-GATED")
else:
    fail("sequencing", out)

# --- 5. handoff: map + derived seams + reader diagnoses, ordered by reader count ------------
rc, out = run("handoff", "--state", S, "--artifact", ART)
final = open(ART).read()
if rc == 0 and "holes=0" in out and "competing=1" in out and "reader_diagnoses=1" in out:
    ok("handoff: derived seams computed once, over the final map")
else:
    fail("handoff", out)
if "## Map" in final and "## Seams — derived" in final and "competing writers" in final and "unasserted edge" in final \
   and "## Seams — reader diagnosis" in final and "| 2 |" in final and "## Approach" in final and "Contract disagreements" in final:
    ok("handoff sections: Map · derived seams · reader diagnoses (reader count) · disagreements · Approach")
else:
    fail("handoff sections", final)

# --- 6. --validate drops an edge whose command does not reproduce ----------------------------
S2, ART2 = f"{W}/s2", f"{W}/plan2.md"; write(ART2, f"---\n---\n\n{MARKER}\n")
REAL = "| read | `lib/a.ts:1` | reads it | — | — | none | `rg -n image_urls lib/a.ts` |\n"
FAKE = "| update | `lib/a.ts:9` | fabricated | — | — | none | `rg -n nothing_here lib/a.ts` |\n"
write(f"{W}/v/A.md", report(REAL + FAKE, ""))
rc, out = run("round", "--state", S2, "--artifact", ART2, "--round", "1", "--repo", REPO, "--validate", f"{W}/v/A.md")
a2 = open(ART2).read()
if rc == 0 and "dropped=1" in out and "reads it" in a2 and "fabricated" not in a2:
    ok("--validate: an edge no command reproduces is dropped; the real one stays")
else:
    fail("validate", out + a2)

# --- 7. NOT-GATED paths write nothing ----------------------------------------------------------
S3, ART3 = f"{W}/s3", f"{W}/plan3.md"; write(ART3, f"---\n---\n{MARKER}\n")
write(f"{W}/bad/stage.md", report("| upload | `lib/a.ts:1` | x | — | — | none | `true` |\n", ""))
rc, out = run("round", "--state", S3, "--artifact", ART3, "--round", "1", f"{W}/bad/stage.md")
if rc == 2 and "unknown stage 'upload'" in out and not os.path.exists(f"{S3}/ledger.json"):
    ok("unknown stage -> NOT-GATED, names the stage list, writes nothing")
else:
    fail("unknown stage", out)
write(f"{W}/bad/cells.md", report("| read | `lib/a.ts:1` | only | four |\n", ""))
rc, out = run("round", "--state", S3, "--artifact", ART3, "--round", "1", f"{W}/bad/cells.md")
if rc == 2 and "expected 7" in out:
    ok("wrong cell count -> NOT-GATED with the count")
else:
    fail("cell count", out)
write(f"{W}/bad/prose.md", "no tables here\n")
rc, out = run("round", "--state", S3, "--artifact", ART3, "--round", "1", f"{W}/bad/prose.md")
if rc == 2 and "no MAP" in out:
    ok("a report with no MAP section -> NOT-GATED")
else:
    fail("no map", out)
write(f"{W}/plan4.md", "no marker\n")
rc, out = run("round", "--state", S3, "--artifact", f"{W}/plan4.md", "--round", "1", f"{W}/r1/A.md")
if rc == 2 and "marker" in out:
    ok("artifact without the marker -> NOT-GATED")
else:
    fail("marker", out)
rc, out = run()
if rc == 2:
    ok("no subcommand -> NOT-GATED")
else:
    fail("no subcommand", out)

# --- 8. spawns nothing; assurance declared ----------------------------------------------------
src = open(SCRIPT).read()
ok("seams-merge spawns nothing") if not any(t in src for t in ("subagent", "claude ", "codex ")) else fail("spawn")
missing = [f for f in ("PROBE:", "SCHEDULE:", "MODE:", "ON-FAILURE:") if f not in src]
ok("4-field assurance declaration present") if not missing else fail("assurance", str(missing))

print("---"); print(f"PASS={PASS} FAIL={FAIL}")
sys.exit(0 if FAIL == 0 else 1)
