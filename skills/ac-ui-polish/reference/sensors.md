# Reference: Sensors — the programmatic audit layer

**Why this file exists.** A UI-polish pass that relies only on a human-or-agent
*looking* at screens has a structural blind spot: it sees one theme, one data
state, and it cannot perceive a 3.9:1 contrast ratio or a hardcoded `#0c1014`
that happens to look fine in the theme you're viewing. Real defects shipped
because the audit was visual-only and dark-only.

**The rule: sensors run FIRST, before the visual rubric, on every matrix cell.**
They are deterministic, cheap, and catch the entire class of "looks fine in the
theme I checked" bugs that eyes miss. The visual rubric (`critique-polish.md`)
then judges *taste*; the sensors judge *correctness*. Both are required.

These sensors are **generic** — the method lives here. The app-specific inputs
(how to toggle theme, the CSS token file, the component dirs, the seed + deployed
URL) live in the app's CORE (for Body Compass: `CORE/ui-audit.md`).

---

## Sensor 1 — Contrast sweep (per theme) — catches "text too light to see"

Run this in the browser via `agent-browser … eval` **once per theme** on every
captured route. It walks every text-bearing element, resolves the effective
background (climbing ancestors through transparent layers), blends the text
colour's own alpha, computes the WCAG contrast ratio, and reports every node
under threshold (4.5:1 body, 3:1 large/bold). Pure measurement — no eyeballing.

```js
(() => {
  const parse = c => { const m = (c||'').match(/rgba?\(([^)]+)\)/); if (!m) return null;
    const p = m[1].split(/[\s,/]+/).map(s => parseFloat(s)).filter(n => !Number.isNaN(n));
    return { r:p[0], g:p[1], b:p[2], a:p[3]==null?1:p[3] }; };
  const lin = v => { v/=255; return v<=0.03928 ? v/12.92 : Math.pow((v+0.055)/1.055, 2.4); };
  const lum = c => 0.2126*lin(c.r) + 0.7152*lin(c.g) + 0.0722*lin(c.b);
  const ratio = (a,b) => { const L1=lum(a), L2=lum(b), hi=Math.max(L1,L2), lo=Math.min(L1,L2); return (hi+0.05)/(lo+0.05); };
  const bgOf = el => { let n = el; while (n) { const bg = parse(getComputedStyle(n).backgroundColor);
    if (bg && bg.a >= 0.95) return bg; n = n.parentElement; } return { r:255, g:255, b:255, a:1 }; };
  // Worst-case stop, never an average: a gradient that is AA on the first stop
  // and 1.61:1 on the yellow stop must fail. getComputedStyle resolves hsl()/var()
  // to rgb() so this regex sees the painted colours.
  const stopsOf = img => {
    const out = [];
    const re = /rgba?\(([^)]+)\)/g;
    let m; while ((m = re.exec(img || ''))) {
      const c = parse('rgb(' + m[1] + ')'); if (c) out.push(c);
    }
    return out;
  };
  const hasText = el => [...el.childNodes].some(n => n.nodeType === 3 && n.textContent.trim());
  const out = [], unmeas = [];
  document.querySelectorAll('body *').forEach(el => {
    if (!hasText(el)) return;
    const s = getComputedStyle(el);
    if (s.visibility === 'hidden' || s.display === 'none' || +s.opacity === 0) return;
    const fg = parse(s.color); if (!fg) return;
    const bg = bgOf(el);
    const size = parseFloat(s.fontSize), bold = (parseInt(s.fontWeight) || 400) >= 700;
    const min = (size >= 24 || (bold && size >= 18.66)) ? 3 : 4.5;
    const rec = (cr, extra) => ({ t: el.textContent.trim().slice(0,40), cr: Math.round(cr*100)/100, min,
      color: s.color, bg: `rgb(${Math.round(bg.r)},${Math.round(bg.g)},${Math.round(bg.b)})`,
      cls: (el.className?.toString?.() || '').slice(0,70), ...extra });
    // Alpha-0 (bg-clip-text): NEVER blend transparent color against bg — that
    // collapses to cr===1.0 and is triaged as noise. Measure the gradient.
    if (fg.a === 0) {
      const stops = stopsOf(s.backgroundImage);
      if (!stops.length) { unmeas.push(rec(0, { why: 'alpha-0 and no parseable backgroundImage' })); return; }
      let worst = Infinity, worstStop = stops[0];
      for (const st of stops) { const cr = ratio(st, bg); if (cr < worst) { worst = cr; worstStop = st; } }
      if (worst < min) out.push(rec(worst, { stop: `rgb(${Math.round(worstStop.r)},${Math.round(worstStop.g)},${Math.round(worstStop.b)})` }));
      return;
    }
    const a = fg.a;
    const eff = { r: fg.r*a + bg.r*(1-a), g: fg.g*a + bg.g*(1-a), b: fg.b*a + bg.b*(1-a) };
    const cr = ratio(eff, bg);
    if (cr < min) out.push(rec(cr, {}));
  });
  const dedupe = arr => { const seen = new Set(), uniq = [];
    for (const f of arr) { const k = f.t + f.cls; if (!seen.has(k)) { seen.add(k); uniq.push(f); } }
    return uniq; };
  const failures = dedupe(out), unmeasurable = dedupe(unmeas);
  return JSON.stringify({ theme: document.documentElement.className,
    failures: failures.length, unmeasurable: unmeasurable.length,
    items: failures.slice(0,40), unmeasurableItems: unmeasurable.slice(0,20) });
})()
```

- **Pass = `failures === 0` AND `unmeasurable === 0` in BOTH themes.** An
  `unmeasurable` node is not a pass and not a bare `cr: 1` — it is a loud
  fail (the sensor could not resolve paint). Each `failures` item is a finding
  (≥ High): `text "Broccoli" cr 1.3 < 4.5 on rgb(255,255,255)`.
- **Worst-case gradient stop, never an average.** `bg-clip-text` paints the
  `backgroundImage` gradient; computed `color` is `rgba(0,0,0,0)`. Score every
  parsed rgb() stop against the resolved background and keep the **lowest**
  ratio. Averaging (or taking the first stop) would hide the 1.61:1 yellow
  stop on the auth headline (704ab9a3^).
- Limitations: it assumes white behind background *images*; manually check text
  over photos. It can't judge *aesthetic* low-contrast intent — that's the rubric's job.
- This overlaps `web-design-guidelines` (a11y compliance). Use that skill's audit
  for the authoritative WCAG pass; this sweep is the fast in-loop sensor so polish
  never *introduces* a contrast regression between rubric runs.

## Sensor 1b — Theme-blind image sources — catches `*-white.*` / `*-black.*` on flipping surfaces

A theme-blind **asset** (white logo on a light card) is invisible to Sensor 1:
computed text colour and class strings are fine; the *image source* is wrong.

```js
(() => {
  const flipping = el => { let n = el; while (n) {
    const c = (n.className?.toString?.() || '');
    if (/\b(card|bg-background|bg-card|bg-surface|theme-flip)\b/.test(c) || n === document.documentElement) return true;
    n = n.parentElement; } return false; };
  const hits = [];
  document.querySelectorAll('img, [style*="background-image"], [class*="bg-["]').forEach(el => {
    const src = el.getAttribute('src') || el.getAttribute('srcset') || getComputedStyle(el).backgroundImage || '';
    const m = src.match(/(?:^|\/)([^/"']+-(?:white|black)\.[a-zA-Z0-9]+)/);
    if (!m) return;
    if (!flipping(el)) return;
    hits.push({ src: m[1], tag: el.tagName, cls: (el.className?.toString?.() || '').slice(0,70) });
  });
  return JSON.stringify({ themeBlind: hits.length, items: hits.slice(0,20) });
})()
```

- **Pass = `themeBlind === 0`.** A `*-white.*` / `*-black.*` source on a
  theme-flipping surface (card / `bg-background` / `bg-card`) is a finding
  (≥ High) — swap to a tokenized or dual-asset treatment. A white mark on a
  permanently-dark overlay is out of scope (Sensor 2's "legitimate text-white"
  carve-out).

## Sensor 2 — Hardcoded-colour grep — catches raw values at the source

`design.md` says *"never raw Tailwind colors / use semantic tokens."* That rule
is greppable. Run over the app's component dirs (CORE names them):

```bash
# Raw colour literals in components (hex / rgb / hsl)
rg -n --glob '*.tsx' --glob '*.ts' \
  -e '#[0-9a-fA-F]{3,8}\b' -e 'rgba?\(' -e 'hsla?\(' \
  <component-dirs> | rg -v '__tests__|\.test\.'

# Hardcoded Tailwind black/white text+bg (theme-blind by definition).
# The trailing \b sits before `/`, so this ALSO matches alpha forms (`bg-white/6`).
rg -n --glob '*.tsx' -e '\b(text|bg)-(white|black)\b' <component-dirs>

# Split the two shapes — they triage differently (see below). --pcre2 is REQUIRED for
# the lookahead; without it rg exits non-zero with a parse error and prints NOTHING.
# Empty output from this command is not a count of zero until you check the exit status.
rg -n --glob '*.tsx' -e 'bg-(white|black)/[0-9]' <component-dirs>          # ALPHA form
rg --pcre2 -n --glob '*.tsx' -e '\bbg-(white|black)\b(?!/)' <component-dirs>  # BARE form

# Inline style colour/background (escapes the token system)
rg -n --glob '*.tsx' -e 'style=\{\{[^}]*(color|background)' <component-dirs>
```

**Triage, don't auto-fail.** A hit is a *candidate*, not a guaranteed bug:
- Legitimate: `text-white` on a permanently-dark surface (e.g. `bg-black/50`
  photo overlay) is correct in both themes — keep it.
- Bug: any raw colour or `text-white`/`bg-black` on a surface that *flips* with
  the theme (card, page, navbar, list row). These are the `#0c1014` FAB face and
  the `rgba(13,20,18)` meal-icon circle from the failure case.
- For each hit, ask: *does this surface change between light and dark?* If yes →
  it must be a token, not a literal → finding.

### ALPHA on a STRUCTURAL element is the class that keeps escaping

`bg-white/6` reads as a harmless tint. On a theme-flipping surface it is not: in dark
mode it is the element's entire visible structure, and in light mode it inverts to
near-invisible, so the container, its header band, its row dividers and its active-chip
state all vanish at once. The screen still *renders*, so contrast and false-clean evals
stay green while the structure is gone.

- **STRUCTURAL** = container / card, divider or border, filter or segment chip, progress
  or slider track, table header band, row hover. On a theme-flipping surface these are a
  **finding**, alpha or not. Correct token: **`bg-foreground/N`** (and
  `border-foreground/N`), which inverts with the theme and preserves the same tint.
  Worked example: `bg-white/6` → `bg-foreground/6`.
- **OVERLAY** = a scrim, photo/video wash, or any layer over permanently-dark content
  (a landing hero, a media surface). `bg-white/4` there is CORRECT — the surface never
  flips. Not a finding.
- **BRAND-LOCKED** = a third-party brand colour that is theme-invariant BY SPEC — a
  Google (`bg-white`) or Apple (`bg-black`) sign-in button face. Exempt, and it is
  normally BARE (no alpha), so the alpha regex misses it entirely. Classify it
  explicitly as brand-locked rather than leaving the next auditor to guess; a bare
  `bg-white`/`bg-black` that is NOT a third-party brand mark is a finding.

**False-positive budget** — a rule that flags every alpha hit runs ~40% false positives
on a real app (overlay-heavy landing/marketing components dominate the misses), and one
that flags none misses ~60%. Neither is acceptable, and neither is decidable from the
regex: the ALPHA/BARE split narrows it, but the STRUCTURAL vs OVERLAY vs BRAND-LOCKED
call is the triage and it needs the surrounding element. Judge each hit by the element it
paints, never by the utility alone — and report the surviving count per route, because a
run-level codebase grep has no cell to block.

## Sensor 3 — Token symmetry — catches "the token only exists in one theme"

Any CSS custom property used as a **surface or text colour** must be defined in
*both* theme blocks (e.g. `:root.light` and `:root.dark`). A var defined only in
the bare `:root` (or only one theme) silently keeps a stale value when the theme
flips — the `--fab-face` failure. The app's design.md already asserts the token
sets "must be symmetric"; this makes it checkable.

Concept (the app's CI ships the exact script — for BCA it's a `quality-gate`
step over `app/globals.css`):

```bash
# Extract --var names from each theme block, diff them. Any var in one block but
# not the other (and not intentionally global) is an asymmetry finding.
```

**Pass = the light and dark token sets are symmetric** (modulo vars that are
deliberately theme-independent, which should live in the shared `:root` and never
encode a surface/text colour).

## Sensor 4 — False-clean check — "empty ≠ clean"

*(from `ac-qa-browser`/`ac-qa-device` discipline rules — empty ≠ clean; a toast
is a finding.)* An errored view renders almost identically to a designed empty
state, so a silent data-fetch failure sails through as "empty state: OK." Before
marking any zero-content / empty-list cell audited, run:

```js
(() => {
  const txt = document.body.innerText;
  return JSON.stringify({
    errorBoundary: !!document.querySelector('[data-error-boundary], [role="alert"]'),
    retryButton: [...document.querySelectorAll('button,a')].some(b => /retry|try again|reload/i.test(b.textContent)),
    errorText: /(something went wrong|failed to load|couldn'?t load|error)/i.test(txt),
    consoleNote: 'also check the captured console-errors for this route',
  });
})()
```

- **A zero-count view that is actually errored is a ≥ High finding** — the error
  state was never *designed*, so the screen the user hits on failure is unstyled.
  It is NOT an "empty state" pass.
- **Toast text after a mutation is a finding** even if the operation succeeded —
  transient (~4 s) and easy to miss in a single screenshot; capture the state
  *during* the toast, or re-trigger to read it.
- Pair with the captured **console errors** for the route (the crawl primitive
  emits them): console noise on a "clean" screen is a finding.

## Sensor 5 — Transition specificity — catches `transition: all`

`transition: all` (and Tailwind's bare `transition`) makes the browser watch every
property and fires unintended transitions on colour/padding/shadow. Every recipe in
`recipes.md` names its properties; this finds the violations.

```bash
# CSS: literal `transition: all` / `transition-property: all`
rg -n --glob '*.css' --glob '*.scss' -e 'transition(-property)?\s*:\s*all' <component-dirs>

# Tailwind: bare `transition` token (= transition-property: all).
# Allowed forms have a suffix/bracket: transition-transform, transition-colors,
# transition-[scale,opacity], transition-none — those must NOT match.
rg -n --glob '*.tsx' -e '(^|["\s])transition(?=["\s])' <component-dirs>

# will-change misuse: `all`, or non-compositable props (background/color/etc.)
rg -n --glob '*.{css,scss,tsx}' -e 'will-change:\s*all' \
  -e 'will-change:\s*(background|border|color|width|height|top|left|margin|padding)' <component-dirs>
```

**Pass = zero hits.** A bare-`transition` hit is ≥ Medium; `transition: all` on an
interactive element that also changes colour/shadow is ≥ High (visible unwanted
fades). Fix → name the properties (`recipes.md` §9–10).

## Sensor 6 — Image outline — catches missing / tinted edges

`recipes.md` §3: every content `<img>`/`Image` gets a `1px` **pure black/white** /10
outline, never tinted. Both halves are greppable.

```bash
# Tinted outline = always wrong (picks up surface colour, reads as dirt)
rg -n --glob '*.tsx' -e 'outline-(slate|zinc|neutral|gray|stone)-' <component-dirs>

# Images — eyeball the hits for a missing or non-black/white outline class.
# (Presence is heuristic; flag any <img>/<Image> with no outline-*/-outline-offset.)
rg -n --glob '*.tsx' -e '<(img|Image)\b' <component-dirs>
```

**Triage:** a tinted-outline hit is a finding (≥ Medium) — switch to
`outline-black/10 dark:outline-white/10`. A content image with **no** outline is a
Low/Medium polish gap (decorative/full-bleed/avatar-with-own-treatment are
legitimate exceptions — judgement call, not auto-fail).

## Sensor 7 — Press-scale — catches exaggerated / missing tactile feedback

`recipes.md` §4: press-scale defaults to `0.96`, **never below `0.95`**.

```bash
# Sub-0.95 press scale (active:scale-[0.9], scale-90, whileTap scale 0.9, …)
rg -n --glob '*.tsx' \
  -e 'active:scale-\[0\.(9[0-4]|[0-8][0-9])\]' \
  -e 'active:scale-(75|80|90)\b' \
  -e 'whileTap=\{\{[^}]*scale:\s*0\.(9[0-4]|[0-8])' <component-dirs>
```

**Pass = zero hits.** Each is a finding (≥ Low): raise to `0.96` (or the app's
press-scale token). *Missing* press feedback on primary buttons is a taste-layer
call for the rubric, not this grep.

## Sensor 8 — Concentric radius (heuristic) — catches drifting nested corners

`recipes.md` §1: nested rounded surfaces need `outer = inner + padding`. Not fully
static-decidable, but the common slop pattern — **identical `rounded-*` on a padded
parent and its direct child** — is a strong candidate flag.

```bash
# Padded element whose own class set repeats a rounded-* token on a child nearby.
# Heuristic: list every rounded-* + p-* co-occurrence, then eyeball parent/child pairs.
rg -n --glob '*.tsx' -e 'rounded-(sm|md|lg|xl|2xl|3xl)\b' <component-dirs> \
  | rg 'p-[0-9]'
```

**Triage only** — confirm the parent/child relationship visually before filing.
Identical radius on a tightly-padded (`p-1`/`p-2`/`p-3`) parent+child is the bug;
large padding (> ~24px / `p-6`+) is exempt (treat as separate surfaces).

## Sensor 9 — Webfont actually renders — catches "the brand font silently never loaded"

The spec names a font (`design.md` `typography.*.fontFamily`). Whether that font is
**declared** is not whether it **renders** — a dropped `@import`, a build that strips a
manual `<link>`, a CDN that fails offline, or a wrong family name all leave the app on its
fallback while every naive check says "fine." **`document.fonts.check('16px "X"')` and
`getComputedStyle(el).fontFamily` are FALSE-POSITIVE traps** — `check()` returns true when
no matching face needs loading (i.e. it resolved via fallback), and computed style only
echoes the CSS *declaration*, not what painted. (This shipped a real regression: a brand
font declared via a second `@import` that the bundle dropped — every naive check passed,
the app rendered the system font app-wide, caught only by the measurement below.)

**Ground truth = glyph-width.** Render a string in the target family backed by a
known-different fallback; if the width equals the *pure fallback*, the webfont didn't load.
Use **two** different fallbacks (monospace AND serif) so a coincidental width match can't
fool it. Run once per route on the LIVE DOM (font is theme-independent — no need to sweep
themes), after `document.fonts.ready`:

```js
(async () => {
  await document.fonts.ready;
  // FAMILIES = the app's declared fonts from CORE/design.md typography.fontFamily
  const FAMILIES = ['General Sans'];           // ← replace per app
  const measure = (family) => { const s = document.createElement('span');
    s.style.cssText = 'position:absolute;visibility:hidden;white-space:nowrap;font:100px ' + family;
    s.textContent = 'WwMmIl1 mgqypj 0123'; document.body.appendChild(s);
    const w = s.getBoundingClientRect().width; s.remove(); return w; };
  const out = FAMILIES.map(f => {
    const vsMono = Math.abs(measure(`"${f}", monospace`) - measure('monospace'));
    const vsSerif = Math.abs(measure(`"${f}", serif`) - measure('serif'));
    return { family: f, renders: vsMono > 1 && vsSerif > 1,    // differs from BOTH fallbacks
             fontsCheckSays: document.fonts.check(`16px "${f}"`) };  // the lying signal, for contrast
  });
  return JSON.stringify({ fonts: out });
})()
```

- **Pass = `renders: true` for every declared font.** `renders:false` while `fontsCheckSays:true`
  is the exact false-positive footprint → ≥ High (the app is not on its specified typeface).
- Corroborate: `[...document.fonts].map(f=>f.family+':'+f.status)` should list the font as
  `loaded`; `performance.getEntriesByType('resource')` should show its file fetched.
- Fix path when it fails: prefer **`next/font/local`** (self-host) over a CDN `@import`/`<link>` —
  build-safe and offline-correct (`recipes.md` §11).

## Sensor 10 — Stacked shadow utilities — catches muddy doubled elevation

`recipes.md` §14: **one shadow utility per element per state.** Two arbitrary
`shadow-[…]` strings on one element — or a named tier plus a default `shadow-*`
scale token — double-render and muddy the edge. The stacked case is greppable.

```bash
# Two+ shadow utilities on one element (arbitrary strings and/or scale tokens)
rg -n --glob '*.tsx' -e 'shadow-\[[^]]*\][^>]*shadow-' <component-dirs>

# A named arbitrary shadow AND a default shadow-scale token on the same element
rg -n --glob '*.tsx' -e 'shadow-\[[^]]*\][^>]*shadow-(sm|md|lg|xl|2xl)\b' <component-dirs>
```

**Pass = zero hits.** Each is a finding (≥ Medium): keep the single tier that matches
the surface (`recipes.md` §14) and drop the rest. A `hover:`/`active:` state that
*genuinely* changes elevation swaps to a different **single** tier — that is not
stacking, and won't match (the two utilities carry distinct state prefixes).

---

## Running the sensors

1. **Per theme, per route.** Force each theme (CORE documents the mechanism —
   localStorage key + root class, or `prefers-color-scheme` emulation), then run
   Sensor 1 (contrast) and Sensor 4 (false-clean) on each captured route. Never
   audit a single theme.
1b. **Once per route (live, theme-independent).** Sensor 9 (webfont renders) — run it
   on the first rendered route; the font is global, so a single `renders:false` is an
   app-wide finding. Cheap insurance against shipping on the fallback font.
2. **Once at repo level.** Sensors 2, 3, 5, 6, 7, 8, and 10 are static greps — run
   them over the codebase before touching the browser; they point you straight at the
   offending lines. (5–8 and 10 enforce the canonical values in `recipes.md`.)
3. **Feed the visual pass.** Sensor output is the *first* set of findings on the
   matrix; the visual rubric adds taste findings on top. A cell is not "audited"
   until both have run and its artifact is captured.

**Sensors are necessary, not sufficient.** They catch correctness (contrast,
hardcoded values, token gaps) and canonical-value violations (transition/will-change
specificity, image outlines, press-scale, nested radii, shadow stacking). They do **not** judge
hierarchy, rhythm, depth, or slop — that is `critique-polish.md` + the craft
references. Run both.
