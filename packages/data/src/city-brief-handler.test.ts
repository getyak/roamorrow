import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from "vitest";

// Keep the production handler and the real SDK; only the external HTTP boundary
// and Deno registration/environment are controlled. No request can reach a network.
vi.mock("https://esm.sh/@supabase/supabase-js@2", async () => {
  const actual = await import("@supabase/supabase-js");
  return {
    createClient: (url: string, key: string, options: object) =>
      actual.createClient(url, key, {
        ...options,
        auth: { persistSession: false, autoRefreshToken: false },
      }),
  };
});

type Failure =
  | "event-write"
  | "event-zero"
  | "event-read"
  | "kit-write"
  | "kit-zero"
  | "kit-read"
  | "downgrade"
  | "ledger-write"
  | null;
interface State {
  failure: Failure;
  target: "events" | "kit";
  eventCount: number;
  eventWriteAttempts: number;
  kitWriteAttempts: number;
  downgradeAttempts: number;
  kitAction: "confirm" | "update" | "omit";
  storedEvents: string[];
  kitWrites: string[];
  receipts: Array<Record<string, unknown>>;
  providerCalls: number;
  noCandidates: boolean;
  databaseCalls: number;
  staleRows: boolean;
  downgraded: string[];
}
let state: State;
let handler: (request: Request) => Promise<Response>;
let validateBriefResponse: (value: unknown, city: string, target: string) => unknown;
interface HandlerBody {
  outcomes: Array<{ target: string; status: string; itemsWritten: number }>;
}
const source = "https://example.la/controlled-test";
const failureResponse = () =>
  Response.json({ code: "XX000", message: "Controlled database failure" }, { status: 500 });

async function boundary(input: string | URL | Request, init?: RequestInit): Promise<Response> {
  const url = new URL(
    typeof input === "string" ? input : input instanceof URL ? input.href : input.url,
  );
  const method = init?.method ?? "GET";
  const headers = new Headers(
    init?.headers ?? (input instanceof Request ? input.headers : undefined),
  );
  const wantsRows = headers.get("prefer")?.includes("return=representation") ?? false;
  const rowResponse = (rows: unknown, status = 200) =>
    wantsRows
      ? Response.json(rows, { status })
      : new Response(null, { status: status === 201 ? 201 : 204 });
  const body = init?.body ? (JSON.parse(String(init.body)) as Record<string, unknown>) : {};
  if (url.host === "api.tavily.com") {
    state.providerCalls++;
    if (state.noCandidates) return Response.json({ results: [] });
    return Response.json({
      results: [{ title: "Isolated source", url: source, content: "Controlled source text" }],
    });
  }
  if (url.host === "api.deepseek.com") {
    state.providerCalls++;
    const events = Array.from({ length: state.eventCount }, (_, i) => ({
      name: `Controlled event ${i}`,
      category: "market",
      when_label: "Tomorrow",
      starts_at: new Date(Date.now() + (i + 1) * 86400000).toISOString(),
      ends_at: new Date(Date.now() + (i + 2) * 86400000).toISOString(),
      solo_score: 5,
      solo_note: "Isolated test",
      source_url: source,
    }));
    const decisions = (state.staleRows ? ["net", "money"] : ["net"]).map((section) => ({
      section,
      action: state.kitAction,
      name: "Controlled update",
      body: "Isolated verified text",
      health: "green",
      sources: [{ type: "official", url: source }],
    }));
    return Response.json({
      choices: [
        {
          message: {
            content: JSON.stringify(state.target === "events" ? { events } : { decisions }),
          },
        },
      ],
      usage: { prompt_tokens: 1, completion_tokens: 1 },
    });
  }
  if (url.host !== "example.supabase.co") throw new Error("Unexpected network request blocked");
  state.databaseCalls++;
  const table = url.pathname.split("/").at(-1);
  if (table === "sc_cities")
    return Response.json([
      {
        city_code: "vte",
        name_en: "Vientiane",
        name_zh: "万象",
        timezone: "Asia/Vientiane",
        brief_enabled: true,
      },
    ]);
  if (table === "city_brief_runs" && method === "GET") return Response.json([]);
  if (table === "city_brief_runs" && method === "POST") {
    if (state.failure === "ledger-write") return failureResponse();
    const receipt = { ...body, id: `run-${state.receipts.length + 1}` };
    state.receipts.push(receipt);
    return rowResponse(receipt, 201);
  }
  if (table === "city_events" && method === "GET")
    return state.failure === "event-read" ? failureResponse() : Response.json([]);
  if (table === "city_events" && method === "POST") {
    state.eventWriteAttempts++;
    if (state.failure === "event-write" && state.storedEvents.length === state.eventCount - 1)
      return failureResponse();
    if (state.failure === "event-zero") return Response.json([]);
    state.storedEvents.push(String(body.id));
    return rowResponse([{ id: body.id }], 201);
  }
  if (table === "city_kits" && method === "GET")
    return state.failure === "kit-read"
      ? failureResponse()
      : Response.json(
          (state.staleRows ? ["net", "money"] : ["net"]).map((section) => ({
            section,
            name: "Controlled kit",
            body: "Test only",
            lens_line: null,
            last_verified_at: new Date(
              Date.now() - (state.staleRows ? 60 : 1) * 86400000,
            ).toISOString(),
          })),
        );

  if (table === "city_kits" && method === "PATCH") {
    if (url.searchParams.has("section")) {
      state.kitWriteAttempts++;
      if (state.failure === "kit-write") return failureResponse();
      if (state.failure === "kit-zero") return Response.json([]);
      state.kitWrites.push("net");
      return rowResponse([{ city_code: "vte", section: "net" }]);
    }
    state.downgradeAttempts++;
    if (state.failure === "downgrade") return failureResponse();
    const rows = state.staleRows
      ? ["net", "money"].filter((section) => !state.kitWrites.includes(section))
      : [];
    state.downgraded.push(...rows);
    return rowResponse(rows.map((section) => ({ city_code: "vte", section })));
  }
  throw new Error(`Unexpected controlled database operation: ${method}/${table}`);
}

beforeAll(async () => {
  const contractEntry = new URL(
    "../../../infra/supabase/functions/_shared/city-brief-contract.ts",
    import.meta.url,
  ).pathname;
  ({ validateBriefResponse } = await import(contractEntry));
  vi.stubGlobal("fetch", boundary);
  vi.stubGlobal("Deno", {
    env: {
      get: (key: string) =>
        (
          ({
            SUPABASE_URL: "https://example.supabase.co",
            SUPABASE_SERVICE_ROLE_KEY: "isolated-service",
            CITY_BRIEF_CRON_SECRET: "isolated-cron",
            TAVILY_API_KEY: "isolated-tavily",
            DEEPSEEK_API_KEY: "isolated-deepseek",
          }) as Record<string, string>
        )[key],
    },
    serve: (callback: typeof handler) => {
      handler = callback;
    },
  });
  const entry = new URL(
    "../../../infra/supabase/functions/compile-city-brief/index.ts",
    import.meta.url,
  ).pathname;
  await import(entry);
});
afterAll(() => vi.unstubAllGlobals());
beforeEach(() => {
  state = {
    failure: null,
    target: "events",
    eventCount: 1,
    eventWriteAttempts: 0,
    kitWriteAttempts: 0,
    downgradeAttempts: 0,
    kitAction: "confirm",
    storedEvents: [],
    kitWrites: [],
    receipts: [],
    providerCalls: 0,
    noCandidates: false,
    databaseCalls: 0,
    staleRows: false,
    downgraded: [],
  };
});
async function run(target: "events" | "kit") {
  state.target = target;
  const response = await handler(
    new Request("https://compiler.test", {
      method: "POST",
      headers: { "x-cron-secret": "isolated-cron", "content-type": "application/json" },
      body: JSON.stringify({ city_code: "vte", target, force: false }),
    }),
  );
  expect(response.status).toBe(200);
  const body: unknown = await response.json();
  if (!body || typeof body !== "object" || !("outcomes" in body) || !Array.isArray(body.outcomes)) {
    throw new Error("Controlled handler returned no structured outcomes");
  }
  return body as HandlerBody;
}

describe("real compiler handler persistence boundary", () => {
  it.each([undefined, "wrong"])(
    "rejects absent/wrong cron auth before any I/O: %s",
    async (secret) => {
      const response = await handler(
        new Request("https://compiler.test", {
          method: "POST",
          headers: {
            "content-type": "application/json",
            ...(secret ? { "x-cron-secret": secret } : {}),
          },
          body: JSON.stringify({ city_code: "vte", target: "events", force: false }),
        }),
      );
      expect(response.status).toBe(401);
      expect(state.databaseCalls).toBe(0);
      expect(state.providerCalls).toBe(0);
    },
  );
  it.each([
    { city_code: "unlisted", target: "events", force: false },
    { city_code: "vte", target: ["events"], force: false },
    { city_code: "vte", target: "events", force: "false" },
  ])("rejects invalid bounded input before any I/O: %j", async (body) => {
    const response = await handler(
      new Request("https://compiler.test", {
        method: "POST",
        headers: { "x-cron-secret": "isolated-cron", "content-type": "application/json" },
        body: JSON.stringify(body),
      }),
    );
    expect(response.status).toBe(400);
    expect(state.databaseCalls).toBe(0);
    expect(state.providerCalls).toBe(0);
  });
  it("rejects a non-POST method without database or provider work", async () => {
    expect((await handler(new Request("https://compiler.test"))).status).toBe(405);
    expect(state.databaseCalls).toBe(0);
    expect(state.providerCalls).toBe(0);
  });
  it("accepts actual event persistence and accounting through the real SDK", async () => {
    const body = await run("events");
    expect(state.storedEvents).toHaveLength(1);
    expect(validateBriefResponse(body, "vte", "events")).toEqual([
      { target: "events", kind: "refreshed", itemsWritten: 1 },
    ]);
    expect(state.receipts[0]?.items_written).toBe(1);
  });
  it.each(["confirm", "update"] as const)(
    "accepts actual kit %s persistence and accounting",
    async (action) => {
      state.kitAction = action;
      const body = await run("kit");
      expect(state.kitWrites).toHaveLength(1);
      expect(state.kitWriteAttempts).toBe(1);
      expect(validateBriefResponse(body, "vte", "kit")).toEqual([
        { target: "kit", kind: "refreshed", itemsWritten: 1 },
      ]);
    },
  );
  it("rejects event write errors rather than accepting ok/zero accounting", async () => {
    state.failure = "event-write";
    const body = await run("events");
    expect(state.storedEvents).toHaveLength(0);
    expect(() => validateBriefResponse(body, "vte", "events")).toThrow();
    expect(state.receipts[0]?.status).toBe("failed");
    expect(state.receipts[0]?.items_written).toBe(0);
  });
  it("preserves one actually written event when the second write fails", async () => {
    state.failure = "event-write";
    state.eventCount = 2;
    const body = await run("events");
    expect(state.storedEvents).toHaveLength(1);
    expect(state.eventWriteAttempts).toBe(2);
    expect(body.outcomes[0]).toMatchObject({ status: "partial", itemsWritten: 1 });
    expect(state.receipts[0]).toMatchObject({ status: "partial", items_written: 1 });
    expect(() => validateBriefResponse(body, "vte", "events")).toThrow();
  });
  it("rejects an event upsert that returns no persisted row", async () => {
    state.failure = "event-zero";
    const body = await run("events");
    expect(state.storedEvents).toHaveLength(0);
    expect(body.outcomes[0]).toMatchObject({ status: "failed", itemsWritten: 0 });
    expect(() => validateBriefResponse(body, "vte", "events")).toThrow();
  });
  it.each(["confirm", "update"] as const)("rejects kit %s write errors", async (action) => {
    state.failure = "kit-write";
    state.kitAction = action;
    const body = await run("kit");
    expect(state.kitWrites).toHaveLength(0);
    expect(state.kitWriteAttempts).toBe(1);
    expect(body.outcomes[0]).toMatchObject({ status: "failed", itemsWritten: 0 });
    expect(state.receipts[0]).toMatchObject({ status: "failed", items_written: 0 });
    expect(() => validateBriefResponse(body, "vte", "kit")).toThrow();
  });
  it.each(["confirm", "update"] as const)(
    "does not count zero-row kit %s updates as written",
    async (action) => {
      state.failure = "kit-zero";
      state.kitAction = action;
      const body = await run("kit");
      expect(state.kitWrites).toHaveLength(0);
      expect(state.kitWriteAttempts).toBe(1);
      expect(body.outcomes[0]).toMatchObject({ status: "failed", itemsWritten: 0 });
      expect(() => validateBriefResponse(body, "vte", "kit")).toThrow();
    },
  );
  it("stops event writes when the deduplication read fails", async () => {
    state.failure = "event-read";
    const body = await run("events");
    expect(state.storedEvents).toHaveLength(0);
    expect(state.receipts[0]).toMatchObject({
      status: "failed",
      items_written: 0,
      search_calls: 3,
      prompt_tokens: 1,
      output_tokens: 1,
    });
    expect(() => validateBriefResponse(body, "vte", "events")).toThrow();
  });
  it("does not classify a failed kit read as an empty successful kit", async () => {
    state.failure = "kit-read";
    const body = await run("kit");
    expect(state.providerCalls).toBe(0);
    expect(state.receipts[0]).toMatchObject({ status: "failed", items_written: 0 });
    expect(() => validateBriefResponse(body, "vte", "kit")).toThrow();
  });
  it("preserves successful kit writes but fails when stale downgrade fails", async () => {
    state.failure = "downgrade";
    const body = await run("kit");
    expect(state.kitWrites).toHaveLength(1);
    expect(state.downgradeAttempts).toBe(1);
    expect(body.outcomes[0]).toMatchObject({ status: "partial", itemsWritten: 1 });
    expect(state.receipts[0]).toMatchObject({ status: "partial", items_written: 1 });
    expect(() => validateBriefResponse(body, "vte", "kit")).toThrow();
  });
  it("preserves search accounting when no candidates and stale downgrade fails", async () => {
    state.noCandidates = true;
    state.failure = "downgrade";
    const body = await run("kit");
    expect(state.providerCalls).toBe(4);
    expect(state.kitWrites).toHaveLength(0);
    expect(state.receipts[0]).toMatchObject({
      status: "failed",
      search_calls: 4,
      prompt_tokens: 0,
      output_tokens: 0,
      items_written: 0,
    });
    expect(() => validateBriefResponse(body, "vte", "kit")).toThrow();
  });
  it("counts actual stale downgrades even when no fresh confirmation is made", async () => {
    state.staleRows = true;
    state.kitAction = "omit";
    const body = await run("kit");
    expect(state.downgraded).toHaveLength(2);
    expect(body.outcomes[0]).toMatchObject({ status: "ok", itemsWritten: 2 });
    expect(state.receipts[0]?.items_written).toBe(2);
  });
  it("returns non-success when the accounting insert fails", async () => {
    state.failure = "ledger-write";
    const response = await handler(
      new Request("https://compiler.test", {
        method: "POST",
        headers: { "x-cron-secret": "isolated-cron", "content-type": "application/json" },
        body: JSON.stringify({ city_code: "vte", target: "events", force: false }),
      }),
    );
    expect(response.status).toBe(503);
    expect(state.storedEvents).toHaveLength(1);
    expect(state.receipts).toHaveLength(0);
  });
});
