# CI / build-time guards — copy-paste doctrine

> Not a file to copy verbatim (unlike `project-AGENTS.md`) — these are two small,
> load-bearing snippets to paste into a project's own build script and quality-gate
> CI workflow. Both generalize a fix that started as one app's post-mortem (a static
> checks passed but runtime broken failure that reached production more than once)
> into doctrine any app can lift.

## 1. Required `NEXT_PUBLIC_*` build-time assert

`NEXT_PUBLIC_*` vars are build-time INLINED: an empty required var doesn't error, it
bakes a silent no-op into the binary (e.g. a missing payments SDK key can ship a dead
Subscribe button — a static check never catches it, only a runtime tap does). A
native/critical feature's required public var must fail the **build**, not the user.
Add near the top of `<APP>`'s native/export build script, before the actual
`next build` call:

```bash
set -e

REQUIRED_PUBLIC_VARS=(
  # <app>: list every NEXT_PUBLIC_* var a native/critical feature depends on —
  # this list is app-specific, the guard mechanism below is not. Example:
  NEXT_PUBLIC_SUPABASE_URL
  NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
)
for v in "${REQUIRED_PUBLIC_VARS[@]}"; do
  if [ -z "${!v:-}" ]; then
    echo "✗ $v is empty/unset — the native build would ship a silently-broken feature. Set it before building." >&2
    exit 1
  fi
done
```

## 2. Dep-removed-but-still-imported CI gate

Origin: a real regression where a PR removed a dependency from `package.json` while a
source file still imported it — no gate caught the removal-with-live-usage until it
broke in production.

Add a step to `<APP>`'s quality-gate CI workflow (alongside format/lint/type-check)
that fails when a PR removes a dependency but the source tree still imports it. Either
satisfies the gate:

- **knip** — run in CI, fail on unused-export/unresolved-import findings that
  correspond to a dependency removed in the diff. Preferred once the app already
  has (or can cheaply add) a knip config.
- **grep-on-removal** — diff-aware, zero-dependency fallback: for every line removed
  from `package.json`'s `dependencies`/`devDependencies` in the PR diff, grep the
  changed source tree for a remaining `from '<pkg>'` / `require('<pkg>')` import;
  any match fails the step.

Land the step on one app first as the pilot, then port it verbatim to sibling apps'
quality-gate workflows. This template records the doctrine; it does not implement
any single app's CI (that stays that app's own work item).
