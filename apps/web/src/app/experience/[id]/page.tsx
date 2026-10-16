/**
 * Scenario D — `/experience/[id]` (server component)
 *
 * Server-rendered for proper SEO. `generateMetadata` produces title /
 * description / OpenGraph / Twitter from the in-memory Lisbon dataset.
 *
 * Layout:
 *   - Browser bar mock + breadcrumb
 *   - Title block (serif italic on en, PingFang SC on zh) with category color wash
 *   - Two-column body: narrative + Quick Facts aside
 *   - "For you" AI block
 *   - Nearby cards (links to other /experience/[id])
 *   - Footer credit
 */

import Link from "next/link";
import { notFound } from "next/navigation";
import type { Metadata } from "next";
import { WEB_CATS, type WebExperience } from "@/lib/lisbon-data";
import { findExperienceAcrossCities, type WebCity } from "@/lib/cities-data";

const FONT_DISPLAY = '-apple-system, "SF Pro Display", "Inter", system-ui, sans-serif';
const FONT_MONO = '"JetBrains Mono", "SF Mono", ui-monospace, monospace';
const FONT_SERIF = '"Fraunces", Georgia, "Cormorant Garamond", serif';
const FONT_CN = '"PingFang SC", "Hiragino Sans GB", system-ui, sans-serif';

type Lang = "zh" | "en";

interface PageProps {
  readonly params: Promise<{ id: string }>;
  readonly searchParams: Promise<Record<string, string | string[] | undefined>>;
}

function resolveLang(searchParams: Record<string, string | string[] | undefined>): Lang {
  const v = searchParams.lang;
  const single = Array.isArray(v) ? v[0] : v;
  return single === "en" ? "en" : "zh";
}

export async function generateMetadata({ params, searchParams }: PageProps): Promise<Metadata> {
  const { id } = await params;
  const sp = await searchParams;
  const lang = resolveLang(sp);
  const found = findExperienceAcrossCities(id);
  if (!found) return { title: "Solo Compass — Not found" };
  const { exp, city } = found;

  const title = lang === "zh" ? exp.titleZh : exp.title;
  const place = lang === "zh" ? exp.placeZh : exp.place;
  const description = lang === "zh" ? exp.whyZh : exp.why;
  const fullTitle = `${title} — ${place} · ${lang === "zh" ? city.zh : city.en} · Solo Compass`;

  return {
    title: fullTitle,
    description,
    openGraph: {
      title: fullTitle,
      description,
      type: "article",
      siteName: "Solo Compass",
      locale: lang === "zh" ? "zh_CN" : "en_US",
    },
    twitter: {
      card: "summary_large_image",
      title: fullTitle,
      description,
    },
    alternates: {
      languages: {
        en: `/experience/${id}?lang=en`,
        zh: `/experience/${id}`,
      },
    },
  };
}

export default async function ExperiencePage({ params, searchParams }: PageProps) {
  const { id } = await params;
  const sp = await searchParams;
  const lang = resolveLang(sp);
  const found = findExperienceAcrossCities(id);
  if (!found) notFound();
  const { exp, city } = found;
  const nearby = city.experiences
    .filter((e) => e.id !== exp.id)
    .map((e) => ({ e, d: Math.hypot(exp.x - e.x, exp.y - e.y) }))
    .sort((a, b) => a.d - b.d)
    .slice(0, 2)
    .map((x) => x.e);
  return <ExperienceView exp={exp} nearby={nearby} lang={lang} city={city} />;
}

function ExperienceView({
  exp,
  nearby,
  lang,
  city,
}: {
  exp: WebExperience;
  nearby: readonly WebExperience[];
  lang: Lang;
  city: WebCity;
}) {
  const cat = WEB_CATS[exp.cat];
  const fontStack = lang === "zh" ? FONT_CN : FONT_DISPLAY;

  const title = lang === "zh" ? exp.titleZh : exp.title;
  const place = lang === "zh" ? exp.placeZh : exp.place;
  const intro = lang === "zh" ? exp.whyZh : exp.why;
  const moment = lang === "zh" ? exp.momentZh : exp.moment;
  const guideNote = (lang === "zh" ? exp.tagsZh : exp.tags).join(" · ");

  const T =
    lang === "zh"
      ? {
          breadcrumb: `${city.zh} · ${cat.zh}`,
          quickFacts: "速览",
          forYou: "指南提示",
          when: "什么时候去",
          whenLabel: ["位置", "最佳时段", "停留", "人多吗", "一人去合适吗", "花费"],
          why: "那一刻",
          nearby: "附近还有",
          addToTrip: "在城市指南中查看",
          viewMap: "城市指南",
          metaSeo: "此页为示例体验内容，出行前请确认当前信息。",
          backToCity: `← 回到 ${city.zh}`,
          mins: "分钟",
        }
      : {
          breadcrumb: `${city.en} · ${cat.en}`,
          quickFacts: "Quick facts",
          forYou: "Guide note",
          when: "When to go",
          whenLabel: ["Where", "Best time", "Stay", "Crowded?", "Solo-friendly?", "Cost"],
          why: "The moment",
          nearby: "Nearby",
          addToTrip: "View in city guide",
          viewMap: "City guide",
          metaSeo: "An illustrative experience. Confirm current details before travel.",
          backToCity: `← Back to ${city.en}`,
          mins: "min",
        };

  const facts: ReadonlyArray<readonly [string, string]> = [
    [T.whenLabel[0]!, `${exp.neighborhood} · ${exp.walkMin} ${T.mins}`],
    [
      T.whenLabel[1]!,
      `${exp.bestHours[0]}:00 – ${exp.bestHours[exp.bestHours.length - 1]! + 1}:00`,
    ],
    [T.whenLabel[2]!, `${exp.durationMin} ${T.mins}`],
    [
      T.whenLabel[3]!,
      lang === "zh" ? { quiet: "安静", calm: "舒适", busy: "较热闹" }[exp.crowd] : exp.crowd,
    ],
    [T.whenLabel[4]!, lang === "zh" ? "是 · 推荐独自前往" : "Yes · solo recommended"],
    [T.whenLabel[5]!, exp.pricePill],
  ];

  return (
    <main
      id="main"
      className="experience-detail"
      style={{
        minHeight: "100vh",
        background: "#F1ECDF",
        fontFamily: fontStack,
        color: "#1A1612",
      }}
    >
      <p
        style={{
          maxWidth: 760,
          margin: "0 auto 16px",
          padding: "0 18px",
          fontSize: 13,
          lineHeight: 1.6,
          color: "#6D6358",
        }}
      >
        {lang === "zh"
          ? "指南预览 · 本页为示例体验，出行前请确认位置、营业与当前情况。"
          : "Guide preview · This is an illustrative experience. Confirm location, opening hours and current conditions before travel."}
      </p>
      <article
        style={{
          maxWidth: 760,
          margin: "0 auto",
          background: "#FBF7F0",
          borderRadius: 12,
          overflow: "hidden",
          border: "0.5px solid #E5DDCD",
          boxShadow: "0 1px 3px rgba(0,0,0,0.05)",
        }}
      >
        <div
          className="exp-topbar"
          style={{
            padding: "11px 22px",
            borderBottom: "0.5px solid #E5DDCD",
            display: "flex",
            alignItems: "center",
            gap: 12,
            justifyContent: "space-between",
            background: "#F8F4ED",
          }}
        >
          <span
            className="exp-brand"
            style={{ fontFamily: FONT_DISPLAY, fontSize: 13, fontWeight: 600, color: "#5C4F3E" }}
          >
            Solo Compass
          </span>
          <Link
            href={`/${city.slug}${lang === "en" ? "?lang=en" : ""}`}
            className="exp-back"
            style={{
              fontFamily: FONT_DISPLAY,
              fontSize: 13,
              color: "#5C4F3E",
              textDecoration: "none",
              padding: "4px 10px",
              borderRadius: 5,
              border: "0.5px solid #E5DDCD",
              background: "#FFF",
            }}
          >
            {T.backToCity}
          </Link>
        </div>

        <div
          className="exp-pad"
          style={{
            paddingTop: 20,
            fontFamily: FONT_MONO,
            fontSize: 10,
            color: "#74695C",
            letterSpacing: 1.5,
            textTransform: "uppercase",
          }}
        >
          {T.breadcrumb}
        </div>

        <div
          className="exp-pad"
          style={{
            paddingTop: 14,
            paddingBottom: 30,
            background: `linear-gradient(180deg, ${cat.color}10, transparent 60%)`,
          }}
        >
          <h1
            style={{
              fontFamily: lang === "zh" ? FONT_CN : FONT_SERIF,
              fontSize: lang === "zh" ? "clamp(26px, 8vw, 42px)" : "clamp(30px, 9vw, 52px)",
              fontWeight: lang === "zh" ? 600 : 400,
              fontStyle: lang === "zh" ? "normal" : "italic",
              letterSpacing: "-1px",
              margin: "0 0 12px",
              lineHeight: 1.05,
              color: "#1A1612",
              overflowWrap: "anywhere",
            }}
          >
            {title}
          </h1>
          <div
            style={{
              fontFamily: lang === "zh" ? FONT_CN : FONT_SERIF,
              fontSize: lang === "zh" ? 18 : 22,
              fontStyle: lang === "zh" ? "normal" : "italic",
              fontWeight: lang === "zh" ? 500 : 400,
              color: "#6D4B29",
              marginBottom: 22,
              letterSpacing: "-0.3px",
            }}
          >
            {place} · {exp.neighborhood}
          </div>
          <div
            style={{
              fontFamily: fontStack,
              fontSize: 17,
              lineHeight: 1.55,
              color: "#1A1612",
              maxWidth: 600,
              letterSpacing: "-0.1px",
            }}
          >
            {intro}
          </div>
        </div>

        <div
          className="exp-pad exp-body-grid"
          style={{
            paddingBottom: 32,
          }}
        >
          <div>
            <h2
              style={{
                fontFamily: lang === "zh" ? FONT_CN : FONT_SERIF,
                fontSize: lang === "zh" ? 22 : 26,
                fontWeight: lang === "zh" ? 600 : 500,
                fontStyle: lang === "zh" ? "normal" : "italic",
                margin: "0 0 12px",
                letterSpacing: "-0.4px",
              }}
            >
              {T.why}
            </h2>
            <p
              style={{
                fontFamily: fontStack,
                fontSize: 15,
                lineHeight: 1.7,
                color: "#3D352A",
                margin: "0 0 28px",
                paddingLeft: 12,
                borderLeft: `2px solid ${cat.color}`,
                fontStyle: lang === "zh" ? "normal" : "italic",
              }}
            >
              “{moment}”
            </p>

            <h2
              style={{
                fontFamily: lang === "zh" ? FONT_CN : FONT_SERIF,
                fontSize: lang === "zh" ? 22 : 26,
                fontWeight: lang === "zh" ? 600 : 500,
                fontStyle: lang === "zh" ? "normal" : "italic",
                margin: "0 0 12px",
                letterSpacing: "-0.4px",
              }}
            >
              {T.when}
            </h2>
            <p
              style={{
                fontFamily: fontStack,
                fontSize: 14.5,
                lineHeight: 1.65,
                color: "#3D352A",
                margin: "0 0 24px",
              }}
            >
              {facts[1]![1]} · {exp.durationMin} {T.mins}
            </p>

            <div
              style={{
                background: "#FFF7EA",
                border: "0.5px solid #EBD9B8",
                borderRadius: 8,
                padding: 16,
                display: "flex",
                gap: 12,
                alignItems: "flex-start",
              }}
            >
              <div
                style={{
                  width: 22,
                  height: 22,
                  flexShrink: 0,
                  borderRadius: 11,
                  background: "linear-gradient(135deg, #FFE7C4, #C98628)",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  color: "#FFF",
                  fontSize: 11,
                }}
              >
                ✦
              </div>
              <div style={{ flex: 1 }}>
                <div
                  style={{
                    fontFamily: FONT_MONO,
                    fontSize: 10,
                    color: "#755125",
                    letterSpacing: 1.2,
                    textTransform: "uppercase",
                    marginBottom: 6,
                  }}
                >
                  {T.forYou}
                </div>
                <div
                  style={{
                    fontFamily: fontStack,
                    fontSize: 13.5,
                    color: "#3D352A",
                    lineHeight: 1.55,
                  }}
                >
                  {guideNote}
                </div>
              </div>
            </div>
          </div>

          <aside
            style={{
              padding: 18,
              background: "#FFF",
              border: "0.5px solid #E5DDCD",
              borderRadius: 8,
              alignSelf: "start",
            }}
          >
            <div
              style={{
                fontFamily: FONT_MONO,
                fontSize: 12,
                color: "#74695C",
                letterSpacing: 1.5,
                textTransform: "uppercase",
                marginBottom: 14,
                paddingBottom: 10,
                borderBottom: "0.5px solid #E5DDCD",
              }}
            >
              {T.quickFacts}
            </div>
            {facts.map(([k, v], i) => (
              <div key={k} style={{ marginBottom: i === facts.length - 1 ? 0 : 12 }}>
                <div
                  style={{
                    fontFamily: FONT_MONO,
                    fontSize: 12,
                    color: "#74695C",
                    letterSpacing: 1,
                    textTransform: "uppercase",
                    marginBottom: 3,
                  }}
                >
                  {k}
                </div>
                <div
                  style={{
                    fontFamily: fontStack,
                    fontSize: 12.5,
                    color: "#1A1612",
                    lineHeight: 1.4,
                  }}
                >
                  {v}
                </div>
              </div>
            ))}
            <div
              style={{
                marginTop: 16,
                paddingTop: 14,
                borderTop: "0.5px solid #E5DDCD",
                display: "flex",
                flexDirection: "column",
                gap: 6,
              }}
            >
              <Link
                href={`/${city.slug}?experience=${encodeURIComponent(exp.id)}${lang === "en" ? "&lang=en" : ""}`}
                className="exp-cta"
                style={{
                  padding: "8px 12px",
                  borderRadius: 5,
                  background: "var(--accent)",
                  border: "none",
                  color: "#FFF7EA",
                  fontFamily: fontStack,
                  fontSize: 12,
                  fontWeight: 600,
                  cursor: "pointer",
                  textAlign: "center",
                  textDecoration: "none",
                }}
              >
                {T.addToTrip}
              </Link>
              <Link
                href={`/${city.slug}${lang === "en" ? "?lang=en" : ""}`}
                className="exp-cta"
                style={{
                  padding: "8px 12px",
                  borderRadius: 5,
                  background: "transparent",
                  border: "0.5px solid #D6CEC0",
                  color: "var(--accent)",
                  fontFamily: fontStack,
                  fontSize: 12,
                  cursor: "pointer",
                  textAlign: "center",
                  textDecoration: "none",
                }}
              >
                ↗ {T.viewMap}
              </Link>
              <div
                style={{
                  marginTop: 8,
                  fontFamily: FONT_MONO,
                  fontSize: 12,
                  color: "#74695C",
                  letterSpacing: 0.5,
                  lineHeight: 1.5,
                }}
              >
                {lang === "zh"
                  ? "示例指南，尚未实时核实。"
                  : "Guide sample; current conditions aren’t verified."}
              </div>
            </div>
          </aside>
        </div>

        {nearby.length > 0 && (
          <div className="exp-pad" style={{ paddingBottom: 36 }}>
            <div
              style={{
                fontFamily: FONT_MONO,
                fontSize: 10,
                color: "#74695C",
                letterSpacing: 2,
                textTransform: "uppercase",
                paddingTop: 24,
                marginBottom: 14,
                borderTop: "0.5px solid #E5DDCD",
              }}
            >
              {T.nearby}
            </div>
            <div
              className="exp-nearby-grid"
              style={{
                gap: 12,
              }}
            >
              {nearby.map((it) => {
                const ncat = WEB_CATS[it.cat];
                const ntitle = lang === "zh" ? it.titleZh : it.title;
                const nplace = lang === "zh" ? it.placeZh : it.place;
                return (
                  <Link
                    key={it.id}
                    href={`/experience/${it.id}${lang === "en" ? "?lang=en" : ""}`}
                    style={{
                      padding: 16,
                      background: "#FFF",
                      border: "0.5px solid #E5DDCD",
                      borderRadius: 8,
                      cursor: "pointer",
                      textDecoration: "none",
                      color: "inherit",
                      display: "block",
                    }}
                  >
                    <div
                      style={{
                        display: "flex",
                        alignItems: "center",
                        gap: 6,
                        marginBottom: 6,
                      }}
                    >
                      <div
                        style={{
                          width: 6,
                          height: 6,
                          borderRadius: 3,
                          background: ncat.color,
                        }}
                      />
                      <span
                        style={{
                          fontFamily: FONT_MONO,
                          fontSize: 12,
                          color: "#6D4B29",
                          letterSpacing: 1,
                          textTransform: "uppercase",
                          fontWeight: 600,
                        }}
                      >
                        {lang === "zh" ? ncat.zh : ncat.en}
                      </span>
                    </div>
                    <div
                      style={{
                        fontFamily: lang === "zh" ? FONT_CN : FONT_SERIF,
                        fontSize: lang === "zh" ? 16 : 19,
                        fontWeight: lang === "zh" ? 600 : 500,
                        fontStyle: lang === "zh" ? "normal" : "italic",
                        color: "#1A1612",
                        marginBottom: 4,
                        letterSpacing: "-0.2px",
                      }}
                    >
                      {ntitle}
                    </div>
                    <div
                      style={{
                        fontFamily: fontStack,
                        fontSize: 12,
                        color: "#5C4F3E",
                        lineHeight: 1.45,
                      }}
                    >
                      {nplace} · {it.walkMin} {T.mins}
                    </div>
                  </Link>
                );
              })}
            </div>
          </div>
        )}

        <div
          className="exp-pad exp-footer"
          style={{
            paddingTop: 20,
            paddingBottom: 20,
            borderTop: "0.5px solid #E5DDCD",
            background: "#F8F4ED",
            display: "flex",
            alignItems: "center",
            gap: 14,
          }}
        >
          <div
            style={{
              width: 22,
              height: 22,
              borderRadius: 11,
              background: "linear-gradient(135deg, #FFE7C4, #C98628)",
              flexShrink: 0,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
            }}
          >
            <svg width="11" height="11" viewBox="0 0 14 14" fill="none">
              <circle cx="7" cy="7" r="5.5" stroke="#FFF" strokeWidth="1" />
              <path d="M7 3 L8 7 L7 11 L6 7 Z" fill="#FFF" />
            </svg>
          </div>
          <div
            style={{
              flex: 1,
              fontFamily: fontStack,
              fontSize: 11.5,
              color: "#5C4F3E",
              lineHeight: 1.5,
            }}
          >
            {T.metaSeo}
          </div>
        </div>
      </article>
    </main>
  );
}
