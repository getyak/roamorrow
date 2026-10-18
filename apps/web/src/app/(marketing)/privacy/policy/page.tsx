import type { Metadata } from "next";
import { copy } from "@/components/marketing/copy";
import { Footer, MarketingNav } from "@/components/marketing/sections";
import { Container } from "@/components/marketing/Container";
import { Section } from "@/components/marketing/primitives";
import { PolicyText } from "@/components/legal/PolicyText";
import { BRAND, publicUrl } from "@/lib/brand";
import { PRIVACY_CONTENT } from "@/lib/privacy-content";

export const metadata: Metadata = {
  title: "Privacy policy",
  description:
    "The full Roamorrow privacy policy in English and 简体中文, covering information use, service providers, retention, deletion and your choices.",
  alternates: { canonical: publicUrl("/privacy/policy") },
  openGraph: {
    title: `Privacy policy · ${BRAND.name}`,
    url: publicUrl("/privacy/policy"),
    siteName: BRAND.name,
    images: ["/opengraph-image"],
  },
};

export default function PrivacyPolicyPage() {
  const props = { copy: copy.en, locale: "en" as const, homePath: "/", altPath: "/zh/privacy" };
  return (
    <>
      <MarketingNav {...props} />
      <main id="main">
        <Section className="pt-20 pb-24">
          <Container width="narrow">
            <h1 className="ds-display-lg font-display">Privacy policy / 隐私政策</h1>
            <PolicyText text={PRIVACY_CONTENT.intro} />
            <section lang="en" className="mt-16 border-t border-border-subtle pt-8">
              <h2 className="font-display text-[32px] font-medium">English</h2>
              <PolicyText text={PRIVACY_CONTENT.english} />
            </section>
            <section id="zh" lang="zh-CN" className="mt-16 border-t border-border-subtle pt-8">
              <h2 className="font-display text-[32px] font-medium">中文</h2>
              <PolicyText text={PRIVACY_CONTENT.chinese} />
            </section>
          </Container>
        </Section>
      </main>
      <Footer {...props} />
    </>
  );
}
