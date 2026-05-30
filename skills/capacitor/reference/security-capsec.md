# Security & Capsec Scanner

**When to read:** Running security audits, reviewing security rules, preparing for app store submission, or enforcing secure storage patterns.

---

## Running the Scanner

```bash
# Interactive scan
bunx capsec scan

# JSON report for CI
bunx capsec scan --format json --output security-report.json
```

62+ rules, zero configuration needed. Source: [capacitor-security](https://github.com/Cap-go/capgo-skills)

---

## Key Security Rules

- **Never hardcode API keys or secrets** in client code
- **Use `@capacitor/preferences` or Secure Storage** for tokens — NOT `localStorage` (evictable on iOS, see `pwa-migration.md`)
- **Validate all native API responses** at the boundary
- **Use HTTPS for all network requests** — no cleartext in production
- **Request permissions at point of use**, not upfront
- **Disable `webContentsDebuggingEnabled`** in production builds (enabled in dev — see `testing-debugging.md`)
- **No sensitive data in `console.log`** — strip in production builds
- **Certificate pinning** for sensitive API endpoints
- **iOS ATS (App Transport Security)** must not allow arbitrary loads in production

---

## Production Build Checklist

- [ ] `webContentsDebuggingEnabled` set to `false` or omitted
- [ ] No hardcoded secrets in codebase (run `bunx capsec scan`)
- [ ] Auth tokens stored in `@capacitor/preferences`, not `localStorage`
- [ ] All API calls use HTTPS
- [ ] Permissions requested contextually (not on app launch)
- [ ] `console.log` stripped or filtered in production bundle
