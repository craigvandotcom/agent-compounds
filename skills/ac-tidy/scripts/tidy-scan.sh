#!/usr/bin/env bash
# tidy-scan.sh — ac-tidy's provable step-3 rules, evaluated read-only (shadow mode).
#
# Prints one proposed action per line, TAB-separated:  rule  target  action  evidence
#   backlog-archive   every task checked, or status: complete   → archive to _backlog/_done/
#   plan-deliver      plan-deliver.sh --check says WOULD-DELIVER → stamp + move to _plans/_done/
#   plan-move         live plan already stamped delivered:        → move to _plans/_done/
#   draft-stale       top-level _plans/*.md, status: draft or findings, 14+ days untouched
#                     → review (flag only — the human decides keep or retire)
#   strip-unrefined   closed bead still labelled unrefined        → label-remove unrefined
#   add-unrefined     open non-epic bead with no lifecycle label  → label-add unrefined
#   label-review      label beads-standards never names           → review (flag only — the
#                     label vocabulary is open; never remove mechanically)
#   type-review       open bead whose title prefix contradicts its issue_type (DECISION:/HUMAN:
#                     typed task, ACTION: typed decision) → review (flag only — which side is
#                     wrong is a judgment; the docket files by issue_type)
#   finding-<kind>    a step-4 finding, deduped: skip-open <id> (an open ac-tidy / proposal /
#                     human-gate bead names the target) · suppressed <id> (a closed ac-tidy
#                     finding named it) · file
# then one `# tidy-scan:` summary line.
#
# NEVER writes. Switch to applying the mechanical rows only after 7 consecutive
# `.claude/state/tidy-runs.jsonl` lines carry `match: true`.
#
# Exit: 0 scanned (zero rows is a real clean); 2 NOT-GATED — `tidy-scan: ?` plus the
# reason; a failed read is never an empty list.
# Env:  AC2_BR_CMD (the br binary br_call reads through; default br)

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "tidy-scan: ? — not a git repo"; exit 2; }
SELF=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
SKILLS=$(cd "$SELF/../.." && pwd)
# shellcheck source=../../_tools/br-call.sh
. "$SKILLS/_tools/br-call.sh" || { echo "tidy-scan: ? — br-call.sh missing"; exit 2; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
cd "$ROOT" || exit 2

br_call list --all --limit 0 --json | tee "$T/beads.json" >/dev/null
[ "${PIPESTATUS[0]}" -eq 0 ] || { echo "tidy-scan: ? — br list refused"; exit 2; }

python3 - "$T/beads.json" "$ROOT" "$SKILLS" <<'PY'
import json, os, re, subprocess, sys, time

beads_path, ROOT, SKILLS = sys.argv[1:4]
def gated(why): print(f"tidy-scan: ? — {why}"); sys.exit(2)

try:
    data = json.load(open(beads_path))
    beads = data["issues"] if isinstance(data, dict) else data
except (ValueError, KeyError, TypeError) as e:
    gated(f"br list unparseable: {e}")
if not all(b.get("id") and b.get("status") and b.get("created_at") for b in beads):
    gated("br list row shape (id/status/created_at missing)")
try:
    recs = [json.loads(l) for l in open(os.path.join(ROOT, ".beads/issues.jsonl")) if l.strip()]
except (OSError, ValueError) as e:
    gated(f".beads/issues.jsonl unreadable (dependency edges): {e}")

rows = []
row = lambda *c: rows.append(c)
labels = lambda b: set(b.get("labels") or [])
is_open = lambda b: b["status"] not in ("closed", "tombstone")

def frontmatter(text):
    m = re.match(r"---\n(.*?)\n---", text, re.S)
    return m.group(1) if m else ""

def fm_key(fm, key):
    m = re.search(rf"^{key}:\s*['\"]?([^'\"\n]*?)['\"]?\s*$", fm, re.M)
    return m.group(1) if m else None

# ── backlog-archive (Scan C's file set) ──────────────────────────────────
SKIP_DIRS = ("_done", "_shipped", "complete", "assets", "audits")
for d, dirs, files in os.walk(os.path.join(ROOT, "_backlog")):
    dirs[:] = sorted(x for x in dirs if x not in SKIP_DIRS)
    for f in sorted(files):
        if not f.endswith(".md") or f.startswith("_") or f in ("ROADMAP.md", "BUSINESS-STRATEGY.md"):
            continue
        p = os.path.join(d, f); rel = os.path.relpath(p, ROOT)
        text = open(p, errors="replace").read()
        done = len(re.findall(r"^\s*- \[[xX]\]", text, re.M))
        todo = len(re.findall(r"^\s*- \[ \]", text, re.M))
        if fm_key(frontmatter(text), "status") == "complete":
            row("backlog-archive", rel, "archive → _backlog/_done/", "status: complete")
        elif done and not todo:
            row("backlog-archive", rel, "archive → _backlog/_done/", f"{done}/{done} tasks checked")

# ── plan-deliver / plan-move (plan-deliver.sh --check is the test) ───────
pdir = os.path.join(ROOT, "_plans")
deliver = os.path.join(SKILLS, "_tools/plan-deliver.sh")
for f in sorted(os.listdir(pdir)) if os.path.isdir(pdir) else []:
    p = os.path.join(pdir, f)
    if not f.endswith(".md") or f == "README.md" or not os.path.isfile(p): continue
    fm = frontmatter(open(p, errors="replace").read())
    rel = os.path.relpath(p, ROOT)
    status = fm_key(fm, "status")
    if status in ("draft", "findings"):
        age_days = (time.time() - os.path.getmtime(p)) / 86400
        if age_days >= 14:
            row("draft-stale", rel, "review", f"status: {status}, {int(age_days)}d untouched")
        continue
    if fm_key(fm, "beadified") is None: continue
    if fm_key(fm, "delivered") is not None:
        row("plan-move", rel, "move → _plans/_done/", f"delivered: {fm_key(fm, 'delivered')}")
        continue
    r = subprocess.run(["bash", deliver, "--check", p], capture_output=True, text=True)
    verdict = (r.stdout.strip().splitlines() or [""])[0]
    if r.returncode == 2: gated(f"plan-deliver --check {rel}: {verdict}")
    if verdict.startswith("WOULD-DELIVER"):
        row("plan-deliver", rel, "stamp delivered: + move → _plans/_done/", verdict.split(" — ", 1)[-1])

# ── lifecycle labels ─────────────────────────────────────────────────────
LIFECYCLE = {"unrefined", "refined", "human-gate", "human-ratified"}
for b in beads:
    if b["status"] == "closed" and "unrefined" in labels(b):
        row("strip-unrefined", b["id"], "label-remove unrefined", "closed")
    elif is_open(b) and b.get("issue_type") != "epic" and not labels(b) & LIFECYCLE:
        row("add-unrefined", b["id"], "label-add unrefined", f"{b['status']}, no lifecycle label")

# ── label-review: labels beads-standards never names (flag only) ─────────
vocab, families = set(), set()
for d, _, files in os.walk(os.path.join(SKILLS, "beads-standards")):
    for f in files:
        for tok in re.findall(r"`([a-z][a-z0-9:_<>.,-]*)`", open(os.path.join(d, f), errors="replace").read()):
            vocab.add(tok)
            if ":<" in tok: families.add(tok.split(":<")[0] + ":")
unnamed = {}
for b in filter(is_open, beads):
    for l in labels(b):
        if l not in vocab and not any(l.startswith(fam) for fam in families):
            unnamed.setdefault(l, []).append(b["id"])
for l, ids in sorted(unnamed.items()):
    row("label-review", l, "review", f"{len(ids)} open bead(s), e.g. {ids[0]}")

# ── type-review: title prefix contradicts issue_type (flag only) ─────────
for b in filter(is_open, beads):
    t, title = b.get("issue_type"), b.get("title", "")
    if (t == "task" and re.match(r"(DECISION|HUMAN)\b", title)) or (t == "decision" and title.startswith("ACTION:")):
        row("type-review", b["id"], "review", f"typed {t}, titled {title.split(':')[0]}:")

# ── step-4 findings, deduped against every bead that names the target ────
by_id = {b["id"]: b for b in beads}
rec_type = {r["id"]: r.get("issue_type") for r in recs}
OWNERS = {"origin:ac-tidy", "pipeline-proposal", "human-gate"}
def dedupe(kind, key_ids, evidence):
    # skip-open: an open finding-shaped bead names the target; suppressed: a closed
    # ac-tidy finding named it — the ruling stands, never re-file it
    hits = [b for b in beads if b["id"] not in key_ids
            and all(k in (b.get("title", "") + "\n" + (b.get("description") or "")) for k in key_ids)]
    live = [b["id"] for b in hits if is_open(b) and labels(b) & OWNERS]
    done = [b["id"] for b in hits if not is_open(b) and "origin:ac-tidy" in labels(b)]
    action = f"skip-open {live[0]}" if live else f"suppressed {done[0]}" if done else "file"
    row(f"finding-{kind}", "→".join(key_ids), action, evidence)

for r in recs:
    for d in r.get("dependencies") or []:
        a, z = d.get("issue_id"), d.get("depends_on_id")
        if d.get("type") != "blocks" or "epic" not in (rec_type.get(a), rec_type.get(z)): continue
        if any(x in by_id and is_open(by_id[x]) for x in (a, z)):  # a closed–closed edge sequences nothing
            dedupe("i2-edge", [a, z], "blocks edge with an epic endpoint")
children = {}
for r in recs:
    for d in r.get("dependencies") or []:
        if d.get("type") == "parent-child": children.setdefault(d.get("depends_on_id"), set()).add(r["id"])
for b in beads:
    if b.get("issue_type") != "epic" or not is_open(b): continue
    kids = children.get(b["id"], set()) | {x for x in by_id if x.startswith(b["id"] + ".")}
    if not any(is_open(by_id[k]) for k in kids if k in by_id) and "Probe:" not in (b.get("description") or ""):
        dedupe("epic-idle", [b["id"]], "open epic, zero open children, no Probe: line")
for b in beads:
    if is_open(b) and "post-merge" in labels(b):
        dedupe("post-merge-tail", [b["id"]], "open, still labelled post-merge")

MECH = ("backlog-archive", "plan-deliver", "plan-move", "strip-unrefined", "add-unrefined")
for r in rows: print("\t".join(map(str, r)))
fnd = [r for r in rows if r[0].startswith("finding-")]
print(f"# tidy-scan: {sum(r[0] in MECH for r in rows)} mechanical · "
      f"{sum(r[2] == 'review' for r in rows)} review · {len(fnd)} findings "
      f"({sum(r[2] == 'file' for r in fnd)} file, "
      f"{sum(r[2].startswith('suppressed') for r in fnd)} suppressed, "
      f"{sum(r[2].startswith('skip-open') for r in fnd)} skip-open)")
PY
