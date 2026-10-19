import { describe, expect, it } from "vitest";
import config from "../../next.config";
import { getPathMatch } from "next/dist/shared/lib/router/utils/path-match";
import { prepareDestination } from "next/dist/shared/lib/router/utils/prepare-destination";
import robots from "../app/robots";
import sitemap from "../app/sitemap";

describe("independent Nomads service", () => {
  it("forwards only the Nomads namespace and leaves trailing slash decisions to its worker", async () => {
    const rewrites = await config.rewrites?.();
    const beforeFiles = Array.isArray(rewrites) ? rewrites : rewrites?.beforeFiles;
    expect(beforeFiles).toContainEqual({
      source: "/nomads/:path*",
      destination: "https://nomads.cubxxw.com/nomads/:path*",
    });
    expect(config.skipTrailingSlashRedirect).toBe(true);
  });

  it("retains directory slashes and query parameters in Next's actual rewrite compiler", async () => {
    const rewrites = await config.rewrites?.();
    const rules = Array.isArray(rewrites) ? rewrites : (rewrites?.beforeFiles ?? []);
    for (const pathname of [
      "/nomads",
      "/nomads/compare/",
      "/nomads/cities/chiang-mai/",
      "/nomads/app.js",
      "/nomads/api/agent/status",
    ]) {
      const rule = rules.find((candidate) => getPathMatch(candidate.source)(pathname));
      expect(rule).toBeDefined();
      const params = getPathMatch(rule!.source)(pathname);
      const { parsedDestination } = prepareDestination({
        destination: rule!.destination,
        params: params || {},
        query: { month: "11" },
        appendParamsToQuery: true,
      });
      expect(parsedDestination.pathname).toBe(pathname);
      expect(parsedDestination.query.month).toBe("11");
    }
  });

  it("advertises both sitemaps while keeping mounted APIs out of crawl paths", () => {
    const result = robots();
    expect(result.sitemap).toContain("https://roamorrow.com/nomads/sitemap.xml");
    const rules = Array.isArray(result.rules) ? result.rules : [result.rules];
    expect(rules[0]?.disallow).toContain("/nomads/api/");
    expect(sitemap().filter((row) => row.url === "https://roamorrow.com/nomads")).toHaveLength(1);
    expect(
      sitemap().find((row) => row.url === "https://roamorrow.com/nomads")?.alternates,
    ).toBeUndefined();
  });
});
