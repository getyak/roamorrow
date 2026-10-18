import { LEGAL_URLS } from "@/lib/legal";
import type { Metadata } from "next";
import { copy } from "@/components/marketing/copy";
import { Footer, MarketingNav } from "@/components/marketing/sections";
import { Container } from "@/components/marketing/Container";
import { Eyebrow, Section } from "@/components/marketing/primitives";

import { BRAND, SITE_URL } from "@/lib/brand";

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: "Privacy",
  description:
    "How Roamorrow handles account, location, voice, photos and diagnostics across native and web features.",
  alternates: {
    canonical: `${SITE_URL}/privacy`,
    languages: {
      en: `${SITE_URL}/privacy`,
      "zh-CN": `${SITE_URL}/zh/privacy`,
      "x-default": `${SITE_URL}/privacy`,
    },
  },
  openGraph: {
    type: "article",
    url: `${SITE_URL}/privacy`,
    title: `${BRAND.name} · Privacy`,
    description: "Data use for location, voice, photos, sync and configured services.",
    images: [{ url: "/opengraph-image", width: 1200, height: 630 }],
  },
  twitter: {
    card: "summary_large_image",
    title: `${BRAND.name} · Privacy`,
    description: "Location, voice, sync and service data use.",
    images: ["/opengraph-image"],
  },
};

const COLLECT: [string, string][] = [
  [
    "Account and sync",
    "Signing in and using sync sends account information and synced records to the configured Supabase backend. Local sample exploration does not require an account.",
  ],
  [
    "Diagnostics",
    "App builds configured with a Sentry DSN send crash and error diagnostics to Sentry. This page does not claim that every report is anonymous or that reporting is enabled in every build.",
  ],
  [
    "Web usage events",
    "The website can use configured PostHog analytics for product events. The current client respects Do Not Track and skips analytics when no project key is configured.",
  ],
];

const NEVER_COLLECT: [string, string][] = [
  [
    "Location and exploration",
    "Location access is requested for location features. Confirmed exploration sends the selected coordinates and radius to OpenStreetMap/Overpass. AI requests may include city and experience context; location is not guaranteed to stay only on the device.",
  ],
  [
    "Saved experiences and messages",
    "Saved and completed experiences can be stored locally or synced through the app backend. Sending a message or an attachment shares that content with the selected conversation.",
  ],
  [
    "Voice input",
    "Native voice input uses Apple speech recognition. Web voice input uses the browser speech service. Processing depends on system and service capabilities; this page does not promise that all audio stays on the device. Transcripts submitted to AI go to the configured provider.",
  ],
  [
    "Photos and camera",
    "Creating an experience or attaching a photo can request photo-library or camera access. Only choose content you intend to use in that feature. Permissions can be managed in system settings.",
  ],
];

const THIRD_PARTY: [string, string][] = [
  [
    "Apple and the browser platform",
    "Native maps, speech recognition and purchases use Apple services. Web maps use Mapbox when configured; web speech uses the browser service.",
  ],
  [
    "AI providers",
    "The default native AI provider is DeepSeek. Provider settings or the Pro proxy determine the destination for submitted prompts and context.",
  ],
  [
    "OpenStreetMap / Overpass",
    "Receives coordinates and radius for exploration after confirmation.",
  ],
  ["Supabase", "Provides configured account, sync, conversation and Pro proxy services."],
  [
    "Sentry / PostHog",
    "Receive diagnostics or web product events when configured. Their service policies apply.",
  ],
];

export default function PrivacyEn() {
  const props = {
    copy: copy.en,
    locale: "en" as const,
    homePath: "/",
    altPath: "/zh/privacy",
  };
  return (
    <>
      <MarketingNav {...props} />
      <main id="main">
        <Section className="pt-24 md:pt-32 pb-8">
          <Container width="narrow" className="text-center">
            <Eyebrow dot="accent" className="justify-center">
              Privacy
            </Eyebrow>
            <h1 className="ds-display-xl mt-6 font-display">
              What we collect, and what we don&apos;t.
            </h1>
            <p className="ds-body-xl mt-6 text-fg-muted">
              Updated October 2026. Data use by feature.
            </p>
          </Container>
        </Section>

        <Section className="pt-4 pb-16">
          <Container width="narrow">
            <a
              href={LEGAL_URLS.privacy}
              className="mb-8 inline-flex min-h-[44px] items-center text-accent-interactive underline underline-offset-4"
            >
              Read the full Privacy Policy
            </a>
            <article>
              <h2 className="font-display text-[28px] font-medium text-fg-primary md:text-[32px]">
                What we collect
              </h2>
              <dl className="mt-8 divide-y divide-border-subtle">
                {COLLECT.map(([k, v]) => (
                  <div key={k} className="py-6">
                    <dt className="font-display text-[18px] font-medium text-fg-primary">{k}</dt>
                    <dd className="ds-body-md mt-2 text-fg-muted">{v}</dd>
                  </div>
                ))}
              </dl>
            </article>

            <article className="mt-16">
              <h2 className="font-display text-[28px] font-medium text-fg-primary md:text-[32px]">
                Data handled by feature
              </h2>
              <dl className="mt-8 divide-y divide-border-subtle">
                {NEVER_COLLECT.map(([k, v]) => (
                  <div key={k} className="py-6">
                    <dt className="font-display text-[18px] font-medium text-fg-primary">{k}</dt>
                    <dd className="ds-body-md mt-2 text-fg-muted">{v}</dd>
                  </div>
                ))}
              </dl>
            </article>

            <article className="mt-16">
              <h2 className="font-display text-[28px] font-medium text-fg-primary md:text-[32px]">
                Third parties
              </h2>
              <dl className="mt-8 divide-y divide-border-subtle">
                {THIRD_PARTY.map(([k, v]) => (
                  <div key={k} className="py-6">
                    <dt className="font-display text-[18px] font-medium text-fg-primary">{k}</dt>
                    <dd className="ds-body-md mt-2 text-fg-muted">{v}</dd>
                  </div>
                ))}
              </dl>
            </article>

            <article className="mt-16">
              <h2 className="font-display text-[28px] font-medium text-fg-primary md:text-[32px]">
                Your controls
              </h2>
              <p className="ds-body-lg mt-4 text-fg-muted">
                Manage location, microphone, camera and photo permissions in system settings.
                Account and sync controls are available in the app. This implementation summary does
                not set a data-retention deadline or replace the published legal policy.
              </p>
            </article>
          </Container>
        </Section>
      </main>
      <Footer {...props} />
    </>
  );
}
