"""scope — the ONE scope model for lint v2 checks.

Every check imports its file population from here; none walks the tree itself.
A set here is a frozenset of repo-root-relative PATHS. The walk runs once at
import and every set is derived from that single pass, so the checks cannot
disagree about what exists.

Sets:
  LIVE_TEXT  skill text a human or agent reads as doctrine: SKILL.md files,
             references/ and reference/ and workflows/ trees. Ledger files are
             NEVER live text — they are dated sensor logs, not doctrine.
  LEDGER     FRICTIONS.md and MAINTENANCE.md — exactly those two filenames,
             anywhere, including under _archive/. The FORMAT docs that teach
             their shape (skill-builder/references/maintenance-ledger.md,
             ac-pipeline/references/run-ledger.md) are LIVE_TEXT, not ledger.
  CORPUS     the trigger corpus (skill-builder/references/trigger-corpus.md).
  ARCHIVE    everything under _archive/.
  HARNESSES  proof-test harnesses (*.test.sh / *.test.py) plus the runner that
             executes them and the workflow that schedules it — Check 20's
             audit surface.
  HOOKS      hooks/hooks.json, the hooks/ executables it wires, and the bead
              board its PENDING-DECISION escapes resolve against — Check 21's
              audit surface.
  TEMPLATES  the templates/ the registry ships plus scripts/
              bead-template-lint.py, the one judge over them — Check 19's
              audit surface.
  CHECKS     the lint v2 check files themselves (lint/checks, harnesses excluded).
  CACHES     directory names that are build/interpreter caches — excluded from
             every walk.

Excluded from every set: CACHES dirs, .git, node_modules, and the vendored
harness layers (.claude, .agents, .factory, .codex — symlinks into this repo's
skills; scanning them double-counts every skill file).
"""

import os

ROOT = os.environ.get("LINT_ROOT") or os.path.dirname(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
)

SKIP_DIRS = frozenset({
    ".git", "node_modules", ".ruff_cache", "__pycache__",
    ".claude", ".agents", ".factory", ".codex",
})
LEDGER_NAMES = ("FRICTIONS.md", "MAINTENANCE.md")
CORPUS_PATH = "skills/skill-builder/references/trigger-corpus.md"


def _walk():
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        rel = os.path.relpath(dirpath, ROOT)
        prefix = "" if rel == "." else rel.replace(os.sep, "/") + "/"
        for fn in filenames:
            yield prefix + fn


_paths = frozenset(_walk())


def _in_dir(path, dirname):
    p = "/" + path
    return ("/" + dirname + "/") in p or p.startswith("/" + dirname + "/")


_live = set()
_ledger = set()
_archive = set()
_harnesses = set()
_hooks = set()
_templates = set()
for p in sorted(_paths):
    base = p.rsplit("/", 1)[-1]
    if base in LEDGER_NAMES:
        _ledger.add(p)
        continue
    if p == "_archive" or p.startswith("_archive/"):
        _archive.add(p)
        continue
    if p.endswith(".test.sh") or p.endswith(".test.py") or p == "scripts/run-all-harnesses.sh":
        _harnesses.add(p)
    if p.startswith(".github/workflows/"):
        _harnesses.add(p)
    if p.startswith("hooks/") or p == ".beads/issues.jsonl":
        _hooks.add(p)
    if p.startswith("templates/") or p == "scripts/bead-template-lint.py":
        _templates.add(p)
    if base == "SKILL.md" or _in_dir(p, "references") or _in_dir(p, "reference") or _in_dir(p, "workflows"):
        _live.add(p)

LIVE_TEXT = frozenset(_live)
LEDGER = frozenset(_ledger)
ARCHIVE = frozenset(_archive)
HARNESSES = frozenset(_harnesses)
HOOKS = frozenset(_hooks)
TEMPLATES = frozenset(_templates)
CORPUS = frozenset({CORPUS_PATH}) if os.path.isfile(os.path.join(ROOT, CORPUS_PATH)) else frozenset()

CHECKS_DIR = os.path.join(ROOT, "lint", "checks")
CHECKS = frozenset(
    "lint/checks/" + f
    for f in sorted(os.listdir(CHECKS_DIR))
    if os.path.isfile(os.path.join(CHECKS_DIR, f)) and not f.endswith(".test.sh")
) if os.path.isdir(CHECKS_DIR) else frozenset()

CACHES = frozenset({d for d in SKIP_DIRS if d not in (".git",)})


def scan(paths, root=None):
    """Absolute paths for the given repo-relative members of `paths`.

    The one place checks turn a scope set into readable absolute paths.
    """
    base = root or ROOT
    for p in sorted(paths):
        yield os.path.join(base, p)
