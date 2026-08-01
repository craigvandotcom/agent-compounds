# Anti-Pattern Lenses — evidence destruction, coordinated workaround, unproven seam

Shared by `ac-review` (correctness + architecture reviewers) and `ac-hygiene`
(bug-hunter + structural lenses). Method only — zero app facts. Reference it as
`ac-pipeline-builder/references/anti-patterns.md`.

> Origin: BCA App Store 2.1(b) post-mortem — four rejections, ~10 days, five
> silent layers, all green under static checks (full narrative: BCA
> `_strategy/app-store-resubmit-v1.2.0-iap-blocker.md` §13). The pipeline's gates
> measure proxies (types, unit tests vs mocks, bundle contents, lint); a critical
> flow can be dead under all of them. These three hunts target the failure
> **mode**, not a specific bug — they compose with each reviewer's normal
> evidence-with-file:line discipline, they don't replace it.

---

## 1. Evidence destruction

**Pattern:** an empty/blanket `catch` or an unbounded `await` on a
non-peripheral journey's code path — an error the system swallows instead of
surfacing.

**Why it's dangerous:** five `catch {}`s made five distinct defects present as
one symptom in the BCA chain. Each layer's failure was individually invisible,
so nothing forced the chain to be diagnosed until the fourth rejection.

**On hit:** demand a stated justification for the swallow — what specific,
expected condition is being suppressed, and why silence is correct here. No
justification → the catch must surface, timeout, or log. Treat as Critical/High,
not a style nit.

## 2. Coordinated workaround

**Pattern:** one error silenced by evasions duplicated across ≥2
config/toolchain layers — e.g. a `package.json` exclusion + a bundler directive
+ a `tsconfig` path alias all pointing at the same suppressed problem.

**Why it's dangerous:** the package.json + bundler directive + tsconfig alias
triple-evasion was the March signature. When the same symptom needs silencing
in more than one layer, the toolchain is telling you the design is wrong — not
that the symptom is minor enough to route around three times.

**On hit:** escalate to a human — never auto-fix by adding a third evasion.
File as `DESIGN_DECISION` / `SCOPE_ESCALATION` (ac-review Phase 7 / ac-hygiene
Phase 5 categories), never as an auto-fixable finding.

## 3. Unproven seam

**Pattern:** the diff crosses a bridge — native plugin boundary, external
service call, build-time↔runtime divide — and no un-mocked test touches that
seam.

**Why it's dangerous:** mocks verify our logic; the bugs live at the boundary
the mock removed. A green suite over a fully-mocked seam proves nothing about
the seam itself.

**On hit:** require an un-mocked test or a journey drive (per
`_shared/verification-gate.md` / `_shared/qa-shared.md`) that actually
exercises the seam before the surface counts as proven. No such proof in the
diff → file it as a finding, not a nit.

---

## Where these apply

- **ac-review:** correctness + architecture reviewers hunt all three alongside
  their existing checklist (`references/review-dimensions.md`).
- **ac-hygiene:** bug-hunter + structural lenses hunt all three alongside their
  existing method (`references/reviewers.md`).

Not a replacement checklist — an addition on top. These three look for the
failure mode (silencing, evasion, unproven boundary); everything else about how
a finding gets reported (evidence, severity, auto-fixable) stays exactly as each
reviewer already does it.
