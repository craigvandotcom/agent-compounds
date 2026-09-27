#!/usr/bin/env bash
# 38-push-lane.test.sh — the fixture proving Check 38's contract.
#
#   PROBE: the committed static fixture is RED on a bare `git push` inside a fenced code
#          block, while a comment quoting `git push`, out-of-fence prose, `push.sh` itself
#          and a `*.test.sh` harness all stay GREEN; the real registry is GREEN; a root with
#          none of the routed surface is NOT-GATED (2).
#
# ASSURANCE
#   PROBE:    bash lint/checks/38-push-lane.test.sh
#   SCHEDULE: scripts/run-all-proofs.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/38-push-lane.py"
ROOT="$(cd "$HERE/../.." && pwd)"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

# --- RED: the static fixture, a bare `git push` inside a fenced code block --------
out="$(python3 "$CHECK" "$ROOT/lint/fixtures/38-push-lane" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "worker.md:10: bare \`git push\`"; then
  ok "RED: fenced code line -> exit 1 naming the line"
else
  bad "fixture code line: expected 1 naming worker.md:10, got $rc"; printf '%s\n' "$out"
fi

# --- GREEN: push.sh itself is excluded even though it runs the real `git push` ------
if printf '%s' "$out" | grep -q "scripts/push.sh:"; then
  bad "push.sh was scanned — it must be excluded (**/push.sh)"
  printf '%s\n' "$out"
else
  ok "GREEN: push.sh excluded"
fi

# --- GREEN: a *.test.sh harness is excluded even though it runs the real `git push` --
if printf '%s' "$out" | grep -q "swarm-commit.test.sh:"; then
  bad "a *.test.sh harness was scanned — it must be excluded"
  printf '%s\n' "$out"
else
  ok "GREEN: *.test.sh harness excluded"
fi

# --- GREEN: a comment quoting `git push`, and out-of-fence prose, are not findings --
if printf '%s' "$out" | grep -qE "worker\.md:[0-9]+: bare" && \
   printf '%s' "$out" | grep -c "worker.md:" | grep -qx 1; then
  ok "GREEN: only the real code line in worker.md was flagged (comment + prose ignored)"
else
  bad "worker.md flagged more than the one code line"; printf '%s\n' "$out"
fi

# --- GREEN: the routed non-fixture examples in the same tree stay clean ------------
if printf '%s' "$out" | grep -qE "handoff\.md|run-loop\.md|commit-discipline\.md"; then
  bad "a clean fixture file was flagged"; printf '%s\n' "$out"
else
  ok "GREEN: the clean fixture files (handoff/run-loop/commit-discipline) stay clean"
fi

# --- GREEN: the real registry -------------------------------------------------------
out="$(python3 "$CHECK" "$ROOT" 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then
  ok "GREEN: the real routed surface is push.sh-only"
else
  bad "real registry: expected 0, got $rc"; printf '%s\n' "$out"
fi

# --- NOT-GATED: none of the routed surface exists under root ------------------------
w="/tmp/38-push-lane-not-gated"
rm -rf "$w" 2>/dev/null
mkdir -p "$w"
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q "NOT-CHECKED"; then
  ok "NOT-GATED: no routed surface -> exit 2, never a pass"
else
  bad "no-surface case: expected 2 NOT-CHECKED, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

if [ "$fails" -gt 0 ]; then
  echo "38-push-lane: $fails case(s) FAILED"
  exit 1
fi
echo "38-push-lane: all cases passed"
