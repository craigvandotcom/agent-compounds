#!/usr/bin/env node
// migrate-frictions-from-memory.mjs — one-time backfill of memory/auto/ friction facts
// into per-skill FRICTIONS.md (W4.4).
//
// Scans a memory dir (--memory-dir; location is NOT hardcoded, it differs per domain)
// for `kind: loop-retro-observation` facts, classifies each against the registry's real
// skill directories, and stages a migration into skills/<skill>/FRICTIONS.md (created
// lazily from the template in skills/skill-builder/references/friction-capture.md).
//
// SAFETY MODEL (read this before running with --apply):
//   - Default mode is DRY-RUN. Nothing is written. The tool prints a classification
//     report + a conservation summary, and writes a JSON manifest (--manifest-out) that
//     is the hand-off artifact for step 2.
//   - The actual same-vs-new dedup judgment (friction-capture.md's W4.2 rule) is an AGENT
//     judgment, not a string match. This tool does NOT perform that judgment. It does
//     three mechanical things instead:
//       1. finds candidate friction facts (kind: loop-retro-observation),
//       2. proposes a target skill (exact tag/stage match against real skill dirs) and a
//          proposed FRICTIONS.md entry (id + all schema fields),
//       3. detects OBVIOUS exact-dup ids (a heading in the target's FRICTIONS.md already
//          uses the same proposed id) and multi-skill ambiguity, and routes those to a
//          "flagged" bucket for an agent/human to adjudicate in the manifest.
//   - --apply reads a manifest produced by this tool (--manifest <path>) and writes ONLY
//     entries an agent has confirmed (auto-migrate entries left unmodified, or pending
//     entries an agent resolved to `"decision": "migrate"`, optionally with a
//     `"resolvedId"`). Entries left "pending" are skipped at apply time, loudly.
//   - Conservation: every scanned fact is bucketed into exactly one of
//     migrate / general (kept in memory) / flagged (needs review) -- never silently
//     dropped. The tool exits non-zero if the bucket counts don't reconcile against the
//     scanned total.
//
// Usage:
//   node scripts/migrate-frictions-from-memory.mjs --memory-dir <path> [options]
//
// Options:
//   --memory-dir <path>    Directory to scan for loop-retro-observation facts (required).
//                          NOT hardcoded -- memory/auto/ location differs by domain.
//   --skills-dir <path>    Directory containing skill subdirs (each with SKILL.md).
//                          Default: <this-registry>/skills.
//   --manifest-out <path>  Where to write the review manifest JSON (dry-run mode).
//                          Default: ./friction-migration-manifest.json (cwd).
//   --manifest <path>      Manifest to read decisions from (--apply mode). Required
//                          together with --apply.
//   --apply                Write confirmed entries into skills/<skill>/FRICTIONS.md.
//                          Without this flag the tool is a pure dry-run (default).
//   --help, -h             Print this help and exit 0.
//
// Exit codes:
//   0   dry-run/apply completed and every scanned fact is accounted for.
//   1   bad args, IO error, or a conservation-accounting mismatch (should never happen
//       structurally -- treated as a bug, not a normal outcome).
//
// Dependency-free (Node core only) -- agent-compounds carries no node_modules / vitest.

import {
  readFileSync,
  writeFileSync,
  existsSync,
  readdirSync,
  statSync,
  mkdirSync,
} from 'node:fs';
import { dirname, join, resolve, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT_NAME = 'migrate-frictions-from-memory.mjs';
const __dirname = dirname(fileURLToPath(import.meta.url));
const DEFAULT_SKILLS_DIR = resolve(__dirname, '..', 'skills');
const DEFAULT_MANIFEST_OUT = resolve(process.cwd(), 'friction-migration-manifest.json');

const HELP_TEXT = [
  `${SCRIPT_NAME} -- one-time backfill of memory/auto/ friction facts into per-skill FRICTIONS.md (W4.4)`,
  '',
  'Scans a memory dir for kind: loop-retro-observation facts, classifies each against the',
  'registry real skill directories, and stages a migration into skills/<skill>/FRICTIONS.md',
  '(created lazily from the template in skills/skill-builder/references/friction-capture.md).',
  '',
  'HONESTY NOTE: the same-vs-new dedup judgment (friction-capture.md W4.2) is an AGENT',
  'judgment, not a string match -- this tool cannot and does not automate it. It does the',
  'MECHANICAL part only: find candidates, propose a target skill + entry, and detect',
  'OBVIOUS exact-dup ids / multi-skill ambiguity. Anything not obviously safe is routed to',
  'a "flagged" bucket in the review manifest for an agent/human to adjudicate BEFORE',
  '--apply. Dry-run is the default; nothing is ever written without an explicit --apply.',
  '',
  'Usage:',
  `  node scripts/${SCRIPT_NAME} --memory-dir <path> [options]`,
  '',
  'Options:',
  '  --memory-dir <path>    Directory to scan for loop-retro-observation facts (required).',
  '                         NOT hardcoded -- memory/auto/ location differs by domain.',
  '  --skills-dir <path>    Directory containing skill subdirs (each with SKILL.md).',
  `                         Default: ${DEFAULT_SKILLS_DIR}`,
  '  --manifest-out <path>  Where to write the review manifest JSON (dry-run mode).',
  '                         Default: ./friction-migration-manifest.json (cwd).',
  '  --manifest <path>      Manifest to read decisions from (--apply mode). Required',
  '                         together with --apply.',
  '  --apply                Write confirmed entries into skills/<skill>/FRICTIONS.md.',
  '                         Without this flag the tool is a pure dry-run (default).',
  '  --help, -h             Print this help and exit 0.',
  '',
  'Exit codes:',
  '  0   dry-run/apply completed and every scanned fact is accounted for.',
  '  1   bad args, IO error, or a conservation-accounting mismatch.',
  '',
  'Workflow:',
  '  1. node scripts/migrate-frictions-from-memory.mjs --memory-dir memory/auto',
  '     -> writes friction-migration-manifest.json, prints classification + conservation.',
  '  2. An agent/human opens the manifest, reviews every "flagged" entry (same-vs-new,',
  '     which skill, is this actually a friction), and sets "decision": "migrate" (with',
  '     an optional "resolvedId" to reuse an existing id) or "decision": "skip".',
  '  3. node scripts/migrate-frictions-from-memory.mjs --memory-dir memory/auto --apply \\',
  '       --manifest friction-migration-manifest.json',
  '     -> writes only confirmed entries into skills/<skill>/FRICTIONS.md.',
].join('\n');

function printHelp() {
  console.log(HELP_TEXT);
}

function fail(msg) {
  console.error(`ERROR: ${msg}`);
  process.exit(1);
}

// --- CLI parsing --------------------------------------------------------------------

function parseArgs(argv) {
  const opts = {
    memoryDir: null,
    skillsDir: DEFAULT_SKILLS_DIR,
    manifestOut: DEFAULT_MANIFEST_OUT,
    manifestIn: null,
    apply: false,
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--help' || a === '-h') {
      printHelp();
      process.exit(0);
    } else if (a === '--memory-dir') {
      opts.memoryDir = argv[++i];
      if (opts.memoryDir === undefined) fail('--memory-dir requires a <path> argument');
    } else if (a === '--skills-dir') {
      opts.skillsDir = argv[++i];
      if (opts.skillsDir === undefined) fail('--skills-dir requires a <path> argument');
    } else if (a === '--manifest-out') {
      opts.manifestOut = argv[++i];
      if (opts.manifestOut === undefined) fail('--manifest-out requires a <path> argument');
    } else if (a === '--manifest') {
      opts.manifestIn = argv[++i];
      if (opts.manifestIn === undefined) fail('--manifest requires a <path> argument');
    } else if (a === '--apply') {
      opts.apply = true;
    } else if (a.startsWith('--')) {
      fail(`unknown option '${a}'`);
    } else {
      fail(`unexpected positional argument '${a}'`);
    }
  }
  return opts;
}

// --- Frontmatter parsing (tailored to the memory/auto/ fact shape; no YAML dep) -----

// Parses the narrow frontmatter shape used by memory/auto/ facts:
//   name: <scalar>
//   description: <scalar, possibly long, unquoted>
//   metadata:
//     type: fact
//     ...
//     evidence: "<quoted scalar>"
//   tags: [a, b, c]
function parseFrontmatter(raw) {
  const lines = raw.split('\n');
  if (lines[0].trim() !== '---') return null;
  let end = -1;
  for (let i = 1; i < lines.length; i++) {
    if (lines[i].trim() === '---') {
      end = i;
      break;
    }
  }
  if (end === -1) return null;

  const fm = { metadata: {} };
  let inMetadata = false;
  for (let i = 1; i < end; i++) {
    const line = lines[i];
    if (line.trim() === '') continue;
    const indent = line.match(/^(\s*)/)[1].length;
    const trimmed = line.trim();
    const m = trimmed.match(/^([A-Za-z0-9_]+):\s*(.*)$/);
    if (!m) continue;
    const [, key, rawValue] = m;
    if (indent === 0) {
      inMetadata = key === 'metadata' && rawValue === '';
      if (!inMetadata) fm[key] = parseScalarOrArray(rawValue);
    } else if (indent >= 2 && inMetadata) {
      fm.metadata[key] = parseScalarOrArray(rawValue);
    }
  }
  const body = lines
    .slice(end + 1)
    .join('\n')
    .trim();
  return { frontmatter: fm, body };
}

function parseScalarOrArray(value) {
  const v = value.trim();
  if (v.startsWith('[') && v.endsWith(']')) {
    const inner = v.slice(1, -1).trim();
    if (inner === '') return [];
    return inner.split(',').map((s) => s.trim());
  }
  if (v.startsWith('"') && v.endsWith('"') && v.length >= 2) {
    return v.slice(1, -1);
  }
  return v;
}

// --- Memory dir scan -----------------------------------------------------------------

function walkMarkdownFiles(dir) {
  const out = [];
  if (!existsSync(dir)) return out;
  const entries = readdirSync(dir);
  for (const entry of entries) {
    const full = join(dir, entry);
    let st;
    try {
      st = statSync(full);
    } catch {
      continue;
    }
    if (st.isDirectory()) {
      out.push(...walkMarkdownFiles(full));
    } else if (entry.endsWith('.md')) {
      out.push(full);
    }
  }
  return out;
}

// A file is a scan candidate if it plausibly carries a loop-retro-observation fact --
// cheap pre-filter (avoid parsing every unrelated .md, e.g. MEMORY.md index files) before
// the full frontmatter parse decides inclusion for real.
function isCandidateFile(path, content) {
  return content.includes('kind: loop-retro-observation') || /loop-retro-/.test(path);
}

// --- Skill directory discovery --------------------------------------------------------

function discoverSkills(skillsDir) {
  if (!existsSync(skillsDir)) fail(`--skills-dir not found: ${skillsDir}`);
  const names = [];
  for (const entry of readdirSync(skillsDir)) {
    if (entry.startsWith('_')) continue; // _shared, _tools -- infra dirs, not skills
    const full = join(skillsDir, entry);
    if (!statSync(full).isDirectory()) continue;
    if (!existsSync(join(full, 'SKILL.md'))) continue; // real skills only
    names.push(entry);
  }
  return names;
}

// --- Classification -------------------------------------------------------------------

function slugFromName(name) {
  return name.replace(/^loop-retro-/, '');
}

function extractFrictionIds(frictionsContent) {
  const ids = [];
  for (const line of frictionsContent.split('\n')) {
    const m = line.match(/^##\s+(\S+)\s*$/);
    if (m) ids.push(m[1]);
  }
  return ids;
}

function wordSet(text) {
  return new Set(
    text
      .toLowerCase()
      .split(/[^a-z0-9]+/)
      .filter((w) => w.length >= 3)
  );
}

function jaccard(a, b) {
  const wa = wordSet(a);
  const wb = wordSet(b);
  if (wa.size === 0 || wb.size === 0) return 0;
  let intersection = 0;
  for (const w of wa) if (wb.has(w)) intersection++;
  const union = new Set([...wa, ...wb]).size;
  return union === 0 ? 0 : intersection / union;
}

// Extract the pre-drafted fix from a fact body's "**Apply:** ..." paragraph, if present.
function extractProposedFix(body, fallback) {
  const m = body.match(/\*\*Apply:\*\*\s*([\s\S]*?)(?:\n\n|$)/);
  if (!m) return fallback;
  return m[1].replace(/\s+/g, ' ').trim();
}

const COST_TO_IMPACT = { severe: 'L', critical: 'L', material: 'M', minor: 'S' };
const CANDIDATE_RELATED_THRESHOLD = 0.35;

function classifyFact(fact, skillNames, skillsDir) {
  const { frontmatter, body, sourceFile } = fact;
  const tags = Array.isArray(frontmatter.tags) ? frontmatter.tags : [];
  const stage = frontmatter.metadata.stage || '';

  // Tags-only matching, deliberately. `stage` names WHERE a fact surfaced (almost every
  // fact has one -- e.g. `stage: implement`), not necessarily which skill OWNS the
  // friction (a general tool quirk can surface during any stage). Real corpus evidence:
  // loop-retro-dcg-redirect-truncation-heredoc-echo-false-positive carries
  // `stage: implement` but NO skill tag, and is correctly general, not ac-implement's.
  // Using stage as a candidate source would wrongly auto-migrate every general fact into
  // whichever skill happened to be running when it was observed.
  const skillSet = new Set(skillNames);
  const candidates = new Set();
  for (const t of tags) if (skillSet.has(t)) candidates.add(t);
  const candidateList = [...candidates];

  const proposedId = slugFromName(frontmatter.name || sourceFile);
  const cost = frontmatter.metadata.cost || '';
  const impact = COST_TO_IMPACT[cost] || 'S';
  const firstSeen = frontmatter.metadata.first_seen || '';
  const recurrence = Number(frontmatter.metadata.recurrence || 1) || 1;
  const proposedFix = extractProposedFix(body, frontmatter.description || '');

  const proposedEntry = {
    id: proposedId,
    skills: candidateList.length === 1 ? candidateList : [],
    impact,
    impact_note: 'inferred from source cost field -- verify',
    frequency: 'occasional',
    frequency_note: 'inferred default (source facts do not carry frequency) -- verify',
    recurrence,
    related: [],
    first_seen: firstSeen,
    last_seen: frontmatter.metadata.last_seen || firstSeen,
    stage: stage || 'manual',
    status: 'open',
    proposed_fix: proposedFix,
    narrative: body,
  };

  let classification;
  let reason;
  let existingIdCollision = false;
  const relatedCandidates = [];

  if (candidateList.length === 0) {
    classification = 'general';
    reason = 'no tag matched a real skill directory -- treated as general/cross-cutting, kept in memory/auto/.';
  } else if (candidateList.length > 1) {
    classification = 'flagged';
    reason = `ambiguous -- ${candidateList.length} candidate skills matched (${candidateList.join(', ')}); an agent must pick the primary skill (and consider a pointer entry in the others per friction-capture.md's cross-cutting convention).`;
  } else {
    const targetSkill = candidateList[0];
    const frictionsPath = join(skillsDir, targetSkill, 'FRICTIONS.md');
    let existingContent = '';
    if (existsSync(frictionsPath)) {
      existingContent = readFileSync(frictionsPath, 'utf8');
      const existingIds = extractFrictionIds(existingContent);
      existingIdCollision = existingIds.includes(proposedId);

      // Candidate-pull: word-overlap hint only, never decides same-vs-new (W4.2).
      const blocks = existingContent.split(/\n(?=## )/).filter((b) => b.startsWith('## '));
      for (const block of blocks) {
        const idMatch = block.match(/^##\s+(\S+)/);
        if (!idMatch) continue;
        const sim = jaccard(body, block);
        if (sim >= CANDIDATE_RELATED_THRESHOLD) {
          relatedCandidates.push({ id: idMatch[1], skill: targetSkill, similarity: Number(sim.toFixed(2)) });
        }
      }
    }

    if (existingIdCollision) {
      classification = 'flagged';
      reason = `exact id collision -- ${targetSkill}/FRICTIONS.md already has an entry with id "${proposedId}"; judge same-vs-new (W4.2) before migrating, do not blindly reuse or blindly mint a new id.`;
    } else {
      classification = 'migrate';
      reason = `single confident skill match (${targetSkill}), no existing id collision.`;
      proposedEntry.skills = [targetSkill];
    }
  }

  return {
    sourceFile,
    name: frontmatter.name || null,
    classification,
    reason,
    targetSkill: classification === 'migrate' ? candidateList[0] : null,
    candidateSkills: candidateList,
    existingIdCollision,
    relatedCandidates,
    proposedEntry,
    decision: classification === 'migrate' ? 'auto-migrate' : classification === 'general' ? 'auto-keep' : 'pending',
  };
}

// --- FRICTIONS.md template + writer ---------------------------------------------------

function todayISO() {
  return new Date().toISOString().slice(0, 10);
}

function frictionsTemplate(skillName) {
  return [
    '---',
    `skill: ${skillName}`,
    `created: ${todayISO()}`,
    'last_pass: never',
    'entries: 0',
    '---',
    '',
    `# ${skillName} -- friction log`,
    '',
    '<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the',
    '     entries below and judge same-vs-new before minting an id (see friction-capture.md',
    '     § Deduplication) -- do not append a duplicate root friction under a new id. -->',
    '',
  ].join('\n');
}

function renderEntry(entry) {
  return [
    `## ${entry.id}`,
    `- skills: [${entry.skills.join(', ')}]`,
    `- impact: ${entry.impact}`,
    `- frequency: ${entry.frequency}`,
    `- recurrence: ${entry.recurrence}`,
    `- related: [${entry.related.join(', ')}]`,
    `- first_seen: ${entry.first_seen}`,
    `- last_seen: ${entry.last_seen}`,
    `- stage: ${entry.stage}`,
    `- status: ${entry.status}`,
    `- proposed_fix: ${entry.proposed_fix}`,
    `- narrative: ${entry.narrative.replace(/\n/g, ' ').replace(/\s+/g, ' ').trim()}`,
    '',
  ].join('\n');
}

function appendEntriesToFrictions(frictionsPath, skillName, entries) {
  let content;
  let existingCount = 0;
  if (existsSync(frictionsPath)) {
    content = readFileSync(frictionsPath, 'utf8');
    const m = content.match(/^entries:\s*(\d+)\s*$/m);
    existingCount = m ? Number(m[1]) : 0;
  } else {
    content = frictionsTemplate(skillName);
  }

  const newCount = existingCount + entries.length;
  content = content.replace(/^entries:\s*\d+\s*$/m, `entries: ${newCount}`);
  content = content.replace(/^last_pass:\s*.*$/m, `last_pass: ${todayISO()}`);

  const appendBlock = entries.map(renderEntry).join('\n');
  content = content.trimEnd() + '\n\n' + appendBlock.trimEnd() + '\n';

  mkdirSync(dirname(frictionsPath), { recursive: true });
  writeFileSync(frictionsPath, content, 'utf8');
}

// --- Conservation summary --------------------------------------------------------------

function printConservationSummary(results) {
  const migrate = results.filter((r) => r.classification === 'migrate');
  const general = results.filter((r) => r.classification === 'general');
  const flagged = results.filter((r) => r.classification === 'flagged');
  const total = results.length;
  const accounted = migrate.length + general.length + flagged.length;

  console.log('\n--- Conservation summary ---');
  console.log(`  scanned:                 ${total}`);
  console.log(`  -> migrated/eligible:    ${migrate.length}`);
  console.log(`  -> kept-general (memory):${' '.repeat(1)}${general.length}`);
  console.log(`  -> flagged-for-review:   ${flagged.length}`);

  if (accounted !== total) {
    console.error(
      `\nCONSERVATION CHECK: FAIL -- ${total - accounted} scanned fact(s) unaccounted for (bucket bug).`
    );
    return false;
  }
  console.log('\nCONSERVATION CHECK: PASS -- every scanned fact mapped to exactly one outcome.');
  return true;
}

// --- Report ------------------------------------------------------------------------

function printReport(results) {
  console.log(`Scanned ${results.length} loop-retro-observation fact(s).\n`);
  for (const r of results) {
    console.log(`[${r.classification.toUpperCase()}] ${r.name || r.sourceFile}`);
    console.log(`  source: ${r.sourceFile}`);
    if (r.classification === 'migrate') {
      console.log(`  target skill: ${r.targetSkill}`);
      console.log(`  proposed id:  ${r.proposedEntry.id}`);
    } else if (r.classification === 'flagged') {
      console.log(`  candidates:   ${r.candidateSkills.join(', ') || '(none)'}`);
    }
    console.log(`  reason: ${r.reason}`);
    if (r.relatedCandidates.length > 0) {
      console.log(
        `  related candidates (candidate-pull hint, agent must judge): ${r.relatedCandidates
          .map((c) => `${c.id}@${c.skill} (${c.similarity})`)
          .join(', ')}`
      );
    }
    console.log('');
  }
}

// --- Main: dry-run ----------------------------------------------------------------

function runDryRun(opts) {
  if (!opts.memoryDir) fail('--memory-dir is required');
  const memoryDir = resolve(opts.memoryDir);
  if (!existsSync(memoryDir)) fail(`--memory-dir not found: ${memoryDir}`);
  const skillsDir = resolve(opts.skillsDir);
  const skillNames = discoverSkills(skillsDir);

  const allFiles = walkMarkdownFiles(memoryDir);
  const results = [];

  for (const file of allFiles) {
    const raw = readFileSync(file, 'utf8');
    if (!isCandidateFile(file, raw)) continue;

    const parsed = parseFrontmatter(raw);
    if (!parsed || parsed.frontmatter.metadata.kind !== 'loop-retro-observation') {
      if (!parsed && /loop-retro-/.test(file)) {
        // Named like a friction fact but unparsable -- do not silently drop it.
        results.push({
          sourceFile: relative(memoryDir, file),
          name: null,
          classification: 'flagged',
          reason: 'unparsable frontmatter on a loop-retro-named file -- needs manual triage.',
          targetSkill: null,
          candidateSkills: [],
          existingIdCollision: false,
          relatedCandidates: [],
          proposedEntry: null,
          decision: 'pending',
        });
      }
      continue;
    }

    const fact = { frontmatter: parsed.frontmatter, body: parsed.body, sourceFile: relative(memoryDir, file) };
    results.push(classifyFact(fact, skillNames, skillsDir));
  }

  printReport(results);
  const ok = printConservationSummary(results);

  const manifest = {
    tool: SCRIPT_NAME,
    version: 1,
    generatedAt: new Date().toISOString(),
    memoryDir,
    skillsDir,
    summary: {
      scanned: results.length,
      migrate: results.filter((r) => r.classification === 'migrate').length,
      general: results.filter((r) => r.classification === 'general').length,
      flagged: results.filter((r) => r.classification === 'flagged').length,
    },
    dedupNote:
      'The same-vs-new judgment (W4.2) is agent-in-the-loop, not automated. Review every "flagged" entry and any "migrate" entry\'s relatedCandidates before running --apply. Set "decision" to "migrate" (optionally "resolvedId") or "skip" on flagged entries you have adjudicated.',
    entries: results,
  };

  mkdirSync(dirname(resolve(opts.manifestOut)), { recursive: true });
  writeFileSync(resolve(opts.manifestOut), JSON.stringify(manifest, null, 2), 'utf8');
  console.log(`\nManifest written: ${resolve(opts.manifestOut)}`);

  if (!ok) process.exit(1);
  process.exit(0);
}

// --- Main: apply --------------------------------------------------------------------

function runApply(opts) {
  if (!opts.manifestIn) fail('--apply requires --manifest <path> (produced by a prior dry-run)');
  const manifestPath = resolve(opts.manifestIn);
  if (!existsSync(manifestPath)) fail(`--manifest not found: ${manifestPath}`);
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
  if (manifest.tool !== SCRIPT_NAME) fail(`manifest was not produced by ${SCRIPT_NAME}`);

  const skillsDir = resolve(opts.skillsDir || manifest.skillsDir);

  const toWrite = []; // { skill, entry }
  let skipped = 0;
  let migrated = 0;
  let keptGeneral = 0;

  for (const entry of manifest.entries) {
    if (entry.classification === 'general') {
      keptGeneral++;
      continue;
    }
    if (entry.classification === 'migrate' && entry.decision !== 'skip') {
      const proposed = { ...entry.proposedEntry };
      if (entry.resolvedId) proposed.id = entry.resolvedId;
      toWrite.push({ skill: entry.targetSkill, entry: proposed });
      migrated++;
      continue;
    }
    if (entry.classification === 'flagged' && entry.decision === 'migrate') {
      const targetSkill = entry.resolvedSkill || entry.targetSkill || entry.candidateSkills[0];
      if (!targetSkill) {
        console.warn(`SKIP (no resolved target skill): ${entry.sourceFile}`);
        skipped++;
        continue;
      }
      const proposed = { ...entry.proposedEntry, skills: [targetSkill] };
      if (entry.resolvedId) proposed.id = entry.resolvedId;
      toWrite.push({ skill: targetSkill, entry: proposed });
      migrated++;
      continue;
    }
    // Anything else (pending flagged, explicit skip) is not written.
    skipped++;
  }

  const bySkill = new Map();
  for (const { skill, entry } of toWrite) {
    if (!bySkill.has(skill)) bySkill.set(skill, []);
    bySkill.get(skill).push(entry);
  }

  for (const [skill, entries] of bySkill) {
    const frictionsPath = join(skillsDir, skill, 'FRICTIONS.md');
    // Within-batch id collision guard (defensive; source names are unique in practice).
    const seen = new Set();
    const deduped = [];
    for (const e of entries) {
      if (seen.has(e.id)) {
        console.warn(`SKIP (duplicate id within this batch for ${skill}): ${e.id}`);
        continue;
      }
      seen.add(e.id);
      deduped.push(e);
    }
    appendEntriesToFrictions(frictionsPath, skill, deduped);
    console.log(`Wrote ${deduped.length} entr${deduped.length === 1 ? 'y' : 'ies'} -> ${frictionsPath}`);
  }

  console.log('\n--- Apply summary ---');
  console.log(`  migrated:      ${migrated}`);
  console.log(`  kept-general:  ${keptGeneral}`);
  console.log(`  skipped/pending (not written, still in manifest for follow-up): ${skipped}`);
  const total = manifest.summary.scanned;
  const accounted = migrated + keptGeneral + skipped;
  if (accounted !== total) {
    console.error(`\nCONSERVATION CHECK: FAIL -- ${total - accounted} fact(s) unaccounted for at apply time.`);
    process.exit(1);
  }
  console.log('\nCONSERVATION CHECK: PASS -- every scanned fact still mapped to exactly one outcome.');
  process.exit(0);
}

// --- Entry point ---------------------------------------------------------------------

function main() {
  const argv = process.argv.slice(2);
  if (argv.length === 0) {
    printHelp();
    process.exit(1);
  }
  const opts = parseArgs(argv);
  if (opts.apply) {
    runApply(opts);
  } else {
    runDryRun(opts);
  }
}

main();
