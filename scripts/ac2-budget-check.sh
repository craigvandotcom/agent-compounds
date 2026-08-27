#!/usr/bin/env bash
#
# ac2-budget-check.sh — the ac2 anti-drift assertion (lint Check 23).
#
# ASSURANCE — MODE: blocking · ON-FAILURE: closed. Every leg fails CLOSED: a discovery set
# that resolves to nothing exits non-zero carrying NOT-GATED, because a cap that measured
# no files is not a cap that held.
#
# WHY A SCRIPT AND NOT A RULE IN PROSE: the plan's biggest named risk for ac2 is cultural —
# the files staying small — and every previous "keep it small" rule in this registry was
# prose, and every one of them lost. The measured evasion is specific: per-file caps "held"
# while references/ grew ~11x. So the budget is counted over the LOADED PATH, and the
# mandatory-load set is DERIVED from the SKILL.md pointers rather than listed here — a
# hardcoded list is the same evasion with an extra step.
#
# THE LEGS:
#   1. family      <=800 lines of skills/ac2-*/SKILL.md, total. (Per-file <=120 is
#                  constitution GUIDANCE, deliberately not a lint tier: the family cap
#                  binds first, 7 x 120 = 840 > 800.)
#   2. loaded path <=1,200 lines including every mandatory-load reference, derived from the
#                  pointers. A pointer that resolves to nothing FAILS; a references file no
#                  SKILL.md points at FAILS as uncounted — fat cannot hide either way.
#   3. canon       lines of pre-existing canon the ac2 skills point at are REPORTED, never
#                  capped. A number nobody prints is a number nobody defends.
#   4. shape       skills/ac2-pipeline/ has NO references/ and NO scripts/ dir (the
#                  constitution's own bound — overflow retires a Calibration, never grows
#                  a subdirectory).
#   5. assurance   every ac2 script declares PROBE / SCHEDULE / MODE / ON-FAILURE. lint
#                  Check 21 reads only hooks/hooks.json and structurally cannot see these.
#                  Discovery set: skills/ac2-*/scripts/*.sh PLUS the named
#                  skills/_tools/polish-fixpoint.sh (the one ac2 script that lives outside
#                  any ac2-* dir, so a glob-only set would silently report zero).
#   6. references  the ac2 family is finally SEEN by dead-reference resolution: lint Check
#                  2's pattern (/ac-[a-z]...) cannot match /ac2-anything. An INVOCATION of
#                  a nonexistent ac2 skill fails; a PATH citation of an unbuilt Phase-2/3
#                  skill is reported as a forward reference, not failed — this epic cites
#                  skills it has not built yet, by design.
#
# Usage:  ac2-budget-check.sh [<repo root>]
# Exit 0  every leg holds · Exit 1 at least one violation · Exit 2 usage error
set -uo pipefail

FAMILY_CAP=800
LOADED_CAP=1200

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
[ -d "$ROOT" ] || { echo "usage: $0 [<repo root>]" >&2; exit 2; }

RC=0
abc_fail() { echo "FAIL: $*"; RC=1; }
count_lines() { [ -f "$1" ] && wc -l <"$1" | tr -d ' ' || echo 0; }

# --- Leg 1: the family cap -------------------------------------------------------------
SKILL_MDS=""
for d in "$ROOT"/skills/ac2-*/; do
  [ -f "$d/SKILL.md" ] || continue
  SKILL_MDS="$SKILL_MDS $d/SKILL.md"
done

if [ -z "${SKILL_MDS// /}" ]; then
  echo "FAIL: NOT-GATED — no skills/ac2-*/SKILL.md found under $ROOT; the caps measured nothing"
  exit 1
fi

FAMILY=0
SKILL_COUNT=0
for f in $SKILL_MDS; do
  FAMILY=$(( FAMILY + $(count_lines "$f") ))
  SKILL_COUNT=$(( SKILL_COUNT + 1 ))
done
if [ "$FAMILY" -gt "$FAMILY_CAP" ]; then
  abc_fail "ac2 family SKILL.md total $FAMILY/$FAMILY_CAP lines across $SKILL_COUNT skills — growth is bought with deletion, or by retiring a Calibration"
else
  echo "ac2-budget: family $FAMILY/$FAMILY_CAP lines across $SKILL_COUNT SKILL.md"
fi

# --- Leg 2: the loaded path, DERIVED from the pointers ---------------------------------
COUNTED=""
for f in $SKILL_MDS; do
  skill_dir=$(dirname "$f")
  for ref in $(grep -oE '(skills/ac2-[a-z0-9-]+/)?references/[A-Za-z0-9._-]+\.md' "$f" | sort -u); do
    case "$ref" in
      skills/*) path="$ROOT/$ref" ;;
      *)        path="$skill_dir/$ref" ;;
    esac
    if [ ! -f "$path" ]; then
      # A relative pointer may cite a SIBLING's reference — ac2-plan names ac2-polish's
      # checklist as its bar. Resolve family-wide before calling it dangling; an ambiguous
      # basename is its own failure, because then the counted file is a coin toss.
      hits=""
      for cand in "$ROOT"/skills/ac2-*/"$ref"; do [ -f "$cand" ] && hits="$hits $cand"; done
      set -- $hits
      if [ $# -eq 1 ]; then
        path="$1"
      elif [ $# -gt 1 ]; then
        abc_fail "$(basename "$skill_dir")/SKILL.md points at '$ref', which exists in more than one ac2 skill ($*) — an ambiguous pointer counts a file by coin toss"
        continue
      else
        abc_fail "$(basename "$skill_dir")/SKILL.md points at '$ref', which does not exist — a pointer to a reference nobody kept"
        continue
      fi
    fi
    case " $COUNTED " in *" $path "*) ;; *) COUNTED="$COUNTED $path" ;; esac
  done
done

# A references file NOBODY points at is uncounted fat, which is exactly the measured evasion.
for d in "$ROOT"/skills/ac2-*/references/; do
  [ -d "$d" ] || continue
  for r in "$d"*; do
    [ -f "$r" ] || continue
    case " $COUNTED " in
      *" $r "*) ;;
      *) abc_fail "NOT-GATED — ${r#$ROOT/} exists but no ac2 SKILL.md points at it, so the loaded-path cap never counted it" ;;
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
  abc_fail "ac2 loaded path $LOADED/$LOADED_CAP lines (SKILL.md $FAMILY + $REF_COUNT mandatory-load reference(s) $REF_LINES) — fat relocated into references/ still counts"
else
  echo "ac2-budget: loaded path $LOADED/$LOADED_CAP lines (SKILL.md $FAMILY + $REF_COUNT reference(s) $REF_LINES)"
fi
for r in $COUNTED; do echo "ac2-budget: counted reference ${r#$ROOT/} ($(count_lines "$r") lines)"; done

# --- Leg 3: pointed-at canon — REPORTED, never capped ----------------------------------
CANON=""
for f in $SKILL_MDS; do
  # Canon is cited both ways in practice — `skills/x/references/y.md` and the bare
  # `x/references/y.md` — so normalise before resolving, or the report reads zero.
  for c in $(grep -oE '(skills/)?[a-z0-9][a-z0-9-]*/(references?|workflows)/[A-Za-z0-9._-]+\.md' "$f" \
             | sed 's|^skills/||' | sed 's|^|skills/|' | sort -u); do
    case "$c" in skills/ac2-*) continue ;; esac
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
echo "ac2-budget: pointed-at canon $CANON_LINES lines across $CANON_FILES file(s) — REPORTED, not capped (relocation-instead-of-reduction stays visible)"

# --- Leg 4: the constitution's own shape -----------------------------------------------
for sub in references scripts; do
  if [ -d "$ROOT/skills/ac2-pipeline/$sub" ]; then
    abc_fail "skills/ac2-pipeline/$sub/ exists — the constitution NEVER grows a $sub dir; overflow retires a Calibration instead"
  fi
done

# --- Leg 5: assurance-triad declarations for ac2 scripts -------------------------------
AC2_SCRIPTS=""
for s in "$ROOT"/skills/ac2-*/scripts/*.sh; do
  [ -f "$s" ] || continue
  AC2_SCRIPTS="$AC2_SCRIPTS $s"
done
[ -f "$ROOT/skills/_tools/polish-fixpoint.sh" ] && AC2_SCRIPTS="$AC2_SCRIPTS $ROOT/skills/_tools/polish-fixpoint.sh"

if [ -z "${AC2_SCRIPTS// /}" ]; then
  abc_fail "NOT-GATED — the ac2 script discovery set resolved to zero scripts; the declaration leg verified nothing"
else
  SCRIPT_COUNT=0
  for s in $AC2_SCRIPTS; do
    SCRIPT_COUNT=$(( SCRIPT_COUNT + 1 ))
    missing=""
    for field in "PROBE:" "SCHEDULE:" "MODE:" "ON-FAILURE:"; do
      grep -q "$field" "$s" || missing="$missing $field"
    done
    [ -z "$missing" ] || abc_fail "${s#$ROOT/} declares no$missing — a mechanism that does not say what it does when it breaks is not assured (Check 21 is hooks.json-scoped and cannot see this one)"
  done
  echo "ac2-budget: assurance declarations — $SCRIPT_COUNT ac2 script(s) discovered"
fi

# --- Leg 6: ac2 cross-reference resolution ---------------------------------------------
FORWARD=""
for d in "$ROOT"/skills/*/; do
  for f in "$d/SKILL.md" "$d"references/*.md "$d"workflows/*.md; do
    [ -f "$f" ] || continue
    # Invocation-shaped: line-start or whitespace, then /ac2-<name>. Must exist on disk.
    for tok in $(grep -oE '(^|[[:space:]])/ac2-[a-z][a-z-]*[a-z]' "$f" | tr -d ' \t' | sed 's|^/||' | sort -u); do
      [ -d "$ROOT/skills/$tok" ] || abc_fail "${f#$ROOT/} invokes /$tok but skills/$tok/ does not exist — the ac2 family was invisible to Check 2's /ac-* pattern"
    done
    # Path-shaped citations of ac2 skills that are not built yet: REPORTED, never failed.
    for p in $(grep -oE 'skills/ac2-[a-z][a-z-]*[a-z]/' "$f" | sed 's|/$||' | sort -u); do
      [ -d "$ROOT/$p" ] && continue
      case " $FORWARD " in *" ${p#skills/} "*) ;; *) FORWARD="$FORWARD ${p#skills/}" ;; esac
    done
  done
done
FWD_COUNT=$(printf '%s' "$FORWARD" | wc -w | tr -d ' ')
echo "ac2-budget: cross-references — $FWD_COUNT forward reference(s) to unbuilt ac2 skills (reported, not failed):${FORWARD:- none}"

exit "$RC"
