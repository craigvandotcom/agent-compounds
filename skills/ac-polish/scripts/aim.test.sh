#!/usr/bin/env bash
# aim.test.sh — RED/GREEN proof harness for aim.sh, both modes.
#
# ASSURANCE-ROLE: test-harness
# CALLER: scripts/run-all-harnesses.sh (discovered by its *.test.sh glob) and any local run.
#
# churn fixture (known git history):
#   big.txt    changed 6 times alone (+init), 206 lines -> hotspot #1 (7 × 206)
#   a.txt/b.txt co-changed 4 times (+init), no import   -> the coupling pair that must appear
#   a.txt/c.txt co-changed 3 times (+init), c imports a -> filtered out (coupling is IN the code)
#   docs/x.md  changed 9 times                          -> excluded by default, never a hotspot
# objects fixture (known tree):
#   column image_urls  touched by db + services(writer) + ui + one test  -> top object
#   column photo_url   touched by db + ui, no writer, no test             -> below it
#   column id          in the stoplist                                     -> never listed
#   type Food          exported, touched from 3 files                      -> listed as type
#   storage key pendingImages via sessionStorage                           -> listed, kinds counts it
# Exit 0 = all cases pass.
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/aim.sh"
[ -x "$SCRIPT" ] || { echo "HARNESS FAIL: $SCRIPT missing or not executable"; exit 1; }

W=$(mktemp -d "${TMPDIR:-/tmp}/aim-XXXXXX")
trap 'rm -rf "$W"' EXIT
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf 'ok   %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf 'FAIL %s\n     %s\n' "$1" "${2:-}"; }

echo "shell: ${BASH_VERSION:+bash $BASH_VERSION}"

# --- 0. modes and usage --------------------------------------------------------------------
out=$("$SCRIPT" 2>&1); rc=$?
[ "$rc" = 2 ] && ok "no mode -> usage, exit 2" || fail "no mode" "$out"
out=$("$SCRIPT" sideways 2>&1); rc=$?
[ "$rc" = 2 ] && printf '%s' "$out" | grep -q NOT-GATED && ok "unknown mode -> NOT-GATED" || fail "unknown mode" "$out"

# ==================================================================== churn
R="$W/repo"; mkdir -p "$R/docs"
g() { git -C "$R" -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@"; }
g init -q
commit() { g add -A >/dev/null; g commit -q -m "$1" >/dev/null; }
seq 1 200 > "$R/big.txt"; echo a > "$R/a.txt"; echo b > "$R/b.txt"; printf 'import a\n' > "$R/c.txt"; echo d > "$R/docs/x.md"
commit init
for i in 1 2 3 4 5 6; do echo "big $i" >> "$R/big.txt"; commit "big $i"; done
for i in 1 2 3 4; do echo "ab $i" >> "$R/a.txt"; echo "ab $i" >> "$R/b.txt"; commit "ab $i"; done
for i in 1 2 3; do echo "ac $i" >> "$R/a.txt"; echo "ac $i" >> "$R/c.txt"; commit "ac $i"; done
for i in 1 2 3 4 5 6 7 8 9; do echo "doc $i" >> "$R/docs/x.md"; commit "doc $i"; done
# 23 commits total

out=$("$SCRIPT" churn --since 3d -C "$R" 2>&1); rc=$?
[ "$rc" = 2 ] && printf '%s' "$out" | grep -q NOT-GATED && ok "churn: bad --since -> NOT-GATED" || fail "bad --since" "$out"
out=$("$SCRIPT" churn --top x -C "$R" 2>&1); rc=$?
[ "$rc" = 2 ] && ok "churn: non-numeric --top -> NOT-GATED" || fail "non-numeric --top" "$out"
out=$("$SCRIPT" churn -C "$W" 2>&1); rc=$?
[ "$rc" = 2 ] && printf '%s' "$out" | grep -q "not a git repo" && ok "churn: not a repo -> NOT-GATED" || fail "not a repo" "$out"

out=$("$SCRIPT" churn --since all -C "$R" 2>&1); rc=$?
[ "$rc" = 0 ] || fail "churn exits 0 on a real repo" "$out"
first=$(printf '%s\n' "$out" | grep '^| 1 |' | head -1)
printf '%s' "$first" | grep -q '`big.txt`' && ok "churn: hotspot #1 is the big churning file" || fail "hotspot #1" "$first"
printf '%s' "$first" | grep -q '| 7 | 206 | 1442 |' && ok "churn: hotspot row carries commits × lines = score (7 × 206)" || fail "hotspot arithmetic" "$first"
printf '%s\n' "$out" | grep -q 'docs/x.md' && fail "churn: excluded path leaked into hotspots" || ok "churn: docs/ excluded by default"
printf '%s' "$first" | grep -q 'git log --no-merges --format=%h' && ok "churn: hotspot row carries its found-by command" || fail "found-by missing" "$first"

out=$("$SCRIPT" churn --since all --min-commits 30 -C "$R" 2>&1)
printf '%s\n' "$out" | grep -q 'coupling: insufficient commits in window (23 < 30)' && ok "churn: coupling refused below the commit threshold, with the numbers" || fail "threshold refusal" "$out"
printf '%s\n' "$out" | grep -q '^| `a.txt`' && fail "churn: coupling table printed despite refusal" || ok "churn: no coupling rows under refusal"

out=$("$SCRIPT" churn --since all --min-commits 10 --min-cochange 3 -C "$R" 2>&1)
printf '%s\n' "$out" | grep -q '^| `a.txt` | `b.txt` | 5 | 1.00 |' && ok "churn: a/b co-changed 5× (4 + init), ratio 5/min(8,5)" || fail "a/b pair" "$(printf '%s\n' "$out" | grep '^| `')"
coupling=$(printf '%s\n' "$out" | sed -n '/Temporal coupling/,$p')
printf '%s\n' "$coupling" | grep -q '`c.txt`' && fail "churn: a/c pair reported although c.txt imports a" || ok "churn: a/c pair filtered — the coupling is in the code"
printf '%s\n' "$out" | grep '^| `a.txt` | `b.txt`' | grep -q 'git show --name-only' && ok "churn: coupling row carries a reproducing found-by" || fail "coupling found-by" "$out"
out=$("$SCRIPT" churn --since all --min-commits 10 --min-cochange 6 -C "$R" 2>&1)
printf '%s\n' "$out" | grep -q 'no pair reached --min-cochange 6' && ok "churn: no qualifying pair -> says so, prints no fake row" || fail "empty coupling" "$out"
out=$("$SCRIPT" churn --since 1w --min-commits 10 -C "$R" 2>&1)
printf '%s\n' "$out" | grep -q '^# aim churn — window: 1w · commits: 23' && ok "churn: header reports window + commit count" || fail "header" "$(printf '%s\n' "$out" | head -1)"

# ==================================================================== objects
O="$W/objrepo"; mkdir -p "$O/lib/supabase" "$O/lib/db" "$O/lib/services" "$O/lib/types" "$O/features/foods" "$O/__tests__" "$O/supabase/migrations"
go() { git -C "$O" -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@"; }
go init -q
cat > "$O/lib/supabase/types.generated.ts" <<'EOF'
export type Database = {
  public: {
    Tables: {
      foods: {
        Row: {
          id: string
          image_urls: string[] | null
          photo_url: string | null
          created_at: string
        }
      }
    }
  }
}
EOF
printf 'create table foods (\n  id uuid primary key,\n  image_urls text[],\n  photo_url text\n);\n' > "$O/supabase/migrations/001.sql"
printf 'export interface Food { id: string; image_urls?: string[]; photo_url?: string }\n' > "$O/lib/types/food.ts"
printf 'import { Food } from "../types/food"\nexport function addFood(f: Food) { return db.insert({ image_urls: f.image_urls, photo_url: f.photo_url }) }\nexport function readFood() { return row.image_urls ?? row.photo_url }\n' > "$O/lib/db/foods.ts"
printf 'export async function autoSave(urls: string[]) { await foodsRepo.update({ image_urls: urls }) }\n' > "$O/lib/services/image-auto-save.ts"
printf 'import { Food } from "../../lib/types/food"\nexport function Gallery(f: Food) { const key = "pendingImages"; sessionStorage.setItem("pendingImages", "x"); return f.image_urls?.length }\n' > "$O/features/foods/gallery.tsx"
printf 'import { Food } from "../lib/types/food"\ntest("x", () => { sessionStorage.getItem("pendingImages"); expect((f as Food).image_urls).toEqual([]) })\n' > "$O/__tests__/gallery.test.ts"
printf 'export function restore() { return sessionStorage.getItem("pendingImages") }\n' > "$O/features/foods/restore.ts"
go add -A >/dev/null; go commit -q -m init >/dev/null

out=$("$SCRIPT" objects -C "$O" 2>&1); rc=$?
[ "$rc" = 0 ] || fail "objects exits 0" "$out"
printf '%s\n' "$out" | grep -q '^# aim objects — inventory' && ok "objects: header" || fail "objects header" "$(printf '%s\n' "$out" | head -1)"
row_img=$(printf '%s\n' "$out" | grep '| `foods.image_urls` |' | head -1)
row_photo=$(printf '%s\n' "$out" | grep '| `foods.photo_url` |' | head -1)
[ -n "$row_img" ] && [ -n "$row_photo" ] && ok "objects: both columns listed" || fail "columns listed" "$out"
printf '%s' "$row_img" | grep -q '| column | 6 | 5 | 2 | 1 | 2 |' && ok "objects: image_urls — 6 touchers (sql, type, db, service, ui, test), 5 layers, 2 writers, 1 test, 2 storage kinds" || fail "image_urls counts" "$row_img"
printf '%s' "$row_photo" | grep -q '| column | 3 | 3 | 1 | 0 | 1 |' && ok "objects: photo_url — 3 touchers, 3 layers, 1 writer, 0 tests, 1 storage kind" || fail "photo_url counts" "$row_photo"
ri=$(printf '%s' "$row_img" | cut -d'|' -f2 | tr -d ' '); rp=$(printf '%s' "$row_photo" | cut -d'|' -f2 | tr -d ' ')
[ "$ri" -lt "$rp" ] && ok "objects: image_urls ranks above photo_url" || fail "ranking" "img=$ri photo=$rp"
printf '%s\n' "$out" | grep -q '| `id` |' && fail "objects: stoplisted column id leaked" || ok "objects: stoplist drops id"
printf '%s\n' "$out" | grep -q '| `Food` | type |' && ok "objects: exported type Food inventoried" || fail "type" "$out"
printf '%s\n' "$out" | grep -q '| `pendingImages` | storage-key |' && ok "objects: sessionStorage key inventoried" || fail "storage key" "$out"
printf '%s' "$row_img" | grep -q "rg -l -w -F 'image_urls'" && ok "objects: row carries a reproducing found-by" || fail "objects found-by" "$row_img"

out=$("$SCRIPT" objects --area 'lib/' -C "$O" 2>&1)
printf '%s\n' "$out" | grep -q '| `foods.image_urls` | column | 3 |' && ! printf '%s\n' "$out" | grep -q '| `foods.photo_url` |' && ok "objects --area: touchers counted INSIDE the area (image_urls 3 under lib/); photo_url (2) drops below the floor" || fail "area" "$out"
out=$("$SCRIPT" objects --area 'nothing-matches-this' -C "$O" 2>&1)
printf '%s\n' "$out" | grep -q 'no object reached --min-touchers' && ok "objects --area with no match -> honest empty row" || fail "area empty" "$out"
out=$("$SCRIPT" objects --min-touchers 99 -C "$O" 2>&1)
printf '%s\n' "$out" | grep -q 'no object reached --min-touchers 99' && ok "objects: --min-touchers prunes to an honest empty row" || fail "min-touchers" "$out"
E="$W/empty"; mkdir -p "$E"; git -C "$E" init -q
out=$("$SCRIPT" objects -C "$E" 2>&1); rc=$?
[ "$rc" = 0 ] && printf '%s\n' "$out" | grep -q 'no candidates found' && ok "objects: a tree with no sources says so" || fail "empty tree" "$out"

# --- assurance ---------------------------------------------------------------------------
if grep -nE '(^|[^[:alnum:]_-])(claude|codex|droid)[[:space:]]|subagent' "$SCRIPT" >/dev/null; then fail "aim.sh invokes an agent"; else ok "aim.sh spawns nothing"; fi
miss=""; for f in PROBE: SCHEDULE: MODE: ON-FAILURE:; do grep -q "$f" "$SCRIPT" || miss="$miss $f"; done
[ -z "$miss" ] && ok "4-field assurance declaration present" || fail "assurance declaration missing:$miss"

echo "---"; echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
