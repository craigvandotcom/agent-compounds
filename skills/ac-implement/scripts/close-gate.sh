#!/usr/bin/env bash
#
# close-gate.sh — the ac2 TEMPORAL causal-necessity probe at close (ac-k25c.3).
#
# ASSURANCE
#   PROBE:      bash skills/ac-implement/scripts/close-gate.test.sh
#   SCHEDULE:   every ac2 worker close; the harness runs on every
#               scripts/run-all-proofs.sh invocation, which lint.sh Check 20 audits.
#   MODE:       blocking
#   ON-FAILURE: closed
#
# THE CLAIM IT MAKES, AND THE ONLY ONE:
#
#   RED before the diff · the test UNCHANGED · GREEN after the diff
#   ------------------------------------------------------------------
#   therefore the diff CAUSED the flip.
#
# The RED was captured at flight-check, with its assertion fingerprint recorded BEFORE the
# diff existed. Here the same test — hash-locked since that receipt, an unchanged-test
# guarantee one checksum buys — runs GREEN. Prose and config beads take the same temporal
# shape using the AC's own grep or diff check; no separate class, no separate gate.
#
# This replaces six prose conventions a worker used to self-audit, and it structurally kills
# the vacuous-AC class: an AC that was already green at claim never got a receipt, so there
# is nothing here to close against.
#
# OUT OF SCOPE, deliberately:
#   - spatial isolation (worktrees survive only where ac-review's destructive sabotage
#     probes need them)
#   - writing VERDICT comments — those belong to the VERIFIER, never the implementer.
#     That separation is the Goodhart guard: the party optimising against the measure does
#     not get to record the verdict.
#   - suite-level green. The local run is PER-BEAD only. Suite green is the batch CI
#     layer's verdict on the committed tree and is never a shared-tree local claim.
#
# THE OWN-HARNESS CARVE-OUT (why the hash leg does not refuse every close in this bead set):
#   A bead that DELIVERS ITS OWN HARNESS has no test at claim, so flight-check re-runs once
#   the harness is written and BEFORE any fix, and the fingerprint it records THEN is what
#   this lock runs from. One writer, one receipt format, two moments. Without the carve-out
#   the hash leg would refuse every close in this very epic, all of whose code beads deliver
#   their own harness.
#
# THE PROSE SCOPE (`subject-scoped`, ac-hnsc): a prose or config bead's probe names the file
#   the bead itself edits, so the receipt hash-locks the probe COMMAND alone and the SUBJECT is
#   free to move — otherwise this leg is unsatisfiable for every prose bead by construction.
#   The full argument, and the guard that keeps a harness-bearing bead out of it, sits at LEG 3.
#
# THE DISPOSITION CARVE-OUT (ac-triage): a close whose reason leads with a disposition
# verb (obsolete: / duplicate: / superseded:) claims "the state this bead aimed at is
# settled" — never "a diff caused a flip". The claim is verified by whichever leg actually
# holds, decided HERE, never assumed:
#   (e-green)   every AC probe exits 0 at HEAD — the work exists; someone else landed it
#   (e-cascade) every `## Consumes` blocker is CLOSED with a disposition close reason —
#               the premise is gone by the plan's own closure (close_reason read live
#               from the board, with flight-check's exact-id/prefix resolution)
# wontfix: EXCLUDED — "we decided not to build this" is intent, and intent stays human.
# A disposition close may land even where the temporal pair is unavailable (no receipt,
# or a receipt whose RED probe is still red); a shipped:/fixed: close may not.
#
# Usage:
#   close-gate.sh <bead-id> --reason "<close reason>" [--actor <name>]
#                 [--vitest-json <report>]
#                 [--body-file <path>] [--root <repo>] [--dry-run]
#
# Env:
#   AC2_FLIGHT_DIR  where flight-check wrote the receipt (default <git-common-dir>/ac-flight)
#   AC2_BR_CMD      the br binary to use (default: br) — the seam the harness drives
#
# Exit 0  the causal claim holds and the close LANDED
# Exit 1  CLOSE-REFUSED — a named leg failed; the bead stays open
# Exit 2  NOT-CHECKED — this gate could not verify. NEVER a pass: a gate that verified
#         nothing must not read as coverage.
#
set -uo pipefail

BEAD=""; REASON=""; ACTOR=""; BODY_FILE=""; ROOT=""; DRY=0; VITEST_JSON=""

while [ $# -gt 0 ]; do
  case "$1" in
    --reason)      REASON="${2:-}"; shift 2 ;;
    --actor)       ACTOR="${2:-}"; shift 2 ;;
    --body-file)   BODY_FILE="${2:-}"; shift 2 ;;
    --root)        ROOT="${2:-}"; shift 2 ;;
    --vitest-json) VITEST_JSON="${2:-}"; shift 2 ;;
    --dry-run)     DRY=1; shift ;;
    -h|--help)     sed -n '2,55p' "${BASH_SOURCE[0]}"; exit 0 ;;
    -*)            echo "NOT-CHECKED: unknown option '$1'" >&2; exit 2 ;;
    *)             [ -z "$BEAD" ] && BEAD="$1" || { echo "NOT-CHECKED: unexpected argument '$1'" >&2; exit 2; }; shift ;;
  esac
done

[ -n "$BEAD" ]   || { echo "NOT-CHECKED: usage: $0 <bead-id> --reason '<close reason>'" >&2; exit 2; }
[ -n "$REASON" ] || { echo "NOT-CHECKED: no --reason given — the evidence core has nothing to cross-reference" >&2; exit 2; }

if [ -z "$ROOT" ]; then
  # ROOT is the CONSUMER repo's root, never the script's own repo: these scripts are
  # symlinked into consumer repos via .agents/skills/, so script-relative resolution
  # lands inside the skills checkout (or .agents/) and every repo-relative probe
  # dies with FileNotFoundError. Derive from the calling repo's git toplevel.
  ROOT=$(git rev-parse --show-toplevel 2>/dev/null) \
    || ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd) \
    || ROOT="$PWD"
fi
cd "$ROOT" || { echo "NOT-CHECKED: cannot enter repo root '$ROOT'" >&2; exit 2; }

# The ONE br_call invocation shape (ac-heyt.3). Path computed BEFORE the cd above:
# BASH_SOURCE may be relative, so the absolute helper path must resolve from the original
# cwd. br_call honors AC2_BR_CMD, so the seam declared below keeps applying to the reads.
# shellcheck source=br-call.sh
BR_CALL="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../_tools" 2>/dev/null && pwd)/br-call.sh"

BR="${AC2_BR_CMD:-br}"
EVIDENCE_CORE="$ROOT/skills/ac-pipeline/scripts/close-evidence-check.sh"
# Vendored-copy layout: app repos track these scripts under .agents/skills/ (the
# agent-compounds registry layout puts skills/ at the repo root), so the evidence
# core may sit one level deeper. Try the canonical path first, then the vendored one.
[ -f "$EVIDENCE_CORE" ] \
  || EVIDENCE_CORE="$ROOT/.agents/skills/ac-pipeline/scripts/close-evidence-check.sh"

refuse()      { echo "CLOSE-REFUSED: $1 — refusing: $2"; exit 1; }
not_checked() { echo "NOT-CHECKED: $1 — $2" >&2; exit 2; }

. "$BR_CALL" 2>/dev/null || not_checked "READ" "br-call.sh helper missing at '$BR_CALL' — no br read can be verified"

sha256_of_stdin() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'
  else return 1
  fi
}

is_test_shaped() {
  case "$1" in
    *.test.sh|*.test.py|*.test.ts|*.test.js|*.test.tsx|*.spec.ts|*.spec.js|*.spec.tsx) return 0 ;;
    *_test.go|*_test.py|*_test.rb|*Test.java|*Tests.swift)                             return 0 ;;
    *) return 1 ;;
  esac
}

# A probe whose stdout is SUPPRESSED BY CONSTRUCTION can never carry assertion lines:
# a silent test (-q or --quiet) or a redirect into /dev/null produces nothing to count, so selecting
# it as the assertion-bearing probe bails COVERAGE on a bead whose harness asserts fine
# (measured: ac-close-gate-coverage-silent-probe-ja8l, instances 4 and 5). Deliberately
# static — it reads the probe's CONSTRUCTION, never its run: a harness that ran but
# emitted nothing stays NOT-CHECKED, because a run that asserted nothing reads identical
# to one that passed.
is_output_silent() {
  case "$1" in
    *grep\ -q*|*rg\ -q*|*\|grep\ -q*|*\>/dev/null*|*\>/\ dev/null*|*--quiet*) return 0 ;;
  esac
  # A probe composed solely of existence predicates (`test -f/-d`, `[ ... ]`) joined by
  # connectors emits nothing by construction — `test` has no stdout — so it can never
  # carry assertion lines either (measured: heyt P1 `test -f` chain shadowing the
  # asserting runner probe). Strip predicates and connectors; silence is an empty rest.
  local rest
  rest=$(printf '%s' "$1" | sed -E 's/test[[:space:]]+-[a-zA-Z]+[[:space:]]+[^&|;]+//g; s/\[[^]]*\]//g; s/&&|\|\||;//g; s/[[:space:]]//g')
  [ -z "$rest" ]
}

br_field() { # <bead-id> <jq field> -> value; a REFUSED read is a NOT-CHECKED, never empty data
  local v
  v=$(br_call show "$1" --json </dev/null \
    | jq -r "if type == \"array\" then .[0] else . end | .$2 // \"\"" 2>/dev/null) \
    || not_checked "READ" "br_call show refused for $1 — the gate cannot verify this close"
  printf '%s\n' "$v"
}

# ---------------------------------------------------------------------------------------
# THE TYPE-ROUTED RULING PATH — a `decision`-type bead, or one labelled `human-gate`, closes
# on a recorded ruling comment, never on the probe machinery below. This is a REAL skip, not
# a leg-outcome change: no RED-receipt read, no PROBE-DRIFT, no UNCOMMITTED, no GREEN/COVERAGE,
# no EVIDENCE core, no claim taken, and no ownership pre-check — a recorded ruling ends a
# decision bead whoever holds it. Every other `issue_type`/label combination falls through
# to the unchanged leg 1-8 flow below.
#
# WHO MAY RULE (the owner's ruling on ac-4y7l.21, list location per ac-4y7l.30): every
# no-probe close requires a ruling signed by a name on the CLOSING BOARD's own `.beads/config.yaml`
# `humans:` key (comma-separated; `<human>` in every template is copied VERBATIM from that
# key — skills/beads-standards/reference/bead-conventions.md and
# skills/ac-human/references/action-loop.md both point here, never restate the list). A board
# with no key authorizes nobody — fail closed, not NOT-CHECKED: a missing/empty list is a
# deterministic "nobody", the same as any other unlisted name. The only non-human ruling
# accepted is the exact `DECISION (ac-tidy): moot` on a bead labelled `pipeline-proposal` — a
# non-`moot` ac-tidy ruling is refused like any other unauthorized actor. OUT: verifying that
# the named human actually wrote the comment (plan risk R1).
# ---------------------------------------------------------------------------------------
BEAD_TYPE=$(br_field "$BEAD" issue_type)
BEAD_LABELS=$(br_call show "$BEAD" --json </dev/null \
  | jq -r 'if type == "array" then .[0] else . end | (.labels // []) | join(",")' 2>/dev/null) \
  || not_checked "READ" "br_call show refused for $BEAD — the gate cannot verify this close"
has_label() { case ",$BEAD_LABELS," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }

# read_humans — the closing board's `humans:` key, raw (comma-separated, untrimmed).
# A missing file or missing key prints nothing — fail closed, never an error: "no key" IS
# "authorizes nobody" (the owner's ruling on ac-4y7l.30), not an unverifiable state.
#
# TWO FILES, local first (2026-09-20 agnosticism pass): the TRACKED `config.yaml` is
# published, so it ships a placeholder that deliberately matches no real actor — a public
# registry must not name one deployment's humans, and an adopter must never silently
# inherit someone else's ruling authority. Real names go in `.beads/config.local.yaml`,
# which `.beads/.gitignore` excludes. The local file WINS when it carries the key; the
# tracked file answers only when it does not. Both absent still means authorizes nobody.
read_humans() {
  local local_cfg="$ROOT/.beads/config.local.yaml"
  local cfg="$ROOT/.beads/config.yaml"
  local val=""
  [ -f "$local_cfg" ] && val=$(grep -m1 '^humans:' "$local_cfg" | sed 's/^humans:[[:space:]]*//')
  if [ -z "$val" ] && [ -f "$cfg" ]; then
    val=$(grep -m1 '^humans:' "$cfg" | sed 's/^humans:[[:space:]]*//')
  fi
  [ -n "$val" ] && printf '%s\n' "$val"
  return 0
}

# human_is_authorized <actor> <humans-csv> — split the csv on commas; each entry is trimmed
# of LEADING/TRAILING whitespace only, so a multi-word name ("Alice Smith") is compared
# as one whole entry, never split on its own inner spaces.
human_is_authorized() {
  local actor entry
  actor=$(printf '%s' "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  [ -n "$2" ] || return 1
  local IFS=,
  for entry in $2; do
    entry=$(printf '%s' "$entry" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ "$entry" = "$actor" ] && return 0
  done
  return 1
}

# find_authorized_ruling — the ONE matcher for a recorded "DECISION (<actor>): ..." comment
# signed by an authorized human (or the exact `DECISION (ac-tidy): moot` on a
# `pipeline-proposal` bead). Sets $RULING to the authorized line, or empty when none is
# found/authorized. The type-routed ruling path below is its one caller.
# A ruling is a comment's own FIRST
# LINE, at column 0, naming an actor that is not a bare template placeholder (`<human>`) —
# this excludes both an indented draft buried inside a longer note and an unfilled template
# quoted on a memo's second line.
#
# THE NEWEST AUTHORIZED RULING WINS: every DECISION-shaped first line across every comment is
# checked, in board order (oldest first), and each authorized one OVERWRITES $RULING — so an
# earlier `DECISION (agent)` never blocks a later valid human ruling, and between two human
# rulings the newer one stands, never the first `grep -m1` hit found.
#
#   Return 0 — the comments read succeeded (RULING may still be empty: none was authorized).
#   Return 1 — the comments read itself refused; the type-routed path reads that as
#              NOT-CHECKED.
#
# Also sets $RULING_COMMENT_ID to the winning comment's own `id` — LEG 8's landing record
# cites it (`ruling-comment: #<id>`) so check 35 rule 6 (ac-4y7l.31) can cross-reference the
# ruling back to a real comment on the row, never a bare unverifiable claim.
find_authorized_ruling() {
  local comments_json rows cid ctext actor humans_csv
  RULING=""; RULING_COMMENT_ID=""
  comments_json=$(br_call comments list "$BEAD" --json </dev/null 2>/dev/null) || return 1
  rows=$(printf '%s' "$comments_json" \
    | jq -r '.[] | [(.id // ""), ((.text // "") | split("\n")[0])] | @tsv' 2>/dev/null)
  [ -n "$rows" ] || return 0
  humans_csv=$(read_humans)
  while IFS=$'\t' read -r cid ctext; do
    [ -n "$ctext" ] || continue
    printf '%s' "$ctext" | grep -qE '^DECISION \([^<)][^)]*\): \S' || continue
    actor=$(printf '%s' "$ctext" | sed -n 's/^DECISION (\([^)]*\)):.*/\1/p')
    [ -n "$actor" ] || continue
    if [ "$actor" = "ac-tidy" ]; then
      if has_label "pipeline-proposal" \
         && printf '%s' "$ctext" | grep -qE '^DECISION \(ac-tidy\): moot([[:space:]]|$)'; then
        RULING="$ctext"; RULING_COMMENT_ID="$cid"
      fi
    elif human_is_authorized "$actor" "$humans_csv"; then
      RULING="$ctext"; RULING_COMMENT_ID="$cid"
    fi
  done <<EOF
$rows
EOF
  return 0
}

if [ "$BEAD_TYPE" = "decision" ] || has_label "human-gate"; then
  find_authorized_ruling \
    || not_checked "DECISION" "comments list refused for $BEAD — a ruling cannot be verified"
  if [ -z "$RULING" ]; then
    echo "CLOSE-REFUSED DECISION: no 'DECISION (<actor>): ...' comment on $BEAD is both a real ruling (first line, column 0, no placeholder actor) and signed by an authorized human — or ac-tidy on a pipeline-proposal bead — a ruling must be recorded before this bead can close" >&2
    exit 1
  fi
  if [ "$DRY" = 1 ]; then
    echo "close-gate[$BEAD] DRY-RUN — ruling path: would close on the recorded ruling: $RULING"
    exit 0
  fi
  command -v "$BR" >/dev/null 2>&1 || not_checked "OWNERSHIP" "br unavailable — the ruling close cannot be verified"
  RULE_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)
  RULE_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  RULE_TEXT="GATE: decided — $BEAD — $REASON; ruling verified: $RULING (ruling-comment: #${RULING_COMMENT_ID:-none}; at $RULE_SHA by ${ACTOR:-<unattributed>} at $RULE_TS)"
  # The landing record commits ATOMICALLY with the close via --transition-comment (br
  # 0.5.12) — no separate post-close write, so no post-close RECORD-FAILED can follow a
  # close that already landed.
  "$BR" close "$BEAD" --reason "$REASON" --transition-comment "$RULE_TEXT" </dev/null >/dev/null 2>&1 || true
  POST_STATUS=$(br_field "$BEAD" status)
  [ "$POST_STATUS" = "closed" ] \
    || refuse "LANDING" "the close did not land — $BEAD reads '$POST_STATUS' after the write"
  echo "close-gate[$BEAD] GATE: decided RECORDED on the bead"
  echo "close-gate[$BEAD] CLOSED — ruling: a recorded DECISION comment authorized this close; no probe legs were run."
  exit 0
fi

# THE DISPOSITION VERB: parsed from the close reason, never from the bead's labels — the
# reason is the caller's claim, and this gate judges claims. Leading whitespace allowed;
# `wontfix` is deliberately absent (intent stays human).
DISPOSITION=0
case "$(printf '%s' "$REASON" | sed -E 's/^[[:space:]]+//')" in
  obsolete:*|duplicate:*|superseded:*) DISPOSITION=1 ;;
esac
CASCADE_DETAIL=""

# consumes_state — condition (e)'s premise reader, verified live from the board: every
# `## Consumes` blocker line must resolve to a bead CLOSED (any close reason) for a
# disposition close at all — an OPEN blocker is a live premise, and a close that kills a
# live premise is intent, not triage. CONSUMES_DISPO additionally demands a disposition
# verb on every blocker's close_reason (the cascade leg). The Consumes line shape and the
# blocker extraction are flight-check.sh's (Refusal 1), including its exact-id/prefix
# resolution — the two gates cannot drift apart on what a premise is. Zero blocker lines
# (`## Consumes: none`) reads as closed: no premise, nothing alive.
CONSUMES_CLOSED=0
CONSUMES_DISPO=0
cascade_holds() {
  local lines line blocker bnode bstatus bclose detail="" full
  CONSUMES_CLOSED=0; CONSUMES_DISPO=0
  lines=$(awk '/^## /{ inb = ($0 ~ "^## Consumes([[:space:]]|$)") ? 1 : 0; next }
                inb { print }' "$BODY" | sed 's/^[[:space:]]*-[[:space:]]*//' | grep -v '^[[:space:]]*$')
  if [ -z "$lines" ]; then
    CONSUMES_CLOSED=1; CONSUMES_DISPO=1; return 0
  fi
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "$line" in *"->"*) ;; *) continue ;; esac
    blocker=$(printf '%s' "$line" | sed -n 's/^\([A-Za-z][A-Za-z0-9._-]*\).*/\1/p' | sed 's/[-._]*$//')
    [ -n "$blocker" ] || continue
    bnode=$(br_call show "$blocker" --json </dev/null 2>/dev/null) || bnode=""
    if [ -z "$bnode" ]; then
      # br matches EXACT ids only; a Consumes line may cite a unique prefix — resolve
      # exactly one, the same rule flight-check applies. An ambiguous or absent blocker
      # fails BOTH legs: the premise cannot be proven settled.
      full=$(br_call list --json --limit 0 </dev/null \
        | jq -r --arg b "$blocker" \
            '[.issues[] | select(.id | startswith($b)) | .id]
               | if length == 1 then .[0] elif length == 0 then "" else "AMBIGUOUS" end' 2>/dev/null) || full=""
      if [ -n "$full" ] && [ "$full" != "AMBIGUOUS" ]; then
        blocker="$full"
        bnode=$(br_call show "$blocker" --json </dev/null 2>/dev/null) || bnode=""
      fi
    fi
    [ -n "$bnode" ] || return 0
    bstatus=$(printf '%s' "$bnode" | jq -r 'if type == "array" then .[0] else . end | .status // ""' 2>/dev/null)
    [ "$bstatus" = "closed" ] || return 0
    bclose=$(printf '%s' "$bnode" | jq -r 'if type == "array" then .[0] else . end | (.close_reason // .closeReason // "")' 2>/dev/null)
    # The BLOCKER's own disposition may be any non-fix verb — the intent decision was
    # already made and recorded on the blocker; the child close merely reads it back.
    case "$bclose" in
      obsolete:*|duplicate:*|superseded:*|wontfix:*|wont-fix:*) detail="$detail $blocker($(printf '%s' "$bclose" | cut -c1-60))" ;;
      *) CONSUMES_CLOSED=1; return 0 ;;
    esac
  done <<EOF
$lines
EOF
  CONSUMES_CLOSED=1
  [ -n "$detail" ] || return 0
  CASCADE_DETAIL="$detail"
  CONSUMES_DISPO=1
  return 0
}

# ---------------------------------------------------------------------------------------
# LEG 1 — RED-RECEIPT. The temporal anchor: this bead was observed RED before the diff.
# Whether the diff CAUSED the flip is judged by ac-review (causal sufficiency), not
# proven here — a checksum shows a file did not change, never that a change sufficed.
# ---------------------------------------------------------------------------------------
FLIGHT_DIR="${AC2_FLIGHT_DIR:-$(git rev-parse --git-common-dir 2>/dev/null || echo .)/ac-flight}"
RECEIPT_FILE="$FLIGHT_DIR/${BEAD}.flight-receipt"

# Receipts APPEND. The LAST one is the moment the lock runs from — for a bead that wrote its
# own harness, that is the re-invocation, not the claim.
LAST=$(awk '/^FLIGHT-RECEIPT v1/{buf=""} {buf = buf $0 "\n"} END{printf "%s", buf}' "$RECEIPT_FILE" 2>/dev/null)
rfield() { printf '%s\n' "$LAST" | grep -m1 "^$1:" | sed "s|^$1:[[:space:]]*||"; }

RED_PROBE=$(rfield 'red-probe')
RED_BEAD=$(rfield 'bead')
RED_AT=$(rfield 'at')

# THE FRESH-VERIFICATION CARVE-OUT (ac-close-gate-already-green-carveout-8r3o, extended by
# run 20260907-exhaust): a bead with no usable claim-time receipt banks no temporal anchor,
# so LEG 1 refused every future close of it — an honest obsolete:/duplicate: disposition
# whose evidence core would otherwise pass (measured: 4 beads dead on the identical verbatim
# refusal), and legitimate shipped: closes of cross-repo work whose probes could not resolve
# from the claim cwd (measured: ac-dream-docket-sweep-mgzw, ac-dream-emitter-born-verified-uo7n,
# 2026-09-08). ANY disposition now closes through the fresh-verify leg instead, under four
# conditions:
#   (a) EVERY AC probe exits 0 at HEAD, and the per-probe results are recorded in the
#       FRESH-VERIFY comment at landing — never a bare summary;
#   (b) the close reason still names a Delivers artifact the evidence core resolves (LEG 7);
#   (c) a usable claim-time receipt still takes precedence — the temporal pair is the
#       preferred proof whenever it exists;
#   (d) the abuse-guard: a fresh-verify attempt on a bead with ANY not-green probe is
#       REFUSED. A fresh close claims only that the state the bead aimed at holds at HEAD;
#       it never claims a diff caused a flip.
# A red-probe disposition close routes through the DISPOSITION carve-out instead
# (condition e, the cascade — see the header).
FRESH_VERIFY=0
if [ ! -s "$RECEIPT_FILE" ] || [ -z "$RED_PROBE" ] || [ "$RED_BEAD" != "$BEAD" ]; then
  FRESH_VERIFY=1
  echo "close-gate[$BEAD] RED-RECEIPT fresh-verify — no usable claim-time receipt (missing, empty, or for another bead); every AC probe is verified green at HEAD below and the per-probe results are recorded on the bead at landing"
fi
[ "$FRESH_VERIFY" = 1 ] || echo "close-gate[$BEAD] RED-RECEIPT ok — RED was: $RED_PROBE"

# ---------------------------------------------------------------------------------------
# LEG 2 — PROBE-DRIFT. The RED probe must still be an AC of this bead. Otherwise the
# acceptance criterion was rewritten after the RED was banked, and the GREEN below answers
# a question nobody is asking any more.
# ---------------------------------------------------------------------------------------
BODY=$(mktemp "${TMPDIR:-/tmp}/ac-close-body.XXXXXX") || not_checked "SETUP" "cannot create a scratch file"
trap 'rm -f "$BODY"' EXIT

if [ -n "$BODY_FILE" ]; then
  [ -r "$BODY_FILE" ] || not_checked "PROBE-DRIFT" "body file '$BODY_FILE' is unreadable"
  cat "$BODY_FILE" >"$BODY"
elif command -v "$BR" >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  br_field "$BEAD" description >"$BODY"
else
  not_checked "PROBE-DRIFT" "no --body-file and br/jq unavailable — the bead's ACs are unreadable"
fi
[ -s "$BODY" ] || not_checked "PROBE-DRIFT" "bead '$BEAD' has an empty body — it declares no ACs to close against"

PROBES=$(grep -o 'Probe: `[^`]*`' "$BODY" | sed 's/^Probe: `//; s/`$//')
PROBE_EXPECTED=$(printf '%s\n' "$PROBES" | grep -c '[^[:space:]]' || true)
[ "$PROBE_EXPECTED" -gt 0 ] || not_checked "PROBE-DRIFT" "bead '$BEAD' names zero extractable probes — there is nothing to run"

if [ "$FRESH_VERIFY" = 1 ]; then
  echo "close-gate[$BEAD] PROBE-DRIFT fresh-verify — no claim-time RED probe; every live AC probe is re-run below instead"
elif printf '%s\n' "$PROBES" | grep -qxF "$RED_PROBE"; then
  echo "close-gate[$BEAD] PROBE-DRIFT ok — the RED probe is still a live AC"
else
  # The receipt exists but its fingerprinted probe is no longer among the live ACs — the
  # criterion was rewritten after the RED was banked, so no temporal pair can be formed and
  # the receipt cannot take precedence (condition c). Fresh verification takes over: every
  # live AC probe must be green at HEAD, and any red probe refuses (condition d).
  FRESH_VERIFY=1
  echo "close-gate[$BEAD] PROBE-DRIFT drift — the fingerprinted RED probe is no longer among the live ACs; the receipt cannot anchor a temporal pair, so the fresh-verify leg runs"
fi

# ---------------------------------------------------------------------------------------
# LEG 3 — UNCOMMITTED. A Delivers path the working tree carries but no commit does cannot
# support a close: the probes below run in the working tree, so a green there can be a
# green no commit carries. Runs before the probe legs and covers shipped/fixed and
# disposition closes alike, so a caller that closes through this gate inherits the leg.
# Ignored and committed-clean paths print nothing under `git status --porcelain` and pass.
# Outside a git work tree the leg reports the skip; it never implies clean.
#
# THE VERDICT IS NOT READABLE OFF AMBIENT CONFIG (ac-fy8s): bare `git status --porcelain`
# honors `status.showUntrackedFiles`, so a config the gated party controls — the repo's own
# `.git/config`, or `~/.gitconfig` — set to `no` silences untracked entries, this leg reads
# the silence as committed-clean, and the close LANDS over a delivery that exists in no
# commit. The explicit `--untracked-files=all` below is a command-line mode, which overrides
# any such config: only the commit state can decide the verdict. The carve-out is preserved
# — an IGNORED path (a .gitignore entry) still prints nothing and still passes, because that
# is the leg's documented shape, not a silence bought by config.
#
# THE VERDICT IS NOT READABLE OFF INDEX STATE EITHER (ac-jdkb): the index carries per-path
# bits — `git update-index --assume-unchanged <path>` and `--skip-worktree <path>` — that tell
# git to SKIP the working-tree file when it computes status. A modified Delivers path with
# either bit set prints nothing under `git status --porcelain --untracked-files=all`, so a
# status-derived verdict certifies committed-clean over content that differs from every commit
# and the close LANDS. Both bits are local, silent, and cost one command to set. So for any
# Delivers path that HEAD carries, the verdict rests on a CONTENT comparison the index cannot
# silence: `git hash-object` of the working-tree file against `git rev-parse HEAD:<path>` — a
# difference refuses regardless of what status says. A path HEAD does not carry (untracked,
# gitignored, or a repo whose HEAD does not resolve) falls back to the status leg below, which
# is the shape that decides it. Running BOTH for a tracked path is deliberate: the content
# comparison sees through the index flags, and the status leg still catches a staged-only
# difference; neither weakens the ignored-path carve-out.
#
# The path extraction is touchers.sh's own shape (skills/_tools/touchers.sh): parens and
# square brackets are admitted, so a Next.js route-group path like `app/(auth)/page.tsx`
# survives intact, and the `touchers:` line is dropped — its globs and reason name paths
# that are not deliveries.
# ---------------------------------------------------------------------------------------
delivers_paths() { # <body-file> — path-shaped tokens under ## Delivers, touchers: lines excluded
  awk '/^## Delivers/{on=1; next} /^## /{on=0} on' "$1" \
    | grep -v '^[[:space:]]*touchers:' \
    | grep -oE '(\./)?[][A-Za-z0-9_@.()-]+(/[][A-Za-z0-9_@.()-]+)+\.[A-Za-z0-9]{1,6}' | sort -u
}

if [ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" = "true" ]; then
  UNCOMMITTED=""
  while IFS= read -r dp; do
    [ -n "$dp" ] || continue
    dp="${dp#./}"
    [ -e "$dp" ] || continue
    # 1. CONTENT vs HEAD (ac-jdkb). Index flags cannot silence this: it reads the working-tree
    #    bytes and the committed blob, never the index's opinion of them. Only a path HEAD
    #    carries has a blob to compare against; a symlink's blob is its target string, which
    #    `git hash-object <path>` would dereference, so it is hashed from readlink instead.
    head_blob=$(git rev-parse --verify --quiet "HEAD:$dp" 2>/dev/null)
    if [ -n "$head_blob" ]; then
      if [ -L "$dp" ]; then
        wt_blob=$(printf '%s' "$(readlink "$dp")" | git hash-object --stdin 2>/dev/null)
      else
        wt_blob=$(GIT_LITERAL_PATHSPECS=1 git hash-object --path="$dp" -- "$dp" 2>/dev/null)
      fi
      if [ -n "$wt_blob" ] && [ "$wt_blob" != "$head_blob" ]; then
        UNCOMMITTED="$UNCOMMITTED $dp"
        continue
      fi
    fi
    # 2. STATUS (ac-fy8s). Decides paths HEAD does not carry — untracked, gitignored, or a
    #    repo with no HEAD — and still catches a staged-only difference on a tracked path.
    #    --untracked-files=all is a command-line mode: it overrides `status.showUntrackedFiles`,
    #    so a repo or global config set to `no` cannot silence this leg's evidence.
    if [ -n "$(GIT_LITERAL_PATHSPECS=1 git status --porcelain --untracked-files=all -- "$dp" 2>/dev/null)" ]; then
      UNCOMMITTED="$UNCOMMITTED $dp"
    fi
  done <<EOF
$(delivers_paths "$BODY")
EOF
  if [ -n "$UNCOMMITTED" ]; then
    echo "CLOSE-REFUSED: UNCOMMITTED — Delivers path(s) carry uncommitted changes:$UNCOMMITTED — the probes run in the working tree, so a green here can be a green no commit carries; commit them and re-run"
    exit 1
  fi
  echo "close-gate[$BEAD] UNCOMMITTED ok — every existing Delivers path is committed-clean or ignored"
else
  echo "close-gate[$BEAD] UNCOMMITTED skipped — not inside a git work tree (this gate reports the skip; it never implies clean)"
fi

# ---------------------------------------------------------------------------------------
# LEG 4 — GREEN, and LEG 5 — COVERAGE. Running the probes is not enough: a run that was
# killed early reads exactly like a run that passed, so files-run must equal files-expected
# and the fingerprinted test must have produced NON-EMPTY assertion results.
# ---------------------------------------------------------------------------------------
PROBE_RUN=0
PROBE_GREEN=0
PROBE_RESULTS=()
ASSERT_OUT=$(mktemp "${TMPDIR:-/tmp}/ac-close-out.XXXXXX") || not_checked "SETUP" "cannot create a scratch file"
trap 'rm -f "$BODY" "$ASSERT_OUT"' EXIT

# The assertion-bearing probe is the one that RUNS A HARNESS, which is not always the probe
# that happened to be RED first: `test -x <script>` is a legitimate RED and emits no
# assertions by construction. Two filters, both required: the probe must NAME a test-shaped
# file that exists, AND its stdout must be able to carry assertion lines (a -q/--quiet test or
# a >/dev/null redirect asserts nothing into any stream we can read — measured as instances
# 4 and 5 of ac-close-gate-coverage-silent-probe-ja8l, plus bd-9y8ii / bd-fswt7.3 for
# `git diff --quiet`). When every probe is output-silent
# (or none names a harness), the temporal exit-code pair recorded in the receipt is the
# assertion, and that pair is checked below instead.
ASSERT_PROBE=""
while IFS= read -r pr; do
  [ -n "$pr" ] || continue
  is_output_silent "$pr" && continue
  for tok in $(printf '%s' "$pr" | grep -oE '[A-Za-z0-9_.][A-Za-z0-9_./-]*\.[A-Za-z0-9]+' || true); do
    if is_test_shaped "$tok" && [ -f "$tok" ]; then ASSERT_PROBE="$pr"; break 2; fi
  done
done <<EOF
$PROBES
EOF

while IFS= read -r pr; do
  [ -n "$pr" ] || continue
  lead=$(printf '%s' "$pr" | awk '{print $1}')
  case "$lead" in ''|'#'|*=*) ;; *)
    command -v "$lead" >/dev/null 2>&1 \
      || not_checked "COVERAGE" "probe '$pr' leads with '$lead', which does not resolve — that probe could not run, so files-run < files-expected"
  ;; esac
  if [ -n "$ASSERT_PROBE" ] && [ "$pr" = "$ASSERT_PROBE" ]; then
    sh -c "$pr" >"$ASSERT_OUT" 2>&1 </dev/null
  else
    sh -c "$pr" >/dev/null 2>&1 </dev/null
  fi
  rc=$?
  PROBE_RUN=$(( PROBE_RUN + 1 ))
  PROBE_RESULTS+=("$pr => exit $rc")
  [ "$rc" -eq 0 ] && PROBE_GREEN=$(( PROBE_GREEN + 1 ))
  if [ "$rc" -ne 0 ]; then
    if [ "$DISPOSITION" = 0 ]; then
      if [ "$FRESH_VERIFY" = 1 ]; then
        refuse "GREEN" "fresh-verify: probe '$pr' exits $rc at HEAD — a fresh-verified close demands EVERY AC probe green; one red probe is a refusal"
      fi
      if [ "$pr" = "$RED_PROBE" ]; then
        refuse "GREEN" "the RED probe still exits $rc — it never reported GREEN, so the diff caused nothing"
      fi
    fi
    # DISPOSITION=1 with a red probe is NOT refused here — the cascade leg decides after
    # the loop (condition e); refusing inline would deny the only honest close a
    # premise-gone bead can carry.
  fi
done <<EOF
$PROBES
EOF

# THE DISPOSITION RESOLUTION (condition e): a disposition close is decided here by
# whichever leg actually holds — the work exists AND no Consumes blocker is open (green),
# or the premise is gone by the plan's own closure (every blocker closed with a disposition
# close). Neither leg holds → refuse: the claim of settledness was wrong or unprovable.
DISPOSITION_LEG=""
if [ "$DISPOSITION" = 1 ]; then
  cascade_holds
  if [ "$PROBE_GREEN" -eq "$PROBE_EXPECTED" ] && [ "$CONSUMES_CLOSED" = 1 ]; then
    DISPOSITION_LEG="green"
  elif [ "$PROBE_GREEN" -ne "$PROBE_EXPECTED" ] && [ "$CONSUMES_DISPO" = 1 ]; then
    DISPOSITION_LEG="cascade"
    echo "close-gate[$BEAD] disposition cascade — rescued by closed blocker(s):$CASCADE_DETAIL (a disposition close never claims a causal flip)"
  else
    refuse "GREEN" "disposition close: $(( PROBE_EXPECTED - PROBE_GREEN )) of $PROBE_EXPECTED probe(s) red at HEAD and the Consumes premise does not support the close (a blocker is open, unresolved, or carries no disposition close) — the close claims the state this bead aimed at is settled, and neither leg of that claim holds"
  fi
fi

[ "$PROBE_RUN" -eq "$PROBE_EXPECTED" ] \
  || not_checked "COVERAGE" "files-run ($PROBE_RUN) != files-expected ($PROBE_EXPECTED) — a partial run is not a pass"
if [ "$DISPOSITION" = 0 ]; then
  [ "$PROBE_GREEN" -eq "$PROBE_EXPECTED" ] \
    || refuse "GREEN" "$(( PROBE_EXPECTED - PROBE_GREEN )) of $PROBE_EXPECTED probe(s) are not green"
fi
if [ "$DISPOSITION_LEG" = "cascade" ]; then
  echo "close-gate[$BEAD] GREEN ok — $PROBE_GREEN/$PROBE_EXPECTED probe(s) green, the rest settled by the cascade leg"
else
  echo "close-gate[$BEAD] GREEN ok — $PROBE_GREEN/$PROBE_EXPECTED probe(s) green, files-run == files-expected"
fi

# Assertion results — the anti-bail leg. In vitest's JSON report the field is literally
# `assertionResults` under `.testResults[]`; for a shell harness the analogue is its own
# ok/FAIL assertion lines. Either way an EMPTY result set is a bail-killed run wearing a
# green exit code, and this refuses it.
ASSERTIONS=0
ASSERT_SOURCE=""
if [ -n "$VITEST_JSON" ]; then
  [ -r "$VITEST_JSON" ] || not_checked "COVERAGE" "--vitest-json '$VITEST_JSON' is unreadable"
  command -v jq >/dev/null 2>&1 || not_checked "COVERAGE" "jq unavailable — assertionResults cannot be counted"
  ASSERTIONS=$(jq '[.testResults[]?.assertionResults[]?] | length' "$VITEST_JSON" 2>/dev/null || echo 0)
  ASSERT_SOURCE="assertionResults in $VITEST_JSON"
elif [ -n "$ASSERT_PROBE" ]; then
  # Assertion line formats live harnesses in this registry actually emit: TAP `ok N …`,
  # `FAIL …`, vitest-style `✓/✗`, and the `  PASS: <label>` label-colon form
  # (ac-close-gate-coverage-silent-probe-ja8l instance 5 — consensus.test.sh's PASS lines
  # missed the old space-or-EOL follower). The token must still be FOLLOWED by something —
  # a bare "PASS" inside prose is not an assertion line.
  ASSERTIONS=$(grep -cE '^[[:space:]]*(ok|not ok|FAIL|PASS|✓|✗)([[:space:]:]|$)' "$ASSERT_OUT" 2>/dev/null || true)
  if [ "${ASSERTIONS:-0}" -eq 0 ]; then
    # A summary line is a fallback, never the primary: it counts what the runner chose to
    # report, and this leg exists precisely because that number can be produced by a run
    # that asserted nothing.
    ASSERTIONS=$(grep -oE '[0-9]+ (passed|assertions?)' "$ASSERT_OUT" 2>/dev/null | head -1 | awk '{print $1}')
  fi
  ASSERT_SOURCE="assertion lines from the harness probe"
else
  # No harness in this bead — a prose or config bead. The assertion is the TEMPORAL PAIR
  # itself: the exit code the receipt recorded as RED, against the exit code measured GREEN
  # a moment ago. It is only an assertion because the receipt actually carries the before
  # value, so a receipt without red-exit gets no credit here.
  RED_EXIT=$(rfield 'red-exit')
  if [ "$DISPOSITION_LEG" = "cascade" ]; then
    ASSERTIONS=1; ASSERT_SOURCE="the cascade check (blocker(s)$CASCADE_DETAIL closed with disposition closes on the board — a disposition close never claims a causal flip)"
  elif [ "$FRESH_VERIFY" = 1 ]; then
    # No claim-time receipt under the carve-out: the fresh verification IS the assertion —
    # LEG 4 measured every AC probe green at HEAD, and LEG 8 records it per-probe.
    ASSERTIONS=1; ASSERT_SOURCE="the fresh-verification itself (all $PROBE_GREEN probe(s) green at HEAD, per-probe results recorded on the bead at landing)"
  elif [ "$RED_EXIT" = '' ] || [ "$RED_EXIT" = 0 ]; then
    not_checked "COVERAGE" "this bead runs no harness and its receipt records no non-zero red-exit, so there is no recorded before-state to compare the GREEN against — the assertion set is empty"
  else
    ASSERTIONS=1; ASSERT_SOURCE="the temporal exit-code pair (RED $RED_EXIT -> GREEN 0) recorded in the receipt"
  fi
fi
[ -n "${ASSERTIONS:-}" ] || ASSERTIONS=0
if [ "$ASSERTIONS" -eq 0 ]; then
  not_checked "COVERAGE" "the assertion-bearing probe produced ZERO assertion results (no assertionResults, no ok/FAIL lines) — a run that asserted nothing reads identical to one that passed"
fi
echo "close-gate[$BEAD] COVERAGE ok — $ASSERTIONS assertion result(s) from $ASSERT_SOURCE"

# ---------------------------------------------------------------------------------------
# LEG 7 — EVIDENCE. Delegated to ac-on0y.2's close-evidence-check.sh, the registry's evidence
# core, rather than growing a private second one that would drift from it.
# ---------------------------------------------------------------------------------------
if [ -x "$EVIDENCE_CORE" ]; then
  EV_OUT=$(AC2_BR_CMD="$BR" bash "$EVIDENCE_CORE" "$BEAD" "$REASON" 2>&1); EV_RC=$?
  printf '%s\n' "$EV_OUT" | sed 's/^/  /'
  case "$EV_RC" in
    0) echo "close-gate[$BEAD] EVIDENCE ok" ;;
    1) refuse "EVIDENCE" "close-evidence-check refused: the reason carries no evidence of the shape this type declares" ;;
    *) not_checked "EVIDENCE" "close-evidence-check could not verify (exit $EV_RC)" ;;
  esac
else
  not_checked "EVIDENCE" "close-evidence-check.sh missing at ${EVIDENCE_CORE#$ROOT/} — the evidence core is the one thing this gate does not reimplement"
fi

# ---------------------------------------------------------------------------------------
# LEG 8 — OWNERSHIP, THE WRITE, AND LANDING. A claim does not hold for the duration: it can
# expire, a sibling can take the bead, a human can reassign it. So ownership is re-asserted
# IMMEDIATELY BEFORE the write — and the close is read back, because a close has failed
# silently before and an unverified write is a claim, not a fact.
# ---------------------------------------------------------------------------------------
if [ "$DRY" = 1 ]; then
  echo "close-gate[$BEAD] DRY-RUN — every leg held; would re-assert in_progress ownership, then:"
  echo "close-gate[$BEAD]   $BR close $BEAD --reason \"$REASON\" --transition-comment \"<landing record>\""
  echo "close-gate[$BEAD]   then read back status == closed"
  exit 0
fi

command -v "$BR" >/dev/null 2>&1 || not_checked "OWNERSHIP" "br unavailable — ownership cannot be re-asserted and the close cannot be verified"

PRE_STATUS=$(br_field "$BEAD" status)
PRE_ASSIGNEE=$(br_field "$BEAD" assignee)
[ "$PRE_STATUS" = "in_progress" ] \
  || refuse "OWNERSHIP" "the bead is '$PRE_STATUS', not in_progress, at the moment of the write — the claim did not hold for the duration"
if [ -n "$ACTOR" ] && [ "$PRE_ASSIGNEE" != "$ACTOR" ]; then
  refuse "OWNERSHIP" "the bead is assigned to '$PRE_ASSIGNEE', not '$ACTOR' — someone else owns this close"
fi

# THE LANDING RECORD: every accepted close leaves exactly one comment naming the evidence
# it ran from — the record is the difference between a verified close and a wave-through,
# and a comment nobody wrote proves nothing to the next reader. Computed BEFORE the write so
# it can travel through `br close --transition-comment` (br 0.5.12), which commits the
# comment ATOMICALLY with the close — no separate post-close write, so no RECORD-FAILED can
# follow a close that already landed.
LND_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)
LND_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
# Every branch below names its evidence in a shape check 35 rule 6 (ac-4y7l.31) can
# cross-reference on the SAME row: `GATE: receipt` cites the flight receipt's own `at:`
# stamp (`receipt-at:`); `GATE: decided` cites the ruling comment's id (`ruling-comment:
# #<id>`, set above by find_authorized_ruling); the cascade and fresh-verify branches
# self-cite the tree they verified (`tree: <sha>`) — there is no separate receipt to point
# at in either case.
if [ "$DISPOSITION_LEG" = "cascade" ]; then
  LND_LABEL="TRIAGE-CLOSE"
  LND_TEXT="TRIAGE-CLOSE: $BEAD — ${REASON%%:*} close accepted on the cascade leg — consumed blocker(s)$CASCADE_DETAIL verified closed-with-disposition on the board at (tree: $LND_SHA) by ${ACTOR:-<unattributed>} at $LND_TS; AC probes NOT all green, and a disposition close never claims a causal flip."
elif [ "$FRESH_VERIFY" = 1 ]; then
  PER_PROBE=""
  for r in "${PROBE_RESULTS[@]:-}"; do
    [ -n "$r" ] && PER_PROBE="$PER_PROBE [$r]"
  done
  LND_LABEL="fresh-verify"
  LND_TEXT="FRESH-VERIFY: $BEAD — ${REASON%%:*} close with no usable claim-time receipt; all $PROBE_GREEN AC probe(s) verified green at (tree: $LND_SHA) by ${ACTOR:-<unattributed>} at $LND_TS — per-probe:$PER_PROBE"
else
  # The ordinary receipt-backed close (DISPOSITION=0) and a disposition close resolved on
  # its `green` leg with a usable receipt both write the same record — one text, covering
  # both.
  LND_LABEL="GATE: receipt"
  LND_TEXT="GATE: receipt — $BEAD — RED probe: $RED_PROBE; receipt-at: ${RED_AT:-none}; reason: $REASON; verified at $LND_SHA by ${ACTOR:-<unattributed>} at $LND_TS"
fi

"$BR" close "$BEAD" --reason "$REASON" --transition-comment "$LND_TEXT" </dev/null >/dev/null 2>&1 || true

POST_STATUS=$(br_field "$BEAD" status)
[ "$POST_STATUS" = "closed" ] \
  || refuse "LANDING" "the close did not land — $BEAD reads '$POST_STATUS' after the write"
echo "close-gate[$BEAD] $LND_LABEL RECORDED on the bead"

if [ "$DISPOSITION" = 1 ]; then
  echo "close-gate[$BEAD] CLOSED — disposition ($DISPOSITION_LEG): the state this bead aimed at is settled at HEAD; no causal flip is claimed."
else
  echo "close-gate[$BEAD] CLOSED — RED before the diff, test unchanged, GREEN after: the diff caused the flip."
fi
exit 0
