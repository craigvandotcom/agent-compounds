---
name: ac-publish
description: 'The ship spine — runs a project''s `.claude/factory.json` ship block: preflight, version, prove, human authorize, promote, verify, tag; `beta` route for test builds. Triggers: "ac2 publish", "ship the ac2 batch", "release this batch" — run by the operator once a batch is ready to ship. NOT the commands themselves: the project owns them, bound by ship-contract.'
---

# ac-publish — run the project's ship block

Stack-free: the project declares every command under `ship` in `.claude/factory.json`; this skill
runs them in order and owns none of the mechanics. Rules each command holds:
`references/ship-contract.md`. Onboarding: `references/distribution.template.md`. Schema:
`templates/factory.json`.

| | |
| --- | --- |
| **Input** | A closed batch on the committed tree; the project's `ship` block |
| **Output** | A promoted and verified build at a PROVEN SHA, tagged on release — or a refusal and no ship |
| **Verification** | The block's own `prove` and `verify`; `scripts/needs-device-gate.sh` (apps declare it in preflight) |

## Run start — check the block

```bash
jq -e '.ship | (.preflight | type == "array") and (.prove | type == "string")
  and (.targets | type == "array" and length > 0 and all(.[]; .name | type == "string"))
  and (.version == null or (.version | has("bump") and has("read")))' .claude/factory.json >/dev/null
```

Non-zero, or no `ship` block: `NOT-GATED` — refuse, ship nothing. A `null` `version`, `promote` or
`verify` logs `SKIP (declared): <step>` and the run continues. A `null` `prove` is `NOT-GATED`: a
gate that cannot verify never reads as a pass.

## Route

Ask `release` or `beta`; offer `beta` only when `jq -e '[.ship.targets[] | select(.beta == true)] | length > 0'`
holds. `beta` runs only the targets declared `"beta": true`, bumps no version and tags nothing.

## Ship, in this order

1. **Preflight.** Run each `ship.preflight[]` entry from the app checkout. Any non-zero stops the ship; name it.
2. **Version** (release only). `version.read` above the latest tag: reuse it, never bump twice.
   Otherwise run `version.bump` once — it commits. Compare as semver: a prerelease such as
   `2.0.0-ws2` is BELOW `2.0.0`, and `sort -V` orders it above. `null`: no bump, no tag.
3. **Prove.** Run `ship.prove --ref "$R"` at the bumped commit. Its LAST stdout line is the proven
   SHA; non-zero is FAIL. Use that SHA for every later step, never `R` or `HEAD`. No fix-forward
   inside a run: a failed proof stops it.
4. **Authorize.** One `AskUserQuestion` listing the route's targets; the human picks which run.
   Unattended: stop and leave the ship on the docket (`ac-human`).
5. **Promote, then verify.** For each picked target, `promote <SHA>`, then `verify <SHA>`. Any
   non-zero stops the ship before the tag.
6. **Tag** (release only). Tag the verified SHA as `v<version.read>`, then `git push` the tag.

Out of scope: the commands behind each step (the project's), QA selection (the verification-gate
class table in `skills/ac-pipeline/references/`), inbound triage.

Retiring, kept until the first release through this spine has run: `references/web-promote.md` ·
`references/executed-jobs.md` · `references/migration-gate.md`.

Next: /ac-land
