import { describe, expect, it } from "vitest";
import config from "../../next.config";
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
