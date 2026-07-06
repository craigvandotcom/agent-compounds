#!/usr/bin/env python3
"""Deterministic consensus for ac-review reviewer findings.

Harness-agnostic (stdlib only, runs under bare /usr/bin/python3). Reads the
round-{N}-{role}.json finding files emitted by the Phase-2 reviewers, dedups on
file:line+category (plus a same-location any-category secondary check —
reviewers describe one defect with different slugs), detects same-round and
cross-round consensus, applies the
MECHANICAL auto-apply cascade from `_shared/review-consensus.md`, carries deferred
findings forward in a consensus registry, and surfaces any missing reviewer
(partial-failure) instead of silently dropping it.

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

EXPECTED = ["security", "performance", "architecture", "correctness"]
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


def load_round(artifacts_dir, rnd):
    present, missing, findings = [], [], []
    for role in EXPECTED:
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


def build(artifacts_dir, rnd):
    reg_path = os.path.join(artifacts_dir, "consensus-registry.json")
    present, missing, findings = load_round(artifacts_dir, rnd)
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
        "reviewers_present": present,
        "reviewers_missing": missing,
        "total_findings": len(findings),
        "after_dedup": len(by_key),
        "auto_fix": sorted(auto_fix, key=lambda x: sev_rank(x["severity"]), reverse=True),
        "deferred": deferred,
    }


def print_summary(r):
    print("## Consensus — round {}".format(r["round"]))
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
    args = ap.parse_args()

    if not os.path.isdir(args.artifacts_dir):
        print("ERROR: artifacts dir not found: {}".format(args.artifacts_dir), file=sys.stderr)
        return 2

    result = build(args.artifacts_dir, args.round)
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
