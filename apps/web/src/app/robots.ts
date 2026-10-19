import type { MetadataRoute } from "next";

/**
 * robots.txt — Next.js App Router auto-generates /robots.txt
 * Doc: SEO_STRATEGY.md §6
 */

import { BRAND, SITE_URL } from "@/lib/brand";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: "*",
        allow: "/",
        disallow: [
          "/api/",
          "/app/",
          "/nomads/api/",
          "/nomads/published-pages/",
          "/nomads/local-data/",
        ],
      },
    ],
    sitemap: [`${SITE_URL}/sitemap.xml`, `${SITE_URL}/nomads/sitemap.xml`],
    host: SITE_URL,
  };
}
