# Native-Shell Checklist — what ONLY the simulator can catch

For hybrid (Capacitor/WKWebView) apps, the browser layer tests the same bundle
with the same engine family — so this checklist is the *reason Layer 2 exists*.
Every item here is invisible or fake in a desktop browser. Work through the
relevant sections on a **full** or **exhaustive** pass; the consuming app's
`CORE/journeys/native.md` flags which items are hot spots for that app.

## Viewport & chrome

- [ ] Safe-area insets: `env(safe-area-inset-*)` with `viewport-fit=cover` —
      no notch/Dynamic Island/home-indicator overlap (desktop reports 0 for all).
      ⚠ `env(safe-area-inset-*)` resolves to **0** unless the viewport sets
      `viewport-fit=cover` (Next: `viewportFit:'cover'` in the `viewport` export) —
      so `pb-safe`/`calc(env(...))` CSS is a **silent no-op** without it, and a
      className/unit test will false-green while the element is still mis-placed.
      VERIFY BY RECT, not by class: an element pinned near a screen edge must have
      its `snapshot -i --raw` rect **inside** the screen bounds AND `hittable:true`
      (a control rendered just off the bottom edge reads `hittable:false`).
- [ ] Status-bar style per screen, light AND dark appearance
- [ ] Cold start: native splash → branded splash → first paint, no white/wrong-color flash
- [ ] Orientation behavior (locked? rotation relayout?)

## Keyboard (the #1 hybrid bug farm)

- [ ] Keyboard show/hide: focused input stays visible, no viewport jump, no
      leftover bottom gap (behavior depends on the app's Capacitor `Keyboard.resize` mode)
- [ ] Custom input accessories / toolbars position correctly above the keyboard
- [ ] Input `type=` attributes summon the right iOS keyboard variants
- [ ] Safe-area-inset-bottom correctness WHILE keyboard is open (regressed in
      specific Capacitor versions — re-check after Capacitor upgrades)
- [ ] Keyboard dismissal (tap-outside, scroll, submit) leaves layout clean

## WKWebView rendering & gesture quirks

- [ ] Rubber-band overscroll and scroll-bounce don't break pinned UI
- [ ] `100vh`/`100dvh` sizing inside the shell (differs from browser)
- [ ] No tap-highlight flashes or long-press text-selection callouts on app chrome
- [ ] OS settings propagate: Dynamic Type sizes, Reduce Motion
- [ ] Momentum scrolling in nested scroll containers

## Origin, networking & storage

- [ ] `capacitor://localhost` origin: API CORS, cookie acceptance, anything keyed on origin/scheme
- [ ] localStorage/IndexedDB survive app restart (webview storage ≠ browser profile)
- [ ] Auth/session persistence across force-quit + relaunch

## Plugin bridge (mocked in browser, REAL here)

- [ ] Each plugin call the journeys exercise: photo picker, filesystem, share,
      haptics call-sites, preferences, status bar, splash
- [ ] Permission prompts: the system alert appears, BOTH grant and deny paths
      recover gracefully (`simctl privacy revoke` to re-test)
- [ ] Plugin error paths: cancelled sheets, denied permissions

## Auth & navigation

- [ ] Native OAuth sheets (Google/Apple native SDK flows) end-to-end — these are
      entirely native-plane, the browser proves nothing about them
- [ ] Deep links: `simctl openurl` each scheme/route → correct in-app destination,
      tested from BOTH cold start and warm (backgrounded) start
- [ ] External links open the system browser / SFSafariViewController, not in-webview
- [ ] iOS back-swipe gesture vs the SPA router — no broken history states

## Lifecycle

- [ ] Background → foreground resume: timers, realtime connections reconnect,
      stale auth tokens refresh, UI not frozen on stale data
- [ ] State restoration after WKWebView process kill (memory pressure reload path —
      `simctl spawn booted notifyutil -p UISimulatedMemoryWarningNotification` exercises the warning;
      true process-kill restoration needs a long background soak or device)
- [ ] Push payload handling (`simctl push`): foreground, background, and tap-to-open routing

## Build-pipeline truth

- [ ] The shipped bundle is FRESH — verify a known recent change is visible
      before trusting any other result (stale `out/` is a whole class of
      native-only bug and the #1 source of false QA results)
