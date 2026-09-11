# ASSURANCE-ROLE: test-harness
# CALLER: scripts/run-all-harnesses.sh (glob-discovered) and lint check
# 19-bead-template-conformance (which shells out to scripts/bead-template-lint.py, the
# module this harness imports directly). Deliberately UNWIRED in hooks/hooks.json: it is
# the PROOF for bead-template-lint.py, not a hook itself.
#
# Covers the probe-shape check (ac-attt): three Probe: shapes that pass `no probe, no
# bead` (a runnable command) and still lie about the result —
#   1. `pnpm <script> -- <file>` (pnpm forwards the literal `--`, running the whole suite)
#   2. a bare `pnpm|npx vitest run <file>` (vitest-affected can silently drop the file)
#   3. `grep -c` read as pass/fail (exits 1 on a zero count)
# each case is checked with a Probe: line built from bead-schema.md's exact grammar
# (`Probe: \`<command>\` — tier: <tier>`) so the module's own extractor is exercised, not
# a hand-rolled shortcut.
import glob
import importlib.util
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

spec = importlib.util.spec_from_file_location(
    "bead_template_lint", os.path.join(HERE, "bead-template-lint.py")
)
lint = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lint)

fails = 0


def check(name, fn, cmd, want):
    got = bool(fn(cmd))
    ok = got == want
    global fails
    if not ok:
        fails += 1
        print(f"FAIL  {name}: want={want} got={got}  cmd={cmd!r}")
    else:
        print(f"ok    {name}: {'FLAG' if want else 'CLEAR':5}  {cmd!r}")


# --- unit-level: each shape-detector function in isolation -----------------------
cases = [
    # (detector, command, expected True/False, case name)
    (lint.has_pnpm_passthrough, "pnpm test:integration:local -- __tests__/x.test.ts", True,
     "pnpm -- passthrough (bd-yfv1j shape)"),
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
    ok = scanned == 1 and len(out) == 1
    if not ok:
        fails += 1
        print(f"FAIL  integration bad/{name}: scanned={scanned} findings={out}")
    else:
        print(f"ok    integration bad/{name}: flagged — {out[0][2]}")

for name, line in GOOD_PROBE_LINES.items():
    out, scanned = scan_one_line(line)
    ok = scanned == 1 and len(out) == 0
    if not ok:
        fails += 1
        print(f"FAIL  integration good/{name}: scanned={scanned} findings={out}")
    else:
        print(f"ok    integration good/{name}: clear")

# --- the registry itself must scan clean under the real check (no regression on the
# corpus this lint actually guards) ------------------------------------------------
real_out, real_scanned = lint.probe_shape_violations()
if real_scanned < 5:
    fails += 1
    print(f"FAIL  registry scan: only {real_scanned} Probe: line(s) found — detector looks broken")
elif real_out:
    fails += 1
    print(f"FAIL  registry scan: {len(real_out)} probe-shape violation(s) in the live registry:")
    for rel, line_no, why in real_out:
        print(f"      {rel}:{line_no} — {why}")
else:
    print(f"ok    registry scan: {real_scanned} Probe: line(s) in the live registry, all sound")

# --- the live registry's bead TEMPLATES must also scan clean (origin · readiness ·
# catch-stage · human-gate contract) -------------------------------------------------
tpl_out, tpl_scanned = lint.violations()
if tpl_scanned < 20:
    fails += 1
    print(f"FAIL  registry templates: only {tpl_scanned} template(s) found — detector looks broken")
elif tpl_out:
    fails += 1
    print(f"FAIL  registry templates: {len(tpl_out)} non-conforming template(s):")
    for rel, line_no, why in tpl_out:
        print(f"      {rel}:{line_no} — {why}")
else:
    print(f"ok    registry templates: {tpl_scanned} template(s) in the live registry, all conformant")

print(f"\n{len(cases) + len(hg_cases) + len(BAD_PROBE_LINES) + len(GOOD_PROBE_LINES) + 2 - fails}/"
      f"{len(cases) + len(hg_cases) + len(BAD_PROBE_LINES) + len(GOOD_PROBE_LINES) + 2} passed")
sys.exit(1 if fails else 0)
