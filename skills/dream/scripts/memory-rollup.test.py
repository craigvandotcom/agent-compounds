#!/usr/bin/env python3
"""memory-rollup.test.py — the executable contract of memory-rollup.py.

Every case runs the script as a subprocess against fixture lanes inside one temp dir,
with HOME pointed into it, so no real memory is read. Pinned:
  each kind fires on its positive fixture and stays silent on its negative
  the JSON contract: top-level keys, row keys, kinds/actions in their sets, score-desc
  verified_against (date or sha) suppresses dead-path and restarts the stale clock
  an unreadable lane lands in `errors` (exit 0 while another lane reads; 2 when none does)

Run: python3 skills/dream/scripts/memory-rollup.test.py   (exit 0 = all pass)
"""

import json
import os
import subprocess
import sys
import tempfile

SCRIPT = os.path.join(os.path.dirname(os.path.realpath(__file__)), "memory-rollup.py")
TODAY = "2026-09-22"
KINDS = {"retired-marker", "duplicate", "dead-path", "stale", "index-drift", "dead-wikilink"}
ACTIONS = {"retire", "merge", "fix-path", "review", "fix-index"}
fails = 0


def check(ok, label):
    global fails
    print(("  ok    " if ok else "  FAIL  ") + label)
    fails += 0 if ok else 1


def note(lane, name, body, fm="", desc="fixture"):
    with open(os.path.join(lane, name + ".md"), "w", encoding="utf-8") as f:
        f.write(f"---\nname: {name}\ndescription: \"{desc}\"\n{fm}---\n\n{body}\n")


def index(lane, names, extra=""):
    with open(os.path.join(lane, "MEMORY.md"), "w", encoding="utf-8") as f:
        f.write("# index\n\nFormat: `- [Title](slug.md) — hook`\n\n")
        f.writelines(f"- [{n}]({n}.md) — x\n" for n in names)
        f.write(extra)


def git(repo, *args, date=None):
    env = dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t",
               GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@t")
    if date:
        env["GIT_AUTHOR_DATE"] = env["GIT_COMMITTER_DATE"] = f"{date}T12:00:00"
    return subprocess.run(["git", "-C", repo, *args], env=env, capture_output=True,
                          text=True, check=True).stdout.strip()


def run(home, *args):
    env = dict(os.environ, HOME=home)
    out = subprocess.run([sys.executable, SCRIPT, "--json", "--today", TODAY, *args],
                         env=env, capture_output=True, text=True)
    try:
        doc = json.loads(out.stdout)
    except ValueError:
        doc = {}
    return out.returncode, doc


def rows_for(doc, kind, fname):
    return [r for r in doc.get("rows", []) if r["kind"] == kind
            and any(f.endswith("/" + fname) for f in r["files"])]


with tempfile.TemporaryDirectory() as home:
    home = os.path.realpath(home)
    repo = os.path.join(home, "org")
    a, b = os.path.join(repo, "lane-a"), os.path.join(repo, "lane-b")
    wiki = os.path.join(home, "wiki")
    for d in (a, b, wiki, os.path.join(home, "present")):
        os.makedirs(d)
    open(os.path.join(home, "present", "file.txt"), "w").close()
    open(os.path.join(wiki, "wiki-page.md"), "w").close()
    git(repo, "init", "-q")

    dup_body = " ".join(f"word{i} shared phrase about the same fact" for i in range(40))
    note(a, "clean", "Links [[other]] and [[wiki-page]]. Cites `~/present/file.txt`.")
    note(a, "other", "A distinct note about something else entirely, nothing shared here.")
    note(a, "orphan", "Not in the index.")
    note(a, "wikidead", "Points at [[no-such-note]].")
    note(a, "sup-field", "Body.", fm="metadata:\n  supersededBy: clean\n")
    note(a, "sup-lead", "Body.", desc="⚠ SUPERSEDED 2026-07-01 by [[clean]]: reversed")
    note(a, "mentions", "Body.", desc="br rejects slashes; the wave advice was RETIRED later")
    note(a, "dup-one", dup_body)
    note(a, "dup-two", dup_body + " one extra tail")
    note(a, "same-name", "Lane A copy of a fact with its own wording one.")
    note(b, "same-name", "Lane B copy, worded quite differently from the other two.")
    note(a, "deadpath", "See `~/gone/file.txt` and `org/nowhere.sh`. "
                        "Skips `~/x/YYYY-MM-DD.log`, `scripts/x.sh`, `~/.cache/c`, `/tmp/t`.")
    note(a, "kept-date", "See `~/gone/kept.txt`.", fm="verified_against: 2026-09-20\n")
    note(a, "kept-sha", "See `~/gone/sha.txt`.")
    note(a, "old", "An old fact recorded 2026-01-02 and never revisited.")
    note(a, "old-but-dated", "Old commit, but the body cites 2026-09-01 evidence.")
    index(a, ["clean", "other", "wikidead", "sup-field", "sup-lead", "mentions", "dup-one",
              "dup-two", "same-name", "deadpath", "kept-date", "kept-sha", "old",
              "old-but-dated"], extra="- [ghost](ghost.md) — gone\n")
    index(b, ["same-name"])
    git(repo, "add", ".")
    git(repo, "commit", "-qm", "fixtures", date="2026-01-03")
    sha = git(repo, "rev-parse", "HEAD")
    note(a, "kept-sha", "See `~/gone/sha.txt`.", fm=f"verified_against: {sha}\n")
    git(repo, "commit", "-qam", "stamp sha", date="2026-01-03")

    rc, doc = run(home, "--lane", a, "--lane", b, "--link-root", wiki,
                  "--lane", os.path.join(home, "missing-lane"))

    check(rc == 0, "exit 0 while at least one lane reads")
    check(set(doc) == {"generated", "lanes", "rows", "errors"}, "top-level keys are the contract")
    rows = doc.get("rows", [])
    check(all(set(r) == {"kind", "files", "score", "evidence", "action"} for r in rows),
          "every row carries exactly kind/files/score/evidence/action")
    check(all(r["kind"] in KINDS and r["action"] in ACTIONS for r in rows),
          "kinds and actions stay inside their sets")
    check([r["score"] for r in rows] == sorted((r["score"] for r in rows), reverse=True),
          "rows sorted by score descending")
    check(any("missing-lane" in e["lane"] for e in doc.get("errors", [])),
          "an unreadable lane lands in errors")

    # index-drift
    check(bool(rows_for(doc, "index-drift", "orphan.md")), "index-drift: unindexed note flagged")
    check(any("ghost.md" in r["evidence"] for r in doc["rows"] if r["kind"] == "index-drift"),
          "index-drift: dead index line flagged")
    check(not any("slug.md" in r["evidence"] for r in rows), "index-drift: inline-code template ignored")
    check(not rows_for(doc, "index-drift", "clean.md"), "index-drift: indexed note silent")
    # dead-wikilink
    check(bool(rows_for(doc, "dead-wikilink", "wikidead.md")), "dead-wikilink: [[no-such-note]] flagged")
    check(not rows_for(doc, "dead-wikilink", "clean.md"),
          "dead-wikilink: note and link-root targets resolve")
    # retired-marker
    check(bool(rows_for(doc, "retired-marker", "sup-field.md")), "retired: supersededBy field flagged")
    check(bool(rows_for(doc, "retired-marker", "sup-lead.md")), "retired: description opening SUPERSEDED flagged")
    check(not rows_for(doc, "retired-marker", "mentions.md"), "retired: a mid-sentence RETIRED is silent")
    check(not rows_for(doc, "retired-marker", "orphan.md"), "retired: clean note silent")
    # duplicate
    check(bool(rows_for(doc, "duplicate", "dup-one.md")), "duplicate: near-identical bodies flagged")
    check(any(r["kind"] == "duplicate" and len(r["files"]) == 2 and "lanes" in r["evidence"]
              for r in rows_for(doc, "duplicate", "same-name.md")), "duplicate: one filename in two lanes")
    check(not rows_for(doc, "duplicate", "other.md"), "duplicate: distinct note silent")
    # dead-path
    dp = rows_for(doc, "dead-path", "deadpath.md")
    ev = dp[0]["evidence"] if dp else ""
    check("~/gone/file.txt" in ev and "org/nowhere.sh" in ev, "dead-path: ~/ and $HOME-child tokens flagged")
    check(not any(t in ev for t in ("YYYY", "x.sh", ".cache", "/tmp")),
          "dead-path: placeholders, dotdirs and /tmp never judged")
    check(not rows_for(doc, "dead-path", "clean.md"), "dead-path: an existing path is silent")
    # verified_against — the Keep loop
    check(not rows_for(doc, "dead-path", "kept-date.md"), "verified date suppresses dead-path")
    check(not rows_for(doc, "dead-path", "kept-sha.md"), "verified sha suppresses dead-path")
    check(not rows_for(doc, "stale", "kept-date.md"), "verified date restarts the stale clock")
    # stale
    st = rows_for(doc, "stale", "old.md")
    check(bool(st) and st[0]["action"] == "review", "stale: old commit and old body -> review")
    check(not rows_for(doc, "stale", "old-but-dated.md"), "stale: a recent body date keeps it fresh")

    rc, doc = run(home, "--lane", os.path.join(home, "missing-lane"))
    check(rc == 2 and doc.get("errors"), "no readable lane -> exit 2 with errors")

print(f"memory-rollup.test.py: {fails} failure(s)")
sys.exit(1 if fails else 0)
