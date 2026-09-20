"""consumers — the consumer-dir union for the deployed-surface checks (07, 12).

Org-level consumers are paths under the repos root; app consumers come from
`infrastructure/ac-deploy-targets.list` — the single source of truth
infra-sync.sh uses to propagate the full registry (see AGENTS.md
"Auto-propagation"). Reading it here means a newly added deploy target is
automatically covered with no manual re-stamp of either check. Falls back to
a glob-discovered app list if the file is unreachable (e.g. a standalone
checkout), so coverage degrades gracefully instead of silently dropping to
zero — see `_fallback_apps()`.

Nothing here spells an org or domain-repo name as a literal: `_domain_name()`
reads this checkout's own real position on disk (this repo sits at
`<org>/<domain>/software/agent-compounds`, so the domain segment is a path
component, not a fact to hardcode), and `_fallback_apps()` reads
`harness.config.json`'s own `targets` glob (already generic — see its `_doc`)
to discover sibling app dirs by walking the filesystem instead of naming them.
A dir this produces that does not exist for a given adopter is silently
skipped downstream (every caller only keeps `isdir()` hits), so guessing a
room/app that does not apply costs nothing.

A roster line is `<app> [public] [packages=a,b]`: the app is the FIRST token, the rest
are flags. A flagged app is walked like any other.

LINT_CONSUMER_BASE (default: the derived org root) is a TEST-ONLY seam: the fixture
harnesses point it at a temp consumer tree. Unset in production every path is
identical to the legacy bash block's.
"""

import glob
import json
import os


def _ac_root():
    """This registry's own root (agent-compounds/) — this file's grandparent.
    Always this checkout's REAL location, never LINT_CONSUMER_BASE: that seam
    relocates where consumer dirs are SEARCHED for (tests/adopters point it at
    an isolated tree), not where this code itself actually lives."""
    return os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def base():
    # Derived, not spelled: this file sits at <org>/<domain>/software/agent-compounds/
    # lint/lib/, so the org root is five parents up — ~/Repos on the Mac monorepo, ~ in
    # the three-repo split. The old hardcoded default named one machine's layout and
    # returned a path that does not exist anywhere else.
    here = os.path.dirname(os.path.abspath(__file__))
    derived = os.path.normpath(os.path.join(here, *([os.pardir] * 5)))
    return os.environ.get("LINT_CONSUMER_BASE") or derived


def _domain_name():
    """The domain-repo directory name this checkout's AC_ROOT sits two levels
    under (mirrors engine/sync.sh's DOMAIN_REPO = AC_ROOT's second parent) —
    whatever an adopter's own layout calls it. A real filesystem fact read off
    this checkout's own path, never a literal org/product name."""
    return os.path.basename(os.path.dirname(os.path.dirname(_ac_root())))


def _org_subpaths():
    """Org-root-relative dirs that may carry their own deployed harness layer:
    the org root's own '.claude', plus '<domain>/<room>/.claude' for this
    checkout's derived domain name across the room convention this factory
    ships (content/books/software — AGENTS.md "Rooms in this repo"). Any of
    these that does not exist for a given adopter is silently skipped by
    every caller."""
    domain = _domain_name()
    return (
        ".claude",
        os.path.join(domain, "content", ".claude"),
        os.path.join(domain, "books", ".claude"),
        os.path.join(domain, "software", ".claude"),
    )


def _fallback_apps():
    """Sibling app names discovered via harness.config.json's own `targets`
    glob (the layout manifest's already-agnostic deploy-target search path —
    see AGENTS.md / engine/sync.sh's resolved_targets()), used only when
    infrastructure/ac-deploy-targets.list is unreachable. Replaces a
    hardcoded app-name tuple: the glob already knows how to find app siblings
    on any layout, so nothing needs spelling here. Never raises — a missing
    or malformed harness.config.json degrades to no fallback apps (still
    safe: every caller skips a dir that does not exist)."""
    cfg_path = os.path.join(_ac_root(), "harness.config.json")
    try:
        with open(cfg_path, encoding="utf-8") as fh:
            cfg = json.load(fh)
    except (OSError, ValueError):
        return ()
    apps = []
    for pattern in cfg.get("targets") or ():
        for d in sorted(glob.glob(os.path.join(_ac_root(), pattern))):
            name = os.path.basename(os.path.normpath(d))
            if name != "agent-compounds" and os.path.isdir(d) and name not in apps:
                apps.append(name)
    return tuple(apps)


def base_present():
    """True when at least one consumer dir actually resolves on disk. This is
    the question the callers (07, 12) need answered — "is there a consumer
    tree to audit" — not "does base() happen to name an existing directory":
    base() derives an ancestor by counting parent hops from this file, and on
    a shallow/unusual clone that ancestor is often just some other directory
    that happens to exist (a home dir, a drive root) even when no consumer
    layer was ever deployed under it. Checking base() alone false-positived,
    which is what made 07/12 exit 2 (NOT-CHECKED) instead of skipping on a
    fresh clone: a bare-existing ancestor let the checks think they had a
    tree to walk, then they found zero actual consumer dirs under it."""
    return any(os.path.isdir(d) for d in consumer_dirs())


def consumer_dirs():
    root = base()
    dirs = {os.path.join(root, sub) for sub in _org_subpaths()}
    deploy_list = os.path.join(root, "infrastructure", "ac-deploy-targets.list")
    apps = []
    if os.path.isfile(deploy_list):
        with open(deploy_list, encoding="utf-8") as fh:
            for line in fh:
                line = line.split("#", 1)[0].strip()
                if line:
                    apps.append(line.split()[0])
    else:
        apps = list(_fallback_apps())
    domain = _domain_name()
    dirs.update(os.path.join(root, domain, "software", app, ".claude") for app in apps)
    return sorted(dirs)
