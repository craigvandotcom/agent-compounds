#!/usr/bin/env python3
# ---
# prevents: a mandated verbatim mirror drifting — the child-spawn environment contract must be
#   pasted byte-identical into every file that constructs a child prompt, an unparsed marker must
#   fail loudly instead of silently dropping what it cannot classify, and a carrier's own
#   paste-instruction must name an anchor that actually occurs in its prompt body
# fixture: lint/fixtures/16-mirror-fidelity
# ---
"""16-mirror-fidelity — every mandated verbatim mirror stays byte-identical to canon,
and its paste instruction actually lands.

Canon MANDATES this duplication: the child-spawn environment contract is
pasted VERBATIM into every file that constructs a child prompt — a
pointer-only reference is explicitly declared insufficient. A mandated
duplicate with no drift check is a guaranteed future divergence.

Two legs:

  Leg 1 (byte-fidelity). The marker corpus is NOT homogeneous, so the
  classification is deliberately narrow and every `<!-- mirror: -->` marker
  must land in exactly one bucket; an unaccounted marker is a hard failure,
  because a check that silently drops what it cannot parse is a false green:

    VERBATIM class   markers citing delegation-contract.md § Child-spawn
                     preamble — byte-compared against the canon block (the
                     blockquoted `>`-prefixed form, stripped for comparison).
    PARAPHRASE class markers citing any other canon — deliberate prose
                     restatements, reported as skipped BY NAME, never silently.
    EXCLUDED         the marker-syntax example in structure-standard.md, whose
                     cited path is a `<placeholder>`, not a file.

  Leg 2 (anchor audit, absorbed from
  skills/ac-pipeline/scripts/preamble-anchor-audit.test.sh). Every carrier's
  header instruction names an anchor ("above its `X` line", "above the `X`
  opening line", or "beginning `X`") telling a future conductor where in the
  prompt body to paste the block. This leg asserts the named anchor actually
  OCCURS in the body, after the header — an anchor that exists only inside
  the header instruction is the inert-paste failure mode: a conductor
  following the instruction literally finds no insertion point, so the
  preamble never reaches any child. Position-based, not occurrence-count: an
  anchor line-wrapped inside the instruction only ever matches the body once
  joined, so counting occurrences false-positives on already-correct files.

Leg-1 population: every *.md under skills/ that lib.scope tracks (LIVE_TEXT
plus the dated ledger files) carrying a `<!-- mirror: -->` marker. Leg-2
population: every *.md under skills/ carrying the literal string
"ENVIRONMENT CONTRACT (non-negotiable)", minus the canon source itself (it
defines the block and constructs no local prompt body).

Exit: 0 clean, 1 violations, 2 no skills/ under root (NOT-GATED, never a pass).
"""

import os
import re
import sys

import _bootstrap  # noqa: F401
from lib import scope  # noqa: E402

CANON_REF = "ac-pipeline/references/delegation-contract.md"
CANON_SECTION = "Child-spawn preamble"
CANON_START = "> ENVIRONMENT CONTRACT (non-negotiable):"
PREAMBLE_START = re.compile(r"^ENVIRONMENT CONTRACT \(non-negotiable\):")
CONTRACT_LINE = "ENVIRONMENT CONTRACT (non-negotiable)"
ANCHOR_PATTERNS = (
    re.compile(r"above its `([^`]*)` line"),
    re.compile(r"above the `([^`]*)` opening line"),
    re.compile(r"beginning `([^`]*)`"),
)

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
    """Marker payload -> (path, section)."""
    body = text.split("mirror:", 1)[1]
    body = body.split("--", 1)[0]
    body = body.split("— edit", 1)[0]
    if "§" in body:
        path, section = body.split("§", 1)
    else:
        path, section = body, ""
    return path.strip(), section.strip()


def anchor_carriers(root):
    """(rel_path, lines) for every *.md under skills/ carrying the ENVIRONMENT
    CONTRACT literal, minus the canon source (it defines the block, constructs
    no local prompt body)."""
    out = []
    skills = os.path.join(root, "skills")
    canon_path = os.path.abspath(os.path.join(root, "skills", CANON_REF))
    for dirpath, _dirnames, filenames in os.walk(skills):
        for fn in sorted(filenames):
            if not fn.endswith(".md"):
                continue
            p = os.path.join(dirpath, fn)
            if os.path.abspath(p) == canon_path:
                continue
            with open(p, encoding="utf-8", errors="replace") as fh:
                text = fh.read()
            if CONTRACT_LINE in text:
                out.append((os.path.relpath(p, root), text.split("\n")))
    return sorted(out)


def anchor_audit(root):
    """Leg 2: every governed carrier's named anchor actually occurs in its
    prompt body, after the header that names it. Returns (checked, broken)."""
    checked = broken = 0
    for rel, lines in anchor_carriers(root):
        cline = next((i for i, ln in enumerate(lines) if CONTRACT_LINE in ln), None)
        if cline is None:
            continue
        checked += 1
        header = " ".join(lines[:cline + 1])
        anchor = None
        for pat in ANCHOR_PATTERNS:
            m = pat.search(header)
            if m:
                anchor = m.group(1)
                break
        if anchor is None:
            findings.append(
                f"{rel}: preamble header names no anchor (checked 'above its `X` line', "
                "'above the `X` opening line', 'beginning `X`') — a conductor cannot find "
                "the paste point")
            broken += 1
            continue
        probe = anchor[:-1] if anchor.endswith("…") else anchor
        last = None
        for i, ln in enumerate(lines):
            if probe in ln:
                last = i
        if last is None or last <= cline:
            findings.append(
                f"{rel}: named anchor '{probe}' does not occur in the prompt body after "
                f"the header (line {cline + 1}) — the paste instruction is inert")
            broken += 1
        else:
            print(f"  PASS  {rel} anchor=[{probe}] (body hit at line {last + 1})")
    if checked:
        print(f"  anchor audit: {checked} governed carrier(s) checked, {broken} broken")
    return checked, broken


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

    anchor_audit(root)

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
