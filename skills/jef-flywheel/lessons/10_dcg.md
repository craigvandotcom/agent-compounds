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

Two recurring false-positive modes (decision `ac-umq`, 2026-07-17). Use these workarounds
instead of rediscovering them or reaching for `allow-once`:

1. **Prose that merely quotes a destructive command** — comment bodies, heredocs, friction
   notes that *mention* `rm -rf` etc. get pattern-matched as if they were invocations.
   Workaround: keep the text out of the bash command line — write the body to a file first,
   then pass it by path (e.g. `br comments add <id> -f <file>`).
2. **Recursive delete of your own session scratch dirs** (`/tmp` probe/work dirs you created
   this session). Workaround: delete files by explicit path then remove the empty dir — or
   avoid the delete entirely by cloning to a fresh timestamped dir instead of
   delete-and-recreate.

The allowlist (`dcg allow <rule-id>`) is rule-granular, not path-granular — allowlisting the
recursive-delete rule to fix mode 2 would disable it everywhere. Don't. Path-scoped
exemptions and invocation-vs-prose matching are filed as upstream dcg asks.

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
