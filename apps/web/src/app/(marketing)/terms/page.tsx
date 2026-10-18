import type { Metadata } from "next";
import { copy } from "@/components/marketing/copy";
import { Footer, MarketingNav } from "@/components/marketing/sections";
import { Container } from "@/components/marketing/Container";
import { Section } from "@/components/marketing/primitives";
import { BRAND, publicUrl } from "@/lib/brand";
import { TERMS_CONTENT } from "@/lib/terms-content";
import { PolicyText } from "@/components/legal/PolicyText";

export const metadata: Metadata = {
  title: "Terms of service",
  description:
    "Roamorrow service terms, including travel information, AI assistance, your content, privacy permissions and purchases. English and 简体中文.",
  alternates: { canonical: publicUrl("/terms") },
  openGraph: {
    title: `Terms of service · ${BRAND.name}`,
    url: publicUrl("/terms"),
    siteName: BRAND.name,
    images: ["/opengraph-image"],
  },
};

export default function TermsPage() {
  const props = { copy: copy.en, locale: "en" as const, homePath: "/", altPath: "/zh" };
  return (
    <>
      <MarketingNav {...props} />
      <main id="main">
        <Section className="pt-20 pb-24">
          <Container width="narrow">
            <h1 className="ds-display-lg font-display">Terms of service / 用户协议</h1>
            <PolicyText text={TERMS_CONTENT.intro} />
            <section lang="en" className="mt-16 border-t border-border-subtle pt-8">
              <h2 className="font-display text-[32px] font-medium">English</h2>
              <PolicyText text={TERMS_CONTENT.english} />
            </section>
            <section lang="zh-CN" className="mt-16 border-t border-border-subtle pt-8">
              <h2 className="font-display text-[32px] font-medium">中文</h2>
              <PolicyText text={TERMS_CONTENT.chinese} />
            </section>
          </Container>
        </Section>
      </main>
      <Footer {...props} />
    </>
  );
}
