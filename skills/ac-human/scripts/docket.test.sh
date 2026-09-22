#!/usr/bin/env bash
# docket.test.sh — proof harness for docket.sh. Builds a throwaway repo with a fixture board
# (stub `br` via AC2_BR_CMD, a sqlite beads.db carrying comments + events), fixture card JSON,
# and asserts the rendered docket. Exit 0 = all cases pass.

SELF=$(cd "$(dirname "$0")" && pwd)
DOCKET="$SELF/docket.sh"
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
PASS=0; FAIL=0
ok()   { PASS=$((PASS + 1)); }
bad()  { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }
has()  { printf '%s' "$OUT" | grep -qF -- "$2" && ok || bad "$1 — expected: $2"; }
hasnt(){ printf '%s' "$OUT" | grep -qF -- "$2" && bad "$1 — unexpected: $2" || ok; }
before(){ a=$(printf '%s\n' "$OUT" | grep -nF -- "$2" | head -1 | cut -d: -f1)
          b=$(printf '%s\n' "$OUT" | grep -nF -- "$3" | head -1 | cut -d: -f1)
          [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ] && ok || bad "$1 — '$2' not before '$3'"; }

R="$W/repo"; mkdir -p "$R/.beads" "$R/.claude"; git -C "$R" init -q
TODAY=$(date +%F)

# ── fixture board ─────────────────────────────────────────────────────────
python3 - "$R" "$TODAY" <<'PY'
import datetime as dt, json, sqlite3, sys
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
con = sqlite3.connect(f"{R}/.beads/beads.db")
con.execute("CREATE TABLE comments (id INTEGER PRIMARY KEY, issue_id TEXT, author TEXT, text TEXT, created_at TEXT)")
con.execute("CREATE TABLE events (id INTEGER PRIMARY KEY, issue_id TEXT, event_type TEXT, actor TEXT, "
            "old_value TEXT, new_value TEXT, comment TEXT, created_at TEXT)")
con.execute("INSERT INTO comments (issue_id,author,text,created_at) VALUES ('g-p0','x',?, '2026-01-01')", (f"verified: {TODAY}",))
con.execute("INSERT INTO comments (issue_id,author,text,created_at) VALUES ('g-p1-old','x','verified: 2020-01-01','2020-01-01')")
for i, (et, cm) in enumerate([("label_added", "Added label human-gate"), ("label_removed", "Removed label human-gate"),
                              ("commented", "DECISION (Craig): ship it"), ("label_added", "Added label human-gate")]):
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

OUT=$(cd "$R" && "$DOCKET")

# order + tiering
before "P0 before P1"                 "g-p0 "      "g-p1-old"
before "P1 oldest first"              "g-p1-old"   "g-p1-new"
before "decisions before actions"     "decisions ("  "actions ("
has    "next is P0"                   "next: g-p0"
has    "action grouped"               "actions (1)"
hasnt  "deferred excluded"            "g-deferred"
hasnt  "future defer excluded"        "g-future"
hasnt  "closed excluded"              "g-closed"
has    "proposal on docket"           "prop-1"
has    "proposals hint"               "⚠ 1 pipeline proposals pending"
# memo
has    "bare decision → no memo"      "⚠ no memo"
has    "partial memo → gate-incomplete" "⚠ gate-incomplete (no consequence, recommendation)"
# anti-rot
printf '%s\n' "$OUT" | grep -F "g-p0 " | grep -qF "(tap-ready)" && ok || bad "verified today → tap-ready"
has    "earlier stamp → stale"        "⚠ stale — reverify (verified 2020-01-01)"
printf '%s\n' "$OUT" | grep -F "g-p1-new" | grep -qF "never verified" && ok || bad "no stamp → never verified"
has    "released history surfaced"    "⚠ released ×1 before — read events"
# lanes
has    "label >5 collapses"           "🔁 flood — 6 queued"
hasnt  "P2 lane member not itemized"  "• flood-0"
has    "P1 lane member stays itemized" "flood-urgent"
has    "old lane elevated"            "🔁 Run the oldlane sitting — 6 queued"
has    "unreadable titles flagged"    "⚠ 6 unreadable titles"
# declared lane
has    "declared lane card"           "· 1 unanimous · 1 split"
has    "unanimous member marked"      "✓ dl-un"
has    "split member unmarked"        "· dl-split"
has    "batch accept offered"         "→ Accept all 1 unanimous recommendations"
# cards
has    "friction count excludes resolved/minor" "top 3 of 3 open critical/common"
has    "critical+common marked"       "[critical·common] f-both"
has    "critical only"                "[critical] f-crit"
has    "common only"                  "[common] f-common"
hasnt  "resolved hidden"              "f-resolved"
before "friction weight order"        "f-both"     "f-crit"
has    "memory row rendered"          "[duplicate] a.md ↔ b.md  score 9 → merge"
has    "stray human-pending"          "stray-1"

# memory source absent → `?`, not a crash
OUT=$(cd "$R" && AC_HUMAN_MEMORY_CMD='echo "memory-rollup.py not found" >&2; exit 127' "$DOCKET")
has    "memory absent → ?"            "### 🧠 Memory — ? (memory-rollup.py not found)"

# br failure → `?` and named, never an empty docket
OUT=$(cd "$R" && BR_FAIL=1 "$DOCKET")
has    "br failure → ? gates"         "### 🔴 Blocking — ? gates"
has    "br failure named"             "br_call list"
has    "br failure → ? remaining"     "Needs you: ? remaining"

# --gates slice
OUT=$(cd "$R" && "$DOCKET" --gates)
has    "gates header"                 "## repo —"
hasnt  "gates omits plans"            "Feed the builders"

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
