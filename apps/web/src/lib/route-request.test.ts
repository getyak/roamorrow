import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({ getServerEnv: vi.fn() }));
vi.mock("@/lib/env", () => ({ getServerEnv: mocks.getServerEnv }));
vi.mock("@/lib/repos", () => ({
  authenticatedUserId: vi.fn(),
  getEvidenceRepo: vi.fn(),
  getExperiencesRepo: vi.fn(),
  getRouteCompilationRepo: vi.fn(),
}));
vi.mock("@/lib/evidence-refresh", () => ({ coverageRefreshJob: vi.fn() }));
vi.mock("@/lib/refresh-scheduler", () => ({ scheduleRefreshJobs: vi.fn() }));

import { POST } from "../app/api/routes/compile/route";

function request(operator = "eq") {
  return new Request("https://example.test/api/routes/compile", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      origin: [98.98, 18.78],
      localDate: "2026-10-24",
      intent: {
        startMinute: 540,
        endMinute: 600,
        tasks: [
          {
            id: "work",
            kind: "deep_work",
            durationMinutes: 30,
            constraints: [
              {
                featureKey: "network.details",
                operator,
                expected: { channels: [1, true, null, { label: "public" }] },
              },
            ],
          },
        ],
      },
    }),
  });
}

describe("route request schema after the Zod security update", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.getServerEnv.mockImplementation(() => {
      throw new Error("test backend is not configured");
    });
  });

  it("accepts nested JSON records and reaches the backend configuration boundary", async () => {
    const response = await POST(request());
    expect(response.status).toBe(503);
    expect(await response.json()).toEqual({ error: "route backend is not configured" });
    expect(mocks.getServerEnv).toHaveBeenCalledOnce();
  });

  it("rejects invalid constraint operators before accessing backend configuration", async () => {
    const response = await POST(request("invalid"));
    expect(response.status).toBe(400);
    expect(await response.json()).toMatchObject({ error: expect.stringContaining("operator") });
    expect(mocks.getServerEnv).not.toHaveBeenCalled();
  });
});
