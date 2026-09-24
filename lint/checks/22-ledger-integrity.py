#!/usr/bin/env python3
# ---
# prevents: a friction ledger and its controls drifting apart — entries citing controls the
#   constitution does not define, receipts nobody kept, a friction re-observed after its control
#   landed accruing silently instead of surfacing as a FAILED CONTROL, and an entry with no scorable
#   ordinal going unreported
# fixture: lint/fixtures/22-ledger-integrity
# ---
"""22-ledger-integrity — the lean family's friction sensor: one check, two surfaces.

The lean family's controls and its friction ledger must still point at each other: every
entry cites a `receipt:` and the `control:` that treats it (or is explicitly `untreated`),
every control names the failure it prevents, and a friction re-observed AFTER its control
landed surfaces as a FAILED CONTROL rather than accruing silently. This check is also the
ONE friction sensor for the ledger-health class: an entry with no scorable ordinal
(impact/frequency/recurrence) is a named finding — never a mutation (the ledger edit is
human-gated; the frictions docket consumes the report rows).

A THIN check over the ONE shared parser (`skills/skill-builder/scripts/friction-rollup.py`),
imported directly (never subprocess, never a second parse of the same files): this module
adds assertions over `parse_ledger()`'s and `collect()`'s already-parsed structures.

THE CONTRACT, both directions:
  ledger -> control   every entry cites a `receipt:` (the evidence) and names the
                      `control:` that treats it, or is explicitly `control: untreated`.
                      A cited control must RESOLVE against the constitution — `I<n>` for
                      an Invariant, `C-<slug>` for a Calibration.
  control -> failure  every Invariant names the failure it Prevents AND its L-tag; every
                      Calibration names its L-tag and the measurement that *retires* it.
  regression          a treated entry whose `last_seen` is AFTER its `control_landed`
                      date is a FAILED CONTROL — the friction kept biting after the fix
                      shipped. Treated entries must carry `control_landed:`, or that
                      detector is unfalsifiable.
  seed rule           a friction id minted in an older ledger is legal input: during
                      construction, controls cite those ids and the family ledger
                      inherits them. Foreign ids are never flagged.

THE SCORABLE SWEEP (folded in from friction-rollup.py --strict; detection automated,
mutation human-gated): every skills/*/FRICTIONS.md entry must carry scorable ordinals
(impact/frequency/recurrence). Findings are REPORT ROWS, never mutations; the frictions
docket consumes them. With no --ledger, the sweep covers ALL ledgers; an explicit
--ledger scopes the sweep to that one ledger. The retired `entries:` frontmatter count
(dafb9b48) is no longer gated — every entry count this check reports is derived from the
parsed ledger at read time, never from a hand-kept field.

FINDINGS CONTRACT (machine-readable, one row per line, grep-able for the docket):
  FAIL: NOT-SCORABLE: <id> (<path>): <ordinal>='<value>'; ...
plus the contract rows (FAIL: ledger entry '...' / FAIL: constitution: ... /
FAIL: FAILED CONTROL — ...).

Usage:  22-ledger-integrity.py [--ledger <path>] [--constitution <path>] [<repo root>]
Exit 0   the ledger and the constitution satisfy the contract
Exit 1   at least one violation (each reported as FAIL: ...), including an explicitly
         named --ledger/--constitution or a parser that cannot be read
Exit 2   the shared parser is missing, or cannot be loaded — nothing was checked
Exit 77  skip — this checkout ships no ledger at all (adopter-local, gitignored); an
         explicitly named --ledger that is absent is still exit 1, never a skip
"""

import argparse
import datetime
import importlib.util
import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO_ROOT_DEFAULT = os.path.dirname(os.path.dirname(_HERE))  # lint/checks -> lint -> root


def _load_rollup(root):
    path = os.path.join(root, "skills", "skill-builder", "scripts", "friction-rollup.py")
    spec = importlib.util.spec_from_file_location("friction_rollup", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# --- the constitution parser: control -> failure --------------------------------------
# Each control is a BLOCK (its text wraps), so flatten block-by-block before asserting —
# the same two-pass shape the retired awk scripts used, ported line for line.
_INVARIANT_RE = re.compile(r"^\d+\.")
_CALIBRATION_RE = re.compile(r"^- \*\*")
_L_TAGS = ("(L1)", "(L2)", "(L3)")


def _flatten_invariants(text):
    out, cur, active = [], None, False
    for line in text.splitlines():
        if line.startswith("## Calibrations"):
            if cur is not None:
                out.append(cur)
            cur, active = None, False
            continue
        if line.startswith("## Invariants"):
            active = True
            continue
        if active and _INVARIANT_RE.match(line):
            if cur is not None:
                out.append(cur)
            cur = line
        elif active and cur is not None:
            cur = cur + " " + line
    if cur is not None:
        out.append(cur)
    return out


def _flatten_calibrations(text):
    out, cur, active = [], None, False
    for line in text.splitlines():
        if line.startswith("## Calibrations"):
            active = True
            continue
        if active and _CALIBRATION_RE.match(line):
            if cur is not None:
                out.append(cur)
            cur = line
        elif active and cur is not None:
            cur = cur + " " + line
    if cur is not None:
        out.append(cur)
    return out


def _slug(name):
    s = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")
    return s


def check_constitution(text, fail):
    """Returns the set of resolvable control ids (`I<n>` / `C-<slug>`), asserting the
    control -> failure direction along the way."""
    control_ids = set()
    for line in _flatten_invariants(text):
        if not line.strip():
            continue
        num = line.split(".", 1)[0]
        control_ids.add(f"I{num}")
        if not any(tag in line for tag in _L_TAGS):
            fail(f"constitution: Invariant {num} carries no L-tag — a control naming "
                 "neither its failure nor its layer is deleted, not demoted")
        if "Prevents:" not in line:
            fail(f"constitution: Invariant {num} names no failure it prevents (no 'Prevents:')")
    for line in _flatten_calibrations(text):
        if not line.strip():
            continue
        m = re.match(r"^- \*\*([^*]+)\*\*", line)
        name = m.group(1) if m else ""
        slug = _slug(name)
        if not slug:
            continue
        control_ids.add(f"C-{slug}")
        if not any(tag in line for tag in _L_TAGS):
            fail(f"constitution: Calibration '{name}' carries no L-tag")
        if "retires when:" not in line:
            fail(f"constitution: Calibration '{name}' names no measurement that retires "
                 "it — a Calibration that cannot be retired is an Invariant in disguise "
                 "or a superstition")
    return control_ids


# --- the ledger -> control direction ---------------------------------------------------
def check_ledger_entries(entries, control_ids, fail):
    """Asserts the ledger -> control direction over one ledger's raw (non-deduped)
    entries, exactly as `--ledger <path>` scoped the bash version."""
    for entry in entries:
        fields = entry.get("fields", {})
        eid = entry["id"]
        receipt = fields.get("receipt", "").strip()
        control = fields.get("control", "").strip()
        landed = fields.get("control_landed", "").strip()
        last_seen = fields.get("last_seen", "").strip()
        untreated = fields.get("untreated", "").strip()
        if not receipt:
            fail(f"ledger entry '{eid}' cites no 'receipt:' — an entry without evidence is an opinion")
        if not control and not untreated:
            fail(f"ledger entry '{eid}' names no 'control:' and is not tagged untreated "
                 "— every friction is treated or declared untreated")
            continue
        low = control.lower()
        if low in ("", "untreated") or low.startswith("untreated"):
            continue  # the sanctioned, explicit escape
        if control not in control_ids:
            fail(f"ledger entry '{eid}' cites control '{control}', which the constitution "
                 "does not define — a pointer to a control nobody kept")
            continue
        if not landed:
            fail(f"ledger entry '{eid}' names control '{control}' but no 'control_landed:' "
                 "date — without it the failed-control detector cannot fire")
            continue
        if last_seen and last_seen > landed:
            fail(f"FAILED CONTROL — '{eid}' was re-observed on {last_seen}, AFTER its "
                 f"control '{control}' landed on {landed}")


def main(argv=None):
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument("--ledger")
    ap.add_argument("--constitution")
    ap.add_argument("root", nargs="?")
    try:
        args = ap.parse_args(argv)
    except SystemExit:
        print("usage: 22-ledger-integrity.py [--ledger <path>] [--constitution <path>] "
              "[<repo root>]", file=sys.stderr)
        return 2

    root = os.path.abspath(args.root) if args.root else _REPO_ROOT_DEFAULT
    ledger_set = args.ledger is not None
    ledger = args.ledger or os.path.join(root, "skills", "ac-pipeline", "FRICTIONS.md")
    constitution = args.constitution or os.path.join(root, "skills", "ac-pipeline", "SKILL.md")

    try:
        rollup = _load_rollup(root)
    except OSError as exc:
        print(f"FAIL: NOT-GATED — the shared ledger parser could not be loaded: {exc}; "
              "nothing was checked", file=sys.stderr)
        return 2

    # --- Absent ledger: skip when unshipped, fail closed when explicitly named --------
    if not os.path.isfile(ledger) and not ledger_set:
        print("skipped: 22-ledger-integrity — no ledger in this checkout, nothing gated")
        return 77
    if not os.path.isfile(ledger):
        print(f"FAIL: NOT-GATED — no ac2 ledger at {ledger}. An absent sensor is not a clean one.")
        return 1

    failures = []
    fail = failures.append

    try:
        led = rollup.parse_ledger(ledger, root)
    except OSError as exc:
        print(f"FAIL: NOT-GATED — the shared parser could not read {ledger}: {exc}")
        return 1
    entry_count = len(led["entries"])
    if entry_count == 0:
        print(f"FAIL: NOT-GATED — {ledger} carries zero entries; an empty ledger proves nothing")
        return 1

    if not os.path.isfile(constitution):
        print(f"FAIL: NOT-GATED — no constitution at {constitution}; controls cannot be resolved")
        return 1
    with open(constitution, encoding="utf-8") as fh:
        control_ids = check_constitution(fh.read(), fail)

    check_ledger_entries(led["entries"], control_ids, fail)

    # --- THE SCORABLE SWEEP (the folded-in --strict classes) --------------------------
    # One parse of every skills/*/FRICTIONS.md via the shared rollup's cross-ledger
    # `collect()`: each entry's own `unscorable` reasons. Two verdict classes above,
    # this one below; every finding is a REPORT ROW for the frictions docket, never a
    # mutation of the ledger.
    today = datetime.date.today()
    try:
        ledgers, by_id = rollup.collect(root, rollup.DEFAULT_THRESHOLD, today)
    except OSError as exc:
        print(f"FAIL: NOT-GATED — the shared parser could not sweep {root}: {exc}")
        return 1
    ledger_rel = os.path.relpath(ledger, root) if ledger_set else None
    not_scorable = sorted(
        (rec for rec in by_id.values()
         if rec["unscorable"] and (ledger_rel is None or rec["path"] == ledger_rel)),
        key=lambda r: (r["path"], r["id"]),
    )
    for rec in not_scorable:
        fail(f"NOT-SCORABLE: {rec['id']} ({rec['path']}): {'; '.join(rec['unscorable'])}")

    if failures:
        for line in failures:
            print(f"FAIL: {line}")
        return 1

    control_count = len(control_ids)
    if ledger_set:
        print(f"  ok: 22-ledger-integrity — {entry_count} entr(y|ies) · {control_count} "
              "controls — contract holds both directions")
    else:
        print(f"  ok: 22-ledger-integrity — {entry_count} entr(y|ies) · {control_count} "
              f"controls — contract holds both directions · all {len(ledgers)} ledgers scorable")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except Exception as exc:  # fail loud: a crashed check is never a pass
        print(f"FAIL 22-ledger-integrity: crashed: {exc}", file=sys.stderr)
        sys.exit(1)
