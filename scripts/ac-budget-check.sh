#!/usr/bin/env bash
#
# ac-budget-check.sh — the lean-pipeline anti-drift assertion (lint Check 23).
#
# ASSURANCE — MODE: blocking · ON-FAILURE: closed. Every leg fails CLOSED: a discovery set
# that resolves to nothing exits non-zero carrying NOT-GATED, because a cap that measured
# no files is not a cap that held.
#
# WHY A SCRIPT AND NOT A RULE IN PROSE: the plan's biggest named risk for the lean
# pipeline is cultural — the files staying small — and every previous "keep it small" rule
# in this registry was prose, and every one of them lost. The measured evasion is specific:
# per-file caps "held" while references/ grew ~11x. So the budget is counted over the
# LOADED PATH, and the mandatory-load set is DERIVED from the SKILL.md pointers rather than
# listed here — a hardcoded list of pointers is the same evasion with an extra step.
#
# FAMILY MEMBERSHIP is an EXPLICIT list, never a glob: post-rename every member is ac-*
# named, so a `skills/ac-*/` sweep would wrongly swallow the fat retained skills
# (ac-hygiene, ac-dashboard, ...). ac-review IS family membership — it hosts the merged
# post-batch review mode — but its manual-panel body is fat BY DESIGN, so it sits OUTSIDE
# the cap arithmetic below; its diet is the no-net-growth ratchet (lint Check 14) and
# Check 15's conductor ceiling. The cap legs measure the six lean workflow skills + the
# constitution.
#
# THE LEGS:
#   1. family      <=800 lines of SKILL.md across the six lean workflow skills + this
#                  constitution, total. (Per-file <=120 is constitution GUIDANCE,
#                  deliberately not a lint tier: the family cap binds first,
#                  7 x 120 = 840 > 800.)
#   2. three numbers, derived from the pointers AND each SKILL.md's own mode table:
#                  SPINE (every SKILL.md; reported, soft-warns) · WORST PATH (spine +
#                  unconditional refs + each skill's heaviest mode; 1,200 is a TARGET
#                  that WARNS when passed, because it is what actually enters context
#                  and the right size is not known) · TOTAL (everything;
#                  reported, never capped). references/ AND workflows/ both count. A
#                  pointer that resolves to nothing FAILS; a file no SKILL.md points at
#                  FAILS as uncounted; a mode row naming a missing file FAILS; workflows/
#                  with no mode table is NOT-GATED — fat cannot hide either
#                  way. ac-pipeline's OWN references/ are owner-hosted shared substrate
#                  consulted on demand by non-family ceremonies, not family mandatory
#                  load, so they are outside this leg (and reported as canon by Leg 3).
#   3. canon       lines of pre-existing canon the lean skills point at are REPORTED,
#                  never capped. A number nobody prints is a number nobody defends.
#   4. RETIRED (a: retires with its subject) — asserted the standalone ac2-pipeline
#                  constitution never grew a references/ or scripts/ dir. At the ac2→ac
#                  merge the constitution moved INTO ac-pipeline, which legitimately hosts
#                  the owner-hosted operating contracts there; the no-subdirs bound now
#                  applies to the constitution CORE in SKILL.md, enforced by review.
#   5. assurance   every lean script declares PROBE / SCHEDULE / MODE / ON-FAILURE. lint
#                  Check 21 reads only hooks/hooks.json and structurally cannot see these.
#                  Discovery set: the six workflow skills' scripts/*.sh PLUS the named
#                  skills/_tools/polish-fixpoint.sh (the one lean script that lives
#                  outside any member dir, so a glob-only set would silently report zero).
#                  ac-pipeline/scripts/*.sh predate the triad convention, are shared
#                  substrate (not family-owned machinery), and carry their own test files.
#   6. RETIRED (a: retires with its subject) — resolved /ac2-* invocations because Check
#                  2's /ac-[a-z] pattern structurally could not see them. The rename
#                  erased that blind spot: Check 2 now resolves every invocation the
#                  family makes.
#
# Usage:  ac-budget-check.sh [<repo root>]
# Exit 0  every leg holds · Exit 1 at least one violation · Exit 2 usage error
set -uo pipefail

FAMILY_CAP=800
LOADED_TARGET=1200   # a TARGET, not a cap (human ruling 2026-08-29): steer toward it, warn past it, never refuse on it

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
[ -d "$ROOT" ] || { echo "usage: $0 [<repo root>]" >&2; exit 2; }

RC=0
abc_fail() { echo "FAIL: $*"; RC=1; }
count_lines() { [ -f "$1" ] && wc -l <"$1" | tr -d ' ' || echo 0; }

# Family membership (all seven) vs the cap-measured set (six — see header) vs the
# pointer/assurance-measured set (five — the workflow skills; ac-pipeline's own
# references/ are owner-hosted shared substrate outside the loaded-path and assurance
# legs, and its scripts predate the triad convention and carry their own test files).
LEAN_SKILLS="ac-plan ac-polish ac-beadify ac-implement ac-review ac-publish ac-pipeline"
CAP_SKILLS="ac-plan ac-polish ac-beadify ac-implement ac-publish ac-pipeline"
REF_SKILLS="ac-plan ac-polish ac-beadify ac-implement ac-publish"

# --- Leg 1: the family cap -------------------------------------------------------------
SKILL_MDS=""
for name in $CAP_SKILLS; do
  [ -f "$ROOT/skills/$name/SKILL.md" ] || continue
  SKILL_MDS="$SKILL_MDS $ROOT/skills/$name/SKILL.md"
done

if [ -z "${SKILL_MDS// /}" ]; then
  echo "FAIL: NOT-GATED — no lean-family SKILL.md found under $ROOT/skills (expected one of: $CAP_SKILLS); the caps measured nothing"
  exit 1
fi

FAMILY=0
SKILL_COUNT=0
for f in $SKILL_MDS; do
  FAMILY=$(( FAMILY + $(count_lines "$f") ))
  SKILL_COUNT=$(( SKILL_COUNT + 1 ))
done
if [ "$FAMILY" -gt "$FAMILY_CAP" ]; then
  abc_fail "lean family SKILL.md total $FAMILY/$FAMILY_CAP lines across $SKILL_COUNT skills — growth is bought with deletion, or by retiring a Calibration"
else
  echo "ac-budget: family $FAMILY/$FAMILY_CAP lines across $SKILL_COUNT SKILL.md"
fi

# --- Leg 2: spine / worst path / total, DERIVED from the pointers and the mode tables ---
#
# Three numbers, one pass. The old single "loaded path" was wrong in BOTH directions and
# they nearly cancelled: it summed every checklist as if all loaded at once (over by ~150 on
# ac-polish, where exactly one loads per run) and it never looked at workflows/ at all
# (under by 145, same skill). A number wrong twice that happens to look plausible is worse
# than a number that is honestly off.
#
#   spine       every lean SKILL.md. Reported, with a SOFT warning above SPINE_WARN — that is
#               the progressive-disclosure signal, not a gate.
#   worst path  spine + every unconditional reference + each skill's HEAVIEST mode. This is
#               what actually enters context on the heaviest run, so it carries the hard cap.
#   total       spine + every reference + every workflow. Reported, never capped, so a
#               relocation stays visible instead of vanishing into an uncounted directory.
#
# MODE MEMBERSHIP IS DERIVED, NOT DECLARED TWICE. A SKILL.md that runs in modes already
# carries a table whose header names `mode` — it needs that table to operate. Any
# references/ or workflows/ path in a row of that table is scoped to the mode in the row's
# first cell; everything else a SKILL.md points at is unconditional. Add a mode, add a
# row, the numbers follow. There is no second list to keep in step.
SPINE_WARN=${SPINE_WARN:-700}

# Pointer discovery: references/ AND workflows/, resolved family-wide for sibling citations.
COUNTED=""        # every counted file, absolute path, deduplicated
SCOPED=""         # "path<TAB>skill<TAB>mode" for mode-scoped files
for f in $SKILL_MDS; do
  skill_dir=$(dirname "$f"); sname=$(basename "$skill_dir")
  # A references/ or workflows/ token PRECEDED BY '/' is the tail of a foreign-skill path
  # (`skill-builder/references/x.md`) — a citation of shared canon, not a family load. It
  # resolves nowhere in the family, so matching it produced a false "pointer nobody kept" on
  # a file that exists (ac-check23-leg2-cross-family-citation-gy75). grep -oE has no
  # lookbehind: require a non-path character (or line start) before the token, then strip it.
  for ref in $(grep -oE '(^|[^/A-Za-z0-9_.-])(skills/ac-[a-z0-9-]+/)?(references|workflows)/[A-Za-z0-9._-]+\.md' "$f" \
                | sed -E 's|^[^/A-Za-z0-9_.-]||' | sort -u); do
    case "$ref" in
      skills/*) path="$ROOT/$ref" ;;
      *)        path="$skill_dir/$ref" ;;
    esac
    if [ ! -f "$path" ]; then
      hits=""
      for name in $CAP_SKILLS; do
        cand="$ROOT/skills/$name/$ref"; [ -f "$cand" ] && hits="$hits $cand"
      done
      set -- $hits
      if [ $# -eq 1 ]; then
        path="$1"
      elif [ $# -gt 1 ]; then
        abc_fail "$sname/SKILL.md points at '$ref', which exists in more than one lean skill ($*) — an ambiguous pointer counts a file by coin toss"
        continue
      else
        abc_fail "$sname/SKILL.md points at '$ref', which does not exist — a pointer to a reference nobody kept"
        continue
      fi
    fi
    case " $COUNTED " in *" $path "*) ;; *) COUNTED="$COUNTED $path" ;; esac
  done

  # Mode table: rows under a header containing `mode`; first cell is the mode key.
  rows=$(awk '
    /^\|/ {
      if (tolower($0) ~ /\|[[:space:]]*mode[[:space:]]*\|/) { inmode=1; next }
      if (inmode && $0 ~ /^\|[[:space:]]*-+/) next
      if (inmode) {
        n=split($0, c, "|"); m=c[2]; gsub(/[[:space:]`]/, "", m)
        line=$0
        while (match(line, /(references|workflows)\/[A-Za-z0-9._-]+\.md/)) {
          print m "\t" substr(line, RSTART, RLENGTH); line=substr(line, RSTART+RLENGTH)
        }
      }
      next
    }
    { inmode=0 }' "$f")
  while IFS=$'\t' read -r mode rel; do
    [ -n "$mode" ] && [ -n "$rel" ] || continue
    path="$skill_dir/$rel"
    [ -f "$path" ] || { abc_fail "$sname/SKILL.md mode '$mode' names '$rel', which does not exist — a mode row pointing at nothing"; continue; }
    SCOPED="$SCOPED
$path	$sname	$mode"
  done <<EOF
$rows
EOF

  # A skill with workflows/ but no parseable mode table cannot have its worst path computed.
  # Workflows are mode-bound by construction, so silence here would be a guess.
  if [ -d "$skill_dir/workflows" ] && ls "$skill_dir/workflows"/*.md >/dev/null 2>&1 && [ -z "$(printf '%s' "$rows" | tr -d '[:space:]')" ]; then
    abc_fail "NOT-GATED — $sname has workflows/ but no mode table names them; its worst path cannot be derived and is not claimed"
  fi
done

# Uncounted fat: ANY references/ or workflows/ file nobody points at.
for name in $REF_SKILLS; do
  for sub in references workflows; do
    d="$ROOT/skills/$name/$sub/"
    [ -d "$d" ] || continue
    for r in "$d"*; do
      [ -f "$r" ] || continue
      case " $COUNTED " in
        *" $r "*) ;;
        *) abc_fail "NOT-GATED — ${r#$ROOT/} exists but no lean SKILL.md points at it, so no number here ever counted it" ;;
      esac
    done
  done
done

# The three numbers.
[ -n "${COUNTED// /}" ] || abc_fail "NOT-GATED — zero mandatory-load files discovered; every number below would be one it never had to earn"
scope_of() {  # <path> -> "skill<TAB>mode" or ""
  printf '%s\n' "$SCOPED" | awk -F'\t' -v p="$1" '$1==p {print $2"\t"$3; exit}'
}
UNCOND_LINES=0; TOTAL_REF_LINES=0; REF_COUNT=0
MODE_LINES=""   # "skill<TAB>mode<TAB>lines" accumulated
for r in $COUNTED; do
  n=$(count_lines "$r"); REF_COUNT=$(( REF_COUNT + 1 )); TOTAL_REF_LINES=$(( TOTAL_REF_LINES + n ))
  sc=$(scope_of "$r")
  if [ -z "$sc" ]; then
    UNCOND_LINES=$(( UNCOND_LINES + n ))
    echo "ac-budget: counted ${r#$ROOT/} ($n lines, unconditional)"
  else
    MODE_LINES="$MODE_LINES
$sc	$n"
    echo "ac-budget: counted ${r#$ROOT/} ($n lines, mode ${sc#*	} of ${sc%	*})"
  fi
done
# Per skill, the heaviest mode; summed across skills. Computed, never assumed.
HEAVIEST_REPORT=$(printf '%s\n' "$MODE_LINES" | awk -F'\t' 'NF==3 { s[$1"\t"$2]+=$3 }
  END { for (k in s) { split(k, a, "\t"); if (s[k] > mx[a[1]]) { mx[a[1]]=s[k]; which[a[1]]=a[2] } }
        tot=0; for (x in mx) { tot+=mx[x]; printf "%s\t%s\t%d\n", x, which[x], mx[x] }
        printf "TOTAL\t-\t%d\n", tot }')
HEAVIEST_LINES=$(printf '%s\n' "$HEAVIEST_REPORT" | awk -F'\t' '$1=="TOTAL"{print $3}')
[ -n "$HEAVIEST_LINES" ] || HEAVIEST_LINES=0
printf '%s\n' "$HEAVIEST_REPORT" | awk -F'\t' '$1!="TOTAL" && NF==3 {printf "ac-budget: %s heaviest mode is %s (%d lines)\n", $1, $2, $3}'

SPINE=$FAMILY
WORST=$(( SPINE + UNCOND_LINES + HEAVIEST_LINES ))
TOTAL=$(( SPINE + TOTAL_REF_LINES ))

if [ "$SPINE" -gt "$SPINE_WARN" ]; then
  echo "ac-budget: WARN spine $SPINE lines is above $SPINE_WARN — that is the always-loaded surface; consider moving mode-specific text into a mode-scoped reference (progressive disclosure), not a cap breach"
else
  echo "ac-budget: spine $SPINE lines (every lean SKILL.md; warns above $SPINE_WARN)"
fi
if [ "$WORST" -gt "$LOADED_TARGET" ]; then
  echo "ac-budget: WARN worst path $WORST is over the $LOADED_TARGET target by $(( WORST - LOADED_TARGET )) (spine $SPINE + unconditional refs $UNCOND_LINES + heaviest modes $HEAVIEST_LINES) — this is what enters context on the heaviest run; look for text that could become mode-scoped or a pointer, and note that relocating into references/ or workflows/ does not reduce it"
else
  echo "ac-budget: worst path $WORST/$LOADED_TARGET target (spine $SPINE + unconditional $UNCOND_LINES + heaviest modes $HEAVIEST_LINES)"
fi
echo "ac-budget: total inventory $TOTAL lines (spine $SPINE + $REF_COUNT reference/workflow file(s) $TOTAL_REF_LINES) — REPORTED, never capped"

# --- Leg 3: pointed-at canon — REPORTED, never capped ----------------------------------
CANON=""
for f in $SKILL_MDS; do
  # Canon is cited both ways in practice — `skills/x/references/y.md` and the bare
  # `x/references/y.md` — so normalise before resolving, or the report reads zero.
  for c in $(grep -oE '(skills/)?[a-z0-9][a-z0-9-]*/(references?|workflows)/[A-Za-z0-9._-]+\.md' "$f" \
             | sed 's|^skills/||' | sed 's|^|skills/|' | sort -u); do
    family_ref=0
    for name in $CAP_SKILLS; do
      case "$c" in skills/"$name"/*) family_ref=1; break ;; esac
    done
    [ "$family_ref" -eq 1 ] && continue
    [ -f "$ROOT/$c" ] || continue
    case " $CANON " in *" $c "*) ;; *) CANON="$CANON $c" ;; esac
  done
done
CANON_LINES=0
CANON_FILES=0
for c in $CANON; do
  CANON_LINES=$(( CANON_LINES + $(count_lines "$ROOT/$c") ))
  CANON_FILES=$(( CANON_FILES + 1 ))
done
echo "ac-budget: pointed-at canon $CANON_LINES lines across $CANON_FILES file(s) — REPORTED, not capped (relocation-instead-of-reduction stays visible)"

# --- Leg 4: RETIRED — see header --------------------------------------------------------

# --- Leg 5: assurance-triad declarations for lean scripts ------------------------------
# *.test.sh is EXCLUDED. A harness IS a probe; requiring one to declare its own probe is
# circular, and scripts/harness-scheduling-check.sh already proves every harness IS RUN.
# Keeping them in was worse than useless: each harness contains the four field NAMES inside
# its own declaration self-check, so `grep -q` matched them and the leg passed for the wrong
# reason on every test file it discovered.
LEAN_SCRIPTS=""
for name in $REF_SKILLS; do
  for s in "$ROOT/skills/$name"/scripts/*.sh; do
    [ -f "$s" ] || continue
    case "$s" in *.test.sh) continue ;; esac
    LEAN_SCRIPTS="$LEAN_SCRIPTS $s"
  done
done
[ -f "$ROOT/skills/_tools/polish-fixpoint.sh" ] && LEAN_SCRIPTS="$LEAN_SCRIPTS $ROOT/skills/_tools/polish-fixpoint.sh"

if [ -z "${LEAN_SCRIPTS// /}" ]; then
  abc_fail "NOT-GATED — the lean script discovery set resolved to zero scripts; the declaration leg verified nothing"
else
  SCRIPT_COUNT=0
  for s in $LEAN_SCRIPTS; do
    SCRIPT_COUNT=$(( SCRIPT_COUNT + 1 ))
    missing=""
    # HEADER-SCOPED. A field mentioned anywhere in the body is prose about declarations,
    # not a declaration: the live scripts all declare by line 24, so 40 is generous and
    # still refuses a match buried in a function 300 lines down.
    for field in "PROBE:" "SCHEDULE:" "MODE:" "ON-FAILURE:"; do
      head -40 "$s" | grep -q "$field" || missing="$missing $field"
    done
    [ -z "$missing" ] || abc_fail "${s#$ROOT/} declares no$missing — a mechanism that does not say what it does when it breaks is not assured (Check 21 is hooks.json-scoped and cannot see this one)"
  done
  echo "ac-budget: assurance declarations — $SCRIPT_COUNT lean script(s) discovered"
fi

# --- Leg 6: RETIRED — see header --------------------------------------------------------

exit "$RC"
