# ac-implement · scheduled — the unattended autopilot run

The hourly gate (`scripts/autopilot-gate.sh`) starts this session only when P0–P1 work exists. This
file is a run skeleton: every behaviour lives in the skill it names, so call that skill, restate nothing.

**Authority.** The stage-table clause in `ac-pipeline/references/stage-table.md` plus the project's
`.claude/factory.json` `autopilot` block, read ONLY through `skills/_tools/autopilot.sh` (`get <key>`).
It grants Polish (bead mode), Implement and the batch push. It never reaches Ship: no version, tag
or store submission. `AC2_AUTOPILOT=1` and `AC2_AUTOPILOT_STATE` are already exported — keep them
in every child's environment.

**Unattended rule.** Nobody answers a prompt. Any human stop becomes a human-gate bead per
`beads-standards/reference/human-gate-template.md` (`ACTION:` card or `DECISION:`), always P1 so
Gate Watch posts it. Never ask, never wait. `<scripts>` is the symlink-resolved `scripts/` dir of this skill.

## 1 — Orient

Run Phase 0 of `ac-implement/SKILL.md` (register with Agent Mail, roster and claim snapshot,
agent-staleness check, `refly.sh`, `pick.sh --count`). Anything UNKNOWN or stale, or any gate
reporting `NEXT: handback`, is not a prompt: send the line
`slack-send "AUTOPILOT DEGRADED: <reason>"`, write the report (§ 6) with `degraded` set, exit 0.

Then turn every skipped protected bead into a gate card, never a silent skip:

    bash <scripts>/pick.sh --count 2>&1 >/dev/null | sed -n 's/^PROTECTED //p'

For each id: `bash <scripts>/return-hold.sh <id> --reason "authorization autopilot-protected" --actor <conductor>`.

## 2 — Polish

At most TWO epics that have unrefined P0–P1 open children, via `ac-polish/SKILL.md` with
`ac-polish/workflows/bead.md` (standalone beads share one artifact). `max_priority` from the block
is the ceiling. A bead that fails to converge twice in a row (`REFUSED` or `ENDED`
twice) gets an `ACTION:` card with the reader's open findings; it stays unrefined.

## 3 — Implement

Skipped while `autopilot.sh get implement` prints `false`. Otherwise run `ac-implement/SKILL.md`
Phases 1 and 2 with `--width` and `--cap` from `autopilot.sh get width` / `get cap` (an absent key
means the skill default). The swarm's own `push.sh` outcome is the push of record. A worker
`autopilot-protected` refusal is a hold: `return-hold.sh` as above, then continue.

## 4 — Ledger and push

When Implement ran, its Phase 2 already committed the ledger and pushed: report that outcome.
When it was skipped, polish stamps are only on disk, and the nightly tidy rebuilds the board
from origin, so an uncommitted ledger is lost. Commit it through the coordinator's lane
(`bash <scripts>/coordinator.sh --run <run-id> --actor <conductor>`, whose commit subject carries
`[no-bead]`), then `bash <scripts>/../../ac-pipeline/scripts/push.sh`. Exit 3 is not a failure:
record `push pending: <file>` in the report and carry on. Exit 1 is a failure — report it.

## 5 — Release card

Exactly one open `release`-labelled P1 `ACTION:` card, template in the human-gate file above.
Find the last tag with `git describe --tags --abbrev=0 --match 'v*'`, then list app code since it:

    git log --format='%h %s' <tag>..HEAD -- . ':!.beads' ':!_plans' ':!_docs' ':!.claude'

Commits listed and no open card: create it (`Gate-reason: authorization — a release is human-authorized`,
the commits in its body, `best-done-when: at the Mac, via ac-publish`). Commits listed and a card
open: update its body with the current list. No commits and a card open: close it. The run never
publishes, versions or tags.

## 6 — Report

Write `$AC2_AUTOPILOT_STATE/last-run.json` as ONE JSON object, even when degraded — the gate
treats a missing file as a failed run:

    {"polished": N, "closed": N, "protected": N, "pushed": ["<head sha>"], "push_pending": "<file>"|null,
     "gates": N, "degraded": "<reason>"|null}

`closed` is a number and `pushed` an array of push.sh head SHAs (`[]` when none): the gate's
`--verdict` reads exactly those two. Then send ONE Slack card from it with
`slack-send --card --status <healthy|degraded> --title "Autopilot" --field k=v ...`, and exit 0.
