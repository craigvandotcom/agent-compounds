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

**Coverage: batch B1 — the 6 pipeline conductors** (`CONDUCTOR_SKILLS` in `lint.sh`) — plus
**B2, the 5 `ac-plan-*` skills**, **B3, the 2 `ac-qa-*` skills**, **B4, the 6 bead-lifecycle
skills**, **B5, the 4 polish/publish skills**, **B6, the 8 remaining `ac-*` skills**, and
**B7, the 12 agent-system + build-platform domain skills**, and **B8, the 15 testing/creative/
publishing domain skills** — **58 skills judged: the complete registry**. Enumerate skills from
`skills/*/SKILL.md`, never `skills/*/` (`skills/_tools/` has no SKILL.md and is not a skill, so
a `*/` loop reports a phantom `MISSING _tools` forever).

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

## ac-backlog

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "add to backlog"
- PASS — "backlog this for a future wave"
- PASS — "park this idea for now"
- PASS — "note this one for later"
- PASS — "capture this theme into the backlog pool"

should-NOT-activate

- FAIL (precision) → PASS (after fix) — "capture this bug I just hit". ac-backlog was the one
  skill in this six-way cluster carrying NO cross-reference clause, while its trigger
  `capture idea` and its own "shape-routing (small+clear goes straight to a bead)" phrase both
  claim bead-creation surface — but a typed bug belongs to ac-bead-capture. Fix: add the
  exclusion clause naming ac-bead-capture for a typed bead now, and ac-beadify for a plan.
- PASS — "beadify this plan" (routes to ac-beadify — backlog is an idea pool, not a plan
  decomposer)
- PASS — "refine the beads" (routes to ac-bead-refine — backlog never touches existing beads)
- PASS — "clean up the backlog" (routes to ac-tidy, whose literal trigger it is — ac-backlog
  fills the pool, ac-tidy grooms it)
- PASS — "add milk to my shopping list"

## ac-bead-capture

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "bead this"
- PASS — "file this as a bead"
- PASS — "log a bug"
- PASS — "track this item"
- PASS — "remember to do X"

should-NOT-activate

- PASS — "park this idea for later" (routes to ac-backlog, which capture's own tail names for
  the grouped backlog pool)
- PASS — "turn this plan into beads" (routes to ac-beadify — also named in that tail)
- PASS — "refine these beads" (routes to ac-bead-refine — the third name in that tail; capture
  creates, refine converges)
- PASS — "pull the new Sentry crashes onto the board" (routes to ac-triage — a fetch-and-cluster
  run over external systems, not a user-dictated capture)
- PASS — "remember my birthday"

## ac-bead-refine

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "refine the beads"
- PASS — "bead refine"
- PASS — "make these beads implementation-ready"
- PASS — "refine bead structure before we implement"
- PASS — "get the unrefined beads to convergence"

should-NOT-activate

- PASS — "refine the plan" (routes to ac-plan-refine-internal, the B2 sibling; every
  ac-bead-refine trigger is bead-scoped)
- PASS — "create beads from this plan" (routes to ac-beadify, which refine's own tail names —
  "creating plan-decomposition beads is ac-beadify's job")
- PASS — "bead this observation" (routes to ac-bead-capture — capture creates one, refine
  converges what exists)
- PASS — "work the refined beads" (routes to ac-implement — refine stamps the label,
  ac-implement consumes it)
- PASS — "refine the wording of this email"

## ac-beadify

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "beadify"
- PASS — "turn this plan into beads"
- PASS — "create beads from the plan"
- PASS — "break the plan into tasks"
- PASS — "decompose the approved plan into a bead structure"

should-NOT-activate

- PASS — "refine the beads afterwards" (routes to ac-bead-refine, which beadify's own tail
  names)
- PASS — "bead this one thing" (routes to ac-bead-capture — beadify requires an existing plan
  and creates a whole structure)
- PASS — "turn these hygiene findings into an epic of beads" (routes to ac-hygiene, which owns
  "deferred findings become an epic of beads" verbatim — this skill's highest-overlap
  neighbour in the registry at 100 shared shingles)
- PASS — "make a plan for this feature" (routes to ac-plan-init — beadify starts where the
  planning chain ends)
- PASS — "break this rock into gravel"

## ac-tidy

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "tidy the pipeline"
- PASS — "clean up the backlog"
- PASS — "reconcile plans and beads"
- PASS — "pipeline housekeeping"
- PASS — "archive the completed items and flag orphans"

should-NOT-activate

- PASS — "clean up the codebase" (routes to ac-hygiene, named explicitly in ac-tidy's own tail —
  one of only two skills in this family that already carried a NOT-for clause)
- PASS — "add this idea to the backlog" (routes to ac-backlog — ac-tidy grooms the pool, it
  does not fill it)
- PASS — "clean the plan" (routes to ac-plan-clean — a plan-draft hygiene pass, not pipeline
  housekeeping)
- PASS — "triage the new crash reports" (routes to ac-triage — inbound external signal, not
  board reconciliation)
- PASS — "tidy my downloads folder"

## ac-triage

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "triage crashes"
- PASS — "check sentry"
- PASS — "any new errors in prod"
- PASS — "pull the TestFlight feedback"
- PASS — "triage github issues"

should-NOT-activate

- FAIL (precision) → PASS (after fix) — "triage the open beads and tell me what to work on".
  The bare verb `triage` plus the trigger `triage production signal` was enough surface to
  select it, but triaging the board is `bv`'s job (read-only) and getting beads workable is
  ac-bead-refine's — ac-triage is strictly INBOUND external signal, and it carried no NOT-for
  clause. Fix: add an exclusion clause naming bv / ac-bead-refine for board triage.
- PASS — "clean up the backlog" (routes to ac-tidy — reconciling what is already on the board)
- PASS — "bead this crash I just saw" (routes to ac-bead-capture — one user-dictated item, not
  a fetch-and-cluster run over external systems)
- PASS — "post the release notes out to the list" (routes to ac-distribute, which ac-triage
  names inline as its outbound counterpart)
- PASS — "triage the patients in the waiting room"

## ac-distribute

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "ship to testflight"
- PASS — "push a build"
- PASS — "release to app store"
- PASS — "cut a build for the beta testers"
- PASS — "submit for review"

should-NOT-activate

- FAIL (precision) → PASS (after fix) — "ship it to production". ac-distribute opens "Use to
  SHIP a built app out the door" and calls itself "the outbound last mile", so it owned the
  strongest `ship` surface in the registry — but the production release GATE is ac-publish,
  which pins main, mints the version bump, calls ac-prove, runs the heavy review, tags, and
  only THEN calls ac-distribute. Routing "ship it to production" here skips every gate, which
  makes this the most consequential miss found across B2–B5 rather than a cosmetic one. The
  reference was asymmetric: ac-publish names ac-distribute, ac-distribute named ac-triage and
  ac-qa-device but not ac-publish. Fix: add the reciprocal clause naming ac-publish.
- PASS — "pull the crashes back in" (routes to ac-triage, which ac-distribute's own tail names
  as the inbound counterpart)
- PASS — "prove the build works on device first" (routes to ac-qa-device — also named in that
  tail)
- PASS — "is main green" (routes to ac-prove — its literal trigger; ac-distribute makes no
  CI-trust claim)
- PASS — "distribute these flyers at the conference"

## ac-publish

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "publish"
- PASS — "release to prod"
- PASS — "ship it to production"
- PASS — "cut the release"
- PASS — "run the release gate and tag the proved commit"

should-NOT-activate

- PASS — "ship to testflight" (routes to ac-distribute — the beta lane it composes; every
  ac-publish trigger is production-scoped)
- PASS — "is main green" (routes to ac-prove, which ac-publish explicitly names as a component
  it calls rather than a job it does)
- PASS — "run the heavy review over everything since the last publish" (routes to ac-review —
  the sharpest near-miss here, since ac-publish's description contains that phrase verbatim;
  what saves it is the "Composes ac-prove + ac-review + ac-distribute" framing, which reads to
  a router as parts, not scope)
- PASS — "close the batch" (routes to ac-batch-close — the per-batch checkpoint, not the
  human-triggered production gate)
- PASS — "publish this article to the blog"

## ac-site-polish

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "polish the website"
- PASS — "polish the landing page"
- PASS — "the website looks like AI slop"
- PASS — "audit the public site"
- PASS — "elevate the homepage"

should-NOT-activate

- PASS — "polish this UI" (routes to ac-ui-polish, which this description names inline as the
  owner of the authenticated app — the sharpest sibling pair in the batch at 210 shared
  shingles, and the mutual "public twin / NOT for the authenticated app" wording separates it
  cleanly in both directions)
- PASS — "just fix the SEO metadata on these pages" (routes to seo-metadata, named in the
  5-item NOT-for clause)
- PASS — "run an accessibility audit" (routes to web-design-guidelines, also named there)
- PASS — "brainstorm three directions for the hero section" (routes to ui-brainstorm, also
  named there)
- PASS — "this div overflows on mobile" (routes to ui-debug, also named there — a CSS defect,
  not a polish pass)

## ac-ui-polish

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "polish this UI"
- PASS — "make this feel premium"
- PASS — "check design conformance"
- PASS — "tighten the visuals on the settings screen"
- PASS — "this screen looks like AI slop"

should-NOT-activate

- PASS — "polish the landing page" (routes to ac-site-polish, named first in ui-polish's own
  NOT-for clause — the reciprocal of the row above)
- PASS — "accessibility audit of this flow" (routes to web-design-guidelines, named there)
- PASS — "design ideation for a new dashboard" (routes to ui-brainstorm, named there)
- PASS — "the modal has a z-index bug" (routes to ui-debug, named there)
- PASS — "polish my shoes"

## ac-align

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "align pipeline"
- PASS — "is my pipeline on strategy"
- PASS — "audit the backlog against my goals"
- PASS — "what should we plan next"
- PASS — "promote something from the pool to active"

should-NOT-activate

- FAIL (precision) → PASS (after fix) — "what should I work on next". One word off the listed
  trigger `what should we plan next`, but the destination is the human docket (ac-human-session)
  or the board read (ac-dashboard) — ac-align decides what to PLAN, not what to touch now, and
  it carried no NOT-for clause. Fix: exclusion clause naming ac-dashboard / ac-human-session.
- FAIL (precision) → PASS (after fix) — "stress-test my strategy". The description says
  `against current strategy` and `against live strategy`; that is enough strategy surface to
  select it over ac-idea-lab, which owns working the idea itself. Named confusion cluster in
  the bead, and it bit. Fix: the same clause names ac-idea-lab (and strategist for org
  strategy).
- PASS — "clean up the backlog" (routes to ac-tidy — reconciling what is on the board, not
  judging it against strategy)
- PASS — "show me the board" (routes to ac-dashboard — ac-align writes, it does not render)
- PASS — "align the paragraph to the left margin"

## ac-dashboard

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "dashboard"
- PASS — "show the board"
- PASS — "state of the pipeline"
- PASS — "what's the factory doing"
- PASS — "give me the full WIP picture across waves, PRs and CI"

should-NOT-activate

- PASS — "what needs me" (routes to ac-human-session, named explicitly in ac-dashboard's own
  routing tail — one of only three skills in this family that already carried one)
- PASS — "reconcile the board and archive what's done" (routes to ac-tidy, named inline)
- PASS — "re-prioritize the backlog against strategy" (routes to ac-align, named inline)
- PASS — "is main green" (routes to ac-prove, which carries that exact phrase as a literal
  trigger; ac-dashboard only lists CI among the panes it renders, so the literal wins)
- PASS — "build me an analytics dashboard page for the app"

## ac-human-session

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "human session"
- PASS — "what needs me"
- PASS — "what's blocked on me"
- PASS — "sit down"
- PASS — "I have twenty minutes — what needs my approval"

should-NOT-activate

- FAIL (precision) → PASS (after fix) — "unblock this failing build". The listed trigger
  `unblock work` is unscoped, so a technical blocker reads as a human-gate blocker; the
  destination is debug (or ac-triage for inbound signal). No NOT-for clause existed. Fix:
  exclusion clause scoping `unblock` to human gates and naming debug.
- PASS — "show me the whole board including the loop-side work" (routes to ac-dashboard —
  ac-human-session deliberately shows only gated work)
- PASS — "tidy the pipeline" (routes to ac-tidy — ac-human-session only mentions tidy as an
  optional pre-pass, not as its job)
- PASS — "run the loop overnight" (routes to ac-loop — ac-human-session hands off TO it)
- PASS — "book me a sit-down with the team"

## ac-hygiene

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "hygiene"
- PASS — "clean up the codebase"
- PASS — "weekly hygiene run"
- PASS — "run a multi-round adversarial review over the code"
- PASS — "find correctness and security cleanups across the app"

should-NOT-activate

- FAIL (precision) → PASS (after fix) — "review this feature branch before merge". The
  description opens `Iterative codebase review` and lists the trigger `iterative review`;
  `review` plus `codebase` is enough surface to beat ac-review, which owns the branch/PR gate.
  Telling: ac-registry-audit's own tail already names `ac-review for a feature branch` while
  ac-hygiene, the skill actually colliding, carried no NOT-for clause at all. Fix: exclusion
  clause naming ac-review.
- FAIL (precision) → PASS (after fix) — "audit the auth module for security holes". The
  description advertises `correctness/security/resilience/contract/reuse cleanups`, so a
  single-module deep audit selects the 7-lens whole-codebase panel; the destination is the
  audit skill. Fix: the same clause names audit.
- PASS — "audit the skill registry for trigger collisions" (routes to ac-registry-audit, which
  names ac-hygiene inline as its counterpart)
- PASS — "tidy the pipeline" (routes to ac-tidy — board housekeeping, not code)
- PASS — "clean up my downloads folder"

## ac-idea-lab

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "stress-test this idea"
- PASS — "devil's advocate on this concept"
- PASS — "what am I missing at a deeper level"
- PASS — "give me the alien perspective on this framework"
- PASS — "first-principles critique of this positioning"

should-NOT-activate

- FAIL (precision) → PASS (after fix) — "brainstorm twenty new product ideas". ALIEN mode
  advertises `paradigm transcendence`, `cross-domain transplants`, `expand`, which reads as
  open-ended generation; the destination is brainstorming. The one exclusion the description
  carried named only ac-plan-lab. Fix: extend the tail to name brainstorming (and
  expert-consensus for the multi-model case).
- PASS — "write a plan with steps and timelines" (routes to ac-plan-lab, named inline)
- PASS — "is my pipeline on strategy" (routes to ac-align, which carries that phrase as a
  literal trigger — the named ac-idea-lab/ac-align cluster resolves correctly in this
  direction)
- PASS — "review this PR" (routes to ac-review — ac-idea-lab is explicitly for things without
  execution steps yet)
- PASS — "get several models to weigh in on this" (routes to expert-consensus — ac-idea-lab is
  a single-judge critique)

## ac-pipeline

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).
This is a canon-holder, not an action skill, so its negatives are weighted toward phrasings
that must wake a conductor or a stage skill instead.

should-activate

- PASS — "pipeline architecture"
- PASS — "add a new stage to the pipeline"
- PASS — "what are the pipeline standards"
- PASS — "where is commit discipline documented"
- PASS — "what's the contract for the verification gate"

should-NOT-activate

- FAIL (precision) → PASS (after fix) — "run validate-qa-run". The description enumerates its
  hosted scripts by name (`scripts/: beads-closed-gate, validate-qa-run`), which reads as a
  capability rather than an inventory, and the NOT-for clause excluded only RUNNING THE
  PIPELINE and EXECUTING A STAGE — never firing a gate/script the skill merely hosts, which
  the calling ceremony owns. Fix: widen the clause to exclude running anything, hosted
  scripts included. Net-neutral-adjacent edit: this is the family's tightest description
  (821/1024, 203 headroom), and the rewrite stays inside it.
- PASS — "run the pipeline" (routes to ac-loop, named in its own NOT-for clause)
- PASS — "implement the ready beads" (routes to ac-implement — covered by the stage-skill
  exclusion)
- PASS — "close the batch" (routes to ac-batch-close, same exclusion)
- PASS — "show me the state of the pipeline" (routes to ac-dashboard, which carries `state of
  the pipeline` as a literal trigger)

## ac-prove

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "prove this commit"
- PASS — "is main green"
- PASS — "get a fresh checkpoint"
- PASS — "gate on a full proof before shipping"
- PASS — "dispatch a full-suite run and fix forward"

should-NOT-activate

- FAIL (precision) → PASS (after fix) — "run the full test suite". The description sells
  `tip-valid full-suite proof` and `the full leg`, so plain local execution selects the
  CI-trust primitive; the destination is the testing skill (or just running the command).
  No NOT-for clause existed. Fix: exclusion clause naming testing.
- PASS — "show CI status on the board" (routes to ac-dashboard — ac-prove obtains a proof, it
  does not render panes)
- PASS — "publish the release" (routes to ac-publish, the ship path that CALLS ac-prove)
- PASS — "review the code quality across the app" (routes to ac-hygiene — the named
  hygiene/registry-audit/prove cluster separates cleanly here)
- PASS — "audit the skill registry" (routes to ac-registry-audit)

## ac-registry-audit

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "registry audit"
- PASS — "audit the skill registry"
- PASS — "dedup the skills"
- PASS — "skill collision check"
- PASS — "are any of our skill triggers colliding"

should-NOT-activate

- PASS — "clean up the codebase" (routes to ac-hygiene, named inline in its own NOT-for tail —
  the strongest exclusion clause in this family, and it is why this skill needed no fix)
- PASS — "review this feature branch" (routes to ac-review, named inline)
- PASS — "clean up the backlog" (routes to ac-tidy, named inline)
- PASS — "audit the auth module" (routes to audit, named inline as the single-domain case)
- PASS — "write me a new skill for X" (routes to skill-builder — authoring, not auditing;
  not named inline but the description is scoped to auditing an existing corpus)

## agent-mail

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "register agent identity"
- PASS — "reserve files before I edit"
- PASS — "I hit FILE_RESERVATION_CONFLICT"
- PASS — "release reservations and deregister"
- PASS — "should this session mint a Tier-1 identity or use FoggyCreek"

should-NOT-activate

- FAIL (precision) → PASS (after fix) — "how do I commit safely in the shared checkout". The
  description advertises `reserving files before editing a shared checkout` and `a pre-commit
  guard block`, but commit discipline itself is owned by ac-pipeline (references/
  commit-discipline); agent-mail owns the reservation, not the commit sequence. No NOT-for
  clause existed. Fix: exclusion clause naming ac-pipeline.
- PASS — "email the release notes to the list" (routes to ac-distribute — Agent Mail is
  agent-to-agent coordination, not outbound publishing)
- PASS — "which agent should I delegate this to" (routes to ac-pipeline's delegation-contract —
  agent-mail is identity and locking, not stance selection)
- PASS — "run the loop with two children in parallel" (routes to ac-loop, which CALLS agent-mail
  rather than being it)
- PASS — "check my inbox"

## beads-standards

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "which label should this bead carry"
- PASS — "what close reason do I use"
- PASS — "how do I write a human-gate bead"
- PASS — "refined vs unrefined — what's the rule"
- PASS — "bead template"

should-NOT-activate

- FAIL (precision) → PASS (after fix) — "refine these beads until they're workable". The
  description opens `Use when creating, refining, or reviewing a bead` and lists the trigger
  `refined unrefined`, which is enough surface to beat ac-bead-refine — the skill that actually
  DOES the refining. beads-standards is the standard those skills follow, not an executor, and
  it carried no NOT-for clause. Fix: exclusion clause naming the ac-bead-* executors.
- FAIL (precision) → PASS (after fix) — "file a bead for this crash". `create a bead` is a
  LITERAL listed trigger, so a capture request selects the canon doc instead of
  ac-bead-capture. Same root cause, same fix.
- PASS — "generate a wave of beads from this plan" (routes to ac-beadify — named in the fix
  clause for the same reason)
- PASS — "triage the board and tell me what's ready" (routes to bv / ac-dashboard — reading the
  board is not writing a bead)
- PASS — "what beads are on my necklace"

## capacitor

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "capacitor"
- PASS — "the tab switch flashes a skeleton"
- PASS — "cold start is slow on iOS"
- PASS — "how should I do keep-mounted tab navigation"
- PASS — "static export plus WKWebView safe-area handling"

should-NOT-activate

- FAIL (precision) → PASS (after fix) — "write a test for this component". The description
  claims `ALL engineering decisions` on the stack and lists `plugin`, `background`, `app
  resume` — an unbounded scope statement with no NOT-for clause, so testing loses. Fix:
  exclusion clause naming testing.
- FAIL (precision) → PASS (after fix) — "write the migration for this schema change". The
  stack line names `Supabase` explicitly, and `data fetching` plus `storage` covers the DB
  surface, so this beats supabase — which reciprocally already names capacitor in its own
  clause while capacitor named nothing. Fix: the same clause names supabase.
- PASS — "the modal has a z-index bug" (routes to ui-debug, which owns visual/CSS defects)
- PASS — "is this form accessible" (routes to web-design-guidelines, which already names
  capacitor as the React-performance destination — the reciprocal now exists)
- PASS — "how do capacitors work in a circuit"

## context-engineering

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).
This is the sharpest cluster in the batch — context-engineering / reflect / dream — so the
negatives below are weighted onto its two siblings.

should-activate

- PASS — "where should this live"
- PASS — "how do we store and remember X"
- PASS — "what loads when"
- PASS — "audit our CLAUDE.md and CORE structure"
- PASS — "design the memory architecture for this new repo"

should-NOT-activate

- FAIL (stale) → PASS (after fix) — "organize these files into folders". The NOT-for clause
  routed this to `librarian`, a skill that DOES NOT EXIST — no `skills/librarian/SKILL.md` in
  agent-compounds and none in the root agent home either (both checked; the root registry is a
  symlink to this one). A dangling destination cannot route, so the exclusion was decorative.
  This is the staleness class the batch was warned about, not an imprecision. Fix: drop the
  phantom name and state the exclusion behaviorally.
- PASS — "capture what we learned this session" (routes to reflect, named inline)
- PASS — "run the dream cycle" (routes to dream — cross-session synthesis, not a routing
  decision)
- PASS — "write a new skill" (routes to skill-builder — authoring, not architecture)
- PASS — "what's the context for this ticket"

## dream

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "run the dream cycle"
- PASS — "synthesize the week's lessons"
- PASS — "lint the memory substrate"
- PASS — "review dream proposals"
- PASS — "what did the dream cycle find"

should-NOT-activate

- PASS — "capture what we learned this session" (routes to reflect, named inline in dream's own
  NOT-for clause — the cluster resolves correctly in this direction)
- PASS — "save this one rule somewhere durable" (routes to context-engineering, also named
  inline)
- PASS — "where should this decision live" (routes to context-engineering — the routing
  question, not the synthesis run)
- PASS — "audit the skill registry" (routes to ac-registry-audit — dream lints memory, not the
  prompt corpus)
- PASS — "interpret my dream last night"

## openrouter

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "which model for this task"
- PASS — "ask Gemini directly"
- PASS — "list available models"
- PASS — "run this on DeepSeek"
- PASS — "switch to a non-default model for this step"

should-NOT-activate

- FAIL (precision) → PASS (after fix) — "get several models to weigh in and rank the answers".
  `ask GPT/Gemini/Grok directly` plus `400+ models` is enough surface to select the transport
  when the destination is expert-consensus, which owns the multi-model panel and ranking. No
  NOT-for clause existed. Fix: exclusion clause naming expert-consensus.
- PASS — "give me multiple divergent design options from different models" (routes to
  ui-brainstorm, which names cross-model consensus ranking as its own job)
- PASS — "what are Claude's pricing tiers" (routes to the claude-api reference — openrouter is
  the multi-provider gateway, not the Anthropic API doc)
- PASS — "improve this prompt before I send it" (routes to prompt-enhance — the prompt, not the
  model)
- PASS — "open the router config on my wifi box"

## planning

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "explain scope oscillation"
- PASS — "what are the divergent-convergent lenses"
- PASS — "I'm planning something outside the pipeline — what's the method"
- PASS — "the plan stage cites a methodology, show me it"
- PASS — "Jeffrey Emanuel planning methodology"

should-NOT-activate

- PASS — "create a plan for this feature" (routes to ac-plan-init, named inline — the
  description is explicit that it is reference-only and NOT a direct entry point)
- PASS — "refine this plan" (routes to ac-plan-refine-internal / ac-plan-refine-external, both
  named inline with their routine/high-stakes split)
- PASS — "do a final correctness pass on the plan" (routes to ac-plan-clean, named inline)
- PASS — "improve the prompts inside this plan command" (routes to prompt-enhance — the named
  planning/prompt-enhance cluster separates cleanly, planning carries no prompt surface)
- PASS — "plan my week"

## prompt-enhance

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "enhance prompts"
- PASS — "score the subagent prompts in this skill"
- PASS — "audit command prompts against the rubric"
- PASS — "prompt engineering pass over our commands"
- PASS — "fix the subagent prompts in this command file"

should-NOT-activate

- FAIL (precision) → PASS (after fix) — "rate this prompt" applied to a one-off user prompt
  (a marketing brief, an image prompt). It is a LITERAL listed trigger, but the skill only
  audits subagent prompts inside skill/command FILES against a rubric — there is no artifact
  to score for an ad-hoc prompt. No NOT-for clause existed to scope it. Fix: exclusion clause
  stating the skill/command-file scope.
- PASS — "clean up our skills" (routes to skill-builder — dieting and structure, not prompt
  rubric scoring)
- PASS — "audit the registry for trigger collisions" (routes to ac-registry-audit — cross-skill
  collisions, not within-file prompt quality)
- PASS — "what's the planning methodology" (routes to planning — the named
  planning/prompt-enhance cluster, which separates on the word `prompt`)
- PASS — "prompt me before you delete anything"

## reflect

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "reflect"
- PASS — "capture learnings"
- PASS — "what did we learn"
- PASS — "compound this session"
- PASS — "save the lessons before I close this out"

should-NOT-activate

- FAIL (precision) → PASS (after fix) — "where should this decision live". `remember this` and
  `save lessons` are listed triggers, and the NOT-for clause named ac-land and dream but NOT
  context-engineering — the sibling that actually owns the WHERE-to-save routing. The
  asymmetry is the tell: dream's clause names both reflect and context-engineering, and
  context-engineering's names reflect, while reflect's named neither. Fix: add
  context-engineering to the clause.
- PASS — "run the full bead-work closure" (routes to ac-land, named inline)
- PASS — "synthesize the week's lessons across sessions" (routes to dream, named inline)
- PASS — "audit our memory architecture" (routes to context-engineering — design, not capture)
- PASS — "reflect the light off this surface"

## skill-builder

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).
Self-referential caveat: this is the skill that OWNS the corpus file being written, so its
verdicts are judged by the very method it defines — an even weaker lower bound than the rest.

should-activate

- PASS — "create a skill"
- PASS — "diet this SKILL.md down"
- PASS — "extract this section to references/"
- PASS — "our description budget is over — trim it"
- PASS — "refactor this skill"

should-NOT-activate

- FAIL (precision) → PASS (after fix) — "build a /command that runs this SOP end to end". The
  triggers `convert to a skill` and `build a skill` sit right on workflow-builder's territory,
  and the asymmetry is the tell: workflow-builder's clause names skill-builder, skill-builder
  named nothing back. Fix: exclusion clause naming workflow-builder.
- FAIL (precision) → PASS (after fix) — "audit the registry for trigger collisions". `clean up
  our skills` and `skill hygiene` are listed triggers that collide directly with
  ac-registry-audit's `registry hygiene` — one skill authors, the other audits the corpus.
  Fix: the same clause names ac-registry-audit.
- PASS — "score the subagent prompts in this skill file" (routes to prompt-enhance — prompt
  rubric, not skill structure)
- PASS — "where should this knowledge live" (routes to context-engineering — placement
  doctrine, not authoring)
- PASS — "build me a skill-based training plan"

## supabase

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "write a migration for this schema change"
- PASS — "review this RLS policy"
- PASS — "generate TypeScript types from the schema"
- PASS — "this query needs an index"
- PASS — "supabase db reset is failing locally"

should-NOT-activate

- FAIL (stale) → PASS (after fix) — "build the UI for this table". The NOT-for clause routed UI
  component work to `design-system`, a skill that DOES NOT EXIST — no
  `skills/design-system/SKILL.md` in agent-compounds and none in the root agent home (both
  checked). The exclusion could not route, which is the staleness class this batch was warned
  about rather than an imprecision. Fix: name the live destinations instead
  (web-design-guidelines for correctness, ac-ui-polish for polish).
- PASS — "React tab-switch performance on native" (routes to capacitor, named inline and
  still live)
- PASS — "write a test for this query helper" (routes to testing — supabase owns the SQL, not
  its harness)
- PASS — "how do I store a token on device" (routes to capacitor — Preferences storage, not
  Postgres)
- PASS — "set up a supabase for the kitchen"

## workflow-builder

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "build a workflow"
- PASS — "create a /command"
- PASS — "turn this SOP into a command"
- PASS — "design a pipeline command for the newsletter run"
- PASS — "scaffold a recurring report job"

should-NOT-activate

- PASS — "author a new SKILL.md" (routes to skill-builder, named inline in its own NOT-for
  clause — the strongest exclusion in this family, and why it needed no fix)
- PASS — "change how the engineering pipeline is designed" (routes to ac-pipeline, named
  inline)
- PASS — "run the pipeline tonight" (routes to ac-loop, named inline)
- PASS — "where should this knowledge live" (routes to context-engineering, named inline)
- PASS — "build a workflow for my morning routine"

## testing

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).
Cluster 1 of 3 (verification) — the bead's predicted failure profile, no NOT-for clause plus a
generic verb, describes this skill exactly, and it bit.

should-activate

- PASS — "write a test for this helper"
- PASS — "this Vitest spec is flaky"
- PASS — "add test coverage for the reducer"
- PASS — "mock MSW for this endpoint"
- PASS — "review these RTL component tests"

should-NOT-activate

- FAIL (precision) → PASS (after fix) — "test the login flow in the browser". The trigger list
  is bare verbs — `test`, `spec`, `coverage`, `mock` — and `E2E tests` plus `Playwright` add
  browser surface, so this beats browser-testing, whose literal trigger `check login` it should
  have lost to. Shortest description in the family (300 chars) and the only one with no NOT-for
  clause at all. Fix: exclusion clause naming browser-testing.
- FAIL (precision) → PASS (after fix) — "run the structured full-app QA before we close the
  batch". Same root cause: `E2E tests` reads as pipeline QA, whose destination is ac-qa-browser
  / ac-qa-device. Fix: the same clause names both.
- PASS — "the modal has a z-index bug" (routes to ui-debug — a visual defect, not a test)
- PASS — "run the pre-deployment security audit" (routes to audit, which names its own scope
  broadly and excludes the code-review siblings inline)
- PASS — "test my patience"

## browser-testing

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "validate the login flow on preview"
- PASS — "quick smoke test after this deploy"
- PASS — "check the browser behaves on production"
- PASS — "test this flow with the agent-browser CLI"
- PASS — "preview validation before I share the link"

should-NOT-activate

- PASS — "run the full web QA with QA_VALIDATION reporting" (routes to ac-qa-browser, named
  explicitly in its own NOT-for clause — the sharpest sibling, and it is excluded)
- PASS — "record the screen on the simulator" (routes to device-testing — native capture, not
  a browser check)
- PASS — "the flex layout breaks at 768px" (routes to ui-debug — a CSS defect, not a flow
  validation)
- PASS — "write a Playwright spec for this" (routes to testing — authoring a test file, not
  driving a browser ad hoc)
- PASS — "test the brakes on my car"

## device-testing

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "record the screen on the simulator"
- PASS — "drive the simulator through this flow"
- PASS — "capture a bug repro on device"
- PASS — "grab a screenshot on device for the demo"
- PASS — "record a marketing clip from the real app"

should-NOT-activate

- FAIL (precision) → PASS (after fix) — "grab the screenshots for the App Store listing". The
  triggers `screenshot the app` (native simulator capture) and `grab a screenshot on device`
  cover exactly how store assets are captured, and the NOT-for clause named ac-qa-device,
  browser-testing and screenshot-refresh — but NOT app-store-screenshots, the one sibling whose
  job is native captures. The asymmetry is the tell: app-store-screenshots excludes
  screenshot-refresh and device-testing excludes screenshot-refresh, so the trio's third edge
  was simply missing. Fix: add app-store-screenshots to the clause.
- PASS — "run the structured native QA gate" (routes to ac-qa-device, named inline)
- PASS — "refresh the landing page screenshots" (routes to screenshot-refresh, named inline)
- PASS — "check the login flow in the browser" (routes to browser-testing, named inline)
- PASS — "test the device driver on my printer"

## ui-debug

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "this CSS isn't applying"
- PASS — "the layout breaks on mobile"
- PASS — "z-index issue on the dropdown"
- PASS — "element is misaligned in Safari only"
- PASS — "overflow is clipping the tooltip"

should-NOT-activate

- FAIL (precision) → PASS (after fix) — "this screen looks off, make it feel premium". The
  description covers `unexpected visual behavior` and `element misaligned`, which reads as
  subjective polish; the destination is ac-ui-polish. The asymmetry is the tell: ui-brainstorm
  and web-design-guidelines BOTH name ac-ui-polish in their clauses, while ui-debug — the
  closest neighbor — carried no NOT-for clause at all. Fix: exclusion clause naming
  ac-ui-polish.
- FAIL (precision) → PASS (after fix) — "the visual regression test is failing in CI".
  `visual regression` is a LITERAL listed trigger, but a failing test routes to testing (author
  the spec) or ac-qa-browser (the gated run) — ui-debug fixes the defect, it does not own the
  harness. Fix: the same clause names testing / ac-qa-browser.
- PASS — "is this form accessible" (routes to web-design-guidelines — objective compliance, not
  a rendering defect)
- PASS — "tab switching feels slow on native" (routes to capacitor — React/lifecycle
  performance, not CSS)
- PASS — "debug why my UI mockup looks bad in Figma"

## audit

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).
**Prediction refuted, recorded honestly:** the bead predicted `audit` would fail alongside
`testing` on the generic-verb profile. It does not — its NOT-for clause already names four
destinations and does the work. Only `testing` fit the predicted profile in this cluster.

should-activate

- PASS — "run the security audit"
- PASS — "pre-deployment audit"
- PASS — "vulnerability assessment on this service"
- PASS — "performance audit before we ship"
- PASS — "compliance review of this data flow"

should-NOT-activate

- PASS — "review this feature branch before merge" (routes to ac-review, named inline)
- PASS — "codebase health sweep between sessions" (routes to ac-hygiene, named inline)
- PASS — "is this form accessible" (routes to web-design-guidelines, named inline)
- PASS — "audit the skill registry for collisions" (routes to ac-registry-audit — `registry
  audit` is its literal trigger, and specificity beats the bare verb `audit` here)
- PASS — "audit my tax return"

## brainstorming

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).
Cluster 2 of 3 (creative / ideation).

should-activate

- PASS — "brainstorm"
- PASS — "explore ideas before I commit to an approach"
- PASS — "what are the options here"
- PASS — "I'm uncertain which approach to take"
- PASS — "weigh these competing visions"

should-NOT-activate

- FAIL (precision) → PASS (after fix) — "push this concept deeper, what am I missing". `think
  through approaches` is a literal listed trigger and the description is otherwise
  scope-generic, so it beats ac-idea-lab, which owns forensic critique and paradigm
  transcendence. The clause named only ui-brainstorm. Fix: add ac-idea-lab to the clause. (The
  reciprocal already exists: ac-idea-lab was given a brainstorming exclusion in batch B6.)
- PASS — "multiple models' opinions on this screen" (routes to ui-brainstorm, named inline)
- PASS — "poll several models on this decision" (routes to expert-consensus — brainstorming is
  a single-track divergent-convergent pass, no multi-model surface)
- PASS — "create the plan now" (routes to ac-plan-init — brainstorming is explicitly
  pre-planning)
- PASS — "brainstorm baby names"

## ui-brainstorm

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "ui brainstorm"
- PASS — "give me several design options for this screen"
- PASS — "what would different models suggest for this layout"
- PASS — "explore alternatives for the onboarding UI"
- PASS — "cross-model consensus on this design"

should-NOT-activate

- PASS — "polish this screen" (routes to ac-ui-polish, named inline)
- PASS — "is this accessible" (routes to web-design-guidelines, named inline)
- PASS — "the dropdown renders behind the header" (routes to ui-debug, named inline)
- PASS — "poll several models on this architecture decision" (routes to expert-consensus — the
  description's `on a UI` scoping is what keeps the non-UI case out, and it holds)
- PASS — "brainstorm the product name" (routes to brainstorming — non-UI ideation)

## expert-consensus

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "ask the experts"
- PASS — "model consensus on this"
- PASS — "what do other models think"
- PASS — "get a second opinion from other AIs"
- PASS — "panel of AI models on this decision"

should-NOT-activate

- FAIL (precision) → PASS (after fix) — "get multiple models' opinions on this screen design".
  `multiple AI models to weigh in` and `poll multiple models` are the strongest phrases in the
  description and carry no UI exclusion, so it beats ui-brainstorm — which does scope itself to
  UI, but only from its own side. No NOT-for clause existed. Fix: exclusion clause naming
  ui-brainstorm.
- FAIL (precision) → PASS (after fix) — "stress-test this idea". The description literally
  contained `stress-testing an idea`, which is ac-idea-lab's literal trigger — a phrase collision
  in the description text itself, not merely an adjacent domain. Fix: the colliding phrase was
  REMOVED from the description outright (an exclusion clause alone would have left the magnet in
  place) and the same clause names ac-idea-lab.
- PASS — "run this one prompt on Gemini" (routes to openrouter — single non-default model, not
  a synthesized panel)
- PASS — "review this branch with the 6-lens panel" (routes to ac-review — a review panel of
  lenses, not of models)
- PASS — "find me an expert consultant to hire"

## app-store-screenshots

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "app store screenshots"
- PASS — "generate the store listing images"
- PASS — "build the App Store Connect assets"
- PASS — "marketing screenshots for the Play Store listing"
- PASS — "screenshot generator for the store listing"

should-NOT-activate

- PASS — "refresh the landing page screenshots" (routes to screenshot-refresh, named inline)
- PASS — "record the simulator for a bug repro" (routes to device-testing — the store-listing
  scoping in every trigger is what keeps ad-hoc native capture out, and it holds)
- PASS — "polish the landing page hero" (routes to ac-site-polish)
- PASS — "add Open Graph images to the marketing site" (routes to seo-metadata — social preview
  assets, not store listings)
- PASS — "take a screenshot of my desktop"

## screenshot-refresh

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).
The strongest clause of the screenshot trio — it excludes BOTH siblings, which is why the only
missing edge in this trio was on device-testing's side.

should-activate

- PASS — "refresh screenshots"
- PASS — "the landing page images are stale"
- PASS — "recapture the marketing site screenshots"
- PASS — "update the screenshots on the website"
- PASS — "screenshot the app for the landing page"

should-NOT-activate

- PASS — "grab a screenshot on the simulator" (routes to device-testing, named inline)
- PASS — "build the App Store listing assets" (routes to app-store-screenshots, named inline)
- PASS — "check the landing page renders on preview" (routes to browser-testing — validation,
  not capture)
- PASS — "add meta tags to the landing page" (routes to seo-metadata)
- PASS — "refresh my screensaver"

## seo-metadata

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).
Cluster 3 of 3 (publishing / content).

should-activate

- PASS — "add Open Graph tags to this page"
- PASS — "audit our meta descriptions"
- PASS — "the sitemap needs regenerating"
- PASS — "add JSON-LD structured data"
- PASS — "set canonical URLs across the marketing site"

should-NOT-activate

- PASS — "Core Web Vitals are bad on this page" (routes to capacitor and web-design-guidelines,
  both named inline)
- PASS — "is this page accessible" (routes to web-design-guidelines — objective compliance, not
  discoverability metadata)
- PASS — "polish the landing page visually" (routes to ac-site-polish — the trigger list is
  entirely metadata-specific, so visual phrasings do not reach it)
- PASS — "recapture the landing page screenshots" (routes to screenshot-refresh)
- PASS — "improve my search ranking on Google Ads"

## web-design-guidelines

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "is this accessible"
- PASS — "a11y check on this component"
- PASS — "audit this form"
- PASS — "does this meet WCAG"
- PASS — "review this UI code for best practices"

should-NOT-activate

- PASS — "make this feel premium" (routes to ac-ui-polish, named inline)
- PASS — "tab switching is slow on native" (routes to capacitor, named inline)
- PASS — "give me several design options" (routes to ui-brainstorm, named inline)
- PASS — "run the pre-deployment UI/UX sweep" (routes to audit, which reciprocally names
  web-design-guidelines for the single-check case — the pair is symmetric)
- PASS — "what are the design guidelines for my living room"

## jef-flywheel

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "flywheel"
- PASS — "set up agent swarm with ntm"
- PASS — "how does the agentic build methodology work end to end"
- PASS — "br/bv setup for a new repo"
- PASS — "AGENTS.md conventions for this project"

should-NOT-activate

- FAIL (precision) → PASS (after fix) — "two agents are about to edit the same file, coordinate
  them". `coordinating multi-agent work` and `agent coordination` are listed triggers, but the
  actual mechanism — identity, file reservations, the pre-commit guard — is agent-mail's.
  jef-flywheel is the conceptual/setup layer and its routing tail named only ac-beadify and the
  ac-* stages. Fix: extend the tail to name agent-mail (and beads-standards for bead canon).
- PASS — "convert this plan into beads" (routes to ac-beadify, named inline)
- PASS — "run a pipeline stage" (routes to the ac-* stage skills, named inline)
- PASS — "which label does this bead need" (routes to beads-standards — now named in the fix
  clause for the same `beads (br/bv)` surface)
- PASS — "how does a flywheel work in an engine"

## jef-prompts

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "give me a prompt for bug hunting"
- PASS — "is there a prompt for refactoring"
- PASS — "find a prompt for planning"
- PASS — "/jef-prompts performance"
- PASS — "show me the jef pack"

should-NOT-activate

- FAIL (precision) → PASS (after fix) — "score and improve the subagent prompts in this skill".
  The description is a prompt LIBRARY, but `performance audit prompt` and `find a prompt` give
  it enough prompt-quality surface to beat prompt-enhance, which owns rubric scoring of prompts
  already written. No NOT-for clause existed. Fix: exclusion clause naming prompt-enhance.
- PASS — "create a new skill" (routes to skill-builder — authoring an artifact, not retrieving
  a canned prompt)
- PASS — "what's the planning methodology" (routes to planning — the method, not a prompt for
  it)
- PASS — "run the pre-deployment audit" (routes to audit — doing the audit, not fetching the
  prompt that describes one)
- PASS — "prompt me before overwriting files"

## wiki

Verdicts are a lower bound (self-judged with the full registry in context — § Method verdict).

should-activate

- PASS — "write this up as a wiki page"
- PASS — "seed a concept page"
- PASS — "garden the wiki"
- PASS — "dedupe the wiki"
- PASS — "build a contradiction page from these facts"

should-NOT-activate

- FAIL (precision) → PASS (after fix) — "synthesize this week's lessons". `weekly distillation`
  is a LITERAL listed trigger and the description leads with `synthesis`, which collides head-on
  with dream — the skill that actually runs weekly cross-session synthesis. The clause named
  context-engineering and reflect but not dream, even though dream is the closest phrase match.
  Fix: add dream to the clause.
- PASS — "save this one decision somewhere durable" (routes to context-engineering, named
  inline)
- PASS — "capture what we learned this session" (routes to reflect, named inline)
- PASS — "where should this knowledge live" (routes to context-engineering — the routing
  question, not the derived view)
- PASS — "edit the Wikipedia article"

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
| ac-backlog | "capture this bug I just hit" selected it | precision | exclusion clause added naming ac-bead-capture (typed bead now) and ac-beadify (whole plan) |
| ac-triage | "triage the open beads and tell me what to work on" selected it | precision | NOT-for clause added naming bv / ac-bead-refine for board triage |
| ac-bead-capture | — | — | none needed |
| ac-bead-refine | — | — | none needed |
| ac-beadify | — | — | none needed |
| ac-tidy | — | — | none needed |
| ac-distribute | "ship it to production" selected it | precision | reciprocal clause added naming ac-publish as the production release gate that calls it |
| ac-publish | — | — | none needed |
| ac-site-polish | — | — | none needed |
| ac-ui-polish | — | — | none needed |
| ac-align | "what should I work on next" and "stress-test my strategy" selected it | precision | NOT-for clause naming ac-dashboard / ac-human-session, ac-idea-lab / strategist, ac-tidy |
| ac-human-session | "unblock this failing build" selected it | precision | "unblock" scoped to human gates; clause naming debug, ac-dashboard, ac-implement / ac-loop |
| ac-hygiene | "review this feature branch" and "audit the auth module" selected it | precision | NOT-for clause naming ac-review, audit, ac-registry-audit, ac-tidy |
| ac-idea-lab | "brainstorm twenty new product ideas" selected it | precision | tail extended to name brainstorming and expert-consensus |
| ac-pipeline | "run validate-qa-run" selected it | precision | NOT-for widened to exclude RUNNING anything it documents, hosted scripts included |
| ac-prove | "run the full test suite" selected it | precision | NOT-for clause naming testing and ac-dashboard |
| ac-dashboard | — | — | none needed |
| ac-registry-audit | — | — | none needed |
| agent-mail | "how do I commit safely in the shared checkout" selected it | precision | clause naming ac-pipeline (commit-discipline, delegation-contract) and ac-distribute |
| beads-standards | "refine these beads" and "file a bead for this crash" selected it | precision | STANDARD-not-executor clause naming ac-bead-refine, ac-bead-capture, ac-beadify |
| capacitor | "write a test for this" and "write the migration" selected it | precision | clause naming testing, supabase, ui-debug, web-design-guidelines |
| context-engineering | its exclusion routed to `librarian`, a skill that does not exist | stale | phantom destination dropped, dream added, file organization stated behaviorally |
| openrouter | "get several models to weigh in and rank the answers" selected it | precision | clause naming expert-consensus, ui-brainstorm, claude-api |
| prompt-enhance | bare "rate this prompt" on a one-off user prompt selected it | precision | scoped to skill/command FILES; clause naming skill-builder and ac-registry-audit |
| reflect | "where should this decision live" selected it | precision | context-engineering added to a clause that named only ac-land and dream |
| skill-builder | "build a /command" and "audit the registry" selected it | precision | clause naming workflow-builder, ac-registry-audit, prompt-enhance |
| supabase | its exclusion routed to `design-system`, a skill that does not exist | stale | repointed at web-design-guidelines and ac-ui-polish |
| dream | — | — | none needed |
| planning | — | — | none needed |
| workflow-builder | — | — | none needed |
| testing | "test the login flow in the browser" and "run the full-app QA" selected it | precision | clause naming browser-testing, device-testing, ac-qa-browser / ac-qa-device, audit |
| device-testing | "grab the screenshots for the App Store listing" selected it | precision | app-store-screenshots added — the screenshot trio's one missing edge |
| ui-debug | "make it feel premium" and "the visual-regression test is failing" selected it | precision | clause naming ac-ui-polish, testing / ac-qa-browser, web-design-guidelines, capacitor |
| brainstorming | "push this concept deeper, what am I missing" selected it | precision | ac-idea-lab and expert-consensus added to a clause that named only ui-brainstorm |
| expert-consensus | multi-model UI opinions, and "stress-test this idea" selected it | precision | the colliding phrase "stress-testing an idea" removed from the description, plus a clause naming ui-brainstorm, ac-idea-lab, openrouter |
| jef-flywheel | "coordinate two agents on the same file" selected it | precision | routing tail extended to name agent-mail and beads-standards |
| jef-prompts | "score and improve the subagent prompts in this skill" selected it | precision | RETRIEVES-only scoping plus a clause naming prompt-enhance and skill-builder |
| wiki | "synthesize this week's lessons" selected it | precision | dream added to a clause that named only context-engineering and reflect |
| audit | — | — | none needed (the B8 prediction that it would fail was refuted) |
| app-store-screenshots | — | — | none needed |
| browser-testing | — | — | none needed |
| screenshot-refresh | — | — | none needed |
| seo-metadata | — | — | none needed |
| ui-brainstorm | — | — | none needed |
| web-design-guidelines | — | — | none needed |

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

B4 score: 60 judgments, 2 failures (both precision), across 2 of the 6 bead-lifecycle skills.
Both re-judged PASS after the description edit. Three batches in, the predictor is now
unambiguous and has not missed once: **the skill in a family that carries no NOT-for clause is
the skill that fails.** ac-backlog and ac-triage were the only two of these six without one;
ac-bead-capture, ac-bead-refine, ac-beadify and ac-tidy all carry sibling cross-references and
all passed clean. Same result in B2 (ac-plan-refine-external) and B3 (the one unqualified
trigger in ac-qa-browser). Treat "has no exclusion clause" as the batch-scan heuristic.

B5 score: 40 judgments, 1 failure (precision), across 1 of the 4 polish/publish skills.
Re-judged PASS after the description edit. The predictor held a fourth time and, usefully,
predicted the NON-failures too: ac-site-polish and ac-ui-polish carry the registry's richest
NOT-for clauses (5 and 5 named alternatives) and passed all 20 judgments clean despite being
the batch's highest-overlap pair at 210 shared shingles — so the refine-flagged hard
constraint on ac-site-polish's 1018-char description never bound. The one failure,
ac-distribute vs ac-publish, is also the most consequential found across B2–B5: routing "ship
it to production" to ac-distribute skips the version bump, the full-suite proof, the heavy
review and the tag.

B6 score: 80 judgments, 8 failures (all precision), across 6 of the 8 remaining `ac-*` skills.
All re-judged PASS after the description edit. The predictor held a fifth time and cleanly: the
four skills carrying NO NOT-for clause (ac-align, ac-human-session, ac-hygiene, ac-prove) all
failed, and the two with the richest clauses (ac-dashboard's routing tail, ac-registry-audit's
four-destination exclusion) passed all 20 judgments clean. ac-pipeline, the canon-holder, failed
in a new way worth naming: its description ENUMERATES the scripts it hosts, which reads to a
router as a capability rather than an inventory, so "run validate-qa-run" selected the doc
instead of the calling ceremony.

B7 score: 120 judgments, 12 failures (10 precision, 2 stale), across 9 of the 12 agent-system +
build-platform skills. All re-judged PASS after the description edit. **This batch introduced a
second failure class the predictor does not catch: STALE destinations.** context-engineering
excluded to `librarian` and supabase excluded to `design-system` — neither skill exists in
agent-compounds/skills or the root agent home (the root registry is a symlink into this one), so
both clauses were decorative and could not route. A skill can carry a well-formed NOT-for clause
and still fail. Add "does every named destination resolve to a live SKILL.md" to the batch scan;
the no-clause heuristic alone would have passed both.

B8 score: 150 judgments, 11 failures (all precision), across 8 of the 15 testing/creative/
publishing skills. All re-judged PASS after the description edit. The predictor held on
`testing` — no clause, bare verbs, and the shortest description in the registry at 300 chars —
but was REFUTED on `audit`, which the bead predicted would fail on the same profile and which
passed all 20 judgments on the strength of a four-destination clause it already carried. The
richest finding is structural: three of the eight failures were MISSING RECIPROCAL EDGES in
otherwise well-clued families (device-testing excluded two of the screenshot trio but not
app-store-screenshots; ui-debug was the only member of the UI quartet with no clause at all;
reflect named two of its three memory siblings). Asymmetry inside a family is a stronger
predictor than clause-absence once most skills carry clauses.

**Registry-wide budget finding (B8, cross-batch — the epic's method did not model it).** Check
13 has TWO limits: a per-skill 1024-char cap, which every batch bead measured, and a
registry-wide ~30,000-char listing budget across all model-invocable descriptions, which none of
them did. Adding exclusion clauses to 35 skills across B6-B8 pushed the registry to 31,033 and
turned Check 13 RED — the aggregate, not any single description, was the binding constraint. B8
resolved it inside its own family per the beads' net-neutral instruction: all 15 descriptions
were tightened (elaborative prose and parentheticals cut, every trigger token and every named
destination preserved), taking the family from 7,268 to 7,040 chars — net **-228** while ADDING
eight exclusion clauses. Registry closed at 29,618/30,000. Anyone extending this corpus must
budget at the registry level first: roughly 380 chars of headroom remain, so further clauses have
to be paid for by tightening, not by growth.

Running total, B1–B8: 580 judgments, 41 failures (38 precision, 1 recall, 2 stale) across all 58
non-conductor-excluded registry skills. The corpus now covers the complete registry.

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
