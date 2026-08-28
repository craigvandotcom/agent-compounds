# code-checklist — the question set ac2-polish runs over a code scope

The loop that runs this (fresh reader per round, severity gating, fixpoint at zero changes)
belongs to `ac2-polish/SKILL.md`. This file is only the questions.
**Routine bound-exhaustion or cycling indicts THIS FILE, not the code.**

## Every question names its oracle

A question this file cannot answer with a COMMAND does not belong in this file. Two fresh
readers agree on what `ubs` printed; they do not agree on what reads better, and a loop built
on the second kind never converges — it cycles, each reader improving the last one's work.

- State the command, run it, and report its exit code and output.
- A finding cites the oracle that failed. No oracle, no finding.
- Taste, naming, structure and "this could be cleaner" are OUT OF SCOPE here. Route them to a
  human reviewer or a bead. A round that reports them is a round that did not read for defects.

**SEVERITY GATE for code — vulnerability · defect · contract violation.** A vulnerability is
exploitable, a defect makes the code do the wrong thing, a contract violation breaks a promise
the code itself states (a type, a documented invariant, a test's premise).

## 1. scope integrity

- Did every edit land inside the declared scope? `git diff --name-only <base>` returns nothing
  outside it. An edit outside scope is a finding regardless of merit.
- Is the scope self-contained — does anything outside it read a symbol this round changed?
  Name the grep that derived the caller set.

## 2. the tree is green

- Do the tests pass? Run the suite. A red tree is the only finding that matters this round;
  report it and stop reading.
- Does the scope have tests AT ALL? A scope with no test file passes "tests green"
  vacuously and can reach fixpoint asserting nothing. Name the test file that should
  exist; its absence is a finding.
- Is every BRANCH in scope covered? Run the repo's coverage command over the scope and
  report the per-file numbers against its configured thresholds. An uncovered branch is
  an untested behaviour: name it, at file:line.
- Does it build and typecheck? Run the build. A green suite over a tree that does not compile
  proves nothing.
- Does `ubs <changed-files>` exit 0 AND report `Files scanned` equal to the count you passed?
  A shortfall is NOT-GATED, not a pass — ubs silently drops file types it does not cover.

## 3. untrusted input

- For every value that crosses a trust boundary — request body, query param, header, env,
  file, third-party response — is it validated before use? Name the validator and the line.
- Is any of it interpolated into SQL, a shell command, a path, or HTML? Show the parameterised
  form, or the escape, or it is a finding.
- Does a validation failure fail CLOSED? Run the failure path and report the exit or status.

## 4. authorization and exposure

- Does every data read and write check the caller's right to it, at the point of access rather
  than in a caller that could be bypassed? Name the check.
- Does any response, log line, or error message carry a secret, a token, another user's data,
  or an internal path? Grep the response shape and the log calls.
- Are row-level policies relied on, and does a test prove one denies? A policy nobody proved
  denying is a policy nobody proved.

## 5. secrets

- Does the diff introduce a literal credential, key, or token? Run the repo's secret scan.
- Is any secret read from source rather than the environment? Name the read.

## 6. error paths

- Does every failure path do something other than swallow? An empty `catch`, a bare
  `except: pass`, an ignored error return, a promise with no rejection handler — each is a
  finding, cited at file:line.
- Does an error fail CLOSED where it gates access, a write, or a check? Force the failure and
  report what happened. Fail-open is a defect even when nothing is observed to break.
- Is a partial write left behind when a multi-step operation fails halfway? Name the step that
  cleans up, or it is a finding.

## 7. state and concurrency

- Does anything read-then-write shared state without atomicity? Name the guard, the
  transaction, or the constraint that makes the race impossible.
- Is an in-process guard — a cache, a rate limit, a "seen" set — relied on for correctness
  across processes or across cold starts? It resets; that is a defect, not a risk.

## 8. contract violation

- Does the code do what its own types, its docs, and its tests' premises say it does? Cite the
  contract and the line that breaks it.
- Does any test assert a behaviour the code no longer has, or pass without exercising the path
  it names? Run it, and run it with the path removed — a test that passes both ways is a
  finding.
