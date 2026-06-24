// dedup-drift-audit.js — the semantic registry-audit engine for /ac-registry-audit.
//
// Read-only. Maps every skill, then runs three analyzers (trigger collisions,
// dangling cross-refs, divergent duplicates) over the full map, then
// adversarially verifies each finding so only real drift survives.
//
// HOW TO RUN (conductor):
//   1. Set ROOT below to the registry root (the dir whose `skills/` you audit).
//   2. Populate SKILLS with the deployable skill names — discover them with:
//        ls -d skills/*/ | sed 's|skills/||;s|/||' | grep -v '^_'
//      INLINE the list here. Do NOT rely on the Workflow `args` parameter — it
//      has been observed arriving undefined in background runs (see the
//      `workflow-tool-args-propagation` global memory fact); inlining is the
//      reliable path.
//   3. Run: Workflow({scriptPath: "<this file>"}). Iterate by editing + re-running.

export const meta = {
  name: 'registry-dedup-drift-audit',
  description: 'Read-only registry audit: trigger collisions, dangling refs, divergent duplicates across all skills',
  phases: [
    { title: 'Map', detail: 'readers extract purpose/triggers/refs per skill' },
    { title: 'Analyze', detail: 'collisions + dangling-refs + duplicates over the full map' },
    { title: 'Verify', detail: 'adversarially verify each finding is real drift, not intentional design' },
  ],
}

// ---- CONDUCTOR: set these two before running ----
const ROOT = '/Users/craigvanheerden/Repos/neometa/software/agent-compounds'
const SKILLS = [/* inline `ls -d skills/*/ | sed 's|skills/||;s|/||' | grep -v '^_'` output here */]
// --------------------------------------------------

if (!SKILLS.length) throw new Error('SKILLS is empty — inline the skill-name list before running (see header).')
const CANON = SKILLS.join(', ')

// chunk skills for the map phase
const CHUNK = 6
const chunks = []
for (let i = 0; i < SKILLS.length; i += CHUNK) chunks.push(SKILLS.slice(i, i + CHUNK))

const CARD_SCHEMA = {
  type: 'object',
  properties: {
    cards: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          purpose: { type: 'string', description: 'one-line what-it-does' },
          triggers: { type: 'array', items: { type: 'string' }, description: 'distinctive trigger keywords/phrases from frontmatter' },
          skillRefs: { type: 'array', items: { type: 'string' }, description: 'OTHER skill names this skill points to (routing/cross-refs)' },
          claimsCanonicalOver: { type: 'string', description: 'the domain this skill claims to be THE canonical authority for, if any; else empty' },
        },
        required: ['name', 'purpose', 'triggers', 'skillRefs', 'claimsCanonicalOver'],
      },
    },
  },
  required: ['cards'],
}

phase('Map')
const mapped = await parallel(chunks.map((chunk, i) => () =>
  agent(
    `You are auditing the skill registry at ${ROOT}.
For EACH of these skills, read ${ROOT}/skills/<name>/SKILL.md (frontmatter description + skim body) and list its references/ dir:
${chunk.join(', ')}

Return one card per skill: name; purpose (one line); triggers (the distinctive trigger keywords from the frontmatter description — not generic words); skillRefs (names of OTHER skills it explicitly routes to or cross-references, e.g. "use X instead"); claimsCanonicalOver (the domain it declares itself THE authority for, e.g. "session-end learning capture", or empty string if it doesn't claim exclusivity).
Be precise and factual. Do not invent refs.`,
    { label: `map:${i}`, phase: 'Map', agentType: 'Explore', schema: CARD_SCHEMA }
  )
))

const allCards = mapped.filter(Boolean).flatMap(r => r.cards)
log(`Mapped ${allCards.length} skills`)
const cardsJSON = JSON.stringify(allCards, null, 1)

const FINDINGS_SCHEMA = {
  type: 'object',
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          kind: { type: 'string', enum: ['collision', 'dangling-ref', 'divergent-duplicate'] },
          skills: { type: 'array', items: { type: 'string' } },
          detail: { type: 'string' },
          severity: { type: 'string', enum: ['high', 'medium', 'low'] },
        },
        required: ['kind', 'skills', 'detail', 'severity'],
      },
    },
  },
  required: ['findings'],
}

phase('Analyze')
const ANALYZERS = [
  {
    key: 'collisions',
    prompt: `Canonical skill list (these all EXIST):\n${CANON}\n\nSkill cards:\n${cardsJSON}\n\nFind TRIGGER COLLISIONS: pairs/sets of skills whose trigger surfaces overlap enough that an agent picking by description alone would route ambiguously. Only report genuine ambiguity a user would hit — NOT deliberately-paired skills that explicitly cross-reference each other with a clear "use X for A, Y for B" boundary (that is good design, not a collision). For each, name the skills and explain the ambiguous overlap. kind="collision".`,
  },
  {
    key: 'dangling',
    prompt: `Canonical skill list (these are the ONLY skills that EXIST):\n${CANON}\n\nSkill cards:\n${cardsJSON}\n\nFind DANGLING REFERENCES: any skillRef that names a skill NOT in the canonical list above (it routes agents to a non-existent skill). For each, list which skills reference it. Ignore deliberately per-app skills that aren't in this shared registry (e.g. design-system, writing-guidelines, curate, brand-system, CORE) — those legitimately live per-app. kind="dangling-ref".`,
  },
  {
    key: 'duplicates',
    prompt: `Canonical skill list:\n${CANON}\n\nSkill cards:\n${cardsJSON}\n\nFind DIVERGENT DUPLICATES: two or more skills that claim canonical authority over the SAME domain (overlapping claimsCanonicalOver) and would compete — the dangerous case being two things both presenting as "the" canonical method that have drifted apart. Distinguish from legitimate scoped-pairs (e.g. feature-scoped vs codebase-wide review is fine). Read the actual SKILL.md files at ${ROOT}/skills/ when needed to confirm. kind="divergent-duplicate".`,
  },
]

const analysis = await parallel(ANALYZERS.map(a => () =>
  agent(a.prompt, { label: `analyze:${a.key}`, phase: 'Analyze', schema: FINDINGS_SCHEMA })
))
const rawFindings = analysis.filter(Boolean).flatMap(r => r.findings)
log(`${rawFindings.length} raw findings`)

const VERDICT_SCHEMA = {
  type: 'object',
  properties: {
    real: { type: 'boolean', description: 'true if genuine drift worth fixing; false if intentional design or false positive' },
    reasoning: { type: 'string' },
    recommendation: { type: 'string', description: 'concrete fix if real, or why-to-leave-it if not' },
    needsHumanDecision: { type: 'boolean', description: 'true if the fix is a judgment call, not a mechanical edit' },
  },
  required: ['real', 'reasoning', 'recommendation', 'needsHumanDecision'],
}

phase('Verify')
const verified = await parallel(rawFindings.map((f, i) => () =>
  agent(
    `Adversarially verify this registry-audit finding. Default to real=false unless the evidence in the actual files supports it. Read the relevant SKILL.md files at ${ROOT}/skills/.

Finding (${f.kind}, severity ${f.severity}): skills=[${f.skills.join(', ')}]
${f.detail}

Is this a REAL problem worth fixing, or intentional design / false positive? Give a concrete recommendation. Mark needsHumanDecision=true if fixing it is a judgment call (e.g. restore a skill vs re-route) rather than a mechanical edit.`,
    { label: `verify:${f.kind}:${i}`, phase: 'Verify', agentType: 'validator', schema: VERDICT_SCHEMA }
  ).then(v => ({ ...f, verdict: v }))
))

const confirmed = verified.filter(Boolean).filter(f => f.verdict?.real)
return {
  totalRaw: rawFindings.length,
  confirmedCount: confirmed.length,
  confirmed: confirmed.map(f => ({
    kind: f.kind,
    severity: f.severity,
    skills: f.skills,
    detail: f.detail,
    recommendation: f.verdict.recommendation,
    needsHumanDecision: f.verdict.needsHumanDecision,
  })),
}
