/**
 * Scenario C — `/trip/[slug]` (server component)
 * Public, shareable trip recap. 760-wide article, magazine-style.
 *
 * Server-rendered for SEO. `generateMetadata` produces title /
 * description / OpenGraph / Twitter from the in-memory trip dataset.
 * Sibling `opengraph-image.tsx` auto-supplies the OG image.
 */

import Link from "next/link";
import { notFound } from "next/navigation";
import { ShareButton } from "@/components/ShareButton";
import type { Metadata } from "next";
import { BRAND, publicUrl } from "@/lib/brand";
import { findTripBySlug, type Trip } from "@/lib/trips-data";

const FONT_DISPLAY = '-apple-system, "SF Pro Display", "Inter", system-ui, sans-serif';
const FONT_MONO = '"JetBrains Mono", "SF Mono", ui-monospace, monospace';
const FONT_SERIF = '"Fraunces", Georgia, "Cormorant Garamond", serif';
const FONT_CN = '"PingFang SC", "Hiragino Sans GB", system-ui, sans-serif';

type Lang = "zh" | "en";

interface PageProps {
  readonly params: Promise<{ slug: string }>;
  readonly searchParams: Promise<Record<string, string | string[] | undefined>>;
}

function resolveLang(searchParams: Record<string, string | string[] | undefined>): Lang {
  const v = searchParams.lang;
  const single = Array.isArray(v) ? v[0] : v;
  return single === "zh" ? "zh" : "en";
}

function sampleTripIntro(lang: "zh" | "en"): string {
  return lang === "zh"
    ? "这是一份示例行程，展示如何记录一次城市漫步。作者、故事与统计仅作演示。"
    : "An illustrative trip recap. The author, story and statistics are examples of how a city walk could be recorded.";
}

export async function generateMetadata({ params, searchParams }: PageProps): Promise<Metadata> {
  const { slug } = await params;
  const sp = await searchParams;
  const lang = resolveLang(sp);
  const trip = findTripBySlug(slug);
  if (!trip) return { title: "Not found" };

  const title = lang === "zh" ? trip.titleZh : trip.titleEn;
  const description = sampleTripIntro(lang);
  const fullTitle = `${title} · ${lang === "zh" ? "行程示例" : "Sample trip"} · Roamorrow`;

  return {
    title: { absolute: fullTitle },
    description,
    openGraph: {
      title: fullTitle,
      description,
      type: "article",
      url: publicUrl(`/trip/${slug}${lang === "zh" ? "?lang=zh" : ""}`),
      siteName: BRAND.name,
      locale: lang === "zh" ? "zh_CN" : "en_US",
    },
    twitter: {
      card: "summary_large_image",
      title: fullTitle,
      description,
    },
    alternates: {
      canonical: publicUrl(`/trip/${slug}${lang === "zh" ? "?lang=zh" : ""}`),
      languages: {
        en: publicUrl(`/trip/${slug}`),
        "zh-CN": publicUrl(`/trip/${slug}?lang=zh`),
        "x-default": publicUrl(`/trip/${slug}`),
      },
    },
  };
}

export default async function TripPage({ params, searchParams }: PageProps) {
  const { slug } = await params;
  const sp = await searchParams;
  const lang = resolveLang(sp);
  const trip = findTripBySlug(slug);
  if (!trip) notFound();
  return <TripRecap trip={trip} lang={lang} />;
}

function TripRecap({ trip, lang }: { trip: Trip; lang: Lang }) {
  const fontStack = lang === "zh" ? FONT_CN : FONT_DISPLAY;

  const T =
    lang === "zh"
      ? {
          by: "作者",
          solo: "独自",
          stats: { walked: "走了", places: "体验", favorite: "最爱" },
          dayLabels: ["第一天", "第二天", "第三天", "第四天"],
          // Truthful copy (R2): the button opens the real city guide — no
          // invented compass.io address, no plan-building promise.
          cta1: "从这座城市的指南开始规划",
          cta2: "示例指南 · 出行前请核实",
          cta3: "地点、地图与诚实笔记",
          ctaButton: "打开城市指南",
          topMeta: "Roamorrow · 行程示例",
          poweredBy: "Roamorrow 行程回顾示例",
          share: "分享",
          km: "公里",
        }
      : {
          by: "A trip by",
          solo: "Solo",
          stats: { walked: "Walked", places: "Places", favorite: "Favorite" },
          dayLabels: ["Day 1", "Day 2", "Day 3", "Day 4"],
          cta1: "Plan from this city's guide",
          cta2: "Sample guide · verify before you go",
          cta3: "Places, maps and honest notes",
          ctaButton: "Open the city guide",
          topMeta: "Roamorrow · Sample trip",
          poweredBy: "A sample Roamorrow trip recap",
          share: "Share",
          km: "km",
        };

  const monthLabel = lang === "zh" ? trip.monthLabelZh : trip.monthLabel;
  const title = lang === "zh" ? trip.titleZh : trip.titleEn;
  const intro = sampleTripIntro(lang);
  const quote = lang === "zh" ? trip.quoteZh : trip.quote;

  return (
    <main
      id="main"
      className="trip-recap"
      style={{
        minHeight: "100vh",
        background: "#F1ECDF",
        fontFamily: fontStack,
        color: "#1A1612",
      }}
    >
      <article
        style={{
          maxWidth: 760,
          margin: "0 auto",
          background: "#F8F4ED",
          borderRadius: 12,
          overflow: "hidden",
          boxShadow: "0 1px 3px rgba(0,0,0,0.05)",
          border: "0.5px solid #E5DDCD",
        }}
      >
        {/* Top bar */}
        <div
          className="trip-topbar"
          style={{
            padding: "12px 22px",
            borderBottom: "0.5px solid #E5DDCD",
            display: "flex",
            alignItems: "center",
            gap: 10,
            background: "#FBF7F0",
          }}
        >
          <div
            style={{
              width: 18,
              height: 18,
              borderRadius: 9,
              background: "linear-gradient(135deg, #FFE7C4, #C98628)",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
            }}
          >
            <svg width="9" height="9" viewBox="0 0 14 14" fill="none">
              <circle cx="7" cy="7" r="5.5" stroke="#FFF" strokeWidth="1" />
            </svg>
          </div>
          <span
            className="trip-crumb"
            style={{
              fontFamily: FONT_MONO,
              fontSize: 11,
              color: "#74695C",
              letterSpacing: 0.5,
            }}
          >
            {/* Truthful page meta (R2): no invented compass.io address. */}
            {T.topMeta}
          </span>
          <span style={{ flex: 1 }} />
          <ShareButton
            title={title}
            text={intro}
            labels={{
              idle: T.share,
              shared: lang === "zh" ? "已分享" : "Shared",
              copied: lang === "zh" ? "链接已复制" : "Link copied",
              failed:
                lang === "zh"
                  ? "分享失败，请手动复制地址栏链接"
                  : "Sharing failed — copy the URL from the address bar",
            }}
          />
        </div>

        {/* Hero */}
        <div className="trip-section" style={{ paddingTop: 40, paddingBottom: 32 }}>
          <div
            style={{
              fontFamily: FONT_MONO,
              fontSize: 10,
              color: "#74695C",
              letterSpacing: 2,
              textTransform: "uppercase",
              marginBottom: 18,
            }}
          >
            {T.by} · {trip.author} · {monthLabel}
          </div>
          <h1
            style={{
              fontFamily: lang === "zh" ? FONT_CN : FONT_SERIF,
              fontSize: lang === "zh" ? "clamp(28px, 8vw, 44px)" : "clamp(32px, 9vw, 56px)",
              fontWeight: lang === "zh" ? 600 : 400,
              fontStyle: lang === "zh" ? "normal" : "italic",
              lineHeight: 1.05,
              letterSpacing: lang === "zh" ? "-0.5px" : "-1.5px",
              color: "#1A1612",
              margin: "0 0 14px",
              overflowWrap: "anywhere",
            }}
          >
            {title}
          </h1>
          <div
            style={{
              fontFamily: fontStack,
              fontSize: 16,
              lineHeight: 1.55,
              color: "#5C4F3E",
              maxWidth: 520,
              marginBottom: 26,
            }}
          >
            {intro}
          </div>

          {/* Stats row */}
          <div
            className="trip-stats"
            style={{
              display: "flex",
              gap: 0,
              padding: "14px 0",
              borderTop: "0.5px solid #E5DDCD",
              borderBottom: "0.5px solid #E5DDCD",
            }}
          >
            {(
              [
                {
                  label: T.stats.walked,
                  value: `${trip.stats.walkedKm} ${T.km}`,
                  mono: true,
                  accent: false,
                },
                {
                  label: T.stats.places,
                  value: String(trip.stats.places),
                  mono: true,
                  accent: false,
                },
                {
                  label: T.stats.favorite,
                  value: trip.stats.favorite,
                  mono: false,
                  accent: false,
                },
                { label: T.solo, value: "★", mono: false, accent: true },
              ] as const
            ).map((s, i) => (
              <div
                key={s.label}
                className="trip-stat"
                style={{
                  borderLeft: i > 0 ? "0.5px solid #E5DDCD" : "none",
                }}
              >
                <div
                  style={{
                    fontFamily: FONT_MONO,
                    fontSize: 12,
                    color: "#74695C",
                    letterSpacing: 1,
                    textTransform: "uppercase",
                    marginBottom: 6,
                  }}
                >
                  {s.label}
                </div>
                <div
                  style={{
                    fontFamily: s.mono ? FONT_MONO : lang === "zh" ? FONT_CN : FONT_SERIF,
                    fontSize: s.mono ? 18 : 16,
                    fontWeight: s.mono ? 500 : 600,
                    fontStyle: !s.mono && lang !== "zh" ? "italic" : "normal",
                    color: s.accent ? "var(--accent-amber)" : "#1A1612",
                    letterSpacing: s.mono ? 0 : "-0.2px",
                  }}
                >
                  {s.value}
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Pull quote */}
        <div className="trip-section" style={{ paddingBottom: 36 }}>
          <div
            style={{
              fontFamily: lang === "zh" ? FONT_CN : FONT_SERIF,
              fontSize: lang === "zh" ? 20 : 24,
              fontStyle: lang === "zh" ? "normal" : "italic",
              fontWeight: lang === "zh" ? 500 : 400,
              lineHeight: 1.4,
              color: "#1A1612",
              paddingLeft: 18,
              borderLeft: "2px solid var(--accent-amber)",
              letterSpacing: "-0.2px",
            }}
          >
            “{quote}”
          </div>
        </div>

        {/* Day cards */}
        <div className="trip-section" style={{ paddingBottom: 40 }}>
          {trip.days.map((d, i) => {
            const dayTitle = lang === "zh" ? d.titleZh : d.title;
            const label = T.dayLabels[i] ?? (lang === "zh" ? `第 ${i + 1} 天` : `Day ${i + 1}`);
            return (
              <div
                key={d.title}
                className="trip-day-grid"
                style={{
                  padding: "20px 0",
                  borderTop: "0.5px solid #E5DDCD",
                  alignItems: "flex-start",
                  gap: 18,
                }}
              >
                <div className="trip-day-meta">
                  <div
                    style={{
                      fontFamily: FONT_MONO,
                      fontSize: 10,
                      color: "#74695C",
                      letterSpacing: 1,
                      marginBottom: 4,
                    }}
                  >
                    {label.toUpperCase()}
                  </div>
                  <div
                    style={{
                      fontSize: 22,
                      color: "var(--accent-amber)",
                      lineHeight: 1,
                    }}
                  >
                    {d.icon}
                  </div>
                </div>
                <div className="trip-day-main">
                  <div
                    style={{
                      fontFamily: lang === "zh" ? FONT_CN : FONT_SERIF,
                      fontSize: lang === "zh" ? 17 : 20,
                      fontWeight: lang === "zh" ? 600 : 500,
                      fontStyle: lang === "zh" ? "normal" : "italic",
                      color: "#1A1612",
                      marginBottom: 8,
                      letterSpacing: "-0.2px",
                      lineHeight: 1.3,
                    }}
                  >
                    {dayTitle}
                  </div>
                  <div
                    style={{
                      fontFamily: fontStack,
                      fontSize: 13,
                      color: "#5C4F3E",
                      lineHeight: 1.5,
                    }}
                  >
                    {d.places.join(" · ")}
                  </div>
                </div>
                <div className="trip-day-km">
                  <div
                    style={{
                      fontFamily: FONT_MONO,
                      fontSize: 12,
                      color: "#74695C",
                      letterSpacing: 1,
                      marginBottom: 2,
                    }}
                  >
                    KM
                  </div>
                  <div
                    style={{
                      fontFamily: FONT_MONO,
                      fontSize: 16,
                      color: "#1A1612",
                      fontWeight: 500,
                    }}
                  >
                    {d.walkedKm}
                  </div>
                </div>
              </div>
            );
          })}
        </div>

        {/* CTA */}
        <div
          className="trip-cta"
          style={{
            padding: "28px 32px",
            background: "linear-gradient(135deg, #2A2218 0%, #1A1612 100%)",
            borderRadius: 12,
            color: "var(--dark-fg)",
          }}
        >
          <div style={{ flex: 1 }}>
            <div
              style={{
                fontFamily: lang === "zh" ? FONT_CN : FONT_SERIF,
                fontSize: lang === "zh" ? 19 : 22,
                fontWeight: lang === "zh" ? 600 : 400,
                fontStyle: lang === "zh" ? "normal" : "italic",
                color: "var(--dark-fg)",
                marginBottom: 4,
                letterSpacing: "-0.3px",
              }}
            >
              {T.cta1}
            </div>
            <div
              style={{
                fontFamily: fontStack,
                fontSize: 12.5,
                color: "var(--dark-fg-muted)",
              }}
            >
              {T.cta3} · {T.cta2}
            </div>
          </div>
          <Link
            href={`/${trip.citySlug}${lang === "zh" ? "?lang=zh" : ""}`}
            className="trip-cta-button"
            style={{
              padding: "10px 18px",
              borderRadius: 6,
              background: "var(--accent-amber)",
              border: "none",
              fontFamily: fontStack,
              fontSize: 13,
              fontWeight: 600,
              color: "var(--dark-surface)",
              cursor: "pointer",
              whiteSpace: "nowrap",
              textDecoration: "none",
            }}
          >
            {/* The action the link really performs (R2): open the city guide. */}
            {T.ctaButton}
          </Link>
        </div>

        {/* Footer */}
        <div
          style={{
            padding: "16px 22px",
            borderTop: "0.5px solid #E5DDCD",
            background: "#FBF7F0",
            fontFamily: FONT_MONO,
            fontSize: 10,
            color: "#74695C",
            letterSpacing: 0.5,
            textAlign: "center",
          }}
        >
          {T.poweredBy}
        </div>
      </article>
    </main>
  );
}
