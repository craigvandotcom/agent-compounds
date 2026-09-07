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
and count readers · --validate drops an edge no command reproduces · the frontmatter fence:
an object row whose file names no term (a same-named column on another table), a flow or
boundary row sharing no word with a declared name, is fenced with the reason and never a new
edge; the far side of a boundary is never fenced; widening the frontmatter re-admits a row;
a placeholder fence -> NOT-GATED; no fence keys -> fence=none · LENS
missing / unknown stage / wrong shape / no marker -> NOT-GATED, nothing written · rounds
consecutive · no spawn, assurance block present. Exit 0 = all pass.
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
if rc == 0 and "lenses=boundary,flow,object" in out and "new_edges=13" in out and "edges=object:6,flow:3,boundary:4" in out \
   and "fence=none" in out:
    ok("round 1: three lens reports -> 13 edges in one artifact, counted per lens; no fence keys -> fence=none")
else:
    fail("round 1", out)
art = open(ART).read(); maps = open(f"{S}/maps.md").read()
if "### object map — 6 edges" in maps and "### flow map — 3 edges" in maps and "### boundary map — 4 edges" in maps \
   and "## Coverage — the digest surface" in art and "### object map" not in art and "| file | object | flow | boundary |" in art:
    ok("maps.md holds the three maps; the artifact below the marker holds only the coverage grid (the digest surface)")
else:
    fail("artifact maps", art + maps[:300])
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
a2 = open(f"{S2}/maps.md").read()
if rc == 0 and "dropped=1" in out and "reads it" in a2 and "fabricated" not in a2:
    ok("--validate: an edge no command reproduces is dropped; the real one stays")
else:
    fail("validate", out + a2)

# --- 5b. the fence: frontmatter object/flows/boundaries bound every lens ----------------------
write(os.path.join(REPO, "lib/foods.ts"), "export const foods = { image_urls: [] }\n")
write(os.path.join(REPO, "lib/families.ts"), "export const families = { image_urls: [] }\n")
write(os.path.join(REPO, "lib/upload.ts"), "export function uploadImages() {}\n")
FENCE = "object: foods.image_urls · uploadImages\nflows: capture → upload → save → display · delete → cleanup\nboundaries: upload route · foods row\n"
S5, ART5 = f"{W}/s5", f"{W}/plan5.md"; write(ART5, f"---\nstatus: findings\n{FENCE}---\n\n{MARKER}\n")
write(f"{W}/f5/o.md", rep("object", OH,
    "| read | `lib/foods.ts:1` | reads it | — | — | none | `true` |\n"
    "| read | `lib/families.ts:1` | same-named column, other table | — | — | none | `true` |\n"
    "| transport | `lib/upload.ts:1` | named symbol | — | — | none | `true` |\n"
    "| create | `lib/missing.ts:1` | file not in repo | — | — | none | `true` |\n"))
write(f"{W}/f5/f.md", rep("flow", FH,
    "| camera capture → save | capture | `lib/foods.ts:1` | user | none | none | `true` |\n"
    "| alias sync → reindex | sync | `lib/families.ts:1` | cron | none | none | `true` |\n"))
write(f"{W}/f5/b.md", rep("boundary", BH,
    "| upload route | consumer | `lib/upload.ts:1` | user | — | none | `true` |\n"
    "| foods row | consumer | `lib/families.ts:1` | internal | image_urls is string[] | none | `true` |\n"
    "| alias table | producer | `lib/families.ts:1` | internal | — | none | `true` |\n"))
rc, out = run("round", "--state", S5, "--artifact", ART5, "--round", "1", "--repo", REPO, f"{W}/f5/o.md", f"{W}/f5/f.md", f"{W}/f5/b.md")
a5 = open(f"{S5}/maps.md").read()
if rc == 0 and "new_edges=5" in out and "fenced=4" in out and "fence=object,flow,boundary" in out \
   and "names none of: foods.image_urls · uploadImages" in out and "not readable" in out \
   and "shares no word with: capture" in out and "shares no word with: upload route" in out:
    ok("fence: same-named column on another table, missing file, undeclared flow and interface are fenced with reasons; 5 rows stay")
else:
    fail("fence round", out)
if "same-named column" not in a5 and "alias sync" not in a5 and "alias table" not in a5 \
   and "named symbol" in a5 and "| foods row | consumer | `lib/families.ts:1` |" in a5:
    ok("fenced rows are not on the maps; a symbol term admits its file; the far side of a declared boundary is never fenced")
else:
    fail("fence artifact", a5)
led5 = json.load(open(f"{S5}/ledger.json"))
if led5["edges"]["object"]["read × lib/families.ts"]["dropped"]["reason"].startswith("outside fence"):
    ok("a fenced row is recorded in the ledger as dropped with the fence reason")
else:
    fail("fence ledger", json.dumps(led5["edges"]["object"])[:400])
write(ART5, open(ART5).read().replace("flows: capture → upload → save → display · delete → cleanup", "flows: capture → upload → save → display · delete → cleanup · alias sync"))
rc, out = run("round", "--state", S5, "--artifact", ART5, "--round", "2", "--repo", REPO, f"{W}/f5/o.md", f"{W}/f5/f.md", f"{W}/f5/b.md")
if rc == 0 and "new_edges=1" in out and "fenced=3" in out and "+ [flow] alias sync → reindex × lib/families.ts" in out and "seen_again=5" in out:
    ok("widening the frontmatter fence re-admits the row on the next round; nothing else moves")
else:
    fail("fence widen", out)
S6, ART6 = f"{W}/s6", f"{W}/plan6.md"
write(ART6, f"---\nobject: <the resolved object — symbols · columns · files>\n---\n\n{MARKER}\n")
rc, out = run("round", "--state", S6, "--artifact", ART6, "--round", "1", "--repo", REPO, f"{W}/f5/o.md")
if rc == 2 and "placeholder" in out and not os.path.exists(f"{S6}/ledger.json"):
    ok("a fence line still holding the template placeholder -> NOT-GATED, nothing written")
else:
    fail("fence placeholder", out)

# --- 5c. the files: line — a closed set every lens's row must sit in ------------------------------
FENCE7 = ("object: foods.image_urls · uploadImages\nflows: capture → upload → save → display · delete → cleanup\n"
          "boundaries: upload route · foods row\nfiles: lib/foods.ts · lib/upload.ts\n")
S7, ART7 = f"{W}/s7", f"{W}/plan7.md"; write(ART7, f"---\nstatus: findings\n{FENCE7}---\n\n{MARKER}\n")
rc, out = run("round", "--state", S7, "--artifact", ART7, "--round", "1", "--repo", REPO, f"{W}/f5/o.md", f"{W}/f5/f.md", f"{W}/f5/b.md")
a7 = open(f"{S7}/maps.md").read()
if rc == 0 and "files=2" in out and "new_edges=4" in out and "fenced=5" in out \
   and "~ [boundary] foods row × consumer × lib/families.ts fenced: `lib/families.ts` is not on the files: line" in out \
   and "~ [flow] alias sync → reindex × lib/families.ts fenced" in out \
   and "| foods row | consumer | `lib/families.ts:1` |" not in a7 and "named symbol" in a7 and "reads it" in a7:
    ok("files: line — a boundary far side and a flow step in an unlisted file are fenced; listed files stay; no per-row file read")
else:
    fail("files fence", out + a7[-600:])
write(ART7, open(ART7).read().replace("files: lib/foods.ts · lib/upload.ts", "files: lib/foods.ts · lib/upload.ts · lib/families.ts"))
rc, out = run("round", "--state", S7, "--artifact", ART7, "--round", "2", "--repo", REPO, f"{W}/f5/o.md", f"{W}/f5/f.md", f"{W}/f5/b.md")
if rc == 0 and "files=3" in out and "new_edges=2" in out and "+ [boundary] foods row × consumer × lib/families.ts" in out \
   and "+ [object] read × lib/families.ts" in out and "fenced=3" in out:
    ok("widening files: re-admits the far side and the object row on the next round; undeclared flow/interface names stay fenced")
else:
    fail("files widen", out)
S8, ART8 = f"{W}/s8", f"{W}/plan8.md"
write(ART8, f"---\nobject: foods.image_urls — uploadImages\nfiles: lib/upload.ts\n---\n\n{MARKER}\n")
rc, out = run("round", "--state", S8, "--artifact", ART8, "--round", "1", "--repo", REPO, f"{W}/f5/o.md")
if rc == 0 and "new_edges=1" in out and "+ [object] transport × lib/upload.ts" in out:
    ok("a dash between object terms splits like the middle dot — the template lure no longer fuses the last symbol")
else:
    fail("fence dash split", out)
S9, ART9 = f"{W}/s9", f"{W}/plan9.md"
write(ART9, f"---\nobject: uploadImages — lib/upload.ts · lib/foods.ts\n---\n\n{MARKER}\n")
rc, out = run("round", "--state", S9, "--artifact", ART9, "--round", "1", "--repo", REPO, f"{W}/f5/o.md")
if rc == 2 and "holds a path" in out and not os.path.exists(f"{S9}/ledger.json"):
    ok("an object term holding a path -> NOT-GATED before round 1, nothing written")
else:
    fail("fence path-in-term", out)

# --- 5d. the kept asset: handoff --keep writes map.json + map.html; aim.sh status reads it ----
subprocess.run(["git", "-C", REPO, "init", "-q"], check=False)
subprocess.run(["git", "-C", REPO, "-c", "user.name=t", "-c", "user.email=t@t", "-c", "commit.gpgsign=false", "add", "-A"], check=False)
subprocess.run(["git", "-C", REPO, "-c", "user.name=t", "-c", "user.email=t@t", "-c", "commit.gpgsign=false", "commit", "-q", "-m", "fixture"], check=False)
HEADSHA = subprocess.run(["git", "-C", REPO, "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
KEEP = f"{W}/kept/foods.image_urls"
rc, out = run("handoff", "--state", S7, "--artifact", ART7, "--keep", KEEP, "--repo", REPO)
mj, mh = f"{KEEP}/map.json", f"{KEEP}/map.html"
if rc == 0 and os.path.exists(mj) and os.path.exists(mh) and f"traced_at {HEADSHA[:12]}" in out:
    ok("handoff --keep writes map.json and map.html and reports traced_at")
else:
    fail("keep writes", out)
kd = json.load(open(mj)) if os.path.exists(mj) else {}
if kd.get("traced_at") == HEADSHA and kd.get("files") == ["lib/families.ts", "lib/foods.ts", "lib/upload.ts"] \
   and kd.get("object_terms") == ["foods.image_urls", "uploadImages"] and "object" in kd.get("edges", {}) \
   and set(kd.get("seams_load", {})) >= {"unasserted-edges", "unsensed-steps", "unchecked-assumptions", "competing-writers"}:
    ok("map.json carries traced_at, the four fence lines, the ledger edges and the seams_load counts")
else:
    fail("map.json shape", json.dumps({k: kd.get(k) for k in ("traced_at", "files", "object_terms", "seams_load")})[:400])
h = open(mh).read() if os.path.exists(mh) else ""
n_edges = sum(1 for e in kd.get("edges", {}).get("object", {}).values() if not e.get("dropped"))
n_filled = h.count("class='cell filled")
n_empty = h.count("class='cell empty'")
if n_filled == n_edges and n_empty == len(kd.get("files", [])) * 7 - n_filled and "lib/families.ts" in h and "<script" not in h and "http" not in h.split("<h1>")[0]:
    ok(f"map.html: one filled grid cell per object edge ({n_filled}), the rest empty ({n_empty}); self-contained, no script, no CDN")
else:
    fail("map.html grid", f"filled={n_filled} edges={n_edges} empty={n_empty} files={len(kd.get('files', []))}")
AIM = os.path.join(os.path.dirname(SCRIPT), "aim.sh")
os.makedirs(f"{REPO}/_docs/seams/foods.image_urls", exist_ok=True)
import shutil; shutil.copy(mj, f"{REPO}/_docs/seams/foods.image_urls/map.json")
r = subprocess.run(["bash", AIM, "status", "-C", REPO], capture_output=True, text=True)
if r.returncode == 0 and f"| `foods.image_urls` | {HEADSHA[:12]} | 0 | 0 | current |" in r.stdout:
    ok("aim.sh status reads the kept map.json: drift 0, current — the two scripts agree on traced_at")
else:
    fail("status reads kept map", r.stdout + r.stderr)
write(f"{W}/bad.json", "{\"nope\": 1}")
r = subprocess.run([sys.executable, os.path.join(os.path.dirname(SCRIPT), "seams-render.py"), f"{W}/bad.json"], capture_output=True, text=True)
if r.returncode == 2 and "NOT-GATED" in r.stderr and not os.path.exists(f"{W}/map.html"):
    ok("seams-render on a shapeless json -> NOT-GATED, writes nothing")
else:
    fail("render not-gated", r.stdout + r.stderr)
rc, out = run("handoff", "--state", S7, "--artifact", ART7, "--keep", f"{W}/kept2", "--repo", f"{W}/notarepo")
if rc == 2 and "traced_at" in out and not os.path.exists(f"{W}/kept2/map.json"):
    ok("handoff --keep without a git HEAD -> NOT-GATED, no map without a traced_at")
else:
    fail("keep no sha", out)

# --- 5e. a SWEPT: block after DIAGNOSIS is a declaration, not rows — the parser ignores it ----
S10, ART10 = f"{W}/s10", f"{W}/plan10.md"; write(ART10, f"---\nstatus: findings\n{FENCE7}---\n\n{MARKER}\n")
write(f"{W}/f10/o.md", rep("object", OH, "| read | `lib/foods.ts:1` | reads it | — | — | none | `true` |\n")
      + "\nSWEPT:\n- lib/foods.ts — read\n- lib/upload.ts — absent\n- lib/families.ts — absent\n")
rc, out = run("round", "--state", S10, "--artifact", ART10, "--round", "1", "--repo", REPO, f"{W}/f10/o.md")
if rc == 0 and "new_edges=1" in out and "SWEPT" not in open(ART10).read() and "SWEPT" not in open(f"{S10}/maps.md").read():
    ok("a SWEPT: declaration after DIAGNOSIS parses as prose — one edge, nothing of it on the map")
else:
    fail("swept block", out)


# --- 5f. coverage is the digest surface; two clean rounds freeze a lens --------------------------
FENCE11 = "object: foods.image_urls · uploadImages\nflows: capture → upload → save → display · delete → cleanup\nboundaries: upload route · foods row\nfiles: lib/foods.ts · lib/upload.ts · lib/families.ts\n"
S11, ART11 = f"{W}/s11", f"{W}/plan11.md"; write(ART11, f"---\nstatus: findings\n{FENCE11}---\n\n{MARKER}\n")
O11 = "| read | `lib/foods.ts:1` | reads it | — | — | none | `true` |\n"
F11 = "| capture | grab | `lib/foods.ts:1` | user | none | none | `true` |\n"
B11 = "| upload route | consumer | `lib/upload.ts:1` | user | — | none | `true` |\n"
for rnd in (1, 2):
    write(f"{W}/c{rnd}/o.md", rep("object", OH, O11)); write(f"{W}/c{rnd}/f.md", rep("flow", FH, F11)); write(f"{W}/c{rnd}/b.md", rep("boundary", BH, B11))
run("round", "--state", S11, "--artifact", ART11, "--round", "1", "--repo", REPO, f"{W}/c1/o.md", f"{W}/c1/f.md", f"{W}/c1/b.md")
c1 = sha(ART11); m1 = sha(f"{S11}/maps.md")
# round 2: object reader relabels the same file under a second stage — a LABEL, not coverage
write(f"{W}/c2/o.md", rep("object", OH, O11 + "| transport | `lib/foods.ts:7` | also ships it | — | — | none | `true` |\n"))
rc, out = run("round", "--state", S11, "--artifact", ART11, "--round", "2", "--repo", REPO, f"{W}/c2/o.md", f"{W}/c2/f.md", f"{W}/c2/b.md")
if rc == 0 and "new_edges=1" in out and "coverage_delta=none" in out and sha(ART11) == c1 and sha(f"{S11}/maps.md") != m1:
    ok("a new stage in a file the lens already covers moves the maps and the ledger, NOT the artifact digest (coverage_delta=none)")
else:
    fail("coverage relabel", f"{out} art_same={sha(ART11) == c1} maps_same={sha(f'{S11}/maps.md') == m1}")
# round 3: same again -> object clean twice -> frozen=object; flow/boundary also clean -> all frozen
rc, out = run("round", "--state", S11, "--artifact", ART11, "--round", "3", "--repo", REPO, f"{W}/c2/o.md", f"{W}/c2/f.md", f"{W}/c2/b.md")
if rc == 0 and "coverage_delta=none" in out and "frozen=object,flow,boundary" in out and sha(ART11) == c1:
    ok("two consecutive clean rounds freeze a lens; the artifact digest is still round-1's (stampable at round 2)")
else:
    fail("freeze", out)
# round 4: boundary reader reaches a NEW file -> coverage moves, boundary unfreezes, others stay frozen
write(f"{W}/c4/b.md", rep("boundary", BH, B11 + "| foods row | consumer | `lib/families.ts:1` | internal | a shape | none | `true` |\n"))
rc, out = run("round", "--state", S11, "--artifact", ART11, "--round", "4", "--repo", REPO, f"{W}/c2/o.md", f"{W}/c2/f.md", f"{W}/c4/b.md")
if rc == 0 and "coverage_delta=boundary" in out and "frozen=object,flow" in out and sha(ART11) != c1 and "| `lib/families.ts` | — | — | rows |" in open(ART11).read():
    ok("a lens reaching a new file moves the digest, unfreezes that lens only, and shows in the coverage grid")
else:
    fail("coverage new file", out + open(ART11).read()[-400:])
# round 5: the fence widens -> everything unfreezes, widened=yes
write(ART11, open(ART11).read().replace("files: lib/foods.ts · lib/upload.ts · lib/families.ts", "files: lib/foods.ts · lib/upload.ts · lib/families.ts · lib/a.ts"))
rc, out = run("round", "--state", S11, "--artifact", ART11, "--round", "5", "--repo", REPO, f"{W}/c2/o.md", f"{W}/c2/f.md", f"{W}/c4/b.md")
if rc == 0 and "widened=yes" in out and "frozen=none" in out and "| `lib/a.ts` | — | — | — |" in open(ART11).read():
    ok("a widened files: line unfreezes every lens and the new file appears in the grid as unwalked")
else:
    fail("widen unfreezes", out)
if os.path.exists(f"{S11}/maps.md") and "### object map — 2 edges" in open(f"{S11}/maps.md").read():
    ok("maps.md carries the full maps for the readers every round")
else:
    fail("maps.md", "missing or short")

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
