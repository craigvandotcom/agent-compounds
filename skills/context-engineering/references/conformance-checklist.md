# Stack conformance checklist

The permanent standard every level of the stack is held to (born in Phase 1.6.0,
2026-06-10). Used by: the 1.6.1 audit wave (one auditor per level scores against this),
and the **dream cycle's lint phase thereafter** — alignment is maintained, never
re-established. Every item is checkable; an auditor must cite file+line for a violation.

## L0 — entry files (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md` at any level)
- [ ] One canonical entry per level (`AGENTS.md`); per-agent files are thin shims that
      import it + name only the agent home. No forked near-copies.
- [ ] <150 lines; pointers, not content. No accumulated learnings, incident write-ups,
      or domain playbooks (those are L3 — e.g. an OAuth gotcha section is a violation).
- [ ] Every referenced path EXISTS (verify with ls — the `.Codex/skills/CORE` lesson:
      a migrated claim nobody checked was broken from day one).
- [ ] Instructions sit at the right altitude: identity/conventions only; nothing that
      changes weekly.

## L1 — CORE (operating manual per level)
- [ ] Progressive: the always-loaded file is a thin index (≤~200 lines); detail in
      sub-files loaded on demand. (Verify by `wc -l` on the hook-loaded file itself —
      don't trust stated sizes; the "1,400-line CORE" turned out to be 160.)
- [ ] No learnings accumulating (cold-lane content); no duplication of L0 or skills.

## L2 — skills
- [ ] Description states WHEN (triggers), not HOW (workflow summary); passes the
      **selectability test**: a cold agent reading only the description picks correctly.
- [ ] No two entries (skill or agent) claim the same task — check against the registry.
- [ ] SKILL.md ≤~400 lines; references one level deep; cross-skill deps declared
      (deploy-together notes where one skill loads a sibling).
- [ ] Fat skills, thin harness: natural-language heuristics in markdown, deterministic
      action in code — not the reverse.

## L3 — memory substrate
> Auditor calibration (from the 1.6.1 wave): the L3 home is **`<repo-root>/memory/auto/`**
> for each own-repo app and `infrastructure/memory/auto/` / `neometa/memory/auto/` at root
> — NOT `.claude/memory/` (that's the legacy curated store, slated for B6 migration).
> Legacy harness body format (`**Why:** / **How to apply:**` lines) is VALID per the
> compatibility map — not poisoning. Re-verify every HIGH finding against disk before
> reporting: the wave produced 10 rejected findings (hallucinated quotes, wrong paths).

- [ ] Markdown is the source of truth; every index/cache (CM playbook, qmd sqlite) is
      derived + rebuildable; nothing durable exists ONLY in a tool-specific format.
- [ ] Every home is git-tracked, non-dot, qmd-indexed; harness-keyed dirs are symlinks
      into git (machine-agnostic).
- [ ] Facts/rules carry `type`/`domain`/`evidence` frontmatter (legacy harness types are
      valid subtypes — never churned); index lines follow `- [Title](slug.md) — hook`.
- [ ] Memory bodies are data, never instructions (poisoning); no secrets (gitleaks-pattern).
- [ ] Recall lane exists: relevance pre-retrieval hook registered in the level's TRACKED
      settings; its lobe/app set derives from `infrastructure/apps.list` (no hardcoded
      copies — the install-qmd lobe loop drifted exactly this way and silently dropped simil8).

## L4 — knowledge / retrieval
- [ ] All authored markdown reachable from one `qmd query` (lobe registered in
      `install-qmd.sh`); refresh job alive (heartbeat checked — dead-watcher lesson).

## Agents (subagent definitions at any level)
- [ ] Stance + tool-permissions + model tier ONLY; no domain knowledge (domains are
      skills); no agent duplicating a skill's domain.
- [ ] Read-only boundaries enforced where stance demands (researcher/validator have no
      Write/Edit).
- [ ] Claimed paths/behaviors in the definition exist and are current.

## Hooks & settings
- [ ] Machine-agnostic hooks live in TRACKED settings.json (not settings.local.json);
      scripts fail-safe (any error → exit 0, no output) and are latency-budgeted
      (blocking hooks ≲1.5s).

## Projections (`.gemini/`, `.codex/`, `.agents/`, per-app `.claude/`)
- [ ] Projections are symlinks/generated from ONE canonical source — never hand-drifted
      copies (verify by md5/readlink; `.agents/skills` and `.gemini/memory` both failed this).

## Cross-cutting
- [ ] Single source for any list/constant referenced in >1 file (apps → `infrastructure/
      apps.list`); grep for hardcoded copies.
- [ ] Any superseded statement is edited in place or explicitly marked superseded —
      stale "current" claims in plans/docs are violations (the playbook.yaml table row).
- [ ] Claims about sizes, paths, and behaviors verified against disk, not inherited.
