import type { Metadata } from "next";
import { copy } from "@/components/marketing/copy";
import { Footer, MarketingNav } from "@/components/marketing/sections";
import { Container } from "@/components/marketing/Container";
import { ButtonLink, Eyebrow, Section } from "@/components/marketing/primitives";
import { BRAND, SITE_URL } from "@/lib/brand";

export const metadata: Metadata = {
  title: "Get Roamorrow",
  description:
    "Explore Roamorrow in your browser. A public iPhone download link is not available here yet; check this page for the current release status.",
  alternates: { canonical: `${SITE_URL}/download` },
  openGraph: {
    type: "website",
    url: `${SITE_URL}/download`,
    siteName: BRAND.name,
    title: "Get Roamorrow",
    description: "The web map is open. A public iPhone download link is not available here yet.",
    images: [{ url: "/opengraph-image", width: 1200, height: 630 }],
  },
};

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
        <Section className="pt-24 pb-24 md:pt-32">
          <Container width="narrow">
            <Eyebrow dot="accent">Get Roamorrow</Eyebrow>
            <h1 className="ds-display-xl mt-6 font-display">Your next detour starts here.</h1>
            <p className="ds-body-xl mt-6 max-w-xl text-fg-muted">
              Explore the web map in your browser. No installation needed.
            </p>
            <div className="mt-10">
              <ButtonLink href={BRAND.webAppPath} variant="primary">
                Open web map
              </ButtonLink>
            </div>
            <article className="mt-20 border-t border-border-subtle pt-10">
              <h2 className="font-display text-[28px] font-medium">Roamorrow for iPhone</h2>
              <p className="ds-body-lg mt-4 text-fg-muted">
                A public App Store or TestFlight download link is not available here yet. We will
                add the release link when it is ready. The native app requires iOS 17 or later.
              </p>
              <p className="ds-body-lg mt-6 text-fg-muted">
                For release or device questions, contact{" "}
                <a className="underline" href={`mailto:${BRAND.supportEmail}`}>
                  {BRAND.supportEmail}
                </a>
                .
              </p>
            </article>
          </Container>
        </Section>
      </main>
      <Footer {...props} />
    </>
  );
}
