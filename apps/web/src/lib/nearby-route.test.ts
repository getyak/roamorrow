import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  findNearby: vi.fn(),
  rank: vi.fn(),
  refresh: vi.fn(),
}));
vi.mock("@/lib/repos", () => ({
  getExperiencesRepo: () => ({ findNearby: mocks.findNearby }),
  getEvidenceRepo: () => ({}),
}));
vi.mock("@solo-compass/ai", () => ({ rankExperiences: mocks.rank }));
vi.mock("@/lib/evidence-refresh", () => ({
  coverageRefreshJob: () => ({}),
  planEvidenceRefresh: () => ({ coverage: "legacy", jobs: [] }),
}));
vi.mock("@/lib/refresh-scheduler", () => ({ scheduleRefreshJobs: mocks.refresh }));

import { GET } from "../app/api/experiences/nearby/route";

describe("nearby accuracy boundary", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.findNearby.mockResolvedValue([]);
    mocks.rank.mockResolvedValue({ ranked: [] });
  });
  afterEach(() => vi.unstubAllEnvs());

  it.each(["", "?lng=&lat=", "?lng=113.75", "?lat=31.78"])(
    "rejects missing coordinates rather than searching at zero: %s",
    async (query) => {
      const response = await GET(
        new Request(`https://example.test/api/experiences/nearby${query}`),
      );
      expect(response.status).toBe(400);
      expect(mocks.findNearby).not.toHaveBeenCalled();
    },
  );

  it("does not return demonstration restaurants when production configuration is absent", async () => {
    vi.stubEnv("NODE_ENV", "production");
    mocks.findNearby.mockRejectedValue(new Error("Invalid server environment configuration"));
    const response = await GET(
      new Request("https://example.test/api/experiences/nearby?lng=113.75&lat=31.78"),
    );
    expect(response.status).toBe(502);
    expect(await response.json()).not.toHaveProperty("results");
  });

  it("keeps development fixtures inside the requested radius", async () => {
    vi.stubEnv("NODE_ENV", "development");
    mocks.findNearby.mockRejectedValue(new Error("Invalid server environment configuration"));
    const response = await GET(
      new Request("https://example.test/api/experiences/nearby?lng=113.75&lat=31.78&radius=1000"),
    );
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({ results: [], degraded: true });
  });
});
