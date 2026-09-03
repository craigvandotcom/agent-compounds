#!/usr/bin/env python3
"""seams-merge.test.py — RED/GREEN proof harness for seams-merge.py (three lenses, one artifact).

ASSURANCE-ROLE: test-harness
CALLER: scripts/run-all-harnesses.sh (discovered by its *.test.py glob) and any local run.

Rules asserted: each lens keys exactly (object stage×path · flow flow×path · boundary
interface×side×path) · one artifact holds three maps and its digest moves only on an edge ·
first-seen text, readers accumulated, a named contract beats none without moving the digest ·
per-lens derivation (hole, competing writers, unasserted edge; step with no sensor, failure
not handled; assumption nothing asserts, half-mapped boundary) · cross-lens seams by shared
path rank first · journey emitted from the flow map · reader diagnoses merge on cited paths
and count readers · --validate drops an edge no command reproduces · LENS missing / unknown
stage / wrong shape / no marker -> NOT-GATED, nothing written · rounds consecutive · no spawn,
assurance block present. Exit 0 = all pass.
"""
import hashlib
import json
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
    global FAIL; FAIL += 1; print(f"FAIL {n}\n     {d[:600]}")


def run(*args):
    r = subprocess.run([sys.executable, SCRIPT, *args], capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr


def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()


def write(p, s):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, "w").write(s)


OH = "| stage | path:line | role | upstream | downstream | contract | found-by |\n|---|---|---|---|---|---|---|\n"
FH = "| flow | step | path:line | controller | sensor | on-failure | found-by |\n|---|---|---|---|---|---|---|\n"
BH = "| interface | side | path:line | producer | assumes | asserts | found-by |\n|---|---|---|---|---|---|---|\n"
DH = "| pattern | edges | what breaks silently | found-by |\n|---|---|---|---|\n"


def rep(lens, hdr, rows="", diag=""):
    return f"LENS: {lens}\nTARGET RESOLVED TO: foods.image_urls\n\nMAP:\n{hdr}{rows}\nDIAGNOSIS:\n{DH}{diag}\n"


W = tempfile.mkdtemp(prefix="seams-3lens-")
REPO = os.path.join(W, "repo"); os.makedirs(os.path.join(REPO, "lib"))
write(os.path.join(REPO, "lib/a.ts"), "export const image_urls = 1\n")
ART = os.path.join(W, "plan.md"); write(ART, f"---\nstatus: findings\n---\n\n## Problem\n\np\n\n{MARKER}\n")
S = os.path.join(W, "state")

O1 = ("| create | `lib/db/foods.ts:139` | addFood inserts | camera | dashboard | `lib/db/__tests__/foods.test.ts` | `rg -n addFood lib/db/foods.ts` |\n"
      "| store | `supabase/migrations/006.sql:3` | image_urls TEXT[] | addFood | readers | none | `rg -n image_urls supabase` |\n"
      "| read | `lib/db/foods.ts:41` | photo_url fallback | store | EntryCard | none | `rg -n photo_url lib/db/foods.ts` |\n"
      "| update | `lib/services/image-upload.ts:218` | queued merge | camera | store | `__tests__/unit/image-upload-concurrent.test.ts` | `rg -n enqueueUpload lib/services` |\n"
      "| update | `lib/services/image-auto-save.ts:34` | blind update | gallery delete | store | none | `rg -n foodsRepo.update lib/services/image-auto-save.ts` |\n"
      "| delete | `lib/db/foods.ts:456` | deleteFood row only | page | — | `__tests__/features/foods/food-delete.test.tsx` | `rg -n deleteFood lib/db/foods.ts` |\n")
F1 = ("| camera capture → save | capture | `app/foods/camera/camera-page-client.tsx:290` | user | none | none | `rg -n handleCapture app/foods/camera` |\n"
      "| camera capture → save | upload | `lib/services/image-upload.ts:191` | camera page | `uploadComplete` flag | compensating delete | `rg -n uploadAndPersistImages lib/services` |\n"
      "| camera capture → save | save | `lib/services/image-auto-save.ts:34` | form | none | swallow | `rg -n autoSaveImageUrls lib/services` |\n")
B1 = ("| camera→form handoff blob | producer | `app/foods/camera/camera-page-client.tsx:294` | internal | form reads uploadedUrls | none | `rg -n PendingImagesData app` |\n"
      "| camera→form handoff blob | consumer | `features/foods/hooks/use-image-management.ts:80` | internal | blob has uploadedUrls | runtime guard | `rg -n PendingImagesData features` |\n"
      "| supabase foods row | consumer | `lib/db/foods.ts:41` | internal | image_urls is string[] | none | `rg -n image_urls lib/db/foods.ts` |\n"
      "| upload route | consumer | `app/api/upload/route.ts:12` | user | — | none | `rg -n 'req.json' app/api/upload/route.ts` |\n")
DA = "| shape divergence | `lib/db/foods.ts:41` · `lib/services/image-upload.ts:218` | two shapes for one column | `rg -n photo_url lib` |\n"

# --- 1. round 1: three lenses, one artifact ------------------------------------------------
write(f"{W}/r1/o.md", rep("object", OH, O1, DA)); write(f"{W}/r1/f.md", rep("flow", FH, F1)); write(f"{W}/r1/b.md", rep("boundary", BH, B1))
rc, out = run("round", "--state", S, "--artifact", ART, "--round", "1", f"{W}/r1/o.md", f"{W}/r1/f.md", f"{W}/r1/b.md")
if rc == 0 and "lenses=boundary,flow,object" in out and "new_edges=13" in out and "edges=object:6,flow:3,boundary:4" in out:
    ok("round 1: three lens reports -> 13 edges in one artifact, counted per lens")
else:
    fail("round 1", out)
art = open(ART).read()
if "### object map — 6 edges" in art and "### flow map — 3 edges" in art and "### boundary map — 4 edges" in art:
    ok("artifact holds the three maps under one marker")
else:
    fail("artifact maps", art)
if "derived_seams=" in out and "cross_lens=3" in out:
    ok("round output reports derived seams and cross-lens seams (auto-save, foods.ts, camera page each seen by two lenses)")
else:
    fail("derived/cross count", out)
d1 = sha(ART)

# --- 2. round 2: same edges, one contract named where round 1 said none -> digest unchanged --
write(f"{W}/r2/o.md", rep("object", OH, O1.replace("| image_urls TEXT[] | addFood | readers | none |", "| image_urls TEXT[] | addFood | readers | `supabase/__tests__/schema.test.ts` |")))
write(f"{W}/r2/f.md", rep("flow", FH, F1)); write(f"{W}/r2/b.md", rep("boundary", BH, B1))
rc, out = run("round", "--state", S, "--artifact", ART, "--round", "2", f"{W}/r2/o.md", f"{W}/r2/f.md", f"{W}/r2/b.md")
if rc == 0 and "new_edges=0" in out and "seen_again=13" in out and sha(ART) == d1:
    ok("clean round across all three lenses leaves the digest UNCHANGED (the stamp condition)")
else:
    fail("clean round", f"{out} same={sha(ART) == d1}")
led = json.load(open(f"{S}/ledger.json"))
e = led["edges"]["object"]["store × supabase/migrations/006.sql"]
if e["contract_disagreement"] and "schema.test" in e["contract"] and e["contract_first"] == "none" and sorted(e["readers"]) == ["o"]:
    ok("a named contract beats none in the ledger, first-seen kept in the artifact, disagreement recorded")
else:
    fail("contract merge", json.dumps(e)[:400])
if led["edges"]["flow"]["camera capture → save × lib/services/image-auto-save.ts"]["readers"] == ["f"] \
   and "camera→form handoff blob × producer × app/foods/camera/camera-page-client.tsx" in led["edges"]["boundary"]:
    ok("flow keys on flow × path; boundary keys on interface × side × path")
else:
    fail("lens keys", json.dumps(list(led["edges"]["flow"]) + list(led["edges"]["boundary"]))[:400])

# --- 3. round 3: a reader adds the cleanup edge -> digest moves, hole closes ------------------
write(f"{W}/r3/o.md", rep("object", OH, "| cleanup | `app/api/cron/gc-storage-objects/route.ts:179` | GC sweeps blobs | store | bucket | `app/api/cron/gc-storage-objects/__tests__/route.test.ts` | `rg -n image_urls app/api/cron` |\n", DA))
rc, out = run("round", "--state", S, "--artifact", ART, "--round", "3", f"{W}/r3/o.md")
if rc == 0 and "new_edges=1" in out and sha(ART) != d1:
    ok("a new edge in one lens moves the digest")
else:
    fail("new edge", out)
led = json.load(open(f"{S}/ledger.json"))
if len(next(iter(led["diag"].values()))["readers"]) == 1 and len(led["diag"]) == 1:
    ok("the same diagnosis from the same reader twice is one entry; cited-path key is order-independent")
else:
    fail("diag key", json.dumps(led["diag"])[:400])

# --- 4. handoff: cross-lens first, per-lens derived, journey ----------------------------------
rc, out = run("handoff", "--state", S, "--artifact", ART)
final = open(ART).read()
if rc == 0 and "cross_lens=3" in out and "derived=" in out:
    ok("handoff ran with cross-lens seams and derived seams")
else:
    fail("handoff", out)
want = ["## Seams — seen by more than one lens (3) — fix these first", "`lib/services/image-auto-save.ts`",
        "## Seams — derived per lens", "| object | competing writers |", "| object | unasserted edge |",
        "| flow | step with no sensor |", "| flow | failure not handled |", "| boundary | assumption nothing asserts |",
        "| boundary | half-mapped boundary |", "| boundary | untrusted input nothing validates | `upload route` · consumer · producer user",
        "## Journey — from the flow map", "capture (sensor: NONE) → upload (sensor: `uploadComplete` flag) → save (sensor: NONE)",
        "## Seams — reader diagnosis", "## Approach", "Contract disagreements"]
missing = [w for w in want if w not in final]
if not missing:
    ok("handoff sections: cross-lens · per-lens derived (all six patterns) · journey · reader diagnosis · disagreements · Approach")
else:
    fail("handoff sections", "missing: " + " || ".join(missing))
if "stage `cleanup` has no row" not in final and "supabase foods row` — only the consumer side" in final:
    ok("hole closed by round 3; half-mapped boundary named with its lone side")
else:
    fail("derived detail", final[-1500:])
fm = final.split("\n---", 1)[0]
if "seams_load: competing-writers=1 unasserted-edges=2 unsensed-steps=2 unchecked-assumptions=2 untrusted-inputs=1 holes=0 edges=14 readers=3 rounds=3" in fm \
   and fm.count("seams_load:") == 1 and "seams_load" in out:
    ok("handoff writes the north-star counts into the frontmatter (seams_load), once, and prints them")
else:
    fail("seams_load", fm + "\n" + out)
rc, out = run("handoff", "--state", S, "--artifact", ART)
if open(ART).read().split("\n---", 1)[0].count("seams_load:") == 1:
    ok("re-running handoff replaces seams_load rather than appending a second line")
else:
    fail("seams_load idempotent", open(ART).read()[:400])

# --- 5. --validate drops an edge whose command does not reproduce ----------------------------
S2, ART2 = f"{W}/s2", f"{W}/plan2.md"; write(ART2, f"---\n---\n\n{MARKER}\n")
write(f"{W}/v/o.md", rep("object", OH, "| read | `lib/a.ts:1` | reads it | — | — | none | `rg -n image_urls lib/a.ts` |\n| update | `lib/a.ts:9` | fabricated | — | — | none | `rg -n nothing_here lib/a.ts` |\n"))
rc, out = run("round", "--state", S2, "--artifact", ART2, "--round", "1", "--repo", REPO, "--validate", f"{W}/v/o.md")
a2 = open(ART2).read()
if rc == 0 and "dropped=1" in out and "reads it" in a2 and "fabricated" not in a2:
    ok("--validate: an edge no command reproduces is dropped; the real one stays")
else:
    fail("validate", out + a2)

# --- 6. NOT-GATED paths write nothing ----------------------------------------------------------
S3, ART3 = f"{W}/s3", f"{W}/plan3.md"; write(ART3, f"---\n---\n{MARKER}\n")
write(f"{W}/bad/nolens.md", f"TARGET RESOLVED TO: x\n\nMAP:\n{OH}| read | `lib/a.ts:1` | x | — | — | none | `true` |\n")
rc, out = run("round", "--state", S3, "--artifact", ART3, "--round", "1", f"{W}/bad/nolens.md")
if rc == 2 and "LENS" in out and not os.path.exists(f"{S3}/ledger.json"):
    ok("a report with no LENS line -> NOT-GATED, nothing written")
else:
    fail("no lens", out)
write(f"{W}/bad/stage.md", rep("object", OH, "| upload | `lib/a.ts:1` | x | — | — | none | `true` |\n"))
rc, out = run("round", "--state", S3, "--artifact", ART3, "--round", "1", f"{W}/bad/stage.md")
if rc == 2 and "unknown stage 'upload'" in out:
    ok("unknown object stage -> NOT-GATED with the stage list")
else:
    fail("unknown stage", out)
write(f"{W}/bad/cells.md", rep("flow", FH, "| f | s | `lib/a.ts:1` | only five |\n"))
rc, out = run("round", "--state", S3, "--artifact", ART3, "--round", "1", f"{W}/bad/cells.md")
if rc == 2 and "expected 7" in out:
    ok("wrong cell count for the lens -> NOT-GATED with the count")
else:
    fail("cells", out)
write(f"{W}/plan4.md", "no marker\n")
rc, out = run("round", "--state", S3, "--artifact", f"{W}/plan4.md", "--round", "1", f"{W}/r1/o.md")
if rc == 2 and "marker" in out:
    ok("artifact without the marker -> NOT-GATED")
else:
    fail("marker", out)
rc, out = run("round", "--state", S, "--artifact", ART, "--round", "9", f"{W}/r1/o.md")
if rc == 2 and "consecutive" in out:
    ok("non-consecutive round -> NOT-GATED")
else:
    fail("sequencing", out)
rc, out = run()
ok("no subcommand -> NOT-GATED") if rc == 2 else fail("no subcommand", out)

# --- 7. spawns nothing; assurance declared ----------------------------------------------------
src = open(SCRIPT).read()
ok("seams-merge spawns nothing") if not any(t in src for t in ("subagent", "claude ", "codex ")) else fail("spawn")
missing = [f for f in ("PROBE:", "SCHEDULE:", "MODE:", "ON-FAILURE:") if f not in src]
ok("4-field assurance declaration present") if not missing else fail("assurance", str(missing))

print("---"); print(f"PASS={PASS} FAIL={FAIL}")
sys.exit(0 if FAIL == 0 else 1)
