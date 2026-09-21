#!/usr/bin/env python3
"""Minimal pointer digest of the memory substrate (hooks-scopes-grok plan, Phase 5.1).

ASSURANCE-ROLE: utility
CALLER: engine/sync.sh (two `python3 "$AC_ROOT/hooks/build_memory_digest.py"` call sites,
verified 2026-08-27) — deliberately UNWIRED in engine/hooks.wiring.json. It is not a hook; it lives
here because its output feeds the generated global rules file. Declared so orphan detection
(lint Check 21) can tell a real utility from a dead executable.


Emits one markdown line per high-value memory (name + description hook) so a harness
with no hook-injection channel (Grok) starts every session knowing what the substrate
holds and pulls detail via qmd. Called by harness-sync's render_context_grok; output
is embedded in the generated global rules file, so it must be DETERMINISTIC for a
given tree state (write_generated idempotence).

Takes NO arguments (ac-vlje.17). The lanes are the memory side's OWN list — the source
`hooks/memory-retrieval.py` already reads: `MEMORY_HOOK_APPS_LIST`, one app dir per
line, each resolved under `MISSION_ROOT/software/`, with `MISSION_ROOT` itself as the
domain repo (a separate input, not an ordering). Lanes are resolved HERE, so the engine
never learns a layout again; the two sync call sites still pass their old arguments
until ac-vlje.5 switches them, and those arguments are ignored.

No list (absent, unreadable or empty) -> one digest line saying no memory lanes are
configured, exit 0. A missing list is a legitimate adopter state, never an error: the
generated file must still render.

Priority when the cap bites: domain rules > app rules > domain facts/project notes.
Never truncates silently — an overflow line names the count omitted.
"""
import glob
import os
import sys

CAP = 60
DESC_MAX = 220

# The same two knobs `hooks/memory-retrieval.py` reads, so the digest and the recall
# hook cannot disagree about which lanes exist. INFRA_ROOT locates the list; MISSION_ROOT
# is both the domain repo and the parent of the software/ lanes.
INFRA_ROOT = os.environ.get("INFRA_ROOT", os.path.expanduser("~/infrastructure"))
MISSION_ROOT = os.environ.get("MISSION_ROOT", os.path.expanduser("~/mission"))
APPS_LIST = os.environ.get(
    "MEMORY_HOOK_APPS_LIST", os.path.join(INFRA_ROOT, "apps.list")
)


def lane_dirs():
    """Each list entry resolved under MISSION_ROOT/software/, in file order.

    Parsed exactly as memory-retrieval.py's `_app_dir_lobe_pairs()` parses it (strip,
    skip blanks) — one grammar for one source. Absent/unreadable -> [] (the caller
    prints the no-lanes line and exits 0).
    """
    try:
        with open(APPS_LIST, encoding="utf-8") as fh:
            names = [a.strip() for a in fh if a.strip()]
    except OSError:
        return []
    return [os.path.join(MISSION_ROOT, "software", name) for name in names]


def parse_frontmatter(path):
    """name / description / metadata.type from a memory file's frontmatter.
    Naive line parser (no yaml dep): handles single-line values and double-quoted
    descriptions that wrap across lines. Returns {} if no frontmatter."""
    try:
        with open(path, encoding="utf-8", errors="ignore") as fh:
            lines = fh.read().splitlines()
    except OSError:
        return {}
    if not lines or lines[0].strip() != "---":
        return {}
    out = {}
    i = 1
    while i < len(lines) and lines[i].strip() != "---":
        line = lines[i]
        for key in ("name", "description", "type"):
            prefix = key + ":"
            if line.strip().startswith(prefix):
                val = line.strip()[len(prefix):].strip()
                if val.startswith('"') and not (len(val) > 1 and val.endswith('"')):
                    # quoted value wrapping across lines — consume until closing quote
                    while i + 1 < len(lines) and not val.endswith('"'):
                        i += 1
                        val += " " + lines[i].strip()
                out[key] = val.strip('"')
        i += 1
    return out


def _memories(directory):
    """(name, type, description) for every frontmattered memory in one memory/auto dir."""
    for f in sorted(glob.glob(os.path.join(directory, "*.md"))):
        if os.path.basename(f) == "MEMORY.md":
            continue
        fm = parse_frontmatter(f)
        if fm.get("name"):
            yield fm["name"], fm.get("type"), fm.get("description", "")


def collect(domain_repo, target_dirs):
    """Digest the domain repo's memories plus each RESOLVED target's.

    ac-9ahd: this used to take a single `repos_root` and glob a hardcoded domain-repo
    path segment under it. That segment was the Mac monorepo's own repo name and does
    not exist in the three-repo layout, so the digest silently collected NOTHING there —
    and because harness-sync runs under `set -euo pipefail`, an unset root aborted the
    first machine-global render outright. No manifest target could repair it, because the
    defect was a hardcoded path segment rather than a wrong root. `lane_dirs()` now
    resolves the lanes from the memory side's own list and this function assumes no
    layout at all.

    The scope label is likewise DERIVED from the domain repo's own basename — which
    differs per layout — rather than hardcoded to one machine's repo name.
    """
    domain_rules, app_rules, domain_rest = [], [], []
    scope = os.path.basename(os.path.normpath(domain_repo)) or "domain"
    for name, mtype, desc in _memories(os.path.join(domain_repo, "memory", "auto")):
        entry = (name, scope, desc)
        (domain_rules if mtype == "rule" else domain_rest).append(entry)
    for target in sorted(target_dirs):
        app = os.path.basename(os.path.normpath(target))
        for name, mtype, desc in _memories(os.path.join(target, "memory", "auto")):
            if mtype == "rule":
                app_rules.append((name, app, desc))
    return domain_rules, app_rules, domain_rest


def main():
    # No arguments: the lanes are the memory side's own list, resolved here.
    lanes = lane_dirs()
    if not lanes:
        print(f"- *no memory lanes are configured — no apps list at {APPS_LIST}; "
              "point MEMORY_HOOK_APPS_LIST at one (one app dir per line, resolved under "
              f"{MISSION_ROOT}/software)*")
        return
    domain_rules, app_rules, domain_rest = collect(MISSION_ROOT, lanes)
    ordered = domain_rules + app_rules + domain_rest
    shown, omitted = ordered[:CAP], len(ordered) - min(len(ordered), CAP)
    for name, scope, desc in shown:
        desc = " ".join(desc.split())
        if len(desc) > DESC_MAX:
            desc = desc[: DESC_MAX - 1].rstrip() + "…"
        print(f"- **{name}** ({scope}) — {desc}")
    if omitted:
        print(f"- *(+{omitted} more memories not shown — search qmd for anything above plus the rest)*")


if __name__ == "__main__":
    main()
