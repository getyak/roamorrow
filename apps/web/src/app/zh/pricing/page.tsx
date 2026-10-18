import type { Metadata } from "next";
import { copy } from "@/components/marketing/copy";
import { Footer, MarketingNav, Pricing } from "@/components/marketing/sections";
import { Container } from "@/components/marketing/Container";
import { Eyebrow, Section } from "@/components/marketing/primitives";
import { HomeJsonLd } from "../../_seo";

import { BRAND, SITE_URL } from "@/lib/brand";
export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: "价格",
  description:
    "先探索免费地图。Pro 按月或按年订阅，部分仪式与归档仍为预览；购买前请查看当前权益与 App Store 价格。",
  alternates: {
    canonical: `${SITE_URL}/zh/pricing`,
    languages: {
      en: `${SITE_URL}/pricing`,
      "zh-CN": `${SITE_URL}/zh/pricing`,
      "x-default": `${SITE_URL}/pricing`,
    },
  },
  openGraph: {
    url: `${SITE_URL}/zh/pricing`,
    title: `${BRAND.name} · 价格`,
    description: "免费版即真实产品，Pro 按月/按年订阅。价格以 App Store 实时为准，无广告。",
    images: [{ url: "/zh/opengraph-image", width: 1200, height: 630 }],
  },
};

const FAQ_ZH = [
  {
    q: "Free 和 Pro 有什么区别？",
    a: "免费地图包含体验、打卡与足迹。Pro 提供 AI 和当前开放的路线工具；部分仪式、归档与导出仍为预览或只读，购买前请查看当前开放的权益。",
  },
  {
    q: "每天能用多少 AI？",
    a: "Pro 包含每日额度 —— 最多 30 次回答、60 次解释。这是真实上限，不是「无限」，App 里能看到当前用量。",
  },
  {
    q: "我的数据怎么处理？",
    a: "确认探索后，选定坐标和半径会发送至 OpenStreetMap/Overpass。AI 请求可能包含城市和体验上下文，账号与同步功能可能需要登录；细节见数据使用页。",
  },
  {
    q: "为什么这页不写价格？",
    a: "价格因地区而异，也会调整。付款前 App Store 会显示实时价格和免费试用资格 —— 我们宁可诚实，也不写一个保证不了的数字。",
  },
  {
    q: "以后会不会接广告？",
    a: "不会。",
  },
  {
    q: "可以先试再买吗？",
    a: "可以 —— 网页地图现在就对所有人开放，iPhone 版的免费层也是能真正用起来的产品，不是演示。",
  },
];

export default function PricingPageZh() {
  const props = {
    copy: copy.zh,
    locale: "zh" as const,
    homePath: "/zh",
    altPath: "/",
  };
  return (
    <div lang="zh-CN">
      <HomeJsonLd locale="zh" />
      <MarketingNav {...props} />
      <main id="main">
        <Section className="pt-24 md:pt-32 pb-8">
          <Container width="narrow" className="text-center">
            <Eyebrow dot="accent" className="justify-center">
              {copy.zh.pricing.eyebrow}
            </Eyebrow>
            <h1 className="ds-display-xl mt-6 font-display">{copy.zh.pricing.title}</h1>
            <p className="ds-body-xl mt-6">{copy.zh.pricing.sub}</p>
          </Container>
        </Section>
        <Pricing {...props} />

        <Section className="border-t border-border-subtle">
          <Container width="narrow">
            <Eyebrow dot="sun">常见问题</Eyebrow>
            <h2 className="ds-display-md mt-6 font-display">真实用户会问的问题，诚实回答。</h2>
            <dl className="mt-12 divide-y divide-border-subtle">
              {FAQ_ZH.map((item, i) => (
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
    </div>
  );
}
