# User Journey Definitions

Core user flows for Body Compass app validation.

## Journey Index

| Journey        | File              | Purpose                                        |
| -------------- | ----------------- | ---------------------------------------------- |
| Authentication | `auth.md`         | Login, logout, session handling                |
| Food Entry     | `food-entry.md`   | Add/edit/delete food via FAB or direct         |
| Signal Entry   | `signal-entry.md` | Add/edit/delete symptom signals                |
| Dashboard      | `dashboard.md`    | Insights, entries, FAB, date navigation        |
| Settings       | `settings.md`     | Account, preferences, logout                   |
| Modifiers      | `modifiers.md`    | Sourcing/processing icons, drawer, persistence |

## When to Use

**During `/work-review`:** Validate affected journeys based on changed files.

**During `/merge`:** Quick smoke test of primary journey.

**Manual testing:** Full journey validation for releases.

## Journey Structure

Each journey file contains:

1. **Prerequisites** - Required state before starting (includes mobile viewport)
2. **Happy Path** - Standard successful flow with exact button labels
3. **Checkpoints** - What to verify at each step
4. **Edge Cases** - Error states and recovery
5. **Mobile Considerations** - Touch-specific behavior

## Mobile Viewport (Default)

**All journeys assume mobile viewport (390x844).** This is a mobile-first PWA.

```bash
agent-browser --session [name] set viewport 390 844
```

## Mapping Changes to Journeys

| Changed Files                                     | Journeys to Test                                   |
| ------------------------------------------------- | -------------------------------------------------- |
| `app/(auth)/*`                                    | `auth.md`                                          |
| `features/foods/*`                                | `food-entry.md`                                    |
| `features/symptoms/*`                             | `signal-entry.md`                                  |
| `features/dashboard/*`                            | `dashboard.md`                                     |
| `features/dashboard/components/settings-view*`    | `settings.md`                                      |
| `features/dashboard/components/floating-action*`  | `dashboard.md`, `food-entry.md`, `signal-entry.md` |
| `features/dashboard/components/dashboard-footer*` | `dashboard.md`                                     |
| `lib/constants/modifiers*`, `*modifier-swap*`     | `modifiers.md`                                     |
| `*expandable-ingredient*`                         | `food-entry.md`, `modifiers.md`                    |
| `components/ui/*`                                 | All affected journeys                              |
| `lib/supabase/*`                                  | `auth.md` + data journeys                          |
| `app/(protected)/app/page.tsx`                    | `dashboard.md`                                     |
