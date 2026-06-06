# Workflow Cadence: Waves vs Continuous

## The Answer

**Jeffrey's flywheel is WAVE-OPTIMIZED, not continuous.**

The system is designed for discrete project waves:

- Big planning phase (80-85% of time)
- Bulk bead creation (171-347 beads at once)
- Swarm execution (15-20% of time)
- Ship and move to next project

## Wave Pattern (What Jeffrey Does)

```
WAVE 1: FrankenTUI
├─ Plan (3+ hours) → 171 beads
├─ Spawn swarm (5-10 agents)
├─ Execute (1-2 days)
└─ Complete

WAVE 2: CASS Memory
├─ Plan (3+ hours) → 347 beads
├─ Spawn swarm
├─ Execute
└─ Complete

WAVE 3-10: Other projects...
```

Jeffrey juggles "10 projects at the same time" - meaning 10 different project waves, NOT continuous processing of one backlog.

## Continuous Pattern (What We Asked About)

```
BACKLOG (always growing)
├─ Add bead: "Fix bug X"
├─ Add bead: "Add feature Y"
├─ Add bead: "Refactor Z"
└─ STANDING ARMY (3-5 agents)
    └─ Continuously: pick bead → implement → done → repeat
```

**The system does NOT natively support this pattern.**

## Why It's Wave-Based

1. **Beads are created in bulk** after heavy planning, not incrementally
2. **Agents are spawned per project** via NTM, not running as persistent daemons
3. **Context is project-specific** - AGENTS.md, beads, worktrees all per-project
4. **Token budgets are subscription-based** (Claude Max, ChatGPT Pro) - optimized for burst usage

## Could We Adapt It for Continuous Work?

To enable continuous processing, we'd need:

1. Persistent agent pool (not per-project spawn)
2. Cross-project bead queue (unified backlog)
3. Lightweight per-bead planning (add incrementally, not bulk)
4. Context rotation (agents switch between projects)
5. Different cost model (metered usage, not burst subscriptions)

## Our Hybrid Approach

**Wave mode for features:**

- Plan feature deeply → create beads → swarm execute → ship

**Continuous mode for maintenance:**

- Use Claude Code Tasks (built-in task queue)
- Add beads incrementally as work arrives
- Skip heavy upfront planning for small items
- Teammates for parallel work on simple tasks

## Recommendation

Start with wave-based projects (Jeffrey's model). As we get comfortable:

- Use waves for complex features (>1 day)
- Use continuous/incremental for bug fixes, small features
- The beads system works for both - it's the planning approach that differs
