# Performance Audit Checklist

**Purpose:** Comprehensive performance optimization verification for any web/mobile application
**Domain:** Build size, Core Web Vitals, database queries, mobile performance, PWA
**Tech Stack:** Next.js 15, React 19, Supabase, Vercel, PWA

---

## Quick Reference Commands

```bash
# Build analysis
pnpm build
ANALYZE=true pnpm build  # Bundle analyzer

# Bundle size report
ls -lh .next/static/chunks/pages/*.js

# Test coverage performance
pnpm test:coverage

# Production test
pnpm build && pnpm start

# Check for unoptimized images
find app/ public/ -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) -size +500k

# Database query analysis
# (Check Supabase dashboard > Database > Logs)
```

---

## Performance Audit Items

### [PERF-001] Analyze Total Bundle Size

**Description:** Verify production build meets documented bundle size baseline
**Severity:** HIGH
**Auto-fixable:** NO
**Parallel Group:** PERF-Build-Analysis

**Verification:**

1. Run: `pnpm build`
2. Check build output for "First Load JS shared by all" metric
3. Document current bundle size as baseline (compare against previous)
4. Run: `ANALYZE=true pnpm build` to visualize bundle
5. Identify largest chunks in analyzer report
6. Flag any significant increase (>10%) from baseline

**Expected Output:** Bundle size documented, largest dependencies identified, no unexpected increases

**Deliverable:** Build size report with baseline comparison

---

### [PERF-002] Audit Code Splitting Configuration

**Description:** Verify Next.js code splitting is working for route-based chunking
**Severity:** MEDIUM
**Auto-fixable:** NO
**Parallel Group:** PERF-Build-Analysis

**Verification:**

1. Check build output: each route should have separate chunk
2. Run: `ls -lh .next/static/chunks/app/`
3. Verify route chunks: (protected)/app/_, (auth)/login/_, api/\*
4. Check no single route loads entire app bundle
5. Test: navigate between routes, verify only necessary chunks load

**Expected Output:** Each major route has separate chunk < 50KB

**Deliverable:** Code splitting report with chunk sizes per route

---

### [PERF-003] Identify Unused Dependencies

**Description:** Find npm packages imported but not actually used in production
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** PERF-Build-Analysis

**Verification:**

1. Run: `pnpm build` and check bundle analyzer
2. Look for packages > 10KB that appear unused
3. Search codebase: `grep -r "from '[package]'" app/ lib/`
4. Check devDependencies not imported in app code
5. Verify tree-shaking works for library imports

**Expected Output:** No unused production dependencies

**Deliverable:** List of unused packages to remove

---

### [PERF-004] Audit Image Optimization

**Description:** Verify all images use Next.js Image component with proper formats
**Severity:** HIGH
**Auto-fixable:** YES
**Parallel Group:** PERF-Images

**Verification:**

1. Find image usage: `grep -r "<img\|<Image" app/ --include="*.tsx"`
2. Verify using `next/image` component (not `<img>`)
3. Check formats configured: avif, webp in `next.config.mjs`
4. Verify sizes prop for responsive images
5. Test: inspect Network tab for avif/webp formats served

**Expected Output:** All images use Next.js Image, modern formats served

**Deliverable:** Convert any `<img>` tags to `<Image>` components

---

### [PERF-005] Check for Unoptimized Large Images

**Description:** Find images > 500KB that should be compressed or resized
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** PERF-Images

**Verification:**

1. Run: `find public/ app/ -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) -size +500k`
2. For each large image, check if actually needed at that size
3. Verify appropriate dimensions for display size
4. Use image optimization tools: imagemin, sharp
5. Test visual quality after compression

**Expected Output:** No images > 500KB, all appropriately sized

**Deliverable:** Compress/resize oversized images

---

### [PERF-006] Verify Lazy Loading of Images

**Description:** Ensure below-the-fold images use lazy loading
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** PERF-Images

**Verification:**

1. Find Image components: `grep -r "<Image" app/ --include="*.tsx"`
2. Check for `loading="lazy"` or default behavior
3. Verify priority images use `priority` prop (above fold)
4. Test: scroll page, check Network tab for delayed image loads
5. Verify LCP image has `priority` prop

**Expected Output:** Below-fold images lazy load, LCP image prioritized

**Deliverable:** Add appropriate loading props to images

---

### [PERF-007] Audit Database Query Efficiency

**Description:** Identify N+1 queries and missing indexes in Supabase queries
**Severity:** HIGH
**Auto-fixable:** NO
**Parallel Group:** PERF-Database

**Verification:**

1. Check Supabase dashboard > Database > Logs for slow queries
2. Find all queries: `grep -r "supabase\.from\|supabase\.rpc" app/ lib/ --include="*.ts"`
3. Look for loops making repeated queries (N+1 pattern)
4. Verify `.select()` only fetches needed columns (not `*`)
5. Test with 100+ records, measure query time

**Expected Output:** No N+1 queries, all queries < 100ms

**Deliverable:** Database query optimization report with slow queries

---

### [PERF-008] Verify Database Indexes Exist

**Description:** Ensure frequently queried columns have database indexes
**Severity:** HIGH
**Auto-fixable:** YES
**Parallel Group:** PERF-Database

**Verification:**

1. Connect to Supabase and check indexes: `\di` in psql
2. Identify frequently queried columns: user_id, created_at, and any app-specific classification columns
3. Verify indexes exist for WHERE, ORDER BY, JOIN columns
4. Check index usage in query plans: `EXPLAIN ANALYZE`
5. Test query speed before/after adding indexes

**Expected Output:** All frequently queried columns indexed

**Deliverable:** Add missing indexes to database schema

---

### [PERF-009] Audit RPC Function Performance

**Description:** If using Supabase RPC functions, verify they're optimized
**Severity:** MEDIUM
**Auto-fixable:** NO
**Parallel Group:** PERF-Database

**Verification:**

1. Find RPC calls: `grep -r "supabase\.rpc" app/ lib/ --include="*.ts"`
2. Check Supabase dashboard > Database > Functions for execution time
3. Review RPC SQL for inefficiencies (missing indexes, unnecessary joins)
4. Test with production-scale data
5. Consider replacing with query builder if simpler

**Expected Output:** All RPC functions < 200ms execution time

**Deliverable:** Optimize or replace slow RPC functions

---

### [PERF-010] Verify Server Components Usage

**Description:** Ensure data fetching uses Server Components where appropriate
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** PERF-React

**Verification:**

1. Find data fetching: `grep -r "use client\|useState\|useEffect" app/ --include="*.tsx"`
2. Check if data fetching can move to Server Components
3. Verify "use client" only when needed (interactivity, hooks)
4. Test: check HTML source for server-rendered data
5. Verify no "loading" waterfalls (serial fetching)

**Expected Output:** Data fetching in Server Components, minimal client components

**Deliverable:** Refactor client components to server where possible

---

### [PERF-011] Audit Re-render Performance

**Description:** Identify unnecessary React re-renders using React DevTools Profiler
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** PERF-React

**Verification:**

1. Run dev server: `pnpm dev`
2. Open React DevTools > Profiler
3. Interact with app (use primary create flow, navigate)
4. Identify components re-rendering frequently
5. Check for missing `memo`, `useCallback`, `useMemo`

**Expected Output:** No unnecessary re-renders on interactions

**Deliverable:** Add React optimization hooks where needed

---

### [PERF-012] Verify Suspense Boundaries for Streaming

**Description:** Ensure Suspense boundaries prevent UI blocking during data fetching
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** PERF-React

**Verification:**

1. Find async components: `grep -r "async function\|Promise" app/ --include="*.tsx"`
2. Check for wrapping Suspense boundaries
3. Verify fallback UI exists (loading state)
4. Test: throttle network, verify streaming behavior
5. Check for multiple small Suspense vs single large

**Expected Output:** Long-running fetches wrapped in Suspense

**Deliverable:** Add Suspense boundaries for slow data fetching

---

### [PERF-013] Audit Component Mount Performance

**Description:** Measure time to interactive (TTI) for key components
**Severity:** MEDIUM
**Auto-fixable:** NO
**Parallel Group:** PERF-React

**Verification:**

1. Use Lighthouse in Chrome DevTools
2. Test key pages: /app (dashboard), and other primary detail routes
3. Check TTI metric (should be < 3.8s on mobile)
4. Identify blocking scripts or large components
5. Profile with React DevTools to find slow mounts

**Expected Output:** TTI < 3.8s on simulated 4G mobile

**Deliverable:** Performance report with TTI metrics per page

---

### [PERF-014] Verify Font Loading Strategy

**Description:** Ensure fonts load efficiently without layout shift
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** PERF-Assets

**Verification:**

1. Check font configuration in `app/layout.tsx`
2. Verify using `next/font` for automatic optimization
3. Check for `font-display: swap` or `optional`
4. Test: throttle network, verify no FOIT (flash of invisible text)
5. Measure Cumulative Layout Shift (CLS) with Lighthouse

**Expected Output:** Fonts optimized with next/font, CLS < 0.1

**Deliverable:** Font loading optimization report

---

### [PERF-015] Audit Third-Party Script Loading

**Description:** Verify analytics/monitoring scripts load efficiently
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** PERF-Assets

**Verification:**

1. Find script tags: `grep -r "<script\|Script" app/ --include="*.tsx"`
2. Verify using Next.js `<Script>` component
3. Check loading strategy: `lazyOnload`, `afterInteractive`
4. Test: measure impact on TTI
5. Consider self-hosting critical scripts

**Expected Output:** Third-party scripts load asynchronously, minimal TTI impact

**Deliverable:** Optimize script loading strategy

---

### [PERF-016] Verify Service Worker Caching Strategy

**Description:** Ensure PWA service worker uses efficient caching for offline mode
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** PERF-PWA

**Verification:**

1. Check service worker registration: `grep -r "register.*worker" app/ public/`
2. Review caching strategy (cache-first, network-first, stale-while-revalidate)
3. Verify static assets cached, API calls network-first
4. Test offline mode: go offline, verify app loads
5. Check cache size doesn't exceed quota

**Expected Output:** Efficient caching strategy, offline mode works

**Deliverable:** Service worker caching optimization

---

### [PERF-017] Audit API Route Performance

**Description:** Measure response time of API endpoints and establish baselines
**Severity:** HIGH
**Auto-fixable:** NO
**Parallel Group:** PERF-API

**Verification:**

1. List API routes: `find app/api -name "route.ts"`
2. Test each with curl or Postman: `time curl -X POST https://...`
3. Document response times and establish baseline
4. Profile with Vercel Analytics or custom logging
5. Identify bottlenecks (database, AI calls, external APIs)
6. Flag significant regressions from baseline

**Expected Output:** API response times documented, bottlenecks identified

**Deliverable:** API performance report with baseline measurements

---

### [PERF-018] Evaluate AI Request Streaming

**Description:** Assess whether AI streaming would benefit user experience
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** PERF-API

**Verification:**

1. Check your app's AI/LLM API routes (e.g. `app/api/image-analysis/route.ts`, `app/api/content-generation/route.ts`)
2. Determine current implementation (streaming vs non-streaming)
3. Measure current AI response times
4. Assess UX impact: does user perceive wait? Would streaming help?
5. If streaming beneficial: verify `stream: true` for Anthropic API
6. If streaming implemented: verify UI updates progressively

**Expected Output:** Streaming assessment with implementation status and UX impact

**Deliverable:** AI streaming recommendation or verification

**Note:** This project currently uses non-streaming AI calls. Evaluate whether streaming would provide meaningful UX improvement for typical use cases.

---

### [PERF-019] Verify Middleware Performance

**Description:** Ensure authentication middleware doesn't slow down requests
**Severity:** MEDIUM
**Auto-fixable:** NO
**Parallel Group:** PERF-Middleware

**Verification:**

1. Read `middleware.ts` for auth checks
2. Add timing logs: `console.time('middleware')`
3. Test protected route: measure middleware execution time
4. Check for unnecessary database calls in middleware
5. Verify session token validation is cached

**Expected Output:** Middleware execution < 50ms

**Deliverable:** Middleware performance report

---

### [PERF-020] Audit Form Submission Performance

**Description:** Verify form submissions feel instant with optimistic updates
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** PERF-UX

**Verification:**

1. Find form submissions: `grep -r "onSubmit\|handleSubmit" app/ --include="*.tsx"`
2. Check for optimistic UI updates before API response
3. Verify loading states during submission
4. Test: throttle network, measure perceived performance
5. Check for unnecessary form re-validation

**Expected Output:** Forms use optimistic updates, feel instant

**Deliverable:** Add optimistic updates to slow forms

---

### [PERF-021] Verify Debouncing on Search/Autocomplete

**Description:** Ensure search inputs debounce to reduce API calls
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** PERF-UX

**Verification:**

1. Find search inputs: `grep -r "onChange\|onInput" app/ --include="*.tsx" | grep -i "search"`
2. Check for debounce implementation (300-500ms)
3. Test: type quickly, verify API calls throttled
4. Check using `useDebounce` hook or similar
5. Verify loading state during search

**Expected Output:** Search inputs debounced, < 5 API calls for 10 characters typed

**Deliverable:** Add debouncing to search inputs

---

### [PERF-022] Audit Mobile Animation Performance

**Description:** Verify touch interactions maintain 60fps
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** PERF-Mobile

**Verification:**

1. Open Chrome DevTools > Performance
2. Enable mobile emulation (throttled CPU)
3. Record interactions: button taps, drawer open/close
4. Check for frame drops (FPS < 60)
5. Verify CSS animations use `transform` and `opacity` (GPU accelerated)

**Expected Output:** All animations 60fps on mobile

**Deliverable:** Optimize animations causing frame drops

---

### [PERF-023] Verify Virtualization for Long Lists

**Description:** Ensure long lists (>50 items) use virtual scrolling
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** PERF-Mobile

**Verification:**

1. Find list components: `grep -r "\.map\(" app/ --include="*.tsx"`
2. Check for lists rendering >50 items
3. Verify using virtualization library (react-window, react-virtual)
4. Test with 500+ items: measure scroll performance
5. Check for unnecessary re-renders on scroll

**Expected Output:** Long lists virtualized, smooth scrolling

**Deliverable:** Add virtualization to long lists

---

### [PERF-024] Audit Touch Target Sizes for Performance

**Description:** Verify touch targets aren't causing unnecessary re-renders
**Severity:** LOW
**Auto-fixable:** YES
**Parallel Group:** PERF-Mobile

**Verification:**

1. Use React DevTools Profiler on mobile viewport
2. Tap buttons/interactive elements rapidly
3. Check for cascading re-renders
4. Verify event handlers use `useCallback`
5. Check for excessive event listener registration

**Expected Output:** Touch interactions don't cause unnecessary re-renders

**Deliverable:** Optimize event handlers in interactive components

---

### [PERF-025] Verify Prefetching for Navigation

**Description:** Ensure Next.js prefetches linked pages for instant navigation
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** PERF-Navigation

**Verification:**

1. Find Link components: `grep -r "<Link" app/ --include="*.tsx"`
2. Verify using Next.js `<Link>` (not `<a>`)
3. Check prefetch behavior (default: hover/viewport)
4. Test: hover link, check Network tab for prefetch
5. Verify critical routes prefetch on mount

**Expected Output:** Links prefetch, navigation feels instant

**Deliverable:** Ensure all navigation uses Next.js Link

---

### [PERF-026] Audit State Management Overhead

**Description:** Verify state management doesn't cause unnecessary complexity
**Severity:** MEDIUM
**Auto-fixable:** NO
**Parallel Group:** PERF-Architecture

**Verification:**

1. Check for state libraries: `grep -r "zustand\|redux\|jotai" package.json`
2. If using global state, verify it's actually needed
3. Check for prop drilling that could use context
4. Verify no excessive context providers (nested 3+ deep)
5. Test re-render impact of state changes

**Expected Output:** State management is minimal and efficient

**Deliverable:** State management architecture review

---

### [PERF-027] Verify Error Boundary Performance

**Description:** Ensure error boundaries don't slow down happy path
**Severity:** LOW
**Auto-fixable:** NO
**Parallel Group:** PERF-Architecture

**Verification:**

1. Find error boundaries: `grep -r "ErrorBoundary\|componentDidCatch" app/`
2. Check placement (not wrapping every component)
3. Verify error boundaries don't re-render unnecessarily
4. Test: trigger error, measure recovery time
5. Check error logging doesn't block UI

**Expected Output:** Error boundaries have minimal performance impact

**Deliverable:** Error boundary performance audit

---

### [PERF-028] Audit Build Time Performance

**Description:** Ensure CI/CD build time is reasonable (< 2 minutes)
**Severity:** LOW
**Auto-fixable:** YES
**Parallel Group:** PERF-DX

**Verification:**

1. Run: `time pnpm build`
2. Check build duration (should be < 2 min for this app size)
3. Identify slow build steps (TypeScript, ESLint)
4. Check for unnecessary file processing
5. Verify caching works in CI (Vercel/GitHub Actions)

**Expected Output:** Build completes in < 2 minutes

**Deliverable:** Build time optimization report

---

### [PERF-029] Verify Development Server Performance

**Description:** Ensure fast refresh and HMR work efficiently in development
**Severity:** LOW
**Auto-fixable:** NO
**Parallel Group:** PERF-DX

**Verification:**

1. Run: `pnpm dev`
2. Make code change, measure time to HMR update
3. Verify < 1 second for simple changes
4. Check for full page reloads (should be rare)
5. Test with file watcher: ensure no excessive reloads

**Expected Output:** HMR updates < 1 second, fast refresh working

**Deliverable:** Development performance report

---

### [PERF-030] Core Web Vitals Field Monitoring

**Description:** Verify Real User Monitoring (RUM) not just lab data for Core Web Vitals
**Severity:** HIGH
**Auto-fixable:** NO
**Parallel Group:** PERF-Monitoring

**Verification:**

1. Check Vercel Analytics or equivalent RUM enabled
2. Verify 75th percentile tracking (Google standard)
3. Check mobile vs desktop segmentation
4. Verify INP tracking for ALL interactions (replaced FID)
5. Compare lab data (Lighthouse) vs field data (RUM)

**Expected Output:** RUM tracking CWV at 75th percentile, INP measured

**Deliverable:** Field monitoring setup verification

---

### [PERF-031] Supabase Cache Hit Rate

**Description:** Verify Supabase database cache performance (target: 99%+)
**Severity:** HIGH
**Auto-fixable:** NO
**Parallel Group:** PERF-Database
**Blocked By:** [PERF-007]

**Verification:**

1. Connect to Supabase DB
2. Run: `SELECT sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read)) AS cache_hit_rate FROM pg_statio_user_tables;`
3. Verify cache hit rate >= 0.99 (99%)
4. If <99%: check compute plan size (may be too small)
5. Review query patterns for cache-unfriendly behavior

**Expected Output:** Cache hit rate >= 99%

**Deliverable:** Cache hit rate report with optimization recommendations

---

### [PERF-032] Index Advisor Analysis

**Description:** Use Supabase index_advisor extension for index optimization
**Severity:** HIGH
**Auto-fixable:** YES
**Parallel Group:** PERF-Database
**Blocked By:** [PERF-008]

**Verification:**

1. Enable index_advisor extension in Supabase
2. Run: `SELECT * FROM index_advisor(min_rows => 100);`
3. Check virtual index testing (rapid, no actual creation)
4. Verify foreign key indexing
5. Use Supabase CLI to detect unused indexes: `supabase db lint`

**Expected Output:** Index recommendations analyzed, unused indexes identified

**Deliverable:** Index optimization plan based on advisor

---

### [PERF-033] pg_stat_statements Query Analysis

**Description:** Identify slow queries using pg_stat_statements
**Severity:** HIGH
**Auto-fixable:** NO
**Parallel Group:** PERF-Database
**Blocked By:** [PERF-007]

**Verification:**

1. Enable pg_stat_statements extension
2. Run: `SELECT query, calls, mean_time, max_time FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 20;`
3. Identify high max_time/mean_time queries
4. Check frequently executed slow queries
5. Apply thresholds: <50ms (fast), <200ms (ok), >500ms (critical)

**Expected Output:** Slow queries identified with execution metrics

**Deliverable:** Query optimization priority list

---

### [PERF-034] Bundle Size Regression Testing

**Description:** Fail CI if bundle increases >10% without justification
**Severity:** HIGH
**Auto-fixable:** YES
**Parallel Group:** PERF-Build-Analysis
**Blocked By:** [PERF-001]

**Verification:**

1. Check CI workflow for bundle size tracking
2. Verify fails if bundle increases >10%
3. Set initial load target: <100KB JS (mobile)
4. Set route-specific target: <50KB per page
5. Check dead code detection (e.g., unused recharts imports)

**Expected Output:** CI enforces bundle size limits, dead code detected

**Deliverable:** Bundle size regression tests in CI

---

### [PERF-035] React 19 Concurrent Features Audit

**Description:** Verify usage of React 19 concurrent rendering features
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** PERF-React
**Blocked By:** [PERF-011]

**Verification:**

1. Check useTransition usage: `grep -r "useTransition" app/ --include="*.tsx"`
2. Verify useDeferredValue for expensive renders
3. Check Suspense boundaries for async components
4. Verify Server Components adoption tracking
5. Test: verify non-urgent updates don't block UI

**Expected Output:** React 19 concurrent features utilized where appropriate

**Deliverable:** React 19 feature adoption report

---

### [PERF-036] Audit Interaction to Next Paint (INP)

**Description:** Verify INP meets Core Web Vital threshold (replaced FID March 2024)
**Severity:** CRITICAL
**Auto-fixable:** NO
**Parallel Group:** PERF-Core-Web-Vitals

**Verification:**

1. Run Lighthouse, check INP score (target: ≤200ms at 75th percentile)
2. Profile high-interaction features: primary data entry, media capture, secondary logging
3. Use Chrome DevTools > Performance panel > Interactions track
4. Identify long-running event handlers (>50ms = potential INP issue)
5. Test with throttled CPU (4x slowdown in DevTools)
6. Check for main thread blocking during interactions

**Expected Output:** INP ≤200ms for all critical interactions

**Deliverable:** INP optimization report with interaction profiling results

**Reference:** INP officially replaced FID as Core Web Vital on March 12, 2024

---

### [PERF-037] Configure Lighthouse CI for Automated Regression Detection

**Description:** Fail PRs that degrade performance metrics
**Severity:** HIGH
**Auto-fixable:** YES
**Parallel Group:** PERF-CI-Automation

**Verification:**

1. Check for `.github/workflows/lighthouse.yml` (create if missing)
2. Verify `lighthouserc.json` exists with performance budgets
3. Check thresholds: LCP <2.5s, INP <200ms, CLS <0.1
4. Verify fail threshold: >10% regression fails PR
5. Check Lighthouse report artifacts generated
6. Verify PR comments show performance changes

**Expected Output:** Lighthouse CI runs on every PR, blocks regressions

**Deliverable:** Lighthouse CI workflow configuration

**Example lighthouserc.json:**

```json
{
  "ci": {
    "assert": {
      "assertions": {
        "categories:performance": ["error", { "minScore": 0.8 }],
        "largest-contentful-paint": ["error", { "maxNumericValue": 2500 }],
        "cumulative-layout-shift": ["error", { "maxNumericValue": 0.1 }]
      }
    }
  }
}
```

---

### [PERF-038] Mobile Network Performance Testing

**Description:** Test app performance under slow network conditions (3G/4G)
**Severity:** HIGH
**Auto-fixable:** NO
**Parallel Group:** PERF-Mobile

**Verification:**

1. Open Chrome DevTools > Network > Slow 3G preset
2. Test critical flows: login, primary create flow, media capture, dashboard load
3. Measure: TTFB, LCP, full page load under throttling
4. Verify offline fallback triggers appropriately
5. Test with Playwright network emulation in E2E tests
6. Check PWA caching effectiveness under poor connectivity

**Expected Output:** App usable on Slow 3G, graceful degradation on network failure

**Deliverable:** Network performance report with throttled metrics

**Reference:** PWA targeting mobile users with variable connectivity needs 3G testing

---

### [PERF-039] AI Response Time Monitoring (TTFT)

**Description:** Track Time to First Token for AI endpoints
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** PERF-API
**Blocked By:** [PERF-017]

**Verification:**

1. Add TTFT logging to AI routes: `console.time('ttft'); ... console.timeEnd('ttft')`
2. Measure: your app's AI/LLM API routes (e.g. image-analysis, content-generation, classification)
3. Check TTFT thresholds: <500ms (snappy), <1500ms (acceptable), >1500ms (poor)
4. Verify streaming implementation if TTFT is high
5. Monitor Vercel function logs for AI response patterns

**Expected Output:** TTFT tracked and within acceptable thresholds

**Deliverable:** AI response time monitoring dashboard or logging

**Reference:** TTFT <500ms perceived as "snappy", >1500ms perceived as "poor"

---

## Summary Template

After completing audit items, generate this summary:

```markdown
## Performance Audit Summary

**Date:** YYYY-MM-DD
**Auditor:** [Name/Tool]
**Scope:** [App Name] - Full Application

### Core Web Vitals

| Metric                          | Current | Target  | Status   |
| ------------------------------- | ------- | ------- | -------- |
| LCP (Largest Contentful Paint)  | X.Xs    | < 2.5s  | ✅/⚠️/❌ |
| INP (Interaction to Next Paint) | Xms     | < 200ms | ✅/⚠️/❌ |
| CLS (Cumulative Layout Shift)   | X.XX    | < 0.1   | ✅/⚠️/❌ |
| TTI (Time to Interactive)       | X.Xs    | < 3.8s  | ✅/⚠️/❌ |
| FCP (First Contentful Paint)    | X.Xs    | < 1.8s  | ✅/⚠️/❌ |

### Bundle Size Analysis

| Metric        | Size   | Target   | Status   |
| ------------- | ------ | -------- | -------- |
| First Load JS | XXX KB | < 250 KB | ✅/⚠️/❌ |
| Largest Chunk | XX KB  | < 100 KB | ✅/⚠️/❌ |
| Total Bundle  | XXX KB | < 500 KB | ✅/⚠️/❌ |

### Findings by Severity

| Severity | Count | Auto-fixable |
| -------- | ----- | ------------ |
| CRITICAL | X     | Y            |
| HIGH     | X     | Y            |
| MEDIUM   | X     | Y            |
| LOW      | X     | Y            |
| INFO     | X     | Y            |

### Recommendations

**Immediate (Critical/High):**

1. [Finding 1] - [Est. improvement]
2. [Finding 2] - [Est. improvement]

**Short-term (Medium):**

1. [Finding 1]
2. [Finding 2]

**Long-term (Low/Info):**

1. [Finding 1]
```
