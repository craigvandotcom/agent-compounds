#!/usr/bin/env python3
# ---
# id: 03-frontmatter-conformance
# prevents: an unparseable or lying frontmatter block — a prose sentence mis-inserted between name: and description: that both presence greps read as green, a name that does not match its directory, an agent declaring a concrete model instead of a tier, and a tier no harness can stamp
# scope: LIVE_TEXT
# severity: fail
# fixture: lint/fixtures/03-frontmatter-conformance
# ---
"""03-frontmatter-conformance — frontmatter that parses, matches, and stamps.

Three populations, the legacy lint.sh Check 3 block's exact legs:

  skills/*/SKILL.md
    name: == directory name; description: non-empty; and BLOCK INTEGRITY —
    the block opens with `---` on line 1, closes at the next `---`, and every
    non-blank line between is a YAML mapping entry whose key is in the
    allowlist (name description accessory tools disable-model-invocation) or
    an indented continuation BELOW a mapping entry. Key COUNT and IDENTITY
    are deliberately not constrained. The allowlist (not a shape regex) is
    what fails `todo: fix this` closed; a genuinely new key is added HERE, in
    the commit that introduces it.
  agents/*.md and agents/review/*.md
    name: == filename (sans .md); tier: present and in
    {orchestrator, coordinator, worker}; `model:` forbidden (tier is the
    canon — models are stamped per harness by the generators).
  harnesses.json
    harnesses.claude.agent_models.<tier> and harnesses.opencode.agent_models.<tier>
    present for every valid tier, so deploy.sh fails loud at lint time instead
    of sync time.

Exit: 0 every leg holds and something was scanned, 1 findings, 2 nothing
scanned (NOT-GATED, never a pass). The judge here is this file's own
implementation of the legacy block's legs — line-based, not lib.frontmatter —
so the verdict cannot drift from what the bash block used to flag.
"""

import json
import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_LINT = os.path.dirname(_HERE)
sys.path.insert(0, _LINT)

from lib import scope  # noqa: E402

CHECK_ID = "03-frontmatter-conformance"
FM_ALLOWED_KEYS = ("name", "description", "accessory", "tools", "disable-model-invocation")
VALID_TIERS = ("orchestrator", "coordinator", "worker")

findings = []


def fail(msg):
    findings.append(msg)


def frontmatter_lines(path):
    """The raw frontmatter block lines (between the --- fences), or None."""
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            lines = fh.read().split("\n")
    except OSError:
        return None
    if not lines or lines[0] != "---":
        return None
    block = []
    for ln in lines[1:]:
        if ln == "---":
            return block
        block.append(ln)
    return None


def check_skill(rel, path):
    name = os.path.basename(os.path.dirname(path))
    with open(path, encoding="utf-8", errors="replace") as fh:
        text = fh.read()
    lines = text.split("\n")
    name_val = next((l[len("name:"):].strip() for l in lines if l.startswith("name:")), "")
    if name_val != name:
        fail(f"{rel}: name '{name_val}' != dir name '{name}'")
    desc_val = next((l[len("description:"):].strip() for l in lines if l.startswith("description:")), "")
    if not desc_val:
        fail(f"{rel}: description is empty or missing")

    if os.path.islink(path):
        fail(f"{rel}: frontmatter block integrity — SKILL.md is a symlink — must be a regular file")
        return
    if not lines or lines[0] != "---":
        fail(f"{rel}: frontmatter block integrity — line 1 is not '---' — no frontmatter block")
        return
    err = ""
    closed = False
    seen_key = False
    for lineno, line in enumerate(lines[1:], start=2):
        if line == "---":
            closed = True
            break
        if not line.strip():
            continue
        if line[0] in " \t":
            if not seen_key:
                err = f"line {lineno} is indented with no mapping entry above it: {line[:80]}"
                break
            continue
        if ":" not in line:
            err = f"line {lineno} is not a YAML mapping entry: {line[:80]}"
            break
        key = line.split(":", 1)[0]
        if key in FM_ALLOWED_KEYS:
            seen_key = True
        else:
            err = (f"line {lineno} is not a known frontmatter key "
                   f"(allowed: {' '.join(FM_ALLOWED_KEYS)}): {line[:80]}")
            break
    if not err and not closed:
        err = "frontmatter block opened at line 1 is never closed by a '---'"
    if err:
        fail(f"{rel}: frontmatter block integrity — {err}")


def check_agent(rel, path):
    name = os.path.basename(path)[:-3]
    with open(path, encoding="utf-8", errors="replace") as fh:
        lines = fh.read().split("\n")
    name_val = next((l[len("name:"):].strip() for l in lines if l.startswith("name:")), "")
    if name_val != name:
        fail(f"{rel}: name '{name_val}' != filename '{name}'")
    tier_val = next((l[len("tier:"):].strip() for l in lines if l.startswith("tier:")), "")
    if not tier_val:
        fail(f"{rel}: no 'tier:' — every registry agent must declare one")
    elif tier_val not in VALID_TIERS:
        fail(f"{rel}: tier '{tier_val}' not in {{orchestrator coordinator worker}}")
    if any(l.startswith("model:") for l in lines):
        fail(f"{rel}: 'model:' is forbidden in the registry — declare 'tier:' and let harnesses.json agent_models resolve it per harness")


def check_harness_tiers(root):
    hj = os.path.join(root, "harnesses.json")
    try:
        with open(hj, encoding="utf-8") as fh:
            harnesses = json.load(fh).get("harnesses", {})
    except (OSError, ValueError):
        fail("harnesses.json: missing or unreadable — tier maps cannot be verified")
        return
    for h in ("claude", "opencode"):
        models = (harnesses.get(h) or {}).get("agent_models") or {}
        for t in VALID_TIERS:
            if not models.get(t):
                fail(f"harnesses.json: harnesses.{h}.agent_models.{t} missing (tier maps must be complete per harness)")


def main():
    import argparse

    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("root", nargs="?", default=None,
                    help="repo root to lint (default: this checkout)")
    args = ap.parse_args()
    root = args.root or scope.ROOT
    scanned = 0
    skills_dir = os.path.join(root, "skills")
    if os.path.isdir(skills_dir):
        for d in sorted(os.listdir(skills_dir)):
            p = os.path.join(skills_dir, d, "SKILL.md")
            if os.path.isfile(p):
                scanned += 1
                check_skill(f"skills/{d}/SKILL.md", p)
    for sub in ("", os.path.join("review")):
        agents_dir = os.path.join(root, "agents", sub) if sub else os.path.join(root, "agents")
        if os.path.isdir(agents_dir):
            for fn in sorted(os.listdir(agents_dir)):
                p = os.path.join(agents_dir, fn)
                if fn.endswith(".md") and os.path.isfile(p):
                    scanned += 1
                    check_agent(f"agents/{fn}" if not sub else f"agents/{sub}/{fn}", p)
    if os.path.isfile(os.path.join(root, "harnesses.json")) or os.path.isdir(skills_dir):
        scanned += 1
        check_harness_tiers(root)

    if scanned == 0:
        print(f"{CHECK_ID} NOT-CHECKED: no skills, agents or harnesses.json under {root} — verified nothing", file=sys.stderr)
        return 2
    for f in findings:
        print(f"FAIL {CHECK_ID}: {f}")
    if findings:
        return 1
    print(f"  ok: {CHECK_ID} — {scanned} frontmatter surface(s) conform")
    return 0


if __name__ == "__main__":
    sys.exit(main())
