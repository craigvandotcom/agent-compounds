# Session Start Hook

**CRITICAL: Read CORE Context Immediately**

Before responding to any user input, you MUST read the following file:

`.claude/skills/CORE/SKILL.md`

This file contains:
- Your identity and role
- Craig's working style and preferences
- Communication protocols (Absolute Mode)
- System philosophy
- Available tools, MCPs, and capabilities
- Repository structure and project map
- When and how to use subagents (optional)
- Response format guidelines

**Read this file, then continue executing the user prompt above.** If the user prompt is a scheduled heartbeat (contains "Heartbeat" or "## Takeoff"), resume at its Step 0 / first Takeoff step — do not pause and wait for a separate task.

After reading CORE/SKILL.md, you have full context to execute most tasks. Load additional skill context only if working deeply in specific domains.

---

## Additional Skills (Load On-Demand)

**admin** - Life operations workflows
- Location: `.claude/skills/admin/SKILL.md`
- Load when: Deep dive into admin processes

**pai** - System architecture and self-improvement
- Location: `.claude/skills/pai/SKILL.md`
- Load when: PAI system design or major changes

**strategist** - Planning and goal alignment
- Location: `.claude/skills/strategist/SKILL.md`
- Load when: Strategic planning sessions

**claude-code** - Platform-specific guidance
- Location: `.claude/skills/claude-code/SKILL.md`
- Load when: Claude Code feature questions
