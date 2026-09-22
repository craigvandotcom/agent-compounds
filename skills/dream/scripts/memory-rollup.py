#!/usr/bin/env python3
"""memory-rollup.py — ONE read-only pass over the memory lanes, ranked hygiene rows.

The memory twin of `skill-builder/scripts/friction-rollup.py`: it scores what is wrong
with the memory substrate so a human can rule on it (ac-human's memory card, dream's
GATHER phase). It never edits a memory; every row is a proposal.

Signals, each chosen for a low false-positive rate:
  index-drift    MEMORY.md names a missing file, or a file has no index line   → fix-index
  dead-wikilink  [[slug]] resolves to no memory and no link root               → fix-path
  retired-marker the note declares itself retired (frontmatter status/supersededBy,
                 or a description that opens RETIRED/SUPERSEDED/DEPRECATED)
                 while still indexed                                           → retire
  duplicate      body word-3-gram Jaccard >= --dup-threshold, or one filename
                 in two lanes                                                  → merge
  dead-path      a `backticked` path anchored at / (under $HOME), ~/ or a $HOME
                 child dir that does not exist; bare names are never judged    → fix-path
  stale          last commit AND newest body date AND verification all older
                 than --stale-days; means "look at it", never "retire it"      → review

No usage-based decay: recall volume is not evidence a note is false.

THE KEEP LOOP. `verified_against: <YYYY-MM-DD | commit sha>` in a note's frontmatter
suppresses its dead-path rows when the verification is no older than the note's last
commit, and restarts its stale clock. A sha resolves in the lane's own repo; one that
does not resolve counts as unverified.

Lanes come from `engine/machine.sh --memory` (this machine's machine.json `memory` key),
or from repeated `--lane`. A lane that cannot be read is an `errors` row, never skipped.

Usage:
  memory-rollup.py [--lane DIR]... [--link-root DIR]... [--json] [--today YYYY-MM-DD]
                   [--top N] [--stale-days N] [--dup-threshold F]

Output (--json): {"generated", "lanes": [{path, files}], "rows": [{kind, files, score,
evidence, action}] sorted by score desc, "errors": [{lane, why}]}.
Exit: 0 scored (rows are advisory) · 2 no lane could be read.
"""

import argparse
import datetime
import json
import os
import re
import subprocess
import sys
from collections import defaultdict

SKIP_FILES = {"MEMORY.md", "README.md"}
FRONTMATTER_RE = re.compile(r"\A---\s*\n(.*?)\n---\s*\n", re.S)
INDEX_LINK_RE = re.compile(r"\[([^\]]*)\]\(([^)#/]+\.md)(#[^)]*)?\)")
INLINE_CODE_RE = re.compile(r"`[^`\n]*`")
WIKILINK_RE = re.compile(r"\[\[([A-Za-z0-9][A-Za-z0-9._-]*)(?:[|#][^\]]*)?\]\]")
FENCE_RE = re.compile(r"^```.*?^```", re.S | re.M)
DATE_RE = re.compile(r"\b(20\d\d-[01]\d-[0-3]\d)\b")
SHA_RE = re.compile(r"\b([0-9a-f]{7,40})\b")
WORD_RE = re.compile(r"[a-z0-9]+")
RETIRED_LEAD_RE = re.compile(r"^\W*(RETIRED|SUPERSEDED|DEPRECATED)\b")
RETIRED_STATUS = {"retired", "superseded", "deprecated", "archived", "obsolete"}
PLACEHOLDER_RE = re.compile(r"[<>*{}$…]|\.\.\.|\s|YYYY|NNN|XXX|(^|/)[a-z]\.[a-z]+$")
HOST_SPECIFIC = ("Library/",)  # macOS home dirs: another host's layout, not this one's
SYSTEM_TMP = ("/tmp", "/dev", "/proc", "/var/tmp", "/run")

# Base scores: fix-cost x certainty. Structural rows lead; stale trails.
SCORE = {"index-drift": 9.0, "dead-wikilink": 8.0, "retired-field": 7.0,
         "retired-word": 6.0, "same-filename": 6.0, "dead-path": 4.0}


def field(fm, key):
    """First `key: value` anywhere in a frontmatter block (flat or nested shape)."""
    m = re.search(rf"^\s*{key}:\s*(.*?)\s*$", fm, re.M)
    return m.group(1).strip().strip("'\"") if m else ""


def read_text(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


def repo_of(path):
    try:
        out = subprocess.run(["git", "-C", path, "rev-parse", "--show-toplevel"],
                             capture_output=True, text=True, timeout=10)
        return out.stdout.strip() if out.returncode == 0 else None
    except (OSError, subprocess.SubprocessError):
        return None


def commit_dates(repo, lane):
    """{abs path: last commit date} for every file under lane, in one git call."""
    dates = {}
    try:
        out = subprocess.run(
            ["git", "-C", repo, "log", "--format=%x00%cs", "--name-only", "--", lane],
            capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.SubprocessError):
        return None
    if out.returncode != 0:
        return None
    for chunk in out.stdout.split("\x00")[1:]:
        lines = chunk.strip().splitlines()
        if not lines:
            continue
        day = datetime.date.fromisoformat(lines[0])
        for rel in lines[1:]:
            dates.setdefault(os.path.join(repo, rel), day)  # newest first: keep first
    return dates


def sha_date(repo, sha, cache):
    key = (repo, sha)
    if key not in cache:
        cache[key] = None
        try:
            out = subprocess.run(["git", "-C", repo, "show", "-s", "--format=%cs", sha],
                                 capture_output=True, text=True, timeout=10)
            if out.returncode == 0 and out.stdout.strip():
                cache[key] = datetime.date.fromisoformat(out.stdout.strip().splitlines()[-1])
        except (OSError, subprocess.SubprocessError, ValueError):
            pass
    return cache[key]


def verified_date(value, repo, cache):
    if not value:
        return None
    m = DATE_RE.search(value)
    if m:
        return datetime.date.fromisoformat(m.group(1))
    m = SHA_RE.search(value)
    return sha_date(repo, m.group(1), cache) if (m and repo) else None


def lanes_from_machine():
    here = os.path.dirname(os.path.realpath(__file__))
    reader = os.path.join(here, "..", "..", "..", "engine", "machine.sh")
    try:
        out = subprocess.run([reader, "--memory"], capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.SubprocessError) as e:
        return [], [], f"engine/machine.sh --memory did not run: {e}"
    if out.returncode != 0:
        return [], [], (out.stderr.strip().splitlines() or [f"exit {out.returncode}"])[0]
    lanes, links = [], []
    for line in out.stdout.splitlines():
        kind, _, path = line.partition("\t")
        (lanes if kind == "lane" else links).append(path)
    return lanes, links, None


def shingles(body):
    words = WORD_RE.findall(body.lower())
    return {" ".join(words[i:i + 3]) for i in range(len(words) - 2)}


def anchored_paths(body, home, home_dirs):
    """(token, abs path) for backticked paths this script is allowed to judge."""
    prose = FENCE_RE.sub("", body)
    for m in INLINE_CODE_RE.finditer(prose):
        tok = m.group(0)[1:-1].strip().rstrip(".,;:)")
        tok = re.sub(r":\d+(-\d+)?$", "", tok).split("#")[0]
        if not tok or PLACEHOLDER_RE.search(tok) or "://" in tok:
            continue
        if tok.startswith("~/"):
            rel = tok[2:]
            if rel.startswith(".") or rel.startswith(HOST_SPECIFIC):
                continue  # host-specific dotdir or layout
            yield tok, os.path.join(home, rel)
        elif tok.startswith("/"):
            if tok.startswith(SYSTEM_TMP) or not tok.startswith(home + "/"):
                continue  # only $HOME is this machine's to judge
            if tok[len(home) + 1:].startswith((".",) + HOST_SPECIFIC):
                continue
            yield tok, tok
        elif "/" in tok and tok.split("/", 1)[0] in home_dirs:
            yield tok, os.path.join(home, tok)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--lane", action="append", default=[], help="memory dir (repeatable)")
    ap.add_argument("--link-root", action="append", default=[], help="extra [[slug]] dir")
    ap.add_argument("--json", action="store_true", help="emit the JSON document")
    ap.add_argument("--today", help="pin today (YYYY-MM-DD) for reproducible scoring")
    ap.add_argument("--top", type=int, default=10, help="rows in the human table")
    ap.add_argument("--stale-days", type=int, default=90)
    ap.add_argument("--dup-threshold", type=float, default=0.2)
    args = ap.parse_args()

    today = datetime.date.fromisoformat(args.today) if args.today else datetime.date.today()
    home = os.path.expanduser("~")
    errors, rows = [], []
    lanes, links = args.lane, args.link_root
    if not lanes:
        lanes, machine_links, why = lanes_from_machine()
        links = links or machine_links
        if why:
            errors.append({"lane": "engine/machine.sh --memory", "why": why})
        elif not lanes:
            errors.append({"lane": "machine.json", "why": "no memory.lanes configured"})
    try:
        home_dirs = {d for d in os.listdir(home)
                     if not d.startswith(".") and os.path.isdir(os.path.join(home, d))}
    except OSError:
        home_dirs = set()

    notes, lane_info = [], []
    for lane in lanes:
        lane = os.path.realpath(os.path.expanduser(lane))
        try:
            names = sorted(f for f in os.listdir(lane) if f.endswith(".md"))
        except OSError as e:
            errors.append({"lane": lane, "why": e.strerror or str(e)})
            continue
        repo = repo_of(lane)
        dates = commit_dates(repo, lane) if repo else None
        if dates is None:
            errors.append({"lane": lane, "why": "no git history — stale not scored"})
        index_path = os.path.join(lane, "MEMORY.md")
        index = None
        if os.path.isfile(index_path):
            index = defaultdict(list)
            try:
                index_text = read_text(index_path)
            except OSError as e:
                errors.append({"lane": index_path, "why": e.strerror or str(e)})
                index_text = ""
            for i, line in enumerate(index_text.splitlines(), 1):
                for m in INDEX_LINK_RE.finditer(INLINE_CODE_RE.sub("", line)):
                    index[m.group(2)].append(i)
        facts = [f for f in names if f not in SKIP_FILES]
        lane_info.append({"path": lane, "files": len(facts)})
        for f in facts:
            path = os.path.join(lane, f)
            try:
                text = read_text(path)
            except OSError as e:
                errors.append({"lane": path, "why": e.strerror or str(e)})
                continue
            fm_m = FRONTMATTER_RE.match(text)
            fm = fm_m.group(1) if fm_m else ""
            notes.append({"lane": lane, "file": f, "path": path, "repo": repo,
                          "fm": fm, "body": text[fm_m.end():] if fm_m else text,
                          "text": text, "commit": (dates or {}).get(path),
                          "indexed": index is None or f in index})
        if index is not None:
            for target, lines in sorted(index.items()):
                if not os.path.isfile(os.path.join(lane, target)):
                    rows.append(("index-drift", [index_path], SCORE["index-drift"],
                                 f"MEMORY.md:{lines[0]} links {target}, which does not exist",
                                 "fix-index"))
            for f in facts:
                if f not in index:
                    rows.append(("index-drift", [os.path.join(lane, f)], SCORE["index-drift"],
                                 "no MEMORY.md line points at this note", "fix-index"))

    # dead wikilinks — resolve across every lane and every link root
    slugs = {os.path.splitext(n["file"])[0] for n in notes}
    for root in links:
        try:
            slugs |= {os.path.splitext(f)[0] for f in os.listdir(os.path.expanduser(root))
                      if f.endswith(".md")}
        except OSError as e:
            errors.append({"lane": root, "why": f"link root unreadable: {e.strerror or e}"})
    for n in notes:
        for i, line in enumerate(n["text"].splitlines(), 1):
            for m in WIKILINK_RE.finditer(line):
                if m.group(1) not in slugs:
                    rows.append(("dead-wikilink", [n["path"]], SCORE["dead-wikilink"],
                                 f"line {i}: [[{m.group(1)}]] resolves to no note", "fix-path"))

    # retired markers — the note says so itself
    for n in notes:
        if not n["indexed"]:
            continue
        status, sup = field(n["fm"], "status").lower(), field(n["fm"], "supersededBy")
        lead = RETIRED_LEAD_RE.search(field(n["fm"], "description"))
        if sup or status.split(" ")[0] in RETIRED_STATUS:
            why = f"supersededBy: {sup}" if sup else f"status: {status}"
            rows.append(("retired-marker", [n["path"]], SCORE["retired-field"],
                         f"{why}, still indexed", "retire"))
        elif lead:
            rows.append(("retired-marker", [n["path"]], SCORE["retired-word"],
                         f"description opens {lead.group(1)}, still indexed", "retire"))

    # duplicates — shared-shingle counts via an inverted index; boilerplate shingles skipped
    sh = [shingles(n["body"]) for n in notes]
    post = defaultdict(list)
    for i, s in enumerate(sh):
        for g in s:
            post[g].append(i)
    shared = defaultdict(int)
    for ids in post.values():
        if 1 < len(ids) <= 40:
            for a in range(len(ids)):
                for b in range(a + 1, len(ids)):
                    shared[(ids[a], ids[b])] += 1
    for (a, b), k in shared.items():
        j = k / (len(sh[a]) + len(sh[b]) - k)
        if j >= args.dup_threshold:
            rows.append(("duplicate", sorted([notes[a]["path"], notes[b]["path"]]),
                         round(4 + 6 * j, 2), f"body 3-gram Jaccard {j:.2f}", "merge"))
    by_name = defaultdict(list)
    for n in notes:
        by_name[n["file"]].append(n["path"])
    for f, paths in sorted(by_name.items()):
        if len(paths) > 1:
            rows.append(("duplicate", sorted(paths), SCORE["same-filename"],
                         f"{f} exists in {len(paths)} lanes", "merge"))

    # dead anchored paths and stale notes — both answer to verified_against
    cache = {}
    for n in notes:
        verified = verified_date(field(n["fm"], "verified_against"), n["repo"], cache)
        kept = verified and n["commit"] and verified >= n["commit"]
        if not kept:
            dead = sorted({tok for tok, p in anchored_paths(n["body"], home, home_dirs)
                           if not os.path.exists(p)})
            if dead:
                rows.append(("dead-path", [n["path"]], SCORE["dead-path"],
                             "missing: " + ", ".join(dead[:3]) +
                             (f" (+{len(dead) - 3})" if len(dead) > 3 else ""), "fix-path"))
        if n["commit"]:
            body_dates = [datetime.date.fromisoformat(d) for d in DATE_RE.findall(n["text"])
                          if d <= today.isoformat()]
            newest = max([n["commit"]] + body_dates + ([verified] if verified else []))
            age = (today - newest).days
            if age > args.stale_days:
                rows.append(("stale", [n["path"]], round(1 + min((age - args.stale_days) / 365, 1), 2),
                             f"newest evidence {newest} ({age}d): commit {n['commit']}"
                             + ("" if verified else ", never verified"), "review"))

    rows = [dict(zip(("kind", "files", "score", "evidence", "action"), r)) for r in rows]
    rows.sort(key=lambda r: (-r["score"], r["kind"], r["files"]))
    doc = {"generated": today.isoformat(), "lanes": lane_info, "rows": rows, "errors": errors}

    if args.json:
        print(json.dumps(doc, indent=2))
    else:
        counts = defaultdict(int)
        for r in rows:
            counts[r["kind"]] += 1
        print(f"memory-rollup {doc['generated']} · {sum(l['files'] for l in lane_info)} notes"
              f" in {len(lane_info)} lanes · " +
              (" · ".join(f"{k} {v}" for k, v in sorted(counts.items())) or "clean"))
        for r in rows[:args.top]:
            shown = ", ".join(os.path.relpath(f, home) for f in r["files"])
            print(f"  {r['score']:5.2f}  {r['kind']:<14} {r['action']:<9} {shown}  — {r['evidence']}")
        for e in errors:
            print(f"  ? {e['lane']}: {e['why']}")
    return 0 if lane_info else 2


if __name__ == "__main__":
    sys.exit(main())
