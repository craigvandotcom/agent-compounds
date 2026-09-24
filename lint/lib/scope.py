"""scope — the ONE scope model for lint v2 checks.

Every check imports its file population from here; none walks the tree itself.
A set here is a frozenset of repo-root-relative PATHS. The walk runs once at
import and every set is derived from that single pass, so the checks cannot
disagree about what exists.

Sets:
  LIVE_TEXT  skill text a human or agent reads as doctrine: SKILL.md files,
             references/ and reference/ and workflows/ trees. Ledger files are
             NEVER live text — they are dated sensor logs, not doctrine.
             .github/ is excluded outright because `_in_dir` matches "workflows"
             as a bare path component, which would otherwise catch
             .github/workflows/*.yml (CI config, not skill doctrine).
  LEDGER     FRICTIONS.md and MAINTENANCE.md — exactly those two filenames,
             anywhere, including under _archive/. The FORMAT docs that teach
             their shape (skill-builder/references/maintenance-ledger.md,
             ac-pipeline/references/run-ledger.md) are LIVE_TEXT, not ledger.
  CORPUS     the trigger corpus (skill-builder/references/trigger-corpus.md).
  HARNESSES  proof-test harnesses (*.test.sh / *.test.py) plus the runner that
             executes them and the workflow that schedules it — the population
             scripts/run-all-proofs.sh + the CI `proofs` job actually run.
  ENGINE     engine/ — the renderer, the stamper and the wiring manifest.
  CHECKS     the lint v2 check files themselves (lint/checks, harnesses excluded).
  TRACKED    every file git tracks — exactly what a clone receives, which is the
             only population that answers "what does the PUBLISHED tree say".
             NOT the walk: the adopter-local artifacts (ledgers, the bead board,
             _archive/) are gitignored yet present on a working machine. Check
             27's surface. Falls back to the walk outside a git checkout.
  COMMITTABLE  tracked plus untracked-not-ignored — what a commit could contain.
             LIVE_TEXT and HARNESSES are cut to it: a gitignored copy of the tree
             (a scratch snapshot) is never doctrine and never a harness.
  SCRIPTS    the runnable scripts the registry ships: .sh and .py files under
              skills/ and scripts/, tests excluded — Check 36's audit surface.

Archived paths (_archive/) and ledger filenames are walked but excluded from
every other set above — an archived or ledger file is never live text, a
harness, or any other classified population.

Excluded from every set: build/interpreter cache dirs, .git, node_modules, and the vendored
harness layers (.claude, .agents, .factory, .codex — symlinks into this repo's
skills; scanning them double-counts every skill file).
"""

import os
import subprocess

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


def _git_files(*args):
    """`git ls-files <args>` as a path set; the walk outside a git checkout, so a
    check run against a fixture root still has a population."""
    try:
        proc = subprocess.run(
            ["git", "--no-optional-locks", "-C", ROOT, "ls-files", "-z", *args],
            capture_output=True, text=True, timeout=60, check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return _paths
    if proc.returncode != 0:
        return _paths  # not a git checkout — a fixture tree or a tarball
    return frozenset(p for p in proc.stdout.split("\0") if p)


TRACKED = _git_files()
COMMITTABLE = _git_files("--cached", "--others", "--exclude-standard")


def _in_dir(path, dirname):
    p = "/" + path
    return ("/" + dirname + "/") in p or p.startswith("/" + dirname + "/")


_live = set()
_ledger = set()
_harnesses = set()
_engine = set()
_scripts = set()
for p in sorted(_paths):
    base = p.rsplit("/", 1)[-1]
    if base in LEDGER_NAMES:
        _ledger.add(p)
        continue
    if p == "_archive" or p.startswith("_archive/"):
        continue
    if p.endswith(".test.sh") or p.endswith(".test.py") or p == "scripts/run-all-proofs.sh":
        _harnesses.add(p)
    if p.startswith(".github/workflows/"):
        _harnesses.add(p)
    # ENGINE — its own surface, because Check 37 asks a question no other scope
    # does: does the engine hardcode a path to canon.
    if p.startswith("engine/"):
        _engine.add(p)
    if (p.startswith("skills/") or p.startswith("scripts/")) \
       and (p.endswith(".sh") or p.endswith(".py")) \
       and not p.endswith(".test.sh") and not p.endswith(".test.py"):
        _scripts.add(p)
    if not p.startswith(".github/") \
       and (base == "SKILL.md" or _in_dir(p, "references") or _in_dir(p, "reference") or _in_dir(p, "workflows")):
        _live.add(p)

LIVE_TEXT = frozenset(_live & COMMITTABLE)
LEDGER = frozenset(_ledger)
HARNESSES = frozenset(_harnesses & COMMITTABLE)
ENGINE = frozenset(_engine)
SCRIPTS = frozenset(_scripts)
CORPUS = frozenset({CORPUS_PATH}) if os.path.isfile(os.path.join(ROOT, CORPUS_PATH)) else frozenset()

CHECKS_DIR = os.path.join(ROOT, "lint", "checks")
CHECKS = frozenset(
    "lint/checks/" + f
    for f in sorted(os.listdir(CHECKS_DIR))
    if os.path.isfile(os.path.join(CHECKS_DIR, f)) and not f.endswith(".test.sh")
    # a leading underscore names a shared helper (e.g. _bootstrap.py), not a
    # check: it carries no header and is never discovered, run or audited as one.
    and not f.startswith("_")
) if os.path.isdir(CHECKS_DIR) else frozenset()


def scan(paths, root=None):
    """Absolute paths for the given repo-relative members of `paths`.

    The one place checks turn a scope set into readable absolute paths.
    """
    base = root or ROOT
    for p in sorted(paths):
        yield os.path.join(base, p)
