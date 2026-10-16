import type { Metadata } from "next";
import { copy } from "@/components/marketing/copy";
import { Footer, MarketingNav, Pricing } from "@/components/marketing/sections";
import { Container } from "@/components/marketing/Container";
import { Eyebrow, Section } from "@/components/marketing/primitives";
import { HomeJsonLd } from "../../_seo";

const SITE_URL = "https://solocompass.app";
export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: "Pricing · Solo Compass",
  description:
    "Explore the free map first. Pro is monthly or yearly; some ritual and archive views remain previews. Review current entitlements and App Store pricing before purchase.",
  alternates: {
    canonical: `${SITE_URL}/pricing`,
    languages: {
      en: `${SITE_URL}/pricing`,
      "zh-CN": `${SITE_URL}/zh/pricing`,
      "x-default": `${SITE_URL}/pricing`,
    },
  },
  openGraph: {
    url: `${SITE_URL}/pricing`,
    title: "Solo Compass · Pricing",
    description: "Monthly or yearly Pro on top of a real free tier. No ads.",
    images: [{ url: "/og/pricing.png", width: 1200, height: 630 }],
  },
};

const FAQ_EN = [
  {
    q: "What's in Free vs Pro?",
    a: "The free map includes experiences, check-ins and your footprint. Pro adds AI and currently available route tools. Some ritual, archive and export views remain previews or read-only; review current entitlements before purchase.",
  },
  {
    q: "How much AI do I get?",
    a: "Pro includes a daily allowance — up to 30 AI answers and 60 explanations per day. It is a real limit, not unlimited, and the app shows where you stand.",
  },
  {
    q: "How is my data handled?",
    a: "After you confirm exploration, selected coordinates and radius go to OpenStreetMap/Overpass. AI requests can include city and experience context. Account and sync features may require sign-in; see the data-use page.",
  },
  {
    q: "Why is the price not on this page?",
    a: "Prices vary by region and change over time. The App Store shows the live price and any free-trial eligibility before you pay — we would rather be honest than quote a number we can't guarantee.",
  },
  {
    q: "Will you ever run ads?",
    a: "No.",
  },
  {
    q: "Can I try before I buy?",
    a: "Yes — the web map is open to everyone right now, and the free tier of the iPhone app is genuinely useful rather than a demo.",
  },
];

export default function PricingPage() {
  const props = {
    copy: copy.en,
    locale: "en" as const,
    homePath: "/",
    altPath: "/zh",
  };
  return (
    <>
      <HomeJsonLd locale="en" />
      <MarketingNav {...props} />
      <main id="main">
        <Section className="pt-24 md:pt-32 pb-8">
          <Container width="narrow" className="text-center">
            <Eyebrow dot="accent" className="justify-center">
              {copy.en.pricing.eyebrow}
            </Eyebrow>
            <h1 className="ds-display-xl mt-6 font-display">{copy.en.pricing.title}</h1>
            <p className="ds-body-xl mt-6">{copy.en.pricing.sub}</p>
          </Container>
        </Section>
        <Pricing {...props} />

        <Section className="border-t border-border-subtle">
          <Container width="narrow">
            <Eyebrow dot="sun">Frequently asked</Eyebrow>
            <h2 className="ds-display-md mt-6 font-display">
              Honest answers to what people actually ask.
            </h2>
            <dl className="mt-12 divide-y divide-border-subtle">
              {FAQ_EN.map((item, i) => (
                <div key={i} className="py-8">
                  <dt className="font-display text-[20px] font-medium leading-tight text-fg-primary">
                    {item.q}
                  </dt>
                  <dd className="ds-body-lg mt-3 text-fg-muted">{item.a}</dd>
                </div>
              ))}
            </dl>
          </Container>
        </Section>
      </main>
      <Footer {...props} />
    </>
  );
}
