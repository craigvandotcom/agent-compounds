#!/usr/bin/env python3
# ---
# id: 16-mirror-fidelity
# prevents: a mandated verbatim mirror drifting — the child-spawn environment contract must be pasted byte-identical into every file that constructs a child prompt, and an unparsed marker must fail loudly instead of silently dropping what it cannot classify
# scope: LIVE_TEXT
# severity: fail
# fixture: lint/fixtures/16-mirror-fidelity
# ---
"""16-mirror-fidelity — the ported Check 16 judge (ac-1p7j.15).

Ported VERBATIM from the legacy bash block (proven by lint/parity.sh against
the extracted block, before the block was removed from lint.sh). Same marker
grammar, same three buckets, same verdict strings.

Canon MANDATES this duplication: the child-spawn environment contract is
pasted VERBATIM into every file that constructs a child prompt — a
pointer-only reference is explicitly declared insufficient. A mandated
duplicate with no drift check is a guaranteed future divergence.

The marker corpus is NOT homogeneous, so the classification is deliberately
narrow and every marker must land in exactly one bucket; an unaccounted
marker is a hard failure, because a check that silently drops what it cannot
parse is a false green:

  VERBATIM class   markers citing delegation-contract.md § Child-spawn
                   preamble — byte-compared against the canon block (the
                   blockquoted `>`-prefixed form, stripped for comparison).
  PARAPHRASE class markers citing any other canon — deliberate prose
                   restatements, reported as skipped BY NAME, never silently.
  EXCLUDED         the marker-syntax example in structure-standard.md, whose
                   cited path is a `<placeholder>`, not a file.

Population: every *.md under skills/ that lib.scope tracks (LIVE_TEXT plus
the dated ledger files) — the same corpus the legacy `grep -rn
--include='*.md'` walked.

Exit: 0 clean, 1 violations, 2 no skills/ under root (NOT-GATED, never a pass).
"""

import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_LINT = os.path.dirname(_HERE)
sys.path.insert(0, _LINT)

from lib import scope  # noqa: E402

CANON_REF = "ac-pipeline/references/delegation-contract.md"
CANON_SECTION = "Child-spawn preamble"
CANON_START = "> ENVIRONMENT CONTRACT (non-negotiable):"
PREAMBLE_START = re.compile(r"^ENVIRONMENT CONTRACT \(non-negotiable\):")

findings = []


def canon_block(root):
    """The § block stripped of its quote prefix, as the carriers must match it."""
    path = os.path.join(root, "skills", CANON_REF)
    if not os.path.isfile(path):
        return []
    block = []
    seen = False
    with open(path, encoding="utf-8", errors="replace") as fh:
        for ln in fh.read().split("\n"):
            if seen and not ln.startswith(">"):
                break
            if ln.startswith(CANON_START):
                seen = True
            if seen:
                block.append(re.sub(r"^> ?", "", ln))
    return block


def markers(root):
    """(rel_path, line_no, line_text) for every <!-- mirror: line, legacy order."""
    out = []
    for rel in sorted(set(scope.LIVE_TEXT) | set(scope.LEDGER)):
        if not (rel.startswith("skills/") and rel.endswith(".md")):
            continue
        with open(os.path.join(root, rel), encoding="utf-8", errors="replace") as fh:
            for i, ln in enumerate(fh.read().split("\n"), start=1):
                if "<!-- mirror:" in ln:
                    out.append((rel, i, ln))
    return out


def classify(text):
    """Marker payload -> (path, section) exactly as the legacy shell parsed it."""
    body = text.split("mirror:", 1)[1]
    body = body.split("--", 1)[0]
    body = body.split("— edit", 1)[0]
    if "§" in body:
        path, section = body.split("§", 1)
    else:
        path, section = body, ""
    return path.strip(), section.strip()


def run(root):
    skills = os.path.join(root, "skills")
    if not os.path.isdir(skills):
        print("16-mirror-fidelity NOT-CHECKED: no skills/ under root — nothing scanned",
              file=sys.stderr)
        return 2

    canon = canon_block(root)
    total = checked = skipped = excluded = 0

    if not canon or len(canon) < 10:
        findings.append(
            f"could not extract the § {CANON_SECTION} block from {CANON_REF}")
        canon = []

    if canon:
        for rel, lineno, text in markers(root):
            total += 1
            mpath, msection = classify(text)
            if mpath.startswith("<"):
                excluded += 1
                print(f"  EXCL  {rel}:{lineno} — marker-syntax example (placeholder path)")
                continue
            if mpath != CANON_REF or msection != CANON_SECTION:
                skipped += 1
                tail = f" § {msection}" if msection else ""
                print(f"  SKIP  {rel}:{lineno} — paraphrase-class mirror of {mpath}{tail} "
                      "(prose restatement, not a verbatim copy)")
                continue
            checked += 1
            with open(os.path.join(root, rel), encoding="utf-8", errors="replace") as fh:
                lines = fh.read().split("\n")
            start = next((i for i in range(lineno - 1, len(lines))
                          if PREAMBLE_START.match(lines[i])), None)
            if start is None:
                findings.append(
                    f"{rel} carries a Child-spawn-preamble mirror marker but no preamble "
                    "block follows it")
                continue
            block = lines[start:start + len(canon)]
            if block == canon:
                print(f"  PASS  {rel} (preamble at line {start + 1})")
            else:
                findings.append(
                    f"{rel} preamble block (line {start + 1}) has DRIFTED from {CANON_REF} "
                    f"§ {CANON_SECTION} — re-paste it verbatim from canon")

    accounted = checked + skipped + excluded
    if total == 0:
        findings.append("zero mirror markers scanned — accounting is vacuous "
                        "(canon block unreadable?)")
    elif accounted != total:
        findings.append(f"accounted for {accounted} of {total} mirror markers — "
                        "an unparsed marker is a false green")
    else:
        print(f"  mirror markers: {total} total — {checked} verbatim-class checked, "
              f"{skipped} paraphrase-class skipped, {excluded} excluded")

    for f in findings:
        print(f"FAIL 16-mirror-fidelity: {f}")
    return 1 if findings else 0


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else scope.ROOT
    if os.path.abspath(root) != scope.ROOT:
        os.environ["LINT_ROOT"] = os.path.abspath(root)
        import importlib
        importlib.reload(scope)
    return run(root)


if __name__ == "__main__":
    sys.exit(main())
