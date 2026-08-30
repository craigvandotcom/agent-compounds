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
#   2. loaded path <=1,200 lines including every mandatory-load reference, derived from
#                  the pointers. A pointer that resolves to nothing FAILS; a references
#                  file no SKILL.md points at FAILS as uncounted — fat cannot hide either
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
LOADED_CAP=1200

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

# --- Leg 2: the loaded path, DERIVED from the pointers ---------------------------------
COUNTED=""
for f in $SKILL_MDS; do
  skill_dir=$(dirname "$f")
  for ref in $(grep -oE '(skills/ac-[a-z0-9-]+/)?references/[A-Za-z0-9._-]+\.md' "$f" | sort -u); do
    case "$ref" in
      skills/*) path="$ROOT/$ref" ;;
      *)        path="$skill_dir/$ref" ;;
    esac
    if [ ! -f "$path" ]; then
      # A relative pointer may cite a SIBLING's reference — ac-plan names ac-polish's
      # checklist as its bar. Resolve family-wide before calling it dangling; an ambiguous
      # basename is its own failure, because then the counted file is a coin toss.
      hits=""
      for name in $CAP_SKILLS; do
        cand="$ROOT/skills/$name/$ref"; [ -f "$cand" ] && hits="$hits $cand"
      done
      set -- $hits
      if [ $# -eq 1 ]; then
        path="$1"
      elif [ $# -gt 1 ]; then
        abc_fail "$(basename "$skill_dir")/SKILL.md points at '$ref', which exists in more than one lean skill ($*) — an ambiguous pointer counts a file by coin toss"
        continue
      else
        abc_fail "$(basename "$skill_dir")/SKILL.md points at '$ref', which does not exist — a pointer to a reference nobody kept"
        continue
      fi
    fi
    case " $COUNTED " in *" $path "*) ;; *) COUNTED="$COUNTED $path" ;; esac
  done
done

# A references file NOBODY points at is uncounted fat, which is exactly the measured
# evasion. Scan the six workflow skills' references/ only — ac-pipeline's own references/
# are owner-hosted shared substrate (see Leg 2 in the header), not family mandatory load.
for name in $REF_SKILLS; do
  d="$ROOT/skills/$name/references/"
  [ -d "$d" ] || continue
  for r in "$d"*; do
    [ -f "$r" ] || continue
    case " $COUNTED " in
      *" $r "*) ;;
      *) abc_fail "NOT-GATED — ${r#$ROOT/} exists but no lean SKILL.md points at it, so the loaded-path cap never counted it" ;;
    esac
  done
done

REF_COUNT=0
REF_LINES=0
for r in $COUNTED; do
  REF_LINES=$(( REF_LINES + $(count_lines "$r") ))
  REF_COUNT=$(( REF_COUNT + 1 ))
done
if [ "$REF_COUNT" -eq 0 ]; then
  abc_fail "NOT-GATED — zero mandatory-load references discovered; the loaded-path leg would report a number it never had to earn"
fi
LOADED=$(( FAMILY + REF_LINES ))
if [ "$LOADED" -gt "$LOADED_CAP" ]; then
  abc_fail "lean loaded path $LOADED/$LOADED_CAP lines (SKILL.md $FAMILY + $REF_COUNT mandatory-load reference(s) $REF_LINES) — fat relocated into references/ still counts"
else
  echo "ac-budget: loaded path $LOADED/$LOADED_CAP lines (SKILL.md $FAMILY + $REF_COUNT reference(s) $REF_LINES)"
fi
for r in $COUNTED; do echo "ac-budget: counted reference ${r#$ROOT/} ($(count_lines "$r") lines)"; done

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
LEAN_SCRIPTS=""
for name in $REF_SKILLS; do
  for s in "$ROOT/skills/$name"/scripts/*.sh; do
    [ -f "$s" ] || continue
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
    for field in "PROBE:" "SCHEDULE:" "MODE:" "ON-FAILURE:"; do
      grep -q "$field" "$s" || missing="$missing $field"
    done
    [ -z "$missing" ] || abc_fail "${s#$ROOT/} declares no$missing — a mechanism that does not say what it does when it breaks is not assured (Check 21 is hooks.json-scoped and cannot see this one)"
  done
  echo "ac-budget: assurance declarations — $SCRIPT_COUNT lean script(s) discovered"
fi

# --- Leg 6: RETIRED — see header --------------------------------------------------------

exit "$RC"
