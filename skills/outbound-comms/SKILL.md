---
name: outbound-comms
description: Use when drafting Slack messages, notifications, session summaries, blocker reports, or emails addressed to Craig — the operator voice for reporting to him, distinct from output voice (brand/audience-facing content). Triggers on "draft a slack message", "notify Craig", "write an email to Craig", "session summary", "status update", "blocker report", "how should I report this", "operator voice".
---

> **Shared skill (agent-compounds).** Symlinked into projects via `deploy.sh` — this is
> the single source of truth; edit here, not in a consumer copy. Method-only and
> portable (no project facts).

# Outbound Comms — Operator Voice

**Purpose:** How every agent talks *to Craig* — Slack messages, emails, notifications,
session summaries, blocker reports. This is the **operator voice** (reporting to Craig),
not the **output voice** (what an agent writes for an audience — see `brand`/`writing-guidelines`
for that). Keep the two separate: a content-drafting session still reports to Craig in
this voice even while writing in a completely different voice for the piece itself.

---

## When to Use This Skill

**Intent Triggers:**
- Drafting a Slack notification or session summary for Craig
- Writing a blocker report or status update
- Drafting an email addressed to Craig
- Any "how do I report this to Craig" question
- End-of-session summaries for scheduled/heartbeat jobs

**When NOT to Use:**
- Content written for an audience (newsletter, X, blog, book) — that's brand/output
  voice, governed by the `brand` and `writing-guidelines` skills instead.

---

## Core Principle

Maximum signal, zero noise.

## Required Patterns

- Direct statements, no hedging
- Imperative verbs ("Updated X", "Blocked on Y")
- Fact-first presentation — lead with the answer, not the setup
- Front-load critical information
- Code references as `file.ts:123`
- File paths as absolute when ambiguous

## Forbidden Patterns

- "Great question!" / "I'd be happy to help"
- "Let me know if you need anything else"
- "Does this make sense?" / "Feel free to..."
- "I'll go ahead and..." / "Let me..."
- Throat-clearing openings ("In today's world...", "It's worth noting...")
- Emoji (unless Craig explicitly requests them)
- Trailing summaries of what you just did — Craig can read the diff
- Padding or filler

## Mobile-First Formatting

- Paragraphs: max 3-4 sentences
- Generous whitespace between sections
- Headers (`##`, `###`) for scannable hierarchy
- Bullets unless sequence matters

## Blocker Format

When blocked, report in this shape:

```
Blocked: [specific issue]
Need: [what unblocks you]
```

Then stop and await input. No speculation, no workarounds unless explicitly asked.

## End-of-Turn Discipline

One or two sentences max: what changed, what's next. Nothing else.
