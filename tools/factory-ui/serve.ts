#!/usr/bin/env node
/**
 * serve.ts — tools/factory-ui: the local single-file face on the factory (ac-6asz.9).
 *
 * Bun or Node (node:http only — no deps, no build step), vanilla HTML+JS.
 * Serves 127.0.0.1 only. The FILES stay the truth: every load re-reads
 * skills/packages.json, the targets list, and harnesses.json from disk, and
 * every edit rewrites the file it claims (validated first, fail loud on 400).
 *
 *   GET  /                        the matrix UI
 *   GET  /api/state                { packages, targets, harnesses, notes }
 *   POST /api/packages/member      { package, skill, present } — edit skills/packages.json
 *   POST /api/targets/package      { target, package, present } — edit packages= tokens
 *   POST /api/targets/reset        { target } — drop packages= (back to default: all)
 *   POST /api/harness/enabled      { harness, enabled } — edit harnesses.json
 *   POST /api/verify               { target } — run lint/consumer.py per cell (streamed)
 *   POST /api/check                run harness-sync.sh --check (streamed)
 *   POST /api/sync                 run harness-sync.sh --all (streamed)
 *
 * Per-target packages live as `packages=a,b` tokens on the targets-list line
 * (`<dir> [public] [packages=csv]`; absent = all packages — the full-set policy
 * default). Unknown package names are refused, never silently stamped.
 *
 * Usage: node tools/factory-ui/serve.ts [--port N]   (default 8471)
 */
import * as http from "node:http";
import * as fs from "node:fs";
import * as path from "node:path";
import { spawn } from "node:child_process";

type Pkg = { blurb?: string; skills: string[]; agents?: string[]; hooks?: string[]; requires?: string[]; budget?: { spine: number; loaded: number } };
type Target = { dir: string; public: boolean; packages: string[] | null };

const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..", "..");
const MANIFEST = path.join(ROOT, "skills", "packages.json");
const HARNESSES = path.join(ROOT, "harnesses.json");
const CONSUMER = path.join(ROOT, "lint", "consumer.py");
const SYNC = path.join(ROOT, "harness-sync.sh");

function reposRoot(): string {
  try {
    const h = JSON.parse(fs.readFileSync(HARNESSES, "utf8"));
    const r = String(h.repos_root || "").replace(/^~(?=\/|$)/, process.env.HOME || "");
    return r || "";
  } catch { return ""; }
}
function targetsListPath(): string {
  return path.join(reposRoot(), "infrastructure", "ac-deploy-targets.list");
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

function readTargets(): { targets: Target[]; note: string } {
  const p = targetsListPath();
  if (!fs.existsSync(p)) return { targets: [], note: `targets list missing: ${p} — per-target packages have no file to edit` };
  const out: Target[] = [];
  for (const rawLine of fs.readFileSync(p, "utf8").split("\n")) {
    const line = rawLine.split("#")[0].trim();
    if (!line) continue;
    const toks = line.split(/\s+/);
    const dir = toks[0];
    let pub = false, pkgs: string[] | null = null;
    for (const t of toks.slice(1)) {
      if (t === "public") pub = true;
      else if (t.startsWith("packages=")) pkgs = t.slice("packages=".length).split(",").map((s) => s.trim()).filter(Boolean);
    }
    out.push({ dir, public: pub, packages: pkgs });
  }
  return { targets: out, note: "" };
}

function readHarnesses(): { names: string[]; enabled: Record<string, boolean>; note: string } {
  try {
    const h = JSON.parse(fs.readFileSync(HARNESSES, "utf8"));
    const names = Object.keys(h.harnesses || {});
    const enabled: Record<string, boolean> = {};
    for (const n of names) enabled[n] = h.harnesses[n].enabled !== false;
    return { names, enabled, note: "" };
  } catch (e) { return { names: [], enabled: {}, note: `harnesses.json unreadable: ${String(e)}` }; }
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
  const { targets, note: tNote } = readTargets();
  if (tNote) notes.push(tNote);
  const { names, enabled, note: hNote } = readHarnesses();
  if (hNote) notes.push(hNote);
  return { root: ROOT, order, pkgs, skills, targets, harnesses: names, enabled, notes };
}

function writeManifest(order: string[], pkgs: Record<string, Pkg>, raw: Record<string, unknown>): void {
  const out: Record<string, unknown> = {};
  for (const k of Object.keys(raw)) if (k.startsWith("_")) out[k] = raw[k];
  for (const k of order) out[k] = pkgs[k];
  fs.writeFileSync(MANIFEST, JSON.stringify(out, null, 2) + "\n");
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
<style>body{font-family:system-ui,sans-serif;max-width:1100px;margin:2em auto;padding:0 1em}table{border-collapse:collapse;margin:1em 0}td,th{border:1px solid #ccc;padding:.25em .5em;font-size:.85em}pre{background:#111;color:#eee;padding:1em;overflow:auto;max-height:30em}.note{background:#fff8e1;padding:.5em}</style>
</head><body><h1>factory matrix</h1><div id="notes"></div>
<h2>packages × skills <small>(edits skills/packages.json)</small></h2><div id="pkgs"></div>
<h2>targets × packages <small>(edits the targets list)</small></h2><div id="tgts"></div>
<h2>harnesses <small>(edits harnesses.json enabled flags)</small></h2><div id="harn"></div>
<h2>run</h2><div id="v"></div>
<p><button onclick="run('/api/check')">Check (harness-sync.sh --check)</button>
<button onclick="run('/api/sync')">Sync (harness-sync.sh --all)</button></p>
<pre id="out"></pre>
<script>
let S=null;
async function load(){S=await(await fetch('/api/state')).json();
document.getElementById('notes').innerHTML=S.notes.map(n=>'<p class="note">'+n+'</p>').join('');
let h='<table><tr><th>skill</th>'+S.order.map(p=>'<th>'+p+'</th>').join('')+'</tr>';
for(const s of S.skills){h+='<tr><td>'+s+'</td>'+S.order.map(p=>'<td><input type="checkbox" '+(S.pkgs[p].skills.includes(s)?'checked':'')+' onchange="member(\\''+p+'\\',\\''+s+'\\',this.checked)"></td>').join('')+'</tr>';}
document.getElementById('pkgs').innerHTML=h+'</table>';
h='<table><tr><th>target</th>'+S.order.map(p=>'<th>'+p+'</th>').join('')+'<th></th></tr>';
for(const t of S.targets){const eff=t.packages||S.order;h+='<tr><td>'+t.dir+(t.public?' (public)':'')+'</td>'+S.order.map(p=>'<td><input type="checkbox" '+(eff.includes(p)?'checked':'')+' onchange="tpkg(\\''+t.dir+'\\',\\''+p+'\\',this.checked)"></td>').join('')+'<td><button onclick="treset(\\''+t.dir+'\\')">all</button> <button onclick="verify(\\''+t.dir+'\\')">verify</button></td></tr>';}
document.getElementById('tgts').innerHTML=h+'</table>'||'<p>no targets</p>';
document.getElementById('harn').innerHTML=S.harnesses.map(n=>'<label><input type="checkbox" '+(S.enabled[n]?'checked':'')+' onchange="hen(\\''+n+'\\',this.checked)"> '+n+'</label> ').join('');
let v='';for(const t of S.targets)v+='<button onclick="verify(\\''+t.dir+'\\')">verify '+t.dir+'</button> ';
document.getElementById('v').innerHTML=v;}
async function post(u,b){const r=await fetch(u,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(b)});if(!r.ok)alert(await r.text());await load();}
function member(p,s,on){post('/api/packages/member',{package:p,skill:s,present:on});}
function tpkg(t,p,on){post('/api/targets/package',{target:t,package:p,present:on});}
function treset(t){post('/api/targets/reset',{target:t});}
function hen(n,on){post('/api/harness/enabled',{harness:n,enabled:on});}
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
    if (req.method === "POST" && url.pathname === "/api/packages/member") {
      const b = await readBody(req) as { package: string; skill: string; present: boolean };
      const { order, pkgs, raw } = readManifest();
      if (!pkgs[b.package]) { json(res, 400, { error: `unknown package '${b.package}'` }); return; }
      if (!fs.existsSync(path.join(ROOT, "skills", String(b.skill), "SKILL.md"))) { json(res, 400, { error: `no such skill '${b.skill}'` }); return; }
      const cur = [...(pkgs[b.package].skills || [])];
      if (b.present) { if (!cur.includes(String(b.skill))) cur.push(String(b.skill)); }
      else { const i = cur.indexOf(String(b.skill)); if (i >= 0) cur.splice(i, 1); }
      if (cur.length === 0) { json(res, 400, { error: `refusing to empty package '${b.package}'` }); return; }
      pkgs[b.package].skills = cur;
      writeManifest(order, pkgs, raw);
      json(res, 200, { ok: true }); return;
    }
    if (req.method === "POST" && url.pathname === "/api/targets/package") {
      const b = await readBody(req) as { target: string; package: string; present: boolean };
      const { order } = readManifest();
      if (!order.includes(String(b.package))) { json(res, 400, { error: `unknown package '${b.package}'` }); return; }
      const p = targetsListPath();
      if (!fs.existsSync(p)) { json(res, 400, { error: `targets list missing: ${p}` }); return; }
      const lines = fs.readFileSync(p, "utf8").split("\n");
      let hit = false;
      const next = lines.map((rawLine) => {
        const code = rawLine.split("#")[0]; const comment = rawLine.slice(code.length);
        if (!code.trim()) return rawLine;
        const toks = code.trim().split(/\s+/);
        if (toks[0] !== b.target) return rawLine;
        hit = true;
        const rest = toks.slice(1).filter((t) => t !== "public" && !t.startsWith("packages="));
        const pub = toks.slice(1).includes("public");
        const m = toks.slice(1).find((t) => t.startsWith("packages="));
        const eff = new Set(m ? m.slice("packages=".length).split(",").map((s) => s.trim()).filter(Boolean) : order);
        if (b.present) eff.add(String(b.package)); else eff.delete(String(b.package));
        const tail = [...(pub ? ["public"] : []), ...rest.filter((t) => t !== "public"), `packages=${[...eff].join(",")}`];
        return `${toks[0]}${tail.length ? " " + tail.join(" ") : ""}${comment ? " " + comment.trim() : ""}`.trimEnd();
      });
      if (!hit) { json(res, 400, { error: `unknown target '${b.target}'` }); return; }
      fs.writeFileSync(p, next.join("\n"));
      json(res, 200, { ok: true }); return;
    }
    if (req.method === "POST" && url.pathname === "/api/targets/reset") {
      const b = await readBody(req) as { target: string };
      const p = targetsListPath();
      if (!fs.existsSync(p)) { json(res, 400, { error: `targets list missing: ${p}` }); return; }
      let hit = false;
      const next = fs.readFileSync(p, "utf8").split("\n").map((rawLine) => {
        const code = rawLine.split("#")[0];
        if (!code.trim()) return rawLine;
        const toks = code.trim().split(/\s+/);
        if (toks[0] !== b.target) return rawLine;
        hit = true;
        return [toks[0], ...toks.slice(1).filter((t) => !t.startsWith("packages="))].join(" ");
      });
      if (!hit) { json(res, 400, { error: `unknown target '${b.target}'` }); return; }
      fs.writeFileSync(p, next.join("\n"));
      json(res, 200, { ok: true }); return;
    }
    if (req.method === "POST" && url.pathname === "/api/harness/enabled") {
      const b = await readBody(req) as { harness: string; enabled: boolean };
      const h = JSON.parse(fs.readFileSync(HARNESSES, "utf8"));
      if (!h.harnesses || !h.harnesses[b.harness]) { json(res, 400, { error: `unknown harness '${b.harness}'` }); return; }
      h.harnesses[b.harness].enabled = !!b.enabled;
      fs.writeFileSync(HARNESSES, JSON.stringify(h, null, 2) + "\n");
      json(res, 200, { ok: true }); return;
    }
    if (req.method === "POST" && url.pathname === "/api/verify") {
      const b = await readBody(req) as { target: string };
      const dir = path.join(ROOT, "..", String(b.target).replace(/[^A-Za-z0-9_.-]/g, ""));
      if (!fs.existsSync(dir)) { json(res, 400, { error: `target dir missing: ${dir}` }); return; }
      streamCmd(res, "python3", [CONSUMER, dir], ROOT); return;
    }
    if (req.method === "POST" && url.pathname === "/api/check") { streamCmd(res, "bash", [SYNC, "--all", "--check"], ROOT); return; }
    if (req.method === "POST" && url.pathname === "/api/sync") { streamCmd(res, "bash", [SYNC, "--all"], ROOT); return; }
    json(res, 404, { error: "not found" });
  } catch (e) { json(res, 500, { error: String(e) }); }
});

const port = Number(process.argv.includes("--port") ? process.argv[process.argv.indexOf("--port") + 1] : 8471);
server.listen(port, "127.0.0.1", () => console.log(`factory-ui on http://127.0.0.1:${port} (root ${ROOT})`));
