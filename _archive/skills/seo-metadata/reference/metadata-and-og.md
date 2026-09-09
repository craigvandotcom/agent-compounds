# Metadata API, Open Graph & Technical SEO

Next.js App Router patterns. App-specific values (domain, brand, handles, default OG image) come from the app's CORE — shown here as constants.

## Root layout: base, defaults, title template (set ONCE)

```tsx
// app/layout.tsx
import type { Metadata } from 'next';

const SITE_URL = 'https://example.app'; // ← from CORE
const BRAND = 'Brand Name';             // ← from CORE

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: {
    default: `${BRAND} — short positioning line`,
    template: `%s · ${BRAND}`, // child pages set only their own title
  },
  description: 'Default ~155-char description used where a page sets none.',
  applicationName: BRAND,
  openGraph: {
    type: 'website',
    siteName: BRAND,
    url: SITE_URL,
    images: ['/og-default.png'], // resolved absolute via metadataBase
  },
  twitter: {
    card: 'summary_large_image',
    site: '@handle', // ← from CORE
  },
  robots: { index: true, follow: true },
};
```

**`metadataBase` is load-bearing:** without it, `openGraph.images`, `alternates.canonical`, and other URL fields resolve relative and break in crawlers/unfurlers.

## Per-page static metadata

```tsx
// app/pricing/page.tsx
export const metadata: Metadata = {
  title: 'Pricing',                          // → "Pricing · Brand Name"
  description: 'Specific, benefit-led, ~155 characters. Not boilerplate.',
  alternates: { canonical: '/pricing' },
  openGraph: {
    title: 'Pricing · Brand Name',
    description: '…',
    url: '/pricing',
    images: ['/og/pricing.png'],
  },
};
```

## Dynamic metadata (`generateMetadata`)

For routes whose metadata depends on data (blog posts, products). Runs server-side; dedupe the fetch with `react`'s `cache()` so the page body doesn't re-fetch.

```tsx
import type { Metadata } from 'next';
import { cache } from 'react';

const getPost = cache(async (slug: string) => fetchPost(slug));

export async function generateMetadata(
  { params }: { params: Promise<{ slug: string }> }
): Promise<Metadata> {
  const { slug } = await params;
  const post = await getPost(slug);
  if (!post) return { title: 'Not found', robots: { index: false } };
  return {
    title: post.title,
    description: post.excerpt,
    alternates: { canonical: `/blog/${slug}` },
    openGraph: {
      type: 'article',
      title: post.title,
      description: post.excerpt,
      url: `/blog/${slug}`,
      publishedTime: post.publishedAt,
      images: [post.ogImage ?? '/og-default.png'],
    },
  };
}
```

## OG images

Two options:

1. **Static** — drop a 1200×630 PNG and reference it in `openGraph.images`.
2. **Generated per-route** — `opengraph-image.tsx` using `ImageResponse`:

```tsx
// app/blog/[slug]/opengraph-image.tsx
import { ImageResponse } from 'next/og';

export const size = { width: 1200, height: 630 };
export const contentType = 'image/png';

export default async function Image({ params }: { params: { slug: string } }) {
  const post = await getPost(params.slug);
  return new ImageResponse(
    (
      <div style={{ /* brand-styled layout */ display: 'flex' }}>
        {post.title}
      </div>
    ),
    size
  );
}
```

Keep OG images at **1200×630** (1.91:1). Provide a branded static default so no page ever unfurls blank.

## Canonical & robots discipline

```tsx
// Noindex private/auth/staging segments
export const metadata: Metadata = { robots: { index: false, follow: false } };
```

- Canonical every indexable page (`alternates.canonical`) to collapse duplicate URLs (trailing slash, query params, www vs apex).
- Noindex: auth flows, account/settings, preview/staging deployments, thank-you pages.

## sitemap.ts & robots.ts

```tsx
// app/sitemap.ts
import type { MetadataRoute } from 'next';

export default function sitemap(): MetadataRoute.Sitemap {
  const base = 'https://example.app'; // ← from CORE
  const routes = ['', '/pricing', '/about'].map(p => ({
    url: `${base}${p}`,
    lastModified: new Date(),
    changeFrequency: 'weekly' as const,
    priority: p === '' ? 1 : 0.7,
  }));
  // + dynamic routes mapped from data
  return routes;
}
```

```tsx
// app/robots.ts
import type { MetadataRoute } from 'next';

export default function robots(): MetadataRoute.Robots {
  const base = 'https://example.app'; // ← from CORE
  return {
    rules: { userAgent: '*', allow: '/', disallow: ['/api/', '/admin/'] },
    sitemap: `${base}/sitemap.xml`,
  };
}
```

## hreflang / locale alternates (only if multi-locale)

```tsx
export const metadata: Metadata = {
  alternates: {
    canonical: '/pricing',
    languages: { 'en-US': '/en/pricing', 'es-ES': '/es/pricing' },
  },
};
```

## Capacitor caveat

For dual-build apps, the **static-export (native) build doesn't need crawler metadata** — `metadataBase` and dynamic OG generation target the web (Vercel) build. Don't spend effort SEO-tuning routes that only ship inside the WebView.
