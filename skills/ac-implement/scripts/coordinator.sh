#!/usr/bin/env bash
#
# coordinator.sh — the ac2 swarm CLOSE-OUT. Runs once, at the end, by the coordinator.
#
# ASSURANCE
#   PROBE:      bash skills/ac-implement/scripts/coordinator.test.sh
#   SCHEDULE:   once per ac2 swarm run, at close-out; the harness runs on every
#               scripts/run-all-harnesses.sh invocation, which lint.sh Check 20 audits.
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
#   coordinator.sh --run <run-id> [--root <repo root>] [--actor-prefix <p>] [--dry-run]
#
# Exit 0  closed out — ledger flushed, verified and committed
# Exit 1  REFUSED: <CLASS> — act on the class, do not route around it
# Exit 2  NOT-GATED — a check could not run, so nothing is claimed

set -uo pipefail

RUN=""; ROOT=""; PREFIX=""; DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --run)          RUN="${2:-}"; shift 2 ;;
    --root)         ROOT="${2:-}"; shift 2 ;;
    --actor-prefix) PREFIX="${2:-}"; shift 2 ;;
    --dry-run)      DRY=1; shift ;;
    *) echo "NOT-GATED: unknown argument '$1'" >&2; exit 2 ;;
  esac
done
[ -n "$RUN" ] || { echo "NOT-GATED: --run <run-id> is required; without it the orphan sweep cannot tell this run's actors from a live sibling run's" >&2; exit 2; }
[ -n "$PREFIX" ] || PREFIX="swarm-$RUN"

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

BR="${AC2_BR_CMD:-br}"
LEDGER=".beads/issues.jsonl"
refuse() { echo "REFUSED: $1 — $2" >&2; exit 1; }
ungated() { echo "NOT-GATED: $1" >&2; exit 2; }

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
  CLAIMS=$(RUST_LOG=error "$BR" coordination status --json 2>/dev/null || true)
  [ -n "$CLAIMS" ] || ungated "'$BR coordination status' returned nothing; liveness is unknown and orphans cannot be ruled out"
  ORPHANS=$(printf '%s' "$CLAIMS" | jq -r --arg p "$PREFIX" \
    '[.claims[]? | select((.issue.status? // "") == "in_progress")
       | select(((.issue.assignee? // "") | startswith($p)))
       | .issue.id] | join(" ")' 2>/dev/null || echo "?")
  [ "$ORPHANS" = "?" ] && ungated "could not parse '$BR coordination status --json'; orphans cannot be ruled out"
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
bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/swarm-commit.sh" \
  --identity "coordinator-$RUN" --message-file "$MSG" --path "$LEDGER" \
  || refuse "LEDGER-WRITE" "swarm-commit.sh refused the ledger commit; read its refusal — the ledger is flushed to disk but UNCOMMITTED"

AFTER=$(git rev-parse HEAD 2>/dev/null || echo none)
[ "$AFTER" != "$BEFORE" ] || refuse "LEDGER-WRITE" \
  "the commit reported success but HEAD did not move — the ledger is flushed to disk and NOT committed. An unverified write is a claim, not a fact"

echo "coordinator[$RUN] CLOSED OUT — ledger flushed, verified and committed at $(git rev-parse --short HEAD)"
exit 0
