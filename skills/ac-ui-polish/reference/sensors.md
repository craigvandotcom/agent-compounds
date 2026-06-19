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
    const p = m[1].split(',').map(s => parseFloat(s)); return { r:p[0], g:p[1], b:p[2], a:p[3]==null?1:p[3] }; };
  const lin = v => { v/=255; return v<=0.03928 ? v/12.92 : Math.pow((v+0.055)/1.055, 2.4); };
  const lum = c => 0.2126*lin(c.r) + 0.7152*lin(c.g) + 0.0722*lin(c.b);
  const ratio = (a,b) => { const L1=lum(a), L2=lum(b), hi=Math.max(L1,L2), lo=Math.min(L1,L2); return (hi+0.05)/(lo+0.05); };
  const bgOf = el => { let n = el; while (n) { const bg = parse(getComputedStyle(n).backgroundColor);
    if (bg && bg.a >= 0.95) return bg; n = n.parentElement; } return { r:255, g:255, b:255, a:1 }; };
  const hasText = el => [...el.childNodes].some(n => n.nodeType === 3 && n.textContent.trim());
  const out = [];
  document.querySelectorAll('body *').forEach(el => {
    if (!hasText(el)) return;
    const s = getComputedStyle(el);
    if (s.visibility === 'hidden' || s.display === 'none' || +s.opacity === 0) return;
    const fg = parse(s.color); if (!fg) return;
    const bg = bgOf(el), a = fg.a;
    const eff = { r: fg.r*a + bg.r*(1-a), g: fg.g*a + bg.g*(1-a), b: fg.b*a + bg.b*(1-a) };
    const cr = ratio(eff, bg);
    const size = parseFloat(s.fontSize), bold = (parseInt(s.fontWeight) || 400) >= 700;
    const min = (size >= 24 || (bold && size >= 18.66)) ? 3 : 4.5;
    if (cr < min) out.push({ t: el.textContent.trim().slice(0,40), cr: Math.round(cr*100)/100, min,
      color: s.color, bg: `rgb(${Math.round(bg.r)},${Math.round(bg.g)},${Math.round(bg.b)})`,
      cls: (el.className?.toString?.() || '').slice(0,70) });
  });
  const seen = new Set(), uniq = [];
  for (const f of out) { const k = f.t + f.cls; if (!seen.has(k)) { seen.add(k); uniq.push(f); } }
  return JSON.stringify({ theme: document.documentElement.className, failures: uniq.length, items: uniq.slice(0,40) });
})()
```

- **Pass = `failures: 0` in BOTH themes.** Each failure is a finding (≥ High):
  `text "Broccoli" cr 1.3 < 4.5 on rgb(255,255,255)` → the ingredient-name bug,
  surfaced objectively.
- Limitations: it assumes white behind background *images*; manually check text
  over photos. It can't judge *aesthetic* low-contrast intent — that's the rubric's job.
- This overlaps `web-design-guidelines` (a11y compliance). Use that skill's audit
  for the authoritative WCAG pass; this sweep is the fast in-loop sensor so polish
  never *introduces* a contrast regression between rubric runs.

## Sensor 2 — Hardcoded-colour grep — catches raw values at the source

`design.md` says *"never raw Tailwind colors / use semantic tokens."* That rule
is greppable. Run over the app's component dirs (CORE names them):

```bash
# Raw colour literals in components (hex / rgb / hsl)
rg -n --glob '*.tsx' --glob '*.ts' \
  -e '#[0-9a-fA-F]{3,8}\b' -e 'rgba?\(' -e 'hsla?\(' \
  <component-dirs> | rg -v '__tests__|\.test\.'

# Hardcoded Tailwind black/white text+bg (theme-blind by definition)
rg -n --glob '*.tsx' -e '\b(text|bg)-(white|black)\b' <component-dirs>

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

---

## Running the sensors

1. **Per theme, per route.** Force each theme (CORE documents the mechanism —
   localStorage key + root class, or `prefers-color-scheme` emulation), then run
   Sensor 1 (contrast) and Sensor 4 (false-clean) on each captured route. Never
   audit a single theme.
2. **Once at repo level.** Sensors 2 and 3 are static — run them over the codebase
   before touching the browser; they point you straight at the offending lines.
3. **Feed the visual pass.** Sensor output is the *first* set of findings on the
   matrix; the visual rubric adds taste findings on top. A cell is not "audited"
   until both have run and its artifact is captured.

**Sensors are necessary, not sufficient.** They catch correctness (contrast,
hardcoded values, token gaps). They do **not** judge hierarchy, rhythm, depth, or
slop — that is `critique-polish.md` + the craft references. Run both.
