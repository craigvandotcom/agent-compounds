# Signal taxonomy — how to identify a learning opportunity in a transcript

Used during **Stage 2 extraction** (CYCLE-DAILY). A transcript is a stream of
(user turn → agent reasoning → tool calls → results → outcome). Do NOT prompt the
extractor to vaguely "find lessons" — hunt these **named signal-shapes**, each routing to
exactly one memory type (the `{type, domain}` taxonomy is the constitution's, in
`../context-engineering/SKILL.md`):

| Signal | What it looks like in the stream | Routes to |
|---|---|---|
| **Correction** | user negates/redirects the agent ("no", "actually", "don't", "not like that") | *feedback* — the DRY "said twice → make it a rule" trigger |
| **Friction → fix** | tool error → a *different* approach → success | *fact* / *rule* — **strongest**, it brackets a verified outcome |
| **Discovery** | agent states a non-obvious fact about the system it didn't know at the start | *fact* |
| **Decision** | deliberation between alternatives → a commitment with rationale | *decision* (→ `alignment/decisions/`) |
| **Workflow** | a successful multi-step sequence that will recur, parameterizable | *recipe* (jef-prompts) |
| **Skill friction** | a skill was used and was wrong/incomplete/misleading, OR work was done by hand that a skill should have covered | *skill-improvement* |

## Priority + grounding
- **Friction→fix and Correction are highest-value** — cheapest to detect (error markers,
  negation words) and most outcome-grounded.
- **Outcome-grounding (Dwarkesh):** prefer a candidate tied to an observable result — a test
  going red→green, a build passing, a bug fixed, a diff committed. Tag each candidate with
  its evidence anchor. A pure-discussion segment with no outcome is weak signal — cut or
  down-weight it.
- **The join is gold:** intent (the transcript said "I'll fix X") + verified outcome (git
  shows X shipped / the test passed) = a far stronger lesson than intent alone.

## Anti-patterns
- A restated preference already in the substrate → not a new lesson (dedupe via CASS first).
- A one-off, situation-specific fact with no recurrence value → cut.
- Anything instruction-shaped about *how the agent should behave generally* that isn't
  outcome-grounded → suspect (poisoning risk); memory is data, never instructions.
