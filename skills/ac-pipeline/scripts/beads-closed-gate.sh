#!/usr/bin/env bash
# beads-closed-gate.sh — BEADS-CLOSED-GATE: the loop's own pre-close gate
# (ac-batch-close no longer checks beads itself).
#
# TRUNK-DIRECT REWRITE (bd-u2lo1.7): under trunk-direct there is no wave
# branch and no commit range to scope against. Work partitioning is now
# CLAIM-AT-SELECTION — a conductor marks its whole selected batch
# `in_progress` + assignee (its Agent Mail AGENT_NAME) at selection time,
# BEFORE any implementation (see ac-loop Phase 1/2, ac-implement Phase 1a).
# The gate's scope is therefore simply: `br list` filtered to
# `assignee ∈ <identities> && status != closed`. No commit-trailer parsing,
# no merge-base range computation, no wave-label lookup — the assignee IS the
# scope.
#
# UNION OF IDENTITIES (bd-w504y): a single batch may be claimed under MORE
# THAN ONE Agent Mail identity. ac-loop claims the batch under its own name
# (e.g. BlueLake), but a delegated ac-implement session self-registers a
# DIFFERENT name (e.g. SunnyBear; ac-loop's name is NOT inherited) and its
# incremental/replacement-bead claims land under THAT identity. Querying only
# the loop identity silently MISSES the delegate's open beads → a fail-OPEN of
# the exact safety gate. So this gate now accepts ONE OR MORE assignees (every
# positional arg = the union) and checks the UNION of their claimed sets.
#   The invoking skill MUST pass every identity that claimed into this batch:
#   the loop identity PLUS each delegated ac-implement identity it was told
#   about (ac-implement reports its registered name back in its summary, and
#   ALSO threads the conductor's claim identity onto its incremental claims —
#   belt-and-suspenders, see ac-implement Phase 1a). If no positional assignee
#   is given, $AGENT_NAME is the sole fallback identity.
#
# FAIL-CLOSED (bd-w504y): the gate must never quietly say "safe to close" when
# it cannot actually see the batch.
#   * No assignee determinable (no positional arg, no $AGENT_NAME) → exit 2.
#   * The UNION claimed-set is EMPTY — every given identity returns zero beads,
#     even with `--all` — → the gate is being asked about a batch that nothing
#     is claimed under, which almost always means the assignee set is
#     wrong/incomplete (a delegated identity was dropped) = fail-open risk. So
#     warn loudly and exit 2, UNLESS `--allow-empty` is passed (the caller has
#     asserted the board is legitimately empty).
#
# Assignees come from the positional args if any; else from `$AGENT_NAME` (the
# conductor's Agent Mail identity, exported earlier in the invoking skill's
# session). Exports don't persist across bash tool calls — re-assert AGENT_NAME
# in the SAME call that runs this script, or pass the identities explicitly.
#
# Prints the set of genuinely open, IN-SCOPE beads (union across identities):
# status != closed, EXCLUDING `post-merge`-labelled beads — those are
# deliberately un-closeable until the merge ships (carried forward as known
# tails, listed in the PR body), never blockers.
#
# Exit 0 — the union in-scope open set is empty: safe to proceed to ac-batch-close.
# Exit 1 — genuinely open (non-post-merge) beads remain in the union: do NOT close.
# Exit 2 — br/jq query failed, no assignee determinable, OR empty claimed-set
#          without --allow-empty (fail-closed).
#
# --- progress.md completeness gate (ac-514; decision ac-x9a apply-modified) ---
# At the close checkpoint, parse the wave's progress.md (written by ac-implement
# Phase 1e — header `TARGET_BEADS={N}` + `KIND=implement`, per-bead
# `### Bead <id>: <title>` + a `- Status:` line, footer `COMPLETED: {done} / {N}`).
# Only `KIND=implement` files carry closure obligations; refine/beadify files are
# skipped in the union entirely (absent KIND = implement, for back-compat):
#   * wave with N>1 beads: HARD-FAIL the close if progress.md lacks a per-bead
#     result entry for each bead OR the `COMPLETED: n/N` tally is absent/short
#     (message names the missing in-scope bead ids).
#   * wave with N==1 bead (incl. investigation-only one-line-verdict waves):
#     WARN-and-record, never block.
# The progress file(s) are located from REPEATED `--progress <path>` flags, else
# `$PROGRESS_FILE`, else `$ARTIFACTS_DIR/progress.md`. If none resolves, the
# completeness check is SKIPPED (a caller that did not opt in keeps the pre-ac-514
# behavior) — the open-bead gate below is unaffected. Evidence: RUN
# 20260716-111224-31570 shipped 3/7 waves with only a 3-line claim header, forcing
# the retrospective to reconstruct a 6-bead wave from git log.
#
# MULTI-FILE UNION (ac-0wi): a PARALLEL wave's children each write their OWN
# progress.md (children never share a progress file — a design invariant). Scoping
# the in-scope set to ALL beads under the passed identities but validating per-bead
# entries against ONE file therefore ALWAYS false-fails: each child file is missing
# its siblings' beads. Fix: accept REPEATED --progress flags; PER-FILE structural
# checks (TARGET_BEADS / Status-line count / COMPLETED tally) stay unchanged, but
# the identity-first COVERAGE check now requires each in-scope bead id to appear in
# the UNION of '### Bead <id>' entries across ALL provided files. A parallel wave
# passes every child's progress.md as repeated --progress flags in ONE call.
# Single-file callers are unaffected (back-compat).
#
# EXPLICIT BATCH SCOPE (ac-0i1): the completeness in-scope set above was
# identity-LIFETIME — the UNION of every bead ever assigned to the passed
# identities, with no batch boundary. In a multi-batch run that makes every later
# ceremony re-demand per-bead entries (and --progress files) for EARLIER batches'
# beads (already gate-validated + report-committed), and mislabels a TARGET_BEADS=1
# wave as "multi-bead" because the N>1 conditional keyed on the identity-lifetime
# set size rather than the current batch. Decision ac-x9a only ever scoped the check
# to "the wave's progress.md". Fix: a conductor that KNOWS its batch may pass it
# explicitly as `--beads <id,id,...>` (comma-separated, repeatable). When given, the
# COMPLETENESS check — and its N>1 coverage conditional — scopes to EXACTLY those
# ids, checked against the UNION of provided --progress files; prior-batch beads
# under the same identity are neither demanded nor counted. The OPEN-bead check
# (below) is UNAFFECTED — it stays identity-wide, so a genuinely-open bead from ANY
# batch still blocks the close regardless of --beads. Without --beads, completeness
# falls back to the identity-lifetime set — byte-identical pre-ac-0i1 behavior.
#
# Usage: beads-closed-gate.sh [--allow-empty] [--progress <path> ...] [--beads <id,id,...>] <assignee1> [assignee2 ...]
#        beads-closed-gate.sh                 # falls back to $AGENT_NAME
set -o pipefail

# --- Out-of-scope bead-status-bleed check (non-blocking; bd-vtrlm) ---
# Detects whether this run's own .beads/issues.jsonl diff touches any
# PRE-EXISTING bead ID outside this conductor's own claimed (in-scope) set.
# A match means `br sync --flush-only` picked up a concurrent session's
# transient bead status (br sync exports the FULL local DB, not a scoped
# diff) -- flag it, don't block (often self-healing; see memory
# br-sync-exports-full-db-cross-branch-bleed). $1 = space/newline-separated
# in-scope id list (may be empty -- an empty declared scope means nothing
# claimed, so ANY pre-existing changed id is flagged). NOTE: .beads/issues.jsonl
# is JSON LINES (one bead object per line) — `jq -r '.id'` streams it directly;
# feeding it a single `[...]` JSON array breaks the stream (jq: "Cannot index
# array with \"id\"") and silently voids this check.
warn_bead_bleed() {
  local in_scope="$1"
  local old_ids changed_ids preexisting_changed out_of_scope
  old_ids=$(git show "${BASE_REF}:.beads/issues.jsonl" 2>/dev/null | jq -r '.id' | sort -u)
  changed_ids=$(git diff --unified=0 "${BASE_REF}..HEAD" -- .beads/issues.jsonl 2>/dev/null \
    | grep -E '^\+\{' | sed -E 's/^\+//' | jq -r '.id' 2>/dev/null | sort -u)
  preexisting_changed=$(comm -12 <(printf '%s\n' "$old_ids") <(printf '%s\n' "$changed_ids"))
  out_of_scope=$(comm -23 <(printf '%s\n' "$preexisting_changed" | sort -u) <(printf '%s\n' "$in_scope" | sort -u))
  if [ -n "$out_of_scope" ]; then
    echo "beads-closed-gate: WARNING -- this run's .beads/issues.jsonl diff changes bead(s) outside its own claimed scope (br sync cross-branch bleed -- see memory br-sync-exports-full-db-cross-branch-bleed):" >&2
    printf '  %s\n' $out_of_scope >&2
  fi
}

# --- progress.md completeness check (ac-514; multi-file union — ac-0wi) ---
# check_progress_completeness <in-scope-ids> <progress-file>...
# PER-FILE (unchanged single-file semantics): each provided file declares its own
# TARGET_BEADS=N. A file with N>1 must carry N '### Bead' entries, N '- Status:'
# lines, and a 'COMPLETED: n/N' tally with n>=N — else HARD-FAIL. A file with
# N<=1 (single-bead child, incl. one-line investigation verdicts) only WARNs on
# thinness, never blocks.
# UNION COVERAGE (identity-first, ac-0wi): when the in-scope BATCH is multi-bead
# (>1 id), every in-scope bead id must carry a '### Bead <id>' entry in SOME
# provided file (the UNION across all files) — else HARD-FAIL naming ONLY the
# truly-missing ids. A single-bead batch (<=1 id) never blocks on coverage.
# Back-compat: exactly one file reproduces the pre-multi-file behavior. A parallel
# wave passes every child's progress.md as repeated --progress flags in ONE call.
# A missing/unresolvable progress file is skipped in the union (warns). If NO file
# yields a TARGET_BEADS header: HARD-FAIL when at least one resolved file EXISTS on
# disk (the check would otherwise be a silent no-op — ac-ewgr.2), skip (return 0)
# when none exists (not opted in, or the file is simply absent).
check_progress_completeness() {
  local in_scope="$1"; shift
  local files=("$@")
  [ "${#files[@]}" -eq 0 ] && return 0   # not opted in — skip

  local union_ids="" valid_files=0 existing_files=0 structural_problem=""
  local pf n entry_count status_count tally done_n ids kind
  for pf in "${files[@]}"; do
    [ -z "$pf" ] && continue
    if [ ! -f "$pf" ]; then
      echo "beads-closed-gate: WARNING — progress file not found at '$pf'; skipping it in the completeness union." >&2
      continue
    fi

    # KIND header — only implement-kind files carry closure obligations. Refine and
    # beadify children stamp beads and ship no code, so their progress files neither
    # contribute ids to the union nor owe per-bead result entries. Skip BEFORE the
    # existing_files++ : a prep file counted there would trip the PROGRESS-NO-HEADER
    # hard fail below, false-blocking a run whose only children were prep.
    # Absent KIND = implement (back-compat with files predating mixed-kind runs).
    kind=$(grep -oE '^KIND=[a-z]+' "$pf" 2>/dev/null | head -1 | sed -E 's/^KIND=//')
    if [ -n "$kind" ] && [ "$kind" != "implement" ]; then
      echo "beads-closed-gate: INFO — '$pf' is KIND=$kind (ships no code); not counted in the completeness union." >&2
      continue
    fi

    existing_files=$((existing_files + 1))
    n=$(grep -oE 'TARGET_BEADS=[0-9]+' "$pf" | head -1 | grep -oE '[0-9]+')
    if [ -z "$n" ]; then
      echo "beads-closed-gate: WARNING — no 'TARGET_BEADS=' header in '$pf'; skipping it in the completeness union." >&2
      continue
    fi
    valid_files=$((valid_files + 1))

    # Collect this file's '### Bead <id>' header ids into the running union. Bead
    # ids run up to the first whitespace or ':' (the title separator).
    ids=$(grep -oE '^### Bead[[:space:]]+[^[:space:]:]+' "$pf" 2>/dev/null | sed -E 's/^### Bead[[:space:]]+//')
    union_ids="${union_ids}"$'\n'"${ids}"

    entry_count=$(grep -oE '^### Bead [^:]+' "$pf" 2>/dev/null | sed -E 's/^### Bead[[:space:]]+//' | sed -E 's/[[:space:]]+$//' | grep -c . )
    status_count=$(grep -cE '^-[[:space:]]*Status:' "$pf" 2>/dev/null)
    tally=$(grep -oE 'COMPLETED:[[:space:]]*[0-9]+[[:space:]]*/[[:space:]]*[0-9]+' "$pf" 2>/dev/null | tail -1)

    if [ "$n" -le 1 ]; then
      # Single-bead FILE (incl. one-line investigation verdicts) — WARN only.
      if [ "$entry_count" -lt 1 ] || [ -z "$tally" ]; then
        echo "beads-closed-gate: WARNING (single-bead wave, N=$n) — progress.md '$pf' is thin (entries=$entry_count, tally='${tally:-none}'); recording, not blocking." >&2
      fi
      continue
    fi

    # Multi-bead FILE (N>1) — per-file structural self-consistency (HARD-FAIL).
    if [ "$entry_count" -lt "$n" ] || [ "$status_count" -lt "$n" ]; then
      structural_problem="${structural_problem:+$structural_problem; }file '$pf': only $entry_count per-bead '### Bead' entries ($status_count with a Status line) for N=$n beads"
    fi
    if [ -z "$tally" ]; then
      structural_problem="${structural_problem:+$structural_problem; }file '$pf': missing 'COMPLETED: n/N' tally"
    else
      done_n=$(printf '%s' "$tally" | grep -oE '[0-9]+' | head -1)
      if [ "${done_n:-0}" -lt "$n" ]; then
        structural_problem="${structural_problem:+$structural_problem; }file '$pf': COMPLETED tally short ('$tally', expected n=$n)"
      fi
    fi
  done

  # No file yielded a TARGET_BEADS header. Two sub-cases, deliberately split (ac-ewgr.2):
  #  - At least one resolved file EXISTS on disk but none carries the header -> HARD FAIL.
  #    The caller handed us a real progress file and the completeness union silently became
  #    a no-op (proven: a genuinely incomplete batch exited 0 even with --beads supplied,
  #    because this short-circuit runs BEFORE the coverage check). This repo already names
  #    "gate silently downgrades to a no-op" a defect (ac-batch-close-ci-gate-vacuous-adbq);
  #    a gate that cannot fail is not a gate.
  #  - No resolved file exists (not opted in, or the file is simply absent) -> skip, return 0.
  #    Keyed on FILE EXISTENCE, not on "was --progress passed", because the arg-resolution
  #    block ALWAYS appends $ARTIFACTS_DIR/progress.md when ARTIFACTS_DIR is set — explicit
  #    opt-in and silent default are indistinguishable here. This keeps
  #    ac-loop/references/beads-closed-gate-invocation.md's "omitting --progress skips the
  #    check entirely" true. Rejected: hard-fail on valid_files==0 unconditionally (breaks
  #    the file-missing case and contradicts that doc); keep-as-warning (no teeth).
  if [ "$valid_files" -eq 0 ]; then
    if [ "$existing_files" -gt 0 ]; then
      echo "beads-closed-gate: PROGRESS-NO-HEADER — $existing_files progress file(s) exist but none carries a 'TARGET_BEADS=' header, so the completeness check would be a silent no-op. Add 'TARGET_BEADS=<count>' to the progress.md header (ac-loop's CLAIM-AT-SELECTION step writes it)." >&2
      return 1
    fi
    return 0
  fi

  # Union coverage (identity-first): only a MULTI-bead in-scope batch blocks.
  # Identity-first (a2ce4bd) defeats the duplicate/extra-entry count-evasion where
  # raw `### Bead`/`Status:` counts reach N while a DISTINCT in-scope bead is
  # entirely absent — now checked across the whole union rather than a single file.
  local in_scope_count missing="" id
  in_scope_count=$(printf '%s\n' $in_scope | grep -c . )
  if [ "$in_scope_count" -gt 1 ]; then
    for id in $in_scope; do
      printf '%s\n' "$union_ids" | grep -qxF "$id" || missing="${missing:+$missing }$id"
    done
  fi

  local problems=""
  [ -n "$missing" ] && problems="in-scope bead(s) with no '### Bead <id>' result entry in any provided progress file: $missing"
  [ -n "$structural_problem" ] && problems="${problems:+$problems; }$structural_problem"

  if [ -n "$problems" ]; then
    echo "beads-closed-gate: PROGRESS-INCOMPLETE — $problems." >&2
    [ -n "$missing" ] && echo "  Missing per-bead result entry for: $missing" >&2
    echo "  A multi-bead wave must record a per-bead result + the COMPLETED tally so the retrospective reads every progress.md (decision ac-x9a); a parallel wave passes ALL child files via repeated --progress." >&2
    return 1
  fi
  return 0
}

# --- Parse flags + collect the union of assignee identities ---
ALLOW_EMPTY=0
ENV_PROGRESS="${PROGRESS_FILE:-}"   # single-file back-compat via env
PROGRESS_FILES=()                   # REPEATED --progress flags accumulate here (ac-0wi)
BEADS_SCOPE=""                      # explicit --beads batch scope (ac-0i1); empty = identity-lifetime
ASSIGNEES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --allow-empty) ALLOW_EMPTY=1; shift ;;
    --progress)
      # Guard the value: a trailing `--progress` with no path would `shift 2` past
      # the end, which bash rejects without shifting — spinning the while-loop
      # forever. A malformed gate invocation must fail LOUD (exit 2), never hang.
      if [ $# -lt 2 ]; then
        echo "beads-closed-gate: ERROR — --progress requires a path argument." >&2
        exit 2
      fi
      PROGRESS_FILES+=("$2"); shift 2 ;;
    --beads)
      # Explicit batch scope (ac-0i1): comma-separated bead ids, repeatable.
      # Same trailing-value guard as --progress (fail LOUD, never hang). Commas
      # become spaces so the completeness function can word-split the list.
      if [ $# -lt 2 ]; then
        echo "beads-closed-gate: ERROR — --beads requires a comma-separated id argument." >&2
        exit 2
      fi
      BEADS_SCOPE="${BEADS_SCOPE:+$BEADS_SCOPE }$(printf '%s' "$2" | tr ',' ' ')"; shift 2 ;;
    --) shift ;;
    *) ASSIGNEES+=("$1"); shift ;;
  esac
done

# Resolve the progress file SET (ac-0wi): explicit --progress flags (one or more)
# win; else the $PROGRESS_FILE env (single); else $ARTIFACTS_DIR/progress.md. A
# parallel wave passes every child's progress.md as repeated --progress flags in
# ONE call — the union of their '### Bead <id>' entries must cover the batch.
if [ "${#PROGRESS_FILES[@]}" -eq 0 ]; then
  if [ -n "$ENV_PROGRESS" ]; then
    PROGRESS_FILES+=("$ENV_PROGRESS")
  elif [ -n "${ARTIFACTS_DIR:-}" ]; then
    PROGRESS_FILES+=("$ARTIFACTS_DIR/progress.md")
  fi
fi

# Fall back to $AGENT_NAME only when no positional identity was given.
if [ "${#ASSIGNEES[@]}" -eq 0 ] && [ -n "${AGENT_NAME:-}" ]; then
  ASSIGNEES=("$AGENT_NAME")
fi
if [ "${#ASSIGNEES[@]}" -eq 0 ]; then
  echo "beads-closed-gate: no assignee provided — pass one or more identities as positional args (loop identity + each delegated ac-implement identity), or export AGENT_NAME before calling this script" >&2
  exit 2
fi

# HARD RULE (bd-w504y / ac-ycr.6; doctrine: agent-mail/references/agent-identity.md): FoggyCreek
# is the Tier-2 chore identity and may NEVER claim beads or be a gate assignee.
# A claimed-set under FoggyCreek always means a conductor fell back to the
# settings.json AGENT_NAME=FoggyCreek default instead of re-asserting its minted
# Tier-1 name — a misattribution that would otherwise surface only as a confusing
# empty/foreign claimed-set downstream. Reject it LOUDLY here, BEFORE the union
# claimed-set query, converting silent misattribution into an immediate error.
# (Checks the fully-resolved set, so a FoggyCreek fallback via $AGENT_NAME is
# caught too, not only an explicit positional arg.)
for a in "${ASSIGNEES[@]}"; do
  if [ "$a" = "FoggyCreek" ]; then
    echo "beads-closed-gate: REJECTED — 'FoggyCreek' is the Tier-2 chore identity and may NEVER claim beads or be a gate assignee (HARD RULE, agent-mail/references/agent-identity.md)." >&2
    echo "  A gate query under FoggyCreek means a conductor fell back to the settings.json AGENT_NAME default instead of re-asserting its minted Tier-1 name." >&2
    echo "  Pass the conductor's actual minted identity (plus each delegated ac-implement identity), never FoggyCreek." >&2
    exit 2
  fi
done

BASE_REF=$(git merge-base origin/main HEAD 2>/dev/null || git merge-base main HEAD 2>/dev/null)
if [ -z "$BASE_REF" ]; then
  echo "beads-closed-gate: could not determine merge-base with main" >&2
  exit 2
fi

# `br list --json` paginates (default --limit 50); --limit 0 = unlimited, so a
# single call always returns an identity's FULL claimed set regardless of batch
# size. `-a`/`--all` includes closed beads too — needed so the bleed check's
# in-scope id list covers beads an identity claimed AND has already closed (a
# closed-but-claimed id must not read as "out of scope"). Query each identity,
# then UNION the results (dedupe by id).
FULL_CLAIMED="[]"
for a in "${ASSIGNEES[@]}"; do
  part=$(br list --json --limit 0 --all --assignee "$a" | jq '.issues') || exit 2
  FULL_CLAIMED=$(jq -s 'add | unique_by(.id)' \
    <(printf '%s' "$FULL_CLAIMED") <(printf '%s' "$part")) || exit 2
done

# FAIL-CLOSED: an empty union claimed-set means the gate can't see any batch
# under the identities it was handed — refuse to green-light unless overridden.
CLAIMED_COUNT=$(printf '%s' "$FULL_CLAIMED" | jq 'length') || exit 2
if [ "$CLAIMED_COUNT" -eq 0 ] && [ "$ALLOW_EMPTY" -ne 1 ]; then
  echo "beads-closed-gate: FAIL-CLOSED — the union claimed-set is EMPTY for assignee(s): ${ASSIGNEES[*]}" >&2
  echo "  A batch was expected to be claimed under one of these identities, but br returned zero beads." >&2
  echo "  This usually means the wrong/incomplete assignee set was passed (a delegated ac-implement identity is missing)." >&2
  echo "  Refusing to report 'safe to close'. Pass EVERY claiming identity, or --allow-empty if the board is genuinely empty." >&2
  exit 2
fi

OPEN=$(echo "$FULL_CLAIMED" | jq \
  '[.[] | select(.status != "closed") | select((.labels // []) | index("post-merge") | not) | select(.issue_type != "epic")]') || exit 2

IN_SCOPE_IDS=$(echo "$FULL_CLAIMED" | jq -r '.[].id' | sort -u)
warn_bead_bleed "$IN_SCOPE_IDS"

# Completeness scope (ac-0i1): an explicit --beads batch scope wins over the
# identity-lifetime IN_SCOPE_IDS. When --beads is given, the completeness check
# (and its N>1 coverage conditional) scopes to EXACTLY those ids — prior-batch
# beads under the same identity are neither demanded nor counted. Without --beads,
# it falls back to IN_SCOPE_IDS (byte-identical pre-ac-0i1 behavior). The
# identity-wide warn_bead_bleed (above) and OPEN-bead check (below) are UNAFFECTED
# — a genuinely-open bead from any batch still blocks regardless of --beads.
if [ -n "$BEADS_SCOPE" ]; then
  COMPLETENESS_IDS=$(printf '%s\n' $BEADS_SCOPE | sort -u)
else
  COMPLETENESS_IDS="$IN_SCOPE_IDS"
fi

# Completeness gate (ac-514) — severity conditional on wave size; runs against the
# resolved progress file, names any missing in-scope bead ids. Skipped (rc 0) when
# no progress file was provided.
PROGRESS_RC=0
check_progress_completeness "$COMPLETENESS_IDS" "${PROGRESS_FILES[@]}" || PROGRESS_RC=1

echo "$OPEN"
OPEN_RC=0
[ "$(printf '%s' "$OPEN" | jq 'length')" -eq 0 ] || OPEN_RC=1

# Fail the gate if EITHER genuinely-open in-scope beads remain OR a multi-bead
# wave's progress.md is incomplete.
[ "$OPEN_RC" -eq 0 ] && [ "$PROGRESS_RC" -eq 0 ]
