# Skill Template

Copy this as the starting `SKILL.md` for a new skill. Delete the sections you don't need; keep it lean (see `structure-standard.md`).

```markdown
---
name: my-skill                # lowercase, hyphens, ≤64 chars, no reserved words (claude/anthropic)
description: Use when <triggering conditions> — <symptoms/nouns/verbs the user actually says>. <One clause on what it does>. Triggers on "<phrase>", "<phrase>". Max 1024 chars, third person, WHEN over HOW.
# Optional:
# disable-model-invocation: true   # manual /my-skill only (task skill); omit for auto-invoked reference skills
# allowed-tools: Read, Bash        # restrict tools if needed
# argument-hint: "[what to pass]"  # shown in the slash-command UI
---

# My Skill

One-sentence purpose.

## When to Use
- <scenario>
**When NOT to use:** <exclusion> → <where to go instead>

## Core Workflow
<the spine: phases, decision points, routing. Keep orchestration here.>

## Supporting files (load on demand)
| File | When to read |
| --- | --- |
| `references/<x>.md` | <stage / condition> |

## Output
<the shape of the result, or a pointer to references/<template>.md>
```

## Notes
- **Task skill vs reference skill.** A task skill (a procedure the user triggers) should set `disable-model-invocation: true` so it behaves like a slash command. A reference skill (conventions Claude should auto-apply) omits that field so Claude can load it when relevant.
- **Pushy description.** Claude under-triggers by default. Write the description to over-communicate *when* to fire ("Use whenever … even if not asked by name"), not to summarize the workflow.
- See `structure-standard.md` for the spine/references split and `testing-patterns.md` for the RED-GREEN-REFACTOR gate.
</content>
