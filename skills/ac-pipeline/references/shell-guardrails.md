# Shell guardrails — writing commands an agent shell actually executes as written

Two classes live here. **Blocked shapes** — the `dcg` command guard rejects the command, loudly
(§ What actually gets blocked, § Sanctioned shapes). **Silent shapes** — the command runs, exits
without complaint, and returns something that is not what you asked for (§ Silent failures).
The second class is the expensive one: a loud block costs a retry, a silent one costs a wrong
conclusion that nothing downstream contradicts.

**Read this the first time a `dcg` rule blocks one of your commands.** Cumulative measured
recurrence across four consecutive loop runs: **26+ blocks**, most of them children running a
setup snippet a skill handed them. A block is the guard working — **change the command shape,
never bypass it.**

**This doc deliberately never quotes the offending constructs.** The rules match on command
TEXT, so a document that pasted a live example would be blocked on the way in — that has
happened twice, once to a bead comment that merely quoted a redirect character and once to one
that quoted a git verb. Constructs below are therefore named, not shown. If you extend this
file, keep that discipline.

## What actually gets blocked

`core.filesystem:redirect-truncate-dynamic-path` is the frequent one. It fires on a
**truncating** stdout redirect whose target path is built from a shell variable rather than
written out literally. That covers nearly every artifacts-dir and state-file write in the
`ac-*` pipeline.

**The rule keys on truncation only — appending is never blocked, and a heredoc is not an
independent trigger.** Probed five ways against **dcg 0.6.7** (2026-08-03, all targets
variable-built): the truncating form, and that same truncating form when fed by a heredoc, are
BLOCKED; the appending form, a brace-group append, and an append fed by a heredoc are all
ALLOWED. dcg's own
explain text lists the appending form as a safer alternative, so do not read this rule as a
ban on preserving-writes. Re-probe before trusting this paragraph on a newer dcg: the parse
is positional, so write the candidate to a literal `/tmp` file first and pass it to `dcg test`
as a command substitution — a command that merely quotes the construct is itself blocked.

Four things make it bite wider than its name suggests, all measured:

1. **The parse is positional, not semantic.** The redirect operator is matched *anywhere on the
   command line*, so a long quoted payload — a bead comment body, a commit message, an inline
   SQL string — is blocked when its ordinary prose happens to contain an arrow-shaped token or
   an angle-bracket placeholder. No redirect need be present.
2. **In-place editors are caught with no redirect at all.** `perl -i` and `sed -i` write temp
   files; the source command contains no redirect and is still rejected.
3. **The verdict is whole-command.** One non-compliant statement blocks every statement sent in
   the same call, the compliant ones included. So a sanctioned write looks broken whenever a
   neighbour in the same block still truncates into a variable-built path — find the offending
   statement, do not rewrite the compliant ones. An error-stream redirect to a variable-built
   path is non-compliant on its own and takes the whole compound with it. Split compound
   commands; never decorate them.
4. **A separate rule, `core.git:checkout-ref-discard`, covers the git verb that restores a path
   from another ref** — including on a clean path.

## Sanctioned shapes (each one empirically confirmed to pass)

| Instead of | Use |
|---|---|
| a redirect into a variable-built path | the **Write tool**, or pipe into **`tee <path>`** — `tee` takes its destination as an *argument*, so there is no redirect operator to match. `tee -a` appends. Prefer a fully-literal `/tmp/...` destination where the run does not need per-run scoping. Keep `tee`'s own redirect fully literal: giving `tee` a variable-built redirect target reintroduces the block. This shape holds inside a multi-statement compound command — see the whole-command rule above. |
| `perl -i` / `sed -i` in-place rewrites | the **Edit tool** (one call per file; `replace_all` for repeated tokens) |
| a long quoted CLI payload (`br comments add`, `br update --description`, a commit body) | write the body with the **Write tool** to a literal `/tmp` file, then pass it as a command substitution that reads that literal path. Strip backslash line-continuations and nested escaped quotes from the payload first — they are what the escaping heuristic matches. |
| a heredoc into a variable-built path | the **Write tool** (and note heredocs containing a dollar sigil have been blocked independently of their target) |
| the git verb that discards a path from a ref | `git show <ref>:<path>` piped onward — into `tee`, or into a tool's stdin flag such as `eslint --stdin`. Read-only and accepted. |
| a truncating write that must stay in shell (script context, no Write tool in reach) | **resolve-then-paste**: `echo` the variable path ONCE, then paste the printed LITERAL into the redirect (`> /tmp/bead-work-…/beads.json`, never the raw `$ARTIFACTS_DIR` token) — the same compose-from-printed-literals discipline the teardown delete path uses. Skill snippets showing `> "$ARTIFACTS_DIR/…"` are illustrative shorthand, not runnable forms. |
| `gh ... --template` with escaped interpolation | `gh ... --jq '<program>'` with the program in **single** quotes |

## Silent failures

### An alias can shadow a POSIX utility name — verify with `type` before you rely on one

**The rule: before a pipeline's correctness depends on a short utility name, run `type <cmd>`.
If it resolves to anything but a file or a shell builtin, invoke it as `command <cmd>` (or its
absolute path) — on this fleet that means `command tr`, never bare `tr`. Never assume a two- or
three-letter name reaches the POSIX utility.**

Agent shells are spawned from the user's interactive profile, so every alias in that profile is
live. An alias is looked up *before* `$PATH`, so the utility can be on `$PATH`, be perfectly
functional, and still never run. Measured on this fleet (re-confirmed 2026-08-08):

```
$ type tr
tr is an alias for tmux new-session -A -s repos -c ~/Repos
$ printf 'a,b\n' | tr ',' '\n'
open terminal failed: not a terminal        # stderr
                                            # stdout: EMPTY
$ printf 'a,b\n' | command tr ',' '\n'
a
b
```

tmux cannot attach in a non-interactive shell, so the substitution yields an **empty string** —
and an assignment swallows the exit status, so nothing in the pipeline notices. Anything shaped
`N=$(… | tr …)` then evaluates to empty and takes the "nothing to do" branch: the reassuring
answer. Two instances in a single refine run — an empty target-id array at Phase 0 (caught only
by an explicit `-gt 0` guard) and an 8-bead verification loop blanked with no error surfaced.

The rule is stated for *any* short name, not for `tr`, because a machine-global alias shadows the
utility **everywhere**; a per-site warning can never cover the next one. `type` is the check.

**Scope: `.md` snippets only. `.sh` files are NOT in scope and must not be "fixed."** The hazard
is specific to a snippet an agent **copies into its own interactive-profile shell** — the
markdown case. A script under a `#!/usr/bin/env bash` shebang runs as a non-interactive
subprocess that never loads the user's zsh aliases, so bare `tr` inside `skills/**/*.sh` is
harmless. Sweeps have conflated these two risk classes three times; they are different, and
re-churning the shell scripts is wasted diff. The sweep that matters:

```bash
grep -rn "| *tr " --include='*.md' skills/ \
  | grep -v "command tr" | grep -v "/usr/bin/tr" \
  | grep -v "shell-guardrails.md"   # this file quotes the broken form on purpose, above
```

Expected output: nothing. A hit is a prescribed snippet an agent will copy verbatim.

**The alias itself is the human's own shell — propose a rename, never edit their profile.**

### Empty is not clean — check the exit status of every structured-input parse

**The rule: a gate that reports clean because it read nothing is worse than no gate. Empty or
unparseable structured input is a HARD FAILURE, never a pass.** Whenever a check's verdict is
computed from parsed input — `jq`, `yq`, `--json` output, a CSV, a snapshot file — capture the
parser's exit status and abort on non-zero, and treat an empty result set as failure whenever the
input list it was derived from is non-empty.

The dangerous shape is the pipeline, because it discards the producer's status silently:

```bash
jq -r '<select>' snapshot.json | while IFS= read -r id; do …; done   # parse error -> zero
                                                                    # iterations -> "clean"
```

The fixed shape captures first, checks, then loops — and proves the input was readable at all
before trusting an empty answer:

```bash
IDS=$(jq -r '<select>' snapshot.json); jq_exit=$?
[ "$jq_exit" -eq 0 ] || { printf 'FATAL: parse failed (jq exit=%s) — aborting.\n' "$jq_exit" >&2; exit 2; }
printf '%s\n' "$IDS" | while IFS= read -r id; do [ -n "$id" ] || continue; …; done
```

Two independent guards, because they catch different failures: **the status check** catches a
malformed payload; **a non-empty-input canary** (e.g. `jq '.issues | length'` must be > 0 when
the target list is non-empty) catches a well-formed but wrong/stale/foreign file. A loop that
skips every item is the same failure as a loop that ran zero times — count what resolved and
abort when a non-empty input resolved nothing.

`set -o pipefail` helps inside a script but does not save a pipeline whose consumer legitimately
exits 0 on empty input; capture-then-check is the shape that always works. Live instance:
`ac-bead-refine/references/workflow.md` § Phase 5 (parity gate + `refined` stamp loop), where
both call sites failed silent and open — a decision bead missing `human-gate` could reach
`refined` without a single bead being checked. Bite-proof:
`ac-pipeline/scripts/bead-refine-concurrent-dir.test.sh` Case 9.

## The rule of thumb

Reach for a **tool call** (Write / Edit / Read) before a shell construct whenever the target
path or the payload is dynamic. The shell is for *running* things; file production and file
mutation belong to the tools. Most of the 26+ blocks were a shell command doing a tool's job.
