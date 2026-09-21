#!/usr/bin/env node
/**
 * serve.ts — tools/factory-ui: the local single-file READ-ONLY face on the factory.
 *
 * Bun or Node (node:http only — no deps, no build step), vanilla HTML+JS.
 * Serves 127.0.0.1 only. The FILES stay the truth and this face only READS them:
 * machine facts (targets, org root, harness overrides) come from the one reader,
 * engine/machine.sh; the package manifest from skills/packages.json. It has no
 * writer: every route is a read, and the two buttons run the engine's own
 * read-only checks.
 *
 *   GET  /              the matrix UI (read-only)
 *   GET  /api/state     { root, org, order, pkgs, skills, targets, harnesses, enabled, notes }
 *   POST /api/verify    { target } — run lint/consumer.py for one listed target (streamed)
 *   POST /api/check     run engine/sync.sh --check (streamed) — drift
 *
 * Usage: node tools/factory-ui/serve.ts [--port N]   (default 8471)
 */
import * as http from "node:http";
import * as fs from "node:fs";
import * as path from "node:path";
import { execFileSync, spawn } from "node:child_process";

type Pkg = { blurb?: string; skills: string[]; agents?: string[]; hooks?: string[]; requires?: string[]; budget?: { spine: number; loaded: number } };
type Target = { dir: string; public: boolean; packages: string[] | null };
type HarnessManifest = { harnesses?: Record<string, { enabled?: boolean }> };

const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..", "..");
const MANIFEST = path.join(ROOT, "skills", "packages.json");
const MACHINE = path.join(ROOT, "engine", "machine.sh");
const CONSUMER = path.join(ROOT, "lint", "consumer.py");
const SYNC = path.join(ROOT, "engine", "sync.sh");

// Every machine fact comes from the one reader. machine.sh self-locates from its own
// path and falls back to the committed base at exit 0 when there is no machine file,
// so this face inherits that contract rather than re-deriving an org root or parsing a
// targets-list line format of its own.
function machine(args: string[]): string {
  return execFileSync("bash", [MACHINE, ...args], { encoding: "utf8", cwd: ROOT });
}

function machineNote(what: string, e: unknown): string {
  const status = (e as { status?: number }).status;
  if (status === 4) return `no machine settings file — ${what} are unconfigured (copy machine.example.json to machine.json)`;
  return `machine.sh ${what} unavailable: ${String(e)}`;
}

function readOrg(): { org: string; note: string } {
  try { return { org: machine(["--org-root"]).trim(), note: "" }; }
  catch (e) { return { org: "", note: machineNote("org root", e) }; }
}

function readManifest(): { order: string[]; pkgs: Record<string, Pkg>; raw: Record<string, unknown> } {
  const raw = JSON.parse(fs.readFileSync(MANIFEST, "utf8"));
  const order = Object.keys(raw).filter((k) => !k.startsWith("_"));
  const pkgs: Record<string, Pkg> = {};
  for (const k of order) pkgs[k] = raw[k] as Pkg;
  return { order, pkgs, raw };
}

function allSkills(): string[] {
  return fs.readdirSync(path.join(ROOT, "skills"), { withFileTypes: true })
    .filter((e) => e.isDirectory() && fs.existsSync(path.join(ROOT, "skills", e.name, "SKILL.md")))
    .map((e) => e.name).sort();
}

// machine.sh --targets emits one `<abs-path>\t<flags>` line per target; flags is a
// space-separated token list (`public` and/or `packages=a,b`). The reader already
// validated every path, so this face parses only its own grammar.
function readTargets(): { targets: Target[]; note: string } {
  let out: string;
  try { out = machine(["--targets"]); }
  catch (e) { return { targets: [], note: machineNote("targets", e) }; }
  const targets: Target[] = [];
  for (const line of out.split("\n")) {
    if (!line.trim()) continue;
    const tab = line.indexOf("\t");
    const dir = tab >= 0 ? line.slice(0, tab) : line;
    const flags = (tab >= 0 ? line.slice(tab + 1) : "").trim().split(/\s+/).filter(Boolean);
    let pub = false, pkgs: string[] | null = null;
    for (const t of flags) {
      if (t === "public") pub = true;
      else if (t.startsWith("packages=")) pkgs = t.slice("packages=".length).split(",").map((s) => s.trim()).filter(Boolean);
    }
    targets.push({ dir, public: pub, packages: pkgs });
  }
  return { targets, note: "" };
}

// machine.sh --harnesses is harnesses.json with this machine's overrides merged, or the
// committed base alone at exit 0 when there is no machine file — never a write path.
function readHarnesses(): { names: string[]; enabled: Record<string, boolean>; note: string } {
  let h: HarnessManifest;
  try { h = JSON.parse(machine(["--harnesses"])); }
  catch (e) { return { names: [], enabled: {}, note: machineNote("harnesses", e) }; }
  const names = Object.keys(h.harnesses || {});
  const enabled: Record<string, boolean> = {};
  for (const n of names) enabled[n] = h.harnesses![n].enabled !== false;
  return { names, enabled, note: "" };
}

function json(res: http.ServerResponse, code: number, obj: unknown): void {
  res.writeHead(code, { "Content-Type": "application/json; charset=utf-8" });
  res.end(JSON.stringify(obj));
}

function readBody(req: http.IncomingMessage): Promise<unknown> {
  return new Promise((resolve, reject) => {
    let s = "";
    req.on("data", (c) => { s += c; if (s.length > 1 << 20) reject(new Error("body too large")); });
    req.on("end", () => { try { resolve(s ? JSON.parse(s) : {}); } catch (e) { reject(e); } });
    req.on("error", reject);
  });
}

function state(): object {
  const notes: string[] = [];
  let order: string[] = [], pkgs: Record<string, Pkg> = {};
  try { ({ order, pkgs } = readManifest()); }
  catch (e) { notes.push(`skills/packages.json unreadable: ${String(e)}`); }
  const skills = allSkills();
  const { org, note: oNote } = readOrg();
  if (oNote) notes.push(oNote);
  const { targets, note: tNote } = readTargets();
  if (tNote) notes.push(tNote);
  const { names, enabled, note: hNote } = readHarnesses();
  if (hNote) notes.push(hNote);
  return { root: ROOT, org, order, pkgs, skills, targets, harnesses: names, enabled, notes };
}

function streamCmd(res: http.ServerResponse, cmd: string, args: string[], cwd: string): void {
  res.writeHead(200, { "Content-Type": "text/plain; charset=utf-8" });
  const child = spawn(cmd, args, { cwd });
  child.stdout.on("data", (d) => res.write(d));
  child.stderr.on("data", (d) => res.write(d));
  child.on("error", (e) => { res.write(`\n[spawn failed: ${String(e)}]\n`); res.end(); });
  child.on("close", (code) => { res.write(`\n[exit ${code}]\n`); res.end(); });
}

const PAGE = `<!doctype html><html><head><meta charset="utf-8"><title>factory matrix</title>
<style>body{font-family:system-ui,sans-serif;max-width:1100px;margin:2em auto;padding:0 1em}table{border-collapse:collapse;margin:1em 0}td,th{border:1px solid #ccc;padding:.25em .5em;font-size:.85em}pre{background:#111;color:#eee;padding:1em;overflow:auto;max-height:30em}.note{background:#fff8e1;padding:.5em}.tag{margin-right:.75em}code{background:#f2f2f2;padding:.1em .3em}</style>
</head><body><h1>factory matrix <small>read-only</small></h1><div id="notes"></div>
<p>org root: <code id="org">…</code> · checkout: <code id="root">…</code></p>
<h2>packages × skills <small>(read-only — edits live in skills/packages.json)</small></h2><div id="pkgs"></div>
<h2>targets <small>(read-only — machine.sh --targets)</small></h2><div id="tgts"></div>
<h2>harnesses <small>(read-only — machine.sh --harnesses)</small></h2><div id="harn"></div>
<h2>run</h2><div id="v"></div>
<p><button onclick="run('/api/check')">Check drift (engine/sync.sh --check)</button></p>
<pre id="out"></pre>
<script>
let S=null;
async function load(){S=await(await fetch('/api/state')).json();
document.getElementById('notes').innerHTML=S.notes.map(n=>'<p class="note">'+n+'</p>').join('');
document.getElementById('root').textContent=S.root;
document.getElementById('org').textContent=S.org||'(unknown)';
let h='<table><tr><th>skill</th>'+S.order.map(p=>'<th>'+p+'</th>').join('')+'</tr>';
for(const s of S.skills){h+='<tr><td>'+s+'</td>'+S.order.map(p=>'<td>'+(S.pkgs[p].skills.includes(s)?'✓':'·')+'</td>').join('')+'</tr>';}
document.getElementById('pkgs').innerHTML=h+'</table>';
h='<table><tr><th>target</th><th>public</th><th>packages</th><th></th></tr>';
for(const t of S.targets){const eff=t.packages||S.order;h+='<tr><td>'+t.dir+'</td><td>'+(t.public?'yes':'no')+'</td><td>'+eff.join(', ')+'</td><td><button onclick="verify(\\''+t.dir+'\\')">verify</button></td></tr>';}
document.getElementById('tgts').innerHTML=(S.targets.length?h+'</table>':'<p>no targets</p>');
document.getElementById('harn').innerHTML=S.harnesses.map(n=>'<span class="tag">'+n+': '+(S.enabled[n]?'enabled':'disabled')+'</span>').join('')||'<p>no harnesses</p>';
let v='';for(const t of S.targets)v+='<button onclick="verify(\\''+t.dir+'\\')">verify '+t.dir+'</button> ';
document.getElementById('v').innerHTML=v;}
function verify(t){run('/api/verify',{target:t});}
async function run(u,b){const el=document.getElementById('out');el.textContent='running…\\n';
const r=await fetch(u,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(b||{})});
const rd=r.body.getReader(),dec=new TextDecoder();while(true){const{done,value}=await rd.read();if(done)break;el.textContent+=dec.decode(value);}el.textContent+='\\n[done]';}
load();</script></body></html>`;

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url || "/", "http://x");
    if (req.method === "GET" && url.pathname === "/") {
      res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" }); res.end(PAGE); return;
    }
    if (req.method === "GET" && url.pathname === "/api/state") { json(res, 200, state()); return; }
    if (req.method === "POST" && url.pathname === "/api/verify") {
      const b = await readBody(req) as { target: string };
      const { targets } = readTargets();
      const hit = targets.find((t) => t.dir === String(b.target));
      if (!hit) { json(res, 400, { error: `'${b.target}' is not a target machine.sh lists` }); return; }
      if (!fs.existsSync(hit.dir)) { json(res, 400, { error: `target dir missing: ${hit.dir}` }); return; }
      streamCmd(res, "python3", [CONSUMER, hit.dir], ROOT); return;
    }
    if (req.method === "POST" && url.pathname === "/api/check") { streamCmd(res, "bash", [SYNC, "--all", "--check"], ROOT); return; }
    json(res, 404, { error: "not found" });
  } catch (e) { json(res, 500, { error: String(e) }); }
});

const port = Number(process.argv.includes("--port") ? process.argv[process.argv.indexOf("--port") + 1] : 8471);
server.listen(port, "127.0.0.1", () => console.log(`factory-ui on http://127.0.0.1:${port} (root ${ROOT})`));
