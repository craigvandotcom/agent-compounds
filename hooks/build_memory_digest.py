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


def collect(repos_root):
    domain_rules, app_rules, domain_rest = [], [], []
    domain_dir = os.path.join(repos_root, "neometa", "memory", "auto")
    for f in sorted(glob.glob(os.path.join(domain_dir, "*.md"))):
        if os.path.basename(f) == "MEMORY.md":
            continue
        fm = parse_frontmatter(f)
        if not fm.get("name"):
            continue
        entry = (fm["name"], "neometa", fm.get("description", ""))
        (domain_rules if fm.get("type") == "rule" else domain_rest).append(entry)
    for d in sorted(glob.glob(os.path.join(repos_root, "neometa", "software", "*", "memory", "auto"))):
        app = d.split(os.sep)[-3]
        for f in sorted(glob.glob(os.path.join(d, "*.md"))):
            if os.path.basename(f) == "MEMORY.md":
                continue
            fm = parse_frontmatter(f)
            if fm.get("name") and fm.get("type") == "rule":
                app_rules.append((fm["name"], app, fm.get("description", "")))
    return domain_rules, app_rules, domain_rest


def main():
    repos_root = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/Repos")
    domain_rules, app_rules, domain_rest = collect(repos_root)
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
