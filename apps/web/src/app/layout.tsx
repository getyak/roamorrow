import type { Metadata, Viewport } from "next";
import "./globals.css";
import { QueryProvider } from "@/lib/query-client";
import { AnalyticsBoot } from "@/lib/analytics";

import { BRAND, SITE_URL } from "@/lib/brand";

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: {
    default: `${BRAND.name} · ${BRAND.tagline}`,
    template: `%s · ${BRAND.name}`,
  },
  description: BRAND.description,
  applicationName: BRAND.name,
  referrer: "origin-when-cross-origin",
  formatDetection: { telephone: false, email: false, address: false },
  // Icons come from src/app/icon.tsx + src/app/apple-icon.tsx (file-based).
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#FAF8F6" },
    { media: "(prefers-color-scheme: dark)", color: "#171410" },
  ],
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  // suppressHydrationWarning silences mismatches caused by browser extensions
  // (e.g. Immersive Translate) that inject attributes onto <html>/<body>
  // before React hydrates. Scoped to these two elements only — descendant
  // hydration checks remain strict.
  return (
    <html lang="en" suppressHydrationWarning>
      <body suppressHydrationWarning>
        <a
          href="#main"
          className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-[100] focus:rounded-md focus:bg-accent focus:px-4 focus:py-2 focus:font-body focus:text-[14px] focus:font-medium focus:text-bg-warm focus:shadow-lg focus:outline-2 focus:outline-accent focus:outline-offset-2"
        >
          Skip to main content
        </a>
        <QueryProvider>
          <AnalyticsBoot />
          {children}
        </QueryProvider>
      </body>
    </html>
  );
}
