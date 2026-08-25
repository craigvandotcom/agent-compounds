# Origin provenance — `origin:<skill>`

Machine-wide canon for the bead provenance axis. Spine rule: `beads-standards/SKILL.md`
§ Agent bead template. Pipeline-contract detail: `reference/bead-conventions.md`.

## The label

Every bead carries exactly one `origin:` label naming the workflow that created it.

| Label | Meaning |
|---|---|
| `origin:<skill>` | The skill that created the bead — `origin:ac-review`, `origin:ac-hygiene`, `origin:ac-beadify`, `origin:ac-triage`, `origin:ac-qa-device`, `origin:ac-qa-browser`, `origin:curate-foods`, `origin:dream`, `origin:reflect`, `origin:ac-land`, `origin:ac-tidy`, `origin:ac-batch-close`, `origin:ac-align`, `origin:ac-prove`, `origin:ac-bead-capture`, `origin:ac-bead-refine`. |
| `origin:manual` | Hand-authored, created outside any skill. |
| `origin:unknown` | Genuinely unattributable. Legal and honest — mirrors the `discovered-from: unknown` precedent. Never guess, never invent a source. |

Put `origin:` FIRST in the label list. One origin per bead: two is corrupt data.

## Not the same as `skill:<name>`

`skill:<name>` names the bead's SUBJECT — "this bead is about ac-loop". `origin:` names its
CREATOR. Independent axes; a bead may carry both, and often should. Do not merge them.

Also distinct from `discovered-from:`, which names the SOURCE BEAD an escape traces to.
`origin:` names the creating workflow. Complementary, not duplicates.

## Enforcement

Three layers, because prose alone was measured insufficient:

1. **Creation gate** — `hooks/bead-capture-guard.py`, a PreToolUse Bash hook, blocks any
   `br create`/`br q` whose `-l/--labels` carries no `origin:` token. Tokenizes with shlex,
   so a `br create` quoted inside a description or heredoc never false-blocks. Fails OPEN on
   unparseable shell: a guard must not wedge an unattended run.
2. **Scripted creation** — the hook cannot see `br` invoked as a child process from Node/TS.
   Those paths enforce in code instead: `BrCreateOptions.origin` is a required field, so a
   call site that omits it fails the TypeScript build.
3. **Refine backstop** — `ac-bead-refine` repairs a missing `origin:` at stamp time
   (inferring where obvious, else `origin:unknown`). It never withholds `refined` for it.

Nightly, `ac-tidy` reports post-cutover beads still missing `origin:` — a guard bypass or a
stale template, never auto-labelled.

## Forward-only — no backfill

Enforcement does not rewrite history. Most pre-cutover beads carry no recoverable origin
signal, so inventing one would fabricate provenance rather than record it. The `ac-tidy`
lint therefore excludes pre-cutover beads entirely; without that exclusion the report drowns
in rows nobody can honestly fix.
