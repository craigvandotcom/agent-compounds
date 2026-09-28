#!/usr/bin/env bash
# stamp-refined.sh — the only sanctioned way to write the `refined` label.
#
# `refined` is the label the worker loop (`ac-implement`) selects on. Writing it with a bare
# `br label add <id> refined` skips the implementation contract. This wrapper cannot be
# skimmed past: the label write lives INSIDE the function and the function shells out to
# element4-check.sh first, unconditionally. Bypassing it takes deleting code.
#
# Source it to get the function, or run it to stamp ids directly:
#   source <path>/stamp-refined.sh ; stamp_refined <bead-id> [<refine-path-label>]
#   bash    <path>/stamp-refined.sh <bead-id> [<bead-id>...]     # REFINE_PATH from env
#   zsh     <path>/stamp-refined.sh <bead-id> [<bead-id>...]
#
# Both forms work under bash and zsh, sourced or executed, from any cwd.
#
# Per-bead exit: 0 stamped · 1 refused (a content gate is unmet — nothing written) ·
# 2 check unusable.
# A refusal is not an error to route around: author the `## Declared RED` and the probes,
# then re-stamp.

# Self-location. zsh does not populate BASH_SOURCE; bash does not set $0 to the file
# when sourced. Read each shell's own answer in its own branch.
# Never put a zsh-only expansion where bash must parse it. Never use `eval` to hide one:
# eval rewrites zsh's %N and zsh_eval_context to `(eval)`.
if [ -n "${ZSH_VERSION:-}" ]; then
  _STAMP_REFINED_SELF="$0"
else
  _STAMP_REFINED_SELF="${BASH_SOURCE[0]}"
fi
# A failed cd leaves the dir empty, ELEMENT4_CHECK misses, and the FATAL guard below
# refuses. Fail-closed by construction.
_STAMP_REFINED_DIR="$(cd "$(dirname "$_STAMP_REFINED_SELF")" && pwd)"
ELEMENT4_CHECK="${ELEMENT4_CHECK:-$_STAMP_REFINED_DIR/element4-check.sh}"
TOUCHERS_TOOL="${TOUCHERS_TOOL:-$_STAMP_REFINED_DIR/touchers.sh}"
PROD_WRITE_TRIPWIRE_TOOL="${PROD_WRITE_TRIPWIRE_TOOL:-$_STAMP_REFINED_DIR/prod-write-tripwire.sh}"
# The one bead reader (ac-m9y4): this script no longer derives a DECISION blocks-edge count
# or a Delivers path list by its own hand — both now run through bead.py's own functions,
# called in-process via python3, the single home the rest of the registry already reads through.
BEAD_PY_TOOL="${BEAD_PY_TOOL:-$_STAMP_REFINED_DIR/bead.py}"
# A SEPARATE override from BEAD_PY_TOOL above: that path is also read IN-PROCESS for
# `_decision_blocks_count`/`extract_paths` further down, and a test stubbing the CHECK gate
# alone (below) must not also swap out those two, unrelated, in-process reads. Defaults to
# the same file — one home in production; only a test ever tells them apart.
BEAD_PY_CHECK_TOOL="${BEAD_PY_CHECK_TOOL:-$BEAD_PY_TOOL}"
# Bounds the OUTER `timeout` wrapping `bead.py check` below (bead.py's own per-probe
# run_probe is separately bounded; this is the whole-check ceiling). A test shortens it to
# exercise the NOT-GATED-on-timeout path without an actual 600s wait.
BEAD_PY_CHECK_TIMEOUT="${BEAD_PY_CHECK_TIMEOUT:-600}"

# The "does a probe run something" predicate now lives ONLY in bead.py's own
# `probe_runs_something` (moved 2026-09-28 — see the PROBE-PRESENCE LEG, part 2 comment
# below): the ONE-BEAD CHECK GATE's `bead.py check` call carries it, so this script no
# longer needs its own copy.

stamp_refined() {
  local id="$1" path_label="${2:-${REFINE_PATH:-refine-full}}"
  [ -n "$id" ] || { echo "stamp_refined: no bead id given" >&2; return 2; }

  if [ ! -x "$ELEMENT4_CHECK" ] && [ ! -f "$ELEMENT4_CHECK" ]; then
    echo "stamp_refined: FATAL — element4-check.sh not found at '$ELEMENT4_CHECK'; refusing to stamp $id" >&2
    return 2
  fi
  if [ ! -f "$BEAD_PY_TOOL" ]; then
    echo "stamp_refined: FATAL — bead.py not found at '$BEAD_PY_TOOL'; refusing to stamp $id" >&2
    return 2
  fi

  # DOWNGRADE LEG (2026-08-31): a refusal used to only decline to ADD the label, so a stale
  # `refined` stamp written under an older, looser contract survived every later pass —
  # measured in the 2026-08-31 ac-implement run, where pre-floor stamps carried zero probes
  # into the worker pool and each one burned claim cycles at flight-check. "Restamped on
  # sight, never grandfathered" is bidirectional: on a CONTENT refusal, if the bead
  # currently holds `refined`, strip it. Only a content verdict downgrades — a cannot-check
  # result (element4 rc 2, unreadable bead) mutates nothing.
  # SHAPE NORMALISER (2026-09-06). The br show read answers with a one-element ARRAY
  # normally, but under concurrent readers it sometimes answers with the bare OBJECT.
  # Every filter below is `.[0]`, which dies "Cannot index object with number" on that
  # shape — and a dead filter reads as "no labels, no description", so the bead is refused
  # for a defect the READER invented. Normalise at the single point each read enters.
  # The read runs through the ONE br-call helper (ac-heyt.3): a refusal mutates nothing
  # below — the cannot-check contract the downgrade leg already observes.
  # shellcheck source=br-call.sh
  . "$_STAMP_REFINED_DIR/br-call.sh" 2>/dev/null \
    || { echo "stamp_refined: FATAL — br-call.sh helper missing; refusing to read $id" >&2; return 2; }
  _show_json() {
    br_call show --json "$1" | jq 'if type=="array" then . else [.] end' 2>/dev/null
  }

  _downgrade() {
    local id="$1" why="$2" held labels_now
    # The HELD read is a cannot-check, never "no stale stamp held": a dead `br` or
    # `jq` must not read as "nothing to strip" (D1).
    held=$(_show_json "$id" | jq -r '[ .[0].labels // [] | .[] | select(. == "refined") ] | length' 2>/dev/null)
    if [ -z "$held" ]; then
      echo "stamp_refined: WRITE-FAILED $id — cannot re-read the board before the downgrade" >&2
      return 2
    fi
    [ "${held:-0}" -gt 0 ] || return 0
    br label remove "$id" "refined" 2>/dev/null || true
    br label add "$id" "unrefined" 2>/dev/null || true
    # READ-BACK, not a trusted exit: the downgrade meant to produce refined-absent
    # and unrefined-present. A dead re-read is a cannot-check; a board that did not
    # accept the writes is a mismatch — both are the single WRITE-FAILED line.
    raw_now=$(_show_json "$id")
    if [ -z "$raw_now" ]; then
      echo "stamp_refined: WRITE-FAILED $id — cannot re-read the board after the downgrade" >&2
      return 2
    fi
    labels_now=$(printf '%s' "$raw_now" | jq -r '.[0].labels // [] | join(",")' 2>/dev/null)
    if printf '%s' "$labels_now" | tr ',' '\n' | grep -qx 'refined' \
       || ! printf '%s' "$labels_now" | tr ',' '\n' | grep -qx 'unrefined'; then
      echo "stamp_refined: WRITE-FAILED $id — the board holds: [$labels_now]" >&2
      return 2
    fi
    echo "stamp_refined: DOWNGRADED $id — stripped a stale 'refined' stamp ($why); it returns to the refine lane." >&2
    return 0
  }

  # ORIGIN-LABEL GATE — runs before every other leg. Every leg below trusts the origin axis
  # to scope itself (family-fixpoint, touchers, probe-presence); a bead that shipped with
  # none must not reach any of them on the strength of everything else looking fine.
  # Contract: beads-standards/reference/bead-schema.md § Required axes.
  local origin_meta origin_hits
  origin_meta=$(_show_json "$id" || true)
  if [ -z "$origin_meta" ]; then
    echo "stamp_refined: REFUSED $id — could not re-read the bead to check its origin label; refusing rather than guessing. No label written." >&2
    return 2
  fi
  origin_hits=$(printf '%s' "$origin_meta" \
    | jq -r '[ .[0].labels // [] | .[] | select(test("^origin:[A-Za-z0-9][A-Za-z0-9._-]*$")) ] | length' 2>/dev/null)
  if [ -z "$origin_hits" ]; then
    echo "stamp_refined: REFUSED $id — could not read labels to check its origin label; refusing rather than guessing. No label written." >&2
    return 2
  fi
  if [ "$origin_hits" -eq 0 ]; then
    echo "stamp_refined: REFUSED $id — no origin:<skill> label (bead-schema.md § Required axes). No label written. Repair: br update $id --add-label origin:<skill> (origin:unknown when unattributable)." >&2
    _downgrade "$id" "no origin: label" || return $?
    return 1
  fi

  # HUMAN-GATE LEG (the operator's ruling): `refined` is what the worker loop selects on, and a
  # human-gate bead is a decision/action for a HUMAN, never a worker claim — the two labels
  # never coexist. Prospective, not a co-presence check: this runs BEFORE the label is
  # written, so a human-gate bead is refused the FIRST time it is stamped, not only caught
  # once it already (wrongly) carries both.
  local human_gate_hits
  human_gate_hits=$(printf '%s' "$origin_meta" \
    | jq -r '[ .[0].labels // [] | .[] | select(. == "human-gate") ] | length' 2>/dev/null)
  if [ -z "$human_gate_hits" ]; then
    echo "stamp_refined: REFUSED $id — could not read labels to check for human-gate; refusing rather than guessing. No label written." >&2
    return 2
  fi
  if [ "$human_gate_hits" -gt 0 ]; then
    echo "stamp_refined: REFUSED $id — human-gate: co-present with a stamp attempt; a human-gate bead is a decision/action for a human and never carries refined. No label written." >&2
    _downgrade "$id" "human-gate co-present" || return $?
    return 1
  fi

  # RULING-STALENESS LEG (ac-2h8w). Measured in a consuming app (bd-i01pk): a human ruling
  # recorded as a `DECISION (<human>): …` comment changed a bead's scope, but the bead kept
  # `refined` from a polish receipt written the day before — no eligibility filter reads
  # comments, so a worker built the rejected option and it shipped. "Newer" is comment ARRAY
  # ORDER, the same axis the family-fixpoint leg below already trusts (it picks the receipt
  # via `tail -1`, not a timestamp field): `br show --json` returns comments in the order
  # they were written. Blind to content — this leg never judges whether a ruling changed
  # scope, only whether one exists after the last receipt. Reuses origin_meta: no bead has
  # mutated between the read above and here.
  local ruling_idx receipt_idx
  ruling_idx=$(printf '%s' "$origin_meta" | jq -r '
    [ .[0].comments // [] | to_entries[]
      | select(.value.text != null and (.value.text | test("^DECISION \\([^)]+\\):")))
      | .key ] | if length > 0 then max else -1 end' 2>/dev/null)
  if [ -z "$ruling_idx" ]; then
    echo "stamp_refined: REFUSED $id — could not read comments to check for a ruling; refusing rather than guessing. No label written." >&2
    return 2
  fi
  if [ "$ruling_idx" -ge 0 ]; then
    receipt_idx=$(printf '%s' "$origin_meta" | jq -r '
      [ .[0].comments // [] | to_entries[]
        | select(.value.text != null and (.value.text | test("^POLISH-FIXPOINT:")))
        | .key ] | if length > 0 then max else -1 end' 2>/dev/null)
    if [ -z "$receipt_idx" ]; then
      echo "stamp_refined: REFUSED $id — could not read comments to check for a receipt; refusing rather than guessing. No label written." >&2
      return 2
    fi
    if [ "$receipt_idx" -lt "$ruling_idx" ]; then
      echo "stamp_refined: REFUSED $id — STALE-RULING: a DECISION ruling is newer than the bead's last polish receipt (or no receipt exists at all); the ruled text has not been re-graded. Re-polish the bead against the ruling, then re-stamp. No label written." >&2
      _downgrade "$id" "DECISION ruling newer than the last fixpoint receipt" || return $?
      return 1
    fi
  fi

  local out rc
  out=$(bash "$ELEMENT4_CHECK" "$id" 2>&1); rc=$?
  if [ "$rc" -ne 0 ]; then
    printf '%s\n' "$out" >&2
    echo "stamp_refined: REFUSED $id — element 4 unmet; no label written." >&2
    if [ "$rc" -eq 1 ]; then _downgrade "$id" "element 4 unmet" || return $?; fi
    return "$rc"
  fi

  # EVERY ORIGIN OWES A FIXPOINT RECEIPT (2026-09-27, ac-m9y4.7 — the old six-label family
  # scoping is gone). The producer is skills/_tools/polish-fixpoint.sh, which writes
  #   POLISH-FIXPOINT: mode=<m> rounds=<n> sha256=<digest> at=<ts> engine=polish-fixpoint.sh
  # as a bead comment at fixpoint. The gate lives HERE because this is the sole sanctioned
  # writer of `refined` — in ac-polish's procedure it would be a check every other caller
  # could route around.
  local meta receipt rounds
  meta=$(_show_json "$id" || true)
  if [ -z "$meta" ]; then
    echo "stamp_refined: REFUSED $id — could not re-read the bead to check its origin; refusing rather than guessing. No label written." >&2
    return 2
  fi

  # PROBE-PRESENCE LEG, part 1 (2026-08-29): `refined` must certify something a worker
  # can execute. Zero `Probe:` lines is still a refusal — measured 2026-08-29, when 18 of
  # 22 refined beads carried none and every lean claim died NOT-GATED.
  local probes
  probes=$(printf '%s' "$meta" | jq -r '.[0].description // ""' | grep -c 'Probe:')
  if [ "${probes:-0}" -eq 0 ]; then
    echo "stamp_refined: REFUSED $id — description carries no executable 'Probe:' line; a refined bead must be probe-bearing (beads-standards: refined). Author the probes, then re-stamp. No label written." >&2
    _downgrade "$id" "no executable Probe: line" || return $?
    return 1
  fi

  # PROBE-PRESENCE LEG, part 2 (runs-something 2026-09-22) — the VERDICT now calls
  # bead.py's own `probe_presence_code_violation` (moved 2026-09-28, checker recheck,
  # evidence org-uv40/org-gv6: VALIDATE ran `bead.py check` alone, which carried no
  # PROBE-PRESENCE leg at all, and passed a bead this script's own inline copy of the SAME
  # rule then refused — the same precedent as the TASK/FEATURE DELIVERS LEG's 2026-09-27
  # move above). ONE home for the rule now, read by this leg, the ONE-BEAD CHECK GATE's
  # own `bead.py check <id>` below, AND `stamp-refined.sh --check`'s thin wrapper — never a
  # second derivation to drift from the other two. This leg stays at its ORIGINAL position
  # (before the fixpoint-receipt gate) so a probe-presence refusal is still the FIRST
  # reason a content-vacuous bead is refused, never masked by a later leg's own message.
  local _ppv_desc _ppv_out _ppv_rc
  _ppv_desc=$(mktemp "${TMPDIR:-/tmp}/stamp-refined-ppv.XXXXXX") || {
    echo "stamp_refined: REFUSED $id — could not write a temp description for the probe-presence leg; refusing rather than guessing. No label written." >&2
    return 2
  }
  printf '%s' "$(printf '%s' "$meta" | jq -r '.[0].description // ""')" >"$_ppv_desc"
  _ppv_out=$(python3 -c '
import os, sys
sys.path.insert(0, os.path.dirname(sys.argv[1]))
import bead
with open(sys.argv[2], "r", encoding="utf-8", errors="replace") as fh:
    desc = fh.read()
v = bead.probe_presence_code_violation(desc)
if v:
    print(v)
' "$BEAD_PY_TOOL" "$_ppv_desc" 2>&1); _ppv_rc=$?
  rm -f "$_ppv_desc"
  if [ "$_ppv_rc" -ne 0 ]; then
    printf '%s\n' "$_ppv_out" >&2
    echo "stamp_refined: REFUSED $id — could not run the probe-presence leg; refusing rather than guessing. No label written." >&2
    return 2
  fi
  if [ -n "$_ppv_out" ]; then
    echo "stamp_refined: REFUSED $id — $_ppv_out. No label written." >&2
    _downgrade "$id" "nothing left to run" || return $?
    return 1
  fi

  # PROBE-SHAPE LEG (bead-schema.md § The probe rule). A probe runs this bead's own test,
  # never the whole suite — that is batch CI's. A probe waiting on a device verdict needs
  # the `device` label, which keeps it out of the worker pool.
  local _allp
  _allp=$(printf '%s\n' "$meta" | jq -r '.[0].description // ""' | grep -o 'Probe: `[^`]*`' || true)
  if printf '%s\n' "$_allp" | grep -qE 'pnpm test(:all)?[[:space:]]*(`|&&|;|\|)'; then
    echo "stamp_refined: REFUSED $id — WHOLE-SUITE probe: a bare 'pnpm test'/'pnpm test:all' runs every test; name this bead's own test file ('pnpm test <file>'). No label written." >&2
    _downgrade "$id" "whole-suite probe" || return $?
    return 1
  fi
  if printf '%s\n' "$_allp" | grep -q 'DEVICE VERDICT' \
     && ! printf '%s' "$meta" | jq -e '.[0].labels // [] | index("device")' >/dev/null 2>&1; then
    echo "stamp_refined: REFUSED $id — DEVICE-UNLABELLED: a probe waits on a DEVICE VERDICT but the bead lacks the 'device' label. Add it: br update $id --add-label device. No label written." >&2
    _downgrade "$id" "device verdict without device label" || return $?
    return 1
  fi
  # ECHO-ONLY LEG: an `echo` cannot fail, so a bead whose every probe is one certifies nothing.
  # One real probe beside an echo still names something that can go RED.
  local _echo_only=1 _bare
  while IFS= read -r _pr; do
    [ -n "$_pr" ] || continue
    _bare=$(printf '%s' "$_pr" | sed 's/^Probe: `//; s/`$//')
    printf '%s' "$_bare" | grep -qE '^[[:space:]]*echo([[:space:]]|$)' || { _echo_only=0; break; }
  done <<EOF
$(printf '%s\n' "$_allp")
EOF
  if [ "$_echo_only" -eq 1 ] && [ -n "$(printf '%s' "$_allp" | tr -d '[:space:]')" ]; then
    echo "stamp_refined: REFUSED $id — ECHO-ONLY: every probe is an echo, which cannot fail; name a command that goes RED when the work is absent. No label written." >&2
    _downgrade "$id" "every probe is echo-only" || return $?
    return 1
  fi

  # PROD-WRITE TRIPWIRE (ac-bhxx). The predicate is judgment; this leg is the mechanical
  # backstop for descriptions that match its signal vocabulary. A signal passes only with
  # the reader's recorded `prod-write: none — <reason>` verdict or the board's existing
  # sensitive-prod + DECISION blocks gate pair. Neither is ever written by this script:
  # a label or edge the gate invents would be its own evidence.
  local desc labels_csv decision_edges pdesc pout prc
  desc=$(printf '%s' "$meta" | jq -r '.[0].description // ""')
  labels_csv=$(printf '%s' "$meta" | jq -r '.[0].labels // [] | join(",")')
  # The DECISION blocks-edge count is bead.py's own `_decision_blocks_count`, never a second
  # edge-type select of this script's own (ac-m9y4.7) — it re-reads the bead itself, the one
  # home. Args, never string-interpolated into the script — untrusted text either way.
  decision_edges=$(python3 -c '
import os, sys
sys.path.insert(0, os.path.dirname(sys.argv[1]))
import bead
n = bead._decision_blocks_count(sys.argv[2])
print(n if n is not None else 0)
' "$BEAD_PY_TOOL" "$id" 2>/dev/null)
  decision_edges=${decision_edges:-0}
  if [ ! -f "$PROD_WRITE_TRIPWIRE_TOOL" ]; then
    echo "stamp_refined: FATAL — prod-write-tripwire.sh not found at '$PROD_WRITE_TRIPWIRE_TOOL'; refusing to stamp $id" >&2
    return 2
  fi
  command -v prod_write_tripwire_check >/dev/null 2>&1 || . "$PROD_WRITE_TRIPWIRE_TOOL"
  pdesc=$(mktemp "${TMPDIR:-/tmp}/stamp-refined-prod-write.XXXXXX") || {
    echo "stamp_refined: REFUSED $id — could not write a temp description for the prod-write leg; refusing rather than guessing. No label written." >&2
    return 2
  }
  printf '%s\n' "$desc" >"$pdesc"
  pout=$(prod_write_tripwire_check "$pdesc" "$labels_csv" "$decision_edges" "$id" 2>&1); prc=$?
  rm -f "$pdesc"
  if [ "$prc" -eq 1 ]; then
    printf '%s\n' "$pout" >&2
    echo "stamp_refined: REFUSED $id — the prod-write tripwire found an unrecorded signal; no label written." >&2
    _downgrade "$id" "prod-write signal has no recorded verdict" || return $?
    return 1
  elif [ "$prc" -ne 0 ]; then
    printf '%s\n' "$pout" >&2
    echo "stamp_refined: REFUSED $id — the prod-write tripwire could not check the description; no label written." >&2
    return 2
  fi

  # TASK/FEATURE DELIVERS LEG — MOVED to bead.py's own `task_feature_delivers_violation`
  # (checker recheck 2026-09-27: VALIDATE ran `bead.py check` alone, which lacked this
  # leg, and passed a bead this script's own now-retired copy of the SAME rule then
  # downgraded — evidence bd-pz8md, bd-1s800). The ONE-BEAD CHECK GATE below already
  # carries it: no caller reads a weaker rule than any other.

  # A header alone declares nothing (the rule element4-check applies to `## Declared RED`):
  # a receipt without a round count and a digest is treated as ABSENT.
  receipt=$(printf '%s' "$meta" \
    | jq -r '[.[0].comments // [] | .[] | .text // ""] | join("\n")' 2>/dev/null \
    | grep -E '^POLISH-FIXPOINT:[[:space:]].*rounds=[0-9]+.*sha256=[0-9a-f]{8,}' | tail -1)
  if [ -z "$receipt" ]; then
    echo "stamp_refined: REFUSED $id — no conforming fixpoint receipt (expected a 'POLISH-FIXPOINT: … rounds=<n> sha256=<digest>' comment from skills/_tools/polish-fixpoint.sh). No label written." >&2
    _downgrade "$id" "no conforming fixpoint receipt" || return $?
    return 1
  fi
  rounds=$(printf '%s' "$receipt" | sed -E 's/.*rounds=([0-9]+).*/\1/')
  if [ "${rounds:-0}" -lt 2 ]; then
    echo "stamp_refined: REFUSED $id — fixpoint receipt records rounds=$rounds; a clean FIRST round proves nothing, so a fixpoint needs a clean round >= 2. No label written." >&2
    _downgrade "$id" "fixpoint receipt below rounds=2" || return $?
    return 1
  fi

  # TOUCHERS LEG (2026-09-03; derivation extracted to skills/_tools/touchers.sh 2026-09-06):
  # a bead that changes a file something else references must NAME those references —
  # command-derived, count reproduced — or say why they are out of scope. Canon:
  # beads-standards/reference/bead-schema.md § Required axes. The trigger is DERIVED,
  # never declared. Why here: bead-polish measured a 16.2% repair rate from hand-listed
  # consumer sets; the slate's caller list was short by two; this very script was once
  # archived with four live callers. A stale count is refused too — the list being stale
  # when used IS the defect.
  #
  # WHY THE LEG MOVED OUT: ac-beadify must WRITE the line the gate refuses beads for, and a
  # second copy of the derivation would drift silently — the writer emitting exactly what
  # the gate rejects. One home, two callers. The verdict still lands here, in the sole
  # sanctioned writer of `refined`, where no caller can route around it.
  local tdesc tout trc
  if [ ! -f "$TOUCHERS_TOOL" ]; then
    echo "stamp_refined: FATAL — touchers.sh not found at '$TOUCHERS_TOOL'; refusing to stamp $id" >&2
    return 2
  fi
  command -v touchers_check >/dev/null 2>&1 || . "$TOUCHERS_TOOL"
  tdesc=$(mktemp "${TMPDIR:-/tmp}/stamp-refined-desc.XXXXXX") || {
    echo "stamp_refined: REFUSED $id — could not write a temp description for the touchers leg; refusing rather than guessing. No label written." >&2
    return 2
  }
  printf '%s\n' "$desc" >"$tdesc"
  tout=$(touchers_check "$tdesc" "$id" 2>&1); trc=$?
  rm -f "$tdesc"
  if [ "$trc" -eq 1 ]; then
    printf '%s\n' "$tout" >&2
    echo "stamp_refined: REFUSED $id — [unowned-touchers] the touchers leg refused (above). Re-derive with 'skills/_tools/touchers.sh derive <path>', then re-stamp. No label written." >&2
    _downgrade "$id" "unowned, malformed or stale touchers" || return $?
    return 1
  elif [ "$trc" -ne 0 ]; then
    printf '%s\n' "$tout" >&2
    echo "stamp_refined: REFUSED $id — touchers could not be derived; refusing rather than guessing. No label written." >&2
    return 2
  fi

  # ONE-BEAD CHECK GATE (ac-m9y4 Vision/D4): "one automatic check that runs whenever a card
  # is polished, marked ready, or picked up" — `refined` must imply a clean `bead.py check`,
  # never a stamp bead.py would itself refuse (measured: ac-tv83.14 held `refined` while
  # `bead.py check ac-tv83.14` refused it). Runs the ID form, never a re-derivation of any
  # rule bead.py already owns — every leg above this one stays exactly as it was; this is an
  # ADDITIONAL, final gate, not a replacement for any of them. `timeout` wraps the WHOLE
  # call: bead.py's own `run_probe` already bounds each individual probe, but a wedged
  # `br show` or a hung `touchers.sh`/`prod-write-tripwire.sh` subprocess inside bead.py's
  # own check must not hang this stamp forever either. REFUSED (rc 1) downgrades an existing
  # stamp, same as every other content leg; NOT-GATED (rc 2) or a timeout (rc 124) mutates
  # NOTHING — a cannot-check result is never read as a pass.
  local bpc_root bpc_out bpc_rc
  # ROOT IS THE CALLER'S REPO, NEVER THIS SCRIPT'S OWN (same fix as close-gate.sh's own
  # "ROOT is the CONSUMER repo's root, never the script's own repo"): this script is
  # symlinked into every consuming app, and `cd`-ing into its OWN location first (via
  # _STAMP_REFINED_DIR, or any other script-relative path) crosses that symlink at the OS
  # level — `git rev-parse` then resolves the REGISTRY's toplevel, not the app's. Measured
  # 2026-09-27: run from a consuming app, every `bead.py check` looked up a bd-* id against
  # the agent-compounds board and `br show` exited 3 — 15 restamps NOT-GATED in one day.
  # `git rev-parse --show-toplevel` alone, with NO prior `cd`, reads the PROCESS's inherited
  # cwd — whatever directory the caller (ac-implement, a human shell) was actually in when
  # it invoked stamp-refined.sh — never this script's own path.
  bpc_root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [ -z "$bpc_root" ]; then
    echo "stamp_refined: REFUSED $id — could not resolve the caller's own repo root (not inside a git repo?) to run bead.py check; refusing rather than guessing. No label written." >&2
    return 2
  fi
  bpc_out=$(cd "$bpc_root" && timeout "$BEAD_PY_CHECK_TIMEOUT" python3 "$BEAD_PY_CHECK_TOOL" check "$id" 2>&1); bpc_rc=$?
  if [ "$bpc_rc" -eq 1 ]; then
    printf '%s\n' "$bpc_out" >&2
    echo "stamp_refined: REFUSED $id — bead.py check refused (above); no label written." >&2
    _downgrade "$id" "bead.py check refused" || return $?
    return 1
  elif [ "$bpc_rc" -ne 0 ]; then
    printf '%s\n' "$bpc_out" >&2
    echo "stamp_refined: REFUSED $id — bead.py check could not be run (exit $bpc_rc: NOT-GATED or timed out); refusing rather than guessing. No label written." >&2
    return 2
  fi

  # THE STAMP IS A READ-BACK, NOT A TRUSTED EXIT (D1). The three writes discard their
  # exits — a rejected write leaves the board unchanged and the read-back catches it —
  # then the board is re-read and the label set the stamp meant to produce is asserted:
  # refined present, unrefined absent, path_label present. A mismatch, or a board that
  # cannot be re-read, exits 2 with a single WRITE-FAILED line. STAMPED prints ONLY on
  # a verified stamp — bead-artifact.py classifies a run by that substring.
  br label remove "$id" "unrefined" 2>/dev/null || true
  br label add "$id" "refined" 2>/dev/null || true
  br label add "$id" "$path_label" 2>/dev/null || true
  # READ-BACK, not a trusted exit: the stamp meant to produce refined-present,
  # unrefined-absent, and path_label-present. A dead re-read is a cannot-check; a
  # board that did not accept the writes is a mismatch — both are WRITE-FAILED.
  raw_now=$(_show_json "$id")
  if [ -z "$raw_now" ]; then
    echo "stamp_refined: WRITE-FAILED $id — cannot re-read the board after the stamp" >&2
    return 2
  fi
  labels_now=$(printf '%s' "$raw_now" | jq -r '.[0].labels // [] | join(",")' 2>/dev/null)
  if ! printf '%s' "$labels_now" | tr ',' '\n' | grep -qx 'refined' \
     || printf '%s' "$labels_now" | tr ',' '\n' | grep -qx 'unrefined' \
     || ! printf '%s' "$labels_now" | tr ',' '\n' | grep -qx "$path_label"; then
    echo "stamp_refined: WRITE-FAILED $id — the board holds: [$labels_now]" >&2
    return 2
  fi
  echo "stamp_refined: STAMPED $id ($path_label)"
}

# stamp_refined_check — the ONE read-only entry point for "would stamp_refined accept this
# content" (ac-<check-gate>). No board writes, no label changes, never resolves a live id.
#
# WHY THIS EXISTS: VALIDATE (ac-polish's bead-mode gate) and the restamp gate used to run
# DIFFERENT rule sets over the SAME content — VALIDATE called `bead.py check <file>` alone,
# which (before the PROBE-PRESENCE move above, and before `--type`/`--labels` threading
# below) skipped several content legs a file target COULD carry, so a bead VALIDATE passed
# the restamp gate then refused. Measured twice: bd-pz8md/bd-1s800 (2026-09-27, the
# TASK/FEATURE DELIVERS LEG's move) and org-uv40/org-gv6 (2026-09-28, the PROBE-PRESENCE
# leg's move, plus three ad hoc scratch scripts a conductor had to hand-write to compensate:
# runs-leg.sh, check_overlay.py, and an inline Delivers/sensitive-prod/prod-write-tripwire
# check — evidence this gate needed one real entry point instead of a growing scratch pile).
#
# EVERY CONTENT LEG THE STAMP RUNS is `bead.py check`'s own job now (element4-check.sh
# runs alongside it, the SAME as the restamp's own first leg) — this function is a THIN
# WRAPPER, never a second copy: `--type`/`--labels` thread through the SAME meta-header
# line `bead-artifact.py export`'s own block header already carries
# (`bead.py`'s `parse_meta_header`), prepended to a scratch copy of the file, never a new
# bead.py flag. Legs that genuinely need a live id (origin-label/human-gate PROSPECTIVE
# checks beyond a bare label read, ruling-staleness, the fixpoint-receipt rounds>=2 gate,
# sensitive-prod's DECISION-blocks count, and prod-write-tripwire's same count) cannot run
# without one and are named on ONE line, never silently — the restamp gate re-checks all of
# them, on the real id, after writeback.
#
# Usage: stamp-refined.sh --check <description-file> [--type <t>] [--labels <csv>]
# Exit 0 clean · 1 a content leg refused (named) · 2 cannot-check (never a pass).
stamp_refined_check() {
  local file="" itype="" labels=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --type)   itype="${2:-}"; shift 2 ;;
      --labels) labels="${2:-}"; shift 2 ;;
      -*)       echo "stamp_refined --check: unknown flag '$1'" >&2; return 2 ;;
      *)        [ -z "$file" ] && file="$1" || { echo "stamp_refined --check: unexpected argument '$1'" >&2; return 2; }; shift ;;
    esac
  done
  [ -n "$file" ] || { echo "stamp_refined --check: usage: stamp-refined.sh --check <description-file> [--type <t>] [--labels <csv>]" >&2; return 2; }
  [ -r "$file" ] || { echo "stamp_refined --check: NOT-GATED — no readable file at '$file'" >&2; return 2; }
  if [ ! -x "$ELEMENT4_CHECK" ] && [ ! -f "$ELEMENT4_CHECK" ]; then
    echo "stamp_refined --check: FATAL — element4-check.sh not found at '$ELEMENT4_CHECK'" >&2; return 2
  fi
  if [ ! -f "$BEAD_PY_CHECK_TOOL" ]; then
    echo "stamp_refined --check: FATAL — bead.py not found at '$BEAD_PY_CHECK_TOOL'" >&2; return 2
  fi

  local rc=0 e4_out e4_rc
  if [ -n "$itype" ]; then
    e4_out=$(bash "$ELEMENT4_CHECK" --file "$file" --type "$itype" 2>&1); e4_rc=$?
  else
    e4_out=$(bash "$ELEMENT4_CHECK" --file "$file" 2>&1); e4_rc=$?
  fi
  printf '%s\n' "$e4_out"
  [ "$e4_rc" -ne 0 ] && rc=1

  # Thread --type/--labels into bead.py check the SAME way a real exported block already
  # does: a leading meta-header line, never a new bead.py CLI flag (least code — one
  # parser, `parse_meta_header`, for both a real export and this scratch prepend). Both
  # fields sit on the SAME line by that parser's own contract, so --labels with no --type
  # cannot form one; a note says so rather than silently dropping --labels.
  local target=""
  if [ -n "$itype" ]; then
    target=$(mktemp "${TMPDIR:-/tmp}/stamp-refined-check.XXXXXX") || {
      echo "stamp_refined --check: NOT-GATED — cannot create a scratch file to thread --type/--labels" >&2
      return 2
    }
    printf 'type: %s · priority: 0 · labels: %s\n' "$itype" "${labels:-none}" >"$target"
    cat "$file" >>"$target"
  else
    target="$file"
    if [ -n "$labels" ]; then
      echo "stamp_refined --check: note — --labels given without --type; bead.py's meta-header needs both on one line, so the label/type-scoped legs are skipped this run (give --type too)" >&2
    fi
  fi

  local bpc_out bpc_rc
  bpc_out=$(python3 "$BEAD_PY_CHECK_TOOL" check "$target" 2>&1); bpc_rc=$?
  [ "$target" != "$file" ] && rm -f "$target"
  printf '%s\n' "$bpc_out"
  case "$bpc_rc" in
    0) ;;
    1) rc=1 ;;
    *) [ "$rc" -eq 0 ] && rc=2 ;;
  esac

  echo "stamp_refined --check: board-only legs skipped (no live id, never resolved): origin-label/human-gate PROSPECTIVE gate, ruling-staleness, fixpoint-receipt (rounds>=2), sensitive-prod (DECISION-blocks count), prod-write-tripwire (same count) — the restamp gate re-checks every one of these, on the real id, after writeback"
  if [ "$rc" -eq 0 ]; then
    echo "stamp_refined --check: OK $file — every content leg the stamp runs is clean"
  fi
  return "$rc"
}

# Executed, or sourced? bash compares BASH_SOURCE[0] to $0. zsh sets $0 to the file in
# BOTH modes, so it cannot discriminate — read zsh_eval_context, whose last frame is
# `toplevel` when executed and `file` when sourced.
# Test this at top level only: inside a function zsh appends `shfunc` and it never matches.
_STAMP_REFINED_DIRECT=0
if [ -n "${ZSH_VERSION:-}" ]; then
  [ "${zsh_eval_context[-1]-}" = toplevel ] && _STAMP_REFINED_DIRECT=1
else
  [ "${BASH_SOURCE[0]-}" = "${0}" ] && _STAMP_REFINED_DIRECT=1
fi

if [ "$_STAMP_REFINED_DIRECT" = 1 ]; then
  if [ "${1:-}" = "--check" ]; then
    shift
    stamp_refined_check "$@"
    exit $?
  fi
  _rc=0
  for _id in "$@"; do
    stamp_refined "$_id"; _r=$?
    # The rc CLASS is preserved, never collapsed: 2 (cannot-check) is the class the
    # claim gate routes NOT-GATED on, and a wrapper that flattens it to 1 misroutes a
    # WRITE-FAILED as a content refusal. First non-zero wins on multi-bead runs.
    [ "$_r" -ne 0 ] && [ "$_rc" -eq 0 ] && _rc="$_r"
  done
  exit "$_rc"
fi
