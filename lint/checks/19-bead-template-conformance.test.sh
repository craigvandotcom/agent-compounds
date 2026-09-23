#!/usr/bin/env bash
# 19-bead-template-conformance.test.sh — the proof harness for
# lint/checks/19-bead-template-conformance.py.
#
#   PROBE: a registry tree whose templates are conformant PASSES; a template without the
#           origin:<skill> label is FAILED; a finding template without a catch-stage label
#           is FAILED; each shape-detector function and the human-gate card contract are
#           exercised in isolation; each of the three lying Probe: shapes is FAILED and
#           each sound shape is CLEAR; the real registry is GREEN.
#
# ASSURANCE
#   PROBE:    bash lint/checks/19-bead-template-conformance.test.sh
#   SCHEDULE: scripts/run-all-proofs.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/19-bead-template-conformance.py"
ROOT="$(cd "$HERE/../.." && pwd)"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

OUT="$(mktemp)"
run_check() {
  python3 "$CHECK" "$1" >"$OUT" 2>&1
  echo $?
}

work="$(mktemp -d)"
trap 'rm -rf "$work" "$OUT"' EXIT

# --- RED: a template without origin: -> exit 1 ------------------------------
# The VACUOUS guard (>= 20 scanned templates) needs a populated fixture tree, so
# generate 20 conformant templates plus one missing its origin:<skill> label.
t="$work/bad"
mkdir -p "$t/hooks" "$t/skills/bad"
cp "$ROOT/hooks/bead-capture-guard.py" "$t/hooks/"
{
  for n in $(seq 1 20); do
    printf '%s\n' '`br create -t task --labels "origin:ac-hygiene,unrefined" --title "fixture-do-not-file '"$n"'"`'
  done
  printf '%s\n' '`br create -t bug --title "no provenance label"`'
} > "$t/skills/bad/SKILL.md"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "no origin:<skill> label" "$OUT"; then
  ok "RED: non-conforming template failed"
else
  bad "RED: expected exit 1 naming the template, got $rc"; cat "$OUT"
fi

# --- RED: a finding template without a catch-stage label -> exit 1 -------------
# The VACUOUS guard (>= 20 scanned templates) needs a populated fixture tree, so
# generate 20 conformant templates plus one finding template missing its catch-stage.
t="$work/nocatch"
mkdir -p "$t/hooks" "$t/skills/bad"
cp "$ROOT/hooks/bead-capture-guard.py" "$t/hooks/"
{
  for n in $(seq 1 20); do
    printf '%s\n' '`br create -t task --labels "origin:ac-hygiene,hygiene-finding,unrefined" --title "fixture-do-not-file '"$n"'"`'
  done
  printf '%s\n' '`br create -t bug --labels "origin:ac-triage,triage,<source>,unrefined" --title "fixture-do-not-file finding no-catch-stage"`'
} > "$t/skills/bad/SKILL.md"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "no catch-stage label" "$OUT"; then
  ok "RED: finding template without catch-stage failed"
else
  bad "RED: expected exit 1 naming the missing catch-stage, got $rc"; cat "$OUT"
fi

# --- LIVE: the real registry's shipped templates conform --------------------
rc=$(run_check "$ROOT")
if [ "$rc" = 0 ]; then
  ok "LIVE: shipped templates conform"
else
  bad "LIVE: expected exit 0 on the real registry, got $rc"; cat "$OUT"
fi

# --- unit + integration: shape-detector functions, the human-gate card contract,
# and probe_shape_violations() over synthetic Probe: lines — imported directly from
# the check module, isolated from the live registry's own corpus either way ---------
UNIT_OUT="$(python3 - "$CHECK" <<'PY'
import importlib.util
import os
import sys
import tempfile

check_path = sys.argv[1]
spec = importlib.util.spec_from_file_location("bead_template_conformance", check_path)
lint = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lint)

fails = 0


def check(name, fn, cmd, want):
    global fails
    got = bool(fn(cmd))
    if got != want:
        fails += 1
        print(f"FAIL  {name}: want={want} got={got}  cmd={cmd!r}")
    else:
        print(f"ok    {name}: {'FLAG' if want else 'CLEAR':5}  {cmd!r}")


# --- unit-level: each shape-detector function in isolation -----------------------
cases = [
    (lint.has_pnpm_passthrough, "pnpm test:integration:local -- __tests__/x.test.ts", True,
     "pnpm -- passthrough"),
    (lint.has_pnpm_passthrough, "pnpm test:one __tests__/x.test.ts", False,
     "pnpm test:one, no --, not flagged"),
    (lint.has_pnpm_passthrough, "npx vitest run --config vitest.integration.local.config.mts __tests__/x.test.ts", False,
     "npx form has no pnpm token, not flagged"),
    (lint.is_bare_affected_vitest, "pnpm vitest run __tests__/x.test.ts", True,
     "bare pnpm vitest run"),
    (lint.is_bare_affected_vitest, "npx vitest run __tests__/x.test.ts", True,
     "bare npx vitest run"),
    (lint.is_bare_affected_vitest, "VITEST_AFFECTED_DISABLED=1 npx vitest run __tests__/x.test.ts", False,
     "affected-disabled env var clears it"),
    (lint.is_bare_affected_vitest, "npx vitest run --config vitest.integration.local.config.mts __tests__/x.test.ts", False,
     "--config integration lane clears it"),
    (lint.is_bare_affected_vitest, "pnpm test:one __tests__/x.test.ts", False,
     "pnpm test:one never matches VITEST_RUN"),
    (lint.has_grepc_probe, "grep -c foo file.ts", True,
     "grep -c as pass/fail"),
    (lint.has_grepc_probe, "[ \"$(grep -c foo file.ts)\" -eq 0 ]", True,
     "grep -c inside a count comparison"),
    (lint.has_grepc_probe, "grep -q foo file.ts", False,
     "grep -q not flagged"),
    (lint.has_grepc_probe, "! grep -q foo file.ts", False,
     "! grep -q not flagged"),
]
for fn, cmd, want, name in cases:
    check(name, fn, cmd, want)

# --- unit-level: the human-gate card contract (human_gate_violation) ---------------
hg_cases = [
    ("br create -t decision --title 'DECISION: pick X' -l origin:x,human-gate -d 'Gate-reason: fork — why'",
     False, "conformant decision card"),
    ("br create -t task --title 'ACTION: do x' -l origin:x,human-gate -d 'Gate-reason: authorization — why'",
     False, "conformant action card"),
    ("br create -t decision --title 'DECISION: pick X' -l origin:x,human-gate -d 'decision: which?'",
     True, "human-gate body with no Gate-reason"),
    ("br create -t task --title 'DECISION: pick X' -l origin:x,human-gate -d 'Gate-reason: fork — why'",
     True, "DECISION: prefix with -t task"),
    ("br create -t decision --title 'ACTION: do x' -l origin:x,human-gate -d 'Gate-reason: authorization — why'",
     True, "ACTION: prefix with -t decision"),
    ("br create -t decision -l origin:x,human-gate -d '<full memo>'",
     False, "placeholder body skipped"),
    ("br create -t decision --title 'Proposal: x' -l origin:x,human-gate -d 'Gate-reason: fork — y'",
     False, "prefix-less title with a reason is legal"),
    ("br create -t decision --title 'Proposal: x' -l origin:x,human-gate -d 'memo with no reason'",
     True, "prefix-less title still needs Gate-reason"),
]
for cmd, want, name in hg_cases:
    check(name, lambda s: lint.human_gate_violation(lint._tokens(s)), cmd, want)

# --- integration-level: probe_shape_violations() over a real Probe: line, extracted
# through PROBE_LINE the same way a registry .md file would be scanned -------------
BAD_PROBE_LINES = {
    "pnpm-dashdash": "  Probe: `pnpm test:integration:local -- __tests__/x.test.ts` — tier: supabase-integration",
    "bare-vitest": "  Probe: `npx vitest run __tests__/x.test.ts` — tier: standing-vitest",
    "grep-c": "  Probe: `grep -c foo file.ts` — tier: none",
}
GOOD_PROBE_LINES = {
    "test-one": "  Probe: `pnpm test:one __tests__/x.test.ts` — tier: standing-vitest",
    "affected-disabled": "  Probe: `VITEST_AFFECTED_DISABLED=1 npx vitest run __tests__/x.test.ts` — tier: standing-vitest",
    "integration-config": "  Probe: `npx vitest run --config vitest.integration.local.config.mts __tests__/x.test.ts` — tier: supabase-integration",
    "bang-grep-q": "  Probe: `! grep -q foo file.ts` — tier: none",
}


def scan_one_line(line):
    """Run the module's real per-file scan machinery over a single synthetic .md file
    holding one Probe: line, isolated in a scratch skills/ tree so the registry's own
    corpus cannot mask a regression either way."""
    with tempfile.TemporaryDirectory() as td:
        skills = os.path.join(td, "skills", "zzz-harness")
        os.makedirs(skills)
        with open(os.path.join(skills, "SKILL.md"), "w") as fh:
            fh.write("## Acceptance Criteria\n- something.\n" + line + "\n")
        saved_root = lint.ROOT
        lint.ROOT = td
        try:
            out, scanned = lint.probe_shape_violations()
        finally:
            lint.ROOT = saved_root
        return out, scanned


for name, line in BAD_PROBE_LINES.items():
    out, scanned = scan_one_line(line)
    good = scanned == 1 and len(out) == 1
    if not good:
        fails += 1
        print(f"FAIL  integration bad/{name}: scanned={scanned} findings={out}")
    else:
        print(f"ok    integration bad/{name}: flagged — {out[0][2]}")

for name, line in GOOD_PROBE_LINES.items():
    out, scanned = scan_one_line(line)
    good = scanned == 1 and len(out) == 0
    if not good:
        fails += 1
        print(f"FAIL  integration good/{name}: scanned={scanned} findings={out}")
    else:
        print(f"ok    integration good/{name}: clear")

print(f"\n{len(cases) + len(hg_cases) + len(BAD_PROBE_LINES) + len(GOOD_PROBE_LINES) - fails}/"
      f"{len(cases) + len(hg_cases) + len(BAD_PROBE_LINES) + len(GOOD_PROBE_LINES)} passed")
sys.exit(1 if fails else 0)
PY
)"
rc=$?
echo "$UNIT_OUT" | sed 's/^/  | /'
if [ "$rc" -eq 0 ]; then
  ok "unit+integration: shape-detector functions, human-gate contract, probe-shape scan"
else
  bad "unit+integration: shape-detector functions, human-gate contract, probe-shape scan"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "All 19-bead-template-conformance contract cases passed."
  exit 0
fi
echo "$fails case(s) FAILED."
exit 1
