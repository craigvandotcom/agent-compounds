#!/usr/bin/env bash
# br-call.sh — the ONE `br … --json` invocation shape (ac-heyt.3). SOURCED, never executed.
#
# With `--json`, a br failure is a VALID JSON error envelope on STDOUT and stderr is EMPTY
# (error_envelope_on_stderr: false) — so a raw `br … --json` read with stderr discarded turns
# a dead read into EMPTY DATA. Measured: `_show_json` on a missing id yields labels null at rc 0.
# `br_call` runs the read and REFUSES on either failure shape — a non-zero exit, or a zero
# exit whose stdout is an object carrying `.error` — returning 2 with the envelope's
# `.error.message` on stderr, so a caller can branch instead of jq-ing nothing. On success it
# prints the payload unchanged and a caller's existing jq pipeline is unaffected.
#
# SOURCING GOTCHA: sets NO shell options at top level (`set -e` / `set -u` / `set -o
# pipefail`) — they would leak into every caller and change their control flow invisibly.
# And it never redirects a br read's stderr to /dev/null — that redirect is the exact habit
# this helper exists to replace; br stderr passes through to the caller untouched.
#
# Usage:   br_call <br-args…>
# Example: data=$(br_call show ac-xyz --json) || return $?
# Canon:   skills/ac-pipeline/SKILL.md (one engine per pattern); proof: br-call.test.sh

br_call() {
  local out rc
  out="$(br "$@")"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    # Non-zero exit: surface the envelope's message when stdout carried one, then the raw
    # payload, both on stderr — never a silent empty data.
    printf '%s' "$out" | jq -r '.error.message // empty' 2>&- | grep -v '^$' | head -1 >&2
    printf '%s' "$out" >&2
    return 2
  fi
  if printf '%s' "$out" | jq -e '.error' >/dev/null 2>&-; then
    # rc 0 but an error envelope on stdout — the shape that made stamp-refined read
    # "no labels held" and proceed. This is the refusal that envelope always meant.
    printf '%s' "$out" | jq -r '.error.message // "br refused"' >&2 2>&-
    return 2
  fi
  printf '%s\n' "$out"
}