# FRICTIONS — ac-beadify

Fixes are proposed here and applied to the skill only after the pattern recurs or the impact is H.

## decision-card-on-queryable-fact
- skills: [ac-beadify]
- impact: H
- frequency: once
- perceptibility: loud
- recurrence: 1
- related: []
- first_seen: 2026-09-05
- last_seen: 2026-09-05
- stage: manual
- status: open
- proposed_fix: one rule in SKILL.md § Procedure step 2: "Before writing a DECISION bead, list
  the facts its options turn on. If any fact is queryable now (a role attribute, a policy body,
  a grant, a config value, a grep), query it and re-read the fork. A fork that a query settles
  is a research gap, not a human gate — fold the answer into the plan or the consuming bead."
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
