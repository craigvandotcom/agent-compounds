---
name: flight-check-check-only-executes-probes
description: `flight-check.sh --check-only` writes nothing but still EXECUTES every AC probe — a board sweep with it runs whatever the probes do (resets, builds, servers)
metadata:
  type: fact
  domain: org
  evidence: 2026-09-27 bead audit — a read-only baseline sweep of an app board ran a package script that resets the local database and several Playwright specs (build + production server) via --check-only
  tags: [flight-check, probes, audit, safety]
---

`--check-only` means "no routing comment, no retitle, no receipt" — it does not mean "no side
effects". The CONSUMES/ENVIRONMENT/RED legs run each probe to find a red one, so the probes'
own effects happen. Before sweeping a board with it, read every probe and exclude destructive or
heavy ones: database resets (including package scripts that wrap one under a harmless name —
check what `db:*` scripts actually run), e2e/Playwright (a webServer builds and starts the app),
deploys, anything writing outside the tree. A stamp-time check that refuses destructive probe
shapes keeps them from reaching claim.
