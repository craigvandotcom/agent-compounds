---
name: seo-metadata
description: Use when adding or auditing SEO and social-share metadata on web/marketing surfaces — page titles, meta descriptions, Open Graph / Twitter cards, canonical URLs, sitemaps, robots, structured data (JSON-LD), and hreflang. Next.js App Router Metadata API focused. Triggers on "SEO", "meta tags", "Open Graph", "OG image", "social preview", "sitemap", "robots.txt", "structured data", "JSON-LD", "schema.org", "canonical URL", "search ranking", "meta description", "discoverability". NOT for Core Web Vitals / render performance (use react-best-practices and web-design-guidelines) or native Capacitor app shells (SEO applies to web surfaces only).
---

> **Generic skill — method only, zero app facts.** This skill is symlinked from
> agent-compounds and shared across consuming apps. It contains technique and
> patterns, not project specifics. **App specifics (production domain, brand name,
> social handles, default OG image, organization details) → read this app's
> `.claude/skills/CORE/SKILL.md`** (and the `AGENTS.md` summary it indexes).
> Do not add app-specific facts to this file — they belong in CORE.

# SEO & Metadata

**Purpose:** Add and audit discoverability + social-share metadata for web surfaces
**Domain:** Next.js App Router Metadata API, Open Graph, structured data, technical SEO
**Status:** Complete

---

## Scope gate (read first)

**SEO applies to web/marketing surfaces only** — sites served by crawlers and shared
on social: marketing homepages, blog/essay pages, landing pages, public app
front-doors. **It does NOT apply to native Capacitor app shells** (`output: 'export'`
wrapped in a WebView): there's no crawler, no social unfurl, and `metadataBase`/
dynamic OG generation often don't apply. If the surface in question is a logged-in
native app screen, this skill is the wrong tool — stop.

App-specific values (the production domain, brand name, default OG image path, org
schema details) live in the app's **CORE**. Pull them from there; never hardcode here.

---

## When to Use This Skill

**Intent Triggers:**
- Adding metadata to a new page/route (title, description, canonical, OG)
- Auditing a marketing site for missing/duplicate/weak metadata
- Setting up `sitemap.ts`, `robots.ts`, or `metadataBase`
- Adding social-share previews (Open Graph / Twitter cards / OG images)
- Adding structured data (JSON-LD) for rich results
- Adding `hreflang` / locale alternates

**When NOT to Use:**
- Core Web Vitals / LCP / CLS / render speed → `react-best-practices` + `web-design-guidelines` (these *influence* ranking but are perf work, not metadata)
- Native app shell screens → out of scope (see scope gate)
- Brand voice of the copy itself → `brand-system`

---

## The audit checklist

For each indexable page, verify (load the reference file for the patterns + code):

- [ ] **Unique title** — descriptive, ~50–60 chars, brand-suffixed via template → `reference/metadata-and-og.md`
- [ ] **Unique meta description** — ~150–160 chars, active, specific (not boilerplate)
- [ ] **`metadataBase`** set once in root layout (absolute URL resolution)
- [ ] **Canonical URL** — `alternates.canonical` (prevents duplicate-content dilution)
- [ ] **Open Graph** — `og:title`, `og:description`, `og:type`, `og:url`, `og:image` (1200×630)
- [ ] **Twitter card** — `summary_large_image` + image
- [ ] **OG image** — per-route `opengraph-image.tsx` or a sensible static default
- [ ] **`robots`** — correct index/noindex per route (noindex auth/private/staging)
- [ ] **`sitemap.ts`** — lists all indexable routes with `lastModified`
- [ ] **`robots.ts`** — allows crawl + points to sitemap
- [ ] **Structured data** — JSON-LD for the page type (Org, Article, Product, FAQ, Breadcrumb) → `reference/structured-data.md`
- [ ] **`hreflang`** — `alternates.languages` if multi-locale (else skip)
- [ ] **Semantic HTML & headings** — one `<h1>`, sequential order (overlaps `web-design-guidelines`)
- [ ] **Image alt text** — descriptive (a11y + image SEO; → `web-design-guidelines`)

---

## Core pattern

Next.js App Router resolves metadata from the **nearest `metadata` export** (static)
or **`generateMetadata`** (dynamic, async). Set defaults + templates once at the root
layout; override per route. Absolute URLs flow from `metadataBase`. Full code in
`reference/metadata-and-og.md`.

```tsx
// app/layout.tsx — set base + defaults + title template ONCE
export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),            // from CORE
  title: { default: BRAND, template: `%s · ${BRAND}` },
  description: DEFAULT_DESCRIPTION,
  openGraph: { type: 'website', siteName: BRAND, images: ['/og-default.png'] },
  twitter: { card: 'summary_large_image' },
};
```

```tsx
// app/<route>/page.tsx — override per page
export const metadata: Metadata = {
  title: 'Pricing',                            // becomes "Pricing · Brand"
  description: '…specific, ~155 chars…',
  alternates: { canonical: '/pricing' },
};
```

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Same title/description on every page | Unique per route; use the title template for the brand suffix |
| Forgetting `metadataBase` | Set once in root layout, or OG/canonical URLs resolve relative and break |
| OG image wrong size / missing | 1200×630; provide a static default even if no per-route image |
| Indexing auth/staging/private routes | `robots: { index: false }` on those segments |
| Applying SEO to native app screens | Out of scope — see the scope gate |
| Hardcoding domain/brand here | Pull from the app's CORE; this skill is generic |
| Treating Core Web Vitals as this skill's job | Real ranking factor, but it's perf work → `react-best-practices` |

---

## Supporting Documentation

| File | When to Read |
|------|--------------|
| `reference/metadata-and-og.md` | Metadata API (static + `generateMetadata`), templates, canonical, robots, `sitemap.ts`/`robots.ts`, OG/Twitter, OG image generation |
| `reference/structured-data.md` | JSON-LD injection + schema.org types (Organization, WebSite, Article, Product, BreadcrumbList, FAQPage) |
| the app's local `CORE` skill | Production domain, brand, social handles, org schema, default OG image |
