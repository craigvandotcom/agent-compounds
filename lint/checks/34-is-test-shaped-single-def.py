#!/usr/bin/env python3
# ---
# id: 34-is-test-shaped-single-def
# prevents: is_test_shaped() drifting into a second definition site (or a copy inside
#   flight-check.sh) — flight-check WRITES the verification scope that close-gate READS,
#   and if the contract both sides interpret is redefined anywhere but close-gate.sh, the
#   temporal proof silently rests on two different contracts
# scope: SCRIPTS
# severity: fail
# fixture: lint/fixtures/34-is-test-shaped-single-def
# ---
"""34-is-test-shaped-single-def — the ported legacy lint.sh "Check 25" block.

Ported VERBATIM (2026-09-12, lint audit ac-b62c): the legacy block lived
inline in lint.sh under the label "Check 25", which collided with the v2
port's own lint/checks/25-archived-names.py — a second, unrelated check
sharing the same numeral — and being inline it was invisible to 00-meta.py's
header contract and to `./lint.sh --check <id>` / `--changed` scoping. This
port lands on the first free numeral (34) with its own fixture; the verdict
strings and the population (skills/ac-implement/scripts/) are unchanged.

The contract:

  1  is_test_shaped() is defined in EXACTLY ONE file under
     skills/ac-implement/scripts/, and that file is close-gate.sh. A second
     definition site (or the sole site living anywhere else) means the scope
     flight-check writes and the scope close-gate reads can drift apart.
  2  flight-check.sh carries no mention of is_test_shaped at all — not even a
     comment — because any copy is a future drift site.

Exit: 0 both legs hold, 1 either leg violated, 2 no
skills/ac-implement/scripts/ under root (NOT-GATED, never a pass).
"""

import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_LINT = os.path.dirname(_HERE)
sys.path.insert(0, _LINT)

from lib import scope  # noqa: E402

CHECK_ID = "34-is-test-shaped-single-def"
POPULATION_DIR = "skills/ac-implement/scripts"
OWNER = "close-gate.sh"


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else scope.ROOT
    if os.path.abspath(root) != scope.ROOT:
        os.environ["LINT_ROOT"] = os.path.abspath(root)
        import importlib
        importlib.reload(scope)

    files = sorted(rel for rel in scope.SCRIPTS if rel.startswith(POPULATION_DIR + "/"))
    if not files:
        print(f"{CHECK_ID} NOT-CHECKED: no {POPULATION_DIR}/ under {root} — verified nothing",
              file=sys.stderr)
        return 2

    sites = []
    for rel in files:
        with open(os.path.join(root, rel), encoding="utf-8", errors="replace") as fh:
            if "is_test_shaped()" in fh.read():
                sites.append(rel)

    findings = []
    if len(sites) != 1 or not sites[0].endswith("/" + OWNER):
        named = " ".join(sites) if sites else "(none)"
        findings.append(
            f"is_test_shaped() has {len(sites)} definition site(s) ({named}) — the contract "
            f"must live in exactly one place, {OWNER} (ac-b62c drift sensor)")

    flight_check = f"{POPULATION_DIR}/flight-check.sh"
    if flight_check in files:
        with open(os.path.join(root, flight_check), encoding="utf-8", errors="replace") as fh:
            if "is_test_shaped" in fh.read():
                findings.append(
                    "flight-check.sh mentions is_test_shaped — it must carry no copy that "
                    f"could drift from {OWNER}'s definition (ac-b62c)")

    for f in findings:
        print(f"FAIL {CHECK_ID}: {f}")
    if findings:
        return 1
    print(f"  ok: {CHECK_ID} — is_test_shaped() defined once, in {OWNER}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
