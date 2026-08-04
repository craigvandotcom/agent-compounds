---
name: jef-prompts
description: 'A curated library of high-leverage one-shot prompts — the Jeffrey-Emanuel jef pack plus local additions. Triggers: "/jef-prompts <hint>", "give me a prompt for", "is there a prompt for", "bug hunting prompt", "planning prompt", "performance audit prompt", "refactor prompt", "find a prompt". RETRIEVES a canned prompt — NOT for scoring or improving prompts already written (prompt-enhance) or authoring skills (skill-builder).'
---

# Prompts Library

A catalog of battle-tested prompts (the "jef" library, after Jeffrey Emanuel, plus local additions). Each entry is a full prompt living in `references/<name>.md`.

## How to use

1. The user invokes `/jef-prompts <hint>` (e.g. `/jef-prompts find a deep bug`, `/jef-prompts make the UI world-class`).
2. Match the hint against the catalog below.
3. **Load the single best-matching `references/<name>.md`** and run it. If 2–3 are plausible, name them and ask which (or run the closest and mention the alternatives).
4. If nothing matches well, say so and suggest the nearest options — don't force a poor fit.

Variant suffixes: **`-genius`** = multi-disciplinary first-principles depth; **`-alien`** = removes the governor on reasoning, paradigm-breaking angles (use sparingly, high-cost/high-variance).

## Catalog

### Debugging & correctness
| Prompt | Use when |
| --- | --- |
| `bug-hunter` | Standard bug hunt after writing/changing code |
| `bug-hunter-genius` | Multi-disciplinary first-principles forensic debugging |
| `bug-hunter-alien` | Bugs beyond human cognitive categories (deep, exotic) |
| `system-weaknesses` | Analyze systemic weaknesses / failure modes |
| `deployment-verifier` | Verify a deployment is actually healthy |
| `e2e-pipeline-validator` | Validate an end-to-end pipeline works |
| `error-message-improver` | Make error messages clear and actionable |
| `cli-error-tolerance` | Harden a CLI against bad input / errors |
| `headless-webview-crumb-debugging` | Find a runtime hang in a Capacitor/WKWebView app with no inspector — env-gated crumb trail read via the a11y tree |

### Performance
| Prompt | Use when |
| --- | --- |
| `deep-performance-audit` | Thorough performance audit |
| `code-optimizer-alien` | Radical optimization (exotic algorithms, self-healing) |

### Code quality, refactor & review
| Prompt | Use when |
| --- | --- |
| `de-slopify` | Strip AI-slop / boilerplate, tighten code |
| `code-reorganizer` | Restructure / reorganize a codebase |
| `stub-eliminator` | Find and finish stubs / TODOs / placeholders |
| `peer-code-reviewer` | Peer-style code review |
| `dependency-audit` | Audit dependencies (risk, bloat, updates) |
| `test-coverage-gaps` | Find untested paths / coverage gaps |
| `api-contract-validator` | Validate API contracts / consistency |

### Planning, ideation & synthesis
| Prompt | Use when |
| --- | --- |
| `brainstorm` | Diverge-then-converge when unsure of approach |
| `idea-wizard` | Develop / pressure-test a single idea |
| `dueling-idea-wizards` | Two opposing perspectives debate an idea |
| `premortem-planner` | Premortem — surface how a plan fails before starting |
| `hundred-to-ten-filter` | Cut 100 options down to the best 10 |
| `plan-enhancer-alien` | Genius-level enhancements to an implementation plan |
| `project-opinion-elicitor` | Elicit strong opinions / direction on a project |
| `synthesize-info` | Synthesize scattered info into a coherent whole |
| `multi-model-synthesis` | Fan a question to multiple models, synthesize |

### Onboarding & docs
| Prompt | Use when |
| --- | --- |
| `deep-project-primer` | Get deeply oriented in an unfamiliar codebase |
| `readme-reviser` | Rewrite / improve a README |

### UI
| Prompt | Use when |
| --- | --- |
| `stripe-level-ui` | Push UI quality to Stripe-grade polish |

### Git & workflow
| Prompt | Use when |
| --- | --- |
| `git-committer` | Craft clean, well-structured commits |
| `land` | Land work / close out a session (flywheel) |
| `agent-swarm-launcher` | Launch a multi-agent swarm on a task |
| `robot-mode-maker` | Turn a workflow into a deterministic "robot mode" |

## Adding prompts

New prompts go in `references/<name>.md` and get a catalog row above. (The personal `prompt-add` skill automates dedup-checking and slug selection.)
