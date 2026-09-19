#!/usr/bin/env bash
#
# coordinator.sh — the ac2 swarm CLOSE-OUT. Runs once, at the end, by the coordinator.
#
# ASSURANCE
#   PROBE:      bash skills/ac-implement/scripts/coordinator.test.sh
#   SCHEDULE:   once per ac2 swarm run, at close-out; the harness runs on every
#               scripts/run-all-proofs.sh invocation, which lint.sh Check 20 audits.
#   MODE:       blocking
#   ON-FAILURE: closed
#
# THREE REFUSALS, AND NOTHING ELSE. Each one guards a failure that leaves NO TRACE when it
# happens — which is the whole reason this is a script and not another paragraph in the
# prompt. Everything else a coordinator does (spawn, wait, trigger CI, hand off to review)
# is visible when it goes wrong, and stays prose.
#
#   LEDGER-STALE  origin moved while the swarm ran. The beads DB never imported those rows,
#                 so flushing it OVERWRITES them. The file looks right, the commit looks
#                 normal, nothing errors, and the other writer's closes are simply gone.
#                 This is the refusal that earns the file.
#   ORPHANS       a worker died holding a claim. The bead is neither open nor progressing;
#                 it reads as busy forever and no sibling can take it. Liveness is a fact
#                 about the world — a prompt cannot reason its way to it.
#   LEDGER-WRITE  the flush produced nothing, or the commit did not land. An unverified
#                 write is a claim, not a fact.
#
# It does NOT commit anything itself: the write is handed to swarm-commit.sh, which is
# already the repo-global lane. One committer, one lane, one place to fix.
#
# Usage:
#   coordinator.sh --run <run-id> [--actor <name>]... [--root <repo root>]
#                  [--actor-prefix <p>] [--mirror-artifacts] [--dry-run]
#
# --actor             REPEATABLE, and the identity source the orphan sweep actually wants: one
#                     per worker, exactly as its hand-back's `ACTOR:` line reported. worker.md
#                     §9 mandates that line for precisely this reason -- "the only way the
#                     minted name reaches its roster and its orphan sweep" -- and until now
#                     there was no parameter to carry it, so the sweep guessed a prefix and
#                     matched nothing. Give every actor of this run; the sweep matches the set
#                     exactly.
#
# --mirror-artifacts  OPTIONAL checkpoint (ac-28nm): after a successful ledger flush, mirror
#                     this run's /tmp-mortal scratch into <git-common-dir>/ac-flight/<run-id>/
#                     artifacts/ so a reboot mid-run loses nothing. Non-blocking: if the
#                     mirror script is absent it is noted, never refused.
#
# Exit 0  closed out — ledger flushed, verified and committed
# Exit 1  REFUSED: <CLASS> — act on the class, do not route around it
# Exit 2  NOT-GATED — a check could not run, so nothing is claimed

set -uo pipefail

RUN=""; ROOT=""; PREFIX=""; DRY=0; MIRROR=0; BRANCH=""; ACTORS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --run)             RUN="${2:-}"; shift 2 ;;
    --branch)          BRANCH="${2:-}"; shift 2 ;;
    --root)            ROOT="${2:-}"; shift 2 ;;
    --actor)           ACTORS+=("${2:-}"); shift 2 ;;
    --actor-prefix)    PREFIX="${2:-}"; shift 2 ;;
    --mirror-artifacts) MIRROR=1; shift ;;
    --dry-run)         DRY=1; shift ;;
    *) echo "NOT-GATED: unknown argument '$1'" >&2; exit 2 ;;
  esac
done
[ -n "$RUN" ] || { echo "NOT-GATED: --run <run-id> is required; without it the orphan sweep cannot tell this run's actors from a live sibling run's" >&2; exit 2; }
# NO SILENT DEFAULT. This used to fall back to `swarm-$RUN`, a prefix NO worker this pipeline
# produces: worker.md mints the identity from Agent Mail, which names agents `CoralGorge`,
# `BrownDesert`, `GentleCave`. The sweep therefore matched the empty set and printed clean, on
# every run that did not pass --actor-prefix by hand. Measured four times (easy-mode
# FRICTIONS.md `orphan-sweep-actor-prefix-never-matches-the-worker-identity`, recurrence 3,
# plus 2026-09-19); once with a worker dead mid-flight still holding a claim, reported clean.
# The entry's own conclusion: a string-prefix convention cannot work once the SERVER names the
# agent, because the coordinator cannot predict the name. So it is given, never guessed --
# and an absent identity source is NOT-GATED, because a sweep that can match nothing has
# verified nothing, which is the one thing this file exists to refuse.
if [ "${#ACTORS[@]}" -eq 0 ] && [ -z "$PREFIX" ]; then
  echo "NOT-GATED: no worker identity given, so the orphan sweep can match nothing and would print clean over a live orphan. Pass --actor <name> once per worker (the ACTOR: line in each hand-back), or --actor-prefix <p> if this run really does use a shared prefix." >&2
  exit 2
fi

if [ -z "$ROOT" ]; then
  # ROOT is the CONSUMER repo's root, never the script's own repo: these scripts are
  # symlinked into consumer repos via .agents/skills/, so script-relative resolution
  # lands inside the skills checkout (or .agents/) and the ledger path is wrong before
  # any refusal can fire. Derive from the calling repo's git toplevel.
  ROOT=$(git rev-parse --show-toplevel 2>/dev/null) \
    || ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd) \
    || ROOT="$PWD"
fi
cd "$ROOT" || { echo "NOT-GATED: cannot enter repo root '$ROOT'" >&2; exit 2; }

# The ONE br_call invocation shape (ac-heyt.3). Path computed BEFORE the cd above:
# BASH_SOURCE may be relative, so the absolute helper path must resolve from the original
# cwd. br_call honors AC2_BR_CMD, so the seam declared below keeps reads and writes on the
# same binary.
# shellcheck source=br-call.sh
BR_CALL="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../_tools" 2>/dev/null && pwd)/br-call.sh"

BR="${AC2_BR_CMD:-br}"
LEDGER=".beads/issues.jsonl"
refuse() { echo "REFUSED: $1 — $2" >&2; exit 1; }
ungated() { echo "NOT-GATED: $1" >&2; exit 2; }

. "$BR_CALL" 2>/dev/null || ungated "br-call.sh helper missing at '$BR_CALL' — no br read can be verified"

command -v git >/dev/null 2>&1 || ungated "git is unavailable; nothing can be verified"
[ -f "$LEDGER" ] || ungated "no ledger at $LEDGER — this is not an ac2 repo root"

# --- Refusal 1: LEDGER-STALE ------------------------------------------------------------
# The DB is flushed OVER the file. If origin carries ledger commits this checkout never
# imported, the flush reverts them silently. Compare against the remote-tracking ref only;
# fetching is the caller's business, and a fetch inside a gate hides a network failure.
UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
if [ -n "$UPSTREAM" ]; then
  BEHIND=$(git rev-list --count "HEAD..$UPSTREAM" -- "$LEDGER" 2>/dev/null || echo "?")
  [ "$BEHIND" = "?" ] && ungated "cannot compare HEAD against $UPSTREAM; staleness is unknown, so the flush is not safe to authorise"
  [ "$BEHIND" -eq 0 ] || refuse "LEDGER-STALE" \
    "$UPSTREAM carries $BEHIND commit(s) touching $LEDGER that this checkout has not imported. Flushing now would overwrite them with no error and no trace. Import first: git show $UPSTREAM:$LEDGER > $LEDGER && $BR sync --import-only, verify by arithmetic, then re-run"
else
  echo "coordinator[$RUN] LEDGER-STALE skipped — no upstream configured, so there is nothing to be stale against"
fi

# --- Refusal 2: ORPHANS -----------------------------------------------------------------
# A claim held by an actor from THIS run that is no longer working it. Liveness comes from
# the board, never from harness notifications: a transient 5xx once read as death.
if command -v "$BR" >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  CLAIMS=$(RUST_LOG=error br_call coordination status --json 2>/dev/null) || CLAIMS=""
  if [ -z "$CLAIMS" ]; then
    # FALLBACK, and deliberately not a skip. `br coordination` landed in a later br than some
    # machines run -- measured absent on br 0.1.14, where this gate went NOT-GATED and took the
    # entire close-out with it (no ledger flush, no commit). The orphan test reads only
    # id/status/assignee, which `br list --json` already carries, so reshape that into the same
    # {claims:[{issue:{...}}]} envelope the jq below expects. The REFUSAL keeps its teeth: a
    # gate that cannot fire reads as coverage, which is the failure this whole file exists for.
    CLAIMS=$(RUST_LOG=error br_call list --json --limit 0 2>/dev/null \
      | jq -c '{claims: [ .[]? | {issue: {id: .id, status: .status, assignee: .assignee}} ]}' 2>/dev/null) \
      || CLAIMS=""
  fi
  [ -n "$CLAIMS" ] || ungated "neither '$BR coordination status' nor '$BR list --json' yielded claim state; liveness is unknown and orphans cannot be ruled out"
  # Exact set when --actor was given, prefix only when --actor-prefix was explicitly asked for.
  # An empty array must stay EMPTY: `printf '%s\n'` with no args still emits one blank line,
  # which became [""] and silently took the exact-match branch, disabling --actor-prefix.
  if [ "${#ACTORS[@]}" -gt 0 ]; then
    ACTORS_JSON=$(printf '%s\n' "${ACTORS[@]}" | jq -R . | jq -s -c .)
  else
    ACTORS_JSON='[]'
  fi
  ORPHANS=$(printf '%s' "$CLAIMS" | jq -r --arg p "$PREFIX" --argjson a "$ACTORS_JSON" \
    '[.claims[]? | select((.issue.status? // "") == "in_progress")
       | select( (($a | length) > 0 and ((.issue.assignee? // "") as $x | $a | index($x)))
                 or (($a | length) == 0 and $p != "" and ((.issue.assignee? // "") | startswith($p))) )
       | .issue.id] | join(" ")' 2>/dev/null || echo "?")
  [ "$ORPHANS" = "?" ] && ungated "could not parse '$BR coordination status'; orphans cannot be ruled out"
  [ -z "${ORPHANS// /}" ] || refuse "ORPHANS" \
    "still in_progress under this run's actors: $ORPHANS. Every worker has returned, so nobody is working these. Reset each to open, clear the assignee, and comment what it left in the tree — then re-run"
else
  ungated "br or jq unavailable — the orphan sweep verified nothing, and a silent orphan is exactly what it exists to catch"
fi

# --- Refusal 3: LEDGER-WRITE ------------------------------------------------------------
BEFORE=$(git rev-parse HEAD 2>/dev/null || echo none)
if [ "$DRY" = 1 ]; then
  echo "coordinator[$RUN] DRY-RUN — both refusals held; would flush, verify and hand the ledger to swarm-commit.sh"
  exit 0
fi
RUST_LOG=error "$BR" sync --flush-only >/dev/null 2>&1 \
  || ungated "'$BR sync --flush-only' failed; the ledger on disk does not reflect the DB and must not be committed"

if git diff --quiet -- "$LEDGER" 2>/dev/null; then
  echo "coordinator[$RUN] ledger unchanged — no bead moved in this run; nothing to commit"
  exit 0
fi

MSG=$(mktemp "${TMPDIR:-/tmp}/ac-coord-msg.XXXXXX") || ungated "cannot create a scratch file"
trap 'rm -f "$MSG"' EXIT
printf '%s\n\n%s\n' \
  "chore(beads): ac2 swarm run $RUN ledger [no-bead]" \
  "Flushed once by the coordinator after every worker returned. LEDGER-STALE and ORPHANS both held." >"$MSG"

# swarm-commit.sh lives beside THIS script, never under "$ROOT/skills/": in consumer
# repos these scripts are reached via the .agents/skills/ symlink, so a $ROOT-relative
# path does not exist (measured: BCA swarm 2026-09-04, LEDGER-WRITE via missing file).
# --branch is FORWARDED, never defaulted here: swarm-commit.sh owns trunk resolution
# (--branch, then `git config ac2.trunk`, then main) and its foreign-branch guard compares
# HEAD against it. Passing nothing lets that resolution run; passing a value states intent.
# Without this passthrough the close-out could not name a trunk at all, so on any checkout
# whose trunk is not `main` the coordinator's own ledger commit was refused unconditionally
# -- measured 2026-09-12 on easy-mode (trunk `dev`), where the swarm's ledger had to be
# committed by hand against the lane this script exists to keep single.
# The expansion below is GUARDED (`${A[@]+"${A[@]}"}`) rather than a bare `"${A[@]}"`:
# this repo runs on bash 3.2 (macOS), where expanding an EMPTY array under `set -u` is an
# "unbound variable" error. A bare expansion here would break every close-out that does not
# pass --branch, which is the default path -- a worse defect than the one this fixes.
BRANCH_ARG=()
[ -n "$BRANCH" ] && BRANCH_ARG=(--branch "$BRANCH")

bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/swarm-commit.sh" \
  --identity "coordinator-$RUN" --message-file "$MSG" --path "$LEDGER" ${BRANCH_ARG[@]+"${BRANCH_ARG[@]}"} \
  || refuse "LEDGER-WRITE" "swarm-commit.sh refused the ledger commit; read its refusal — the ledger is flushed to disk but UNCOMMITTED"

AFTER=$(git rev-parse HEAD 2>/dev/null || echo none)
[ "$AFTER" != "$BEFORE" ] || refuse "LEDGER-WRITE" \
  "the commit reported success but HEAD did not move — the ledger is flushed to disk and NOT committed. An unverified write is a claim, not a fact"

echo "coordinator[$RUN] CLOSED OUT — ledger flushed, verified and committed at $(git rev-parse --short HEAD)"

# --- optional checkpoint: mirror the run's /tmp scratch into ac-flight (ac-28nm) --------
# A multi-day run's /tmp artifacts (run-id.md, /tmp claim/comment/worker files) die on a
# reboot or the OS sweep. This OPTIONAL leg mirrors them repo-side so a reboot loses nothing
# but a copy step. NON-BLOCKING: a missing mirror script is noted, never refused — the close
# already happened; this is a durability nicety, not a gate.
if [ "$MIRROR" = 1 ]; then
  MIRROR_SH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/mirror-run-artifacts.sh"
  if [ -x "$MIRROR_SH" ]; then
    bash "$MIRROR_SH" --run "$RUN" \
      || echo "coordinator[$RUN] mirror-run-artifacts reported a problem; run state may not be durable (non-blocking)"
  else
    echo "coordinator[$RUN] mirror-run-artifacts.sh not found beside coordinator.sh — run-state mirror skipped (non-blocking)"
  fi
fi
exit 0
