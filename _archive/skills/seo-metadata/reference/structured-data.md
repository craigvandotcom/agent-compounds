# Structured Data (JSON-LD)

schema.org structured data for rich results. App-specific values (org name, logo, social URLs) come from the app's CORE.

## Injection pattern

Render JSON-LD in a `<script type="application/ld+json">`. In the App Router, inline it in the relevant `layout`/`page` server component:

```tsx
function JsonLd({ data }: { data: Record<string, unknown> }) {
  return (
    <script
      type="application/ld+json"
      // Server-rendered; data is app-controlled (not user input). If any field
      // is user-derived, sanitize it first.
      dangerouslySetInnerHTML={{ __html: JSON.stringify(data) }}
    />
  );
}
```

Place site-wide types (Organization, WebSite) in the root layout; place page types (Article, Product, FAQ, Breadcrumb) in the page.

## Common types

### Organization (root layout, once)

```json
{
  "@context": "https://schema.org",
  "@type": "Organization",
  "name": "Brand Name",
  "url": "https://example.app",
  "logo": "https://example.app/logo.png",
  "sameAs": ["https://twitter.com/handle", "https://instagram.com/handle"]
}
```

### WebSite (+ Sitelinks search box, if you have search)

```json
{
  "@context": "https://schema.org",
  "@type": "WebSite",
  "name": "Brand Name",
  "url": "https://example.app",
  "potentialAction": {
    "@type": "SearchAction",
    "target": "https://example.app/search?q={query}",
    "query-input": "required name=query"
  }
}
```

### Article / BlogPosting (blog & essay pages)

```json
{
  "@context": "https://schema.org",
  "@type": "BlogPosting",
  "headline": "Post title",
  "description": "Excerpt",
  "image": "https://example.app/og/post.png",
  "datePublished": "2026-06-07",
  "dateModified": "2026-06-07",
  "author": { "@type": "Person", "name": "Author Name" },
  "publisher": {
    "@type": "Organization",
    "name": "Brand Name",
    "logo": { "@type": "ImageObject", "url": "https://example.app/logo.png" }
  }
}
```

### Product / SoftwareApplication (app landing pages)

```json
{
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  "name": "App Name",
  "applicationCategory": "HealthApplication",
  "operatingSystem": "iOS, Android",
  "offers": { "@type": "Offer", "price": "0", "priceCurrency": "USD" }
}
```

### BreadcrumbList (deep pages)

```json
{
  "@context": "https://schema.org",
  "@type": "BreadcrumbList",
  "itemListElement": [
    { "@type": "ListItem", "position": 1, "name": "Home", "item": "https://example.app" },
    { "@type": "ListItem", "position": 2, "name": "Blog", "item": "https://example.app/blog" }
  ]
}
```

### FAQPage (pages with a genuine Q&A section)

```json
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    {
      "@type": "Question",
      "name": "Question text?",
      "acceptedAnswer": { "@type": "Answer", "text": "Answer text." }
    }
  ]
}
```

## Rules

- **Only mark up content that's actually on the page.** Google penalizes JSON-LD describing content the user can't see (e.g. FAQ markup with no visible FAQ).
- **Keep it in sync** with visible content (prices, dates, availability).
- **Validate** with Google's Rich Results Test / Schema.org validator before shipping.
- **Don't over-mark.** Org + WebSite site-wide, then the single best-fit type per page. More types ≠ more ranking.
