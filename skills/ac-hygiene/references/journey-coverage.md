# Journey-coverage filing — the deterministic lane

This check is deterministic, not a judgment call, so it skips the round/consensus
machinery and files directly. `CORE/journeys/` absent for the app → skip, nothing
to audit. This same derivation is the starting point for the initial all-apps
journey-tagging sweep; audit and sweep share one inventory method so tags come from
ground truth, never memory.

## File only actionable defects

A finding that reports CONFORMANCE — a scan whose result is "this is fine" (a
conformant template, a passing check) — is a pass-record: it goes to the run
ledger line, never to a bead. Filing a pass as a bead manufactured 21
unactionable board entries before the batch disposition (2026-09-09); this flow's
output is findings, not attestations.

## The filing shape

Coverage gaps are UNCONFIRMED LEADS: they file as `investigation` — the
probe-exempt type — never as `task`, which the bead-capture-guard refuses without
a born probe:

    br create -t investigation \
      --labels origin:ac-hygiene,hygiene-finding,journey-gap,unrefined,impact:<class> \
      -d "Coverage audit: <surface> has no journey-registry entry (or is
      under-tagged) — untagged critical surfaces are unprotected by the
      runtime-proof gates."
