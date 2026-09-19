"""consumers — the consumer-dir union for the deployed-surface checks (07, 12).

Org-level consumers are discovered from the repos root; app consumers come
from `infrastructure/ac-deploy-targets.list` — the single source of truth
infra-sync.sh uses to propagate the full registry (see AGENTS.md
"Auto-propagation"). Reading it here means a newly added deploy target is
automatically covered with no manual re-stamp of either check. Falls back to
on-disk discovery if the file is unreachable (e.g. a standalone checkout),
so coverage degrades gracefully instead of silently dropping to zero.

vitest-affected is DELIBERATELY kept on the union by explicit append: it carries
a `public` flag in the list (its harness layer is gitignored), and the whole-line
parsing below reproduces the legacy block verbatim — the flagged line yields a
nonexistent dir that is skipped, and the explicit append is what covers it.

LINT_CONSUMER_BASE (default: the derived org root) is a TEST-ONLY seam: the fixture
harnesses point it at a temp consumer tree. Unset in production every path is
identical to the legacy bash block's.
"""

import json
import os

ORG_CONSUMER_SUBPATHS = (
    ".claude",
)

# Covered before the union existed; keep explicit so coverage never regresses.
EXPLICIT_APPS = ("vitest-affected",)


def _repo_root():
    # lint/lib/ -> lint/ -> agent-compounds. Counting is safe HERE: this file's position
    # inside its own repo is a fact the repo controls, unlike the repo's position on a
    # machine.
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.normpath(os.path.join(here, os.pardir, os.pardir))


def base():
    """The org root: the first ancestor of this repo holding an infrastructure/ dir.

    Counting parents was the old answer — "five parents up", assuming
    <org>/<domain>/software/agent-compounds/lint/lib. On a flat layout like
    ~/code/agent-compounds that yields /Users, and checks 07 and 12 then report
    "no consumer dir exists under /Users": a broken derivation wearing the costume
    of an empty machine. Marker, not arithmetic.

    This is the Python twin of engine/org-root.sh — same walk, same `org_root`
    override, and scripts/org-root-derivation.test.sh holds the two in step.
    """
    override = os.environ.get("LINT_CONSUMER_BASE")
    if override:
        return override

    repo = _repo_root()
    layout = os.path.join(repo, "harness.config.json")
    try:
        with open(layout, encoding="utf-8") as fh:
            explicit = json.load(fh).get("org_root")
        if explicit:
            return os.path.expanduser(explicit)
    except (OSError, ValueError):
        pass  # a missing or malformed manifest falls through to the walk

    d = repo
    while d != os.path.dirname(d):
        d = os.path.dirname(d)
        if os.path.isdir(os.path.join(d, "infrastructure")):
            return d
    # No marker anywhere. Returning a guess is what the old code did; return the
    # non-existent-by-construction sentinel instead, so base_present() is False and
    # the callers SKIP with a message naming the real problem.
    return os.path.join(repo, "__no-org-root__")


def base_present():
    """True when the consumer ROOT exists. A bare checkout (CI) has none, so the
    consumer-surface checks (07, 12) have nothing to audit and SKIP green rather
    than NOT-GATE: a not-gated check makes the whole lint run exit 2, and a red
    gate that can never pass is worse than none."""
    return os.path.isdir(base())


def _software_roots(root):
    """`software/` dirs under the org root, whether the domain is a child or the root itself."""
    roots = []
    direct = os.path.join(root, "software")
    if os.path.isdir(direct):
        roots.append(direct)
    try:
        for name in os.listdir(root):
            cand = os.path.join(root, name, "software")
            if os.path.isdir(cand):
                roots.append(cand)
    except OSError:
        pass
    return roots


def _listed_apps(root):
    deploy_list = os.path.join(root, "infrastructure", "ac-deploy-targets.list")
    apps = []
    if os.path.isfile(deploy_list):
        with open(deploy_list, encoding="utf-8") as fh:
            for line in fh:
                line = line.split("#", 1)[0].strip()
                if line:
                    apps.append(line)
    return apps


def consumer_dirs():
    root = base()
    dirs = {os.path.join(root, sub) for sub in ORG_CONSUMER_SUBPATHS}
    sw_roots = _software_roots(root)
    for sw in sw_roots:
        domain = os.path.dirname(sw)
        dirs.add(os.path.join(domain, "content", ".claude"))
        dirs.add(os.path.join(domain, "books", ".claude"))
        dirs.add(os.path.join(sw, ".claude"))
    apps = _listed_apps(root)
    for sw in sw_roots:
        for app in apps:
            dirs.add(os.path.join(sw, app, ".claude"))
        for app in EXPLICIT_APPS:
            dirs.add(os.path.join(sw, app, ".claude"))
    return sorted(dirs)
