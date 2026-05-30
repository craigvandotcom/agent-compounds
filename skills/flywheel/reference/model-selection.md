# Model Selection and Roles

## Core Principle: Plan with Opus, Execute with Sonnet

- **Opus 4.5** for complex planning, architecture, agent coordination
- **Sonnet 4.5** for high-volume implementation (more usage per dollar)
- Sonnet is "eager to jump in" but makes sloppy mistakes -- mitigate with review loops
- Codex with high reasoning effort is slower but fewer mistakes

## Gemini for Review Duty

- Assign Gemini primarily to code review, not core implementation
- Different model = different perspective = catches blind spots

## Cross-Pollination Hack

```
I just asked another agent (Claude Code Opus 4.5) to do the following:
[paste instructions]. Now you do the same thing.
```

Gets multi-model diversity without re-writing prompts from scratch.

## Model Assignment Summary

| Role                    | Recommended Model   | Reasoning                                         |
| ----------------------- | ------------------- | ------------------------------------------------- |
| Planning / Architecture | Opus 4.5 or GPT Pro | Deep reasoning, fewer iterations needed           |
| Implementation (bulk)   | Sonnet 4.5          | More tokens per dollar, review loops catch errors |
| Code Review             | Gemini              | Different perspective, catches blind spots        |
| Plan Refinement         | GPT Pro + Claude    | Cross-model blending produces better plans        |
| Swarm Coordination      | Claude Code         | Best agent mail + bv integration                  |
