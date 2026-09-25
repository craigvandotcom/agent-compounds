#!/usr/bin/env bash
# docket.test.sh — proof harness for docket.sh. Builds a throwaway repo with a fixture board
# (stub `br` via AC2_BR_CMD, a sqlite beads.db carrying comments + events), fixture card JSON,
# and asserts the rendered docket. Exit 0 = all cases pass.

SELF=$(cd "$(dirname "$0")" && pwd)
DOCKET="$SELF/docket.sh"
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
PASS=0; FAIL=0
ALL=""    # every rendered case, for the width assertion at the end
ok()   { PASS=$((PASS + 1)); }
bad()  { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }
has()  { printf '%s' "$OUT" | grep -qF -- "$2" && ok || bad "$1 — expected: $2"; }
hasnt(){ printf '%s' "$OUT" | grep -qF -- "$2" && bad "$1 — unexpected: $2" || ok; }
before(){ a=$(printf '%s\n' "$OUT" | grep -nF -- "$2" | head -1 | cut -d: -f1)
          b=$(printf '%s\n' "$OUT" | grep -nF -- "$3" | head -1 | cut -d: -f1)
          [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ] && ok || bad "$1 — '$2' not before '$3'"; }
# block_has: the mini-block starting at the line == <id-line> (up to the next blank line)
# carries <substring> — the shape a stacked gate/lane/member block renders as.
block_has(){ chunk=$(awk -v id="$2" 'index($0,id)==1{f=1} f{print; if($0==""){exit}}' <<<"$OUT")
             printf '%s' "$chunk" | grep -qF -- "$3" && ok || bad "$1 — expected '$3' in block '$2'"; }

R="$W/repo"; mkdir -p "$R/.beads" "$R/.claude"; git -C "$R" init -q
TODAY=$(date +%F)

# ── fixture board ─────────────────────────────────────────────────────────
python3 - "$R" "$TODAY" <<'PY'
import datetime as dt, json, os, sqlite3, sys
R, TODAY = sys.argv[1], sys.argv[2]
now = dt.datetime.now(dt.timezone.utc)
iso = lambda d: (now - dt.timedelta(days=d)).strftime("%Y-%m-%dT%H:%M:%SZ")
fut = (now + dt.timedelta(days=5)).strftime("%Y-%m-%dT%H:%M:%SZ")
memo = "evidence: x\nconsequence: y\nrecommendation: z"
B = []
def bead(i, p, d, labels, t="decision", title=None, desc=memo, status="open", **kw):
    B.append(dict(id=i, priority=p, created_at=iso(d), labels=labels, issue_type=t,
                  title=title or f"title {i}", description=desc, status=status, **kw))
bead("g-p0", 0, 1, ["human-gate"])
bead("g-p1-old", 1, 9, ["human-gate"])
bead("g-p1-new", 1, 2, ["human-gate"])
bead("g-act", 2, 3, ["human-gate"], t="task", desc="do it")
bead("g-nomemo", 3, 3, ["human-gate"], desc="HUMAN: decide X")
bead("g-partial", 3, 3, ["human-gate"], desc="evidence: only")
bead("g-deferred", 1, 3, ["human-gate"], status="deferred")
bead("g-future", 1, 3, ["human-gate"], defer_until=fut)
bead("g-closed", 1, 3, ["human-gate"], status="closed")
bead("prop-1", 2, 1, ["pipeline-proposal"])
for n in range(6): bead(f"flood-{n}", 2, 2, ["human-gate", "flood"])
bead("flood-urgent", 1, 2, ["human-gate", "flood"])
for n in range(6): bead(f"old-{n}", 2, 30, ["human-gate", "oldlane"], title=f"hold 6f390127-aaaa-bbbb {n}")
bead("dl-un", 2, 4, ["human-gate", "declared"], desc="votes: green, green, green\nrecommendation: accept green")
bead("dl-split", 2, 4, ["human-gate", "declared"], desc="votes: green, red, green")
bead("stray-1", 2, 4, ["refined"], t="task", desc="blocked, waiting on Apple account")
json.dump({"issues": B, "total": len(B), "has_more": False, "limit": 0}, open(f"{R}/board.json", "w"))
# edges: g-p1-new frees two beads, g-act one; every other gate blocks nothing
dep = lambda i, *on: dict(id=i, status="open", dependencies=[{"issue_id": i, "depends_on_id": o, "type": "blocks"} for o in on])
with open(f"{R}/.beads/issues.jsonl", "w") as fh:
    for r in B + [dep("w1", "g-p1-new", "g-act"), dep("w2", "g-p1-new")]: fh.write(json.dumps(r) + "\n")
os.makedirs(f"{R}/_plans")
for name, fm in (("d", "status: draft"), ("a", "status: approved"), ("b", "status: bead-ready"),
                 ("p", "status: approved\npolish_rounds: 2\npolish_fixpoint_sha256: x")):
    open(f"{R}/_plans/plan-{name}.md", "w").write(f"---\n{fm}\n---\n")
con = sqlite3.connect(f"{R}/.beads/beads.db")
con.execute("CREATE TABLE comments (id INTEGER PRIMARY KEY, issue_id TEXT, author TEXT, text TEXT, created_at TEXT)")
con.execute("CREATE TABLE events (id INTEGER PRIMARY KEY, issue_id TEXT, event_type TEXT, actor TEXT, "
            "old_value TEXT, new_value TEXT, comment TEXT, created_at TEXT)")
con.execute("INSERT INTO comments (issue_id,author,text,created_at) VALUES ('g-p0','x',?, '2026-01-01')", (f"verified: {TODAY}",))
con.execute("INSERT INTO comments (issue_id,author,text,created_at) VALUES ('g-p1-old','x','verified: 2020-01-01','2020-01-01')")
for i, (et, cm) in enumerate([("label_added", "Added label human-gate"), ("label_removed", "Removed label human-gate"),
                              ("commented", "DECISION (operator): ship it"), ("label_added", "Added label human-gate")]):
    con.execute("INSERT INTO events (issue_id,event_type,actor,comment,created_at) VALUES ('g-p1-new',?,'x',?,?)",
                (et, cm, f"2026-01-0{i + 1}"))
con.commit()
json.dump({"lanes": [{"label": "declared", "name": "decl",
                      "fields": {"votes": [{"re": "^votes:\\s*([^\\n]+)"}]}, "line": ["{votes}"],
                      "unanimous": {"re": "^votes:\\s*(\\w+),\\s*\\1,\\s*\\1\\s*$"}}]},
          open(f"{R}/.claude/docket-lanes.json", "w"))
ent = lambda i, w, r, prom, st="open": dict(id=i, skill="s", weight=w, recurrence=r, promotable=prom,
                                            status=st, perceptibility="silent", proposed_fix=f"fix {i}", path="p")
json.dump({"dream": {"entries": [ent("f-crit", 30, 1, True), ent("f-common", 20, 3, False),
                                 ent("f-both", 40, 4, True), ent("f-resolved", 99, 5, True, "resolved"),
                                 ent("f-minor", 50, 1, False)]}}, open(f"{R}/frictions.json", "w"))
json.dump({"generated": TODAY, "lanes": [], "errors": [],
           "rows": [{"kind": "duplicate", "files": ["a.md", "b.md"], "score": 9, "evidence": "jaccard 0.7", "action": "merge"}]},
          open(f"{R}/memory.json", "w"))
PY

cat > "$W/br" <<EOF
#!/usr/bin/env bash
[ -n "\${BR_FAIL:-}" ] && { echo '{"error":{"message":"db locked"}}'; exit 1; }
cat "$R/board.json"
EOF
chmod +x "$W/br"
export AC2_BR_CMD="$W/br" AC_HUMAN_FRICTION_CMD="cat '$R/frictions.json'" AC_HUMAN_MEMORY_CMD="cat '$R/memory.json'"

OUT=$(cd "$R" && "$DOCKET"); ALL="$ALL
$OUT"

# order + tiering
before "a gate that frees beads outranks P0" "g-p1-new · " "g-p0 · "
has    "it names what it frees"       "g-p1-new · 2d · P1 · frees 2"
before "P0 before P1"                 "g-p0 · "    "g-p1-old"
before "P1 oldest first"              "g-p1-old"   "flood-urgent"
before "decisions before actions"     "🔴 DECISIONS"  "🔴 ACTIONS"
has    "next is the most freeing"     "→ next g-p1-new"
before "blocking gates before plans"  "🔴 ACTIONS"  "🟡 PLANS"
before "plans before idle gates"      "🟡 PLANS"   "⚪ IDLE GATES"
before "polished before approved"     "plan-p.md" "plan-a.md"
before "approved before draft"        "plan-a.md" "plan-d.md"
hasnt  "bead-ready is the loop's"     "plan-b.md"
has    "action grouped"               "🔴 ACTIONS · 1"
hasnt  "deferred excluded"            "g-deferred"
hasnt  "future defer excluded"        "g-future"
hasnt  "closed excluded"              "g-closed"
has    "proposal on docket"           "prop-1 ·"
has    "proposals hint"               "⚠ 1 proposal(s) pending"
# memo
has    "bare decision → no memo"      "⚠ no memo"
has    "partial memo → gate-incomplete" "⚠ gate-incomplete (no consequence"
# anti-rot
block_has "verified today → tap-ready"  "g-p0 · 24h · P0"   "(tap-ready)"
has    "earlier stamp → stale"        "⚠ stale — reverify (verified"
block_has "no stamp → never verified" "g-p1-new · 2d · P1" "never verified"
block_has "released history surfaced" "g-p1-new · 2d · P1" "⚠ released ×1 — read events"
# lanes
has    "label >5 collapses"           "🔁 FLOOD · 6"
hasnt  "P2 lane member not itemized"  "flood-0 ·"
has    "P1 lane member stays itemized" "flood-urgent · 2d · P1"
block_has "old lane elevated"         "🔁 OLDLANE · 6" "⚠ elevated — run this sitting"
has    "unreadable titles flagged"    "⚠ 6 unreadable titles — re-title"
# declared lane
has    "declared lane card"           "1 unanimous · 1 split"
has    "unanimous member marked"      "✓ dl-un · 4d"
has    "split member unmarked"        "· dl-split · 4d"
has    "batch accept offered"         "→ accept 1 unanimous ✓"
# cards
has    "friction count excludes resolved/minor" "🧰 FRICTIONS · top 3 of 3"
has    "critical+common marked"       "1. [critical·common] w40"
has    "critical only"                "[critical] w30"
has    "common only"                  "[common] w20"
hasnt  "resolved hidden"              "f-resolved"
before "friction weight order"        "f-both"     "f-crit"
has    "memory row rendered"          "1. [duplicate] 9 → merge"
block_has "memory row files"          "1. [duplicate] 9 → merge" "↔ b.md"
has    "stray human-pending"          "stray-1 ·"

# edges unreadable → every gate stays 🔴, the failure named
swap() { python3 -c 'import os, sys; os.rename(sys.argv[1], sys.argv[2])' "$R/.beads/$1" "$R/.beads/$2"; }
swap issues.jsonl issues.off
OUT=$(cd "$R" && "$DOCKET"); ALL="$ALL
$OUT"
hasnt  "no idle tier without edges"   "⚪ IDLE GATES"
has    "the edge read is named"       ".beads/issues.jsonl"
swap issues.off issues.jsonl

# memory source absent → `?`, not a crash
OUT=$(cd "$R" && AC_HUMAN_MEMORY_CMD='echo "memory-rollup.py not found" >&2; exit 127' "$DOCKET"); ALL="$ALL
$OUT"
has    "memory absent → ?"            "🧠 MEMORY · ? (memory-rollup.py not"

# br failure → `?` and named, never an empty docket
OUT=$(cd "$R" && BR_FAIL=1 "$DOCKET"); ALL="$ALL
$OUT"
has    "br failure → ? gates"         "🔴 GATES · ?"
has    "br failure named"             "br_call list"
has    "br failure → ? remaining"     "🧑 NEEDS YOU · ? gates"

# --gates slice
OUT=$(cd "$R" && "$DOCKET" --gates); ALL="$ALL
$OUT"
has    "gates header"                 "gates · no upstream"
hasnt  "gates omits plans"            "🟡 PLANS"

# Every line fits a phone: 40 columns, never wrapped.
wide=$(printf '%s\n' "$ALL" | python3 -c 'import sys; print(max(len(l.rstrip("\n")) for l in sys.stdin))')
if [ "$wide" -le 40 ]; then echo "ok   width: widest line $wide"; ok
else echo "FAIL width: widest line $wide > 40"; bad "phone width"; fi

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
