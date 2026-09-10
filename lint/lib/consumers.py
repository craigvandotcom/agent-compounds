"""consumers — the consumer-dir union for the deployed-surface checks (07, 12).

Org-level consumers are fixed paths under the repos root; app consumers come
from `infrastructure/ac-deploy-targets.list` — the single source of truth
infra-sync.sh uses to propagate the full registry (see AGENTS.md
"Auto-propagation"). Reading it here means a newly added deploy target is
automatically covered with no manual re-stamp of either check. Falls back to
the last-known app list if the file is unreachable (e.g. a standalone checkout),
so coverage degrades gracefully instead of silently dropping to zero.

vitest-affected is DELIBERATELY kept on the union by explicit append: it carries
a `public` flag in the list (its harness layer is gitignored), and the whole-line
parsing below reproduces the legacy block verbatim — the flagged line yields a
nonexistent dir that is skipped, and the explicit append is what covers it.

LINT_CONSUMER_BASE (default: $HOME/Repos) is a TEST-ONLY seam: the fixture
harnesses point it at a temp consumer tree. Unset in production every path is
identical to the legacy bash block's.
"""

import os

ORG_CONSUMER_SUBPATHS = (
    ".claude",
    "neometa/content/.claude",
    "neometa/books/.claude",
    "neometa/software/.claude",
)

FALLBACK_APPS = (
    "body-compass-app",
    "unsit-app",
    "art-still-app",
    "cv-site",
    "move-free-app",
    "neometa-app",
)

# Covered before the union existed; keep explicit so coverage never regresses.
EXPLICIT_APPS = ("vitest-affected",)


def base():
    return os.environ.get("LINT_CONSUMER_BASE") or os.path.expanduser("~/Repos")


def base_present():
    """True when the consumer ROOT exists. A bare checkout (CI) has none, so the
    consumer-surface checks (07, 12) have nothing to audit and SKIP green rather
    than NOT-GATE: a not-gated check makes the whole lint run exit 2, and a red
    gate that can never pass is worse than none."""
    return os.path.isdir(base())


def consumer_dirs():
    root = base()
    dirs = {os.path.join(root, sub) for sub in ORG_CONSUMER_SUBPATHS}
    deploy_list = os.path.join(root, "infrastructure", "ac-deploy-targets.list")
    apps = []
    if os.path.isfile(deploy_list):
        with open(deploy_list, encoding="utf-8") as fh:
            for line in fh:
                line = line.split("#", 1)[0].strip()
                if line:
                    apps.append(line)
    else:
        apps = list(FALLBACK_APPS)
    dirs.update(os.path.join(root, "neometa", "software", app, ".claude") for app in apps)
    dirs.update(os.path.join(root, "neometa", "software", app, ".claude") for app in EXPLICIT_APPS)
    return sorted(dirs)
