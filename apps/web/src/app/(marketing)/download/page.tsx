import type { Metadata } from "next";
import { copy } from "@/components/marketing/copy";
import { Footer, MarketingNav } from "@/components/marketing/sections";
import { Container } from "@/components/marketing/Container";
import { ButtonLink, Eyebrow, Section } from "@/components/marketing/primitives";
import { resolveDistribution, distributionCopy } from "@/lib/distribution";

const SITE_URL = "https://solocompass.app";

const dist = resolveDistribution();
const availability = distributionCopy(dist.primaryKind, "en");

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: "Download · Solo Compass for iOS",
  // W01: no placeholder store id, no invented price or availability. The
  // page states where things actually stand and offers the real web entry.
  description: availability.status,
  alternates: {
    canonical: `${SITE_URL}/download`,
    languages: {
      en: `${SITE_URL}/download`,
      "zh-CN": `${SITE_URL}/download`,
      "x-default": `${SITE_URL}/download`,
    },
  },
  openGraph: {
    type: "website",
    url: `${SITE_URL}/download`,
    title: "Solo Compass for iOS — availability",
    description: availability.status,
    images: [{ url: "/og/download.png", width: 1200, height: 630 }],
  },
  twitter: {
    card: "summary_large_image",
    title: "Solo Compass for iOS — availability",
    description: availability.status,
    images: ["/og/download.png"],
  },
};

const REQUIREMENTS: [string, string][] = [
  ["Device", "iPhone (iOS 17.0 or later)"],
  ["Languages", "English, 简体中文"],
  ["Price", "Free tier · Pro is monthly or yearly, priced live in the App Store"],
  ["Status", availability.status],
];

export default function DownloadPage() {
  const props = {
    copy: copy.en,
    locale: "en" as const,
    homePath: "/",
    altPath: "/zh",
  };
  return (
    <>
      <MarketingNav {...props} />
      <main id="main">
        <Section className="pt-24 pb-12 md:pt-32">
          <Container width="narrow" className="text-center">
            <Eyebrow dot="accent" className="justify-center">
              Download
            </Eyebrow>
            <h1 className="ds-display-xl mt-6 font-display">Solo Compass on iPhone.</h1>
            <p className="ds-body-xl mt-6 text-fg-muted">{availability.status}</p>
            <div className="mt-10 flex flex-wrap justify-center gap-4">
              {dist.iosAvailable ? (
                <ButtonLink href={dist.primaryHref} variant="primary">
                  {availability.action}
                </ButtonLink>
              ) : (
                <ButtonLink href="/app" variant="primary">
                  Open the web map
                </ButtonLink>
              )}
            </div>
          </Container>
        </Section>

        <Section className="pb-24">
          <Container width="narrow">
            <article>
              <h2 className="font-display text-[28px] font-medium text-fg-primary md:text-[32px]">
                Requirements
              </h2>
              <dl className="mt-8 divide-y divide-border-subtle">
                {REQUIREMENTS.map(([k, v]) => (
                  <div key={k} className="flex justify-between gap-6 py-4">
                    <dt className="font-body text-[15px] font-medium text-fg-primary">{k}</dt>
                    <dd className="text-right font-body text-[15px] text-fg-muted">{v}</dd>
                  </div>
                ))}
              </dl>
              <p className="mt-6 font-body text-[13px] text-fg-subtle">
                Prices and any free-trial eligibility are shown live in the App Store before you pay
                — nothing on this page invents a price or an availability date.
              </p>
            </article>

            <article className="mt-16">
              <h2 className="font-display text-[28px] font-medium text-fg-primary md:text-[32px]">
                Not on Android yet.
              </h2>
              <p className="ds-body-lg mt-4 text-fg-muted">
                You can explore the web map on Android. An Android app is not publicly available.
              </p>
            </article>
          </Container>
        </Section>
      </main>
      <Footer {...props} />
    </>
  );
}
