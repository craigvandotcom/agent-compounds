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
# Per-bead exit: 0 stamped · 1 refused (element 4 unmet, or description carries no executable
# `Probe:` line — nothing written) · 2 check unusable.
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

stamp_refined() {
  local id="$1" path_label="${2:-${REFINE_PATH:-refine-full}}"
  [ -n "$id" ] || { echo "stamp_refined: no bead id given" >&2; return 2; }

  if [ ! -x "$ELEMENT4_CHECK" ] && [ ! -f "$ELEMENT4_CHECK" ]; then
    echo "stamp_refined: FATAL — element4-check.sh not found at '$ELEMENT4_CHECK'; refusing to stamp $id" >&2
    return 2
  fi

  # DOWNGRADE LEG (2026-08-31): a refusal used to only decline to ADD the label, so a stale
  # `refined` stamp written under an older, looser contract survived every later pass —
  # measured in the 2026-08-31 ac-implement run, where pre-floor stamps carried zero probes
  # into the worker pool and each one burned claim cycles at flight-check. "Restamped on
  # sight, never grandfathered" is bidirectional: on a CONTENT refusal, if the bead
  # currently holds `refined`, strip it. Only a content verdict downgrades — a cannot-check
  # result (element4 rc 2, unreadable bead) mutates nothing.
  _downgrade() {
    local id="$1" why="$2" held
    held=$(br show --json "$id" 2>/dev/null | jq -r '[ .[0].labels // [] | .[] | select(. == "refined") ] | length' 2>/dev/null || echo 0)
    [ "${held:-0}" -gt 0 ] || return 0
    br label remove "$id" "refined" 2>/dev/null
    br label add "$id" "unrefined" 2>/dev/null
    echo "stamp_refined: DOWNGRADED $id — stripped a stale 'refined' stamp ($why); it returns to the refine lane." >&2
  }

  local out rc
  out=$(bash "$ELEMENT4_CHECK" "$id" 2>&1); rc=$?
  if [ "$rc" -ne 0 ]; then
    printf '%s\n' "$out" >&2
    echo "stamp_refined: REFUSED $id — element 4 unmet; no label written." >&2
    [ "$rc" -eq 1 ] && _downgrade "$id" "element 4 unmet"
    return "$rc"
  fi

  # FAMILY-ORIGIN BEADS ADDITIONALLY REQUIRE A FIXPOINT RECEIPT (ac-gv70).
  # The producer is skills/_tools/polish-fixpoint.sh, which writes
  #   POLISH-FIXPOINT: mode=<m> rounds=<n> sha256=<digest> at=<ts> engine=polish-fixpoint.sh
  # as a bead comment at fixpoint. The gate lives HERE because this is the sole sanctioned
  # writer of `refined` — in ac-polish's procedure it would be a check every other caller
  # could route around. Selector is the LABEL token — the EXPLICIT six origin labels of the
  # lean pipeline (the renamed origin-label series; see beads-standards' migration note) —
  # never the description's shape: shape cannot tell a lean bead from a legacy one that
  # merely lacks a Declared RED, and mis-scoping would silently refuse live beads. It is
  # also never a `startswith("origin:ac-")`: that would sweep EVERY ac-* origin label
  # (ac-hygiene, ac-triage, the manual ac-review panel's own findings) — over-catching,
  # and refusing beads this gate was never meant to gate.
  local meta family_hits receipt rounds
  meta=$(br show --json "$id" 2>/dev/null || true)
  if [ -z "$meta" ]; then
    echo "stamp_refined: REFUSED $id — could not re-read the bead to check its origin; refusing rather than guessing. No label written." >&2
    return 2
  fi
  family_hits=$(printf '%s' "$meta" | jq -r '
    [ .[0].labels // [] | .[] | select(
        . == "origin:ac-plan" or . == "origin:ac-polish" or . == "origin:ac-beadify" or
        . == "origin:ac-implement" or . == "origin:ac-review" or . == "origin:ac-publish"
      ) ] | length' 2>/dev/null || echo 0)

  # PROBE-PRESENCE LEG (2026-08-29): `refined` must certify something a worker can execute.
  # The worker's flight-check gate executes `Probe:` lines; a description with none
  # makes the stamp a routing hint, not a fact — measured 2026-08-29: 18 of 22
  # `refined` beads in one ready pool
  # carried a Declared RED and zero probes, and every lean claim died NOT-GATED. The floor
  # here is PRESENCE (>= 1 probe); per-AC completeness stays the checklist's judgment
  # (ac-polish references/bead-checklist.md § 2), because counting ACs mechanically would
  # re-implement the checklist badly.
  local probes
  probes=$(printf '%s' "$meta" | jq -r '.[0].description // ""' | grep -c 'Probe:')
  if [ "${probes:-0}" -eq 0 ]; then
    echo "stamp_refined: REFUSED $id — description carries no executable 'Probe:' line; a refined bead must be probe-bearing (beads-standards: refined). Author the probes, then re-stamp. No label written." >&2
    _downgrade "$id" "no executable Probe: line"
    return 1
  fi

  if [ "${family_hits:-0}" -gt 0 ]; then
    # A header alone declares nothing (the rule element4-check applies to `## Declared RED`):
    # a receipt without a round count and a digest is treated as ABSENT.
    receipt=$(printf '%s' "$meta" \
      | jq -r '[.[0].comments // [] | .[] | .text // ""] | join("\n")' 2>/dev/null \
      | grep -E '^POLISH-FIXPOINT:[[:space:]].*rounds=[0-9]+.*sha256=[0-9a-f]{8,}' | tail -1)
    if [ -z "$receipt" ]; then
      echo "stamp_refined: REFUSED $id — family-origin bead with no conforming fixpoint receipt (expected a 'POLISH-FIXPOINT: … rounds=<n> sha256=<digest>' comment from skills/_tools/polish-fixpoint.sh). No label written." >&2
      _downgrade "$id" "no conforming fixpoint receipt"
      return 1
    fi
    rounds=$(printf '%s' "$receipt" | sed -E 's/.*rounds=([0-9]+).*/\1/')
    if [ "${rounds:-0}" -lt 2 ]; then
      echo "stamp_refined: REFUSED $id — fixpoint receipt records rounds=$rounds; a clean FIRST round proves nothing, so a fixpoint needs a clean round >= 2. No label written." >&2
      _downgrade "$id" "fixpoint receipt below rounds=2"
      return 1
    fi
  fi

  br label remove "$id" "unrefined" 2>/dev/null
  br label add "$id" "refined" 2>/dev/null
  br label add "$id" "$path_label" 2>/dev/null
  echo "stamp_refined: STAMPED $id ($path_label)"
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
  _rc=0
  for _id in "$@"; do stamp_refined "$_id" || _rc=1; done
  exit "$_rc"
fi
