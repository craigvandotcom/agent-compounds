# Shared board scan (the pipeline read layer)

**The single way to read pipeline state — beads + plans + backlog + the gates over them — into
a structured "board."** `ac-align`, `ac-tidy`, `ac-human-session`, `ac-dashboard`, and `ac-loop`
(Phase 0 orient) all read THIS, then apply their own lens. **Share the read; never the
judgment.** The five scans are defined ONCE here so they can't drift across the skills that
consume them.

This file owns the *read* (what to scan, how to categorize). Each consumer owns the *lens*
(what to do with it) — see "Lenses" at the bottom.

---

## ToC
- Phase 0 — init
- Scan A — beads
- Scan B — plans
- Scan C — backlog
- Scan E — scheduled CI gate health (the other unconsumed signal)
- Scan F — board truth (the already-shipped probe)
- The board snapshot (shape returned to the consumer)
- Lenses (who reads this board, for what)

## Phase 0 — init

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
```

Run scans A, B, C, D, E **in parallel** (they're independent).

## Scan A — beads

```bash
br list  --json --limit 1000   # NON-CLOSED beads only → object {issues:[...], total, has_more, limit}
br ready --json                # unblocked + ready → a FLAT array
cat .beads/issues.jsonl        # the ONLY complete source — includes closed beads
```

> **`br` JSON shape differs by subcommand — don't conflate them:**
> - `br list --json` returns a **paginated object** (`default limit 50`). Always pass
>   `--limit 1000` (or page on `has_more`) and iterate **`.issues[]`**, not `.[]`.
> - `br ready --json` returns a **bare array** — iterate **`.[]`**.
> Getting this wrong fails silently-ish (`jq: Cannot index array with string …`, or
> a truncated list at 50).

> **⚠️ `br list --json` DOES NOT RETURN CLOSED BEADS** (br 0.2.x). It has returned 436
> records with zero `status=closed` while
> `.beads/issues.jsonl` held 2,453 records of which 2,017 were closed. `--limit` does not
> help. This is **load-bearing**: the Tier-1 stale-`unrefined`-on-CLOSED-beads sweep and
> the Tier-2 positive-proof archive gate both need closed beads, and both would silently
> under-count to **zero** — a false clean, not an error. **Any predicate involving closed
> beads must read `.beads/issues.jsonl` directly.**
>
> Related: `br sync` in a fresh worktree rebuilds from JSONL and reports
> `Created: 2453 issues` while `br list` then shows 436. The two numbers are consistent
> only once the above is understood — it is not a corrupt import.

Categorize every bead:

| Category | Test |
|----------|------|
| **ready (refined)** | in `br ready` AND has the `refined` label (presence, not absence of `unrefined` — `skills/beads-standards/reference/bead-conventions.md`) |
| **unrefined** | lacks the `refined` label — has `unrefined`, or no lifecycle label at all (needs `/ac-bead-refine`) |
| **blocked** | `status=open`, NOT in `br ready` |
| **in_progress** | `status=in_progress` |
| **closed** | `status=closed`/`done` |

Surface these labels (consumers filter on them): `human-gate`, `dream-proposal`,
`triage,<src>`, finding labels (`qa-finding`/`review-finding`/`hygiene-finding`), `qa-blocker`.
For **epics** (dependent_count > 3 or "epic" in title): count total / ready / blocked / closed
children.

### Docket health (open gates + reason-less gates)

**Always print.** Every listed consumer inherits this line — do not make it
consumer-only. Key ONLY on the explicit `Gate-reason:` marker (never infer
"this looks mechanical"). A deferred bead is not on the docket: exclude
`status=deferred` AND exclude `status=open` rows whose `defer_until` is in
the future. Empty/`br` failure is NOT clean (same doctrine as Scan E
`unknown`): fail loud, never print `0` as healthy.

**ALARM** if open human-gate count is `>25` OR any reason-less gate is older
than `48h` (age from `created_at`). Print the same standing as the Scan E
`ci-gates` / `ci_health` echo — one first-class `docket-health:` line every
run, `ok` included.

```bash
# FAIL LOUD if br list --json cannot be read — do not print 0 as clean.
DOCKET=$(br list --json --limit 0 --all) || { echo "docket-health: ERROR — br list --json failed (empty-is-not-clean)"; exit 2; }
printf '%s' "$DOCKET" | python3 -c "
import json, sys, datetime
raw = sys.stdin.read()
try:
    data = json.loads(raw)
except Exception as e:
    print('docket-health: ERROR — unparseable br list --json (empty-is-not-clean):', e)
    sys.exit(2)
issues = data.get('issues') if isinstance(data, dict) else data
if issues is None:
    print('docket-health: ERROR — unexpected br list shape (empty-is-not-clean)')
    sys.exit(2)
now = datetime.datetime.now(datetime.timezone.utc)
def parse_until(s):
    if not s: return None
    s = str(s).replace('Z', '+00:00')
    try: return datetime.datetime.fromisoformat(s)
    except Exception: return None
def on_docket(i):
    st = i.get('status')
    if st == 'deferred': return False
    until = parse_until(i.get('defer_until'))
    if until and until > now: return False
    return st in ('open', 'blocked', 'in_progress')
hg = [i for i in issues if 'human-gate' in (i.get('labels') or [])]
docket = [i for i in hg if on_docket(i)]
reasonless = [i for i in docket if 'Gate-reason:' not in (i.get('description') or '')]
stale = []
for i in reasonless:
    created = parse_until(i.get('created_at') or i.get('created'))
    if created and (now - created).total_seconds() > 48 * 3600:
        stale.append(i)
alarms = []
if len(docket) > 25:
    alarms.append(str(len(docket)) + ' open gates >25')
if stale:
    alarms.append(str(len(stale)) + ' reason-less >48h')
suffix = (' · ALARM (' + '; '.join(alarms) + ')') if alarms else ''
print(f'docket-health: {len(docket)} open human-gate · {len(reasonless)} reason-less{suffix}')
for i in reasonless:
    print(i.get('id'))
"
```

### Structural lint (parentage + edges)

Beyond the status categories above, Scan A also computes two structural lint classes —
defined ONCE here so `ac-tidy`, `ac-loop` Phase 0 orient, and standalone lint can't fork
on what "orphan" or "illegal edge" mean:

- **Parentage-gap orphan** — an open, non-epic bead with no epic parent (no `parent-child`
  edge to an epic). `human-gate` beads are EXCLUDED from this class (Arm 0 owns their
  parentage — wired at creation). This is the I1 sense of "orphan" (a bead with no home
  epic), distinct from `ac-tidy`'s older sense ("orphan = a bead referencing a plan file
  that no longer exists") — both are reported, they are different classes.
- **Authored epic-edge** — any `blocks` edge with an **epic endpoint** (either end an epic)
  is an I2 violation: epic order is derived from cross-epic bead edges, never authored
  directly (`skills/beads-standards/SKILL.md` § Sequencing & parentage). Report it ALWAYS;
  converting it into the right bead-level edge needs human judgment, so route the
  conversion to Tier 3 rather than auto-fixing.

**Edge queries read `.beads/issues.jsonl` directly.** `br list --json` (0.2.16) returns
the beads but NO dependency edges — parse the jsonl for the `blocks` / `parent-child`
relationships these two classes need.

### File-cluster density (batch-selection read)


Derived read over the ready-orphan set — ranks the file paths cited in bead descriptions
by density. The consumer's lens (densest cluster first, disjoint clusters per parallel
child) stays with the consumer (`ac-loop` § Batch orphans by FILE CLUSTER).

```bash
# Densest file clusters across the ready orphan set (drives batch selection).
br ready --limit 0 --json | jq -r '.[] | select(
  (.labels | index("refined")) and (.labels | index("human-gate") | not)
) | .description' \
  | grep -oE '[a-zA-Z0-9_./-]+\.[a-zA-Z0-9]+' \
  | grep -E '\.(ts|tsx|js|mjs|yml|yaml|sh|swift)$' \
  | sort | uniq -c | sort -rn | head -20
```

> Grab the WHOLE extension first, then filter anchored on `$`. A single
> `grep -oE '...\.(ts|js|...)'` silently truncates `issues.jsonl` → `issues.js` and
> `tsconfig.scripts.json` → `tsconfig.scripts.js`, inventing two files that do not exist
> and ranking them into the top cluster.

## Scan B — plans

```bash
ls "$PROJECT_ROOT/_plans/"*.md 2>/dev/null
```

Skip `README.md`, `_done/`, `research/`, `templates/`, `checkpoints/`. Per plan, read
frontmatter:

- **status** — `draft | refined | approved | beadified | loop-ready`; ANY other value is present-but-out-of-vocabulary and routes to `unclassified[]` with the raw value preserved — **never dropped**, and renderers MUST report it (bd-5ljt6)
- **loop-ready** — the autonomous hand-off flag (the loop owns these; humans don't sign them off again)
- **refinement_rounds** — frontmatter field, else count `### Round N` headings in the `## Refinement Log` (headings only)
- **source_backlog**, **mtime** (recency)
- **Fallback** (no frontmatter): `## Refinement Log` → `refined`; `Status: Approved` text → `approved`; referenced by a bead record (description OR comments — match the whole record, then filter) → `beadified`; else `draft`. Flag the missing frontmatter for `/ac-tidy`. An unparseable board (jsonl unreadable, `br` error) is an ERROR, not `N_matching=0` — empty and error stay distinguishable (never fail toward "nothing to do").

## Scan C — backlog

```bash
find "$PROJECT_ROOT/_backlog" -name "*.md" \
  -not -name "_*" -not -name "ROADMAP.md" -not -name "BUSINESS-STRATEGY.md" \
  -not -path "*/_done/*" -not -path "*/_shipped/*" -not -path "*/complete/*" \
  -not -path "*/assets/*" -not -path "*/audits/*" \
  2>/dev/null
```

Per file, read frontmatter + count tasks:

- **folder** — `active/` (committed scope) · `pool/` (candidate) · legacy `v*/` (pre-migration → flag for the `{active,pool}` migration `ac-align` offers)
- **status** — `captured` · `candidate` (triage-promoted, awaiting human approval) · `planned` · `complete`
- **type / horizon / channel / source** (from the `ac-backlog` frontmatter schema)
- **unchecked task count** (`- [ ]`) vs checked (`- [x]`)
- Skip `status: complete` **only**. Zero checkboxes means prose-captured, NOT done — route it to `unclassified[]` (raw reason preserved) and renderers MUST report it; the old task-count skip silently hid 16 live files, 3 of them in committed `active/` scope.

## Scan E — scheduled CI gate health (the other unconsumed signal)

**A scheduled gate emits a verdict every night; if nothing consumes it, the gate protects
nothing while appearing to exist.** **While a suite is red,
its passing assertions carry no signal**, because a new genuine failure moves the count from
1-failed to 2-failed and nothing watches either number. Hence consecutive reds **escalate**: a
persistently-red gate is strictly worse than a missing one — it looks like coverage while
providing none.

```bash
# Per-run scratch dir. Writes go through `tee`, never a truncating redirect — dcg's
# core.filesystem:redirect-truncate-dynamic-path blocks `> "$VAR/path"`. `tee "$VAR/path"`
# is allowed; a redirect to a fully-literal path (`>/dev/null`, `2>/tmp/…`) is allowed.
# gh's stdout is kept in a shell variable (10 runs — small) so no per-workflow file write
# is needed at all, and its stderr goes to a LITERAL path.
D="${ARTIFACTS_DIR:-/tmp/ac_board_scan_scratch}"; mkdir -p "$D"
WF_DIR="$PROJECT_ROOT/.github/workflows"

# 1. Enumerate SCHEDULED workflows FROM THE REPO — never a hardcoded list, or a gate added
#    tomorrow is unwatched from the day it lands.
{ [ -d "$WF_DIR" ] && find "$WF_DIR" -maxdepth 1 \( -name '*.yml' -o -name '*.yaml' \) | sort \
  | while IFS= read -r f; do
      awk '/^[[:space:]]+schedule:[[:space:]]*$/{s=1} END{exit !s}' "$f" && printf '%s\n' "$f"
    done; } | tee "$D/sched" >/dev/null

# 2. ONE `gh run list` per workflow, no more — orient runs on every loop iteration. ANY failure
#    of the probe (no gh, no auth, no network, no remote, unparseable JSON) yields `unknown`.
GH_REPO=$(git -C "$PROJECT_ROOT" remote get-url origin 2>/dev/null \
          | sed -E 's#^(git@[^:]+:|ssh://[^/]+/|https?://[^/]+/)##; s#\.git$##')
epoch_of() { date -u -d "$1" +%s 2>/dev/null || date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$1" +%s 2>/dev/null; }
NOW=$(date -u +%s)
while IFS= read -r f; do
  wf=$(basename "$f")
  # Cadence grace from the cron fields: daily (DOM and DOW both `*`) -> 48h, sparser -> 8d.
  cad=$(awk -F"'" '/^[[:space:]]+- cron:/{split($2,c," "); print (c[3]=="*" && c[5]=="*")?48:192; exit}' "$f")
  [ -n "$cad" ] || cad=192
  # LITERAL stderr path (variable target would be blocked); stdout captured, not redirected.
  if runs=$(gh run list -R "$GH_REPO" --workflow "$wf" --limit 10 \
              --json conclusion,createdAt,event 2>/tmp/ac_board_scan_gh_err) && [ -n "$runs" ]; then
    # streak = consecutive non-`success` verdicts from newest; still-running runs are skipped,
    # never counted green. Verdict/streak read EVERY event (freshest truth about the suite)...
    res=$(printf '%s' "$runs" | jq -r '[.[]|select(.conclusion!="" and .conclusion!=null)] as $d | ($d|length) as $n
      | if $n==0 then "unknown 0"
        else (($d|map(.conclusion)|index("success")) // $n) as $s
             | (if $s==0 then "green" else "red" end)+" "+($s|tostring) end' 2>/dev/null)
    # ...but staleness reads ONLY `schedule` events, else a manual dispatch masks a dead cron.
    last=$(printf '%s' "$runs" | jq -r '[.[]|select(.event=="schedule")|.createdAt]|max // ""' 2>/dev/null)
  else
    res=""; last=""
  fi
  [ -n "$res" ] || res="unknown 0"
  verdict=${res%% *}; streak=${res##* }
  age_h=-1
  [ -n "$last" ] && age_h=$(( (NOW - $(epoch_of "$last")) / 3600 ))
  printf '%s\t%s\t%s\t%s\t%s\n' "$wf" "$verdict" "$streak" "$age_h" "$cad"
done < "$D/sched" | tee "$D/ci-gates" >/dev/null

# 3. Classify. Precedence ALARM > unknown > warn > ok: a gate the probe could not read must
#    NEVER print as green, and a red gate must not be softened by a healthy sibling.
CI_HEALTH=$(awk -F'\t' '{ s=0
    if ($2=="unknown") s=2
    else if ($2=="red") s=($3>=2)?3:1
    if ($2!="unknown") { if ($4<0) { if (s<2) s=2 } else if ($4>$5) s=3 }
    if (s>r) r=s } END{ print (NR==0)?"none":(r==3?"ALARM":(r==2?"unknown":(r==1?"warn":"ok"))) }' "$D/ci-gates")
CI_GATES=$(awk -F'\t' '{ printf "%s%s=%s%s%s", (NR>1?" · ":""), $1, $2, ($2=="red"?"×"$3:""),
    ($2=="unknown"?"":($4>=0?"("$4"h)":"(no-sched-run)")) } END{ print "" }' "$D/ci-gates")
CI_WHY=""
[ "$CI_HEALTH" = unknown ] && CI_WHY=" · probe: $(head -1 /tmp/ac_board_scan_gh_err 2>/dev/null || echo 'gh unavailable')"

echo "ci-gates: $(( $(wc -l < "$D/sched") )) scheduled · ${CI_GATES:-none} · ci_health: $CI_HEALTH$CI_WHY"
```

Verified under `bash` **and** `zsh` against the live `body-compass-app` (3 scheduled workflows →
`ALARM` on the real `e2e.yml` streak) and on every degraded input: `gh` absent from `PATH`,
`gh` present but unauthenticated, no network, and a repo with no scheduled workflow.

**Classification** (shared so consumers can't fork on what "CI is fine" means):

| `ci_health` | Condition |
|---|---|
| `ok` | every scheduled workflow's newest *completed* run is `success` **and** its cron fired inside its cadence grace |
| `warn` | a streak of exactly 1 red (newest red, the one before it green) — one bad night |
| `ALARM` | streak **≥ 2** consecutive reds on any workflow, **or** a cron that has not fired inside its grace (48 h daily / 8 d sparser — a silently disabled schedule, GitHub's 60-day-inactivity auto-disable being the common cause) |
| `unknown` | the probe could not answer for some workflow — no `gh`, unauthenticated, no network, no remote, zero completed runs, unparseable JSON, or no `schedule` event inside the window. **It NEVER collapses to `ok`**: a health check that prints green when it could not check is a fresh instance of the very defect this scan exists to catch. Proof harness: `scripts/ci-gate-health.test.sh` (20 cases, bash + zsh — run it after ANY edit to the block above) |
| `none` | the repo has no scheduled workflow at all (doc repos) — a real answer, distinct from `unknown` |

**Alert DELIVERY is deliberately not wired** (bd-o9vmx, human-gated): there is no Slack webhook
anywhere in the fleet and the curator's "Slack alert" is LLM-emitted prose a human reads,
so picking a channel and provisioning a secret is Craig's call. This scan is
therefore the consumer of last resort — **the loop noticing for itself** — not a notification.

---

## Scan F — board truth (the already-shipped probe)

**An open bead whose work has already merged is invisible to every other scan.** It keeps
its `refined` label, keeps appearing in `br ready`, and is selected as ordinary implement
work — so a conductor spends a full opus child to discover the code already exists. No
other scan catches it: `ac-tidy`'s staleness notion is `br stale` (**age-based, not
artifact-based**), and Scans A–E never open a file or read a commit message.

The cheapest signal is that **the fixing commit often names the bead** — in its subject or
a `Bead:` trailer.

```bash
"$PROJECT_ROOT"/.claude/skills/ac-pipeline/scripts/board-truth.sh   # --cov-base <ref> optional
```

Prints `board-truth: <n> open bead(s) …` then one `<bead-id>\t<cited-epoch>` line per flag.
Exits 0 always. Counts only an id in a commit SUBJECT or behind a `Bead:` trailer; drops
`chore(beads)`/`[no-bead]` bookkeeping and any commit that FILED the bead. Mechanism and
proof harness: `scripts/board-truth.sh` + `scripts/board-truth.test.sh`.

**FLAG-ONLY. This scan MUST NOT close, label, or defer anything.** A false STALE makes the
conductor skip real work, which is strictly worse than the wasted child this exists to
prevent. The output is a shortlist for a conductor to adjudicate by reading the bead's
`## Delivers` and checking those artifacts at HEAD — cheap, because the list is short.

**Verify it still bites after ANY edit:** run `scripts/board-truth.test.sh` (8 synthetic
cases, no repo or beads DB needed). A detector that silently matches nothing is worse
than none.

**Known limitation, deliberately accepted:** a bead someone merely *comments* on gets a
fresh `updated_at` and stops flagging. This scan is the cheap net for the **cited-but-open**
class. The **shipped-uncited** class — work merged with no commit naming the bead — is
caught only by checking a bead's declared artifacts at HEAD, which is not automated here.

---

## The board snapshot (shape returned to the consumer)

```
beads:    { ready[], unrefined[], blocked[], in_progress[], epics[], byLabel{} }
plans:    { draft[], refined[], approved[], beadified[], loop_ready[], unclassified[] }
backlog:  { active[], pool[], candidates[], unclassified[] }   # candidates = status:candidate
ci:       { gates[] (workflow, verdict, streak, sched_age_h, cadence_h), health }
truth:    { flagged[] (bead_id, cited_epoch), count }   # Scan F — advisory shortlist, never an action
```

> **ANY `ci_health` other than `ok`/`none` is NEVER silent.** Every consumer must surface it in its
> own opening output, **even when it is `ok`** — that line is the only thing standing between an
> autonomous run and proceeding on the belief that CI is green. A five-day red nightly that can
> only be found by a later accident is the failure mode being fixed here, and a probe whose result
> is computed and then not printed reproduces it exactly. **The same rule governs
> every `unclassified[]` bucket above** — a read layer must NEVER silently drop an item it cannot
> classify; it routes it to `unclassified[]` and reports it, because an item dropped for being
> unrecognisable is indistinguishable from an item that does not exist.

## Lenses (who reads this board, for what)

| Consumer | Lens (its own judgment, NOT here) | Extra reads beyond the board |
|----------|-----------------------------------|------------------------------|
| **`ac-align`** | strategy fit · `pool → active` promotion · sequencing | `_strategy/` |
| **`ac-tidy`** | lifecycle reconciliation · archival · orphan/stale flags | bead↔plan cross-references |
| **`ac-human-session`** | human gates only (apply the loop boundary: drop ready beads, in-flight waves, `loop-ready` plans) | PRs (`gh pr list`), prod health, org-wide `human-gate` sweep — **scheduled-CI health comes from Scan E, not an ad-hoc `gh run list`** |
| **`ac-dashboard`** | render-only — the WHOLE board, both sides of the loop boundary; no judgment, no writes, no prompts | wave branches (`git branch -r`), PRs (`gh pr list`), **Scan E for scheduled gates** (own `gh run list` only for the CURRENT head's checks) |
| **`ac-loop`** | Phase 0 orient — classify the actionable set (orphans · unrefined · plan waves · bug lane) + the parentage-gap/epic-edge structural lint, to drive the autonomous run; **print Scan E's `ci-gates` line EVERY run, `ok` included; print Scan F's `board-truth` line EVERY run, `0` included, and adjudicate any flagged bead BEFORE dispatching an implement child at it; print Scan A's `docket-health` line EVERY run** | `bv --robot-triage`, `loop-ready` plans, `.claude/legacy-branches.txt` |

The board is the shared substrate; the lens is each skill's reason to exist. Don't move a lens
in here, and don't re-specify a scan out there.
