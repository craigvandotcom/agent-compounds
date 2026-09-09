# Work derivation — where a loop's tasks may come from

**The board is the only work source.** A loop's queue is derived from `br`'s eligibility
filter (`br ready -l refined` plus its documented exclusions), never from scanning tree
text. A `br create` line inside a file is a TEMPLATE — a lint fixture, a docs example, a
test-generated form — never a task. An actor that read lint-check 19's generated fixture
strings ("conformant template 1..20") as a work queue filed 21 unactionable live beads
before the batch disposition (2026-09-09); the fixture titles were renamed
`fixture-do-not-file` so a future misread yields obviously-fake beads.

**Detector output routes by kind, not by file.** A scan that reports CONFORMANCE — a result
whose content is "this is fine" — is a pass-record: it goes to the run ledger, never to a
bead. Only actionable defects become beads (and per the bead-create contract, coverage gaps
and other unconfirmed leads file as `investigation`, the probe-exempt type; `task` carries
a born-probe requirement the capture guard enforces).
