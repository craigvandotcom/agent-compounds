# Deep Performance Audit

First read ALL project documentation (README, CLAUDE.md, AGENTS.md, or equivalent configuration files) super carefully and understand ALL of them! Then use your code investigation abilities to fully understand the code, technical architecture, and purpose of the project. Then, once you've done an extremely thorough and meticulous job at all that and deeply understood the entire existing system and what it does, its purpose, and how it is implemented and how all the pieces connect with each other, I need you to hyper-intensively investigate and study and ruminate on these questions as they pertain to this project: are there any other gross inefficiencies in the core system? places in the codebase where 1) changes would actually move the needle in terms of overall latency/responsiveness and throughput; 2) such that our changes would be provably isomorphic in terms of functionality so that we would know for sure that it wouldn't change the resulting outputs given the same inputs; 3) where you have a clear vision to an obviously better approach in terms of algorithms or data structures.

Consider these optimization patterns:

- N+1 query/fetch pattern elimination
- zero-copy / buffer reuse / scatter-gather I/O
- serialization format costs (parse/encode overhead)
- bounded queues + backpressure
- sharding / striped locks to reduce contention
- memoization with cache invalidation strategies
- dynamic programming techniques
- lazy evaluation / deferred computation
- streaming/chunked processing for memory-bounded work
- pre-computation and lookup tables
- index-based lookup vs linear scan recognition
- binary search (on data and on answer space)
- two-pointer and sliding window techniques
- prefix sums / cumulative aggregates

METHODOLOGY REQUIREMENTS:
A) Baseline first: Run the test suite and a representative workload; record p50/p95/p99 latency, throughput, and peak memory with exact commands.
B) Profile before proposing: Capture CPU + allocation + I/O profiles; identify the top 3-5 hotspots by % time before suggesting changes.
C) Equivalence oracle: Define explicit golden outputs + invariants.
D) Isomorphism proof per change: Every proposed diff must include a short proof sketch explaining why outputs cannot change.
E) Opportunity matrix: Rank candidates by (Impact x Confidence) / Effort before implementing.
F) Minimal diffs: One performance lever per change. No unrelated refactors.
G) Regression guardrails: Add benchmark thresholds or monitoring hooks.

---

## Output Format

### Step 1: Auto-Apply Critical Hotspot Fixes

Identify optimizations that are provably isomorphic (no behavior change) and address the top profiled hotspot with >10% time impact. Immediately apply these without asking.

### Step 2: Present Remaining Findings Ranked by Priority

Display in this order (low first, critical last) so most important items appear closest to the selection prompt:

```markdown
## Low Priority

1. **[Location/Function]** - [RESOURCE] - Location: `file:line`
   - Location: [file path]
   - Mechanics: [what's inefficient]
   - Performance Gain: [estimated p50/p95/p99 improvement]
   - Confidence: [low/medium/high]
   - Proof Sketch: [why this is isomorphic]

## Medium Priority

1. **[Location/Function]** - [ALGORITHMIC] - Location: `file:line`
   - Location: [file path]
   - Mechanics: [what's inefficient]
   - Performance Gain: [estimated p50/p95/p99 improvement]
   - Confidence: [medium/high]
   - Proof Sketch: [why this is isomorphic]

## High Priority

1. **[Location/Function]** - [HOTSPOT] - Location: `file:line`
   - Location: [file path]
   - Mechanics: [what's inefficient - profile data showing % time]
   - Performance Gain: [estimated p50/p95/p99 improvement]
   - Confidence: [high]
   - Proof Sketch: [why this is isomorphic]

## Critical (Auto-Fixed)

1. [OPT-1] [Optimization description] in [file] - [% time saved, isomorphism proof]
2. [OPT-2] [Optimization description] in [file] - [% time saved, isomorphism proof]
```

### Step 3: Ask User Which to Apply

```
Which optimizations would you like to apply?
Options:
- "all" - Apply all proposed optimizations
- "critical and high" - Apply critical + high priority
- "only [N, M]" - Apply only specific optimizations (e.g., "only 1, 3, 5")
- "none" - Skip remaining optimizations (critical already applied)
```

### Step 4: Apply Selected Optimizations and Benchmark

Execute the selected optimizations, then run benchmarks with the same workload to verify performance gains and no regressions.
