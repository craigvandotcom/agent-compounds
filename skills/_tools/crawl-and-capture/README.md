# \_tools/crawl-and-capture

Shared full-app **crawl + screenshot** primitive. Visits every route in an app's
manifest, settles, and screenshots at a viewport set — wrapping `agent-browser`
with the mandatory discipline (one named session, **guaranteed finally-close**,
never `close --all`). Emits `index.json` so consumers iterate captures instead of
re-crawling.

**Capture once, consume twice** — one run feeds both:

- **`ac-qa-browser`** — functional QA (run `errors`/console/web-shell checklist per route)
- **`ac-ui-polish`** — whole-app visual conformance vs `CORE/design.md`

Neither skill re-implements the crawl loop; both call this.

## Usage

```bash
node _tools/crawl-and-capture/crawl-and-capture.mjs \
  --base-url http://localhost:3000 \
  --manifest .claude/skills/CORE/journeys/routes.md \
  --out .crawl-out \
  --viewports 320x844,390x844,428x926
```

| Flag | Default | Notes |
|------|---------|-------|
| `--base-url` | _(required)_ | dev server / preview / prod origin |
| `--manifest` | _(required)_ | the app's `routes.md` (format below) |
| `--out` | `.crawl-out` | screenshots + `index.json` land here |
| `--viewports` | `320x844,390x844,428x926` | `WxH` CSV; the app's declared set |
| `--auth-script` | _(none)_ | app-owned login (see below); without it, `(auth)` routes are **skipped, not failed** |
| `--session` | `crawl-and-capture` | distinct name so teardown is unambiguous |
| `--settle` | `networkidle` | `agent-browser wait --load` mode |
| `--downscale` | _(off)_ | `sips -Z <px>` each png (macOS) — keeps the model image cap happy on big crawls |
| `--limit` | _(all)_ | cap route count for smoke runs |

## Manifest format (`CORE/journeys/routes.md`)

One route per line: **first token = path, rest = label**. `#`/`##` lines and blanks
are ignored (so markdown headers + commented-out dynamic routes are skipped by
design). A label containing **`(auth)`** marks a login-gated route.

```
/                       home
/login                  login
/app                    app home / dashboard (auth)
```

## Auth-gated routes

Login is **app-specific** (field refs are discovered at runtime via `snapshot`, so a
generic tool can't hardcode them). Provide `--auth-script <path>`; it's invoked once,
before the first `(auth)` route, as:

```bash
bash <auth-script> <session-name> <base-url>
```

and must leave that `agent-browser` session signed in (creds from the app's
`.env.local` / `environments.md`). Without it, auth routes are skipped and counted
in the summary (no silent caps). Public routes always crawl.

## Output

`<out>/index.json`:

```jsonc
{
  "base": "...", "capturedAt": "ISO", "viewports": ["320x844", ...],
  "counts": { "routes": 16, "captured": 16, "errors": 0, "skippedAuth": 0 },
  "routes": [{ "path": "/login", "label": "login", "auth": false,
               "shots": [{ "viewport": "390x844", "file": ".crawl-out/login@390x844.png" }] }]
}
```

Screenshots: `<out>/<route-slug>@<WxH>.png` (e.g. `app-foods-view@390x844.png`).

**Exit codes:** `0` all attempted routes captured clean · `1` ≥1 route errored
(index still written with per-route status) · `2` setup/usage error.

## Requires

`agent-browser` on PATH (`npm i -g agent-browser`). CLI mechanics + the runaway-CPU
teardown rationale: `browser-testing/SKILL.md`. Theme/appearance matrix (light/dark)
is run per-route by the consuming skill's checklist — this primitive captures at the
app's default theme; multi-theme capture is a future flag.
