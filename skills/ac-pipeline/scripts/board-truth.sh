#!/usr/bin/env bash
# board-truth.sh — Scan F: flag open beads whose work may already have merged.
#
# An open bead whose work has landed keeps its `refined` label and keeps appearing in
# `br ready`, so a conductor selects it as ordinary implement work and spends a child
# discovering the code already exists. No other scan catches it: ac-tidy's staleness is
# age-based, and Scans A-E never read a commit message.
#
# ADVISORY ONLY. Prints a shortlist and exits 0. It must never close, label or defer a
# bead: a false stale makes the conductor skip real work, which is worse than the wasted
# child this exists to prevent.
#
# Usage:  board-truth.sh [--cov-base <ref>] [--repo <dir>]
# Output: `board-truth: N open bead(s) ...` then one `<id>\t<epoch>` line per flag.
set -uo pipefail

COV_BASE=""
REPO="."
while [ $# -gt 0 ]; do
  case "$1" in
    --cov-base) COV_BASE="${2:-}"; shift 2 ;;
    --repo)     REPO="${2:-.}"; shift 2 ;;
    *) echo "board-truth.sh: unknown arg '$1'" >&2; exit 64 ;;
  esac
done
# A blind source reports DEGRADED on stdout, never silence — silence reads as clean.
cd "$REPO" 2>/dev/null || { echo "board-truth: UNKNOWN — repo '$REPO' unreadable"; exit 0; }

# Window anchored on the last release tag, never on the review mark: a moving anchor
# shrinks the window every time a batch closes.
if [ -z "$COV_BASE" ]; then
  COV_BASE=$(git describe --tags --match 'v*' --abbrev=0 2>/dev/null)
  [ -n "$COV_BASE" ] || COV_BASE=$(git rev-list --max-parents=0 HEAD 2>/dev/null | tail -1)
fi
[ -n "$COV_BASE" ] || { echo "board-truth: 0 open bead(s) — no git history"; exit 0; }

D="${ARTIFACTS_DIR:-/tmp/ac_board_truth}"; mkdir -p "$D"

# Flatten to one record per commit; bodies span lines.
git log "$COV_BASE..HEAD" --format='%ct|%H|%s|%b' 2>/dev/null \
  | awk '/^[0-9]+\|/{if(r)print r; r=$0; next}{r=r" "$0} END{if(r)print r}' \
  | tee "$D/commits-flat" >/dev/null

# Only two shapes count as a claim that a bead was WORKED: an id in the SUBJECT, or an id
# introduced by a `Bead:`/`Beads:` trailer. A bare mention in prose does not count — ledger
# and report commits list dozens of ids they never touched. Bookkeeping commits are dropped
# wholesale: they name beads without implementing them.
awk -F'|' '{ ct=$1+0; subj=$3
    if (subj ~ /^chore\(beads\)/ || $0 ~ /\[no-bead\]/) next
    body=""; for(i=4;i<=NF;i++) body=body "|" $i
    n=split(subj, t, /[^A-Za-z0-9._-]/)
    for(i=1;i<=n;i++) if (t[i] ~ /^bd-[A-Za-z0-9._-]+$/) if (ct>seen[t[i]]+0) seen[t[i]]=ct
    # Split on the field separator too: the flattener prefixes each body field with `|`,
    # so a trailer that STARTS the body arrives as `|Bead:` and would never match.
    m=split(body, w, /[|[:space:]]+/)
    for(i=1;i<m;i++) if (w[i] ~ /^[Bb]eads?:$/ && w[i+1] ~ /^bd-[A-Za-z0-9._-]+$/) if (ct>seen[w[i+1]]+0) seen[w[i+1]]=ct
  } END { for (k in seen) printf "%s\t%d\n", k, seen[k] }' "$D/commits-flat" \
  | tee "$D/cited" >/dev/null

br list --status open --limit 0 --json 2>/dev/null \
  | jq -r '.issues[] | [.id, .updated_at, .created_at] | @tsv' 2>/dev/null \
  | tee "$D/open-beads" >/dev/null

to_epoch() { s=${1%.*}; s=${s%Z}
  date -u -j -f '%Y-%m-%dT%H:%M:%S' "$s" +%s 2>/dev/null || date -u -d "$1" +%s 2>/dev/null; }

: | tee "$D/board-truth" >/dev/null
while IFS="$(printf '\t')" read -r id upd crt; do
  [ -n "$id" ] || continue
  cit=$(awk -F'\t' -v k="$id" '$1==k{print $2}' "$D/cited"); [ -n "$cit" ] || continue
  ue=$(to_epoch "$upd"); ce=$(to_epoch "$crt")
  [ -n "$ue" ] && [ -n "$ce" ] || continue
  # Must post-date the last touch AND not be the commit that FILED the bead: a review
  # commit cites the beads it creates, which is never evidence the work is done.
  [ "$cit" -gt "$ue" ] && [ "$cit" -gt $(( ce + 7200 )) ] \
    && printf '%s\t%s\n' "$id" "$cit" >> "$D/board-truth"
done < "$D/open-beads"

N=$(wc -l < "$D/board-truth" | xargs)
echo "board-truth: ${N:-0} open bead(s) cited by a later non-bookkeeping commit — VERIFY, never auto-close"
cat "$D/board-truth"
exit 0
