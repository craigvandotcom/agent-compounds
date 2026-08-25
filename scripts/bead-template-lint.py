#!/usr/bin/env python3
"""Static twin of hooks/bead-capture-guard.py — lints `br create` TEMPLATES in skills/.

The runtime guard catches what an agent TYPES. This catches what the registry SHIPS.
Neither alone is enough: a correct template can be typed wrong, and a stale template
poisons every future run that copies it.

It IMPORTS the guard rather than reimplementing the contract. Two copies of the rules
would drift — which is the exact failure this whole mechanism exists to prevent. Change
`beads-standards/reference/bead-create-contract.md`, then the guard; this follows for free.

A "template" is a `br create`/`br q` carrying at least one flag. A bare prose mention
("before any `br create`") carries none and is not linted.
"""

import glob
import importlib.util
import os
import re
import shlex
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

spec = importlib.util.spec_from_file_location(
    "bead_capture_guard", os.path.join(ROOT, "hooks", "bead-capture-guard.py")
)
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)

FLAG = re.compile(r"(^|\s)(-t|-p|-l|-d|--type|--priority|--labels|--title|--body|--description)([=\s]|$)")
CMD = re.compile(r"(^|[`\s])br (create|q)\b")

# A TEMPLATE may legitimately carry an unsubstituted placeholder — `origin:<skill>`, or
# qa-shared's two-twin `origin:<ac-qa-device|ac-qa-browser>`. That is the template doing its
# job. The RUNTIME guard is deliberately stricter and rejects the same placeholder, because
# by then it must have been substituted. Same contract, different moment.
TEMPLATE_ORIGIN = re.compile(r"^origin:(<[^>]+>|[A-Za-z0-9][A-Za-z0-9._-]*)$")


def template_has_origin(cmd):
    return any(TEMPLATE_ORIGIN.match(l) for l in guard.all_labels(cmd))


# A title or labels — NOT -d/--description. Skill prose illustrates shell-quoting hazards
# with fragments like `br create -d "…"`, which name nothing and are not copyable templates.
CONTENT_FLAGS = {"--title", "-l", "--labels"}
CONTENT_PREFIXES = ("--title=", "--labels=")


def is_substantive(cmd):
    """True for a real template; False for a prose mention of the command.

    Skill text says things like "`br create -t decision` matches the type table" — a
    reference to the command, not an invocation to copy. Linting those produces noise that
    trains people to ignore the check. A real template names WHAT it files: a title, a body,
    or labels.
    """
    sub_at = next(i for i, t in enumerate(cmd) if t.rsplit("/", 1)[-1] == "br")
    rest = cmd[sub_at + 2:]
    skip_next = False
    for tok in rest:
        if skip_next:
            skip_next = False
            continue
        if tok in CONTENT_FLAGS or tok.startswith(CONTENT_PREFIXES):
            return True
        if tok.startswith("-"):
            skip_next = tok in {"-t", "--type", "-p", "--priority", "--parent", "-e", "--estimate", "-d", "--description", "--body"}
            continue
        return True  # a bare positional — the title
    return False


INLINE_CODE = re.compile(r"`([^`]*\bbr (?:create|q)\b[^`]*)`")


def clip_inline_code(block):
    """Keep only the inline-code span when the command sits inside one.

    Two failure modes this avoids. Stripping backticks wholesale leaves the trailing
    markdown prose as bare tokens, which then read as a positional title and make a prose
    mention look like a template. Leaving them attached glues a fence onto the last label
    (`unrefined\\`` != `unrefined`) and fakes a missing readiness label.
    """
    m = INLINE_CODE.search(block)
    return m.group(1) if m else block.replace("`", " ")


def templates(path):
    """Yield (line_no, joined_command) for each real template in a markdown file."""
    lines = open(path, encoding="utf-8").read().split("\n")
    i = 0
    while i < len(lines):
        if CMD.search(lines[i]):
            block, j = lines[i], i
            # backslash continuations
            while block.rstrip().endswith("\\") and j + 1 < len(lines):
                j += 1
                block = block.rstrip()[:-1] + " " + lines[j]
            # a markdown line that wraps immediately after the labels flag
            if re.search(r"(--labels|\s-l)\s*$", block) and j + 1 < len(lines):
                j += 1
                block = block + " " + lines[j].strip()
            if FLAG.search(block):
                yield i + 1, clip_inline_code(block).strip()
            i = j
        i += 1


def violations():
    """Returns (violations, templates_scanned). The count is not cosmetic: if the detection
    regex ever breaks, this lint would scan nothing and report success — a false green is
    worse than no check, because it is trusted."""
    out = []
    scanned = 0
    for path in sorted(glob.glob(os.path.join(ROOT, "skills", "**", "*.md"), recursive=True)):
        rel = os.path.relpath(path, ROOT)
        for line_no, block in templates(path):
            try:
                tokens = shlex.split(block, comments=False, posix=True)
            except ValueError:
                continue  # unparseable prose fragment — fail open, same as the guard
            for cmd in guard.commands(tokens):
                if guard.is_bead_create(cmd) is None:
                    continue
                if any(t in guard.HELP for t in cmd) or not is_substantive(cmd):
                    continue
                scanned += 1
                if not template_has_origin(cmd):
                    out.append((rel, line_no, "no origin:<skill> label"))
                    continue
                typ = guard.bead_type(cmd)
                if (
                    typ is not None
                    and typ not in guard.READINESS_EXEMPT_TYPES
                    and not guard.has_readiness(cmd)
                ):
                    out.append((rel, line_no, f"type `{typ}` with no readiness label"))
    return out, scanned


if __name__ == "__main__":
    bad, scanned = violations()
    if scanned < 20:
        print(f"  VACUOUS: only {scanned} bead templates found under skills/ — the "
              "detector is broken, not the registry. A pass here would be a false green.")
        sys.exit(1)
    for rel, line_no, why in bad:
        print(f"  {rel}:{line_no} — {why}")
    if bad:
        print(
            f"\n{len(bad)} non-conforming bead template(s). "
            "Contract: skills/beads-standards/reference/bead-create-contract.md"
        )
    else:
        print(f"  {scanned} bead templates scanned, all conformant")
    sys.exit(1 if bad else 0)
