# DCG: Destructive Command Guard

**Goal:** Block dangerous commands before they execute.

---

## Why DCG Matters

AI agents sometimes propose destructive commands like hard resets or recursive deletes.
DCG stops those commands _before_ they run and suggests safer alternatives.

---

## Essential Commands

### Test a Command

```bash
dcg test "git reset --hard" --explain
```

### Register the Hook

```bash
dcg install
```

### Check Health

```bash
dcg doctor
```

---

## Protection Packs

Enable only the packs you need:

```bash
# ~/.config/dcg/config.toml
[packs]
enabled = ["git", "filesystem", "database.postgresql"]
```

---

## Allow-Once Workflow

If you _must_ run a blocked command:

```bash
dcg allow-once <code>
```

Use this sparingly and only when you understand the risk.

---

## Quick Reference

| Command                      | What it does                    |
| ---------------------------- | ------------------------------- |
| `dcg test "<cmd>"`           | Check if a command is dangerous |
| `dcg test "<cmd>" --explain` | Explain why it was blocked      |
| `dcg packs`                  | List protection packs           |
| `dcg install`                | Register Claude Code hook       |
| `dcg allow-once <code>`      | Bypass a single command         |
| `dcg doctor`                 | Health check                    |

---

## Known False-Positives — Sanctioned Workarounds

Refreshed against **dcg 0.6.7** (probe matrix re-run 2026-08-03; original modes from decision
`ac-umq`, 2026-07-17). Use these workarounds instead of rediscovering them or reaching for
`allow-once`.

1. **Prose that merely quotes a destructive command — STILL LIVE, but the reason changed.**
   Evaluated in isolation, `dcg test` now returns ALLOWED for a string that merely *mentions*
   a destructive command, so this is no longer a `dcg` verdict problem. What still bites is the
   harness **pre-execution** guard, which scans the agent's WHOLE command line: a destructive or
   redirect literal riding along inside a quoted argument is matched as if it were an
   invocation. (Observed three times in one run against `core.filesystem:rm-rf-root-home` on a
   `/tmp` path and `core.filesystem:redirect-truncate-dynamic-path`, and again on
   `core.git:restore-worktree` from a bead close-reason that merely described repairing a file.
   Stated as an inference about the pre-execution scan, not a proven internal mechanism — the
   *observable* is stable and costs turns.)
   **Workaround (unchanged):** keep the text off the bash command line — write the body to a
   file first, then pass it by path (e.g. `br comments add <id> -f <file>`, or
   `--reason "$(cat <file>)"`). **Corollary:** probing dcg's own behavior means assembling the
   literal from concatenated fragments, or running the probes from a script file, so the literal
   never appears on a command line at all.
2. **Recursively deleting a `/tmp` scratch dir you created this session — FIXED in 0.6.7.**
   Re-probed ALLOWED; that entry and its workaround are retired.
3. **`core.filesystem:redirect-truncate-dynamic-path` — new live mode.** It keys on
   **TRUNCATION**, not on path-dynamism: `>` to a variable path is blocked whether the path is
   quoted or unquoted, and so is a heredoc into a truncating redirect. Do not describe it as
   blocking "dynamic paths" generally — that framing is wrong. Verified-ALLOWED escapes:
   **append** (`>>`), **`tee <path>`** with only a literal `/dev/null` on the redirect (the path
   becomes an argument, so there is no redirect operator to match), `tee -a`, `tee` fed by a
   heredoc, and fully-**literal** `/tmp` destinations. A literal redirect target is impossible to
   write in advance whenever the path carries a runtime discriminator, which is why `tee` is the
   general escape.

The allowlist (`dcg allow <rule-id>`) is rule-granular, not path-granular — allowlisting a whole
rule to dodge one false positive disables it everywhere. Don't. Path-scoped exemptions and
invocation-vs-prose matching are filed as upstream dcg asks.

---

## Integration with Other Tools

- **SLB**: Two-person rule after DCG pre-check
- **UBS**: Quality checks before commits
- **Mail**: Coordinate on safety decisions

---

## Congratulations!

You've completed the ACFS onboarding.

You now have:

- A fully configured development VPS
- Three powerful coding agents
- A complete coordination toolstack
- The knowledge to use it all

**Go build something amazing!**

---

_Run `acfs doctor` to verify your setup, then start your first project with `cc`!_
