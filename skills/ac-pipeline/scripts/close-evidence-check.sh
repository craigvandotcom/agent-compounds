#!/usr/bin/env bash
#
# close-evidence-check.sh — per-type close-evidence gate (ac-on0y.2).
#
# Bead closure verified STATUS and never EVIDENCE. The per-type close-artifact rules
# existed as convention only — bead-conventions § Per-type close artifacts, explicitly
# "presence-checked, not truth-checked" and delegated to closing-skill prose. So "closed"
# meant "an agent merged something", not "proven the way the bead itself declared".
#
# Usage:
#   close-evidence-check.sh [--report-only] [--list-unverifiable] <bead-id> <intended close reason>
#
# Exit 0  evidence present (or legitimately exempt, or --report-only)
# Exit 1  REFUSED — the close reason carries no evidence of the shape this type declares
# Exit 2  NOT-CHECKED — the gate could not verify. Never a pass: a gate that verified
#         nothing must not read as coverage (rule: a-gate-must-fail-when-it-verified-nothing).
#         The UNVERIFIABLE-DELIVERS verdict exits 2 too, but names itself: "the bead is
#         structurally unverifiable" and "this close lacks evidence" are different failures
#         (ac-k25c.7 — a gate whose refusals all look alike trains callers to ignore it).
#
# --list-unverifiable: audit mode. Lists every OPEN task/feature bead whose ## Delivers
# holds no path-shaped token (or is missing) — the population whose closes this gate can
# never verify. Exit 0 with the listing; exit 2 if the board cannot be read.
#
# THE BAR IS PRESENCE + CROSS-REFERENCE, never semantic truth — that stays review's job.
#   bug           -> the reason cites a test-shaped path (the regression test)
#   task/feature  -> the reason names >=1 artifact from THIS bead's own ## Delivers
#   investigation -> the reason cites a spawned bead id or a documented-answer marker
#   epic          -> the reason cites the probe receipt close-gate.sh ran from, AND
#                    every ## Delivers path exists on disk, EXCEPT those declared
#                    under a `deleted-*:` label (`deleted-script:`, `deleted-test:`,
#                    …): their absence is the deliverable, so they are skipped and
#                    never required on disk (exit-0 itself is close-gate.sh's GREEN
#                    leg, which runs before this core). An epic closes when its
#                    children are closed; there is no review receipt to demand
#                    (ac-ac-review-narrowing-aq10.1, .10)
#   human-gate    -> exempt (closure is a recorded human decision)
#
# HISTORICAL CLOSES ARE NEVER SWEPT: this runs at close time, on the bead being closed.
#
# NO BYPASS (ac-m9y4.4): the `--force` flag and its paired recorded-reason marker are both
# deleted — close-gate.sh, this gate's only caller, never passed `--force`, so the escape
# had never fired. The owner's ruling on ac-m9y4.4, 2026-09-27, supersedes ac-bpth. Every
# close now runs the same evidence rule.
#
set -uo pipefail

# The ONE br_call invocation shape (ac-heyt.3); a refusal is a NOT-CHECKED below,
# never empty data. Missing helper = nothing can be read = the same NOT-CHECKED.
# shellcheck source=br-call.sh
_TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../_tools" 2>/dev/null && pwd)"
. "$_TOOLS_DIR/br-call.sh" 2>/dev/null \
  || { echo "close-evidence NOT-CHECKED: br-call.sh helper missing — no board read can be verified" >&2; exit 2; }

# bead.py is the one bead reader every tool parses cards through (ac-m9y4.4): every
# Delivers-path extraction below — task/feature, epic, and the --list-unverifiable audit
# alike — reads through its `delivers()` (the touchers-line exclusion and the dotted
# child-bead-id shape guard are both already built into it there), never a second
# hand-rolled copy of the pattern. Fail-closed: a missing bead.py or python3 is
# NOT-CHECKED here, at load time, never a silent "no artifacts".
[ -f "$_TOOLS_DIR/bead.py" ] \
  || { echo "close-evidence NOT-CHECKED: bead.py missing at $_TOOLS_DIR/bead.py — Delivers paths cannot be derived" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 \
  || { echo "close-evidence NOT-CHECKED: python3 not on PATH — bead.py cannot be run" >&2; exit 2; }

# The program lives in its own file, never a heredoc attached to `python3 -`: a heredoc IS
# the command's stdin, so a text argument piped in on the same command would starve
# `sys.stdin.read()` of everything but EOF (the lesson needs-device-gate.sh's own
# write_device_paths_py already paid for). `BEAD_MODULE_PATH` is the same test-only
# override bead-capture-guard.py's own `_load_bead_module()` uses: a nonexistent path
# drives the crash-path fixture without ever touching the real file in a shared checkout.
_EV_BEAD_HELPER="$(mktemp)"
trap 'rm -f "$_EV_BEAD_HELPER"' EXIT
cat >"$_EV_BEAD_HELPER" <<'PY'
import importlib.util, json, os, sys


def _load_bead():
    override = os.environ.get("BEAD_MODULE_PATH")
    path = override or os.environ["BEAD_PY_PATH"]
    spec = importlib.util.spec_from_file_location("bead", path)
    if spec is None or spec.loader is None:
        raise ImportError(f"cannot load bead.py at {path!r}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _delivers(bead, desc):
    populated = bool(bead.section(desc, "Delivers").strip())
    entries = bead.delivers(desc)
    artifacts = sorted({p for e in entries if not e["deleted_kind"] for p in e["paths"]})
    deleted = sorted({p for e in entries if e["deleted_kind"] for p in e["paths"]})
    return populated, artifacts, deleted


def main():
    bead = _load_bead()
    mode = sys.argv[1]
    if mode in ("task-feature", "epic"):
        with open(sys.argv[2], "r") as f:
            desc = f.read()
        populated, artifacts, deleted = _delivers(bead, desc)
        print(f"POPULATED:{'yes' if populated else 'no'}")
        for a in artifacts:
            print(f"ARTIFACT:{a}")
        if mode == "epic":
            for a in deleted:
                print(f"DELETED:{a}")
        return 0
    if mode == "audit":
        data = json.load(sys.stdin)
        rows = data if isinstance(data, list) else data.get("issues", [])
        count = 0
        for node in rows:
            itype = node.get("issue_type") or ""
            if itype not in ("task", "feature"):
                continue
            iid = node.get("id") or ""
            desc = node.get("description") or ""
            populated, artifacts, _deleted = _delivers(bead, desc)
            if not populated:
                print(f"NO-DELIVERS\t{iid}")
                count += 1
            elif not artifacts:
                print(f"UNVERIFIABLE-DELIVERS\t{iid}")
                count += 1
        print(f"close-evidence: {count} open task/feature bead(s) whose closes can never pass evidence check")
        return 0
    print(f"unknown helper mode {mode!r}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        print(f"NOT-CHECKED: bead.py unavailable or crashed: {e}", file=sys.stderr)
        sys.exit(2)
PY

REPORT_ONLY=0
LIST_UNVERIFIABLE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --report-only) REPORT_ONLY=1; shift ;;
    --list-unverifiable) LIST_UNVERIFIABLE=1; shift ;;
    --) shift; break ;;
    -*) echo "close-evidence-check: unknown flag '$1'" >&2; exit 2 ;;
    *) break ;;
  esac
done

# --- audit mode: the population this gate can never verify -------------------
if [ "$LIST_UNVERIFIABLE" = 1 ]; then
  RAW=$(br_call list --status open --json) \
    || { echo "close-evidence NOT-CHECKED: br_call list refused — the audit verified nothing" >&2; exit 2; }
  if [ -z "$RAW" ]; then
    echo "close-evidence NOT-CHECKED: 'br list' returned nothing — the audit verified nothing" >&2
    exit 2
  fi
  AUDIT_OUT=$(printf '%s' "$RAW" | BEAD_PY_PATH="$_TOOLS_DIR/bead.py" python3 "$_EV_BEAD_HELPER" audit); AUDIT_RC=$?
  [ "$AUDIT_RC" -eq 0 ] \
    || { echo "close-evidence NOT-CHECKED: bead.py audit crashed (exit $AUDIT_RC) — the audit verified nothing" >&2; exit 2; }
  printf '%s\n' "$AUDIT_OUT"
  exit 0
fi

BEAD_ID="${1:-}"
REASON="${2:-}"

verdict() { # <PASS|REFUSE|NOT-CHECKED|EXEMPT> <message> <exit>
  printf 'close-evidence[%s] %s: %s\n' "$BEAD_ID" "$1" "$2"
  if [ "$REPORT_ONLY" = 1 ]; then
    printf 'close-evidence[%s] (report-only: exiting 0 regardless)\n' "$BEAD_ID"
    exit 0
  fi
  exit "$3"
}

if [ -z "$BEAD_ID" ] || [ -z "$REASON" ]; then
  echo "usage: $(basename "$0") [--report-only] <bead-id> <close reason>" >&2
  echo "close-evidence NOT-CHECKED: missing bead id or close reason" >&2
  exit 2
fi

RAW=$(br_call show "$BEAD_ID" --json) \
  || verdict "NOT-CHECKED" "br_call show refused for $BEAD_ID — cannot read the bead's declared evidence" 2
if [ -z "$RAW" ]; then
  verdict "NOT-CHECKED" "'br show' returned nothing for $BEAD_ID — cannot read the bead's declared evidence" 2
fi

# br returns an object for one id and an array for several; normalise.
NODE=$(printf '%s' "$RAW" | jq -c 'if type=="array" then .[0] else . end' 2>/dev/null || true)
if [ -z "$NODE" ] || [ "$NODE" = "null" ]; then
  verdict "NOT-CHECKED" "could not parse br output for $BEAD_ID" 2
fi

ITYPE=$(printf '%s' "$NODE" | jq -r '.issue_type // empty')
LABELS=$(printf '%s' "$NODE" | jq -r '(.labels // []) | join(",")')
DESC=$(printf '%s' "$NODE" | jq -r '.description // ""')

if [ -z "$ITYPE" ]; then
  verdict "NOT-CHECKED" "bead has no issue_type — cannot select an evidence rule" 2
fi

# --- exemptions ------------------------------------------------------------
case ",$LABELS," in
  *,human-gate,*) verdict "EXEMPT" "human-gate bead — closure is a recorded human decision" 0 ;;
esac

# --- per-type rules --------------------------------------------------------
case "$ITYPE" in
  bug)
    # (a) A NON-FIX disposition has no regression test by construction. Demanding one
    #     would refuse every obsolete/duplicate close — measured on 5 of 24 recent bug
    #     refusals in the ac-on0y.2 calibration sweep.
    if printf '%s' "$REASON" \
       | grep -qiE '^[[:space:]]*(obsolete|duplicate|superseded|wont-?fix|not[- ]reproducible|works[- ]as[- ]intended)\b'; then
      verdict "PASS" "bug — non-fix disposition; evidence-of-fix does not apply" 0
    fi

    # (b) The regression test, named.
    if printf '%s' "$REASON" \
       | grep -qE '[A-Za-z0-9_./-]*([Tt]est|[Ss]pec)[A-Za-z0-9_./-]*\.[A-Za-z0-9]+'; then
      verdict "PASS" "bug — close reason cites a test-shaped path" 0
    fi

    # (c) Prose/doc/config bugs prove themselves with a grep/diff probe, not a test file
    #     — the SAME temporal shape (recorded before-state -> measured after-state).
    #     Requires BOTH a probe command and a before/after marker, so a bare mention of
    #     the word "grep" is not evidence. Measured: 13 of 24 recent bug refusals were
    #     this class, each carrying real recorded evidence.
    if printf '%s' "$REASON" | grep -qE '\b(grep|rg|diff|jq|awk|sed)\b' \
       && printf '%s' "$REASON" | grep -qE '(->|→|\bwas\b|\bnow\b|exit(s|=)|no hits|hits=)'; then
      verdict "PASS" "bug — close reason records a grep/diff probe with a before/after state" 0
    fi

    verdict "REFUSE" "bug — close reason shows no regression evidence: no test path, no recorded grep/diff before-after, no non-fix disposition" 1
    ;;

  investigation)
    if printf '%s' "$REASON" | grep -qE '\b[a-z]{2,}-[a-z0-9]{3,}(\.[0-9]+)*\b'; then
      verdict "PASS" "investigation — close reason cites a spawned bead id" 0
    fi
    if printf '%s' "$REASON" | grep -qE '(ANSWER:|FINDINGS:|[A-Za-z0-9_./-]+\.md)'; then
      verdict "PASS" "investigation — close reason cites a documented answer" 0
    fi
    verdict "REFUSE" "investigation — close reason names neither a spawned bead id nor a documented answer" 1
    ;;

  task|feature)
    # Delivers extraction reads through bead.py's `delivers()` (ac-m9y4.4) — the touchers-
    # line exclusion is already built in there, never a second hand-rolled copy.
    _DESCFILE=$(mktemp) || verdict "NOT-CHECKED" "cannot create a scratch file for the Delivers read" 2
    printf '%s' "$DESC" >"$_DESCFILE"
    _HELP_OUT=$(BEAD_PY_PATH="$_TOOLS_DIR/bead.py" python3 "$_EV_BEAD_HELPER" task-feature "$_DESCFILE" 2>&1); _HELP_RC=$?
    rm -f "$_DESCFILE"
    [ "$_HELP_RC" -eq 0 ] \
      || verdict "NOT-CHECKED" "bead.py failed extracting Delivers paths: $_HELP_OUT" 2

    _POPULATED=$(printf '%s\n' "$_HELP_OUT" | sed -n 's/^POPULATED://p')
    if [ "$_POPULATED" != "yes" ]; then
      verdict "NOT-CHECKED" "$ITYPE has no populated '## Delivers' section — there is no declared artifact to cross-reference. Give the bead a Delivers section" 2
    fi

    ARTIFACTS=$(printf '%s\n' "$_HELP_OUT" | sed -n 's/^ARTIFACT://p')

    if [ -z "$ARTIFACTS" ]; then
      verdict "UNVERIFIABLE-DELIVERS" "$ITYPE bead $BEAD_ID carries a prose-only '## Delivers' — no path-shaped artifact exists to cross-reference, so NO close of this bead can ever pass evidence check. Fix the bead (give Delivers a path). Audit siblings: close-evidence-check.sh --list-unverifiable" 2
    fi

    while IFS= read -r art; do
      [ -n "$art" ] || continue
      if printf '%s' "$REASON" | grep -qF -- "$art"; then
        verdict "PASS" "$ITYPE — close reason names declared artifact '$art'" 0
      fi
      # A bare basename in the reason still cross-references the promise.
      base="${art##*/}"
      if [ "$base" != "$art" ] && printf '%s' "$REASON" | grep -qF -- "$base"; then
        verdict "PASS" "$ITYPE — close reason names declared artifact '$base'" 0
      fi
    done <<< "$ARTIFACTS"

    printf 'close-evidence[%s] declared artifacts:\n' "$BEAD_ID" >&2
    printf '  - %s\n' $ARTIFACTS >&2
    verdict "REFUSE" "$ITYPE — close reason names NONE of the artifacts this bead's own ## Delivers promised" 1
    ;;

  epic)
    # An epic closes on its children's temporal pairs: the close reason cites the probe
    # receipt line close-gate.sh ran from, and every ## Delivers path must exist on disk —
    # the epic promises integration, so a promised path that was never created is a
    # refusal, not a wave-through. (That every probe exited 0 is close-gate.sh's GREEN
    # leg, which runs before this core; the citation is what lands it in the record.)
    #
    # Delivers extraction reads through bead.py's `delivers()` (ac-m9y4.4): the
    # touchers-line exclusion and the dotted child-bead-id shape guard (a touchers line's
    # `owned by: <child bead id>` is path-shaped but is not a file — measured on ac-4y7l,
    # whose nine Delivers bullets each name their owner bead) are both already built in
    # there, never a second hand-rolled copy. A `deleted-*:` declaration (`deleted-script:`,
    # `deleted-test:`, …) promises the artifact's ABSENCE: the deletion IS the deliverable,
    # verified by the closing child's own `test ! -e` probes and the closeout's
    # delivered-marker — never by a file on disk, so it is read separately (DELETED) and
    # never required to exist. Measured live on ac-ac-review-narrowing-aq10: 9/9 children
    # closed, 6/6 probes green, refused on the two files its own D6 deleted.
    _DESCFILE=$(mktemp) || verdict "NOT-CHECKED" "cannot create a scratch file for the Delivers read" 2
    printf '%s' "$DESC" >"$_DESCFILE"
    _HELP_OUT=$(BEAD_PY_PATH="$_TOOLS_DIR/bead.py" python3 "$_EV_BEAD_HELPER" epic "$_DESCFILE" 2>&1); _HELP_RC=$?
    rm -f "$_DESCFILE"
    [ "$_HELP_RC" -eq 0 ] \
      || verdict "NOT-CHECKED" "bead.py failed extracting Delivers paths: $_HELP_OUT" 2

    _POPULATED=$(printf '%s\n' "$_HELP_OUT" | sed -n 's/^POPULATED://p')
    if [ "$_POPULATED" != "yes" ]; then
      verdict "NOT-CHECKED" "epic has no populated '## Delivers' section — there is no declared artifact to cross-reference. Give the bead a Delivers section" 2
    fi

    ARTIFACTS=$(printf '%s\n' "$_HELP_OUT" | sed -n 's/^ARTIFACT://p')
    DELETED_ARTIFACTS=$(printf '%s\n' "$_HELP_OUT" | sed -n 's/^DELETED://p')

    if [ -z "$ARTIFACTS" ] && [ -z "$DELETED_ARTIFACTS" ]; then
      verdict "UNVERIFIABLE-DELIVERS" "epic bead $BEAD_ID carries a prose-only '## Delivers' — no path-shaped artifact exists to cross-reference, so NO close of this bead can ever pass evidence check. Fix the bead (give Delivers a path). Audit siblings: close-evidence-check.sh --list-unverifiable" 2
    fi

    if ! printf '%s' "$REASON" | grep -qiE 'probe receipt'; then
      verdict "REFUSE" "epic — close reason cites no probe receipt: an epic closes on its children's temporal pairs, so the reason must cite the probe receipt line close-gate.sh ran from (every probe exit 0)" 1
    fi

    MISSING=""
    while IFS= read -r art; do
      [ -n "$art" ] || continue
      if ! printf '%s' "$REASON" | grep -qF -- "$art"; then
        base="${art##*/}"
        if [ "$base" = "$art" ] || ! printf '%s' "$REASON" | grep -qF -- "$base"; then
          verdict "REFUSE" "epic — close reason names NONE of the artifacts this bead's own ## Delivers promised (missing '$art')" 1
        fi
      fi
      [ -e "$art" ] || MISSING="$MISSING $art"
    done <<< "$ARTIFACTS"

    if [ -n "$MISSING" ]; then
      verdict "REFUSE" "epic — declared artifact(s) missing on disk:$MISSING" 1
    fi

    verdict "PASS" "epic — close reason cites the probe receipt and every declared artifact exists" 0
    ;;

  *)
    verdict "EXEMPT" "issue_type '$ITYPE' has no declared per-type close artifact" 0
    ;;
esac
