# Trigger precision/recall corpus

The cheapest skill eval in the promotion ladder (`references/promotion-ladder.md`
§ cheapest-first item 1): per skill, a **should-activate** set of natural prompts and a
**should-NOT-activate** exclusion set, judged against that skill's frontmatter
`description:` **alone** — that is all the router sees. A should-activate phrasing that
would not select the skill is a **recall** failure; a should-NOT phrasing that would
select it is a **precision** failure. Both are findings; the fix is a description edit,
re-judged after.

**This is a judged eval, not a machine-runnable check.** There is no router to assert
against — the verdicts below are model judgments recorded as evidence. Row grammar, so
un-verdicted rows are greppable: every phrasing row starts `- PASS`, `- FAIL`, or
`- PASS (after fix)`.

**Coverage: batch B1 — the 6 pipeline conductors** (`CONDUCTOR_SKILLS` in `lint.sh`) —
plus **B2, the 5 `ac-plan-*` skills**, plus **B3, the 2 `ac-qa-*` skills**. The remaining
registry skills are the follow-on
batches; enumerate them from
`skills/*/SKILL.md`, never `skills/*/` (`skills/_tools/` has no SKILL.md and is not a
skill, so a `*/` loop reports a phantom `MISSING _tools` forever).

---

## ac-loop

should-activate

- PASS — "run the loop"
- PASS — "ship everything available tonight, don't check in with me"
- PASS — "go autonomous on the backlog until it's clear"
- PASS — "work through all the ready beads without asking me anything"
- PASS — "kick off the scheduled overnight agent run"

should-NOT-activate

- PASS — "review this PR"
- PASS — "implement bead ac-xyz" (single named goal — the description routes that to the
  stages directly)
- FAIL (precision) → PASS (after fix) — "loop this prompt every 5 minutes". The
  description opened "Autonomous bead-shipping loop — runs scheduled…"; `loop` +
  `scheduled` is enough surface for a router to select it over the `loop` skill, which is
  what actually schedules an arbitrary prompt on an interval. Fix: an explicit exclusion
  clause naming the `loop` skill.
- PASS — "write a plan for the new feature"
- PASS — "close the batch"

## ac-implement

should-activate

- PASS — "work the beads"
- PASS — "start implementation on the refined beads"
- PASS — "run the wave"
- PASS — "implement the next three beads"
- PASS — "let's do the bead work for this epic"

should-NOT-activate

- FAIL (precision) → PASS (after fix) — "start implementing the login form". The listed
  trigger `start implementation` was unqualified, so a bare coding request with no bead
  behind it matched the strongest phrase in the description. Fix: qualify the trigger to a
  refined bead wave and add the explicit no-bead exclusion.
- PASS — "run the loop" (routes to ac-loop; ac-implement's own "loops until the wave is
  done" is body prose about its inner loop, not an autonomous-mode claim)
- PASS — "review the implementation"
- PASS — "refine these beads"
- PASS — "close out the session"

## ac-review

should-activate

- PASS — "review the branch"
- PASS — "pre-merge review"
- PASS — "code review this feature before we merge"
- PASS — "run the review panel over the wave's diff"
- FAIL (recall) → PASS (after fix) — "review the batch before we close it". The
  description said **Feature-branch** code review with `pre-merge review` as its latest
  trigger — under trunk-direct there is no feature branch and no merge, so the pipeline's
  actual pre-close gate phrasing did not match its own gate's description. Fix: name the
  trunk-direct batch case and add `review the batch` / `pre-close review` triggers.

should-NOT-activate

- PASS — "review my calendar for tomorrow"
- PASS — "review this book chapter"
- PASS — "review the plan document"
- PASS — "security review of the pending changes" (the built-in `security-review` is the
  narrower match; ac-review's security dimension is one lens of a 6-dimension panel, and
  the description scopes it to a branch/batch diff)
- PASS — "review these design mockups"

## ac-batch-close

should-activate

- PASS — "close the batch"
- PASS — "batch close"
- PASS — "ship the batch"
- PASS — "run the closing ceremony for these beads"
- PASS — "dispatch CI for this batch and commit the batch report"

should-NOT-activate

- PASS — "cut a release and tag it" (the description's explicit "moved to ac-publish"
  clause does the exclusion work — the clearest single precision win in B1)
- PASS — "close this bead"
- PASS — "land the session"
- PASS — "merge the wave"
- PASS — "close the sprint in Jira"

## ac-merge

should-activate

- PASS — "merge the wave"
- PASS — "merge to main"
- PASS — "ship the branch"
- PASS — "open a PR and land this branch"
- PASS — "merge this hygiene branch"

should-NOT-activate

- FAIL (precision) → PASS (after fix) — "land my trunk-direct batch on main". The
  description claimed to be "The single merge-to-main path for ANY branch", so a
  trunk-direct session — which never branches and closes via ac-batch-close — matched it
  on the strongest phrase it has. Over-claiming scope is a precision bug even when every
  word was true at the time it was written. Fix: scope to a PR branch and name the
  trunk-direct exclusion.
- PASS — "ship the batch"
- PASS — "close the batch"
- PASS — "resolve these merge conflicts"
- PASS — "git merge origin/main into my branch" (inverse direction; the description is a
  merge-TO-main path)

## ac-land

should-activate

- PASS — "land the session"
- PASS — "wrap up session"
- PASS — "close out the bead work"
- PASS — "clean up the spawned tasks and release the Agent Mail reservations"
- PASS — "do the retrospective for this wave"

should-NOT-activate

- PASS — "capture what I learned today" (the description's explicit "NOT for standalone
  lesson capture… that is reflect" clause catches it)
- PASS — "land this branch on main"
- PASS — "close the batch"
- PASS — "clean up my desktop files"
- PASS — "land the plane"

## ac-plan-clean

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "clean the plan"
- PASS — "correctness pass on the plan before we beadify"
- PASS — "run the hygiene pass over the plan draft"
- PASS — "check that the plan's structure holds together"
- PASS — "final polish on the plan before it becomes beads"

should-NOT-activate

- PASS — "make a plan for the migration" (routes to ac-plan-init, which clean's own
  "Requires an existing plan file; to create a plan use ac-plan-init" clause names)
- PASS — "refine the plan" (routes to ac-plan-refine-internal, whose literal trigger it is;
  clean scopes itself to "targeted fixes, not a rewrite")
- PASS — "get other models to critique this plan" (routes to ac-plan-refine-external —
  clean's 3 reviewers are its own hygiene pass, not external models)
- FAIL (precision) → PASS (after fix) — "check the plan for anything it's missing".
  `check the plan` is a literal ac-plan-clean trigger and the description claimed
  **completeness**, while `what is the plan missing` is a literal ac-plan-lab trigger and
  substantive gap-hunting is lab's job — two siblings claiming one phrasing with no
  discriminator between them. Fix: narrow clean's third axis from "completeness" to
  "internal consistency" and add an exclusion clause naming ac-plan-lab for gap-hunting.
- PASS — "clean up the stale files in my repo"

## ac-plan-init

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "make a plan"
- PASS — "plan this feature"
- PASS — "start a plan for the offline-sync work"
- PASS — "write me an implementation plan for this backlog item"
- PASS — "plan init"

should-NOT-activate

- PASS — "clean the plan" (routes to ac-plan-clean, named in init's own "To improve an
  existing draft use ac-plan-clean / ac-plan-refine-internal / ac-plan-refine-external" tail)
- PASS — "pressure-test this plan" (routes to ac-plan-lab, also named in that tail)
- PASS — "refine the plan with subagents" (routes to ac-plan-refine-internal — same tail;
  init is scoped to CREATE a first draft)
- PASS — "turn this plan into beads" (routes to ac-beadify — the cross-family confusable;
  init is the entry point of the planning chain and ends at the plan)
- PASS — "plan my week"

## ac-plan-lab

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "genius review the plan"
- PASS — "pressure-test this plan"
- PASS — "what is the plan missing"
- PASS — "alien perspective on this roadmap"
- PASS — "find the flaws in our Q3 delivery plan"

should-NOT-activate

- PASS — "take this raw concept somewhere new" (routes to ac-idea-lab, which lab's own
  closing clause names — the B1-predicted exclusion-clause shape)
- PASS — "check the plan" (routes to ac-plan-clean; lab's surface is entirely
  critique/transcendence verbs, with no correctness or hygiene claim)
- PASS — "refine external" (routes to ac-plan-refine-external — lab critiques in-session and
  never claims external models)
- PASS — "review the branch before we merge" (routes to ac-review; every lab trigger is
  plan/roadmap-scoped, never a diff)
- PASS — "run the weekly strategy review" (routes to the `strategist` skill — lab's
  "strategy" is qualified inline to "(steps/timelines/resources)", i.e. an executable plan,
  not an org review cadence)

## ac-plan-refine-external

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "refine external"
- PASS — "multi-model refine of this plan"
- PASS — "get other models to critique this plan"
- PASS — "run the plan past a couple of other models through openrouter"
- PASS — "external plan refinement on this high-stakes migration plan"

should-NOT-activate

- FAIL (precision) → PASS (after fix) — "refine the plan with a panel of reviewers". This
  was the one description in the family carrying NO sibling exclusion clause (clean names
  init; init names clean/refine-internal/refine-external/lab; lab names ac-idea-lab;
  refine-internal names refine-external; refine-external named nobody) — exactly the shape
  B1's method verdict predicted would fail. "refine … panel of reviewers" matches
  "multi-model refine" and "3–4 diverse … models" strongly, but the correct destination is
  ac-plan-refine-internal, whose reviewers are subagents. Fix: add the reciprocal exclusion
  clause naming ac-plan-refine-internal.
- PASS — "improve this plan with subagents" (routes to ac-plan-refine-internal — its literal
  trigger, and internal is explicit about "no external models")
- PASS — "clean the plan" (routes to ac-plan-clean; external's whole surface is external
  models plus the openrouter CLI)
- PASS — "ask another model what it thinks of this code" (not a plan — external scopes
  itself to "a HIGH-STAKES plan" and "external plan refinement")
- PASS — "compare pricing across OpenRouter models"

## ac-plan-refine-internal

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "refine the plan"
- PASS — "refine internal"
- PASS — "improve this plan with subagents"
- PASS — "multi-agent plan refinement, heavy tier"
- PASS — "deepen the plan until the reviewers converge"

should-NOT-activate

- PASS — "multi-model refine" (routes to ac-plan-refine-external, which internal's own
  "for external multi-model refinement use ac-plan-refine-external" tail names — the
  reciprocal of the fix applied to external above)
- PASS — "refine these beads" (routes to ac-bead-refine, the cross-family confusable; every
  internal trigger is plan-scoped)
- PASS — "check the plan for correctness" (routes to ac-plan-clean — internal DEEPENS,
  clean verifies; "correctness pass" appears only in clean)
- PASS — "make a plan for this feature" (routes to ac-plan-init; internal's "Requires an
  existing plan" is the discriminator)
- PASS — "refine the copy on the landing page"

## ac-qa-browser

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "browser QA"
- PASS — "validate the web build before we ship"
- PASS — "QA in browser against the production build"
- PASS — "web smoke test of the deployed URL"
- PASS — "run the appearance matrix and grab screenshots in the browser"

should-NOT-activate

- FAIL (precision) → PASS (after fix) — "QA the TestFlight build". `QA the deployed app` was
  the one trigger in this list carrying no surface qualifier, and in a pair whose ENTIRE
  distinction is the execution surface (browser vs device) that is the one place ambiguity is
  fatal — a TestFlight build is native and belongs to ac-qa-device, but "deployed app" matched
  browser's most generic trigger. Fix: qualify the trigger to `QA the deployed web app`.
- PASS — "QA on device" (routes to ac-qa-device — its literal trigger, and this description
  names itself "the web twin of ac-qa-device")
- PASS — "quick post-deploy smoke test of the login flow" (routes to browser-testing, which
  owns "quick post-deploy smoke tests, login/auth flows" verbatim and carries the reciprocal
  NOT-for clause pointing back here)
- PASS — "this flexbox layout is broken on mobile" (routes to ui-debug — a CSS/rendering
  defect, not a journey validation run)
- PASS — "test the API endpoint with curl"

## ac-qa-device

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "device QA"
- PASS — "QA on device"
- PASS — "test on iOS"
- PASS — "validate the native build on the simulator"
- PASS — "native smoke test with the appearance matrix"

should-NOT-activate

- PASS — "browser QA" (routes to ac-qa-browser — its literal trigger; this description names
  itself "the native twin of ac-qa-browser")
- PASS — "record a screen video of the app on the simulator for App Review" (routes to
  device-testing, which owns capture-as-deliverable verbatim and carries the reciprocal
  NOT-for clause pointing back here)
- PASS — "validate the web build" (routes to ac-qa-browser; every ac-qa-device trigger carries
  a native/device/simulator/iOS qualifier — the asymmetry the browser-side fix above closed)
- PASS — "the safe-area padding is wrong in this component" (routes to ui-debug — a CSS defect
  in React, not a native journey run)
- PASS — "set up a new iOS provisioning profile"

---

## Findings and fixes

| Skill | Failure | Class | Fix applied |
|---|---|---|---|
| ac-loop | "loop this prompt every 5 minutes" selected it | precision | exclusion clause naming the `loop` skill |
| ac-implement | "start implementing the login form" selected it | precision | `start implementation` qualified to a refined bead wave + no-bead exclusion |
| ac-review | "review the batch before we close it" did NOT select it | recall | trunk-direct batch named; `review the batch` / `pre-close review` triggers added |
| ac-merge | "land my trunk-direct batch on main" selected it | precision | scoped to a PR branch + trunk-direct exclusion naming ac-batch-close |
| ac-batch-close | — | — | none needed |
| ac-land | — | — | none needed |
| ac-plan-clean | "check the plan for anything it's missing" selected it | precision | third axis narrowed from "completeness" to "internal consistency" + exclusion naming ac-plan-lab for gap-hunting |
| ac-plan-refine-external | "refine the plan with a panel of reviewers" selected it | precision | reciprocal exclusion clause naming ac-plan-refine-internal added |
| ac-plan-init | — | — | none needed |
| ac-plan-lab | — | — | none needed |
| ac-plan-refine-internal | — | — | none needed |
| ac-qa-browser | "QA the TestFlight build" selected it | precision | trigger qualified from `QA the deployed app` to `QA the deployed web app` |
| ac-qa-device | — | — | none needed |

Score: 60 judgments, 4 failures (3 precision, 1 recall), across 4 of 6 skills. All four
re-judged PASS after the description edit; the re-judged verdicts are recorded inline
above as `PASS (after fix)`. Whether the follow-on batch runs at all is gated on the
method verdict below, not on this score.

Observation carried to the follow-on batch (not a precision/recall failure, so not fixed
here): ac-batch-close's description embeds a bare bead id, `(bd-pwt44)`. It costs router
tokens and says nothing to a router; provenance belongs in the ledger. Sweep bead-id
tokens out of descriptions as a batch, not one-off.

B2 score: 50 judgments, 2 failures (both precision), across 2 of the 5 `ac-plan-*` skills.
Both re-judged PASS after the description edit. The bead-id sweep carried from B1 was run
across all 17 skills in batches B2–B5 and returned zero hits — nothing to strip. B1's
prediction held exactly: the only skill with no sibling exclusion clause
(ac-plan-refine-external) is the one that failed on an inter-sibling near-miss.

B3 score: 20 judgments, 1 failure (precision), across 1 of the 2 `ac-qa-*` skills. Re-judged
PASS after the description edit. As the designated calibration run this pair confirmed the
sharpest form of the B1 finding: where two siblings differ ONLY by execution surface, any
trigger phrase left un-qualified for that surface is the failure — every other trigger in
both descriptions carried its qualifier and passed.

## Method verdict

**GO.**

Judging from the `description:` alone produced usable, non-noisy signal on all 6
conductors: a 4/6 hit rate with zero coin-flip calls, and every failure traced to a
specific clause that could be edited. Three properties made it work, and they are the
conditions the follow-on batch inherits:

1. **The failures were not stylistic.** Each one was a real routing error a user would
   hit — two of them (ac-review, ac-merge) were descriptions that had gone stale against
   trunk-direct while their bodies had already been updated. The eval found doctrine
   drift that no lint check sees, which is more value than "test the router" promised.
2. **Explicit exclusion clauses are what pass.** The two clean skills (ac-batch-close,
   ac-land) are exactly the two whose descriptions already carry a NOT-for clause. That
   is the transferable fix shape, and it predicts the follow-on's failures: skills with
   no NOT-for clause and a generic verb in their trigger list.
3. **The near-miss set is where the signal is.** Unrelated negatives ("review my
   calendar") are free passes and prove nothing; every finding came from a phrasing that
   sits between two sibling skills. Weight the follow-on's exclusion sets toward
   same-family near-misses, not distant domains.

Caveat on the method, recorded so the follow-on does not over-trust it: the judge is the
same model that will later be routed, judging its own description text with the whole
registry in context — it can see distinctions a cold router may miss, so these verdicts
are a **lower bound** on the true failure rate, never an upper one.
