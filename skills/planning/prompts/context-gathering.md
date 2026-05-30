# Context Gathering (Before Each Round)

Spawn 3 parallel code-explorer agents to gather codebase context before running a refinement round.

---

## Explorer 1: Referenced Files

````markdown
Task(
subagent_type: "code-explorer",
model: "haiku",
prompt: "# Fetch Referenced Files

Read and summarize the following files mentioned in the plan:

**Files to read:**
{{REFERENCED_FILES}}

**For each file, provide:**

1. File path
2. Current implementation summary (2-3 sentences)
3. Key exports/interfaces
4. Dependencies it imports
5. Any patterns or conventions used

**Output format:**

```markdown
## [file-path]

**Summary:** [what this file does]
**Exports:** [key exports]
**Patterns:** [relevant patterns]
**Code snippet (key section):**
\`\`\`typescript
[relevant code]
\`\`\`
```
````

"
)

````

---

## Explorer 2: Existing Patterns

```markdown
Task(
  subagent_type: "code-explorer",
  model: "haiku",
  prompt: "# Find Existing Patterns

Search the codebase for patterns relevant to this plan:

**Patterns to find:**
{{REFERENCED_PATTERNS}}

**Search for:**

1. Similar implementations that already exist
2. Shared utilities or hooks that could be reused
3. Established conventions for this type of feature
4. Test patterns used for similar functionality

**For each pattern found:**

- Where it's used
- How it's implemented
- Whether the plan aligns with or diverges from it

**Output format:**

```markdown
## Pattern: [name]

**Found in:** [file paths]
**Implementation approach:** [summary]
**Plan alignment:** [aligns | diverges | new pattern]
**Relevant code:**
\`\`\`typescript
[example]
\`\`\`
````

"
)

````

---

## Explorer 3: Impact Analysis

```markdown
Task(
  subagent_type: "code-explorer",
  model: "haiku",
  prompt: "# Analyze Impact Scope

Analyze what the plan's changes will affect:

**Directories to analyze:**
{{KEY_DIRECTORIES}}

**Find:**

1. Files that import from files the plan will modify
2. Tests that cover the affected code
3. Components that depend on affected components
4. API routes that use affected utilities

**Output format:**

```markdown
## Impact Analysis

### Files that will be modified
[list from plan]

### Files that depend on modified files
[list with import relationships]

### Existing test coverage
[list test files and what they cover]

### Potential ripple effects
[components/routes that might need updates]
````

"
)

````

---

## Variables to Extract from Plan

Before running explorers, parse the plan:

```markdown
REFERENCED_FILES: [list of file paths mentioned]
REFERENCED_PATTERNS: [component names, hooks, utilities mentioned]
KEY_DIRECTORIES: [directories the plan will modify]
````

---

## Synthesize Context

After all 3 explorers complete, combine into CODEBASE_CONTEXT:

```markdown
## Codebase Context for Round [N]

### Referenced Files Status

[Synthesized from Explorer 1]

### Existing Patterns

[Synthesized from Explorer 2]

### Impact Scope

[Synthesized from Explorer 3]

### Key Findings

- [Finding 1: e.g., "Plan references UserService but it was renamed to AuthService"]
- [Finding 2: e.g., "Similar feature exists in /features/foods - could reuse pattern"]
- [Finding 3: e.g., "3 test files cover affected code, will need updates"]
```

---

## When to Re-gather

- **Round 1:** Always full context gathering
- **Round 2+:** Re-gather if plan changed significantly, otherwise reuse
- **Focused rounds:** Only gather context for specific areas being refined
