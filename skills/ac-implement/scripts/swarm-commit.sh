#!/usr/bin/env bash
#
# swarm-commit.sh — the ac2 REPO-GLOBAL commit lane.
#
# WHY A SCRIPT AND NOT PROSE: the lane it replaces is ~12 git/quoting scar rules plus 5
# duplicated warnings carried as prose in the worker prompt, self-audited by whoever is
# committing. A rule a human re-reads at 2am is not a control; every one of these scars
# was already written down when it bit. Constitution Invariant 5: one engine per pattern;
# scripts, not scar prose.
#
# IT IS A DESIGN UPGRADE, NOT A CODIFICATION. The prose lane serialises WORKER SIBLINGS
# (one flock taken inside one swarm run). The measured cross-writer collision was two
# SCHEDULED JOBS updating the beads ledger — neither of them a worker, neither inside that
# flock. So this lane is repo-global: every writer takes it, workers and scheduled jobs
# alike, and the lane requires no worker context whatsoever (see --identity below).
#
# ASSURANCE (skills/ac-pipeline/references/assurance-declarations.md § The four fields):
#   PROBE:      skills/ac-implement/scripts/swarm-commit.test.sh — RED/GREEN over every
#               refusal rule, the lock, the scoping, the lint-staged repair and the
#               non-worker second-process case
#   SCHEDULE:   on every commit taken through the lane; and on every CI run via
#               scripts/run-all-harnesses.sh (registry-lint `harnesses` job)
#   MODE:       blocking
#   ON-FAILURE: closed — a refusal exits non-zero BEFORE the commit, and a rejected commit
#               can never reach the push. Silence is never success here: every refusal
#               names the rule it broke.
#
# THE RULES IT ENFORCES (each refusal prints `REFUSED [<rule>]`):
#   outside-lock       the commit ran without holding the repo-global lane
#   no-identity        no explicit --identity; the ambient AGENT_NAME is NEVER trusted
#   unscoped-pathspec  no paths, or a path that sweeps the shared index
#   inline-message     -m/--message instead of a message FILE
#   no-message-file    --message-file missing, unreadable or empty
#   foreign-branch     the checkout is not on the branch this commit was written for
#   no-claim-receipt   the subject names a bead whose claim flight-check REFUSED and no
#                      flight receipt dated after that refusal is on record — the refusal→
#                      rework rule lives only in worker seed text, so a worker that ignores
#                      it ships a diff whose premise-verification loop is void
#   ledger-behind-upstream  the pathspec includes .beads/issues.jsonl and the tracking ref
#                      is AHEAD of HEAD on it — refused BEFORE the commit exists, with the
#                      exact remedy printed (no upstream configured is NOT-CHECKED, never
#                      a silent skip; no fetch is made — the tracking ref is read as last
#                      fetched)
#
# EXIT CODES
#   0  committed (and pushed unless --no-push)      3  refusal — a rule above fired
#   2  usage                                        4  lane busy — lock not acquired
#   5  commit rejected by a hook/guard (NOTHING was pushed)
#   9  foreign branch — stop, touch nothing        10  commit is local; push was rejected
#
# USAGE
#   swarm-commit.sh --identity <name> --message-file <file> --path <p> [--path <p>...]
#                   [--branch main] [--remote origin] [--timeout 600] [--no-push]
#
set -uo pipefail

ORIG=("$@")
LOCKED=0
IDENTITY="${AC2_COMMIT_IDENTITY:-}"   # explicit lane channel ONLY — never AGENT_NAME
MSGFILE=""
BRANCH="main"
REMOTE="origin"
TIMEOUT=600
PUSH=1
PATHS=()

refuse() { rule="$1"; shift; echo "REFUSED [$rule]: $*" >&2; exit 3; }
usage()  { echo "usage: $0 --identity <name> --message-file <f> --path <p> [--path <p>...]" >&2; exit 2; }

# The ONE br_call invocation shape (ac-heyt.3). The witness read below is
# informational; a refusal names itself on stderr instead of yielding a bare hash.
# shellcheck source=br-call.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../_tools" 2>/dev/null && pwd)/br-call.sh" 2>/dev/null || true

while [ $# -gt 0 ]; do
  case "$1" in
    --_locked)       LOCKED=1; shift ;;
    --identity)      IDENTITY="${2:-}"; shift 2 ;;
    --message-file|-F) MSGFILE="${2:-}"; shift 2 ;;
    --path)          PATHS+=("${2:-}"); shift 2 ;;
    --branch)        BRANCH="${2:-}"; shift 2 ;;
    --remote)        REMOTE="${2:-}"; shift 2 ;;
    --timeout)       TIMEOUT="${2:-}"; shift 2 ;;
    --no-push)       PUSH=0; shift ;;
    -m|--message)
      # An inline body is the measured truncation scar: an apostrophe in the message
      # closes the shell quote, the commit lands truncated and the push is skipped at
      # exit 0 — you believe you shipped and nothing landed.
      refuse inline-message "-m/--message is not accepted; write the body to a file and pass --message-file" ;;
    -a|-A|--all)
      refuse unscoped-pathspec "$1 sweeps the shared index; name every path with --path" ;;
    -h|--help)       usage ;;
    *) echo "swarm-commit: unknown argument '$1'" >&2; usage ;;
  esac
done

# --- identity ---------------------------------------------------------------------------
# NEVER the ambient AGENT_NAME. Harness settings set a STATIC fallback that every shell
# inherits, so an identity check reading the environment can never fail — it silently
# compares the reservation holder against the fallback and rejects the writer's OWN
# reservation as a foreign conflict. Identity here is passed, or the lane refuses.
[ -n "$IDENTITY" ] || refuse no-identity "--identity (or AC2_COMMIT_IDENTITY) is required; the ambient AGENT_NAME is never trusted"

# --- message file -----------------------------------------------------------------------
[ -n "$MSGFILE" ] || refuse no-message-file "--message-file is required"
[ -r "$MSGFILE" ] || refuse no-message-file "message file '$MSGFILE' is missing or unreadable"
[ -s "$MSGFILE" ] || refuse no-message-file "message file '$MSGFILE' is empty"

# --- pathspec ---------------------------------------------------------------------------
# flock serialises the lane's writers; it does NOT serialise other sessions sharing the
# checkout. An unscoped commit still publishes whatever is sitting in the shared index
# under this writer's message, so the pathspec goes on the COMMIT, not just the add.
[ "${#PATHS[@]}" -gt 0 ] || refuse unscoped-pathspec "no --path given; a bare commit publishes the whole shared index"
for p in "${PATHS[@]}"; do
  case "$p" in
    ""|"."|"./"|".."|"/"|":/"|:/*|"-"*)
      refuse unscoped-pathspec "path '$p' is not a scoped path" ;;
    ":!"*)
      refuse unscoped-pathspec "path '$p' is an exclude pathspec, not a named path" ;;
    *'*'*|*'?'*|*'['*)
      # A pattern CHARACTER is not evidence of a pattern. Every Next.js dynamic-route file
      # is a literal `[...]` name, and refusing those by their own name left the enclosing
      # DIRECTORY as the only way through the lane — a WIDER pathspec than the change, which
      # is exactly the sibling-sweeping this rule exists to prevent. The rule as written
      # pushed writers toward the harm it names.
      #
      # Existence on disk as a regular file separates the two readings with no ambiguity: a
      # genuine glob names nothing, so it still refuses right here. GIT_LITERAL_PATHSPECS
      # (exported inside the lane) then stops git re-expanding what this check just allowed.
      if [ ! -e "$p" ] || [ -d "$p" ]; then
        refuse unscoped-pathspec "path '$p' is a pattern, not a named file on disk; patterns match a sibling's files too"
      fi ;;
  esac
done

# --- the lane ----------------------------------------------------------------------------
FLOCK="$(command -v flock || true)"
[ -n "$FLOCK" ] || { echo "swarm-commit: NOT-GATED — flock(1) is not installed; the lane cannot be taken and no commit is attempted" >&2; exit 4; }

git rev-parse --git-dir >/dev/null 2>&1 || { echo "swarm-commit: not inside a git repository" >&2; exit 2; }

# NEVER a literal .git/<name>.lock: `.git` is a FILE in every neoMeta app (submodule) and
# in every linked worktree, so that path never opens and the mutex silently does nothing.
# --git-common-dir resolves to the ONE shared directory behind every worktree, which is
# what makes this lane repo-global rather than per-worktree.
COMMON_DIR="$(git rev-parse --git-common-dir)"
case "$COMMON_DIR" in /*) ;; *) COMMON_DIR="$(cd "$COMMON_DIR" && pwd)" ;; esac
LOCKFILE="$COMMON_DIR/ac-swarm-commit.lock"

if [ "$LOCKED" -eq 0 ]; then
  "$FLOCK" -w "$TIMEOUT" -E 4 "$LOCKFILE" "$0" --_locked "${ORIG[@]}"
  rc=$?
  [ "$rc" -eq 4 ] && echo "swarm-commit: LANE-BUSY — another writer held $LOCKFILE for ${TIMEOUT}s; nothing was committed" >&2
  exit "$rc"
fi

# --- inside the lane: prove it -----------------------------------------------------------
# flock(2) locks live on the OPEN FILE DESCRIPTION, so a second open() of the same file
# conflicts with the lock our parent holds even inside our own process tree. If a
# non-blocking acquire SUCCEEDS, nobody holds the lane and we are running outside it.
if "$FLOCK" -n -E 4 "$LOCKFILE" true 2>/dev/null; then
  refuse outside-lock "the lane at $LOCKFILE is not held; re-invoke without --_locked so the lock is taken"
fi

# The guard compares THIS to the reservation holder, so it is exported inside the lane
# from the explicit identity, shadowing whatever static fallback the shell inherited.
export AGENT_NAME="$IDENTITY" BR_AGENT_NAME="$IDENTITY"

# Literal pathspecs for every git call in the lane. The guard above admits a bracket path
# only when it EXISTS on disk by that exact name; without this, git would still read
# `app/foods/[id]/page.tsx` as a wildmatch pattern — matching `app/foods/d/page.tsx` and NOT
# the file the writer named. The guard's reading and git's reading must be the SAME reading,
# or the lane admits one path and commits another.
export GIT_LITERAL_PATHSPECS=1

CUR="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
[ "$CUR" = "$BRANCH" ] || { echo "REFUSED [foreign-branch]: HEAD is on '$CUR', this commit was written for '$BRANCH'; stop and touch nothing" >&2; exit 9; }

# ---------------------------------------------------------------------------------------
# LEG — no-claim-receipt. A commit whose subject names bead X is refused when X has a
# refused-claim flight receipt on record (a flight-check that exited PREMISE-FAILED at
# claim) and no flight receipt for X dated AFTER the last refusal. The refusal→rework
# rule lives only in worker seed text; a worker that ignores it ships a diff whose
# premise verification (RED observed at claim, against the tree) never ran for the
# shipped commit — the ledger stays honest (beads left open) but the batch carries
# changes with a void premise-verification loop. Structural, repo-global, no worker
# context: the subject is parsed from the message file, the refusal record is read
# from the repo's own `.beads/issues.jsonl` (the bead's title is prefixed
# `PREMISE-FAILED:` by flight-check on refusal, and the refusal moment is the latest
# `Premise failure:` comment), and the receipts live beside this lane's lock in the
# git common dir.
# ---------------------------------------------------------------------------------------
FLIGHT_DIR="${AC2_FLIGHT_DIR:-$COMMON_DIR/ac-flight}"
BOARD="$(git rev-parse --show-toplevel 2>/dev/null || pwd)/.beads/issues.jsonl"
[ -n "$MSGFILE" ] && [ -r "$MSGFILE" ] || refuse no-claim-receipt "the message file is unreadable — the subject cannot be checked for a refused claim"
SUBJECT=$(sed -n '1p' "$MSGFILE" 2>/dev/null || true)
if [ -n "$SUBJECT" ] && [ -f "$BOARD" ] && command -v jq >/dev/null 2>&1; then
  # every ac-* token in the subject is a candidate bead id; the board decides if it IS one
  for tok in $(printf '%s\n' "$SUBJECT" | grep -oE 'ac-[A-Za-z0-9][A-Za-z0-9._-]*' | sort -u); do
    row=$(jq -c --arg id "$tok" 'select(.id == $id)' "$BOARD" 2>/dev/null | head -1)
    [ -n "$row" ] || continue
    title=$(printf '%s' "$row" | jq -r '.title // ""')
    case "$title" in
      PREMISE-FAILED:*)
        # refusal on record. The refusal moment = the latest `Premise failure:` comment
        # (flight-check writes it at refusal); fall back to the record's own updated_at.
        refusal_ts=$(printf '%s' "$row" | jq -r '
            ([.comments[]? | select(.text | startswith("Premise failure:")) | .created_at] | max) // .updated_at // ""')
        recv="$FLIGHT_DIR/$tok.flight-receipt"
        last_at=""
        if [ -f "$recv" ]; then
          last_at=$(awk '/^FLIGHT-RECEIPT v1/{buf=""} {buf = buf $0 "\n"} END{printf "%s", buf}' "$recv" \
            | grep -m1 '^at:' | sed 's/^at:[[:space:]]*//')
        fi
        # ISO-8601 UTC compares lexicographically once fractional seconds + Z are stripped.
        norm_ts() { printf '%s' "$1" | sed -E 's/\.[0-9]+//; s/Z$//'; }
        if [ -z "$refusal_ts" ] || [ -z "$last_at" ] \
           || [ "$(norm_ts "$last_at")" \< "$(norm_ts "$refusal_ts")" ]; then
          refuse no-claim-receipt "subject names '$tok', whose claim flight-check refused, and no flight receipt dated after the refusal is on record — re-claim the bead and bank a fresh RED, or re-refine it"
        fi
        ;;
    esac
  done
elif [ -n "$SUBJECT" ]; then
  echo "swarm-commit: no-claim-receipt NOT-CHECKED — no board at '$BOARD' or jq unavailable; a refused-claim subject cannot be verified (this gate reports the skip; it never implies clean)"
fi

# ---------------------------------------------------------------------------------------
# LEG — ledger-behind-upstream. .beads/issues.jsonl is a DERIVED file whose one-committer
# rule is prose only: two checkouts exporting overlapping content wedge the ledger, and
# nothing in the commit lane notices. A commit whose pathspec includes the ledger is
# refused BEFORE it exists when the tracking ref is ahead of HEAD on that path, with the
# exact remedy printed. No upstream configured is a NOT-CHECKED line, never a silent skip.
# Deliberately no fetch: the tracking ref is compared AS LAST FETCHED (every automated
# puller here is already --ff-only, so a stale ref costs one loud refusal at the next
# pull). The refusal also prints br's sync witness root_hash so two checkouts can prove
# their derived ledgers identical without going through git at all.
# ---------------------------------------------------------------------------------------
LEDGER_IN_PATHS=0
for p in "${PATHS[@]}"; do
  [ "$p" = ".beads/issues.jsonl" ] && LEDGER_IN_PATHS=1
done
if [ "$LEDGER_IN_PATHS" -eq 1 ]; then
  AHEAD=$(git rev-list --count HEAD..@{upstream} -- .beads/issues.jsonl 2>/dev/null)
  if [ -z "${AHEAD:-}" ]; then
    echo "swarm-commit: ledger-behind-upstream NOT-CHECKED — no upstream configured for the ledger path; a stale tracking ref cannot be compared (this gate reports the skip; it never implies clean)"
  elif [ "$AHEAD" -gt 0 ]; then
    WITNESS=""
    if command -v br >/dev/null 2>&1 && [ -f .beads/issues.jsonl ]; then
      WITNESS=$(br_call sync --witness --json | jq -r '.witness.root_hash // ""' 2>/dev/null) || WITNESS=""
    fi
    remedy="upstream is $AHEAD ledger commit(s) ahead of HEAD — the derived ledger would diverge; remedy: git pull --ff-only, then br sync, then re-run"
    [ -n "$WITNESS" ] && remedy="$remedy. Sync witness root_hash: $WITNESS"
    refuse ledger-behind-upstream "$remedy"
  fi
fi

git add -- "${PATHS[@]}" || { echo "swarm-commit: git add failed; nothing committed, nothing pushed" >&2; exit 5; }

if ! git commit -F "$MSGFILE" -- "${PATHS[@]}"; then
  # A rejected commit MUST NOT fall through to a push: the push would report
  # "Everything up-to-date" and exit 0, and the writer would believe it shipped.
  echo "swarm-commit: commit REJECTED (hook or guard); nothing was pushed" >&2
  exit 5
fi

# --- lint-staged repair -------------------------------------------------------------------
# lint-staged rewrites files in the WORKTREE from the pre-commit hook. When it does not
# re-stage its own output the commit carries the pre-lint bytes while the worktree carries
# the post-lint bytes, and the next writer inherits a dirty tree it did not create. Detect
# exactly that divergence — worktree vs the commit just made, on OUR paths only — and
# re-add so the commit carries what lint produced.
DIVERGED="$(git diff --name-only HEAD -- "${PATHS[@]}")"
if [ -n "$DIVERGED" ]; then
  echo "swarm-commit: lint-staged divergence, re-adding post-lint bytes:"
  echo "$DIVERGED" | sed 's/^/  /'
  git add -- "${PATHS[@]}" || { echo "swarm-commit: re-add failed" >&2; exit 5; }
  # --no-verify on the AMEND only: the hook already ran and produced these exact bytes;
  # re-running it here would rewrite and diverge again, forever. Pathspec still scopes it.
  git commit --amend --no-edit --no-verify -- "${PATHS[@]}" >/dev/null \
    || { echo "swarm-commit: amend REJECTED; nothing was pushed" >&2; exit 5; }
  STILL="$(git diff --name-only HEAD -- "${PATHS[@]}")"
  [ -z "$STILL" ] || { echo "REFUSED [lint-staged-unstable]: worktree still diverges after one repair pass; nothing was pushed" >&2; exit 5; }
fi

echo "swarm-commit: committed $(git rev-parse --short HEAD) as $IDENTITY"

[ "$PUSH" -eq 1 ] || exit 0

if ! git push "$REMOTE" "$BRANCH"; then
  # Not fatal and never repaired here: NEVER pull, rebase, stash or reset in the lane.
  echo "PUSH_REJECTED — the commit is safe in local $BRANCH; the orchestrator reconciles" >&2
  exit 10
fi
exit 0
