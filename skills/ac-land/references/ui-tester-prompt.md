# UI Tester Prompt (Phase 1c)

Spawn one `browser-tester` per matched journey (all in one message, parallel). Substitute the resolved `<ARTIFACTS_DIR>` from Phase 0.

````
Task(subagent_type: "browser-tester", prompt: """
You are a browser tester. Your job: run a UI journey happy path and report results. You test and report — never edit code.

## Your Task
Run the <journey-name> journey happy path. This is session closure smoke testing.

### Setup
1. Dev server is already running
2. Open the journey's starting URL using the project's browser testing tool

### Test

Run Happy Path steps from the journey definition. Focus on:

- Elements render correctly
- Interactions work (clicks, form fills, navigation)
- No console errors
- Correct data flow (saves, displays, updates)

### Output

Write report to <ARTIFACTS_DIR>/ui-suite-<journey-name>.md
Include screenshots for any failures.
Happy path only — skip edge cases.
""")
````
