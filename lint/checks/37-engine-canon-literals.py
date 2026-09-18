#!/usr/bin/env python3
# ---
# id: 37-engine-canon-literals
# prevents: the engine hardcoding a path to canon instead of deriving it — the defect
#   that made harness-sync unrunnable outside one machine's monorepo, rendered a dead
#   hook path into all seven deploy targets, and 404'd the recall hook on every prompt
#   (ac-9ahd). A literal survives a layout change silently: it still parses, still
#   renders, and only the file at the end of it is missing.
# scope: ENGINE
# severity: fail
# fixture: lint/fixtures/37-engine-canon-literals
# ---
"""37-engine-canon-literals — the engine must DERIVE its paths, never spell them.

The boundary this mechanises (ac-ys8f): `engine/` holds machinery, the repo root holds
canon, and the machinery reaches canon through variables resolved from its own location
(`AC_ROOT`, `ENGINE_DIR`, `ORG_ROOT`) — never through a literal that pins one machine's
directory layout.

Forbidden in engine/ CODE:

  1  An absolute home-anchored path — `$HOME/Repos/...`, `~/Repos/...`, `/Users/<x>/...`,
     `/home/<x>/...`. These name one machine. `$HOME` alone is fine and is how rendered
     configs stay portable: the consuming harness expands it.
  2  A hardcoded domain-repo segment — `neometa/software/`, `mission/software/`. The
     domain repo names itself differently per layout, so spelling either one is the
     same bug wearing a different name.

PROSE IS OUT OF SCOPE, deliberately. Comments, docstrings and `_doc` fields explain this
history and must be able to quote the very literals the check forbids — including the
commit that relocated these files. A check that reddened on its own explanation would be
removed within a week, so it reads code lines only: `#`-comments are stripped, and in the
wiring manifest only the `command` fields are examined.

Exit: 0 clean, 1 a literal found, 2 no engine/ under root (NOT-GATED, never a pass).
"""

import json
import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_LINT = os.path.dirname(_HERE)
sys.path.insert(0, _LINT)

from lib import scope  # noqa: E402

CHECK_ID = "37-engine-canon-literals"

PATTERNS = (
    (re.compile(r'\$HOME/Repos|~/Repos'), "home-anchored monorepo literal"),
    (re.compile(r'/Users/[A-Za-z0-9._-]+/'), "absolute macOS home path"),
    (re.compile(r'/home/[A-Za-z0-9._-]+/'), "absolute Linux home path"),
    (re.compile(r'\b(?:neometa|mission)/software/'), "hardcoded domain-repo segment"),
)


def _code_lines(text):
    """(lineno, text) for lines that are not pure comments. Cheap on purpose: a shell
    comment is the only prose form that shares a line with code, and stripping the
    trailing part would also strip legitimate `#` inside a string."""
    for i, line in enumerate(text.splitlines(), 1):
        if line.lstrip().startswith("#"):
            continue
        yield i, line


def _manifest_commands(path):
    """Only the `command` fields of the wiring manifest are code — everything else in
    it is documentation, including the long `_doc` that recounts this exact defect."""
    try:
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
    except Exception as exc:  # malformed is a different check's job, not a silent pass
        return None, f"{os.path.basename(path)} does not parse as JSON ({exc})"
    out = []
    for entry in data.get("wiring", []):
        cmd = entry.get("command")
        for value in (cmd.values() if isinstance(cmd, dict) else [cmd]):
            if isinstance(value, str):
                out.append((entry.get("id", "?"), value))
    return out, None


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else scope.ROOT
    if os.path.abspath(root) != scope.ROOT:
        os.environ["LINT_ROOT"] = os.path.abspath(root)
        import importlib
        importlib.reload(scope)

    files = sorted(scope.ENGINE)
    if not files:
        print(f"{CHECK_ID} NOT-CHECKED: no engine/ under {root} — verified nothing",
              file=sys.stderr)
        return 2

    findings = []
    for rel in files:
        path = os.path.join(root, rel)
        if rel.endswith(".json"):
            commands, err = _manifest_commands(path)
            if err:
                findings.append(f"{rel}: {err}")
                continue
            for wiring_id, cmd in commands:
                for pattern, label in PATTERNS:
                    if pattern.search(cmd):
                        findings.append(
                            f"{rel}: wiring '{wiring_id}' command carries a {label} — "
                            f"use a {{HOOKS}}/{{INFRA}} placeholder the renderer substitutes")
            continue
        with open(path, encoding="utf-8", errors="replace") as fh:
            for lineno, line in _code_lines(fh.read()):
                for pattern, label in PATTERNS:
                    if pattern.search(line):
                        findings.append(
                            f"{rel}:{lineno}: {label} — derive it from ENGINE_DIR/"
                            f"AC_ROOT/ORG_ROOT instead of spelling it")

    if findings:
        for f in findings:
            print(f"{CHECK_ID} FAIL: {f}", file=sys.stderr)
        return 1

    print(f"    ok: {CHECK_ID} — {len(files)} engine file(s) derive their paths, none spelled")
    return 0


if __name__ == "__main__":
    sys.exit(main())
