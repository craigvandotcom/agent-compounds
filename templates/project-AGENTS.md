# <Project Name> — Agent Entry Point
#
# TEMPLATE — fill every <placeholder> before committing.
# Copy to your project root as AGENTS.md and delete this header block.
#
# Usage: cp templates/project-AGENTS.md ../my-project/AGENTS.md

## Project Overview

| Field | Value |
|---|---|
| **Name** | `<project-name>` |
| **Stack** | `<e.g. Next.js + TypeScript + Tailwind + Supabase + Capacitor>` |
| **Type** | `<e.g. Web app / Native app / CLI tool / Content repo>` |
| **Purpose** | `<One sentence: what does this project do and who is it for?>` |

## Project Commands

| Operation | Command |
|---|---|
| **Dev server** | `<e.g. pnpm dev>` |
| **Test** | `<e.g. pnpm test>` |
| **Lint** | `<e.g. pnpm lint>` |
| **Type-check** | `<e.g. pnpm type-check>` |
| **Build** | `<e.g. pnpm build>` |

## Architecture

```
<project-name>/
├── <src-dir>/      # <describe main source>
├── <feature-dir>/  # <describe feature structure>
└── <config-files>  # <describe key config>
```

> Key conventions: `<e.g. feature-based dirs under features/<name>/, colocated tests>`

## Rules

- **Durable knowledge routes via context-engineering** — decisions go to
  `../alignment/decisions/`, facts/rules to `memory/auto/`; session-end capture: `reflect`.
- `<Add project-specific rules here — e.g. "never commit .env.local">`.
- `<Add further rules as the project grows>`.
