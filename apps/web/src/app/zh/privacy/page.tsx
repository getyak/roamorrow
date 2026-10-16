import { LEGAL_URLS } from "@/lib/legal";
import type { Metadata } from "next";
import { copy } from "@/components/marketing/copy";
import { Footer, MarketingNav } from "@/components/marketing/sections";
import { Container } from "@/components/marketing/Container";
import { Eyebrow, Section } from "@/components/marketing/primitives";

const SITE_URL = "https://solocompass.app";

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: "隐私 · Solo Compass",
  description: "Solo Compass 的账号、位置、语音、照片、同步与诊断数据如何用于原生和网页功能。",
  alternates: {
    canonical: `${SITE_URL}/zh/privacy`,
    languages: {
      en: `${SITE_URL}/privacy`,
      "zh-CN": `${SITE_URL}/zh/privacy`,
      "x-default": `${SITE_URL}/privacy`,
    },
  },
  openGraph: {
    type: "article",
    url: `${SITE_URL}/zh/privacy`,
    title: "Solo Compass · 隐私",
    description: "位置、语音、照片、同步与配置服务的数据使用说明。",
    locale: "zh_CN",
    alternateLocale: "en_US",
    images: [{ url: "/og/privacy-zh.png", width: 1200, height: 630 }],
  },
  twitter: {
    card: "summary_large_image",
    title: "Solo Compass · 隐私",
    description: "位置、语音、照片、同步与配置服务的数据使用说明。",
    images: ["/og/privacy-zh.png"],
  },
};

const COLLECT: [string, string][] = [
  [
    "账号与同步",
    "登录和使用同步时，账号信息与同步记录会发送到配置的 Supabase 后端。本地示例探索无需账号。",
  ],
  [
    "故障诊断",
    "配置了 Sentry DSN 的应用版本会向 Sentry 发送崩溃和错误诊断。本页不承诺所有报告都匿名，也不表示每个版本都已启用上报。",
  ],
  [
    "网页使用事件",
    "网站可使用配置的 PostHog 记录产品事件。当前客户端尊重 Do Not Track；未配置项目密钥时跳过分析。",
  ],
];

const NEVER_COLLECT: [string, string][] = [
  [
    "位置与探索",
    "位置功能会请求定位权限。确认探索后，选定坐标与半径会发送至 OpenStreetMap/Overpass。AI 请求可能包含城市和体验上下文，位置并非保证只留在设备上。",
  ],
  [
    "收藏、记录与消息",
    "收藏和完成记录可保存在本地，或通过应用后端同步。发送消息或附件时，相应内容会分享至选定对话。",
  ],
  [
    "语音输入",
    "原生语音使用 Apple 语音识别，网页语音使用浏览器语音服务。处理方式取决于系统与服务能力，本页不承诺所有音频都只在本地处理；提交给 AI 的转录文字会发送至配置的服务商。",
  ],
  [
    "照片与相机",
    "创建体验或添加照片附件时，可能请求照片库或相机权限。请选择准备在该功能使用的内容；可在系统设置管理权限。",
  ],
];

const THIRD_PARTY: [string, string][] = [
  [
    "Apple 与浏览器平台",
    "原生地图、语音识别和购买使用 Apple 服务。网页地图配置后使用 Mapbox，网页语音使用浏览器服务。",
  ],
  ["AI 服务商", "原生默认使用 DeepSeek。服务商设置或 Pro 代理决定提交的问题与上下文发往哪里。"],
  ["OpenStreetMap / Overpass", "确认探索后接收坐标和半径。"],
  ["Supabase", "提供配置后的账号、同步、对话和 Pro 代理服务。"],
  ["Sentry / PostHog", "配置启用时接收诊断或网页产品事件，适用各服务的政策。"],
];

export default function PrivacyZh() {
  const props = {
    copy: copy.zh,
    locale: "zh" as const,
    homePath: "/zh",
    altPath: "/privacy",
  };
  return (
    <div lang="zh-CN">
      <MarketingNav {...props} />
      <main id="main">
        <Section className="pt-24 md:pt-32 pb-8">
          <Container width="narrow" className="text-center">
            <Eyebrow dot="accent" className="justify-center">
              隐私
            </Eyebrow>
            <h1 className="ds-display-xl mt-6 font-display">我们收集什么，不收集什么。</h1>
            <p className="ds-body-xl mt-6 text-fg-muted">
              更新于 2026 年 10 月，按功能说明数据用途。
            </p>
          </Container>
        </Section>

        <Section className="pt-4 pb-16">
          <Container width="narrow">
            <a
              href={LEGAL_URLS.privacy}
              className="mb-8 inline-flex min-h-[44px] items-center text-accent-interactive underline underline-offset-4"
            >
              阅读完整隐私政策
            </a>
            <article>
              <h2 className="font-display text-[28px] font-medium text-fg-primary md:text-[32px]">
                我们收集什么
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
                按功能处理的数据
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
                第三方服务
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
                你可以管理的选项
              </h2>
              <p className="ds-body-lg mt-4 text-fg-muted">
                可在系统设置管理定位、麦克风、相机与照片权限，账号和同步选项可在应用内管理。
                此处说明当前功能的数据用途，不设定数据保留期限，也不替代正式发布的法律政策。
              </p>
            </article>
          </Container>
        </Section>
      </main>
      <Footer {...props} />
    </div>
  );
}
