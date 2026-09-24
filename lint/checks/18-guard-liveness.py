#!/usr/bin/env python3
# ---
# prevents: a dead guard — a hook that is wired but not executable, or a guard that no longer fires
#   on its positive case (or fires on its negative one); doctrine that never reaches the actor is
#   this registry's most expensive failure mode
# fixture: lint/fixtures/18-guard-liveness
# ---
"""18-guard-liveness — every wired guard actually fires.

Executability alone is not the assertion: a hook that
runs and always exits 0 is equally dead. So every guard asserts that it RUNS,
and every guard we can drive asserts that it FIRES on a positive case and
stays SILENT on a negative one.

  - every hook script under hooks/ must be executable — a `.py`, a `.sh`, or
    an extensionless file carrying a shebang; the `.md` docs there are not
    guards and are never scanned
  - skill-edit-guard.py must fire (exit 2) on both entry points — an Edit
    file_path under skills/, and a Bash command writing into skills/ — and
    stay silent (exit 0) on both negatives (non-skill file, read-only command)
  - wiring lives in the harness settings this machine actually renders
    (org scope: `<org_root>/.claude/settings.json`, org_root read via
    `engine/machine.sh --org-root`), never a hardcoded user path. When that
    file cannot be located (machine.json absent, e.g. CI) or does not exist,
    the leg reports a NOTICE and claims no verdict. When it IS present, an
    unwired or partially-wired guard FAILs — it is exactly as dead as a
    non-executable one.

The probe flag dir is a private mktemp — a shared /tmp path would be
clobbered by concurrent runs.

Exit: 0 clean, 1 violations, 2 no hook scripts under root (NOT-GATED, never a
pass).
"""

import os
import subprocess
import sys
import tempfile

_HERE = os.path.dirname(os.path.abspath(__file__))
_LINT = os.path.dirname(_HERE)  # this check imports no `lib` module — _LINT only computes the repo root below

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

    def _is_hook_script(path, name):
        """True for a guard script: `.py`, `.sh`, or an extensionless file with a
        shebang. `.md` docs (delegation-reminder.md and friends) are never guards."""
        if name.endswith(".md"):
            return False
        if name.endswith(".py") or name.endswith(".sh"):
            return True
        if "." in name:
            return False
        try:
            with open(path, "rb") as fh:
                return fh.read(2) == b"#!"
        except OSError:
            return False

    scanned = 0
    for name in sorted(os.listdir(hooks)):
        path = os.path.join(hooks, name)
        if not os.path.isfile(path) or not _is_hook_script(path, name):
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

    # The live wiring: org scope renders skill-edit-guard into
    # <org_root>/.claude/settings.json. org_root comes from the ONE reader of
    # machine.json (engine/machine.sh) — never a hardcoded user path. When
    # machine.json is absent (e.g. CI) machine.sh exits 4 and org_root is
    # unknown, so the leg can only NOTICE. Once the settings file IS present,
    # an unwired or partially-wired guard is a real FAIL, not a notice.
    ac_root = os.path.dirname(_LINT)
    machine_sh = os.path.join(ac_root, "engine", "machine.sh")
    settings = None
    try:
        org_root_proc = subprocess.run(
            ["bash", machine_sh, "--org-root"],
            capture_output=True, text=True, timeout=30,
        )
        if org_root_proc.returncode == 0 and org_root_proc.stdout.strip():
            settings = os.path.join(org_root_proc.stdout.strip(), ".claude", "settings.json")
    except (subprocess.SubprocessError, OSError):
        settings = None

    if settings is None:
        notices.append(
            "machine.json is not configured on this machine (engine/machine.sh "
            "--org-root) — wiring not verified")
    elif not os.path.isfile(settings):
        notices.append(f"{settings} absent — wiring not verified on this machine")
    else:
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
            violations.append(
                f"skill-edit-guard is NOT wired in {settings} — it cannot fire on this machine")
        else:
            violations.append(
                f"skill-edit-guard wired on [{wiring}] only — the uncovered entry point is ungoverned")

    for n in notices:
        print(f"NOTICE: {n}")
    if scanned == 0 and not violations:
        print("18-guard-liveness NOT-CHECKED: no hook scripts under root — nothing scanned",
              file=sys.stderr)
        return 2
    if violations:
        for v in violations:
            print(f"FAIL 18-guard-liveness: {v}")
        return 1
    print(f"18-guard-liveness: {scanned} hook script(s) scanned, all guards alive")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
