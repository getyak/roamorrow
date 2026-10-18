import type { Metadata } from "next";
import Link from "next/link";
import { copy } from "@/components/marketing/copy";
import { Footer, MarketingNav } from "@/components/marketing/sections";
import { Container } from "@/components/marketing/Container";
import { Section } from "@/components/marketing/primitives";
import { BRAND, publicUrl } from "@/lib/brand";

export const metadata: Metadata = {
  title: "Support",
  description:
    "Contact Roamorrow for product support, release questions, or private requests about your account and data.",
  alternates: { canonical: publicUrl("/support") },
  openGraph: {
    title: `Support · ${BRAND.name}`,
    url: publicUrl("/support"),
    siteName: BRAND.name,
    images: ["/opengraph-image"],
  },
};

export default function SupportPage() {
  const props = { copy: copy.en, locale: "en" as const, homePath: "/", altPath: "/zh" };
  return (
    <>
      <MarketingNav {...props} />
      <main id="main">
        <Section className="pt-24 pb-24">
          <Container width="narrow">
            <h1 className="ds-display-xl font-display">How can we help?</h1>
            <p className="ds-body-xl mt-8 text-fg-muted">
              For product support or release questions, email{" "}
              <a className="underline" href={`mailto:${BRAND.supportEmail}`}>
                {BRAND.supportEmail}
              </a>
              .
            </p>
            <p className="ds-body-lg mt-8 text-fg-muted">
              For account access, corrections, or data deletion requests, email{" "}
              <a className="underline" href={`mailto:${BRAND.privacyEmail}`}>
                {BRAND.privacyEmail}
              </a>
              . Include the feature or account involved, and keep passwords and API keys out of your
              message.
            </p>
            <p className="ds-body-lg mt-8 text-fg-muted">
              Read our{" "}
              <Link href="/privacy" className="underline">
                privacy policy
              </Link>{" "}
              and{" "}
              <Link href="/terms" className="underline">
                terms of service
              </Link>{" "}
              for details.
            </p>
            <div lang="zh-CN" className="mt-12 border-t border-border-subtle pt-8">
              <h2 className="font-display text-[28px] font-medium">需要帮助？</h2>
              <p className="ds-body-lg mt-4 text-fg-muted">
                产品和发布问题请联系 {BRAND.supportEmail}；账号与数据请求请联系 {BRAND.privacyEmail}
                。说明相关功能或账号即可，请勿发送密码或 API 密钥。
              </p>
            </div>
          </Container>
        </Section>
      </main>
      <Footer {...props} />
    </>
  );
}
