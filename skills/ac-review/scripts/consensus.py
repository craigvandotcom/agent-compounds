#!/usr/bin/env python3
"""Deterministic consensus for ac-review reviewer findings.

Harness-agnostic (stdlib only, runs under bare /usr/bin/python3). Reads the
round-{N}-{role}.json finding files emitted by the Phase-2 reviewers, dedups on
file:line+category (plus a same-location any-category secondary check —
reviewers describe one defect with different slugs), detects same-round and
cross-round consensus, applies the
MECHANICAL auto-apply cascade from `ac-pipeline/references/review-consensus.md`, carries deferred
findings forward in a consensus registry, and surfaces any missing reviewer
(partial-failure) instead of silently dropping it.

Which reviewers to expect comes from (highest precedence first):
  1. --expect security,performance,...      explicit CLI override
  2. <dir>/panel-round-<N>.json             the panel manifest Phase 2 writes at
                                            spawn time ({"round": N, "spawned":
                                            [...], "skipped": {...}}) — the
                                            normal path for the 6-dimension panel
There is NO third source. A missing, unparseable or empty manifest is `unknown`
panel composition, and **`unknown` never collapses to `ok`**: the script exits
non-zero (EXIT_PANEL_UNKNOWN) and writes nothing, because a review that cannot
confirm its own panel composition has not reviewed anything it can attest to.
Silently defaulting to a smaller panel is what this script exists to prevent —
observed 2026-07-31: a dcg-blocked manifest write dropped the contracts and
test-quality reviewers, one Critical among them, and the run still printed green
(bd-axeyx).

A dimension listed as spawned but with no parseable output file is reported in
`reviewers_missing` — a partial failure, never a silent pass.

What this does NOT do: the design-decision gate (a choice with no objectively
superior answer) is irreducibly the conductor's judgment — it is applied to the
`deferred` pool this script emits, not mechanized here.

Usage:
    python3 consensus.py --artifacts-dir <dir> --round <N>

Emits a human-readable summary to stdout and writes:
    <dir>/consensus-round-<N>.json   machine-readable result
    <dir>/consensus-registry.json    deferred-finding pool (cross-round memory)
"""
import argparse
import json
import os
import re
import sys

EXIT_NO_ARTIFACTS_DIR = 2
EXIT_PANEL_UNKNOWN = 3
AUTO_SEVERITIES = {"critical", "high"}
_SEV_ORDER = {"critical": 4, "high": 3, "medium": 2, "low": 1}


def sev_rank(s):
    return _SEV_ORDER.get((s or "").strip().lower(), 0)


def norm_key(f):
    """Stable match key: normalized file path + line + lowercased category."""
    file = re.sub(r"^\./", "", (f.get("file") or "").strip())
    line = f.get("line")
    cat = (f.get("category") or "").strip().lower()
    return "{}:{}|{}".format(file, line, cat)


def load_panel(artifacts_dir, rnd, override):
    """Resolve the expected reviewer set: CLI override > panel manifest > FAIL.

    Returns (roles, source, skipped) on success, or (None, reason, None) when the
    panel is `unknown`. There is deliberately no default panel: a verdict without a
    denominator is not a verdict, and `unknown` must never collapse to `ok`.
    """
    if override:
        roles = [r.strip() for r in override.split(",") if r.strip()]
        if roles:
            return roles, "cli", {}
        return None, "--expect was given but named no reviewer roles", None
    path = os.path.join(artifacts_dir, "panel-round-{}.json".format(rnd))
    if not os.path.exists(path):
        return None, "panel manifest not found: {}".format(path), None
    try:
        with open(path) as fh:
            data = json.load(fh)
    except (json.JSONDecodeError, OSError) as e:
        return None, "panel manifest {} could not be parsed: {}".format(path, e), None
    spawned = data.get("spawned") or []
    if not spawned:
        return None, "panel manifest {} has an empty 'spawned' list".format(path), None
    skipped = data.get("skipped") or {}
    return spawned, "manifest", skipped if isinstance(skipped, dict) else {}


def panel_unknown(reason, rnd):
    """Emit the loud failure for an unconfirmable panel and return the exit code."""
    print("ERROR: PANEL UNKNOWN for round {} — {}".format(rnd, reason), file=sys.stderr)
    print("ERROR: refusing to fall back to a default panel. A review that cannot confirm its",
          file=sys.stderr)
    print("       own panel composition has not reviewed anything it can attest to; a defaulted",
          file=sys.stderr)
    print("       panel silently DROPS whatever the missing reviewers found (bd-axeyx).",
          file=sys.stderr)
    print("FIX: write the Phase-2 panel manifest (panel-round-{}.json) with the Write tool on a".format(rnd),
          file=sys.stderr)
    print("     literal path — see ac-pipeline/references/shell-guardrails.md if dcg blocked the write — and",
          file=sys.stderr)
    print("     re-run. Only if the panel is genuinely known out-of-band, pass --expect.",
          file=sys.stderr)
    print("VERDICT: NEEDS_DECISION (panel unknown — NOT approved)", file=sys.stderr)
    return EXIT_PANEL_UNKNOWN


def load_round(artifacts_dir, rnd, expected):
    present, missing, findings = [], [], []
    for role in expected:
        path = os.path.join(artifacts_dir, "round-{}-{}.json".format(rnd, role))
        if not os.path.exists(path):
            missing.append(role)
            continue
        try:
            with open(path) as fh:
                data = json.load(fh)
        except (json.JSONDecodeError, OSError) as e:
            missing.append(role)
            print("WARN: could not parse {}: {}".format(path, e), file=sys.stderr)
            continue
        present.append(role)
        for item in data.get("findings", []) or []:
            item["_reviewer"] = role
            item["_key"] = norm_key(item)
            findings.append(item)
    return present, missing, findings


def load_registry(path):
    if not os.path.exists(path):
        return []
    try:
        with open(path) as fh:
            return json.load(fh)
    except (json.JSONDecodeError, OSError):
        return []


def build(artifacts_dir, rnd, expected, panel_source, panel_skipped=None):
    reg_path = os.path.join(artifacts_dir, "consensus-registry.json")
    present, missing, findings = load_round(artifacts_dir, rnd, expected)
    registry = load_registry(reg_path)
    prior_keys = {e["key"]: e for e in registry if e.get("round", 0) < rnd}

    by_key = {}
    for f in findings:
        by_key.setdefault(f["_key"], []).append(f)

    # Same-location secondary index: reviewers invent category slugs
    # independently, so genuine multi-reviewer agreement on one file:line can
    # hide behind three different slugs (observed 2026-07-04: normalize.ts:36
    # flagged by 3 reviewers under 3 categories — the category-keyed pass left
    # all three deferred). Location = the file:line half of the key.
    by_loc = {}
    for f in findings:
        loc = f["_key"].rsplit("|", 1)[0]
        by_loc.setdefault(loc, set()).add(f["_reviewer"])

    auto_fix, deferred = [], []
    for key, group in by_key.items():
        rep = max(group, key=lambda x: sev_rank(x.get("severity")))
        reviewers = sorted({g["_reviewer"] for g in group})
        reasons = []
        if (rep.get("severity") or "").strip().lower() in AUTO_SEVERITIES:
            reasons.append("severity:{}".format(rep.get("severity")))
        if len(reviewers) >= 2:
            reasons.append("same-round-consensus:{}".format(",".join(reviewers)))
        loc_reviewers = by_loc.get(key.rsplit("|", 1)[0], set())
        if len(reviewers) < 2 and len(loc_reviewers) >= 2:
            reasons.append(
                "same-location-consensus:{}".format(",".join(sorted(loc_reviewers)))
            )
        if key in prior_keys:
            reasons.append("cross-round-consensus:round-{}".format(prior_keys[key].get("round")))
        entry = {
            "key": key,
            "title": rep.get("title"),
            "severity": rep.get("severity"),
            "file": rep.get("file"),
            "line": rep.get("line"),
            "category": rep.get("category"),
            "fix": rep.get("fix"),
            "auto_fixable": rep.get("auto_fixable"),
            "reviewers": reviewers,
            "reasons": reasons,
        }
        (auto_fix if reasons else deferred).append(entry)

    # Carry deferred single-reviewer findings forward for cross-round matching.
    reg_keys = {e["key"] for e in registry}
    for d in deferred:
        if d["key"] not in reg_keys:
            registry.append({
                "round": rnd,
                "key": d["key"],
                "reviewer": d["reviewers"][0],
                "severity": d["severity"],
                "file": d["file"],
                "line": d["line"],
                "category": d["category"],
                "summary": d["title"],
            })
    try:
        with open(reg_path, "w") as fh:
            json.dump(registry, fh, indent=2)
    except OSError as e:
        print("WARN: could not write registry: {}".format(e), file=sys.stderr)

    return {
        "round": rnd,
        "reviewers_expected": expected,
        "panel_source": panel_source,
        "panel_skipped": panel_skipped or {},
        "reviewers_present": present,
        "reviewers_missing": missing,
        "total_findings": len(findings),
        "after_dedup": len(by_key),
        "auto_fix": sorted(auto_fix, key=lambda x: sev_rank(x["severity"]), reverse=True),
        "deferred": deferred,
    }


def print_summary(r):
    print("## Consensus — round {}".format(r["round"]))
    # The denominator, always printed: a verdict that does not state its own scope is
    # not a verdict. Copy this line verbatim into the report's `**Panel:**` field.
    print("Panel ({}): {}".format(r["panel_source"], ", ".join(r["reviewers_expected"])))
    if r.get("panel_skipped"):
        print("Panel skipped: {}".format(
            "; ".join("{}={}".format(k, v) for k, v in sorted(r["panel_skipped"].items()))))
    if r["reviewers_missing"]:
        print("⚠ MISSING reviewers (partial failure — DO NOT treat as clean): {}".format(
            ", ".join(r["reviewers_missing"])))
    print("Reviewers present: {}".format(", ".join(r["reviewers_present"]) or "none"))
    print("Findings: {} total → {} after dedup".format(r["total_findings"], r["after_dedup"]))
    print()
    print("AUTO_FIX ({}):".format(len(r["auto_fix"])))
    for e in r["auto_fix"]:
        print("  - [{}] {}:{} — {}  ({})".format(
            e["severity"], e["file"], e["line"], e["title"], "; ".join(e["reasons"])))
    print()
    print("DEFERRED ({}) — apply the design-decision gate to these:".format(len(r["deferred"])))
    for e in r["deferred"]:
        print("  - [{}] {}:{} — {}  ({})".format(
            e["severity"], e["file"], e["line"], e["title"], ",".join(e["reviewers"])))


def main():
    ap = argparse.ArgumentParser(description="Deterministic ac-review consensus.")
    ap.add_argument("--artifacts-dir", required=True)
    ap.add_argument("--round", type=int, default=1)
    ap.add_argument("--expect", default=None,
                    help="Comma-separated reviewer roles to expect (overrides the panel manifest)")
    args = ap.parse_args()

    if not os.path.isdir(args.artifacts_dir):
        print("ERROR: artifacts dir not found: {}".format(args.artifacts_dir), file=sys.stderr)
        return EXIT_NO_ARTIFACTS_DIR

    expected, panel_source, panel_skipped = load_panel(
        args.artifacts_dir, args.round, args.expect)
    if expected is None:
        return panel_unknown(panel_source, args.round)

    result = build(args.artifacts_dir, args.round, expected, panel_source, panel_skipped)
    out = os.path.join(args.artifacts_dir, "consensus-round-{}.json".format(args.round))
    try:
        with open(out, "w") as fh:
            json.dump(result, fh, indent=2)
    except OSError as e:
        print("WARN: could not write {}: {}".format(out, e), file=sys.stderr)

    print_summary(result)
    return 0


if __name__ == "__main__":
    sys.exit(main())
