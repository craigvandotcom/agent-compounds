---
description: Radical performance optimization using exotic algorithms and self-healing architectures. Use when standard optimizations are insufficient or order-of-magnitude improvements needed.
---

# Code Optimizer Alien

First read ALL project documentation and code to understand the system deeply. Then think like an alien engineer encountering Earth code: question every assumption, explore unconventional approaches beyond standard best practices, and consider mathematical structures from information theory, quantum computing, and theoretical computer science.

Generate 20+ optimization ideas across these dimensions:

**Exotic Mathematical Structures:**

- Entropic optimal transport (Schrödinger bridges via Sinkhorn-Knopp)
- Large-deviations theory (Cramér rate functions for failure bounds)
- Convex optimization, dynamic programming, spectral methods
- Quantum-inspired structures (tensor networks, adiabatic annealing)
- Succinct tries, wavelet trees, holographic storage approximations

**Self-Healing Runtime Integrity:**

- Self-correcting codes (LDPC, turbo codes) for error resilience
- Chaos engineering probes with Lyapunov stability checks
- Sequential probability ratio tests (SPRT) for runtime monitoring
- Robust optimization (CVaR) for preemptive recovery
- Formal verification (temporal logics, model checking)
- Adaptive anomaly detection with automated recovery paths

**Hyper-Performance Primitives:**

- Zero-copy I/O, lock-free concurrency, cache-oblivious algorithms
- SIMD/GPU offloads, vectorized operations
- Predictive prefetching, evolutionary self-optimization loops
- Memory pool reuse, custom allocators

Rank all candidates by: (Impact × Confidence) / Effort

Winnow to the top 5, ordered best to worst. For each:

- Detailed mechanics and implementation steps
- Estimated performance gains (p50/p95/p99 if measurable)
- Confidence level (0-100%)
- Formal proof sketch of isomorphic equivalence (outputs unchanged)

---

## Output Format

### Step 1: Auto-Apply Critical Optimizations

Identify optimizations that are non-negotiable improvements (clear wins with no risk, proven algorithmic upgrades, obvious resource leaks). Immediately apply these without asking.

### Step 2: Present Remaining Optimizations Ranked by Priority

Display in this order (low first, critical last) so most important items appear closest to the selection prompt:

```markdown
## Low Priority

1. **[Title]** - [Optimization Type] - Location: `file:line`
   - Mechanics: [How it works]
   - Performance Gain: [p50/p95/p99 estimates]
   - Confidence: [0-100%]
   - Proof Sketch: [Isomorphic equivalence]
   - Implementation: [Concrete steps]

## Medium Priority

1. **[Title]** - [Optimization Type] - Location: `file:line`
   - Mechanics: [How it works]
   - Performance Gain: [p50/p95/p99 estimates]
   - Confidence: [0-100%]
   - Proof Sketch: [Isomorphic equivalence]
   - Implementation: [Concrete steps]

## High Priority

1. **[Title]** - [Optimization Type] - Location: `file:line` [Impact: X, Confidence: Y, Effort: Z]
   - Mechanics: [How it works]
   - Performance Gain: [p50/p95/p99 estimates]
   - Confidence: [0-100%]
   - Proof Sketch: [Isomorphic equivalence]
   - Implementation: [Concrete steps]

## Critical (Auto-Applied)

1. [Description of optimization applied] - Location: `file:line`
```

### Step 3: Ask User Which to Apply

```
Which optimizations would you like to apply?
Options:
- "all" - Apply all proposed optimizations
- "critical and high" - Apply critical + high priority
- "only [N, M]" - Apply only specific optimization numbers
- "none" - Skip remaining optimizations (critical already applied)
```

### Step 4: Apply Selected Optimizations and Benchmark

Execute the selected optimizations, then run benchmarks to verify performance improvements and functional equivalence.
