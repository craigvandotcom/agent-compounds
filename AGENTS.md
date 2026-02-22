# AGENTS.md — Subagent Context Template

> **This is a template.** Copy it into your project root and fill in each section.
> Subagents spawned by flywheel commands read this file for project context.
> Delete this instructions block after filling in.

## Project Overview

| Field     | Value                          |
| --------- | ------------------------------ |
| **Name**  | <!-- e.g. my-saas-app -->      |
| **Stack** | <!-- e.g. Python/FastAPI/Postgres, TypeScript/Next.js/Supabase --> |
| **Type**  | <!-- e.g. web app, CLI tool, library, mobile app --> |
| **Purpose** | <!-- one sentence --> |

## Project Commands

> Map each operation to the actual command in this project.
> Leave blank if not applicable. Commands are referenced by flywheel workflows.

| Operation      | Command                        |
| -------------- | ------------------------------ |
| **Dev server** | <!-- e.g. pnpm dev, cargo run, python manage.py runserver --> |
| **Test**       | <!-- e.g. pnpm test, pytest, cargo test --> |
| **Lint**       | <!-- e.g. pnpm lint, ruff check ., cargo clippy --> |
| **Type-check** | <!-- e.g. pnpm type-check, mypy ., N/A --> |
| **Format**     | <!-- e.g. pnpm format, ruff format ., cargo fmt --> |
| **Build**      | <!-- e.g. pnpm build, cargo build --release --> |
| **Quality gate** | <!-- full pipeline, e.g. pnpm format && pnpm lint && pnpm type-check && pnpm test --> |

## Architecture

> Show the source layout so agents know where to find things.

```
project-root/
├── src/           # <!-- describe -->
├── tests/         # <!-- describe -->
├── ...
```

## Available Skills (optional)

> If the project has `.claude/skills/`, list them here so agents know what domain context is available.

| Skill | Path | Load when |
| ----- | ---- | --------- |
| <!-- e.g. supabase --> | <!-- .claude/skills/supabase/SKILL.md --> | <!-- DB/schema/migration work --> |

## Rules

> Project-specific constraints agents must follow.

- <!-- e.g. TypeScript strict — no `any` types -->
- <!-- e.g. All new code must have tests -->
- <!-- e.g. Never force push -->
- <!-- e.g. Follow existing patterns in neighboring files -->
