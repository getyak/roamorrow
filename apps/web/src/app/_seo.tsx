/**
 * SEO — JSON-LD Schema.org structured data.
 * Doc: SEO_STRATEGY.md §5
 *
 * Rendered inline via a Server Component so search engines see
 * it on first crawl without hydration.
 */

import type { Locale } from "@/components/marketing/copy";

import { BRAND, SITE_URL } from "@/lib/brand";

export function HomeJsonLd({ locale }: { locale: Locale }) {
  const url = locale === "zh" ? `${SITE_URL}/zh` : SITE_URL;
  const name = BRAND.name;
  const description =
    locale === "zh"
      ? "为独自旅行者做的 iOS 地图应用。跨来源交叉编译，AI 展示不确定性，无广告，说明数据用途。免费版即真实产品；Pro 为月度/年度订阅，价格以 App Store 实时为准。"
      : "A map-first companion for solo travelers on iOS. Cross-referenced sources, honest AI, no ads, data use explained. Free tier is the real product; Pro is a monthly or yearly subscription, priced live in the App Store.";

  const softwareApp = {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    name,
    url,
    operatingSystem: "iOS 17.0+",
    applicationCategory: "TravelApplication",
    description,
    // No invented prices: only the genuinely free web tier is offered here.
    // Pro pricing is live App Store data and cannot be hard-coded.
    offers: [
      {
        "@type": "Offer",
        price: "0",
        priceCurrency: locale === "zh" ? "CNY" : "USD",
        description: locale === "zh" ? "免费（网页地图与免费层）" : "Free (web map and free tier)",
      },
    ],
    creator: {
      "@type": "Organization",
      name: BRAND.name,
      url: SITE_URL,
    },
    inLanguage: locale === "zh" ? "zh-CN" : "en",
  };

  const organization = {
    "@context": "https://schema.org",
    "@type": "Organization",
    name: BRAND.name,
    url: SITE_URL,
    logo: `${SITE_URL}/brand/roamorrow-mark.svg`,
    sameAs: [BRAND.repositoryUrl],
  };

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(softwareApp) }}
      />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(organization) }}
      />
    </>
  );
}
