# Docket queue lanes — collapse the flood, never the emergency

A **queue lane** is one machine-filed batch of gate beads from a single upstream source.
`scripts/docket.sh` detects and renders lanes; this file carries the rules it implements and
the declaration format an app uses.

## Three rules, in order (computed)

1. **Collapse >5 to ONE block.** Any non-lifecycle label carrying >5 on-docket gate beads renders
   as a stacked block — `🔁 {LANE} · {N}` then an indented `oldest {age}` row — and its P2+
   members are never itemized. Collapse is presentation, not deferral: the lane block **is work
   in this sitting** — after the independent P0/P1s, auto-advance into it. `{N} remaining` and
   `~{est} min` never count a lane.
2. **P0/P1 are NEVER collapsed.** They are itemized above the lane block and excluded from its
   count. A lane label is a *filing* channel, not a statement of importance.
3. **Elevate at `>=20` members OR oldest `>21` days** → an indented `⚠ elevated — run this
   sitting` row inside the block, a first-class tap above 🟢. Collapse and elevation are
   independent thresholds.

## Declared lanes — the app's batch card

An app declares its own batch lanes in `<project>/.claude/docket-lanes.json`. The registry never
names an app's lane; an app without the file sees only the three rules above.

```json
{ "lanes": [ {
    "label": "<bead label>",
    "name": "<short lane name>",
    "fields": { "<field>": [ { "from": "title|description", "re": "<regex, group 1 = value>" } ] },
    "line": ["{field}", "{other}"],
    "unanimous": [ { "from": "description", "re": "<regex that matches only a unanimous recommendation>" } ]
} ] }
```

- A declared lane always renders as ONE block, whatever its size: each member its own
  `✓`/`·` id row + a wrapped line built from `line` segments (a segment whose field does not
  match is dropped) — unanimous marked `✓`, split marked `·`. Extractors are tried in order;
  the first match wins.
- `unanimous` must match ONLY a structured marker the filer writes — never free prose. A missed
  unanimous costs one manual tap; a false one applies a ruling nobody made.
- The block offers **accept N unanimous** (`references/action-loop.md`), then walks the split
  members one by one.

## Lane-health checks

- **Unreadable titles are a FILING DEFECT.** >5 members whose title carries a raw uuid/hash →
  docket.sh flags it; offer a re-title pass (the subject is usually in the body or the source
  system) and fix the filer too.
- **A lane filed before its governing policy was ratified is STALE BY CONSTRUCTION** — some
  members are now auto-resolvable. Judge the fraction expected to survive re-triage and state
  it, rather than presenting the raw count as all real human work.
