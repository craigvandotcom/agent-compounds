# Browser-agent capture (fallback path)

Read this when Phase 3 selects Option C — no dedicated capture script exists and the
screenshots are of a web surface. One browser agent per manifest screenshot.

## Setup — confirm parameters with the user

First, check for auth details in project files (`.env.local`, `CLAUDE.md`, test fixtures, seed scripts). Then ask the user to confirm or provide:

- **Dev server URL** (default: `http://localhost:3000`)
- **Auth required?** If yes: login URL, test credentials (email + password) — propose any credentials found in project files
- **Viewport** (default: 390px wide × 844px tall — iPhone 15 Pro)
- **Device scale factor** (default: 2 for retina)
- **Color scheme** (default: dark — adjust if the app uses light theme)

**For each screenshot in the Phase 1 manifest**, spawn one `browser-agent` with a targeted prompt. Agents run in parallel — one agent per screenshot.

## Template for every agent prompt

```
Dev server: <URL>
<If auth required:>
  Login page: <login URL>
  Credentials: <email> / <password>
  After login, you'll be at: <post-login route>

Viewport: <width>px × <height>px, deviceScaleFactor <scale>, <color scheme> color scheme.

Before taking any screenshot, execute this cleanup via page.evaluate():
  document.querySelector('nextjs-portal')?.remove()
  document.querySelector('vite-error-overlay')?.remove()
  document.querySelectorAll('[data-dev-indicator],[data-nextjs-toast],[data-testid="dev-tools"]').forEach(el => el.remove())
  // Remove all focus rings for mobile appearance
  const style = document.createElement('style');
  style.textContent = `
    *:focus, *:focus-visible, *:focus-within {
      outline: none !important; box-shadow: none !important;
      --tw-ring-shadow: none !important; --tw-ring-color: transparent !important;
      --tw-ring-offset-shadow: none !important;
    }`;
  document.head.appendChild(style);
  // Blur any focused element
  document.activeElement?.blur();

Wait for network requests to finish, then wait an additional 3 seconds before capturing.

<Natural language description of: what route to navigate to, what interactions to perform,
what should be visible in the screenshot. Derived from the manifest context + appRoute.>

Save the screenshot to: <absolute path to project root>/<filename>
```

**Important:** Resolve the absolute project root path (e.g. `/home/user/project`) before constructing agent prompts. Do NOT pass `$PWD` literally — browser agents don't execute shell variables.

## Guidance for agents

- If a login form shows a loading state, wait for it to appear before submitting
- If already logged in as the wrong user, navigate to settings/profile and sign out first
- Scroll to find content that isn't immediately visible — do not give up if something is off-screen
- If a drawer, modal, or panel needs to be open for the screenshot, interact to open it before capturing
- If the first attempt produces an empty or error state, try once more after a longer wait

## Mobile Appearance Cleanup Reference

Screenshots must mimic real mobile app appearance. All cleanup happens at capture time only — **never modify app component code, global CSS, or framework config.**

### Dev indicators

```js
// Next.js dev toolbar (shadow DOM element — use CSS, not remove())
// CSS: nextjs-portal { display: none !important; }
// Or via JS:
document.querySelector('nextjs-portal')?.remove()

// Vite error overlay
document.querySelector('vite-error-overlay')?.remove()

// Generic dev indicator attributes
document.querySelectorAll('[data-dev-indicator], [data-nextjs-toast]').forEach(el => el.remove())

// React DevTools badge (if visible)
document.querySelector('#react-devtools-backend-installation')?.remove()
```

### Focus rings (Tailwind + native)

<!-- mirror of the CSS embedded in the prompt template above — edit both together -->
Tailwind uses CSS custom properties for ring utilities. Override both native and Tailwind focus styles:

```css
*:focus, *:focus-visible, *:focus-within {
  outline: none !important;
  box-shadow: none !important;
  --tw-ring-shadow: none !important;
  --tw-ring-color: transparent !important;
  --tw-ring-offset-shadow: none !important;
}
```

Also blur the active element before capture: `document.activeElement?.blur()`

### Style injection survival

**`page.addStyleTag()` and `document.querySelector().remove()` do NOT survive `page.goto()` navigations.** If the capture script navigates to a new page (e.g. reloading for a different tab state), re-inject styles after each navigation.

Pattern for Playwright scripts:
```ts
const injectStyles = () => page.addStyleTag({ content: `...` });
await injectStyles();           // initial
await page.goto(url);           // navigates — styles lost
await injectStyles();           // re-inject
```

## Troubleshooting (browser-agent path)

| Issue | Fix |
|-------|-----|
| Dev indicator visible | Use CSS `nextjs-portal { display: none }` — more reliable than `.remove()` for shadow DOM |
| Focus ring on input | Inject Tailwind ring overrides + `document.activeElement?.blur()` before capture |
| Styles missing after navigation | Re-inject `addStyleTag()` after every `page.goto()` call |
| Food cards not found | Check component selectors — use `role` and CSS class attributes (e.g. `[role="link"].spring-press-subtle`) instead of text matching |
| File not saved | Ensure the output path is absolute — browser agents cannot resolve shell variables like `$PWD` |
