#!/usr/bin/env python3
"""Minimal pointer digest of the memory substrate (hooks-scopes-grok plan, Phase 5.1).

ASSURANCE-ROLE: utility
CALLER: harness-sync.sh (two `python3 "$AC_ROOT/hooks/build_memory_digest.py"` call sites,
verified 2026-08-27) — deliberately UNWIRED in hooks/hooks.json. It is not a hook; it lives
here because its output feeds the generated global rules file. Declared so orphan detection
(lint Check 21) can tell a real utility from a dead executable.


Emits one markdown line per high-value memory (name + description hook) so a harness
with no hook-injection channel (Grok) starts every session knowing what the substrate
holds and pulls detail via qmd. Called by harness-sync's render_context_grok; output
is embedded in the generated global rules file, so it must be DETERMINISTIC for a
given tree state (write_generated idempotence).

Priority when the cap bites: domain rules > app rules > domain facts/project notes.
Never truncates silently — an overflow line names the count omitted.
"""
import glob
import os
import sys

CAP = 60
DESC_MAX = 220


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
    defect was a hardcoded path segment rather than a wrong root. So the caller now
    resolves the directories and passes them in; this function assumes no layout at all.

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
    # argv: <domain-repo-dir> [<resolved-target-dir> ...] — the caller resolves layout.
    if len(sys.argv) < 2:
        sys.exit("usage: build_memory_digest.py <domain-repo-dir> [<target-dir> ...]")
    domain_repo, target_dirs = sys.argv[1], sys.argv[2:]
    domain_rules, app_rules, domain_rest = collect(domain_repo, target_dirs)
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
