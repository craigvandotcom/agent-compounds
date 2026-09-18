#!/usr/bin/env python3
# ---
# id: 18-guard-liveness
# prevents: a dead guard — a hook that is wired but not executable, or a guard that no longer fires
#   on its positive case (or fires on its negative one); doctrine that never reaches the actor is
#   this registry's most expensive failure mode
# scope: HOOKS
# severity: fail
# fixture: lint/fixtures/18-guard-liveness
# ---
"""18-guard-liveness — the ported Check 18 (ac-1p7j.15).

Ported VERBATIM from the legacy bash block (proven by lint/parity.sh against
the extracted block, before the block was removed from lint.sh). Same probes,
same verdict strings. Executability alone is not the assertion: a hook that
runs and always exits 0 is equally dead. So every guard asserts that it RUNS,
and every guard we can drive asserts that it FIRES on a positive case and
stays SILENT on a negative one.

  - every hooks/*.py must be executable
  - skill-edit-guard.py must fire (exit 2) on both entry points — an Edit
    file_path under skills/, and a Bash command writing into skills/ — and
    stay silent (exit 0) on both negatives (non-skill file, read-only command)
  - bead-capture-guard is a HARD gate, so its own 25-case behaviour suite is
    driven rather than duplicated probes that would drift from it
  - wiring lives in the harness settings, not this repo, so a missing or
    partial matcher is reported as a NOTICE, never failed — but it is ALWAYS
    printed: an unwired guard is exactly as dead as a non-executable one

The probe flag dir is a private mktemp (the legacy block used a shared
/tmp/lint-guard-probe that concurrent runs clobbered).

Exit: 0 clean, 1 violations, 2 no hooks/*.py under root (NOT-GATED, never a
pass).
"""

import os
import subprocess
import sys
import tempfile

_HERE = os.path.dirname(os.path.abspath(__file__))
_LINT = os.path.dirname(_HERE)
sys.path.insert(0, _LINT)

violations = []
notices = []


def probe_guard(seg, payload, expected, label, flagroot):
    flagdir = os.path.join(flagroot, f"p{expected}-{os.getpid()}-{label.replace(' ', '-')}")
    try:
        cmd = [seg]
        proc = subprocess.run(
            cmd, input=payload, capture_output=True, text=True, timeout=60,
            env={**os.environ, "SKILL_EDIT_GUARD_FLAG_DIR": flagdir},
        )
        got = proc.returncode
    except (subprocess.SubprocessError, OSError):
        got = -1
    if got != expected:
        violations.append(f"skill-edit-guard {label} (exit {got}, expected {expected})")


def main(argv=()):
    """argv is injectable so harnesses can drive this check without stdin games."""
    args = list(argv)
    root = args[0] if args else os.path.dirname(_LINT)
    hooks = os.path.join(root, "hooks")
    if not os.path.isdir(hooks):
        print("18-guard-liveness NOT-CHECKED: no hooks/ under root — nothing scanned",
              file=sys.stderr)
        return 2

    scanned = 0
    for name in sorted(os.listdir(hooks)):
        path = os.path.join(hooks, name)
        if not (os.path.isfile(path) and name.endswith(".py")):
            continue
        scanned += 1
        if not os.access(path, os.X_OK):
            violations.append(
                f"hooks/{name} is not executable — the hook is wired but dead")

    seg = os.path.realpath(os.path.join(hooks, "skill-edit-guard.py"))
    if os.path.isfile(seg) and os.access(seg, os.X_OK):
        with tempfile.TemporaryDirectory(prefix="lint-guard-probe.") as flagroot:
            probe_guard(seg, '{"tool_input":{"file_path":"/x/skills/y/SKILL.md"}}',
                        2, "did not fire on a skills/ file_path", flagroot)
            probe_guard(seg, '{"tool_input":{"command":"perl -0pi -e s/a/b/ skills/y/references/z.md"}}',
                        2, "did not fire on a Bash write into skills/", flagroot)
            probe_guard(seg, '{"tool_input":{"file_path":"/x/lint.sh"}}',
                        0, "fired on a non-skill file", flagroot)
            probe_guard(seg, '{"tool_input":{"command":"grep -rn foo skills/"}}',
                        0, "fired on a read-only command", flagroot)
        print("  skill-edit-guard: fires on both entry points, silent on both negatives")
    else:
        violations.append(
            "skill-edit-guard.py missing or not executable — cannot probe behaviour")

    bog = os.path.join(hooks, "bead-capture-guard.test.py")
    bog_guard = os.path.join(hooks, "bead-capture-guard.py")
    if os.access(bog_guard, os.X_OK) and os.path.isfile(bog) and os.access(bog, os.R_OK):
        rc = subprocess.run([sys.executable, bog], capture_output=True, timeout=120).returncode
        if rc == 0:
            print("  bead-capture-guard: provenance-gate behaviour suite passes")
        else:
            violations.append(
                "bead-capture-guard behaviour suite FAILED — run python3 hooks/bead-capture-guard.test.py")
    else:
        violations.append(
            "bead-capture-guard.py or its .test.py is missing — the bead provenance gate cannot be verified")

    settings = os.path.join(os.path.expanduser("~"), "Repos", ".claude", "settings.json")
    if os.path.isfile(settings):
        try:
            import json
            with open(settings, encoding="utf-8") as fh:
                d = json.load(fh)
            matchers = [
                e.get("matcher", "*")
                for e in d.get("hooks", {}).get("PreToolUse", [])
                for h in e.get("hooks", [])
                if "skill-edit-guard" in h.get("command", "")
            ]
            wiring = ",".join(matchers) if matchers else "NONE"
        except (OSError, ValueError):
            wiring = "NONE"
        if "Bash" in wiring and "Edit" in wiring:
            print(f"  wiring: skill-edit-guard on [{wiring}] — both entry points covered")
        elif wiring in ("NONE", ""):
            notices.append(
                f"skill-edit-guard is NOT wired in {settings} — it cannot fire on this machine")
        else:
            notices.append(
                f"skill-edit-guard wired on [{wiring}] only — the uncovered entry point is ungoverned")
    else:
        notices.append(f"{settings} unreadable — wiring not verified on this machine")

    for n in notices:
        print(f"NOTICE: {n}")
    if scanned == 0 and not violations:
        print("18-guard-liveness NOT-CHECKED: no hooks/*.py under root — nothing scanned",
              file=sys.stderr)
        return 2
    if violations:
        for v in violations:
            print(f"FAIL 18-guard-liveness: {v}")
        return 1
    print(f"18-guard-liveness: {scanned} hooks/*.py scanned, all guards alive")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
