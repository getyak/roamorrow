import { beforeEach, describe, expect, it, vi } from "vitest";

const m = vi.hoisted(() => ({
  auth: vi.fn(),
  env: vi.fn(),
  nearby: vi.fn(),
  byId: vi.fn(),
  snapshots: vi.fn(),
  plan: vi.fn(),
  matrix: vi.fn(),
  record: vi.fn(),
  completion: vi.fn(),
  cached: vi.fn(),
  quota: vi.fn(),
  cachePut: vi.fn(),
  anon: vi.fn(),
  refresh: vi.fn(),
  client: vi.fn(),
  upsert: vi.fn(),
}));
vi.mock("@/lib/repos", () => ({
  authenticatedUserId: m.auth,
  getExperiencesRepo: () => ({ findNearby: m.nearby, findById: m.byId }),
  getEvidenceRepo: () => ({ getSnapshotsForExperiences: m.snapshots }),
  getRouteCompilationRepo: () => ({ findFresh: m.cached, consumeQuota: m.quota, put: m.cachePut }),
  getWorkSessionRepo: () => ({ record: m.record }),
  getCompletionsRepo: () => ({ record: m.completion }),
}));
vi.mock("@/lib/env", () => ({ getServerEnv: m.env }));
vi.mock("@/lib/anon-cookie", () => ({
  readOrMintAnonId: m.anon,
  anonCookieOptions: { name: "anon", path: "/" },
}));
vi.mock("@solo-compass/routing", () => ({
  planWorkdayRoute: m.plan,
  ValhallaMatrixClient: class {
    buildMatrix = m.matrix;
  },
}));
vi.mock("@/lib/route-candidates", () => ({
  compileRouteCandidates: () => [],
  withDefaultTaskCandidatePools: (tasks: unknown) => tasks,
}));
vi.mock("@/lib/evidence-refresh", () => ({ coverageRefreshJob: () => ({}) }));
vi.mock("@/lib/refresh-scheduler", () => ({ scheduleRefreshJobs: m.refresh }));
vi.mock("@supabase/supabase-js", () => ({ createClient: m.client }));

import { POST as compile } from "../app/api/routes/compile/route";
import { POST as workSession } from "../app/api/work-sessions/route";
import { POST as checkin } from "../app/api/experiences/[id]/checkin/route";
import { POST as traffic } from "../app/api/traffic/route";

const request = (body: unknown) =>
  new Request("https://synthetic.invalid/api", {
    method: "POST",
    headers: { "content-type": "application/json", "content-length": "1" },
    body: JSON.stringify(body),
  });
function routeInput() {
  return {
    origin: [-9.14, 38.71],
    localDate: "2026-10-24",
    intent: {
      startMinute: 540,
      endMinute: 1020,
      tasks: [
        {
          id: " task-one ",
          kind: "deep_work",
          durationMinutes: 60,
          constraints: [
            {
              featureKey: " custom.feature ",
              operator: "eq",
              expected: { nested: ["yes", 1, true, null, { inner: "value" }] },
            },
          ],
        },
      ],
    },
  };
}
const session = {
  idempotencyKey: "session-unique",
  experienceId: "exp_fixture",
  plannedTaskKind: "deep_work",
  startedAt: "2026-10-24T09:00:00+08:00",
  endedAt: "2026-10-24T10:00:00+08:00",
  outcome: "completed",
};

beforeEach(() => {
  vi.resetAllMocks();
  m.env.mockReturnValue({
    VALHALLA_URL: "https://synthetic.invalid",
    SUPABASE_URL: "https://synthetic.invalid",
    SUPABASE_SERVICE_ROLE_KEY: "synthetic-service-key",
  });
  m.auth.mockResolvedValue("caller");
  const exp = {
    id: "exp_fixture",
    title: "Fixture",
    category: "food_drink",
    location: { coordinates: [-9.14, 38.71] },
  };
  m.nearby.mockResolvedValue([exp]);
  m.byId.mockResolvedValue(exp);
  m.snapshots.mockResolvedValue(
    new Map([["exp_fixture", { placeId: "place_fixture", features: [] }]]),
  );
  m.cached.mockResolvedValue(null);
  m.quota.mockResolvedValue(true);
  m.cachePut.mockResolvedValue(undefined);
  m.matrix.mockResolvedValue({});
  m.plan.mockReturnValue({ status: "solved", solution: {} });
  m.record.mockResolvedValue({ session: { id: "session_fixture" }, materializedFeatureKeys: [] });
  m.anon.mockResolvedValue({ id: "anonymous_fixture", minted: false });
  m.client.mockReturnValue({
    from: () => ({
      upsert: m.upsert,
      select: () => ({ eq: () => ({ maybeSingle: async () => ({ data: null }) }) }),
    }),
  });
  m.upsert.mockResolvedValue({ error: null });
});

describe("route compilation request contract", () => {
  it("preserves coordinates, defaults, trimming and recursive JSON constraints", async () => {
    const response = await compile(request(routeInput()));
    expect(response.status).toBe(200);
    expect(m.nearby).toHaveBeenCalledWith({
      center: [-9.14, 38.71],
      radiusMeters: 3000,
      limit: 30,
    });
    expect(m.matrix.mock.calls[0]?.[1]).toBe("pedestrian");
    expect(m.plan.mock.calls[0]?.[0].tasks[0]).toMatchObject({
      id: "task-one",
      constraints: [
        {
          featureKey: "custom.feature",
          minimumConfidence: 0.6,
          expected: { nested: ["yes", 1, true, null, { inner: "value" }] },
        },
      ],
    });
    expect(await response.json()).toMatchObject({ cache: "miss", result: { status: "solved" } });
  });
  it.each([0, 7])("rejects %i tasks before downstream work", async (length) => {
    const body = routeInput();
    body.intent.tasks = Array.from({ length }, () => body.intent.tasks[0]!);
    const response = await compile(request(body));
    expect(response.status).toBe(400);
    expect(m.auth).not.toHaveBeenCalled();
    expect(m.nearby).not.toHaveBeenCalled();
    expect(await response.json()).toEqual({ error: expect.any(String) });
  });
  it("rejects oversized collections without expanding thousands of validation errors", async () => {
    const body = routeInput();
    const response = await compile(
      request({ ...body, intent: { ...body.intent, tasks: Array(2048).fill(null) } }),
    );
    expect(response.status).toBe(400);
    const json = await response.json();
    expect(json.error.length).toBeLessThan(256);
    expect(m.auth).not.toHaveBeenCalled();
    expect(m.nearby).not.toHaveBeenCalled();
  });
  it("retains the authenticated-user boundary", async () => {
    m.auth.mockResolvedValue(null);
    expect((await compile(request(routeInput()))).status).toBe(401);
    expect(m.nearby).not.toHaveBeenCalled();
  });
  it.each([{ origin: [-181, 0] }, { origin: [0, 91] }])(
    "rejects invalid GeoJSON coordinate %j",
    async ({ origin }) => {
      expect((await compile(request({ ...routeInput(), origin }))).status).toBe(400);
      expect(m.nearby).not.toHaveBeenCalled();
    },
  );
});

describe("work-session validation", () => {
  it("preserves offset datetimes, explicit false values and trimmed identifiers", async () => {
    expect(
      (
        await workSession(
          request({
            ...session,
            experienceId: " exp_fixture ",
            powerAvailable: false,
            minimumSpend: { amount: 0, currency: "EUR" },
          }),
        )
      ).status,
    ).toBe(201);
    expect(m.record).toHaveBeenCalledWith(
      expect.objectContaining({
        experienceId: "exp_fixture",
        startedAt: session.startedAt,
        powerAvailable: false,
        minimumSpend: { amount: 0, currency: "EUR" },
      }),
    );
  });
  it.each([
    { unexpected: true },
    { startedAt: "yesterday" },
    { wifiReliability: 6 },
    { minimumSpend: { amount: -1, currency: "EUR" } },
  ])("rejects invalid input before recording: %j", async (invalid) => {
    expect((await workSession(request({ ...session, ...invalid }))).status).toBe(400);
    expect(m.record).not.toHaveBeenCalled();
  });
  it("checks authentication before parsing input", async () => {
    m.auth.mockResolvedValue(null);
    expect((await workSession(request(null))).status).toBe(401);
  });
});

describe("anonymous check-in validation", () => {
  const context = () => ({ params: Promise.resolve({ id: "exp_fixture" }) });
  it.each([{}, { rating: 1 }, { rating: 5 }])("keeps valid optional rating: %j", async (body) => {
    expect((await checkin(request(body), context())).status).toBe(200);
    expect(m.completion).toHaveBeenCalledWith({
      anonUserId: "anonymous_fixture",
      experienceId: "exp_fixture",
      rating: "rating" in body ? body.rating : undefined,
    });
  });
  it.each([{ rating: 0 }, { rating: 6 }, { rating: 1.5 }, { rating: "3" }, { unknown: true }])(
    "rejects invalid rating/unknown keys: %j",
    async (body) => {
      expect((await checkin(request(body), context())).status).toBe(400);
      expect(m.anon).not.toHaveBeenCalled();
      expect(m.completion).not.toHaveBeenCalled();
    },
  );
});

describe("traffic input compatibility", () => {
  it("keeps malformed input fail-open without a database client", async () => {
    expect(
      await (await traffic(request({ experienceId: "exp_fixture", lng: "bad", lat: 38 }))).json(),
    ).toEqual({ ok: true });
    expect(m.client).not.toHaveBeenCalled();
  });
  it("keeps valid coordinate pings scoped and hashed", async () => {
    expect(
      await (
        await traffic(request({ experienceId: "exp_fixture", lng: -9.14, lat: 38.71 }))
      ).json(),
    ).toEqual({ ok: true });
    expect(m.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        experience_id: "exp_fixture",
        anon_id: expect.stringMatching(/^[a-f0-9]{64}$/),
      }),
      { onConflict: "experience_id,anon_id" },
    );
  });
});
