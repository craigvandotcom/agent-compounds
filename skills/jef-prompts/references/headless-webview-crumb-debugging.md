# Headless WKWebView debugging via a11y-readable crumb trail

**When to use:** a Capacitor/WKWebView app misbehaves at runtime (hang, silent no-op)
and you have no Safari Web Inspector (headless agent session, sim or device). The JS
console is unreachable; `log stream` shows nothing JS-side; `document.title` crumbs get
clobbered by the framework's title management.

**The recipe (proven 2026-07-07 — found a 5-layer paywall hang in one build cycle after
hours of log-fishing failed):**

1. **Instrument with an env-gated crumb trail** in the suspect module:
   ```ts
   export const crumbs: string[] = [];
   export function crumb(step: string) {
     if (process.env.NEXT_PUBLIC_XXX_DEBUG !== '1') return;
     crumbs.push(`${Date.now() % 100000}:${step}`);
     try { window.dispatchEvent(new CustomEvent('debug-crumb')); } catch {}
   }
   ```
   Drop `crumb('phase:detail')` before/after EVERY await in the suspect chain — the gap
   between the last crumb that fired and the first that didn't IS the hang point.

2. **Render the trail into a component the flow already shows** (gated on the same env
   flag), with the full trail in an `aria-label`:
   ```tsx
   {process.env.NEXT_PUBLIC_XXX_DEBUG === '1' && (
     <p aria-label={`debug tick${tick}: ${crumbs.join(' > ')}`}>…</p>
   )}
   ```
   Re-render via a listener on the custom event + a 2s interval tick.

3. **Read it headlessly** with any a11y-tree tool (`agent-device snapshot -i | grep debug`).
   The a11y tree is the one channel that survives headless: no console, no network tap,
   no title needed.

4. Build with the flag on (`NEXT_PUBLIC_XXX_DEBUG="1"` in the build env), drive the flow,
   read the trail. Strip the flag from the build env before shipping — the instrument
   code itself can stay (inert, tree-shaken or no-op).

**Why not document.title:** frameworks (Next.js metadata) rewrite it on render, eating
crumbs mid-trail — the evidence self-destructs. The DOM+aria-label sink is owned by you.

**Parameters:** the env flag name; the module to instrument; the component to render into
(must be visible in the broken state — e.g. the stuck screen itself).
