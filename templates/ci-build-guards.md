# CI / build-time guards — copy-paste doctrine

> Not a file to copy verbatim (unlike `project-AGENTS.md`) — these are two small,
> load-bearing snippets to paste into a project's own build script and quality-gate
> CI workflow. Both come from the BCA App Store 2.1(b) post-mortem (four rejections
> traced to static-check-passed-but-runtime-broken layers) and generalize a fix that
> started in one app's files into doctrine every app can lift.

## 1. Required `NEXT_PUBLIC_*` build-time assert

`NEXT_PUBLIC_*` vars are build-time INLINED: an empty required var doesn't error, it
bakes a silent no-op into the binary (a missing RevenueCat key shipped a dead Subscribe
button through four App Store rejections). A native/critical feature's required public
var must fail the **build**, not the user. Add near the top of the app's native/export
build script (BCA: `scripts/cap-build.sh`), before the actual `next build` call:

```bash
set -e

REQUIRED_PUBLIC_VARS=(
  # <app>: list every NEXT_PUBLIC_* var a native/critical feature depends on —
  # this list is app-specific, the guard mechanism below is not.
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

Origin: BCA bead `bd-qtz6u` (2.1(b) post-mortem, layer-1 guard) — commit `82739012`
removed `@revenuecat/purchases-capacitor` from `package.json` while
`lib/services/purchases.ts` still imported it; no gate caught the removal-with-live-usage.

Add a step to the app's quality-gate CI workflow (alongside format/lint/type-check —
BCA: `.github/workflows/quality-gate.yml`) that fails when a PR removes a dependency
but the source tree still imports it. Either satisfies the gate:

- **knip** — run in CI, fail on unused-export/unresolved-import findings that
  correspond to a dependency removed in the diff. Preferred once the app already
  has (or can cheaply add) a knip config.
- **grep-on-removal** — diff-aware, zero-dependency fallback: for every line removed
  from `package.json`'s `dependencies`/`devDependencies` in the PR diff, grep the
  changed source tree for a remaining `from '<pkg>'` / `require('<pkg>')` import;
  any match fails the step.

BCA (`bd-qtz6u`) is the pilot — land the step there first, then port it verbatim to
sibling apps' quality-gate workflows. This template records the doctrine; it does not
implement BCA's CI (that stays BCA's own bead).
