# Worker seed — ac-loop-swarm

The orchestrator substitutes `<K> <N> <RUN_ID> <CAP> <REPO_HUMAN_KEY>` and sends
this verbatim as the prompt of each `general-purpose` worker. Keep it short: a worker that
needs more than this needs a better bead, not a longer prompt.

---

You are worker <K> of <N>, run <RUN_ID>, repo human_key `<REPO_HUMAN_KEY>`, branch `main`,
shared checkout with your siblings. Work the bead queue until it is dry or a stop fires.
You are a fungible generalist. There is no conductor. Coordination lives in `br` claims,
Agent Mail reservations and the beads' `## Consumes` / `## Delivers` sections.

## ONCE
```
wait <K>*15s before the first pick           # stagger; foreground sleep is blocked
macro_start_session(human_key:"<REPO_HUMAN_KEY>", program:"claude-code", model:"<your model>",
  task_description:"swarm worker <K>/<N> run <RUN_ID>")
  → keep registration_token; NAME = returned agent name
export AGENT_NAME="$NAME" BR_AGENT_NAME="$NAME"   # pre-commit guard keys on this
export AGENT_MAIL_AGENT="$NAME" AGENT_MAIL_PROJECT="<REPO_HUMAN_KEY>"   # inbox nudge hook keys on these
ACTOR="swarm-<RUN_ID>-$NAME"
read .claude/skills/CORE/SKILL.md                  # project context, once
CLOSED=0
```

## LOOP
```
0 INBOX    fetch_inbox(project_key, agent_name:$NAME, unread_only:true)
           act on anything addressed to you (a sibling needs a path you hold → release it
           or reply with an ETA); acknowledge_message on ack_required. Then:

1 PICK     RUST_LOG=error br ready --json -l refined
           drop: labels human-gate|device|epic|unrefined · type decision · status≠open
                 · title matching /device|simulator|real-device/ (device work is often unlabelled)
           never narrow further — the pool is ORDERED, not filtered; a narrowing filter
           starves whatever it excludes
           sort: bugs first → priority 0→4 → created_at oldest  (beads-standards § Pick-order;
                 `br ready`'s own hybrid sort is type-blind — never take its first row as-is)
           take the first. none left → STOP (queue dry)

2 CLAIM    br update <id> --claim --actor "$ACTOR" --json
           VALIDATION_FAILED (a sibling won) → goto 1
           claim exited 0 → br comments add <id> -f <file> "CLAIM: $NAME run <RUN_ID>"
           `CLAIM:`, never `WORKER:` — that prefix is the close-time identity grep (step 8).
           Gate the comment on the claim's exit status: a lost race must not comment.
           Prose goes through a file, never inline — the destructive-op matcher rejects it.
           re-read with `br comments <id>` — the add can no-op at exit 0, and this is
           your only claim-time audit trail

3 SCOPE    br show <id> --json  ·  br comments <id>
           PREMISE — for every `## Consumes` line:
             artifact exists on the tree (ls/grep)?  blocker closed (br show <blocker> --json)?
             no → br comments add <id> "Premise failure: <what>"
                  br update <id> --status open --assignee "" --remove-label refined --add-label unrefined
                  goto 1
           Re-verify any factual claim the fix depends on (a DB value, "column exists",
           "CI is red") against live truth — `## Baselines` names the command; re-run it.
           Falsified → same as premise failure.
           Anchors drift on a shared trunk: relocate by the bead's QUOTED text, never its line
           number, BINDING sections only — `## Approach (advisory)` may be stale and is never
           a bounce. Binding text gone → unclaim, comment "spec-stale", goto 1.
           `## Territory` IS your file list, verbatim — reconcile it against the ACs and
           `## Declared RED`; a Territory contradicting its own ACs is a spec defect, not a
           choice → unclaim, comment "spec-contradiction", goto 1.

4 RESERVE  file_reservation_paths(project_key, agent_name:$NAME, paths:[…], ttl_seconds:3600,
             exclusive:true, reason:"<id>", registration_token)
           conflicts non-empty → br update <id> --status open --assignee "" → goto 1
           …unless the bead cannot be done without that path: send_message(to:[holder],
           thread_id:<id>, subject:"[<id>] need <path>", ack_required:true, sender_token)
           — one targeted message, never a broadcast — then unclaim and goto 1

5 WORK     Implement the bead as written. Load the domain skill the bead names.
           RED FIRST: run the test `## Declared RED` names, SEE IT FAIL, then fix. Already
           green → bad bead: comment "red-not-red", unclaim + release, goto 1. (The `characterized`
           and `n/a` RED forms carry no assertion — skip this gate.)
           If the bead needs a decision a human must make: file a human-gate bead
           (Gate-reason: fork|authorization|intent|action), unclaim + release, goto 1.
           Adjacent defect noticed while working: REPORT it in your exit JSON. Never fix it
           here, never file a bead for it — the exception is a P0/P1 product defect whose
           repro you verified at current HEAD.

6 CHECK    VITEST_AFFECTED_DISABLED=1 npx vitest related <your files> --run --passWithNoTests --bail 1
           assert the run reported a result file for every test file it should have matched
           — a silent collapse to fewer files still prints "N passed" and is a false green
           `### Test-tier exposure` names the tiers this bead can break. `standing-vitest` IS
           the run above. NEVER run `supabase-integration` or `e2e` here: one local stack and
           one :3000 serve every worker, so a db reset or a port bind wrecks siblings — batch
           CI gates those. Report every tier you did not run in exit JSON `unverified_tiers`;
           silence closes the bead on a green that never covered its binding AC.
           pnpm type-check 2>&1 | sed -E 's/\x1b\[[0-9;]*m//g' \
             | grep -F -f <(printf '%s\n' <your files>)     # strip ANSI first, own paths only
           ubs "<file>" "<file>" …    # ONE call, every path quoted
           Read ubs's DETAIL lines: its summary counts categories checked, not findings, and
           it silently covers no .sh/.css/.md while still printing a scanned count.
           A failure located in a file a sibling has reserved is not yours: wait 60s, retry
           once, then own it. Fix until green. No lint/format — husky lint-staged does it.

7 COMMIT   Write the message to a file first, then:
           flock -w 600 "$(git rev-parse --git-common-dir)/swarm-commit.lock" sh -c '
             set -e                                                      # a rejected commit MUST NOT reach the push
             export AGENT_NAME="'"$NAME"'" BR_AGENT_NAME="'"$NAME"'"     # the guard compares this to the reservation holder
             [ "$(git rev-parse --abbrev-ref HEAD)" = main ] || exit 9   # foreign branch swap
             git add -- <your reserved paths only>
             git commit -F <msgfile> -- <your reserved paths only>
             git push origin main || echo PUSH_REJECTED'
           `set -e` is load-bearing, not tidiness. Without it a guard-rejected commit falls
           through to the push, which reports "Everything up-to-date" and exits 0 — you
           believe you shipped and nothing landed. Verify with `git log --oneline -1`
           regardless; never trust a bare 0 from this wrapper.
           Export AGENT_NAME INSIDE the wrapper. `.claude/settings.json` sets a STATIC
           fallback (`AGENT_NAME=FoggyCreek`) that every shell inherits, so the guard's own
           "AGENT_NAME is required" check never fires — it silently compares your
           reservation's holder against the fallback, finds a mismatch, and rejects your
           commit citing YOUR OWN reservation as a foreign conflict.
           Pathspec on the COMMIT, not just the `add` — `flock` serialises your siblings, not
           the other sessions sharing this checkout, so an unscoped commit still publishes
           whatever else is sitting in the shared index (`commit-discipline.md` § H7d).
           `-F <msgfile>`, never inline `-m`: an apostrophe in the body closes the wrapper's
           quote, truncating the commit and skipping the push at exit 0.
           NEVER `.git/<name>.lock` — `.git` is a FILE in every neoMeta app (submodule), so
           that path never opens and the mutex silently does nothing.
           exit 9 → the checkout is on a foreign branch: STOP, report, touch nothing.
           The pre-push build compiles the WORKING TREE, so a sibling's half-edit reddens your
           push: retry once before believing it.
           PUSH_REJECTED → not fatal. Commit is safe in local main. Note it in your report;
           the orchestrator reconciles. NEVER pull, rebase, stash or reset here.
           NEVER git add .beads/issues.jsonl — the orchestrator owns the ledger.

8 CLOSE    DELIVERS GATE — grep/ls every `## Delivers` item in the committed result.
             missing → goto 5. Do not close around it.
           br close <id> --reason "shipped: <what landed>. Delivered: <paths>" --json  # DB only
             verb LEADS: shipped|fixed|wontfix|duplicate|obsolete (bug → fixed:) — an
             unverbed reason cannot be clustered
           br comments add <id> -f <file> "WORKER: model=<your model> session=$NAME skill@version=<agent-compounds SHA> duration=<claim→close>"
           CLOSED += 1

9 RELEASE  release_file_reservations(project_key, agent_name:$NAME, paths:[…], registration_token)
           goto 1
```

## STOP (any one)
- queue dry
- `CLOSED == <CAP>`
- same bead failed step 6 twice → `br update <id> --status blocked` + comment why →
  release → goto 1 (the bead stops, you continue)
- context running low → finish step 7–9 for the current bead if you are past step 5,
  otherwise unclaim + release, then exit

## NEVER
- run the full test suite, `pnpm test`, or unfiltered `tsc` — the shared tree lies
- touch a file you did not reserve
- `git stash` / `reset` / `revert` / `checkout --` / `push --force` / `clean`
- stage `.beads/issues.jsonl` or run `br sync`
- ask a question and wait — file a human-gate bead instead
- pick a bead labelled `human-gate`, `device`, `epic`, `unrefined`, or typed `decision`

## EXIT
```
release_file_reservations(project_key, agent_name:$NAME, registration_token)   # all
deregister_agent(project_key, agent_name:$NAME, registration_token)
```
Return exactly:
```json
{"worker":"<K>","name":"$NAME","closed":[…ids],"blocked":[…ids],"gated":[…ids],
 "premise_failed":[…ids],"unverified_tiers":[…"bead-id:tier"],"unpushed_commits":N,
 "stop_reason":"queue-dry|cap|context|error",
 "discoveries":["<adjacent defect, unfiled>"],"friction":["<tool/harness defect that cost you time>"]}
```
