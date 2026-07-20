#!/usr/bin/env node
// skill-diet-conservation.mjs — the "no silent loss" gate for skill-diet sweeps (W3.1).
//
// Given a before/after SKILL.md pair, extracts every ## / ### / #### heading and asserts
// every heading present in BEFORE but absent from AFTER (a "removed heading") maps to a
// destination:
//   (a) EXTRACT       — the heading (or its content) now lives in a references/*.md or
//                        skills/_shared/*.md file reachable from the skill.
//   (b) DUPLICATE      — a surviving twin heading exists elsewhere in the after-tree
//                        (including the after SKILL.md itself).
//   (c) DELETE-UNIQUE  — recorded in the skill's MAINTENANCE.md (Holding pen or Cut-log).
//   (d) EXPLICIT MARKER — an inline `<!-- diet: "<heading>" -> <destination> -->` comment,
//                        or a "superseded / deleted @ <SHA>" note referencing the heading,
//                        found anywhere in the after-tree.
//
// Any removed heading with none of the above is a VIOLATION -> non-zero exit.
//
// Usage:
//   node scripts/skill-diet-conservation.mjs <before-file> <after-file> [options]
//   node scripts/skill-diet-conservation.mjs --git <ref> <after-file> [options]
//
// Options:
//   --skill-dir <dir>   Skill directory to search for destinations. Defaults to the
//                        directory containing <after-file>.
//   --strict            Require EXACT normalized heading matches; near-matches (renamed
//                        headings) are treated as violations instead of warnings.
//   --help, -h           Print this usage and exit 0.
//
// Exit codes:
//   0   no removed headings, or every removed heading has a mapped destination.
//   1   at least one removed heading has no destination (or a bad-args / IO error).
//
// Dependency-free (Node core only) — agent-compounds carries no node_modules / vitest.

import { readFileSync, existsSync, readdirSync, statSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { dirname, join, resolve, relative } from 'node:path';

const SCRIPT_NAME = 'skill-diet-conservation.mjs';

function printHelp() {
  console.log(`${SCRIPT_NAME} — skill-diet conservation check (W3.1)

Asserts every heading removed between a before/after SKILL.md pair maps to a destination
(extracted to references/, a surviving duplicate, a MAINTENANCE.md entry, or an explicit
diet marker). Exits non-zero on any unmapped removal.

Usage:
  node scripts/${SCRIPT_NAME} <before-file> <after-file> [options]
  node scripts/${SCRIPT_NAME} --git <ref> <after-file> [options]

Options:
  --skill-dir <dir>   Directory to search for destinations (references/, _shared/,
                      MAINTENANCE.md). Defaults to dirname(<after-file>).
  --strict            Require exact heading matches; near-matches fail instead of warn.
  --help, -h          Print this help and exit 0.

Examples:
  node scripts/${SCRIPT_NAME} /tmp/skill-before.md skills/ac-loop/SKILL.md
  node scripts/${SCRIPT_NAME} --git HEAD skills/ac-loop/SKILL.md --strict
`);
}

function fail(msg) {
  console.error(`ERROR: ${msg}`);
  process.exit(1);
}

function parseArgs(argv) {
  const opts = { git: null, strict: false, skillDir: null, positional: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--help' || a === '-h') {
      printHelp();
      process.exit(0);
    } else if (a === '--git') {
      opts.git = argv[++i];
      if (opts.git === undefined) fail('--git requires a <ref> argument');
    } else if (a === '--skill-dir') {
      opts.skillDir = argv[++i];
      if (opts.skillDir === undefined) fail('--skill-dir requires a <dir> argument');
    } else if (a === '--strict') {
      opts.strict = true;
    } else if (a.startsWith('--')) {
      fail(`unknown option '${a}'`);
    } else {
      opts.positional.push(a);
    }
  }
  return opts;
}

// --- Heading extraction ------------------------------------------------------------

// Extract ##/###/#### headings, skipping fenced code blocks (``` ... ```).
function extractHeadings(content) {
  const headings = [];
  let inFence = false;
  const lines = content.split('\n');
  for (const line of lines) {
    if (/^\s*```/.test(line)) {
      inFence = !inFence;
      continue;
    }
    if (inFence) continue;
    const m = line.match(/^(#{2,4})\s+(.+?)\s*$/);
    if (m) {
      headings.push({ level: m[1].length, raw: m[2], normalized: normalizeHeading(m[2]) });
    }
  }
  return headings;
}

// Normalize a heading for comparison: strip markdown emphasis/links/code ticks,
// lowercase, collapse whitespace, strip trailing punctuation.
function normalizeHeading(text) {
  let t = text;
  t = t.replace(/`([^`]*)`/g, '$1'); // inline code
  t = t.replace(/\[([^\]]*)\]\([^)]*\)/g, '$1'); // links -> label
  t = t.replace(/[*_]{1,3}/g, ''); // bold/italic markers
  t = t.replace(/\s+/g, ' ').trim();
  t = t.replace(/[.:,;!?]+$/g, '');
  return t.toLowerCase();
}

function wordSet(normalized) {
  return new Set(normalized.split(/[^a-z0-9]+/).filter((w) => w.length >= 2));
}

// Jaccard word-overlap similarity, 0..1.
function similarity(a, b) {
  const wa = wordSet(a);
  const wb = wordSet(b);
  if (wa.size === 0 && wb.size === 0) return 1;
  let intersection = 0;
  for (const w of wa) if (wb.has(w)) intersection++;
  const union = new Set([...wa, ...wb]).size;
  return union === 0 ? 0 : intersection / union;
}

const NEAR_MATCH_THRESHOLD = 0.6;

// --- Destination search -------------------------------------------------------------

function listMarkdownFiles(dir) {
  if (!existsSync(dir)) return [];
  try {
    return readdirSync(dir)
      .filter((f) => f.endsWith('.md'))
      .map((f) => join(dir, f))
      .filter((f) => statSync(f).isFile());
  } catch {
    return [];
  }
}

function findRepoRoot(startDir) {
  try {
    return execFileSync('git', ['rev-parse', '--show-toplevel'], {
      cwd: startDir,
      stdio: ['ignore', 'pipe', 'ignore'],
    })
      .toString()
      .trim();
  } catch {
    return null;
  }
}

// Collect every candidate destination file's content: after-SKILL.md itself,
// <skillDir>/references/*.md, <skillDir>/MAINTENANCE.md, and the registry-wide
// <repoRoot>/skills/_shared/*.md.
function collectDestinationCorpus(skillDir, afterContent) {
  const files = [];
  files.push({ path: '(after SKILL.md)', content: afterContent });

  for (const f of listMarkdownFiles(join(skillDir, 'references'))) {
    files.push({ path: f, content: readFileSync(f, 'utf8') });
  }

  const maintenancePath = join(skillDir, 'MAINTENANCE.md');
  if (existsSync(maintenancePath)) {
    files.push({ path: maintenancePath, content: readFileSync(maintenancePath, 'utf8') });
  }

  const repoRoot = findRepoRoot(skillDir);
  if (repoRoot) {
    const sharedDir = join(repoRoot, 'skills', '_shared');
    for (const f of listMarkdownFiles(sharedDir)) {
      files.push({ path: f, content: readFileSync(f, 'utf8') });
    }
  }

  return files;
}

// Explicit diet-marker / superseded-deleted patterns.
const SHA_RE = /\b[0-9a-f]{7,40}\b/;

function hasExplicitMarker(corpus, headingRaw) {
  for (const { content } of corpus) {
    const lines = content.split('\n');
    for (const line of lines) {
      if (!line.toLowerCase().includes(headingRaw.toLowerCase().slice(0, 20))) continue;
      const lower = line.toLowerCase();
      if (lower.includes('diet:')) return true;
      if ((lower.includes('superseded') || lower.includes('deleted')) && SHA_RE.test(line)) {
        return true;
      }
    }
  }
  return false;
}

// Search the destination corpus for a heading match. Returns
// { kind: 'exact' | 'near' | null, file, matchedText }.
function findDestination(headingNormalized, corpus, excludeContent) {
  let nearMatch = null;
  for (const { path, content } of corpus) {
    if (content === excludeContent && path === '(after SKILL.md)') {
      // Still search after-SKILL.md for duplicate headings elsewhere in the same file,
      // just don't let the removed heading match against itself trivially (it can't,
      // since it's absent from `afterHeadings` by construction of the caller).
    }
    const headings = extractHeadings(content);
    for (const h of headings) {
      if (h.normalized === headingNormalized) {
        return { kind: 'exact', file: path, matchedText: h.raw };
      }
    }
    // Fall back to prose containment (relocated content without a matching heading).
    const normalizedBody = content.toLowerCase();
    if (headingNormalized.length >= 8 && normalizedBody.includes(headingNormalized)) {
      return { kind: 'exact', file: path, matchedText: '(prose match)' };
    }
    for (const h of headings) {
      const sim = similarity(headingNormalized, h.normalized);
      if (sim >= NEAR_MATCH_THRESHOLD && (!nearMatch || sim > nearMatch.sim)) {
        nearMatch = { kind: 'near', file: path, matchedText: h.raw, sim };
      }
    }
  }
  return nearMatch;
}

// --- Main ------------------------------------------------------------------------

function readBeforeContent(opts) {
  if (opts.git) {
    const afterFile = opts.positional[0];
    if (!afterFile) fail('--git mode requires the <after-file> positional argument');
    const afterAbs = resolve(afterFile);
    const repoRoot = findRepoRoot(dirname(afterAbs));
    if (!repoRoot) fail(`could not resolve a git repo root from '${afterFile}'`);
    const relPath = relative(repoRoot, afterAbs);
    try {
      return execFileSync('git', ['show', `${opts.git}:${relPath}`], { cwd: repoRoot }).toString();
    } catch (e) {
      fail(`'git show ${opts.git}:${relPath}' failed: ${e.message}`);
    }
  }
  const beforeFile = opts.positional[0];
  if (!beforeFile) fail('missing <before-file> argument');
  if (!existsSync(beforeFile)) fail(`before-file not found: ${beforeFile}`);
  return readFileSync(beforeFile, 'utf8');
}

function readAfterContent(opts) {
  const afterFile = opts.git ? opts.positional[0] : opts.positional[1];
  if (!afterFile) fail('missing <after-file> argument');
  if (!existsSync(afterFile)) fail(`after-file not found: ${afterFile}`);
  return { path: afterFile, content: readFileSync(afterFile, 'utf8') };
}

function main() {
  const argv = process.argv.slice(2);
  if (argv.length === 0) {
    printHelp();
    process.exit(1);
  }
  const opts = parseArgs(argv);

  const beforeContent = readBeforeContent(opts);
  const { path: afterFile, content: afterContent } = readAfterContent(opts);

  const skillDir = resolve(opts.skillDir || dirname(afterFile));
  if (!existsSync(skillDir)) fail(`--skill-dir not found: ${skillDir}`);

  const beforeHeadings = extractHeadings(beforeContent);
  const afterHeadings = extractHeadings(afterContent);
  const afterNormalizedSet = new Set(afterHeadings.map((h) => h.normalized));

  const removed = beforeHeadings.filter((h) => !afterNormalizedSet.has(h.normalized));

  if (removed.length === 0) {
    console.log('CONSERVATION CHECK: PASS — 0 headings removed, nothing to map.');
    process.exit(0);
  }

  const corpus = collectDestinationCorpus(skillDir, afterContent);

  const violations = [];
  const warnings = [];
  const mapped = [];

  for (const h of removed) {
    if (hasExplicitMarker(corpus, h.raw)) {
      mapped.push({ heading: h.raw, via: 'explicit diet/supersede marker' });
      continue;
    }
    const dest = findDestination(h.normalized, corpus, afterContent);
    if (dest && dest.kind === 'exact') {
      mapped.push({ heading: h.raw, via: `${dest.file} ("${dest.matchedText}")` });
    } else if (dest && dest.kind === 'near') {
      if (opts.strict) {
        violations.push({
          heading: h.raw,
          reason: `only a near-match found (${Math.round(dest.sim * 100)}% overlap in ${dest.file} — "${dest.matchedText}"); --strict requires an exact match or explicit marker`,
        });
      } else {
        warnings.push({ heading: h.raw, via: `near-match in ${dest.file} ("${dest.matchedText}", ${Math.round(dest.sim * 100)}% overlap) — verify this is the intended destination` });
        mapped.push({ heading: h.raw, via: `near-match (warn) in ${dest.file}` });
      }
    } else {
      violations.push({
        heading: h.raw,
        reason: 'no destination found; extract to references/ (or skills/_shared/), record in MAINTENANCE.md (Holding pen / Cut-log), or add a `<!-- diet: "..." -> ... -->` marker',
      });
    }
  }

  console.log(`CONSERVATION CHECK: ${removed.length} heading(s) removed.`);
  for (const m of mapped) {
    console.log(`  MAPPED   "${m.heading}" -> ${m.via}`);
  }
  for (const w of warnings) {
    console.log(`  WARN     "${w.heading}" -> ${w.via}`);
  }
  for (const v of violations) {
    console.log(`  MISSING  "${v.heading}" -> ${v.reason}`);
  }

  if (violations.length > 0) {
    console.error(
      `\nCONSERVATION CHECK: FAIL — ${violations.length} of ${removed.length} removed heading(s) have no mapped destination.`
    );
    process.exit(1);
  }

  console.log(`\nCONSERVATION CHECK: PASS — all ${removed.length} removed heading(s) mapped.`);
  process.exit(0);
}

main();
