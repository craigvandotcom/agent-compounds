#!/usr/bin/env python3
# ---
# id: 31-orphan-references
# prevents: a references/, reference/ or workflows/ file nothing in the registry points at — dead
#   weight the loaded-path budget still counts when it is unconditional, and a copy that drifts with
#   no reader to notice (nothing enumerated the reference tree against its readers before)
# scope: LIVE_TEXT
# severity: fail
# fixture: lint/fixtures/31-orphan-references
# ---
"""31-orphan-references — reference files with no pointer in the registry (ac-1p7j.5).

A file under any skill's references/, reference/ or workflows/ tree is governed
(the LIVE_TEXT members that are not SKILL.md). It is an ORPHAN when no file in
the pointer corpus cites it, by either form:

  full    skills/<skill>/<sub>/<file>          repo-relative, as 28 resolves
  scoped  <sub>/<file>                         e.g. references/foo.md — counted
                                               from any corpus file: ambiguous
                                               mentions resolve to EXISTS, so the
                                               check never flags on a guess

The pointer corpus is LIVE_TEXT + agents/*.md + README.md — the registry's read
surface. Tooling (lint.sh, the checks) deliberately does NOT keep a reference
alive: a file only lint knows about is still dead weight for every reader.

The allowlist lint/allowlists/31-orphan-references.txt is DATED and SHRINK-ONLY,
same contract as 25:
  - every entry must still be an orphan; a file that gained a reader has its
    entry REMOVED in the same change;
  - growth is refused against the committed base (merge-base of config
    base_ref and HEAD, falling back to HEAD^) — the first landing has no
    committed version at base, that IS the seed, and the ratchet starts the
    moment one exists.

Exit: 0 clean, 1 orphans, 2 scanned nothing (NOT-GATED, never a pass).
"""

import json
import os
import subprocess
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_LINT = os.path.dirname(_HERE)
sys.path.insert(0, _LINT)

from lib import scope  # noqa: E402

ALLOWLIST = "lint/allowlists/31-orphan-references.txt"
DEFAULT_BASE_REF = "origin/main"

violations = []
notes = []


def is_candidate(rel):
    # skills/ only: scope.py's dir-name match also sweeps .github/workflows,
    # which is CI config, not registry reference weight.
    if not rel.startswith("skills/") or rel.endswith("SKILL.md"):
        return False
    for sub in ("references/", "reference/", "workflows/"):
        if "/" + sub in "/" + rel:
            return True
    return False


def pointer_corpus(root):
    paths = set(scope.LIVE_TEXT)
    agents = os.path.join(root, "agents")
    if os.path.isdir(agents):
        for fn in os.listdir(agents):
            if fn.endswith(".md"):
                paths.add("agents/" + fn)
    if os.path.isfile(os.path.join(root, "README.md")):
        paths.add("README.md")
    return sorted(paths)


def texts(root, paths):
    out = {}
    for rel in paths:
        p = os.path.join(root, rel)
        try:
            with open(p, encoding="utf-8", errors="replace") as fh:
                out[rel] = fh.read()
        except OSError:
            continue
    return out


def git(root, *args):
    proc = subprocess.run(
        ["git", "--no-optional-locks", "-C", root, *args],
        capture_output=True, text=True, timeout=60,
    )
    return proc.stdout.strip()


def ratchet_base(root):
    ref = DEFAULT_BASE_REF
    cfg = os.path.join(root, "lint", "config.json")
    if os.path.isfile(cfg):
        try:
            with open(cfg, encoding="utf-8") as fh:
                ref = json.load(fh).get("base_ref", DEFAULT_BASE_REF)
        except (OSError, ValueError):
            ref = DEFAULT_BASE_REF
    if git(root, "rev-parse", "--verify", "--quiet", ref):
        b = git(root, "merge-base", ref, "HEAD")
        if b:
            return b
    head = git(root, "rev-parse", "--verify", "--quiet", "HEAD")
    if head and git(root, "rev-parse", "--verify", "--quiet", "HEAD^"):
        return git(root, "rev-parse", "HEAD^")
    return ""


def committed_entries(root, base):
    proc = subprocess.run(
        ["git", "--no-optional-locks", "-C", root, "show", f"{base}:{ALLOWLIST}"],
        capture_output=True, text=True, timeout=60,
    )
    if proc.returncode != 0:
        return None
    return [line.strip() for line in proc.stdout.splitlines()
            if line.strip() and not line.startswith("#")]


def load_allowlist(path):
    entries = []
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if line and not line.startswith("#"):
                entries.append(line)
    return entries


def scan(root):
    corpus_paths = pointer_corpus(root)
    if not corpus_paths:
        print("31-orphan-references NOT-CHECKED: no pointer corpus under this root — nothing scanned")
        return 2
    texts_by_rel = texts(root, corpus_paths)

    candidates = sorted(p for p in scope.LIVE_TEXT if is_candidate(p))
    if not candidates:
        print("31-orphan-references NOT-CHECKED: no references/, reference/ or workflows/ file under "
              "this root — nothing scanned")
        return 2

    orphans = []
    for cand in candidates:
        sub = cand.split("/")[-2]
        fn = cand.rsplit("/", 1)[-1]
        full = cand
        scoped = f"{sub}/{fn}"
        pointed = False
        for rel, text in texts_by_rel.items():
            if rel == cand:
                continue
            if full in text or scoped in text:
                pointed = True
                break
        if not pointed:
            orphans.append(cand)

    allowed = set()
    allowlist_path = os.path.join(root, ALLOWLIST)
    if os.path.isfile(allowlist_path):
        allowed = set(load_allowlist(allowlist_path))
        for entry in sorted(allowed - set(orphans)):
            if not os.path.isfile(os.path.join(root, entry)):
                violations.append(
                    f"allowlist entry '{entry}' names a file that no longer exists "
                    "— the list only shrinks: remove the entry")
            else:
                violations.append(
                    f"allowlist entry '{entry}' is no longer an orphan — something points "
                    "at it now; the list only shrinks: remove the entry")
        base = ratchet_base(root)
        if base:
            committed = committed_entries(root, base)
            if committed is None:
                notes.append(
                    f"allowlist has no committed version at base {base[:12]} "
                    "— this is the seed; the shrink-only growth ratchet starts once it lands")
            else:
                for entry in sorted(allowed - set(committed)):
                    violations.append(
                        f"allowlist GREW vs base {base[:12]}: '{entry}' is not in the committed list "
                        "— the allowlist only shrinks; clean the tree and remove an entry instead")
        else:
            notes.append("no resolvable base ref — growth ratchet skipped this run (shallow or standalone checkout)")

    print(f"31-orphan-references: {len(candidates)} reference file(s) checked against "
          f"{len(corpus_paths)} corpus file(s), {len(orphans)} orphan(s), {len(allowed)} allowlist entr(ies)")
    for n in notes:
        print(f"NOTE: {n}")
    for rel in orphans:
        if rel not in allowed:
            violations.append(
                f"{rel} is an orphan — nothing in the registry points at it: delete it, "
                "or wire a reader; the allowlist is a dated shrinking rest home, not an amnesty")
    if violations:
        print("FAIL 31-orphan-references: unreferenced reference file(s) or a non-shrinking allowlist:")
        for v in violations:
            print(f"  - {v}")
        return 1
    print("31-orphan-references: PASS")
    return 0


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else scope.ROOT
    if os.path.abspath(root) != scope.ROOT:
        os.environ["LINT_ROOT"] = os.path.abspath(root)
        import importlib
        importlib.reload(scope)
    return scan(root)


if __name__ == "__main__":
    sys.exit(main())
