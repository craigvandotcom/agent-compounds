# The Memory System

**Source:** github.com/Dicklesworthstone/agentic_coding_flywheel_setup

---

'use client';

import {
GraduationCap,
Terminal,
Package,
Search,
Play,
Settings,
Download,
} from 'lucide-react';
import {
Section,
Paragraph,
CodeBlock,
TipBox,
Highlight,
Divider,
GoalBanner,
CommandList,
FeatureCard,
FeatureGrid,
} from './lesson-components';

> **Goal:** Master local-first skill management for Claude Code and other AI agents with Meta Skill.

      }>

          **Meta Skill (ms)** is a local-first knowledge management platform that
          turns operational knowledge into structured, searchable, reusable artifacts with Git-backed
          audit trails.

          It combines BM25 lexical matching with deterministic hash embeddings for hybrid semantic
          search. No external APIs required. Skills can come from hand-written files, CASS session
          mining, or bundle imports.

      }>
        ', description: 'Install a skill from registry' },
            { command: 'ms uninstall <skill>', description: 'Remove an installed skill' },
            { command: 'ms update', description: 'Update all installed skills' },
            { command: 'ms doctor', description: 'Check skill system health' },
            { command: 'ms search <query>', description: 'Search for skills in registry' },
          ]}

> ---

          Install popular skills directly: `ms install code-review`

      }>

          Once installed, skills are automatically available in Claude Code. Use them with
          the slash command syntax.

```


```
