# Skill Builder Changelog

## 2026-01-23 - Major Update (v2.0)

Based on research from:
- Anthropic's official skills repository
- obra/superpowers (RED-GREEN-REFACTOR methodology)
- Claude Code plugin-dev patterns

### Breaking Changes

- **Size Constraints Updated:** Changed from 150-250 lines to 200-400 lines (aligns with Anthropic's 1,500-2,000 word average)

### New Features

#### 1. Description Guidance Strengthened

**Added critical principle:**
- Descriptions must focus on WHEN (triggering conditions), NOT HOW (workflow summary)
- Agents follow summaries instead of reading full content when descriptions summarize workflows
- Added bad/good examples showing this distinction

**Location:** `SKILL.md` - "Description is Critical" section

#### 2. Skill Testing Protocol Added

**New section in SKILL.md:**
- RED-GREEN-REFACTOR methodology for skills
- Natural language trigger testing
- Common rationalization loopholes table
- Verification gate protocol

**Why:** "If you didn't watch an agent fail without the skill, you don't know if the skill teaches the right thing." - obra/superpowers

#### 3. Verification Gate Added

**Four-step mandatory gate:**
1. Demonstrate Failure (document baseline without skill)
2. Demonstrate Success (show skill makes difference)
3. Test Edge Cases (variations, exclusions, loopholes)
4. Evidence Review (before/after comparison)

**No rationalizations accepted:**
- "Testing would be redundant"
- "The skill is too simple to test"
- "I'll verify it works in production"
- "Manual testing is sufficient"

#### 4. Writing Style Guide Added

**New section covering:**
- Voice and tone (imperative for instructions, third-person for descriptions)
- Trigger phrase specificity (concrete nouns/verbs users say, not abstract purposes)
- Active voice for explanations

**Examples:**
- ❌ Vague: "Helps with task management"
- ✅ Specific: "Use when user mentions tasks, todos, deadlines, reminders, calendar events, scheduling, or daily planning"

#### 5. Scripts Directory Created

**`scripts/init-skill.sh`:**
- Initialize new skill from template
- Auto-generates YAML frontmatter with name and description
- Creates directory structure (workflows/, reference/)
- Generates README.md with next steps checklist
- Validates name format and description length
- Cross-platform compatible (macOS, Linux, Windows via Git Bash)

**`scripts/validate-skill.sh`:**
- Validates YAML frontmatter format
- Checks name conventions (lowercase-hyphen, max 64 chars)
- Validates description (max 1024 chars, trigger phrases present)
- Detects workflow summary anti-pattern
- Checks size constraints (warns >400 lines, fails >500)
- Validates recommended sections present
- Color-coded output with emojis
- Exit code 0 (pass) or 1 (fail)

**`scripts/README.md`:**
- Complete documentation for both scripts
- Usage examples and troubleshooting
- Workflow integration patterns
- Pre-commit hook example

#### 6. Testing Patterns Reference Added

**New file:** `reference/testing-patterns.md`

**Contents:**
- The Iron Law ("watch agent fail without skill")
- RED-GREEN-REFACTOR detailed workflow
- Natural language trigger testing format
- Verification gate protocol with examples
- Common rationalization loopholes table
- Testing workflow summary diagram
- When to load this reference

### Enhanced Sections

#### Quick Checklist Updated

**Added items:**
- Description focuses on WHEN not HOW
- Tested: natural prompts trigger skill without explicit mentions
- Verification gate passed (fail → success → edge cases)
- Writing style: imperative instructions, third-person descriptions

#### Workflows Updated

**`workflows/create-skill.md`:**
- Phase 4 (Testing) expanded with verification gate
- Added baseline failure documentation
- Added natural language trigger testing
- Added rationalization loophole detection
- Updated output checklist with new requirements

#### References Updated

**`reference/best-practices.md`:**
- Added CRITICAL PRINCIPLE about WHEN vs HOW
- Added workflow summary anti-pattern example
- Updated size constraints (200-400 lines)
- Strengthened CSO (Claude Search Optimization) guidance

### Documentation Improvements

- Added scripts reference table to SKILL.md
- Added testing-patterns.md to reference documentation table
- Created comprehensive scripts/README.md
- All examples now show both anti-patterns and correct patterns
- Emphasized verification gate as non-negotiable

### Quality Improvements

- All scripts are executable (`chmod +x`)
- Scripts include comprehensive error handling
- Validation provides actionable feedback
- Color-coded output for better UX
- Cross-platform compatibility tested

### Files Added

```
.claude/skills/skill-builder/
├── scripts/
│   ├── init-skill.sh           # NEW
│   ├── validate-skill.sh       # NEW
│   └── README.md               # NEW
├── reference/
│   ├── testing-patterns.md     # NEW
│   └── best-practices.md       # UPDATED
├── workflows/
│   └── create-skill.md         # UPDATED
├── SKILL.md                    # UPDATED
└── CHANGELOG.md                # NEW
```

### Files Modified

- `SKILL.md` - 189 lines → 353 lines (still within 200-400 target)
- `workflows/create-skill.md` - Enhanced testing phase
- `reference/best-practices.md` - Strengthened description guidance

### Validation Status

```bash
./scripts/validate-skill.sh .
```

**Result:** ✅ VALIDATION PASSED (353/500 lines)

All new content follows progressive disclosure principles:
- Core guidance in SKILL.md
- Deep methodology in reference/testing-patterns.md
- Automation in scripts/
- Workflows for procedures

### Migration Notes

**For existing skills:**

1. Review descriptions - do they focus on WHEN or HOW?
2. Update workflow summaries to triggering conditions
3. Run `./scripts/validate-skill.sh` on each skill
4. Test natural language activation (no explicit skill mentions)
5. Document verification (RED-GREEN-REFACTOR)

**Backward compatible:**
- Size guidelines expanded (not restricted)
- New sections are additions (not replacements)
- Existing skills continue to work
- Scripts provide validation, not enforcement

### Roadmap

**Future enhancements:**
- Automated trigger phrase extraction
- Example skill library with test cases
- Integration test framework (headless sessions)
- Skill performance profiling
- Template variants for different skill types

### Sources

Research documentation:
- internal Anthropic-skills analysis notes
- `knowledge/3-references/research/obra-superpowers-deep-dive.md`
- `knowledge/3-references/research/obra-superpowers-quick-reference.md`

Anthropic's average skill size: ~2,200 words
- Recommended: 1,500-2,000 words
- Our target: 200-400 lines (balanced approach)

---

**Version:** 2.0
**Date:** 2026-01-23
**Author:** architect subagent
**Status:** Complete
