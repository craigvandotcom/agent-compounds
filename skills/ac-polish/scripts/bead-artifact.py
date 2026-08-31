#!/usr/bin/env python3
"""bead-artifact.py — export a bead set to ONE polish artifact, and write it back.

ac-polish bead mode measures a file. This is the sole sanctioned way to build that file
and to land it again.

Both halves FAIL CLOSED. A setup error is NOT-GATED, never a silent no-op; a partial write
is reported and exits non-zero.

Lifecycle labels (`refined` / `unrefined`) are NEVER written here directly. `skills/_tools/stamp-refined.sh`
owns that pair. An artifact holds the label snapshot taken at export and must not restore it.
What writeback --apply DOES do is run the RESTAMP SWEEP after landing the bodies: every
implementable bead in the artifact is re-gated through `stamp-refined.sh` (the sole writer),
so a conforming stamp is refreshed under today's contract and a stale one is stripped by the
gate's own downgrade leg. "Restamped on sight, never grandfathered" is a mechanism, not prose.

The dry run walks the same branches as the write and withholds only the `br` call. A dry run
that skips a branch cannot gate it.

Usage:
  bead-artifact.py export    --out <dir> --ids <id>[,<id>...]
  bead-artifact.py writeback --artifact <path> [--apply]

Run from the repo whose `.beads/` you mean — `br` resolves the board from the CWD.

Exit 0 all good · 1 at least one bead failed · 2 NOT-GATED (nothing was attempted).
"""
import argparse
import json
import os
import re
import subprocess
import sys

LIFECYCLE_LABELS = {"refined", "unrefined"}

# The sole sanctioned writer of the `refined`/`unrefined` pair (owner-hosted at
# skills/_tools/). Resolved off THIS file's location so the sweep works from any repo
# whose skills are the registry or a symlinked copy of it. Deliberately NOT
# env-overridable: an environment-controlled path reaching subprocess is taint.
STAMP_REFINED = str(__import__("pathlib").Path(__file__).resolve().parents[2] / "_tools" / "stamp-refined.sh")

DELIM = re.compile(r"<!-- BEAD:([^ ]+) -->\n(.*?)\n<!-- /BEAD:\1 -->", re.S)


def die(code, msg):
    print(f"bead-artifact: {msg}", file=sys.stderr)
    sys.exit(code)


def br(args):
    r = subprocess.run(["br", *args], capture_output=True, text=True)
    return r.returncode, r.stdout or "", r.stderr or ""


def require_board():
    """Refuse before touching anything if `br` cannot see a board from here."""
    rc, _, err = br(["list", "--json", "--limit", "1"])
    if rc != 0:
        die(2, f"NOT-GATED — `br` cannot resolve a board from {os.getcwd()!r} (rc={rc}). "
               f"Run from the repo that owns the `.beads/` you mean. Nothing was attempted."
               f"\n  br said: {err.strip()[:300]}")


def show(bead_id):
    rc, out, err = br(["show", "--json", bead_id])
    if rc != 0 or not out.strip():
        return None, f"br show exited {rc}: {err.strip()[:200]}"
    try:
        d = json.loads(out)
    except json.JSONDecodeError as exc:
        return None, f"br show returned unparseable JSON: {exc}"
    if isinstance(d, list):
        if not d:
            return None, "br show returned an empty array — the id did not resolve"
        d = d[0]
    return d.get("issue", d), None


def cmd_export(args):
    require_board()
    ids = [i.strip() for i in args.ids.split(",") if i.strip()]
    if not ids:
        die(2, "NOT-GATED — --ids named no beads")
    os.makedirs(args.out, exist_ok=True)
    path = os.path.join(args.out, "artifact.md")

    blocks, failed = [], []
    for bead_id in ids:
        d, err = show(bead_id)
        if d is None:
            failed.append((bead_id, err))
            continue
        labels = ",".join(d.get("labels") or []) or "none"
        blocks += [
            f"<!-- BEAD:{bead_id} -->",
            f"# {bead_id} — {d.get('title', '')}",
            f"type: {d.get('issue_type')} · priority: {d.get('priority')} · labels: {labels}",
            "",
            (d.get("description") or "").rstrip(),
            "",
            f"<!-- /BEAD:{bead_id} -->",
            "",
        ]

    # A bead missing from the artifact is a bead no round ever reads: it converges clean
    # and stamps unread. Write nothing rather than write a partial set.
    if failed:
        for bead_id, err in failed:
            print(f"bead-artifact: FAIL {bead_id} — {err}", file=sys.stderr)
        die(1, f"REFUSED — {len(failed)} of {len(ids)} beads did not resolve; "
               f"{path} was NOT written.")

    with open(path, "w") as fh:
        fh.write("\n".join(blocks) + "\n")
    print(f"bead-artifact: EXPORTED {len(ids)} beads -> {path}")
    return 0


def parse(path):
    with open(path) as fh:
        txt = fh.read()
    out = []
    for m in DELIM.finditer(txt):
        bead_id, body = m.group(1), m.group(2)
        lines = body.split("\n")
        if not lines[0].startswith("# "):
            die(2, f"NOT-GATED — block {bead_id} has no '# <id> — <title>' line; "
                   "the artifact is malformed and nothing was written.")
        head = lines[0][2:]
        title = head.split(" — ", 1)[1] if " — " in head else head
        desc = "\n".join(lines[2:]).strip() + "\n"
        out.append((bead_id, title, desc))
    if not out:
        die(2, f"NOT-GATED — no BEAD blocks found in {path}")
    return out


def artifact_labels(meta_line):
    m = re.search(r"labels:\s*(.+?)\s*$", meta_line)
    if not m or m.group(1).strip() == "none":
        return set()
    return {x.strip() for x in m.group(1).split(",") if x.strip()}


def restamp_sweep(bead_ids):
    """Re-gate every implementable bead through stamp-refined.sh (the sole writer).

    Decisions and epics are skipped: element 4 exempts them and a receipt records polish,
    not implement-readiness. Outcomes: STAMPED (conforming), DOWNGRADED (stale stamp
    stripped by the gate's own downgrade leg), or a routed-around refusal (rc 2). The
    sweep never fails the writeback: a downgrade is the gate working, not an error.
    """
    targets = []
    for bead_id in bead_ids:
        live, err = show(bead_id)
        if live is None:
            print(f"bead-artifact: RESTAMP SKIP {bead_id} — could not re-read: {err}")
            continue
        if live.get("issue_type") in ("epic", "decision"):
            continue
        targets.append(bead_id)
    if not targets:
        print("bead-artifact: RESTAMP SWEEP — no implementable beads to re-gate.")
        return
    print(f"bead-artifact: RESTAMP SWEEP — re-gating {len(targets)} implementable "
          f"bead(s) through stamp-refined.sh:")
    stamped = downgraded = refused = 0
    for bead_id in targets:
        r = subprocess.run(["bash", STAMP_REFINED, bead_id], capture_output=True, text=True)
        out = (r.stdout or "") + (r.stderr or "")
        if "STAMPED" in out:
            stamped += 1
            print(f"  STAMPED    {bead_id}")
        elif "DOWNGRADED" in out:
            downgraded += 1
            print(f"  DOWNGRADED {bead_id} — stale stamp stripped; returns to the refine lane")
        else:
            refused += 1
            first = next((ln for ln in out.splitlines() if ln.strip()), "(no output)")
            print(f"  REFUSED    {bead_id} — {first.strip()[:160]}")
    print(f"bead-artifact: RESTAMP RESULT — {stamped} stamped, {downgraded} downgraded, "
          f"{refused} refused.")


def cmd_writeback(args):
    require_board()
    beads = parse(args.artifact)
    with open(args.artifact) as fh:
        raw = fh.read()
    dry = not args.apply
    failed = []

    for bead_id, title, desc in beads:
        live, err = show(bead_id)
        if live is None:
            failed.append((bead_id, f"could not re-read before writing: {err}"))
            continue
        have = set(live.get("labels") or [])

        m = re.search(rf"<!-- BEAD:{re.escape(bead_id)} -->\n[^\n]*\n([^\n]*)", raw)
        want = artifact_labels(m.group(1)) if m else set()
        add = sorted((want - have) - LIFECYCLE_LABELS)
        title_changed = title != live.get("title")

        if dry:
            print(f"bead-artifact: DRY  {bead_id:46} desc={len(desc)}B "
                  f"title={'CHANGED' if title_changed else 'same'} +labels={add or '-'}")
            continue

        rc, _, err = br(["update", bead_id, "-d", desc])
        if rc != 0:
            failed.append((bead_id, f"description write exited {rc}: {err.strip()[:200]}"))
            continue
        if title_changed:
            rc, _, err = br(["update", bead_id, "--title", title])
            if rc != 0:
                failed.append((bead_id, f"title write exited {rc}: {err.strip()[:200]}"))
                continue
        for label in add:
            rc, _, err = br(["label", "add", bead_id, label])
            if rc != 0:
                failed.append((bead_id, f"label add {label!r} exited {rc}"))
        print(f"bead-artifact: WROTE {bead_id:46} +labels={add or '-'}")

    if failed:
        for bead_id, err in failed:
            print(f"bead-artifact: FAIL {bead_id} — {err}", file=sys.stderr)
        die(1, f"REFUSED — {len(failed)} of {len(beads)} beads failed. "
               "The board is PARTIALLY written; re-run after fixing the cause.")

    if dry:
        sweepable = 0
        for bead_id, _, _ in beads:
            live, err = show(bead_id)
            if live is not None and live.get("issue_type") not in ("epic", "decision"):
                sweepable += 1
        print(f"bead-artifact: DRY  RESTAMP SWEEP would re-gate {sweepable} implementable "
              f"bead(s) through stamp-refined.sh after --apply.")
        verb = "DRY RUN over"
        tail = " — pass --apply to write."
        count = len(beads)
    else:
        restamp_sweep([bead_id for bead_id, _, _ in beads])
        verb = "WRITEBACK COMPLETE —"
        tail = ", 0 failures."
        count = len(beads)
    print(f"\nbead-artifact: {verb} {count} beads{tail}")
    return 0


def main():
    ap = argparse.ArgumentParser(prog="bead-artifact.py")
    sub = ap.add_subparsers(dest="cmd", required=True)

    e = sub.add_parser("export", help="export a bead set to one artifact")
    e.add_argument("--out", required=True, help="directory to write artifact.md into")
    e.add_argument("--ids", required=True, help="comma-separated bead ids")

    w = sub.add_parser("writeback", help="write an artifact back to the board")
    w.add_argument("--artifact", required=True)
    w.add_argument("--apply", action="store_true", help="actually write (default: dry run)")

    args = ap.parse_args()
    sys.exit(cmd_export(args) if args.cmd == "export" else cmd_writeback(args))


if __name__ == "__main__":
    main()
