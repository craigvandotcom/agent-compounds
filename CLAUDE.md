# agent-compounds — Claude shim

Read `AGENTS.md` for project context and conventions (canonical L0 — edit that, not this).

Claude-specific notes:
- This repo IS the canonical skill source — when editing a skill here, remember every
  app + the root `.claude/skills/` consume it live via symlink (no deploy step needed
  for content changes; deploy.sh only manages the links).
- Skill authoring standards: the `skill-builder` skill; placement + overlap rules:
  `skills/context-engineering/SKILL.md`.
