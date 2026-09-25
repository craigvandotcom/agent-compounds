---
name: ac-beadify
description: 'Compile an APPROVED ac2 plan into lean beads — the four-section ac2 schema, a wired dependency graph, and plan retirement. Refuses any bead whose ACs name no executable probe (no probe, no bead). Triggers: "ac2 beadify", "compile the plan into ac2 beads", "ac2 beads from plan". To grade the result use ac-polish.'
---

# ac-beadify — plan in, lean beads out

## I/O Contract

|                  |                                                                              |
| ---------------- | ---------------------------------------------------------------------------- |
| **Input**        | One plan `plan-approve.sh check` accepts (`ac-plan`, graded by `ac-polish` plan-checklist) |
| **Output**       | Beads in `br` on the ac2 schema, with every dependency edge wired both ways    |
| **Artifacts**    | The epic bead; the plan moved to `_plans/_done/` (retirement)                  |
| **Verification** | `br dep cycles` · `br lint` · the probe-extractor below · Consumes↔edge parity |

Contract compiled TO: `references/bead-schema.md` (mandatory load); canon by pointer:
`skills/ac-pipeline/SKILL.md`, `beads-standards`.

## The refusal that defines this skill

**No probe, no bead.** An AC that names no executable probe is REFUSED, emitted nowhere,
returned to the plan — a refusal, never a warning, never a label: softening it IS the
vacuous-AC regression (measured H-impact, recurrence 5). Mechanically, for every candidate bead:

```sh
# every AC must yield a probe; every probe must be runnable AND RED against current HEAD
grep -o 'Probe: `[^`]*`' "$BEAD" | sed 's/^Probe: `//; s/`$//' \
  | while IFS= read -r p; do
      sh -n -c "$p" || { echo "REFUSED: unrunnable probe: $p"; continue; }
      sh -c "$p" >/dev/null 2>&1 \
        && echo "REFUSED: already green — this probe passes before the work exists: $p"
    done
```

Count the extracted probes against the AC bullets; fewer = REFUSED. A prose fragment
(`wc -l`, "diff the file") is not a probe. **Execution is part of the refusal** — a probe
already green at compile REFUSES the bead (dogfood #2 measured 19; baseline in
`ac-pipeline/FRICTIONS.md`). One that cannot run (state-mutating, needs a device/credentials)
goes on an explicit NOT-EXECUTED list — never a silent skip; one naming an artifact this bead
has yet to create keeps the guarded form `test -x <path> && bash <path>`, honestly RED at compile.

## Procedure

1. **Read the plan and check it mechanically.** Load `references/bead-schema.md`. Run
   `skills/_tools/plan-approve.sh check <plan>`, then `skills/_tools/planned-layer.sh check
   <plan>` — the writer's own read-back, never a hand grep of its keys. Non-zero from either
   (`REFUSED …` or `NOT-GATED …`) is REFUSED and the plan is returned, never compiled: the
   second catches an overlap the board grew since approval.
2. **Cut the work into beads.** Sizing is from the bead-checklist, never from taste: one bead
   = one focused worker pass. Two signals govern the cut, both cheaper here than at implement:
   - **Split signal** — heavy in-bead cognition at implement time means it was too big; split it.
   - **Under-specification is a PREMISE-FAILURE class** — a worker must never grind through an
      underdetermined bead improvising decisions the bead should have made; a fork the plan does not
      settle appends a `needs-human` card to `## Decisions` per the one card grammar in `skills/ac-plan/references/decisions.md`, sets `status: refined`,
     prints `beadify-refusal: needs-human` on its own line and stops — a plan defect surfaced
     to the docket, never a bead, never a human gate.
3. **Write each bead to the four-section schema, exactly.** `## Intent` · `## Acceptance
   Criteria` · `## Delivers` · `## Consumes` — first header per type: `bug` → `## Steps to
   Reproduce`, `epic` → `## Success Criteria` (`br lint` compiles those in). Nothing else.
   **Line numbers are banned in Intent.** The epic's AC is the plan's silver bullet verbatim,
   and `## Success Criteria` still opens with the plan's `## Vision` verbatim. Every child AC
   quotes its plan "Done when:" verbatim and adds only the probe; a split deliverable has each
   child quote the parent line and add its own slice's values. "a test named X passes" is not an AC.
4. **Apply the refusal** (§ above) to every bead before any of them is created. Refuse the
   bead, not the batch — but do not create a partial graph around a refused node.
5. **Wire Delivers/Consumes as the graph.** `## Delivers` names artifacts; a dependent's
   `## Consumes` cites `<blocker-id> -> <artifact>` that the blocker's Delivers promises, or
   `none`; a `<…>` placeholder is REFUSED (it reads as a premise). Then create the edges and
   read them back: direction is `<blocked> depends-on <blocker>`, a reversed `br dep add` is
   SILENT, so read every edge back (`br dep cycles`, then `br show` on both ends). Every
   child of the compiled epic gets ONE edge — parent-child (containment) — read back the
    same way. The no-probe refusal names epics explicitly (a probe-less epic is refused like any other bead); parity holds both ways.
- **`## Planned layer` rows wire the same edges, cross-epic.** A `consumes` row becomes a `blocks` edge to the named bead from every new bead whose `## Delivers` shares the row's scanned path (`planned-layer.sh scan <plan>` names the match), read back the same way; a `supersedes` BEAD row closes that bead (reason: `superseded by <epic>`); a `supersedes` PLAN row stamps `superseded_by: <this plan>` on that plan and joins this compile's own retirement walk (§ below).
- **One path per `## Delivers` bullet, and every delivered path that git ALREADY TRACKS owes a
      touchers line.** `skills/_tools/touchers.sh derive <path>` prints `<stem> <N> <command>`;
      write it beneath the bullet as ``touchers: `<command>` → <N> · owned by: <sibling bead>``
      — else `out-of-scope: <why>`.
5b. **Emit the closeout bead** — D3: every plan-derived epic gets one even with no one-shots
    (keyed off `beadified:` absent); emit the closeout bead per `references/bead-schema.md` § Closeout (D8 shape, edges + readback, one-shot refusal D4, `Detect:` lift D7).
6. **Create the beads** per the schema's Header fields (an epic off `<Name> — <what it implements>` is REFUSED) — bodies go `-d "$(cat <file>)"` (`br create` REJECTS `-f` with a title); bead text stays dcg-safe.
7. **Retire the plan** (§ below).

## Plan retirement — the seams chain, and the one case that refuses it

On a successful compile the plan file is **moved to `_plans/_done/`**, the epic bead gets a
comment naming its new path; the plan is preserved, never deleted.

**A plan is never necessarily a single file — retire the whole reachable chain.** The walk follows ANY frontmatter value on this plan, and every plan it leads to, that names an existing `_plans/` file — not a fixed key list (`seams_source:` / `parent:` / `supersedes:` / `splits[]:` / `seeded_from:` all qualify, same as anything future) — moving each to `_plans/_done/` (not just `$PLAN_FILE`), stamped `status: done` + `beadified: <epic-id>`, RETIREMENT HELD guard (§ below) per file.
Skip a target that is `status: approved` and not beadified — that plan is still promised work of its own, never retired here.

**REFUSE to retire while an open bead needs the plan as its subject** — its `## Delivers` or `## Consumes`
names the plan; Intent provenance and this compile's own epic and children never hold it. Held: leave the file, say so.
```sh
RUST_LOG=error br list --status open --json | EPIC="$EPIC" NAME="$(basename "$PLAN_FILE")" python3 -c 'import json,os,re,sys
d=json.load(sys.stdin); d=d if isinstance(d,list) else d.get("issues",d); e=os.environ["EPIC"]
print(*[i["id"] for i in d if not (i["id"]+".").startswith(e+".") and os.environ["NAME"] in "".join(re.findall(r"^## (?:Delivers|Consumes)\n(.*?)(?=^## |\Z)",i.get("description") or "",re.M|re.S))])' | grep . && echo "RETIREMENT HELD"
```

The guard lives HERE — the only place its condition still holds.

## Hand-off

End with `Next: /ac-polish bead <epic>` and stop.
