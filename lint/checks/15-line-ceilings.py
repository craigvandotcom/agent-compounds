#!/usr/bin/env python3
# ---
# id: 15-line-ceilings
# prevents: an outlier or brand-new oversized SKILL.md slipping past the per-file no-net-growth
#   ratchet — the coarse conductor-tier (1110) and standard-tier (730) line ceilings, with the one-way
#   ratchet that refuses a raised constant that outruns its measured tier
# scope: LIVE_TEXT
# severity: fail
# fixture: lint/fixtures/15-line-ceilings
# ---
"""15-line-ceilings — the ported Check 15 judge (ac-1p7j.15).

Ported VERBATIM from the legacy bash block (proven by lint/parity.sh against
the extracted block, before the block was removed from lint.sh). Same roster
derivation, same ratchet arithmetic, same verdict strings. The constants
moved to lint/config.json (conductor_ceiling, standard_ceiling,
conductor_skills) per the bead intent — a ceiling change is a config change.

These ceilings are a COARSE BACKSTOP for outliers and brand-new large skills
— SECONDARY to Check 14's per-file no-net-growth ratchet, which is the
PRIMARY control. A ceiling only catches a skill that was already too big when
it first crossed the line (or one whose growth is stamped-exempt from
Check 14).

Ratchet — ONE-WAY, by construction. The derived ceiling is recomputed from
the live SKILL.md line counts every run and FAILS when the committed constant
EXCEEDS it. It is NOT symmetric: a derived value looser than the constant is
never licence to raise it — a raise is a reviewed config edit, and this check
catches the raise that outruns the measured tier.

  conductor tier  ceil_to_10(tier max x 1.15) — W3.2-pilot measured cap
                  (live-run-accepted 2026-07-21; live tier max is ac-review)
  standard tier   ceil_to_10(tier max x 1.10) — deliberately TIGHTER than the
                  conductor multiplier so each re-measure is a real tightening

Exit: 0 clean, 1 violations, 2 no skills/*/SKILL.md under root (NOT-GATED,
never a pass).
"""

import json
import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_LINT = os.path.dirname(_HERE)
sys.path.insert(0, _LINT)

from lib import scope  # noqa: E402

CONFIG = "lint/config.json"
SKILL_RE = re.compile(r"^skills/[^/]+/SKILL\.md$")

violations = []


def ceil_to_10(max_lines, mult_pct):
    """Integer form of ceil_to_10(max x mult): truncate, round up to the next 10."""
    raw = max_lines * mult_pct // 100
    return (raw + 9) // 10 * 10


def load_config(root):
    with open(os.path.join(root, CONFIG), encoding="utf-8") as fh:
        return json.load(fh)


def roster(root):
    """name -> (lines, tier, accessory) over the top-level skills, one pass."""
    out = {}
    for rel in sorted(scope.LIVE_TEXT):
        if not SKILL_RE.match(rel):
            continue
        name = rel.split("/")[1]
        with open(os.path.join(root, rel), encoding="utf-8", errors="replace") as fh:
            lines = 0
            acc = False
            for ln in fh:
                lines += 1
                if ln.startswith("accessory: true"):
                    acc = True
        out[name] = (lines, "conductor" if name in cfg_conductors else "standard", acc)
    return out


cfg_conductors = []


def run(root):
    global cfg_conductors
    try:
        cfg = load_config(root)
        cond_ceiling = int(cfg["conductor_ceiling"])
        std_ceiling = int(cfg["standard_ceiling"])
        cfg_conductors = list(cfg["conductor_skills"])
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print(f"FAIL 15-line-ceilings: {CONFIG} missing or incomplete ({exc}) — "
              "the ceiling constants are a config change, never a script edit")
        return 1

    ros = roster(root)
    if not ros:
        print("15-line-ceilings NOT-CHECKED: no skills/*/SKILL.md under root — nothing scanned",
              file=sys.stderr)
        return 2

    con_max, con_owner = 0, "(none)"
    std_max, std_owner = 0, "(none)"
    for name, (lines, tier, acc) in ros.items():
        if tier == "conductor":
            if lines > con_max:
                con_max, con_owner = lines, name
        elif not acc:
            if lines > std_max:
                std_max, std_owner = lines, name

    std_derived = ceil_to_10(std_max, 110)
    if std_ceiling > std_derived:
        violations.append(
            f"ratchet violated — STANDARD_CEILING ({std_ceiling}) exceeds derived ceiling "
            f"({std_derived} = ceil_to_10({std_max} x 1.10), tier max {std_owner}) — the ratchet "
            "moves DOWN only; diet the skill instead of raising the constant")
    else:
        print(f"  PASS  ratchet         STANDARD_CEILING {std_ceiling} <= derived {std_derived} "
              f"= ceil_to_10({std_max} x 1.10), tier max {std_owner}")
    con_derived = ceil_to_10(con_max, 115)
    if cond_ceiling > con_derived:
        violations.append(
            f"ratchet violated — CONDUCTOR_CEILING ({cond_ceiling}) exceeds derived ceiling "
            f"({con_derived} = ceil_to_10({con_max} x 1.15), tier max {con_owner}) — the ratchet "
            "moves DOWN only; diet the skill instead of raising the constant")
    else:
        print(f"  PASS  ratchet         CONDUCTOR_CEILING {cond_ceiling} <= derived {con_derived} "
              f"= ceil_to_10({con_max} x 1.15), tier max {con_owner}")

    for cname in cfg_conductors:
        if cname not in ros:
            violations.append(f"conductor skill '{cname}' has no SKILL.md at skills/{cname}/SKILL.md")
            continue
        lines = ros[cname][0]
        if lines > cond_ceiling:
            violations.append(
                f"conductor '{cname}' SKILL.md is {lines} lines > {cond_ceiling} ceiling "
                "(diet it or move content to references/)")
        else:
            print(f"  PASS  {cname:<16} {lines:>5} / {cond_ceiling} lines")
    for name, (lines, tier, acc) in sorted(ros.items()):
        if tier == "conductor" or acc:
            continue
        if lines > std_ceiling:
            violations.append(
                f"standard skill '{name}' SKILL.md is {lines} lines > {std_ceiling} ceiling "
                "(diet it or move content to references/)")
        else:
            print(f"  PASS  {name:<16} {lines:>5} / {std_ceiling} lines")

    if violations:
        for v in violations:
            print(f"FAIL 15-line-ceilings: {v}")
        return 1
    print(f"15-line-ceilings: {len(ros)} SKILL.md scanned — conductor {cond_ceiling}, "
          f"standard {std_ceiling}")
    return 0


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else scope.ROOT
    if os.path.abspath(root) != scope.ROOT:
        os.environ["LINT_ROOT"] = os.path.abspath(root)
        import importlib
        importlib.reload(scope)
    return run(root)


if __name__ == "__main__":
    sys.exit(main())
