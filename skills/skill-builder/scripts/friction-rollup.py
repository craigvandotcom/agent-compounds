#!/usr/bin/env python3
"""friction-rollup.py — ONE parse of the FRICTIONS.md sensor logs, two output views.

The friction ledgers (`skills/*/FRICTIONS.md`, schema:
`skill-builder/references/friction-capture.md`) had three would-be consumers and no
shared computation: dream's W4.5 weighting pass carried the formula inline, ac-tidy had
no staleness scan, and no cross-skill trend surface existed at all. Worse, `last_pass`
was defined by the schema and written by NOTHING — an unswept ledger read exactly like a
swept one, so the freshness field was unfalsifiable evidence.

This script is the single parser. Two views come out of one pass:
  view `dream`  — the FULL W4.5 computation: per-entry weight, promotion flagging,
                  `related`-graph clusters. dream calls this instead of re-deriving it.
  view `trends` — per-skill open counts, entries added since the last scan, top-N by
                  weight, and STALENESS flags. ac-tidy and ac-dashboard read this.

ASSURANCE — MODE: advisory · ON-FAILURE: open. It never exits non-zero on ledger
content: a malformed ledger is REPORTED as malformed, never a hard failure, because a
crashed sensor is a silent sensor. Callers flag; they never block on it.

READ-ONLY BY DEFAULT. The one write path is the explicit `--stamp` flag, which stamps
`last_pass: <today>` into every ledger this run parsed. It exists for exactly one caller:
dream's CYCLE-mode W4.5 scan, whose visit is the event `last_pass` is supposed to record.
No other consumer passes it, and without it this script does not touch a byte
(pinned by friction-rollup.test.py's no-write case).

Usage:
  friction-rollup.py [--root DIR] [--view dream|trends|all] [--stale-days N]
                     [--threshold N] [--top N] [--stamp]

Output: one JSON document on stdout.
Exit 0 always, except 2 for a usage error.
"""

from __future__ import annotations

import argparse
import datetime
import glob
import json
import os
import re
import sys

# --- Calibrations. Each states where it comes from, so it can be retired on evidence. ---

# dream SKILL.md § Phase 2 "Cluster → skill-improvement (W4.5)": the ordinal mappings and
# the promotion bar. Read from there, never re-invented here; --threshold overrides.
IMPACT_NUM = {"S": 1, "M": 2, "L": 3}
FREQUENCY_NUM = {"rare": 1, "occasional": 2, "frequent": 3, "every-run": 4}
DEFAULT_THRESHOLD = 12

# friction-capture.md § How it feeds promotion: `perceptibility` gates the weight BEFORE
# it is compared to the bar — a `loud` entry is a sensor reading, never a candidate.
PROMOTABLE_PERCEPTIBILITY = {"silent", "misleading"}

# THE SWEEP OBLIGATION, and the reason this number is 21.
# `last_pass` records the date of the last COMPLETED dream CYCLE scan of that ledger —
# not the date of its last entry. dream CYCLE is a weekly scheduled run, so a swept
# ledger is re-stamped every 7 days whether or not it gained an entry. That is the whole
# point: it separates "this skill produced no new friction" (healthy, and invisible in an
# entry count) from "nobody has looked at this sensor" (a dead sensor that still reads
# live). 21 days = three missed weekly cycles, which is a scheduling failure rather than
# a slow week. `last_pass: never` is NOT overdue-by-degree — it is never-visited, and is
# reported under its own reason so it cannot be mistaken for a stale-by-a-day ledger.
DEFAULT_STALE_DAYS = 21

FRONTMATTER_RE = re.compile(r"\A---\s*\n(.*?)\n---\s*\n", re.S)
FIELD_RE = re.compile(r"^-\s+([A-Za-z_]+):\s*(.*)$")
ENTRY_RE = re.compile(r"^##\s+(\S+)\s*$")
# A cross-cutting friction is logged ONCE in its primary skill; other ledgers carry a
# `see <id> in <skill>` pointer. The schema counts once per id, so pointers never count.
POINTER_RE = re.compile(r"^\s*see\s+\S+\s+in\s+", re.I)


def parse_list(raw: str) -> list:
    raw = raw.strip()
    if raw.startswith("[") and raw.endswith("]"):
        raw = raw[1:-1]
    return [p.strip() for p in raw.split(",") if p.strip()]


def parse_ledger(path: str, root: str) -> dict:
    """Parse one FRICTIONS.md. Never raises on content — malformed is a reported state."""
    rel = os.path.relpath(path, root)
    out = {
        "path": rel,
        "skill": os.path.basename(os.path.dirname(path)),
        "created": None,
        "last_pass": None,
        "declared_entries": None,
        "malformed": [],
        "entries": [],
    }
    try:
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
    except OSError as exc:
        out["malformed"].append("unreadable: %s" % exc)
        return out

    fm = FRONTMATTER_RE.match(text)
    if not fm:
        out["malformed"].append("no frontmatter block")
        body = text
    else:
        body = text[fm.end():]
        for line in fm.group(1).splitlines():
            if ":" not in line:
                continue
            key, _, val = line.partition(":")
            key, val = key.strip(), val.strip().strip('"').strip("'")
            if key == "skill":
                out["skill"] = val or out["skill"]
            elif key == "created":
                out["created"] = val
            elif key == "last_pass":
                out["last_pass"] = val
            elif key == "entries":
                out["declared_entries"] = val
        if out["last_pass"] is None:
            out["malformed"].append("frontmatter has no last_pass field")

    current = None
    last_field = None
    for line in body.splitlines():
        m = ENTRY_RE.match(line)
        if m:
            current = {"id": m.group(1), "fields": {}}
            out["entries"].append(current)
            last_field = None
            continue
        if current is None:
            continue
        f = FIELD_RE.match(line)
        if f:
            last_field = f.group(1)
            current["fields"][last_field] = f.group(2).strip()
        elif last_field and line.strip():
            current["fields"][last_field] += " " + line.strip()
    return out


def score(entry_fields: dict, threshold: int) -> dict:
    """weight(id) = impact_num x frequency_num x recurrence — dream W4.5, verbatim."""
    impact = entry_fields.get("impact", "").strip()
    freq = entry_fields.get("frequency", "").strip()
    perc = entry_fields.get("perceptibility", "").strip()
    status = entry_fields.get("status", "").strip() or "open"
    raw_rec = entry_fields.get("recurrence", "").strip()
    unscorable = []
    if impact not in IMPACT_NUM:
        unscorable.append("impact=%r" % impact)
    if freq not in FREQUENCY_NUM:
        unscorable.append("frequency=%r" % freq)
    try:
        recurrence = int(raw_rec)
    except ValueError:
        recurrence = 0
        unscorable.append("recurrence=%r" % raw_rec)
    weight = None
    if not unscorable:
        weight = IMPACT_NUM[impact] * FREQUENCY_NUM[freq] * recurrence
    return {
        "impact": impact,
        "frequency": freq,
        "perceptibility": perc,
        "status": status,
        "recurrence": recurrence,
        "weight": weight,
        "unscorable": unscorable,
        # The bar AND the perceptibility gate AND status, together — an over-bar `loud`
        # entry is not a candidate, and neither is one already promoted or resolved.
        "promotable": bool(
            weight is not None
            and weight >= threshold
            and perc in PROMOTABLE_PERCEPTIBILITY
            and status == "open"
        ),
    }


def collect(root: str, threshold: int) -> tuple:
    ledgers = [
        parse_ledger(p, root)
        for p in sorted(glob.glob(os.path.join(root, "skills", "*", "FRICTIONS.md")))
    ]
    by_id = {}
    for led in ledgers:
        for raw in led["entries"]:
            fields = raw["fields"]
            eid = raw["id"]
            if POINTER_RE.match(fields.get("narrative", "")):
                led.setdefault("pointers", []).append(eid)
                continue
            if eid in by_id:  # counted ONCE per id, per the schema
                by_id[eid]["also_listed_in"].append(led["skill"])
                continue
            rec = {
                "id": eid,
                "skill": led["skill"],
                "path": led["path"],
                "related": parse_list(fields.get("related", "")),
                "first_seen": fields.get("first_seen", ""),
                "last_seen": fields.get("last_seen", ""),
                "proposed_fix": fields.get("proposed_fix", ""),
                "also_listed_in": [],
            }
            rec.update(score(fields, threshold))
            by_id[eid] = rec
    return ledgers, by_id


def cluster(by_id: dict) -> list:
    """Group ids by the `related` graph — one cluster yields one candidate, not N."""
    parent = {eid: eid for eid in by_id}

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    for eid, rec in by_id.items():
        for other in rec["related"]:
            if other in parent:  # a `related` id with no entry is a dangling pointer
                a, b = find(eid), find(other)
                if a != b:
                    parent[a] = b

    groups = {}
    for eid in by_id:
        groups.setdefault(find(eid), []).append(eid)

    out = []
    for members in groups.values():
        members.sort()
        weights = [by_id[m]["weight"] for m in members if by_id[m]["weight"] is not None]
        out.append({
            "members": members,
            "skills": sorted({by_id[m]["skill"] for m in members}),
            "max_weight": max(weights) if weights else None,
            "total_weight": sum(weights) if weights else None,
            # "An over-bar id OR cluster becomes a candidate" (dream W4.5): a cluster is
            # over the bar when a MEMBER is — summing near-duplicates would manufacture
            # candidates the bar was written to exclude.
            "promotable": any(by_id[m]["promotable"] for m in members),
            "proposed_fixes": [by_id[m]["proposed_fix"] for m in members
                               if by_id[m]["proposed_fix"]],
        })
    out.sort(key=lambda c: (-(c["max_weight"] or 0), c["members"][0]))
    return out


def days_since(date_str: str, today: datetime.date):
    try:
        return (today - datetime.date.fromisoformat(date_str)).days
    except (ValueError, TypeError):
        return None


def trends(ledgers: list, by_id: dict, stale_days: int, top: int, today: datetime.date) -> dict:
    per_id_by_skill = {}
    for rec in by_id.values():
        per_id_by_skill.setdefault(rec["skill"], []).append(rec)

    skills = []
    for led in ledgers:
        recs = per_id_by_skill.get(led["skill"], [])
        lp = (led["last_pass"] or "").strip().strip('"')
        age = days_since(lp, today)
        if lp in ("", "never", "None"):
            stale, reason = True, "never-visited"
        elif age is None:
            stale, reason = True, "unparseable last_pass: %r" % lp
        elif age > stale_days:
            stale, reason = True, "last scan %d days ago (> %d)" % (age, stale_days)
        else:
            stale, reason = False, None
        # Entries the last scan never saw. Never visited (age is None) => all of them.
        since = [r["id"] for r in recs
                 if age is None or (days_since(r["first_seen"], today) or 0) < age]
        weights = [r["weight"] for r in recs if r["weight"] is not None]
        skills.append({
            "skill": led["skill"],
            "path": led["path"],
            "last_pass": lp or "never",
            "days_since_last_pass": age,
            "stale": stale,
            "stale_reason": reason,
            "open_entries": sum(1 for r in recs if r["status"] == "open"),
            "total_entries": len(recs),
            "entries_since_last_pass": since,
            "max_weight": max(weights) if weights else None,
            "malformed": led["malformed"],
        })
    skills.sort(key=lambda s: (not s["stale"], s["skill"]))

    ranked = sorted(
        (r for r in by_id.values() if r["weight"] is not None),
        key=lambda r: (-r["weight"], r["id"]),
    )
    return {
        "stale_days": stale_days,
        "sweep_obligation": (
            "last_pass records the last COMPLETED dream CYCLE scan (weekly). A ledger with "
            "no new entries is healthy; a ledger nobody visited is a dead sensor."
        ),
        "stale_count": sum(1 for s in skills if s["stale"]),
        "skills": skills,
        "top_by_weight": [
            {k: r[k] for k in ("id", "skill", "weight", "status", "perceptibility", "promotable")}
            for r in ranked[:top]
        ],
    }


def stamp(ledgers: list, root: str, today: datetime.date) -> list:
    """The ONE write path: record this scan in every ledger it parsed."""
    stamped = []
    line_re = re.compile(r"^last_pass:.*$", re.M)
    for led in ledgers:
        path = os.path.join(root, led["path"])
        try:
            with open(path, encoding="utf-8") as fh:
                text = fh.read()
        except OSError:
            continue
        fm = FRONTMATTER_RE.match(text)
        if not fm:
            continue  # no frontmatter to stamp; already reported as malformed
        head, rest = text[: fm.end()], text[fm.end():]
        new_line = "last_pass: %s" % today.isoformat()
        if line_re.search(head):
            head = line_re.sub(new_line, head, count=1)
        else:
            head = head.replace("---\n", "---\n" + new_line + "\n", 1)
        if head + rest != text:
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(head + rest)
            stamped.append(led["path"])
    return stamped


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="FRICTIONS.md rollup — one parse, two views.")
    ap.add_argument("--root", default=os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                                   "..", "..", ".."))
    ap.add_argument("--view", choices=("dream", "trends", "all"), default="all")
    ap.add_argument("--stale-days", type=int, default=DEFAULT_STALE_DAYS)
    ap.add_argument("--threshold", type=int, default=DEFAULT_THRESHOLD)
    ap.add_argument("--top", type=int, default=10)
    ap.add_argument("--stamp", action="store_true",
                    help="dream CYCLE only: write last_pass into every parsed ledger")
    ap.add_argument("--today", default=None, help="ISO date override (tests)")
    ap.add_argument("--ledger", default=None,
                    help="parse ONE ledger and emit its raw entries (no cross-ledger "
                         "dedup). The single-ledger consumers — e.g. the ac2 "
                         "control<->friction integrity check — read this instead of "
                         "growing a second parser over the same files.")
    args = ap.parse_args(argv)

    if args.ledger:
        led = parse_ledger(os.path.abspath(args.ledger),
                           os.path.abspath(args.root or os.curdir))
        for raw in led["entries"]:
            raw["score"] = score(raw["fields"], args.threshold)
        json.dump({"ledger": led}, sys.stdout, indent=2)
        sys.stdout.write("\n")
        return 0

    root = os.path.abspath(args.root)
    today = (datetime.date.fromisoformat(args.today) if args.today
             else datetime.date.today())

    ledgers, by_id = collect(root, args.threshold)
    doc = {
        "generated": today.isoformat(),
        "root": root,
        "ledgers": len(ledgers),
        "ids": len(by_id),
        "malformed": [{"path": l["path"], "why": l["malformed"]} for l in ledgers if l["malformed"]],
    }
    if args.view in ("dream", "all"):
        doc["dream"] = {
            "threshold": args.threshold,
            "impact_num": IMPACT_NUM,
            "frequency_num": FREQUENCY_NUM,
            "promotable_perceptibility": sorted(PROMOTABLE_PERCEPTIBILITY),
            "entries": sorted(by_id.values(), key=lambda r: (-(r["weight"] or 0), r["id"])),
            "clusters": cluster(by_id),
        }
    if args.view in ("trends", "all"):
        doc["trends"] = trends(ledgers, by_id, args.stale_days, args.top, today)
    if args.stamp:
        doc["stamped"] = stamp(ledgers, root, today)

    json.dump(doc, sys.stdout, indent=2, sort_keys=False)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
