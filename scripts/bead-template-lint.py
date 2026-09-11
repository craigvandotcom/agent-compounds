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
# qa-shared's `origin:<ac-qa>`. That is the template doing its
# job. The RUNTIME guard is deliberately stricter and rejects the same placeholder, because
# by then it must have been substituted. Same contract, different moment.
TEMPLATE_ORIGIN = re.compile(r"^origin:(<[^>]+>|[A-Za-z0-9][A-Za-z0-9._-]*)$")

# The catch-stage CLOSED set (beads-standards § Catch-stage vocabulary — never mint a
# new token). A finding-bead template — one whose labels carry the `triage` marker but
# NOT the `ops` escalation marker — must file its escape with exactly one of these, so
# the escape-attribution corpus is built by contract, not by downstream accident.
CATCH_STAGE = ("qa-finding", "review-finding", "hygiene-finding", "ci-finding", "prod-finding")


def has_catch_stage(cmd):
    return any(l in CATCH_STAGE for l in guard.all_labels(cmd))


def is_finding_template(cmd):
    """True for a template that files a FINDING bead — a defect-shaped bead (bug /
    investigation) carrying the triage source marker. The ops/escalation template carries
    `triage,ops` too but files a pipeline-ops task, not a finding, so it is excluded by
    the `ops` token; the feature-fork template files `-t decision`, not a finding, so it
    is excluded by type. Under-enforcing on an unsubstituted `-t <type>` placeholder is
    correct — the same doctrine as bead_type: it could stand for anything, and the
    runtime guard + ac-align's nightly reconcile cover the substitution moment."""
    labels = guard.all_labels(cmd)
    if "triage" not in labels or "ops" in labels:
        return False
    typ = guard.bead_type(cmd)
    return typ in ("bug", "investigation")


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
    with open(path, encoding="utf-8") as fh:
        lines = fh.read().split("\n")
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
            # a quoted argument may itself span lines (a multi-line --description
            # with embedded ## sections). shlex cannot parse an unbalanced quote,
            # and skipping the block would silently un-scan the template — the
            # ac-triage Phase-3a finding template was invisible to this lint for
            # exactly that reason. Keep joining until the quotes balance.
            while block.count('"') % 2 == 1 and j + 1 < len(lines):
                j += 1
                block = block + "\n" + lines[j]
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
                    continue
                if is_finding_template(cmd) and not has_catch_stage(cmd):
                    out.append((rel, line_no, "finding template with no catch-stage label"))
    return out, scanned


# --- probe-shape check (ac-attt) --------------------------------------------------
#
# `no probe, no bead` (ac-beadify) only asks that a `Probe:` line exist and run without
# a syntax error — it says nothing about whether the probe can actually MEASURE the AC.
# Three shapes pass that bar and still lie, all measured on live swarms:
#   1. `pnpm <script> -- <file>` — pnpm forwards the literal `--` to the script, so a
#      bare test-runner script sees `-- <file>` as ITS OWN args and runs its default
#      (whole-suite) target; unrelated reds make the probe unwinnable (bd-yfv1j, bd-9y8ii).
#   2. a bare `pnpm vitest run <file>` / `npx vitest run <file>` — the vitest-affected
#      plugin can silently drop the named file on a busy trunk (bd-1khmb, bd-wzzds,
#      bd-9yjcl). `VITEST_AFFECTED_DISABLED=1` or an explicit `--config` (the local
#      integration lane) makes the run reliable; `pnpm test:one <file>` is the reliable
#      single-file unit form and never matches this shape.
#   3. `grep -c` read as pass/fail — it exits 1 when the count is 0, so a probe built on
#      "returns 0" reads green in the unfixed state (bd-3gkp2). `grep -q` / `! grep -q`
#      do not have this failure mode.
PROBE_LINE = re.compile(r"Probe:\s*`([^`]*)`")
VITEST_RUN = re.compile(r"\b(pnpm|npx)\s+vitest\s+run\b")
# Regex, not shlex: `grep -c` reads as pass/fail just as often INSIDE a substitution
# (`[ "$(grep -c foo file)" -eq 0 ]`) as bare — shlex collapses the quoted `$(...)` into
# one opaque token and never sees the inner `grep`, so a token walk misses exactly the
# shape the bead this check ships for (bd-3gkp2) was built from.
GREP_C = re.compile(r"\bgrep\b(?:\s+-[A-Za-z]+\b)*\s+(-[A-Za-z]*c[A-Za-z]*\b|--count\b)")


def probes(path):
    """Yield (line_no, command) for each `Probe: `<command>`` occurrence in a markdown
    file — the same span bead-schema.md's canonical extractor lifts
    (`grep -o 'Probe: \\`[^\\`]*\\`'`), read here per-line so a finding names its source."""
    with open(path, encoding="utf-8") as fh:
        lines = fh.read().split("\n")
    for i, line in enumerate(lines):
        m = PROBE_LINE.search(line)
        if m:
            yield i + 1, m.group(1)


def _tokens(cmd):
    try:
        return shlex.split(cmd, comments=False, posix=True)
    except ValueError:
        return cmd.split()  # unparseable prose/placeholder — best-effort, never crash


def has_pnpm_passthrough(cmd):
    """`pnpm <script> -- <file>` — a bare `--` token anywhere after a `pnpm` token means
    pnpm forwards it (and everything after) to the script verbatim, so this probe does
    not scope to `<file>` the way it appears to."""
    toks = _tokens(cmd)
    seen_pnpm = False
    for tok in toks:
        if tok.rsplit("/", 1)[-1] == "pnpm":
            seen_pnpm = True
        elif seen_pnpm and tok == "--":
            return True
    return False


def is_bare_affected_vitest(cmd):
    """A bare `pnpm|npx vitest run <file>` with neither the affected-plugin disable env
    var nor an explicit `--config` (the integration lane) can silently drop the named
    file under vitest-affected. `pnpm test:one <file>` never matches `VITEST_RUN`."""
    if not VITEST_RUN.search(cmd):
        return False
    if "VITEST_AFFECTED_DISABLED=1" in cmd:
        return False
    if "--config" in cmd:
        return False
    return True


def has_grepc_probe(cmd):
    """`grep -c`/`--count` in command position — the exit-code failure mode. `grep -q`
    and `! grep -q` carry no `c` in their flags and never match."""
    return bool(GREP_C.search(cmd))


def probe_shape_violations():
    """Returns (violations, probes_scanned) for the three lying probe shapes above,
    scanned across the same registry the template check covers. Same doctrine as
    `violations()`: an unscanned corpus must never read as a clean pass."""
    out = []
    scanned = 0
    for path in sorted(glob.glob(os.path.join(ROOT, "skills", "**", "*.md"), recursive=True)):
        rel = os.path.relpath(path, ROOT)
        for line_no, cmd in probes(path):
            scanned += 1
            if has_pnpm_passthrough(cmd):
                out.append((rel, line_no,
                    "probe uses `pnpm <script> -- <file>` — pnpm forwards the literal "
                    "`--`, so this does not scope to <file>; use `pnpm test:one <file>`"))
            elif is_bare_affected_vitest(cmd):
                out.append((rel, line_no,
                    "probe uses a bare vitest run that vitest-affected can silently drop "
                    "— set VITEST_AFFECTED_DISABLED=1, add --config <integration config>, "
                    "or use `pnpm test:one <file>`"))
            elif has_grepc_probe(cmd):
                out.append((rel, line_no,
                    "probe uses `grep -c` as a pass/fail check — exits 1 on a zero count; "
                    "use `grep -q` / `! grep -q`"))
    return out, scanned


if __name__ == "__main__":
    bad, scanned = violations()
    shape_bad, shape_scanned = probe_shape_violations()
    if scanned < 20:
        print(f"  VACUOUS: only {scanned} bead templates found under skills/ — the "
              "detector is broken, not the registry. A pass here would be a false green.")
        sys.exit(1)
    bad = bad + shape_bad
    # The probe-shape floor guards against a false GREEN only — a genuine template
    # finding above must still be reported and failed on its own terms, never masked
    # behind a "the other detector found nothing" message.
    if not bad and shape_scanned < 5:
        print(f"  VACUOUS: only {shape_scanned} Probe: line(s) found under skills/ — the "
              "probe-shape detector is broken, not the registry. A pass here would be a false green.")
        sys.exit(1)
    for rel, line_no, why in bad:
        print(f"  {rel}:{line_no} — {why}")
    if bad:
        print(
            f"\n{len(bad)} non-conforming bead template(s). "
            "Contract: skills/beads-standards/reference/bead-create-contract.md"
        )
    else:
        print(f"  {scanned} bead templates scanned, all conformant; "
              f"{shape_scanned} probe(s) shape-checked, all sound")
    sys.exit(1 if bad else 0)
