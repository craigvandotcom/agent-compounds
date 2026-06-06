# The Art of Agent Direction

**Source:** github.com/Dicklesworthstone/agentic_coding_flywheel_setup

---

> **Goal:** Master the art of directing AI agents with precision and intention.

          The difference between a mediocre agent session and a brilliant one
          often comes down to **how you direct the agent**.
          This lesson dissects the patterns that make prompts effective, drawn
          from real-world workflows that consistently produce excellent results.

          AI models allocate "compute" based on perceived task
          importance. **Stacked modifiers** signal that this
          task deserves maximum attention:

```

> ****
            These aren't filler words. They're{" "}
            **calibration signals** that tell the model to allocate
            more reasoning depth to the task.

> ****
            **Claude Code feature:** The word{" "}
            **ultrathink** is a specific Claude Code directive that
            tells the system to allocate significantly more thinking tokens. While
            it's a tool-level feature in Claude Code, using intensity words like
            "think deeply" or "reason carefully" can help other
            agents/models allocate more attention to complex tasks as well.

          Models tend to take shortcuts. Explicit scope directives push against
          premature narrowing:

```

          Questions trigger **metacognition**—forcing the
          model to evaluate its own output before finalizing:

```

> ****
            **Plan Space Principle:** Revising plans is 10x cheaper
            than debugging implementations. Force verification at the planning
            stage.

          **Psychological reset techniques** help agents
          approach code without prior assumptions or confirmation bias:

```

          Great prompts consider **future contexts**—the
          agent that will continue this work, the human who will review it, the
          "future self" who needs to understand it:

```

          **Stable reference documents** (like AGENTS.md)
          serve as behavioral anchors. Re-reading them is especially critical
          after context compaction.

```

> ---

            **Why this matters after compaction:**

            1. **Context decay:** Rules lose salience as more
            content is added

            2. **Summarization loss:** Compaction may miss nuances

            3. **Drift prevention:** Periodic grounding prevents
            behavioral divergence

            4. **Fresh frame:** Re-reading establishes correct
            operating context

```

          Push for **deep understanding** over surface-level
          pattern matching:

```

          Here's a real prompt that combines multiple patterns:

```

// =============================================================================
// INTENSITY EXAMPLE
// =============================================================================
function IntensityExample({
  phrase,
  effect,
}: {
  phrase: string;
  effect: string;
}) {

      `"{phrase}"`
      →
      {effect}

// =============================================================================
// SCOPE CARD
// =============================================================================
function ScopeCard({
  direction,
  phrases,
}: {
  direction: "expand" | "deepen";
  phrases: string[];
}) {
  const isExpand = direction === "expand";

#### {isExpand ? "↔ Breadth" : "↓ Depth"}

        {phrases.map((phrase) => (
          - "{phrase}"

        ))}

// =============================================================================
// VERIFICATION QUESTION
// =============================================================================
function VerificationQuestion({
  question,
  purpose,
}: {
  question: string;
  purpose: string;
}) {

        ?

"{question}"

→ {purpose}

// =============================================================================
// FRESH EYES CARD
// =============================================================================
function FreshEyesCard({
  technique,
  example,
  mechanism,
}: {
  technique: string;
  example: string;
  mechanism: string;
}) {

#### {technique}

      `{example}`

↳ {mechanism}

// =============================================================================
// TEMPORAL CONCEPT
// =============================================================================
function TemporalConcept({
  concept,
  description,
}: {
  concept: string;
  description: string;
}) {

      {concept}
      —
      {description}

// =============================================================================
// PRINCIPLE CARD
// =============================================================================
function PrincipleCard({
  principle,
  description,
}: {
  principle: string;
  description: string;
}) {

      {principle}
      —
      {description}

// =============================================================================
// PATTERN BREAKDOWN
// =============================================================================
function PatternBreakdown() {
  const patterns = [
    { name: "Anchoring", line: "Reread AGENTS.md..." },
    { name: "Intensity", line: "Use ultrathink" },
    { name: "Fresh Eyes", line: "randomly explore" },
    { name: "Scope (depth)", line: "deeply investigate and understand" },
    { name: "First Principles", line: "trace their functionality" },
    { name: "Context First", line: "Once you understand...larger context" },
    { name: "Intensity (stacked)", line: "super careful, methodical, and critical" },
    { name: "Fresh Eyes", line: 'with "fresh eyes"' },
    { name: "Scope (breadth)", line: "any obvious bugs, problems, errors, issues..." },
    { name: "Intensity (triple)", line: "systematically and meticulously and intelligently" },
    { name: "Anchoring", line: "comply with ALL rules" },
  ];

  #### Pattern Analysis

        {patterns.map((p, i) => (

            {p.name}
            ←
            `"{p.line}"`

        ))}

// =============================================================================
// QUICK REF ITEM
// =============================================================================
function QuickRefItem({
  pattern,
  when,
  key_phrases,
}: {
  pattern: string;
  when: string;
  key_phrases: string;
}) {

        Pattern

{pattern}

        When

{when}

        Key Phrases

{key_phrases}


```
