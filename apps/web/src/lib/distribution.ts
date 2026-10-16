/**
 * Distribution configuration — the single source of truth for where the
 * product can actually be obtained (W01).
 *
 * The marketing pages used to hard-code a placeholder App Store link
 * (`id0000000000`). A placeholder store id is worse than no store link: it
 * looks like availability that doesn't exist. This module reads optional
 * env-configured URLs, validates that they are REAL public Apple store /
 * TestFlight destinations, and otherwise reports honest unavailability so
 * callers fall back to the genuine web exploration entry (`/app`).
 *
 * It NEVER invents an id or a price. A missing store link is a fact to
 * report, not a gap to paper over.
 */

export type DistributionKind = "app-store" | "testflight" | "web-app";

export interface Distribution {
  /** Validated public App Store URL, or null when none is configured. */
  readonly appStoreUrl: string | null;
  /** Validated public TestFlight URL, or null when none is configured. */
  readonly testFlightUrl: string | null;
  /** Where the primary CTA should actually go. */
  readonly primaryHref: string;
  readonly primaryKind: DistributionKind;
  /** True only when a validated public store/TestFlight link exists. */
  readonly iosAvailable: boolean;
  /**
   * Honest availability sentence key callers can localize against.
   * "pending" = iOS app exists (native app is the product) but no public
   * download link is configured yet; "available" = a validated link exists.
   */
  readonly availability: "available" | "pending";
}

/** Genuine web exploration entry — always real, never gated on env. */
export const WEB_APP_HREF = "/app";

const APP_STORE_HOSTS = new Set(["apps.apple.com", "itunes.apple.com"]);
const TESTFLIGHT_HOSTS = new Set(["testflight.apple.com"]);

/** Placeholder / obviously-not-real store ids we must never ship. */
const PLACEHOLDER_ID_PATTERNS = [/id0{6,}/i, /id0000000000/i, /\/id0+\b/i];

function parseHttpsUrl(raw: string): URL | null {
  try {
    const url = new URL(raw);
    return url.protocol === "https:" ? url : null;
  } catch {
    return null;
  }
}

function isPlaceholderStoreId(url: URL): boolean {
  const path = url.pathname;
  return PLACEHOLDER_ID_PATTERNS.some((re) => re.test(path));
}

/**
 * A public App Store URL: https on an Apple store host, carrying a plausible
 * app id path and no placeholder id.
 */
export function isPublicAppStoreUrl(raw: string | null | undefined): boolean {
  if (!raw) return false;
  const url = parseHttpsUrl(raw);
  if (!url) return false;
  if (!APP_STORE_HOSTS.has(url.hostname)) return false;
  if (isPlaceholderStoreId(url)) return false;
  // A real listing is /app/<slug>/id<digits> (or /us/app/… style paths).
  return /\/id\d{6,}/.test(url.pathname);
}

/** A public TestFlight URL: https on testflight.apple.com with a real join path. */
export function isPublicTestFlightUrl(raw: string | null | undefined): boolean {
  if (!raw) return false;
  const url = parseHttpsUrl(raw);
  if (!url) return false;
  if (!TESTFLIGHT_HOSTS.has(url.hostname)) return false;
  return url.pathname.startsWith("/join/");
}

/**
 * Resolve the current distribution from an env-like object (defaults to
 * `process.env`). Reads NEXT_PUBLIC_APP_STORE_URL / NEXT_PUBLIC_TESTFLIGHT_URL;
 * any unvalidated value is treated as absent.
 */
export function resolveDistribution(
  env: Record<string, string | undefined> = typeof process !== "undefined" ? process.env : {},
): Distribution {
  const appStoreUrl = isPublicAppStoreUrl(env.NEXT_PUBLIC_APP_STORE_URL)
    ? (env.NEXT_PUBLIC_APP_STORE_URL as string)
    : null;
  const testFlightUrl = isPublicTestFlightUrl(env.NEXT_PUBLIC_TESTFLIGHT_URL)
    ? (env.NEXT_PUBLIC_TESTFLIGHT_URL as string)
    : null;

  if (appStoreUrl) {
    return {
      appStoreUrl,
      testFlightUrl,
      primaryHref: appStoreUrl,
      primaryKind: "app-store",
      iosAvailable: true,
      availability: "available",
    };
  }
  if (testFlightUrl) {
    return {
      appStoreUrl,
      testFlightUrl,
      primaryHref: testFlightUrl,
      primaryKind: "testflight",
      iosAvailable: true,
      availability: "available",
    };
  }
  // No validated public download destination: the real action is the web
  // exploration entry, and iOS availability is honestly "not yet linked".
  return {
    appStoreUrl: null,
    testFlightUrl: null,
    primaryHref: WEB_APP_HREF,
    primaryKind: "web-app",
    iosAvailable: false,
    availability: "pending",
  };
}

export function distributionCopy(kind: DistributionKind, locale: "en" | "zh") {
  const labels = {
    "app-store": {
      en: ["Get on App Store", "The iPhone app is available through the App Store."],
      zh: ["App Store 下载", "通过 App Store 获取 iPhone 版。"],
    },
    testflight: {
      en: [
        "Join the TestFlight beta",
        "The iPhone beta is available through TestFlight; participation depends on open places.",
      ],
      zh: ["加入 TestFlight 测试", "通过 TestFlight 获取 iPhone 测试版，能否加入以测试名额为准。"],
    },
    "web-app": {
      en: [
        "Open the web map",
        "An iOS download link is not available here yet. The web map is open.",
      ],
      zh: ["打开网页地图", "此处尚未提供公开的 iOS 下载链接，可先探索网页地图。"],
    },
  } as const;
  const [action, status] = labels[kind][locale];
  return { action, status };
}
