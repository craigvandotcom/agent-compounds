# Version bump — interactive AskUserQuestion spec

Read only in **interactive mode** — when a human runs ac-merge directly and wants to
override the default bump, NOT when running under a delegation prompt that pre-answers
the bump (`ac-loop` / `ac-hygiene` delegated runs take `patch` silently). Use these
exact labels and descriptions — the option wording is the enforcement content; do not
paraphrase it.

```
AskUserQuestion(
  questions: [{
    question: "Bump v{CURRENT_VERSION} → patch (default)? Choose minor/major only for a deliberate milestone, or skip if frozen.",
    header: "Version bump",
    multiSelect: false,
    options: [
      { label: "patch (Recommended)", description: "Default for EVERY merge — fixes, features, and chores alike. App version is a build number, not a library API contract." },
      { label: "minor", description: "Explicit opt-in only — a deliberate feature-milestone release you are choosing now." },
      { label: "major", description: "Explicit opt-in only — a deliberate, announced breaking/milestone release." },
      { label: "skip — freeze the version", description: "Only for a standing freeze (e.g. an App Store submission in review). Don't touch package.json." }
    ]
  }]
)
```
