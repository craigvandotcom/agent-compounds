#!/usr/bin/env python3
"""deployed-app-conformance — no dead names in every-prompt surfaces.

This audits DEPLOY TARGETS, which sync.sh owns — lint.sh gates only this
repo's own tree, never a consumer's. Called as a subprocess from sync.sh's
--check leg; `lint/lib/consumers.py` stays put (lint check 14 also imports
it), so this file reaches into `lint/` for it rather than duplicating the
consumer-dir union logic.

Probes each consumer's hooks/workflow-reminder.md (C1 dead pipeline
commands), its .codex/hooks twin where present, hooks/delegation-reminder.md
(C2 dead delegation tools), and the app-root AGENTS.md (C3 dead pipeline
stage names). The union itself — the org root's `.claude` union the deploy
targets' `.claude` — is asked of engine/machine.sh through lib.consumers,
never derived here.

Scope is deliberately narrow — only the named every-prompt files — so the
check never fires on documentation that legitimately mentions these strings
as history/examples rather than live guidance.

Exit: 0 clean, or no consumer dir resolves at all (SKIP, disclosed — the
check audits files outside this repo and a fresh/consumer-less checkout has
none); 1 dead names; 2 the machine's facts are unresolved-or-refused
(NOT-CHECKED — a human must fix the machine file, so a green here would be a
claim nobody made).
"""

import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))          # engine/checks
_ENGINE_DIR = os.path.dirname(_HERE)                         # engine
_AC_ROOT = os.path.dirname(_ENGINE_DIR)                       # repo root
_LINT_DIR = os.path.join(_AC_ROOT, "lint")
if _LINT_DIR not in sys.path:
    sys.path.insert(0, _LINT_DIR)

from lib import consumers  # noqa: E402

C1_PATTERN = "/ac/bead-work|/ac/wave-merge|/ac/backlog-add|/ac/bead-land|/ac/work-review"
C2_PATTERN = "cass search"
C3_PATTERN = "bead-work|wave-merge"

violations = []


def fail(msg):
    violations.append(msg)


def disp(path):
    """What the violation names — the consumer path with the $HOME/ prefix off."""
    home_prefix = os.path.expanduser("~") + os.sep
    return path[len(home_prefix):] if path.startswith(home_prefix) else path


def scan():
    try:
        dirs = consumers.consumer_dirs()
    except consumers.MachineNotConfigured as exc:
        print(f"SKIP deployed-app-conformance: {exc} — the consumer union is unknown "
              "here, so nothing was conformed and nothing was verified", file=sys.stderr)
        return 0
    except consumers.MachineWrong as exc:
        print(f"deployed-app-conformance: {exc}", file=sys.stderr)
        return 2
    if not any(os.path.isdir(d) for d in dirs):
        print(f"SKIP deployed-app-conformance: no consumer dir resolves "
              f"under {consumers.org_root()} (a consumer-less checkout, e.g. a fresh clone with "
              "no deployed harness layer); nothing to conform, nothing verified",
              file=sys.stderr)
        return 0
    scanned = 0
    for d in dirs:
        if not os.path.isdir(d):
            continue  # non-existent dirs are skipped silently: a consumer-less
            # checkout is a disclosed SKIP above, not a per-dir failure here
        scanned += 1
        app_root = os.path.dirname(d)
        for hooks_dir in (os.path.join(d, "hooks"), os.path.join(app_root, ".codex", "hooks")):
            wr = os.path.join(hooks_dir, "workflow-reminder.md")
            if os.path.isfile(wr) and re.search(C1_PATTERN, _read(wr)):
                fail(f"C1: {disp(wr)} still contains dead pipeline command name(s)")
            dr = os.path.join(hooks_dir, "delegation-reminder.md")
            if os.path.isfile(dr) and re.search(C2_PATTERN, _read(dr)):
                fail(f"C2: {disp(dr)} still contains dead delegation tool name(s)")
        agents_md = os.path.join(app_root, "AGENTS.md")
        if os.path.isfile(agents_md) and re.search(C3_PATTERN, _read(agents_md)):
            fail(f"C3: {disp(agents_md)} still contains dead pipeline stage name(s)")

    if scanned == 0:
        # A consumer dir resolved a moment ago; this branch should be unreachable
        # outside a race (a dir removed mid-scan). Either way, a scan that touched
        # zero dirs proved nothing — skip, never claim a pass.
        print("SKIP deployed-app-conformance: no consumer dir resolved on "
              "scan; nothing to conform, nothing verified", file=sys.stderr)
        return 0
    print(f"deployed-app-conformance: {scanned} consumer dir(s) scanned")
    if violations:
        print("FAIL deployed-app-conformance: dead name(s) in every-prompt surfaces:")
        for v in violations:
            print(f"  - {v}")
        return 1
    print("deployed-app-conformance: PASS")
    return 0


def _read(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        return fh.read()


def main():
    return scan()


if __name__ == "__main__":
    sys.exit(main())
