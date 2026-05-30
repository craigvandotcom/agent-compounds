# Capacitor Plugin Catalog

**When to read:** Choosing which plugin to install for a native feature, looking up package names, or understanding Body Compass-specific use cases.

Install pattern: `pnpm add @capacitor/plugin-name && npx cap sync`

---

## Core Plugins (Body Compass Use Cases)

| Plugin              | Package                          | Use Case                                  |
| ------------------- | -------------------------------- | ----------------------------------------- |
| Camera              | `@capacitor/camera`              | Meal photo capture                        |
| Geolocation         | `@capacitor/geolocation`         | Location-based tracking                   |
| Local Notifications | `@capacitor/local-notifications` | Meal/symptom reminders                    |
| Haptics             | `@capacitor/haptics`             | Touch feedback                            |
| Status Bar          | `@capacitor/status-bar`          | Native status bar styling                 |
| Keyboard            | `@capacitor/keyboard`            | Keyboard event handling                   |
| Splash Screen       | `@capacitor/splash-screen`       | App launch screen                         |
| Push Notifications  | `@capacitor/push-notifications`  | FCM/APNs                                  |
| Share               | `@capacitor/share`               | Native share sheet                        |
| Preferences         | `@capacitor/preferences`         | Key-value storage (replaces localStorage) |
| App                 | `@capacitor/app`                 | App lifecycle, deep link events           |

---

## Community Plugins

| Plugin      | Package                       | Use Case                                       |
| ----------- | ----------------------------- | ---------------------------------------------- |
| SQLite      | `@capacitor-community/sqlite` | Persistent local database (replaces IndexedDB) |
| OTA Updates | `@capgo/capacitor-updater`    | Live updates without app store review          |

---

## External Resources

- [Capacitor Plugin Registry](https://capacitorjs.com/docs/plugins)
- [capgo-skills](https://github.com/Cap-go/capgo-skills) — 24 Capacitor AI skills (`npx skills add Cap-go/capgo-skills`)
- [Capacitor Plugin API Tutorial](https://capacitorjs.com/docs/plugins/tutorial/designing-the-plugin-api)
