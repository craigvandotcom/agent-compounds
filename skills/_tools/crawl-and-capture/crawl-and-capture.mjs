#!/usr/bin/env node
// crawl-and-capture — shared full-app crawl + screenshot primitive.
//
// Wraps the `agent-browser` CLI with the mandatory discipline (ONE named
// session, guaranteed finally-close on every exit path, never `close --all`)
// and loops a route manifest × a viewport set, screenshotting each. Emits an
// index.json so consumers iterate captures instead of re-crawling.
//
// "Capture once, consume twice": the same run feeds `ac-qa-browser` (functional
// QA — errors/console/web-shell per route) AND `ac-ui-polish` (visual
// conformance vs design.md). Neither should re-implement the crawl loop.
//
// Generic / app-agnostic — all app specifics arrive as flags:
//   --base-url   http://localhost:3000        (required)
//   --manifest   path/to/routes.md            (required; format below)
//   --out        dir                          (default ./.crawl-out)
//   --viewports  320x844,390x844,428x926      (default; mobile-first set)
//   --auth-script path                         (app-owned; signs the session in —
//                  invoked as: bash <script> <session> <base-url>. Without it,
//                  routes flagged (auth) in the manifest are SKIPPED, not failed.)
//   --session    name                          (default crawl-and-capture)
//   --settle     networkidle|load|domcontent   (default networkidle)
//   --downscale  1500                          (optional; sips -Z on each png, macOS)
//   --limit      N                             (optional; cap routes, for smoke runs)
//
// Manifest format (CORE/journeys/routes.md): one route per line, first token =
// path, rest = label. `#`/`##` lines and blanks are ignored. A line whose label
// contains "(auth)" needs the login step. Commented-out lines (dynamic routes)
// are skipped by design.
//
// Exit: 0 = every attempted route captured clean; 1 = one or more routes errored
// (still writes index.json with per-route status); 2 = setup/usage error.
//
// Requires: `agent-browser` on PATH (npm i -g agent-browser). See
// browser-testing/SKILL.md for the CLI + the runaway-CPU teardown rationale.

import { execFileSync, spawnSync } from 'node:child_process';
import { readFileSync, mkdirSync, writeFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

// ── args ────────────────────────────────────────────────────────────────────
const argv = process.argv.slice(2);
const arg = (name, def) => {
  const i = argv.indexOf('--' + name);
  return i >= 0 && argv[i + 1] ? argv[i + 1] : def;
};
const has = name => argv.includes('--' + name);

const BASE = arg('base-url');
const MANIFEST = arg('manifest');
const OUT = arg('out', '.crawl-out');
const SESSION = arg('session', 'crawl-and-capture');
const SETTLE = arg('settle', 'networkidle');
const AUTH_SCRIPT = arg('auth-script');
const DOWNSCALE = arg('downscale');
const LIMIT = arg('limit') ? Number(arg('limit')) : Infinity;
const VIEWPORTS = arg('viewports', '320x844,390x844,428x926')
  .split(',')
  .map(s => {
    const [w, h] = s.trim().split('x').map(Number);
    return { w, h, label: `${w}x${h}` };
  });

if (!BASE || !MANIFEST) {
  console.error(
    'usage: crawl-and-capture.mjs --base-url <url> --manifest <routes.md> [--out dir]\n' +
      '       [--viewports 320x844,390x844] [--auth-script path] [--session name]\n' +
      '       [--settle networkidle|load|domcontent] [--downscale 1500] [--limit N]'
  );
  process.exit(2);
}
if (!existsSync(MANIFEST)) {
  console.error(`manifest not found: ${MANIFEST}`);
  process.exit(2);
}

// ── parse the route manifest ──────────────────────────────────────────────────
// path = first token; auth = label mentions "(auth)"; skip comments/headers/blanks.
function parseManifest(text) {
  const routes = [];
  for (const raw of text.split('\n')) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue; // comments + ## headers + dynamic-route notes
    if (!line.startsWith('/')) continue; // only real path lines
    const [path, ...rest] = line.split(/\s+/);
    const label = rest.join(' ');
    routes.push({ path, label, auth: /\(auth\)/i.test(label) });
  }
  return routes;
}

// ── agent-browser helpers (one session, always closed) ────────────────────────
const ab = (...args) =>
  execFileSync('agent-browser', ['--session', SESSION, ...args], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
  });

function slug(p) {
  const s = p.replace(/^\/+|\/+$/g, '').replace(/[^a-zA-Z0-9]+/g, '-');
  return s || 'home';
}

// ── crawl ─────────────────────────────────────────────────────────────────────
function main() {
  // verify agent-browser is installed before opening anything
  if (spawnSync('agent-browser', ['--help'], { stdio: 'ignore' }).error) {
    console.error('agent-browser not found on PATH — `npm i -g agent-browser`.');
    process.exit(2);
  }

  let routes = parseManifest(readFileSync(MANIFEST, 'utf8'));
  mkdirSync(OUT, { recursive: true });

  let authed = false;
  if (AUTH_SCRIPT) {
    if (!existsSync(AUTH_SCRIPT)) {
      console.error(`--auth-script not found: ${AUTH_SCRIPT}`);
      process.exit(2);
    }
  }

  const results = [];
  let errors = 0;
  let skippedAuth = 0;
  let opened = false;

  try {
    ab('open', BASE);
    opened = true;

    let count = 0;
    for (const route of routes) {
      if (count >= LIMIT) break;

      if (route.auth && !AUTH_SCRIPT) {
        skippedAuth++;
        results.push({ ...route, skipped: 'auth (no --auth-script)' });
        console.log(`⏭  ${route.path} — skipped (auth, no --auth-script)`);
        continue;
      }
      // lazily sign in once, before the first auth route
      if (route.auth && !authed) {
        console.log(`🔑 authenticating via ${AUTH_SCRIPT} …`);
        const r = spawnSync('bash', [AUTH_SCRIPT, SESSION, BASE], {
          encoding: 'utf8',
          stdio: ['ignore', 'inherit', 'inherit'],
        });
        if (r.status !== 0) throw new Error('auth-script failed; aborting auth routes');
        authed = true;
      }
      count++;

      const shots = [];
      let routeErr = null;
      for (const vp of VIEWPORTS) {
        const file = join(OUT, `${slug(route.path)}@${vp.label}.png`);
        try {
          ab('set', 'viewport', String(vp.w), String(vp.h));
          ab('open', BASE.replace(/\/$/, '') + route.path);
          ab('wait', '--load', SETTLE);
          ab('screenshot', file);
          if (DOWNSCALE && process.platform === 'darwin') {
            spawnSync('sips', ['-Z', String(DOWNSCALE), file], { stdio: 'ignore' });
          }
          shots.push({ viewport: vp.label, file });
        } catch (e) {
          routeErr = (e.stderr || e.message || String(e)).toString().trim().slice(0, 300);
        }
      }
      if (routeErr) {
        errors++;
        results.push({ ...route, error: routeErr, shots });
        console.log(`✗  ${route.path} — ${routeErr.split('\n')[0]}`);
      } else {
        results.push({ ...route, shots });
        console.log(`✓  ${route.path} — ${shots.length} shot(s)`);
      }
    }
  } catch (e) {
    errors++;
    console.error(`crawl aborted: ${(e.message || e).toString().slice(0, 300)}`);
  } finally {
    // MANDATORY scoped teardown — close ONLY our session, on every exit path.
    if (opened) {
      try {
        ab('close');
      } catch {
        /* daemon may already be gone; nothing more we can do safely */
      }
    }
  }

  const index = {
    base: BASE,
    manifest: MANIFEST,
    capturedAt: new Date().toISOString(),
    viewports: VIEWPORTS.map(v => v.label),
    counts: {
      routes: results.length,
      captured: results.filter(r => r.shots?.length && !r.error).length,
      errors,
      skippedAuth,
    },
    routes: results,
  };
  writeFileSync(join(OUT, 'index.json'), JSON.stringify(index, null, 2));

  console.log(
    `\n${errors ? '⚠' : '✓'} ${index.counts.captured}/${results.length} routes captured` +
      (skippedAuth ? `, ${skippedAuth} auth route(s) skipped (pass --auth-script)` : '') +
      (errors ? `, ${errors} errored` : '') +
      `\n→ ${join(OUT, 'index.json')}`
  );
  process.exit(errors ? 1 : 0);
}

main();
