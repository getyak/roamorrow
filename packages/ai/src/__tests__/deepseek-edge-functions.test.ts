/**
 * Offline handler tests for the migrated DeepSeek Edge Functions.
 *
 * These tests load the REAL `infra/supabase/functions/{synthesize-experiences,
 * chat-proxy}/index.ts` sources, transpile them to CommonJS with the TypeScript
 * compiler API, and run them in a Node `vm` sandbox with mocked `Deno.serve`,
 * `Deno.env`, a fake Supabase client, and a mocked `fetch`. They assert the
 * actual wire request (URL, Bearer auth, model, thinking), the actual response
 * handling (schema guards, model-qualified cache, SSE passthrough) and the
 * preserved auth/quota gates. No Deno runtime, network, or duplicated handler
 * logic.
 */

import { readFileSync } from "node:fs";
import { join } from "node:path";
import * as vm from "node:vm";
import { webcrypto } from "node:crypto";
import * as ts from "typescript";
import { describe, it, expect } from "vitest";
import * as deepseekShared from "../../../../infra/supabase/functions/_shared/deepseek";

// ─── Handler loader ──────────────────────────────────────────────────────────

const REPO_ROOT = join(__dirname, "..", "..", "..", "..");
const SYNTH_PATH = join(REPO_ROOT, "infra/supabase/functions/synthesize-experiences/index.ts");
const CHAT_PATH = join(REPO_ROOT, "infra/supabase/functions/chat-proxy/index.ts");

interface EdgeHandlerOptions {
  env: Record<string, string>;
  supabase: unknown;
  fetchImpl: (input: string | URL, init?: RequestInit) => Promise<Response>;
}

/** Transpile + run one Edge Function, returning the captured Deno.serve handler. */
function loadEdgeHandler(
  absPath: string,
  options: EdgeHandlerOptions,
): (req: Request) => Promise<Response> {
  const source = readFileSync(absPath, "utf8");
  const { outputText } = ts.transpileModule(source, {
    compilerOptions: {
      module: ts.ModuleKind.CommonJS,
      target: ts.ScriptTarget.ES2022,
      esModuleInterop: true,
    },
    fileName: absPath,
  });

  let handler: ((req: Request) => Promise<Response>) | undefined;
  const sandbox: Record<string, unknown> = {
    module: { exports: {} },
    exports: {},
    require: (id: string): unknown => {
      if (id.includes("@supabase/supabase-js")) {
        return { createClient: () => options.supabase };
      }
      if (id.includes("_shared/deepseek")) {
        return deepseekShared;
      }
      throw new Error(`unexpected require: ${id}`);
    },
    Deno: {
      env: { get: (key: string) => options.env[key] },
      serve: (fn: (req: Request) => Promise<Response>) => {
        handler = fn;
      },
    },
    Request,
    Response,
    Headers,
    URL,
    URLSearchParams,
    TextEncoder,
    TextDecoder,
    crypto: webcrypto,
    console,
    fetch: options.fetchImpl,
  };
  vm.createContext(sandbox);
  vm.runInContext(outputText, sandbox, { filename: absPath });
  if (!handler) throw new Error("Deno.serve handler was not registered");
  return handler;
}

// ─── Fake Supabase ───────────────────────────────────────────────────────────

interface FakeSupabaseOptions {
  userId?: string | null;
  tier?: string;
  callCount?: number;
  cachedPayload?: unknown;
  cachedModelName?: string;
  cachedSynthesizedAt?: string;
}

interface FakeSupabase {
  admin: unknown;
  upserts: Array<{ table: string; row: Record<string, unknown> }>;
  inserts: Array<{ table: string; row: Record<string, unknown> }>;
  eqCalls: Array<{ table: string; column: string; value: unknown }>;
}

function makeFakeSupabase(options: FakeSupabaseOptions = {}): FakeSupabase {
  const upserts: FakeSupabase["upserts"] = [];
  const inserts: FakeSupabase["inserts"] = [];
  const eqCalls: FakeSupabase["eqCalls"] = [];

  function from(table: string): Record<string, unknown> {
    const filters: Array<[string, unknown]> = [];
    const builder: Record<string, unknown> = {};
    for (const method of ["select", "gte", "lt", "in", "order", "limit", "neq", "is"]) {
      builder[method] = () => builder;
    }
    builder["eq"] = (column: string, value: unknown) => {
      filters.push([column, value]);
      eqCalls.push({ table, column, value });
      return builder;
    };
    const resolve = () => {
      if (table === "profiles") {
        return { data: { entitlement_tier: options.tier ?? "pro" }, error: null, count: null };
      }
      if (table === "synthesized_experiences") {
        if (options.cachedPayload !== undefined) {
          const modelFilter = filters.find(([column]) => column === "model_name");
          // Only honour the cache when the query is model-qualified and the
          // cached model matches. An unqualified query returns the stale row
          // (which is exactly the bug the model filter prevents).
          if (!modelFilter || options.cachedModelName === modelFilter[1]) {
            return {
              data: {
                payload: options.cachedPayload,
                synthesized_at: options.cachedSynthesizedAt ?? new Date().toISOString(),
              },
              error: null,
              count: null,
            };
          }
        }
        return { data: null, error: null, count: null };
      }
      if (table === "sc_function_calls") {
        return { data: null, error: null, count: options.callCount ?? 0 };
      }
      return { data: null, error: null, count: null };
    };
    builder["maybeSingle"] = async () => resolve();
    builder["single"] = async () => resolve();
    builder["upsert"] = async (row: Record<string, unknown>) => {
      upserts.push({ table, row });
      return { error: null };
    };
    builder["insert"] = async (row: Record<string, unknown>) => {
      inserts.push({ table, row });
      return { error: null };
    };
    builder["then"] = (onFulfilled: (value: unknown) => unknown) =>
      Promise.resolve(resolve()).then(onFulfilled);
    return builder;
  }

  const admin = {
    auth: {
      getUser: async () =>
        options.userId === null
          ? { data: { user: null }, error: { message: "invalid jwt" } }
          : { data: { user: { id: options.userId ?? "user-1" } }, error: null },
    },
    from,
  };
  return { admin, upserts, inserts, eqCalls };
}

// ─── Fixtures ────────────────────────────────────────────────────────────────

const ENV = {
  SUPABASE_URL: "https://fake.supabase.co",
  SUPABASE_SERVICE_ROLE_KEY: "service-role",
  DEEPSEEK_API_KEY: "sk-test-deepseek",
};

const POI = { osmId: 1, name: "Cafe", nameEn: null, lat: 1, lon: 2, tags: { amenity: "cafe" } };
const SYNTH_BODY = { pois: [POI], cityCode: "vte", locale: "en", cacheKey: "ck-1" };
const ITEM = {
  osmId: 1,
  title: "Temple",
  oneLiner: "Quiet.",
  whyItMatters: "Peaceful.",
  category: "culture",
};

function chatResponse(content: string, status = 200): Response {
  return new Response(
    JSON.stringify({
      choices: [{ message: { content } }],
      usage: { prompt_tokens: 5, completion_tokens: 6 },
    }),
    { status, headers: { "content-type": "application/json" } },
  );
}

function postRequest(url: string, body: unknown, withAuth = true): Request {
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (withAuth) headers["Authorization"] = "Bearer test-jwt";
  return new Request(url, { method: "POST", headers, body: JSON.stringify(body) });
}

// ─── synthesize-experiences: success + wire ──────────────────────────────────

describe("synthesize-experiences handler", () => {
  it("regenerates malformed cached facts rather than returning them", async () => {
    const fake = makeFakeSupabase({
      cachedPayload: [{ ...ITEM, durationMinMinutes: -5 }],
      cachedModelName: "deepseek-flash",
    });
    let fetched = false;
    const handler = loadEdgeHandler(SYNTH_PATH, {
      env: ENV,
      supabase: fake.admin,
      fetchImpl: async () => {
        fetched = true;
        return chatResponse(JSON.stringify([ITEM]));
      },
    });
    const response = await handler(postRequest("https://p.functions.supabase.co/x", SYNTH_BODY));
    expect(response.status).toBe(200);
    expect(fetched).toBe(true);
    expect(await response.json()).toEqual({ experiences: [ITEM], cached: false });
    expect(fake.upserts).toHaveLength(1);
  });

  it("accepts unknown optional facts without inventing defaults", async () => {
    const unknown = {
      ...ITEM,
      bestStartHour: null,
      bestEndHour: null,
      durationMinMinutes: null,
      durationMaxMinutes: null,
      soloOverall: null,
      howTo: null,
      soloHint: null,
    };
    const fake = makeFakeSupabase();
    const handler = loadEdgeHandler(SYNTH_PATH, {
      env: ENV,
      supabase: fake.admin,
      fetchImpl: async () => chatResponse(JSON.stringify([unknown])),
    });
    const response = await handler(postRequest("https://p.functions.supabase.co/x", SYNTH_BODY));
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ experiences: [unknown], cached: false });
    expect(fake.upserts).toHaveLength(1);
  });

  it.each([
    ["negative duration", { durationMinMinutes: -5 }],
    ["reversed duration", { durationMinMinutes: 90, durationMaxMinutes: 10 }],
    ["invalid hour", { bestStartHour: 27, bestEndHour: 20 }],
    ["invalid score", { soloOverall: 25 }],
    ["non-text instructions", { howTo: [42] }],
    ["empty title", { title: "   " }],
  ])("rejects malformed model facts before cache write: %s", async (_label, overrides) => {
    const fake = makeFakeSupabase();
    const handler = loadEdgeHandler(SYNTH_PATH, {
      env: ENV,
      supabase: fake.admin,
      fetchImpl: async () => chatResponse(JSON.stringify([{ ...ITEM, ...overrides }])),
    });
    const response = await handler(postRequest("https://p.functions.supabase.co/x", SYNTH_BODY));
    expect(response.status).toBe(502);
    expect(fake.upserts).toHaveLength(0);
  });

  it.each([null, [], 42])("rejects non-object request body %s with 400", async (body) => {
    const fake = makeFakeSupabase();
    const handler = loadEdgeHandler(SYNTH_PATH, {
      env: ENV,
      supabase: fake.admin,
      fetchImpl: async () => {
        throw new Error("should not call model");
      },
    });
    const response = await handler(postRequest("https://p.functions.supabase.co/x", body));
    expect(response.status).toBe(400);
  });

  it("rejects a model response that silently omits a requested place", async () => {
    const fake = makeFakeSupabase();
    const handler = loadEdgeHandler(SYNTH_PATH, {
      env: ENV,
      supabase: fake.admin,
      fetchImpl: async () => chatResponse(JSON.stringify([ITEM])),
    });
    const response = await handler(
      postRequest("https://p.functions.supabase.co/x", {
        ...SYNTH_BODY,
        pois: [POI, { ...POI, osmId: 2, name: "Other cafe" }],
      }),
    );
    expect(response.status).toBe(502);
    expect(fake.upserts).toHaveLength(0);
  });

  it("preserves exact provider IDs across batches while the model uses safe aliases", async () => {
    const fake = makeFakeSupabase();
    const handler = loadEdgeHandler(SYNTH_PATH, {
      env: ENV,
      supabase: fake.admin,
      fetchImpl: async () => chatResponse(JSON.stringify([ITEM])),
    });
    for (const id of ["4611686018427387905", "4611686018427387906"]) {
      const response = await handler(
        postRequest("https://p.functions.supabase.co/x", {
          ...SYNTH_BODY,
          pois: [{ ...POI, osmId: id }],
        }),
      );
      expect(response.status).toBe(200);
      expect(await response.json()).toMatchObject({ experiences: [{ osmId: id }] });
    }
    expect(fake.upserts.map(({ row }) => row["id"])).toEqual([
      "exp_osm_4611686018427387905",
      "exp_osm_4611686018427387906",
    ]);
    expect(
      fake.upserts.map(({ row }) => (row["payload"] as { osmId: string }[])[0]?.osmId),
    ).toEqual(["4611686018427387905", "4611686018427387906"]);
  });

  it("does not serve stale cached facts even when the model and client key match", async () => {
    const fake = makeFakeSupabase({
      cachedPayload: [ITEM],
      cachedModelName: "deepseek-flash",
      cachedSynthesizedAt: "2020-01-01T00:00:00Z",
    });
    let fetched = false;
    const handler = loadEdgeHandler(SYNTH_PATH, {
      env: ENV,
      supabase: fake.admin,
      fetchImpl: async () => {
        fetched = true;
        return chatResponse(JSON.stringify([ITEM]));
      },
    });
    const response = await handler(postRequest("https://p.functions.supabase.co/x", SYNTH_BODY));
    expect(response.status).toBe(200);
    expect(fetched).toBe(true);
    expect(((await response.json()) as { cached: boolean }).cached).toBe(false);
    expect(fake.upserts[0]?.row["synthesized_at"]).toEqual(expect.any(String));
  });

  it("fingerprints input facts on the server rather than trusting a reused client key", async () => {
    const fake = makeFakeSupabase();
    const handler = loadEdgeHandler(SYNTH_PATH, {
      env: ENV,
      supabase: fake.admin,
      fetchImpl: async () => chatResponse(JSON.stringify([ITEM])),
    });
    await handler(postRequest("https://p.functions.supabase.co/x", SYNTH_BODY));
    await handler(
      postRequest("https://p.functions.supabase.co/x", {
        ...SYNTH_BODY,
        pois: [{ ...POI, tags: { ...POI.tags, opening_hours: "18:00-22:00" } }],
      }),
    );
    const keys = fake.upserts.map(({ row }) => row["source_cache_key"]);
    expect(keys).toHaveLength(2);
    expect(keys[0]).not.toBe(keys[1]);
  });

  it("calls DeepSeek with Bearer auth, Flash, thinking disabled, and caches by model", async () => {
    const fake = makeFakeSupabase();
    let captured: { url: string; init?: RequestInit } | undefined;
    const handler = loadEdgeHandler(SYNTH_PATH, {
      env: ENV,
      supabase: fake.admin,
      fetchImpl: async (url, init) => {
        captured = { url: String(url), init };
        return chatResponse(JSON.stringify([ITEM]));
      },
    });

    const res = await handler(postRequest("https://p.functions.supabase.co/x", SYNTH_BODY));

    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ experiences: [ITEM], cached: false });

    expect(captured?.url).toBe("https://api.deepseek.com/v1/chat/completions");
    const headers = new Headers(captured?.init?.headers);
    expect(headers.get("Authorization")).toBe("Bearer sk-test-deepseek");

    const sent = JSON.parse(String(captured?.init?.body)) as Record<string, unknown>;
    expect(sent["model"]).toBe("deepseek-flash");
    expect(sent["thinking"]).toEqual({ type: "disabled" });
    expect(sent["extra_body"]).toBeUndefined();
    expect(Array.isArray(sent["messages"])).toBe(true);

    expect(fake.upserts).toHaveLength(1);
    expect(fake.upserts[0]?.row).toMatchObject({
      model_name: "deepseek-flash",
      source_cache_key: expect.stringMatching(/^facts-v2:[a-f0-9]{64}$/),
    });
    expect(fake.inserts.some((row) => row.table === "sc_function_calls")).toBe(true);
  });

  it("qualifies the cache lookup by source_cache_key AND model_name", async () => {
    const fake = makeFakeSupabase({ cachedPayload: [ITEM], cachedModelName: "deepseek-flash" });
    let fetched = false;
    const handler = loadEdgeHandler(SYNTH_PATH, {
      env: ENV,
      supabase: fake.admin,
      fetchImpl: async () => {
        fetched = true;
        return chatResponse(JSON.stringify([ITEM]));
      },
    });

    const res = await handler(postRequest("https://p.functions.supabase.co/x", SYNTH_BODY));

    expect(fetched).toBe(false);
    expect(await res.json()).toEqual({ experiences: [ITEM], cached: true });
    const synthFilters = fake.eqCalls.filter((c) => c.table === "synthesized_experiences");
    expect(synthFilters).toContainEqual({
      table: "synthesized_experiences",
      column: "source_cache_key",
      value: expect.stringMatching(/^facts-v2:[a-f0-9]{64}$/),
    });
    expect(synthFilters).toContainEqual({
      table: "synthesized_experiences",
      column: "model_name",
      value: "deepseek-flash",
    });
  });

  it("does not serve an old model's cached payload for a Flash request", async () => {
    const fake = makeFakeSupabase({
      cachedPayload: [{ osmId: 99, title: "Claude era" }],
      cachedModelName: "claude-sonnet-4-6",
    });
    let fetched = false;
    const handler = loadEdgeHandler(SYNTH_PATH, {
      env: ENV,
      supabase: fake.admin,
      fetchImpl: async () => {
        fetched = true;
        return chatResponse(JSON.stringify([ITEM]));
      },
    });

    const res = await handler(postRequest("https://p.functions.supabase.co/x", SYNTH_BODY));

    const payload = (await res.json()) as { cached: boolean };
    expect(fetched).toBe(true);
    expect(payload.cached).toBe(false);
  });

  it("returns a controlled 502 for an empty upstream array and does not cache", async () => {
    const fake = makeFakeSupabase();
    const handler = loadEdgeHandler(SYNTH_PATH, {
      env: ENV,
      supabase: fake.admin,
      fetchImpl: async () => chatResponse("[]"),
    });

    const res = await handler(postRequest("https://p.functions.supabase.co/x", SYNTH_BODY));

    expect(res.status).toBe(502);
    expect(fake.upserts).toHaveLength(0);
  });

  it.each([
    ["null item", "[null]"],
    ["numeric item", "[1,2]"],
    ["array item", "[[]]"],
    ["missing fields", `[{"osmId":1,"title":"T"}]`],
    ["no JSON array", "I could not help with that."],
  ])("returns a controlled 502 for %s and does not cache", async (_label, content) => {
    const fake = makeFakeSupabase();
    const handler = loadEdgeHandler(SYNTH_PATH, {
      env: ENV,
      supabase: fake.admin,
      fetchImpl: async () => chatResponse(content),
    });

    const res = await handler(postRequest("https://p.functions.supabase.co/x", SYNTH_BODY));

    expect(res.status).toBe(502);
    expect(fake.upserts).toHaveLength(0);
  });

  it("returns 502 on upstream DeepSeek error", async () => {
    const fake = makeFakeSupabase();
    const handler = loadEdgeHandler(SYNTH_PATH, {
      env: ENV,
      supabase: fake.admin,
      fetchImpl: async () => new Response("boom", { status: 500 }),
    });

    const res = await handler(postRequest("https://p.functions.supabase.co/x", SYNTH_BODY));

    expect(res.status).toBe(502);
    expect(fake.upserts).toHaveLength(0);
  });

  it("preserves auth (401), entitlement (402) and quota (429) gates", async () => {
    const noAuth = loadEdgeHandler(SYNTH_PATH, {
      env: ENV,
      supabase: makeFakeSupabase().admin,
      fetchImpl: async () => chatResponse(JSON.stringify([ITEM])),
    });
    expect(
      (await noAuth(postRequest("https://p.functions.supabase.co/x", SYNTH_BODY, false))).status,
    ).toBe(401);

    const free = loadEdgeHandler(SYNTH_PATH, {
      env: ENV,
      supabase: makeFakeSupabase({ tier: "free" }).admin,
      fetchImpl: async () => chatResponse(JSON.stringify([ITEM])),
    });
    expect((await free(postRequest("https://p.functions.supabase.co/x", SYNTH_BODY))).status).toBe(
      402,
    );

    const quota = loadEdgeHandler(SYNTH_PATH, {
      env: ENV,
      supabase: makeFakeSupabase({ callCount: 30 }).admin,
      fetchImpl: async () => chatResponse(JSON.stringify([ITEM])),
    });
    expect((await quota(postRequest("https://p.functions.supabase.co/x", SYNTH_BODY))).status).toBe(
      429,
    );
  });
});

// ─── chat-proxy: server-owned model + streaming passthrough ──────────────────

describe("chat-proxy handler", () => {
  it("forces Flash + thinking disabled even when the client asks for Claude/enabled", async () => {
    const fake = makeFakeSupabase();
    let captured: { url: string; init?: RequestInit } | undefined;
    const handler = loadEdgeHandler(CHAT_PATH, {
      env: ENV,
      supabase: fake.admin,
      fetchImpl: async (url, init) => {
        captured = { url: String(url), init };
        return chatResponse("ok");
      },
    });

    const res = await handler(
      postRequest("https://p.functions.supabase.co/chat-proxy", {
        model: "claude-sonnet-4-6",
        thinking: { type: "enabled" },
        messages: [{ role: "user", content: "hi" }],
        kind: "voice",
      }),
    );

    expect(res.status).toBe(200);
    expect(await res.json()).toMatchObject({ choices: [{ message: { content: "ok" } }] });
    expect(captured?.url).toBe("https://api.deepseek.com/v1/chat/completions");
    const sent = JSON.parse(String(captured?.init?.body)) as Record<string, unknown>;
    expect(sent["model"]).toBe("deepseek-flash");
    expect(sent["thinking"]).toEqual({ type: "disabled" });
    expect(sent["kind"]).toBeUndefined();
  });

  it("passes an SSE stream through unchanged while forcing Flash/thinking", async () => {
    const sse = 'data: {"choices":[{"delta":{"content":"hi"}}]}\n\ndata: [DONE]\n\n';
    const fake = makeFakeSupabase();
    let captured: { init?: RequestInit } | undefined;
    const handler = loadEdgeHandler(CHAT_PATH, {
      env: ENV,
      supabase: fake.admin,
      fetchImpl: async (_url, init) => {
        captured = { init };
        return new Response(sse, {
          status: 200,
          headers: { "content-type": "text/event-stream" },
        });
      },
    });

    const res = await handler(
      postRequest("https://p.functions.supabase.co/chat-proxy", {
        messages: [{ role: "user", content: "hi" }],
        stream: true,
        kind: "voice",
      }),
    );

    expect(res.status).toBe(200);
    expect(res.headers.get("content-type")).toBe("text/event-stream");
    expect(await res.text()).toBe(sse);
    const headers = new Headers(captured?.init?.headers);
    expect(headers.get("Accept")).toBe("text/event-stream");
    const sent = JSON.parse(String(captured?.init?.body)) as Record<string, unknown>;
    expect(sent["model"]).toBe("deepseek-flash");
    expect(sent["thinking"]).toEqual({ type: "disabled" });
  });

  it("preserves the 401 auth gate", async () => {
    const handler = loadEdgeHandler(CHAT_PATH, {
      env: ENV,
      supabase: makeFakeSupabase().admin,
      fetchImpl: async () => chatResponse("ok"),
    });
    const res = await handler(
      postRequest(
        "https://p.functions.supabase.co/chat-proxy",
        { messages: [{ role: "user", content: "hi" }] },
        false,
      ),
    );
    expect(res.status).toBe(401);
  });
});
