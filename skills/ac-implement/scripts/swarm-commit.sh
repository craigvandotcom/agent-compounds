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
# COMMIT ONLY, NEVER THE TREE'S PUBLISH STEP (ac-ftfz.9): this lane used to hold its lock
# across a network call, so gate-wait dominated a whole run's work time, and a rejected
# remote update surfaced two layers away from its cause. The whole-tree publish step is a
# separate, later, once-per-batch layer (`ac-pipeline/scripts/push.sh`) — this lane only
# ever commits locally, fast, and hands the tree off clean for that later step.
#
# ASSURANCE (skills/ac-pipeline/references/assurance-declarations.md § The four fields):
#   PROBE:      skills/ac-implement/scripts/swarm-commit.test.sh — RED/GREEN over every
#               refusal rule, the lock, the scoping, the lint-staged repair and the
#               non-worker second-process case
#   SCHEDULE:   on every commit taken through the lane; and on every CI run via
#               scripts/run-all-proofs.sh (registry-lint `proofs` job)
#   MODE:       blocking
#   ON-FAILURE: closed — a refusal exits non-zero BEFORE the commit. Silence is never
#               success here: every refusal names the rule it broke.
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
#   unclaimed          the subject names a bead the committing identity does not hold the
#                      claim on, read fresh off the board — never a staged commit for a
#                      claim another writer holds
#   outside-scope      a named path is not inside that bead's own `## Delivers` scope — the
#                      bead's own declaration is the boundary, never a hand-audited guess.
#                      A bead whose Delivers names no path is unscoped and is not checked; a
#                      subject with no bead token, or the coordinator's own `[no-bead]`
#                      ledger-flush marker, is unchecked outright.
#   ledger-behind-upstream  the pathspec includes .beads/issues.jsonl and the tracking ref
#                      is AHEAD of HEAD on it — refused BEFORE the commit exists, with the
#                      exact remedy printed (no upstream configured is NOT-CHECKED, never
#                      a silent skip; no fetch is made — the tracking ref is read as last
#                      fetched)
#
# EXIT CODES
#   0  committed                                    3  refusal — a rule above fired
#   2  usage                                        4  lane busy — lock not acquired
#   5  commit rejected by a hook/guard               6  NOT-GATED — the claim or scope
#   9  foreign branch — stop, touch nothing             could not be verified either way
#
# USAGE
#   swarm-commit.sh --identity <name> --message-file <file> --path <p> [--path <p>...]
#                   [--branch main] [--remote origin] [--timeout 600]
#
set -uo pipefail

ORIG=("$@")
LOCKED=0
IDENTITY="${AC2_COMMIT_IDENTITY:-}"   # explicit lane channel ONLY — never AGENT_NAME
MSGFILE=""
BRANCH="main"
REMOTE="origin"
TIMEOUT=600
PATHS=()

refuse() { rule="$1"; shift; echo "REFUSED [$rule]: $*" >&2; echo "NEXT: repair $rule" >&2; exit 3; }
usage()  { echo "usage: $0 --identity <name> --message-file <f> --path <p> [--path <p>...]" >&2; echo "NEXT: handback" >&2; exit 2; }
not_gated() { echo "NOT-GATED [$1]: $2" >&2; echo "NEXT: handback" >&2; exit 6; }

# extract_paths [body] (else stdin) -> sorted unique path tokens, via bead.py's plain-text
# extractor (ac-m9y4.10) — the one bead reader every tool parses cards through, never a
# second hand-rolled copy of the pattern. `BEAD_MODULE_PATH` is the same test-only override
# bead-capture-guard.py's own `_load_bead_module()` uses: a nonexistent path drives the
# crash-path fixture without ever touching the real file in a shared checkout.
extract_paths() {
  local input
  if [ "$#" -gt 0 ]; then input="$1"; else input="$(cat)"; fi
  printf '%s' "$input" | BEAD_PY_PATH="${BEAD_PY_HOME:-}" python3 -c '
import importlib.util, os, sys


def _load_bead():
    override = os.environ.get("BEAD_MODULE_PATH")
    path = override or os.environ["BEAD_PY_PATH"]
    spec = importlib.util.spec_from_file_location("bead", path)
    if spec is None or spec.loader is None:
        raise ImportError(f"cannot load bead.py at {path!r}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


try:
    bead = _load_bead()
    text = sys.stdin.read()
    for p in bead.extract_paths(text):
        print(p)
except Exception as e:
    print(f"NOT-GATED: bead.py unavailable or crashed: {e}", file=sys.stderr)
    sys.exit(2)
'
}

# The ONE br_call invocation shape (ac-heyt.3). The witness read below is
# informational; a refusal names itself on stderr instead of yielding a bare hash.
# shellcheck source=br-call.sh
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../_tools" 2>/dev/null && pwd)"
. "$TOOLS_DIR/br-call.sh" 2>/dev/null || true

while [ $# -gt 0 ]; do
  case "$1" in
    --_locked)       LOCKED=1; shift ;;
    --identity)      IDENTITY="${2:-}"; shift 2 ;;
    --message-file|-F) MSGFILE="${2:-}"; shift 2 ;;
    --path)          PATHS+=("${2:-}"); shift 2 ;;
    --branch)        BRANCH="${2:-}"; shift 2 ;;
    --remote)        REMOTE="${2:-}"; shift 2 ;;
    --timeout)       TIMEOUT="${2:-}"; shift 2 ;;
    -m|--message)
      # An inline body is the measured truncation scar: an apostrophe in the message
      # closes the shell quote and the commit lands truncated at exit 0 — you believe
      # you shipped and nothing landed.
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

# --- placeholder-message ------------------------------------------------------------------
# fcc88b3 shipped a bead's work as subject "test" / body "body" — the commit-msg hook only
# WARNS on a missing Cause: line, and nothing in the lane ever judged the subject or body
# shape, so the lane had no owner refusing a placeholder. Refused only when the subject
# looks like a placeholder (no conventional type prefix, AND under four words) AND the body
# also looks like a placeholder (under three words total) — a real short conventional
# subject with a thin body, or an unconventional subject with a real explanatory body, is
# left alone; only the fcc88b3 combination is refused.
MSG_SUBJECT="$(sed -n '1p' "$MSGFILE" 2>/dev/null || true)"
MSG_BODY="$(tail -n +2 "$MSGFILE" 2>/dev/null | grep -v '^[[:space:]]*$' || true)"
subj_words=$(printf '%s' "$MSG_SUBJECT" | wc -w | tr -d '[:space:]')
body_words=$(printf '%s' "$MSG_BODY" | wc -w | tr -d '[:space:]')
subj_placeholder=0
# ANY lowercase `type:` or `type(scope):` prefix counts as conventional — this repo's own
# history carries ac, beads, dream, batch, review, skills, friction and doctrine beside the
# usual set, and an enumerated whitelist refuses a legitimate short commit the moment a new
# type appears (found by the final review of ac-4y7l: `review(...)` was missing).
if printf '%s' "$MSG_SUBJECT" | grep -qE '^[a-z]+(\([^)]*\))?!?: .'; then
  :
else
  [ "${subj_words:-0}" -lt 4 ] && subj_placeholder=1
fi
if [ "$subj_placeholder" -eq 1 ] && [ "${body_words:-0}" -lt 3 ]; then
  refuse placeholder-message "subject '$MSG_SUBJECT' names no conventional type (a lowercase 'type:' or 'type(scope):' prefix) and is under four words, and the body is under three words — this looks like fcc88b3's placeholder ('test' / 'body'), not a message naming the failure this commit prevents"
fi

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
[ -n "$FLOCK" ] || { echo "swarm-commit: NOT-GATED — flock(1) is not installed; the lane cannot be taken and no commit is attempted" >&2; echo "NEXT: handback" >&2; exit 4; }

git rev-parse --git-dir >/dev/null 2>&1 || { echo "swarm-commit: not inside a git repository" >&2; echo "NEXT: handback" >&2; exit 2; }

# NEVER a literal .git/<name>.lock: `.git` is a FILE, not a directory, in a submodule
# and in every linked worktree, so that path never opens and the mutex silently does nothing.
# --git-common-dir resolves to the ONE shared directory behind every worktree, which is
# what makes this lane repo-global rather than per-worktree.
COMMON_DIR="$(git rev-parse --git-common-dir)"
case "$COMMON_DIR" in /*) ;; *) COMMON_DIR="$(cd "$COMMON_DIR" && pwd)" ;; esac
LOCKFILE="$COMMON_DIR/ac-swarm-commit.lock"

if [ "$LOCKED" -eq 0 ]; then
  # Snapshot the message file BEFORE taking the lock. Swarm workers share one /tmp
  # and the lane validates --message-file up front but used to read it only at
  # `git commit -F` after the flock wait — a sibling rewriting the caller's file
  # during the wait changed the commit subject/body under a different bead's code.
  MSG_SNAPSHOT="$(mktemp "${TMPDIR:-/tmp}/swarm-commit-msg.XXXXXX")" \
    || { echo "swarm-commit: cannot create message snapshot" >&2; echo "NEXT: handback" >&2; exit 5; }
  cp -- "$MSGFILE" "$MSG_SNAPSHOT" \
    || { rm -f "$MSG_SNAPSHOT"; echo "swarm-commit: cannot snapshot message file" >&2; echo "NEXT: handback" >&2; exit 5; }
  LOCK_ARGS=()
  _prev_is_msg=0
  for _a in "${ORIG[@]}"; do
    if [ "$_prev_is_msg" -eq 1 ]; then
      LOCK_ARGS+=("$MSG_SNAPSHOT")
      _prev_is_msg=0
      continue
    fi
    case "$_a" in
      --message-file|-F) LOCK_ARGS+=("$_a"); _prev_is_msg=1 ;;
      *) LOCK_ARGS+=("$_a") ;;
    esac
  done
  "$FLOCK" -w "$TIMEOUT" -E 4 "$LOCKFILE" "$0" --_locked "${LOCK_ARGS[@]}"
  rc=$?
  rm -f "$MSG_SNAPSHOT"
  [ "$rc" -eq 4 ] && { echo "swarm-commit: LANE-BUSY — another writer held $LOCKFILE for ${TIMEOUT}s; nothing was committed" >&2; echo "NEXT: pick" >&2; }
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
[ "$CUR" = "$BRANCH" ] || { echo "REFUSED [foreign-branch]: HEAD is on '$CUR', this commit was written for '$BRANCH'; stop and touch nothing" >&2; echo "NEXT: handback" >&2; exit 9; }

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
  # every <prefix>-<id> token in the subject is a candidate bead id, any board prefix
  # (not only `ac-`) — the board decides if it IS one via the exact-id lookup below.
  for tok in $(printf '%s\n' "$SUBJECT" | grep -oE '[A-Za-z]+-[A-Za-z0-9][A-Za-z0-9._-]*' | sort -u); do
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
# LEG — unclaimed / outside-scope (ac-ftfz.9). The right bead, the right files, real
# identity: a commit whose subject names bead X is refused unless THIS identity currently
# holds X's claim, and every named path lies inside X's own `## Delivers` scope — the
# SAME path-extraction pattern diff-closure.sh already uses (bead.py's plain-text
# extract_paths; the touchers: line excluded), never a second, divergent definition.
# `## Territory` is deliberately not read here (a fallback scope source owned elsewhere);
# a bead whose Delivers names no path is unscoped and is not checked at all. Exemptions:
# the coordinator's own `[no-bead]` ledger-flush marker and a subject naming no bead token
# pass outright; a row that cannot be parsed is NOT-GATED, never a silent pass — the claim
# and scope could not be verified either way.
# ---------------------------------------------------------------------------------------
BEAD_PY_HOME="$TOOLS_DIR/bead.py"
if [ -n "$SUBJECT" ]; then
  case "$SUBJECT" in
    *"[no-bead]"*) : ;;  # the coordinator's own ledger-flush commit — never any one bead's
    *)
      if [ -f "$BOARD" ] && command -v jq >/dev/null 2>&1; then
        [ -f "$BEAD_PY_HOME" ] || not_gated outside-scope "bead.py missing at '$BEAD_PY_HOME' — scope cannot be derived"
        command -v python3 >/dev/null 2>&1 || not_gated outside-scope "python3 not on PATH — bead.py cannot be run"
        for tok in $(printf '%s\n' "$SUBJECT" | grep -oE '[A-Za-z]+-[A-Za-z0-9][A-Za-z0-9._-]*' | sort -u); do
          row=$(jq -c --arg id "$tok" 'select(.id == $id)' "$BOARD" 2>/dev/null | head -1)
          [ -n "$row" ] || continue

          assignee=$(printf '%s' "$row" | jq -r '.assignee // ""' 2>/dev/null) \
            || not_gated unclaimed "subject names '$tok' but its board row's assignee could not be read — the claim cannot be verified"
          if [ "$assignee" != "$IDENTITY" ]; then
            refuse unclaimed "subject names '$tok', currently claimed by '${assignee:-nobody}', not '$IDENTITY' — this identity does not hold that claim"
          fi

          desc=$(printf '%s' "$row" | jq -r '.description // ""' 2>/dev/null) \
            || not_gated outside-scope "subject names '$tok' but its board row's description could not be read — scope cannot be verified"
          # extract_paths runs as its OWN final command over an already-computed string,
          # never piped straight from awk/grep: under `pipefail`, a truly empty ## Delivers
          # body makes `grep -v` itself exit 1 (nothing to select is not an error, but
          # pipefail cannot tell the two apart) — chained into the pipe, that reads as
          # "bead.py crashed" when it never ran. The filter's own `|| true` keeps its
          # benign non-match off this leg's verdict.
          delivers_section=$(printf '%s\n' "$desc" \
            | awk '/^## Delivers/{on=1; next} /^## /{on=0} on' \
            | grep -v '^[[:space:]]*touchers:' || true)
          scope_list=$(extract_paths "$delivers_section"); ep_rc=$?
          [ "$ep_rc" -eq 0 ] \
            || not_gated outside-scope "bead.py failed extracting Delivers paths for '$tok' (exit $ep_rc)"
          [ -n "$scope_list" ] || continue   # unscoped bead — no path declared, not checked

          for p in "${PATHS[@]}"; do
            pn="${p#./}"
            printf '%s\n' "$scope_list" | grep -qxF "$pn" \
              || refuse outside-scope "path '$p' is not in '$tok''s own ## Delivers scope — own it in this change, or split the commit"
          done
        done
      fi
      ;;
  esac
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
  # Canonicalize before comparing: the same ledger is spelled
  # `./.beads/issues.jsonl`, `.beads//issues.jsonl`, the directory `.beads` /
  # `.beads/` — and git stages the ledger under every one of those spellings, so
  # the check must fire under all of them. A segment stack resolves `.` and `..`
  # lexically (ac-b94y: the ac-qvcb normalizer stripped leading `./` BEFORE
  # collapsing `//`, turning `.//.beads/issues.jsonl` into `/.beads/...`, and
  # never touched dot segments at all — so `.beads/./issues.jsonl` and
  # `a/../.beads/issues.jsonl` each committed silently). A leading `..` is
  # preserved, never resolved: `../.beads/issues.jsonl` names the PARENT's
  # ledger, not this repo's, and must not trip the gate.
  np="$p"
  np_abs=0; case "$np" in /*) np_abs=1 ;; esac
  np_out=""; np_rest="$np"
  while [ -n "$np_rest" ]; do
    case "$np_rest" in
      */*) np_seg="${np_rest%%/*}"; np_rest="${np_rest#*/}" ;;
      *)   np_seg="$np_rest"; np_rest="" ;;
    esac
    case "$np_seg" in
      ""|".") continue ;;
      "..")
        np_top="${np_out##*/}"
        if [ -n "$np_out" ] && [ "$np_top" != ".." ]; then
          case "$np_out" in */*) np_out="${np_out%/*}" ;; *) np_out="" ;; esac
        elif [ "$np_abs" -eq 0 ]; then
          np_out="${np_out:+$np_out/}.."
        fi ;;
      *) np_out="${np_out:+$np_out/}$np_seg" ;;
    esac
  done
  np="$np_out"
  [ "$np_abs" -eq 1 ] && np="/$np"
  case "$np" in
    .beads/issues.jsonl|.beads) LEDGER_IN_PATHS=1 ;;
  esac
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

git add -- "${PATHS[@]}" || { echo "swarm-commit: git add failed; nothing committed" >&2; echo "NEXT: handback" >&2; exit 5; }

if ! git commit -F "$MSGFILE" -- "${PATHS[@]}"; then
  echo "swarm-commit: commit REJECTED (hook or guard); nothing was committed" >&2
  echo "NEXT: repair hook" >&2
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
  git add -- "${PATHS[@]}" || { echo "swarm-commit: re-add failed" >&2; echo "NEXT: handback" >&2; exit 5; }
  # --no-verify on the AMEND only: the hook already ran and produced these exact bytes;
  # re-running it here would rewrite and diverge again, forever. Pathspec still scopes it.
  git commit --amend --no-edit --no-verify -- "${PATHS[@]}" >/dev/null \
    || { echo "swarm-commit: amend REJECTED" >&2; echo "NEXT: repair hook" >&2; exit 5; }
  STILL="$(git diff --name-only HEAD -- "${PATHS[@]}")"
  [ -z "$STILL" ] || { echo "REFUSED [lint-staged-unstable]: worktree still diverges after one repair pass; nothing was committed" >&2; echo "NEXT: repair lint-staged-unstable" >&2; exit 5; }
fi

echo "swarm-commit: committed $(git rev-parse --short HEAD) as $IDENTITY"
exit 0
