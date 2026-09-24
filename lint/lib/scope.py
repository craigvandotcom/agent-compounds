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
  ARCHIVE    everything under _archive/.
  HARNESSES  proof-test harnesses (*.test.sh / *.test.py) plus the runner that
             executes them and the workflow that schedules it — the population
             scripts/run-all-proofs.sh + the CI `proofs` job actually run.
  ENGINE     engine/ — the renderer, the stamper and the wiring manifest.
  HOOKS      engine/hooks.wiring.json, the hooks/ executables it wires, and the bead
              board its PENDING-DECISION escapes resolve against — Check 21's
              audit surface.
  TEMPLATES  the templates/ the registry ships plus check 19, the one judge over
              them — Check 19's audit surface.
  CHECKS     the lint v2 check files themselves (lint/checks, harnesses excluded).
  ALL        every walked path — the trigger for a check that reads cross-cutting
             repo state (the git log, the board) rather than a file population, so
             any change must run it. A check scoped to a narrower set instead ran
             only when a file in that set changed, leaving cross-cutting drift
             unpoliced until CI.
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
  CACHES     directory names that are build/interpreter caches — excluded from
              every walk.
  README             the root README.md — Check 04's audit surface. Named in
                      04's header (`scope: LIVE_TEXT README`).
  AGENT_STANCES      agents/*.md, the 5 core stance files — the surface Checks
                      03 (tier vs concrete model), 25 (retired alias names)
                      and 28-citations (named stances resolve) name as their subject.
                      Named in each of those checks' headers — a header can
                      list several set names separated by whitespace/commas
                      (see the composite-alias note below).
  DEPLOY_SCRIPT      engine/deploy.sh alone — Check 08's actual subject (narrower
                      than LIVE_TEXT). Named in 08's header alongside LIVE_TEXT.
  HARNESS_MANIFEST   the root harnesses.json (per-harness agent-model/deploy
                      manifest) — distinct from HARNESSES (proof-test files)
                      above. Named in 03's header (it reads harnesses.json too).
  LINT_CONFIG        skills/packages.json (`_lint` section) — read at runtime
                       by several checks (14, 15, 25), any of
                       which its thresholds can change. Not wired into any
                       check's `scope:` header, and not read by run.py —
                       a config-file change is covered for free since every
                       run means the whole suite.

Multi-name scope headers: a check's `# scope:` line may name more than one
set (`LIVE_TEXT AGENT_STANCES HARNESS_MANIFEST`); 00-meta.py's header
validator does one literal `getattr(scope, header["scope"])`, so a small set
of composite aliases is registered below under the exact literal strings the
checks declare — purely so that simpler, single-name validator does not choke
on a multi-word value. `scope:` is otherwise inert: every check runs on every
invocation, so these aliases exist only to keep 00-meta's header contract
satisfied, never to drive selection.

Excluded from every set: CACHES dirs, .git, node_modules, and the vendored
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
_archive = set()
_harnesses = set()
_hooks = set()
_engine = set()
_templates = set()
_scripts = set()
_agent_stances = set()
for p in sorted(_paths):
    base = p.rsplit("/", 1)[-1]
    if p.startswith("agents/") and p.endswith(".md"):
        _agent_stances.add(p)
    if base in LEDGER_NAMES:
        _ledger.add(p)
        continue
    if p == "_archive" or p.startswith("_archive/"):
        _archive.add(p)
        continue
    if p.endswith(".test.sh") or p.endswith(".test.py") or p == "scripts/run-all-proofs.sh":
        _harnesses.add(p)
    if p.startswith(".github/workflows/"):
        _harnesses.add(p)
    # engine/hooks.wiring.json is the wiring manifest — still the HOOKS surface
    # despite living outside hooks/, so name it beside the prefix rule.
    if p.startswith("hooks/") or p == ".beads/issues.jsonl" or p == "engine/hooks.wiring.json":
        _hooks.add(p)
    # ENGINE — its own surface, because Check 37 asks a question no other scope
    # does: does the engine hardcode a path to canon.
    if p.startswith("engine/"):
        _engine.add(p)
    if p.startswith("templates/") or p == "lint/checks/19-bead-template-conformance.py":
        _templates.add(p)
    if (p.startswith("skills/") or p.startswith("scripts/")) \
       and (p.endswith(".sh") or p.endswith(".py")) \
       and not p.endswith(".test.sh") and not p.endswith(".test.py"):
        _scripts.add(p)
    if not p.startswith(".github/") \
       and (base == "SKILL.md" or _in_dir(p, "references") or _in_dir(p, "reference") or _in_dir(p, "workflows")):
        _live.add(p)

LIVE_TEXT = frozenset(_live & COMMITTABLE)
LEDGER = frozenset(_ledger)
ARCHIVE = frozenset(_archive)
HARNESSES = frozenset(_harnesses & COMMITTABLE)
HOOKS = frozenset(_hooks)
ENGINE = frozenset(_engine)
TEMPLATES = frozenset(_templates)
SCRIPTS = frozenset(_scripts)
AGENT_STANCES = frozenset(_agent_stances)
CORPUS = frozenset({CORPUS_PATH}) if os.path.isfile(os.path.join(ROOT, CORPUS_PATH)) else frozenset()


def _one(rel):
    return frozenset({rel}) if os.path.isfile(os.path.join(ROOT, rel)) else frozenset()


README = _one("README.md")
DEPLOY_SCRIPT = _one("engine/deploy.sh")
HARNESS_MANIFEST = _one("harnesses.json")
LINT_CONFIG = _one("skills/packages.json")

# --- composite scope aliases -------------------------------------------------
# 00-meta.py's header-contract validator does one literal `getattr(scope,
# header["scope"])`; it has no notion of a `scope:` line naming several sets.
# These aliases exist solely so 00-meta's simpler, single-name check does not
# choke on the exact multi-word `scope:` values check headers carry — nothing
# else reads them: `scope:` no longer drives which checks run.
_COMPOSITE_SCOPES = {
    "LIVE_TEXT AGENT_STANCES HARNESS_MANIFEST": LIVE_TEXT | AGENT_STANCES | HARNESS_MANIFEST,
    "LIVE_TEXT README": LIVE_TEXT | README,
    "LIVE_TEXT DEPLOY_SCRIPT": LIVE_TEXT | DEPLOY_SCRIPT,
    "LIVE_TEXT AGENT_STANCES": LIVE_TEXT | AGENT_STANCES,
    "LIVE_TEXT AGENT_STANCES HOOKS": LIVE_TEXT | AGENT_STANCES | HOOKS,
}
globals().update(_COMPOSITE_SCOPES)

CHECKS_DIR = os.path.join(ROOT, "lint", "checks")
CHECKS = frozenset(
    "lint/checks/" + f
    for f in sorted(os.listdir(CHECKS_DIR))
    if os.path.isfile(os.path.join(CHECKS_DIR, f)) and not f.endswith(".test.sh")
    # a leading underscore names a shared helper (e.g. _bootstrap.py), not a
    # check: it carries no header and is never discovered, run or audited as one.
    and not f.startswith("_")
) if os.path.isdir(CHECKS_DIR) else frozenset()

CACHES = frozenset({d for d in SKIP_DIRS if d not in (".git",)})

# Every walked path. A check whose subject is repo state rather than a file
# population declares this — kept only for 00-meta.py's header contract, since
# there is no scope-to-diff selection any header value could otherwise drive.
ALL = frozenset(_paths)


def scan(paths, root=None):
    """Absolute paths for the given repo-relative members of `paths`.

    The one place checks turn a scope set into readable absolute paths.
    """
    base = root or ROOT
    for p in sorted(paths):
        yield os.path.join(base, p)
