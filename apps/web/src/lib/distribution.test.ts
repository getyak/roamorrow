import { describe, expect, it } from "vitest";
import {
  WEB_APP_HREF,
  isPublicAppStoreUrl,
  isPublicTestFlightUrl,
  resolveDistribution,
  distributionCopy,
} from "./distribution";

describe("isPublicAppStoreUrl", () => {
  it("accepts a real https apps.apple.com listing", () => {
    expect(isPublicAppStoreUrl("https://apps.apple.com/app/solo-compass/id6478234512")).toBe(true);
  });

  it("rejects the shipped placeholder id0000000000", () => {
    expect(isPublicAppStoreUrl("https://apps.apple.com/app/solo-compass/id0000000000")).toBe(false);
    expect(isPublicAppStoreUrl("https://apps.apple.com/us/app/x/id0000000000?mt=8")).toBe(false);
  });

  it("rejects non-Apple hosts and non-https", () => {
    expect(isPublicAppStoreUrl("https://example.com/app/id6478234512")).toBe(false);
    expect(isPublicAppStoreUrl("http://apps.apple.com/app/x/id6478234512")).toBe(false);
  });

  it("rejects empty, unparsable and id-less paths", () => {
    expect(isPublicAppStoreUrl("")).toBe(false);
    expect(isPublicAppStoreUrl("not a url")).toBe(false);
    expect(isPublicAppStoreUrl("https://apps.apple.com/")).toBe(false);
  });

  it("rejects injected placeholder tokens inside a plausible URL", () => {
    expect(isPublicAppStoreUrl("https://apps.apple.com/app/x/id00000000")).toBe(false);
  });
});

describe("isPublicTestFlightUrl", () => {
  it("accepts a real join link", () => {
    expect(isPublicTestFlightUrl("https://testflight.apple.com/join/abcdef123")).toBe(true);
  });

  it("rejects bare domains and other hosts", () => {
    expect(isPublicTestFlightUrl("https://testflight.apple.com/")).toBe(false);
    expect(isPublicTestFlightUrl("https://example.com/join/abc")).toBe(false);
    expect(isPublicTestFlightUrl(undefined)).toBe(false);
  });
});

describe("resolveDistribution", () => {
  it("falls back to the real web entry when no validated URL exists", () => {
    const d = resolveDistribution({});
    expect(d.primaryHref).toBe(WEB_APP_HREF);
    expect(d.primaryKind).toBe("web-app");
    expect(d.appStoreUrl).toBeNull();
    expect(d.iosAvailable).toBe(false);
    expect(d.availability).toBe("pending");
  });

  it("treats the placeholder store id as absent — never as availability", () => {
    const d = resolveDistribution({
      NEXT_PUBLIC_APP_STORE_URL: "https://apps.apple.com/app/solo-compass/id0000000000",
    });
    expect(d.appStoreUrl).toBeNull();
    expect(d.primaryKind).toBe("web-app");
    expect(d.availability).toBe("pending");
  });

  it("uses a validated App Store URL as the primary action", () => {
    const d = resolveDistribution({
      NEXT_PUBLIC_APP_STORE_URL: "https://apps.apple.com/app/solo-compass/id6478234512",
    });
    expect(d.primaryKind).toBe("app-store");
    expect(d.primaryHref).toContain("id6478234512");
    expect(d.iosAvailable).toBe(true);
    expect(d.availability).toBe("available");
  });

  it("prefers App Store over TestFlight and still surfaces TestFlight", () => {
    const d = resolveDistribution({
      NEXT_PUBLIC_APP_STORE_URL: "https://apps.apple.com/app/x/id6478234512",
      NEXT_PUBLIC_TESTFLIGHT_URL: "https://testflight.apple.com/join/abc12345",
    });
    expect(d.primaryKind).toBe("app-store");
    expect(d.testFlightUrl).toBe("https://testflight.apple.com/join/abc12345");
  });

  it("falls back to TestFlight when it is the only validated link", () => {
    const d = resolveDistribution({
      NEXT_PUBLIC_TESTFLIGHT_URL: "https://testflight.apple.com/join/abc12345",
    });
    expect(d.primaryKind).toBe("testflight");
    expect(d.primaryHref).toContain("testflight.apple.com");
    expect(d.iosAvailable).toBe(true);
  });

  it("never invents availability from a broken env value", () => {
    const d = resolveDistribution({ NEXT_PUBLIC_APP_STORE_URL: "https://apps.apple.com/app/x" });
    expect(d.iosAvailable).toBe(false);
  });
});

describe("distribution action labels match destinations", () => {
  it("labels beta links as TestFlight in both languages", () => {
    expect(distributionCopy("testflight", "en").action).toContain("TestFlight");
    expect(distributionCopy("testflight", "zh").status).toContain("TestFlight");
  });
  it("does not announce unavailable iOS links when a store listing is configured", () => {
    expect(distributionCopy("app-store", "en").status).not.toMatch(/not|no public/i);
    expect(distributionCopy("web-app", "en").status).toContain("not available here");
  });
});
