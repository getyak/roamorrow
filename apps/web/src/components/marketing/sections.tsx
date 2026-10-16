/**
 * Marketing sections — Nav / Hero / Problem / Pillars / Trust / Pricing / Footer
 * Doc: WEB_LANDING_DESIGN.md §4
 *
 * All sections take (copy, locale, homePath) as props so they render identically
 * for /en and /zh routes. The page files (app/page.tsx and app/zh/page.tsx) do
 * the composition — sections know nothing about routing.
 */

import Link from "next/link";
import { Container } from "./Container";
import { ButtonLink, Chip, Eyebrow, IPhoneFrame, Section } from "./primitives";
import { DayPageMock } from "./DayPageMock";
import { HeroMotif } from "./HeroMotif";
import { MobileNav } from "./MobileNav";
import { CapabilityMock } from "./CapabilityMocks";
import { resolveDistribution, distributionCopy } from "@/lib/distribution";
import type { Copy, Locale } from "./copy";

// Distribution is resolved from validated env (W01). With no validated
// public store/TestFlight URL the real action is the web map (`/app`) and
// iOS availability is stated honestly — the placeholder id0000000000 link
// is gone for good.
const dist = resolveDistribution();

interface Props {
  copy: Copy;
  locale: Locale;
  homePath: string; // "/" or "/zh"
  altPath: string; // "/zh" or "/"
}

/* ============================================================
   Nav
   ============================================================ */

export function MarketingNav({ copy, locale, homePath, altPath }: Props) {
  const items = [
    { href: `${homePath === "/" ? "" : homePath}/#features`, label: copy.nav.features },
    { href: `/lisbon${locale === "en" ? "?lang=en" : ""}`, label: copy.nav.cities },
    { href: locale === "zh" ? "/zh/pricing" : "/pricing", label: copy.nav.pricing },
    { href: locale === "zh" ? "/zh/manifesto" : "/manifesto", label: copy.nav.manifesto },
  ];
  const ctaLabel = distributionCopy(dist.primaryKind, locale).action;
  const ctaHref = dist.primaryHref;
  return (
    <nav
      className="sticky top-0 z-40 border-b border-border-subtle backdrop-blur-xl"
      style={{ background: "color-mix(in oklab, var(--bg-warm) 82%, transparent)" }}
    >
      <Container width="wide">
        <div className="flex h-[72px] items-center justify-between gap-6">
          <Link
            href={homePath}
            className="flex min-h-[44px] items-center gap-2 font-display text-[20px] font-medium tracking-tight"
          >
            <SoloCompassMark />
            <span>Solo Compass</span>
          </Link>
          <div className="hidden items-center gap-1 md:flex">
            {items.map((it) => (
              <Link
                key={it.href}
                href={it.href}
                className="group relative inline-flex min-h-[44px] items-center rounded-md px-3 py-2 font-body text-[14px] font-normal text-fg-muted transition-colors duration-fast hover:text-fg-primary"
              >
                {it.label}
                <span
                  aria-hidden
                  className="absolute inset-x-3 -bottom-[2px] h-[1.5px] origin-left scale-x-0 bg-accent transition-transform duration-normal ease-decel group-hover:scale-x-100"
                />
              </Link>
            ))}
          </div>
          <div className="flex items-center gap-3">
            <Link
              href={altPath}
              className="hidden min-h-[44px] min-w-[44px] items-center justify-center font-mono text-[11px] font-medium uppercase tracking-[0.16em] text-fg-muted hover:text-fg-primary md:inline-flex"
            >
              {copy.langSwitch}
            </Link>
            <ButtonLink href={ctaHref} variant="primary" className="hidden md:inline-flex">
              {ctaLabel}
            </ButtonLink>
            <MobileNav
              items={items}
              langLabel={copy.langSwitch}
              langHref={altPath}
              ctaLabel={ctaLabel}
              ctaHref={ctaHref}
              menuLabel={locale === "zh" ? "打开菜单" : "Open menu"}
              closeLabel={locale === "zh" ? "关闭菜单" : "Close menu"}
            />
          </div>
        </div>
      </Container>
    </nav>
  );
}

function SoloCompassMark() {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" aria-hidden>
      <circle
        cx="12"
        cy="12"
        r="11"
        fill="none"
        stroke="var(--accent-interactive)"
        strokeWidth="1.4"
      />
      <circle cx="12" cy="12" r="2.6" fill="var(--sun-gold)" />
      <path d="M12 2 L14 12 L12 22 L10 12 Z" fill="var(--accent-interactive)" opacity="0.85" />
    </svg>
  );
}

/* ============================================================
   Hero — cascading reveal
   ============================================================ */

export function Hero({ copy, locale }: Props) {
  const ctaLabel = distributionCopy(dist.primaryKind, locale).action;
  return (
    <Section className="relative overflow-hidden pt-10 md:pt-14">
      <HeroMotif />
      <Container width="wide" className="relative">
        <div className="grid grid-cols-1 items-center gap-10 md:grid-cols-12 md:gap-8">
          <div className="md:col-span-7">
            <div className="ds-reveal" style={{ animationDelay: "0ms" }}>
              <Eyebrow dot="sun">{copy.hero.eyebrow}</Eyebrow>
            </div>
            <h1 className="ds-display-2xl mt-6 font-display">
              {copy.hero.h1Lines.map((line, i) => (
                <span
                  key={i}
                  className="ds-reveal block"
                  style={{ animationDelay: `${200 + i * 120}ms` }}
                >
                  {line}
                </span>
              ))}
            </h1>
            <p className="ds-body-xl ds-reveal mt-6 max-w-xl" style={{ animationDelay: "620ms" }}>
              {copy.hero.sub}
            </p>
            <div
              className="ds-reveal mt-8 flex flex-wrap items-center gap-5"
              style={{ animationDelay: "760ms" }}
            >
              <ButtonLink href={dist.primaryHref} variant="primary">
                {ctaLabel}
              </ButtonLink>
              <a
                href="#features"
                className="inline-flex min-h-[44px] items-center font-body text-[16px] font-medium text-fg-primary underline-offset-4 hover:underline"
              >
                {copy.hero.ctaSecondary} →
              </a>
            </div>
            {/* Honest iOS availability — no placeholder store link, no
                invented release date. */}
            <p
              className="ds-reveal ds-body-sm mt-4 max-w-md"
              style={{ animationDelay: "820ms" }}
              data-testid="hero-ios-status"
            >
              {distributionCopy(dist.primaryKind, locale).status}
            </p>
          </div>
          <div className="md:col-span-5">
            <div
              className="ds-reveal-scale flex justify-center md:justify-end"
              style={{ animationDelay: "200ms" }}
            >
              <IPhoneFrame tilt>
                <DayPageMock />
              </IPhoneFrame>
            </div>
            <p className="mt-3 text-center font-mono text-[10px] uppercase tracking-[0.16em] text-fg-subtle md:text-right">
              {locale === "zh" ? "预览示意" : "Preview illustration"}
            </p>
          </div>
        </div>
      </Container>
    </Section>
  );
}

/* ============================================================
   Problem — editorial monologue
   ============================================================ */

export function Problem({ copy }: Props) {
  return (
    <Section className="border-t border-border-subtle">
      <Container width="narrow">
        <Eyebrow dot="omen">{copy.problem.eyebrow}</Eyebrow>
        <div className="mt-12 space-y-8">
          {copy.problem.paragraphs.map((p, i) => (
            <p
              key={i}
              className={`font-body text-[22px] leading-[1.7] ${
                i === copy.problem.paragraphs.length - 1
                  ? "text-fg-primary font-medium"
                  : i < 2
                    ? "text-fg-primary"
                    : "text-fg-muted"
              }`}
            >
              {renderMuted(p.text, p.muted)}
            </p>
          ))}
        </div>
      </Container>
    </Section>
  );
}

function renderMuted(text: string, muted?: string[]): React.ReactNode {
  if (!muted?.length) return text;
  const parts: React.ReactNode[] = [text];
  muted.forEach((m, idx) => {
    for (let i = 0; i < parts.length; i++) {
      const part = parts[i];
      if (typeof part === "string" && part.includes(m)) {
        const [before, ...rest] = part.split(m);
        const after = rest.join(m);
        parts.splice(
          i,
          1,
          before,
          <span key={`m-${idx}`} className="text-fg-muted font-medium">
            {m}
          </span>,
          after,
        );
        break;
      }
    }
  });
  return <>{parts}</>;
}

/* ============================================================
   Pillars — three warm cards
   ============================================================ */

export function Pillars({ copy }: Props) {
  return (
    <Section id="features" className="border-t border-border-subtle">
      <Container>
        <div className="max-w-2xl">
          <Eyebrow dot="sun">{copy.pillars.eyebrow}</Eyebrow>
          <h2 className="ds-display-lg mt-6 font-display">{copy.pillars.title}</h2>
          <p className="ds-body-xl mt-6">{copy.pillars.sub}</p>
        </div>
        <div className="mt-16 grid grid-cols-1 gap-6 md:grid-cols-3">
          {copy.pillars.items.map((item, i) => (
            <article
              key={i}
              // Static container: light border encodes grouping only — no
              // hover-lift, no fake affordance.
              className="flex flex-col rounded-lg border border-border-subtle bg-surface-white p-8 pt-10"
            >
              <span
                className={`h-3 w-3 rounded-full ${
                  item.dot === "sun"
                    ? "bg-sun-gold"
                    : item.dot === "omen"
                      ? "bg-omen-gold"
                      : "bg-accent"
                }`}
                aria-hidden
              />
              <h3 className="ds-display-sm mt-6 font-display">{item.title}</h3>
              <p className="ds-body-md mt-4 text-fg-muted">{item.body}</p>
            </article>
          ))}
        </div>
      </Container>
    </Section>
  );
}

/* ============================================================
   Capabilities — six product screens (deep app tie-in)
   ============================================================ */

type CapKind = "askSolo" | "blindbox" | "capsule" | "omen" | "bestNow" | "brag";

const CAPABILITY_ORDER: {
  kind: CapKind;
  bulletsKey: "askSolo" | "blindbox" | "capsule" | "omen" | "bestNow" | "brag";
}[] = [
  { kind: "askSolo", bulletsKey: "askSolo" },
  { kind: "blindbox", bulletsKey: "blindbox" },
  { kind: "capsule", bulletsKey: "capsule" },
  { kind: "omen", bulletsKey: "omen" },
  { kind: "bestNow", bulletsKey: "bestNow" },
  { kind: "brag", bulletsKey: "brag" },
];

export function Capabilities({ copy, locale }: Props) {
  return (
    <Section id="capabilities" className="relative bg-bg-warm">
      <Container width="wide">
        <div className="max-w-[720px]">
          <Eyebrow dot="sun">{copy.capabilities.eyebrow}</Eyebrow>
          <h2 className="ds-display-xl mt-6 font-display">{copy.capabilities.title}</h2>
          <p className="ds-body-lg mt-6 text-fg-muted">{copy.capabilities.sub}</p>
          <p className="ds-body-md mt-3 text-fg-muted">
            {locale === "zh"
              ? "以下包含功能预览；部分仪式与归档页面当前仅供预览或只读，不承诺为已开放的订阅权益。"
              : "These examples include previews. Some ritual and archive views are currently preview-only or read-only and are not promised as available subscription benefits."}
          </p>
          <p className="ds-body-md mt-3 font-mono uppercase tracking-[0.14em] text-fg-subtle">
            {copy.capabilities.intro}
          </p>
        </div>

        <div className="mt-20 space-y-32">
          {CAPABILITY_ORDER.map(({ kind }, i) => {
            const block = copy[kind];
            const flip = i % 2 === 1;
            return (
              <article
                key={kind}
                data-capability={kind}
                className="grid grid-cols-1 items-center gap-12 md:grid-cols-2 md:gap-20"
              >
                <div className={flip ? "md:order-2" : ""}>
                  <div className="flex justify-center">
                    <IPhoneFrame tilt={i % 3 === 1} className="max-w-[280px]">
                      <CapabilityMock kind={kind} copy={copy} />
                    </IPhoneFrame>
                  </div>
                </div>
                <div className={flip ? "md:order-1" : ""}>
                  <Chip
                    tone={
                      kind === "askSolo"
                        ? "accent"
                        : kind === "blindbox"
                          ? "warning"
                          : kind === "capsule"
                            ? "accent"
                            : kind === "omen"
                              ? "sun"
                              : kind === "bestNow"
                                ? "success"
                                : "sun"
                    }
                  >
                    {block.eyebrow}
                  </Chip>
                  <h3 className="ds-display-lg mt-6 font-display">{block.title}</h3>
                  <p className="ds-body-lg mt-6 text-fg-muted">{block.body}</p>
                  <ul className="mt-8 space-y-4">
                    {block.bullets.map((b, bi) => (
                      <li key={bi} className="flex gap-3">
                        <span
                          aria-hidden
                          className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-accent"
                        />
                        <span className="ds-body-md text-fg-primary">{b}</span>
                      </li>
                    ))}
                  </ul>
                </div>
              </article>
            );
          })}
        </div>
      </Container>
    </Section>
  );
}

/* ============================================================
   Trust — three promises
   ============================================================ */

export function Trust({ copy }: Props) {
  return (
    <Section
      className="relative bg-surface-sunken"
      style={{
        // Soft warm-white bleed at both edges — no hard border, no fake "card
        // dropped into the page" look. Trust is a valley of quieter light.
        boxShadow:
          "inset 0 24px 32px -32px rgba(31,26,20,0.05), inset 0 -24px 32px -32px rgba(31,26,20,0.05)",
      }}
    >
      <Container width="narrow">
        <Eyebrow dot="accent">{copy.trust.eyebrow}</Eyebrow>
        <h2 className="ds-display-xl mt-6 font-display">{copy.trust.title}</h2>
        <div className="mt-16 space-y-12 divide-y divide-border-subtle">
          {copy.trust.items.map((item, i) => (
            <div key={i} className={i === 0 ? "" : "pt-12"}>
              <h3 className="font-display text-[26px] font-medium leading-tight text-fg-primary">
                {item.heading}
              </h3>
              <p className="ds-body-lg mt-4 text-fg-muted">{item.body}</p>
            </div>
          ))}
        </div>
      </Container>
    </Section>
  );
}

/* ============================================================
   Pricing — two-card comparison
   ============================================================ */

export function Pricing({ copy, locale }: Props) {
  // With no validated store link the plan CTAs honestly route to the
  // availability page, and Free routes to the real web map — never back to
  // the pricing page itself (W01).
  const planHref = dist.iosAvailable
    ? dist.primaryHref
    : locale === "zh"
      ? "/download"
      : "/download";
  const planCta = dist.iosAvailable
    ? distributionCopy(dist.primaryKind, locale).action
    : locale === "zh"
      ? "查看 iOS 可用性"
      : "Check iOS availability";
  return (
    <Section id="pricing" className="border-t border-border-subtle">
      <Container>
        <div className="mx-auto max-w-2xl text-center">
          <Eyebrow dot="accent" className="justify-center">
            {copy.pricing.eyebrow}
          </Eyebrow>
          <h2 className="ds-display-lg mt-6 font-display">{copy.pricing.title}</h2>
          <p className="ds-body-xl mt-6 text-fg-muted">{copy.pricing.sub}</p>
        </div>

        <div className="mx-auto mt-16 grid max-w-4xl grid-cols-1 gap-6 md:grid-cols-2">
          {/* Monthly */}
          <article className="flex flex-col rounded-xl border border-border-default bg-surface-white p-10">
            <div className="flex items-baseline justify-between">
              <h3 className="font-display text-[22px] font-medium">{copy.pricing.monthly.name}</h3>
            </div>
            <div className="mt-6 flex items-baseline gap-2">
              <span className="font-display text-[26px] font-medium">
                {copy.pricing.monthly.price}
              </span>
              <span className="ds-body-sm">{copy.pricing.monthly.pricePer}</span>
            </div>
            <p className="ds-body-md mt-4 text-fg-muted">{copy.pricing.monthly.tagline}</p>
            <ul className="mt-8 space-y-3">
              {copy.pricing.monthly.features.map((f, i) => (
                <li
                  key={i}
                  className="flex items-start gap-3 font-body text-[15px] text-fg-primary"
                >
                  <CheckGlyph />
                  <span>{f}</span>
                </li>
              ))}
            </ul>
            <div className="mt-10">
              <ButtonLink href={planHref} variant="secondary" className="w-full">
                {planCta}
              </ButtonLink>
            </div>
          </article>

          {/* Yearly */}
          <article className="relative flex flex-col rounded-xl border border-accent-border bg-accent-soft p-10">
            <Chip tone="accent" className="absolute -top-3 left-8">
              {copy.pricing.yearly.badge}
            </Chip>
            <div className="flex items-baseline justify-between">
              <h3 className="font-display text-[22px] font-medium">{copy.pricing.yearly.name}</h3>
            </div>
            <div className="mt-6 flex items-baseline gap-2">
              <span className="font-display text-[26px] font-medium">
                {copy.pricing.yearly.price}
              </span>
              <span className="ds-body-sm">{copy.pricing.yearly.pricePer}</span>
            </div>
            <p className="ds-body-md mt-4 text-fg-muted">{copy.pricing.yearly.tagline}</p>
            <ul className="mt-8 space-y-3">
              {copy.pricing.yearly.features.map((f, i) => (
                <li
                  key={i}
                  className="flex items-start gap-3 font-body text-[15px] text-fg-primary"
                >
                  <CheckGlyph filled />
                  <span>{f}</span>
                </li>
              ))}
            </ul>
            <div className="mt-10">
              <ButtonLink href={planHref} variant="primary" className="w-full">
                {planCta}
              </ButtonLink>
            </div>
          </article>
        </div>

        <p className="mx-auto mt-8 max-w-2xl text-center font-body text-[13px] text-fg-subtle">
          {copy.pricing.priceNote}
        </p>

        <div className="mt-6 text-center">
          <ButtonLink href="/app" variant="ghost">
            {copy.pricing.free}
          </ButtonLink>
        </div>
      </Container>
    </Section>
  );
}

function CheckGlyph({ filled }: { filled?: boolean }) {
  return (
    <span
      aria-hidden
      className={`mt-[3px] flex h-4 w-4 shrink-0 items-center justify-center rounded-full ${
        filled ? "bg-accent text-bg-warm" : "border border-border-default text-fg-primary"
      }`}
    >
      <svg width="9" height="9" viewBox="0 0 9 9" fill="none">
        <path
          d="M1.5 4.5 L3.5 6.5 L7.5 2.5"
          stroke="currentColor"
          strokeWidth="1.6"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
    </span>
  );
}

/* ============================================================
   Footer
   ============================================================ */

export function Footer({ copy }: Props) {
  return (
    <footer className="border-t border-border-subtle bg-surface-sunken pt-24 pb-16">
      <Container>
        <p className="ds-body-lg max-w-2xl text-fg-primary">{copy.footer.tagline}</p>
        <div className="mt-16 grid grid-cols-2 gap-8 md:grid-cols-4">
          <div className="col-span-2 md:col-span-1">
            <div className="flex min-h-[44px] items-center gap-2 font-display text-[18px] font-medium">
              <SoloCompassMark />
              Solo Compass
            </div>
          </div>
          {copy.footer.columns.map((col) => (
            <div key={col.heading}>
              <h4 className="font-mono text-[11px] font-medium uppercase tracking-[0.16em] text-fg-subtle">
                {col.heading}
              </h4>
              <ul className="mt-4 space-y-3">
                {col.links.map((l) => (
                  <li key={l.href}>
                    <Link
                      href={l.href}
                      className="inline-flex min-h-[44px] items-center font-body text-[15px] text-fg-muted hover:text-fg-primary"
                    >
                      {l.label}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
        <div className="mt-16 border-t border-border-subtle pt-8 font-body text-[13px] text-fg-subtle">
          {copy.footer.bottom}
        </div>
      </Container>
    </footer>
  );
}
