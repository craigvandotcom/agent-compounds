# Supabase + Capacitor Lifecycle (CRITICAL)

Two non-obvious gotchas that bite every Capacitor + Supabase app, plus the sign-out wipe ordering.

## Realtime `setAuth` on `TOKEN_REFRESHED`

Supabase JS v2 has **ONE global `realtime.setAuth()`**, not a per-channel version. Without wiring it up, every realtime channel keeps the JWT it had when it was created, and ~1h after sign-in the server stops pushing messages with no client-side error — users see stale data forever.

```typescript
// lib/supabase/client.ts (module-scope side effect, ONCE per app)
supabase.auth.onAuthStateChange((event, session) => {
  if (event === 'TOKEN_REFRESHED' && session) {
    supabase.realtime.setAuth(session.access_token);
  }
});
```

Add a regression test: `features/auth/__tests__/realtime-token-refresh.test.ts` asserts `setAuth` is called exactly once on `TOKEN_REFRESHED`.

## iOS WKWebView background suspension reality

**iOS suspends WKWebView's JavaScript runtime ~30 seconds after backgrounding.** Consequences:

- `@capacitor/network` `networkStatusChange` CANNOT fire while suspended.
- `setInterval` / `setTimeout` do NOT run.
- Any "writes reach server within N minutes regardless of app state" SLO is unachievable.

This forces an honest sync model:

| User state            | Queue drain timing                                |
| --------------------- | ------------------------------------------------- |
| Foregrounded + online | Within seconds                                    |
| Backgrounded          | On next foreground (`App.resume` event), N/A here |
| Offline → online (bg) | Drains on next foreground, NOT on reconnect       |

**Explicitly NOT supported without native code:** background fetch, periodic fetch, or any "data reaches server within N minutes regardless of app state." Adding background fetch invites Apple-review battery scrutiny and platform-specific code without proportional benefit at Stage 0–2.

Wire `App.resume` to refetch on return:

```typescript
useEffect(() => {
  const listener = App.addListener('resume', () => {
    mutate(/* dashboard keys */); // SWR refetch
  });
  return () => {
    listener.then(l => l.remove());
  };
}, []);
```

## JWT-first sign-out wipe (order matters)

If the app is killed mid-wipe, the order determines what's left behind. Clear the JWT FIRST so even a half-wiped state cannot operate as the prior user:

```typescript
async function signOut() {
  // 1. JWT first — after this, the app cannot operate as the prior user
  await supabase.auth.signOut({ scope: 'local' });
  await Preferences.remove({ key: 'last-known-authed' });

  // 2. SWR cache flush — clear ALL keys (prevents cross-user contamination)
  await mutate(() => true, undefined, { revalidate: false });

  // 3. session/localStorage UI state
  sessionStorage.clear();
  // localStorage: only clear app-owned keys, not user-agent-owned ones

  // 4. If you have IDB: closeAll() → deleteDatabase() → onblocked 2s timeout
  //    (see distribution-stage.md — only relevant once you actually ship local-first storage)
}
```

**Trigger from all paths:** explicit logout button, `onAuthStateChange('USER_DELETED')`, `onAuthStateChange('SIGNED_OUT')` (covers cross-tab).

**Common landmine — SWR static keys cross-user contamination:** If SWR fetcher keys are static strings like `'dashboard-data'`, signing out + signing in as a different user on the same device briefly renders the PREVIOUS user's cached data. Either flush ALL SWR keys on sign-out (above), or scope every fetcher key by `user.id`. Allow-list keys that legitimately stay global (`canonical-ingredient-list`, etc.) and fail the build on un-scoped data keys.
