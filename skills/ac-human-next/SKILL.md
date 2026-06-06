---
name: ac-human-next
description: Human action dashboard — surface manual tasks, decisions, blockers, and reviews that need the human's attention. Triggers: 'what needs me', 'human next', 'my action items', 'what's blocked on me', 'what needs my decision'.
disable-model-invocation: true
---


**You are a human-action scanner.** Read-only. Scan all project sources for items that require human intervention — things an agent can't do. Prioritize by impact and urgency, then present a short actionable list.

Complement to `/ac-next` (which finds what agents should work on next).

---

## I/O Contract

|                  |                                                                      |
| ---------------- | -------------------------------------------------------------------- |
| **Input**        | None (reads project state directly)                                  |
| **Output**       | Prioritized list of human-required actions                           |
| **Artifacts**    | None (stateless — no writes)                                         |
| **Verification** | N/A (read-only)                                                      |

---

## Phase 0: Initialize

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
```

---

## Phase 1: Scan Sources (parallel)

Run all scans simultaneously. Each scan produces candidate items.

### A. User's Manual Backlog

```bash
find "$PROJECT_ROOT/_backlog-manual" -name "*.md" \
  -not -name "README.md" -not -path "*/_done/*" \
  2>/dev/null
```

Read each file. Extract frontmatter (`status`, `blocker`, `urgency`, `est`) and all unchecked `- [ ]` items. Group by urgency (critical-path first, then ready, then future).

### B. Blocked Pipeline Items

```bash
br list --json 2>/dev/null
```

Find beads or tasks with status `blocked` or notes mentioning "waiting on", "needs manual", "requires account", "needs the user", "human decision".

### C. Open PRs Needing Review

```bash
gh pr list --state open --json number,title,createdAt,labels 2>/dev/null
```

Any open PRs that need human review or merge approval.

### D. Recent Deployments

```bash
gh run list --limit 3 --json status,conclusion,name,createdAt 2>/dev/null
```

Failed CI runs or deployments that need human investigation.

### E. Backlog Decisions

Scan `_backlog/` for items tagged `needs-decision` or with questions in their notes. Also check `_plans/` for plans awaiting user approval.

```bash
find "$PROJECT_ROOT/_backlog" -name "*.md" -not -name "_*" -not -path "*/_done/*" -not -path "*/_shipped/*" -not -path "*/assets/*" -not -path "*/audits/*" 2>/dev/null
find "$PROJECT_ROOT/_plans" -name "*.md" -not -path "*/_done/*" 2>/dev/null
```

Look for:
- Plans with `status: needs-approval` or `status: draft`
- Backlog items with open questions or `decision:` tags
- Items referencing external services (Apple, Vercel, Supabase dashboard, etc.)

### F. Vercel / Production Status

```bash
curl -s -o /dev/null -w "%{http_code}" https://www.eat.zone 2>/dev/null
```

Quick health check — flag if production is down.

---

## Phase 2: Categorize & Prioritize

Sort items into priority tiers:

### Tier 1: Blocking (do now)
Items that block agent work or production:
- Production down
- Failed deployments
- Blocked beads waiting on human action
- PRs blocking a merge

### Tier 2: High Impact (do today)
Items with significant downstream value:
- Apple Developer enrollment steps (unblocks App Store)
- Account setup / API keys
- Plan approvals that unblock implementation waves

### Tier 3: Quick Wins (5 min or less)
Low-effort items worth batching:
- Dashboard configuration
- Review a screenshot
- Approve a plan
- Toggle a setting

### Tier 4: Backlog (do when free)
Non-urgent manual tasks:
- Documentation
- Ops runbooks
- Future planning

---

## Phase 3: Present Dashboard

Format as a concise, scannable dashboard:

```
## What Needs You Right Now

### Blocking (0 items)
Nothing blocking — agents can proceed autonomously.

### High Impact (2 items)
1. Unblock external dependency — unblocks downstream agent work
   Source: _backlog-manual/ > "Blocked on external dependency"

2. Review production deployment artifacts
   Source: _backlog-manual/ > "Review Production Artifacts"

### Quick Wins (1 item)
1. Configure third-party service alert rules (~5 min)
   Source: _backlog-manual/ > "Third-party service configuration"

### Backlog (1 item)
1. Create launch ops runbook (~15 min)
   Source: _backlog-manual/ > "Launch Ops Runbook"

---
Total: 4 items needing human attention
Pipeline status: agents can work autonomously on N beads
```

---

## Principles

1. **Human time is scarce** — only surface what genuinely needs a human
2. **Agents can't do these** — account access, real-device testing, business decisions, external service setup
3. **Impact ordering** — what unblocks the most downstream work comes first
4. **Actionable** — each item should be clear enough to act on without further research
5. **No nagging** — if nothing needs attention, say so and move on
