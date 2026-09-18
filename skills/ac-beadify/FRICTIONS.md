---
skill: ac-beadify
created: 2026-09-05
last_pass: never
---

# FRICTIONS — ac-beadify

Fixes are proposed here and applied to the skill only after the pattern recurs or the impact is H.

## decision-card-on-queryable-fact
- skills: [ac-beadify]
- impact: L
- frequency: rare
- perceptibility: loud
- recurrence: 1
- related: []
- first_seen: 2026-09-05
- last_seen: 2026-09-05
- stage: manual
- status: resolved
- proposed_fix: LANDED 2026-09-09 (ac-wp8i.16): the query-first rule now lives in
  skills/ac-plan/references/decisions.md ("a fork a query settles is research done now, not a
  card", the escalation test), and ac-beadify step 2 routes an unsettled fork to a
  `needs-human` card on the plan — `beadify-refusal: needs-human` — never to a human gate.
- narrative: the compound-check epic (bd-epic-compound-check-n0lug) shipped one DECISION card,
  "which Postgres role does CURATE_POSTGRES_URL resolve to, and should the curator SET ROLE".
  Craig asked to settle it before bead polish and objected that the pipeline should not need a
  human here. Two read-only SQL queries and one grep settled it in minutes: the `postgres` role
  has BYPASSRLS and owns the tables, `service_role` bypasses RLS too (so option c was not a
  hardening), and every policy is keyed to auth.uid() (so option b, a dedicated role, would need
  USING (true) policies on ~8 tables — bypass with more files). The card was closed as option a
  with a connect-time BYPASSRLS sensor folded into bead .10. The seams trace had phrased the
  finding as "the curator bypasses every hardening migration"; the plan carried that phrasing
  into a Decision; beadify compiled it into a gate. Nobody ran the query. Cost: one human
  round-trip and a false human-gate label on a closed question. Same-run sibling: bead .8 named
  a GitHub secret for the golden key although all eleven workflows run on a self-hosted runner
  whose ~/actions-runner/.env can hold it — another fact a grep of `runs-on` would have given.
