#!/usr/bin/env python3
"""friction-rollup.test.py — fixture harness for friction-rollup.py.

Both polarities on every claim: a stale fixture AND a fresh one, a promotable entry AND
an over-bar `loud` one that must NOT promote, a stamping run AND a default run that must
leave every byte alone. A one-sided case is satisfied by a check that always fires.

Run directly:  python3 skills/skill-builder/scripts/friction-rollup.test.py
Discovered automatically by scripts/run-all-harnesses.sh (glob over *.test.py).
"""

import datetime
import json
import os
import subprocess
import sys
import tempfile

DIR = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(DIR, "friction-rollup.py")
TODAY = "2026-08-27"

FAILURES = []


def ok(msg):
    print("  PASS: %s" % msg)


def bad(msg):
    print("  FAIL: %s" % msg)
    FAILURES.append(msg)


def check(cond, msg, detail=""):
    ok(msg) if cond else bad("%s%s" % (msg, (" — " + detail) if detail else ""))


def ledger(skill, last_pass, entries, created="2026-01-01", frontmatter=True):
    head = ("---\nskill: %s\ncreated: %s\nlast_pass: %s\nentries: %d\n---\n\n"
            % (skill, created, last_pass, len(entries))) if frontmatter else ""
    return head + "# %s — friction log\n\n" % skill + "\n".join(entries)


def entry(eid, impact="M", frequency="frequent", perceptibility="silent", recurrence=2,
          related="[]", status="open", first_seen="2026-08-20", narrative="it broke."):
    return ("## %s\n- skills: [x]\n- impact: %s\n- frequency: %s\n- perceptibility: %s\n"
            "- recurrence: %s\n- related: %s\n- first_seen: %s\n- last_seen: %s\n"
            "- stage: manual\n- status: %s\n- proposed_fix: fix %s.\n- narrative: %s\n"
            % (eid, impact, frequency, perceptibility, recurrence, related, first_seen,
               first_seen, status, eid, narrative))


def build_root(tmp):
    """A miniature registry: one ledger per case, so every claim has its own subject."""
    def write(skill, text):
        d = os.path.join(tmp, "skills", skill)
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, "FRICTIONS.md"), "w", encoding="utf-8") as fh:
            fh.write(text)

    # fresh: scanned 3 days ago, one over-bar promotable entry (2 x 3 x 2 = 12 >= 12)
    write("fresh-skill", ledger("fresh-skill", "2026-08-24",
                                [entry("over-bar", recurrence=2)]))
    # stale: scanned 60 days ago — well past the 21-day obligation
    write("stale-skill", ledger("stale-skill", "2026-06-28",
                                [entry("stale-one", impact="S", frequency="rare",
                                       recurrence=1)]))
    # never visited: a dead sensor that reads live
    write("never-skill", ledger("never-skill", "never", [entry("never-one")]))
    # malformed: no frontmatter at all
    write("broken-skill", ledger("broken-skill", "", [entry("broken-one")],
                                 frontmatter=False))
    # gates: an over-bar LOUD entry (must not promote) + a related pair (one cluster)
    write("gate-skill", ledger("gate-skill", "2026-08-26", [
        entry("loud-big", impact="L", frequency="every-run", recurrence=5,
              perceptibility="loud"),
        entry("promoted-big", recurrence=9, status="promoted"),
        entry("cluster-a", related="[cluster-b]"),
        entry("cluster-b", related="[cluster-a]", impact="S", frequency="rare",
              recurrence=1),
        entry("see-elsewhere", narrative="see over-bar in fresh-skill"),
        entry("unscorable", impact="XL", frequency="sometimes", recurrence="lots"),
    ]))
    return tmp


def run(root, *args):
    out = subprocess.run([sys.executable, SCRIPT, "--root", root, "--today", TODAY] + list(args),
                         capture_output=True, text=True, timeout=120)
    return out


def snapshot(root):
    seen = {}
    for dirpath, _, files in os.walk(root):
        for f in files:
            p = os.path.join(dirpath, f)
            with open(p, encoding="utf-8") as fh:
                seen[os.path.relpath(p, root)] = fh.read()
    return seen


def main():
    tmp = tempfile.mkdtemp()
    root = build_root(tmp)

    # --- Case 1: the script runs on fixtures and emits parseable JSON, exit 0 ----------
    res = run(root)
    try:
        doc = json.loads(res.stdout)
        check(res.returncode == 0, "Case 1: rollup exits 0 on a fixture registry",
              "rc=%d stderr=%s" % (res.returncode, res.stderr))
    except json.JSONDecodeError as exc:
        bad("Case 1: stdout is not JSON — %s / stderr=%s" % (exc, res.stderr))
        print("\n%d case(s) FAILED." % len(FAILURES))
        return 1

    # --- Case 2: STALE ledger flagged; FRESH one is not (both polarities) -------------
    by_skill = {s["skill"]: s for s in doc["trends"]["skills"]}
    check(by_skill["stale-skill"]["stale"] and "60 days" in (by_skill["stale-skill"]["stale_reason"] or ""),
          "Case 2a: a ledger last scanned 60 days ago is FLAGGED stale",
          str(by_skill["stale-skill"]))
    check(not by_skill["fresh-skill"]["stale"],
          "Case 2b: a ledger scanned 3 days ago is NOT flagged",
          str(by_skill["fresh-skill"]))

    # --- Case 3: `last_pass: never` is never-visited, not overdue-by-degree ------------
    check(by_skill["never-skill"]["stale"]
          and by_skill["never-skill"]["stale_reason"] == "never-visited",
          "Case 3: 'last_pass: never' is reported as never-visited",
          str(by_skill["never-skill"]))

    # --- Case 4: malformed frontmatter is REPORTED, never a crash ---------------------
    check(any("broken-skill" in m["path"] for m in doc["malformed"]) and res.returncode == 0,
          "Case 4: a ledger with no frontmatter is reported malformed, exit still 0",
          str(doc["malformed"]))

    # --- Case 5: the weight formula and the bar ---------------------------------------
    entries = {e["id"]: e for e in doc["dream"]["entries"]}
    check(entries["over-bar"]["weight"] == 12 and entries["over-bar"]["promotable"],
          "Case 5a: M x frequent x 2 = 12 clears the bar and is promotable",
          str(entries["over-bar"]))
    check(entries["stale-one"]["weight"] == 1 and not entries["stale-one"]["promotable"],
          "Case 5b: S x rare x 1 = 1 does not clear the bar",
          str(entries["stale-one"]))

    # --- Case 6: the perceptibility gate outranks the bar ------------------------------
    check(entries["loud-big"]["weight"] == 60 and not entries["loud-big"]["promotable"],
          "Case 6a: an over-bar `loud` entry scores 60 but is NOT promotable",
          str(entries["loud-big"]))
    check(entries["promoted-big"]["weight"] == 54 and not entries["promoted-big"]["promotable"],
          "Case 6b: an already-`promoted` entry is not re-promoted",
          str(entries["promoted-big"]))

    # --- Case 7: `related` grouping yields ONE cluster, not N near-duplicates ----------
    clusters = {tuple(c["members"]): c for c in doc["dream"]["clusters"]}
    check(("cluster-a", "cluster-b") in clusters,
          "Case 7a: two ids joined by `related` land in ONE cluster",
          str(list(clusters)))
    pair = clusters.get(("cluster-a", "cluster-b"))
    check(pair and pair["promotable"] and pair["max_weight"] == 12,
          "Case 7b: the cluster is over the bar because a MEMBER is (max, not sum)",
          str(pair))

    # --- Case 8: pointer entries and unscorable entries -------------------------------
    check("see-elsewhere" not in entries,
          "Case 8a: a `see <id> in <skill>` pointer entry is not counted",
          str(sorted(entries)))
    check(entries["unscorable"]["weight"] is None
          and entries["unscorable"]["unscorable"]
          and not entries["unscorable"]["promotable"],
          "Case 8b: an entry with junk ordinals is unscorable, not silently zero",
          str(entries["unscorable"]))

    # --- Case 9: entries the last scan never saw --------------------------------------
    check(by_skill["stale-skill"]["entries_since_last_pass"] == ["stale-one"],
          "Case 9a: an entry first seen after the last scan is listed as new",
          str(by_skill["stale-skill"]))
    check(by_skill["never-skill"]["entries_since_last_pass"] == ["never-one"],
          "Case 9b: on a never-visited ledger every entry counts as unseen",
          str(by_skill["never-skill"]))

    # --- Case 10: ONE parse, two views — the views cannot disagree ---------------------
    top = {t["id"]: t["weight"] for t in doc["trends"]["top_by_weight"]}
    check(all(entries[i]["weight"] == w for i, w in top.items()) and top,
          "Case 10: trends' top-by-weight matches the dream view's weights exactly",
          str(top))

    # --- Case 11: READ-ONLY by default — the default run writes NOTHING ---------------
    before = snapshot(root)
    run(root, "--view", "trends")
    check(snapshot(root) == before,
          "Case 11: a default run leaves every ledger byte-identical")

    # --- Case 12: --stamp is the write path, and it stamps EVERY parsed ledger --------
    res = run(root, "--stamp")
    doc2 = json.loads(res.stdout)
    stamped = set(doc2.get("stamped", []))
    check(len(stamped) == 4, "Case 12a: --stamp writes last_pass to all 4 well-formed ledgers",
          str(sorted(stamped)))
    after = snapshot(root)
    check(("last_pass: %s" % TODAY) in after["skills/never-skill/FRICTIONS.md"],
          "Case 12b: a never-visited ledger now carries today's scan date")
    check(after["skills/broken-skill/FRICTIONS.md"] == before["skills/broken-skill/FRICTIONS.md"],
          "Case 12c: a frontmatter-less ledger is left untouched, not repaired blindly")

    # --- Case 13: the stamp clears staleness — the sensor is now falsifiable ----------
    doc3 = json.loads(run(root, "--view", "trends").stdout)
    check(all(not s["stale"] for s in doc3["trends"]["skills"] if s["skill"] != "broken-skill"),
          "Case 13: after a stamped scan no well-formed ledger reads stale",
          str([(s["skill"], s["stale_reason"]) for s in doc3["trends"]["skills"]]))

    # --- Case 14: the live registry parses — the fixtures are not the only subject -----
    live_root = os.path.abspath(os.path.join(DIR, "..", "..", ".."))
    res = subprocess.run([sys.executable, SCRIPT, "--root", live_root, "--view", "trends"],
                         capture_output=True, text=True, timeout=120)
    try:
        live = json.loads(res.stdout)
        check(res.returncode == 0 and live["ledgers"] >= 15,
              "Case 14: the live registry's ledgers parse (%s found)" % live.get("ledgers"),
              res.stderr)
    except json.JSONDecodeError:
        bad("Case 14: live registry run did not emit JSON — %s" % res.stderr[:400])

    # --- Case 15: the dream path and the dashboard path cannot disagree ---------------
    # The seam this bead exists to close: two consumers, one computation. Run the two
    # consumer invocations SEPARATELY and demand identical weights, bar and clusters.
    d_only = json.loads(run(root, "--view", "dream").stdout)
    t_only = json.loads(run(root, "--view", "trends").stdout)
    dmap = {e["id"]: e["weight"] for e in d_only["dream"]["entries"]}
    tmap = {t["id"]: t["weight"] for t in t_only["trends"]["top_by_weight"]}
    check(bool(tmap) and all(dmap[i] == w for i, w in tmap.items())
          and d_only["dream"]["threshold"] == doc["dream"]["threshold"]
          and [c["members"] for c in d_only["dream"]["clusters"]]
              == [c["members"] for c in doc["dream"]["clusters"]],
          "Case 15: dream path and dashboard path agree on weights, bar and clusters")

    print()
    if FAILURES:
        print("%d fixture test(s) FAILED." % len(FAILURES))
        return 1
    print("All friction-rollup fixture tests passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
