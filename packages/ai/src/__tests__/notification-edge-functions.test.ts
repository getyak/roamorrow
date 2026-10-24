import { webcrypto } from "node:crypto";
import { join } from "node:path";
import { beforeAll, describe, expect, it } from "vitest";
import { loadEdgeHandler } from "./helpers/edge-handler";

type Row = Record<string, unknown>;
interface FixtureOptions {
  userId?: string | null;
  authError?: boolean;
  rows?: Record<string, Row[]>;
  errors?: string[];
  noApns?: boolean;
  host?: string;
  statuses?: Record<string, number>;
  failDelete?: boolean;
  metadata?: Row;
}
let privatePem: string;
beforeAll(async () => {
  const pair = await webcrypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, [
    "sign",
    "verify",
  ]);
  const der = await webcrypto.subtle.exportKey("pkcs8", pair.privateKey);
  privatePem = `-----BEGIN PRIVATE KEY-----\n${Buffer.from(der).toString("base64")}\n-----END PRIVATE KEY-----`;
});

function fixture(name: string, options: FixtureOptions = {}) {
  const deleted: string[] = [];
  const fetched: Array<{ url: string; init: RequestInit }> = [];
  const signed: Array<{ header: Row; claims: Row; key: webcrypto.CryptoKey }> = [];
  const queries: string[] = [];
  const rows: Record<string, Row[]> = {
    friend_requests: [
      { id: "request", requester_id: "caller", recipient_id: "recipient", status: "pending" },
    ],
    chat_messages: [
      { id: "message", sender_id: "caller", conversation_id: "conversation", body: "hello" },
    ],
    conversations: [{ id: "conversation", participant_ids: ["caller", "recipient"] }],
    companion_profiles: [
      { user_id: "caller", avatar_emoji: "🦊" },
      { user_id: "recipient", avatar_emoji: "🦉" },
    ],
    friend_codes: [{ code: "SOLO-ABCD-1234", user_id: "recipient", revoked_at: null }],
    device_push_tokens: [
      { user_id: "recipient", token: "good" },
      { user_id: "caller", token: "sender-secret" },
      { user_id: "outsider", token: "outsider-secret" },
    ],
    ...options.rows,
  };
  function from(table: string) {
    queries.push(table);
    const predicates: Array<(row: Row) => boolean> = [];
    let deleting = false;
    const result = () => {
      const selected = (rows[table] ?? []).filter((row) => predicates.every((test) => test(row)));
      if (deleting) {
        deleted.push(...selected.map((row) => String(row.token)));
        if (options.failDelete) throw new Error("cleanup unavailable");
      }
      return {
        data: selected,
        error: options.errors?.includes(table) ? new Error("lookup") : null,
      };
    };
    const builder = {
      select() {
        return builder;
      },
      eq(column: string, value: unknown) {
        predicates.push((row) => row[column] === value);
        return builder;
      },
      in(column: string, values: unknown[]) {
        predicates.push((row) => values.includes(row[column]));
        return builder;
      },
      delete() {
        deleting = true;
        return builder;
      },
      async maybeSingle() {
        const value = result();
        return { ...value, data: value.data[0] ?? null };
      },
      then(
        resolve: (value: ReturnType<typeof result>) => unknown,
        reject?: (reason: unknown) => unknown,
      ) {
        return Promise.resolve().then(result).then(resolve, reject);
      },
    };
    return builder;
  }
  const handler = loadEdgeHandler(
    join(__dirname, "../../../../infra/supabase/functions", name, "index.ts"),
    {
      env: {
        SUPABASE_URL: "https://synthetic.invalid",
        SUPABASE_SERVICE_ROLE_KEY: "synthetic-service-key",
        ...(options.noApns
          ? {}
          : {
              APNS_KEY_P8: privatePem,
              APNS_KEY_ID: "key-id",
              APNS_TEAM_ID: "team-id",
              APNS_TOPIC: "test.topic",
            }),
        ...(options.host ? { APNS_HOST: options.host } : {}),
      },
      supabase: {
        from,
        auth: {
          getUser: async () => ({
            data: { user: options.userId === null ? null : { id: options.userId ?? "caller" } },
            error: options.authError ? new Error("auth") : null,
          }),
          admin: {
            getUserById: async () => ({
              data: { user: { user_metadata: options.metadata ?? { display_handle: "Traveler" } } },
            }),
          },
        },
      },
      moduleMocks: {
        "https://deno.land/x/djwt@v3.0.2/mod.ts": {
          create: async (header: Row, claims: Row, key: webcrypto.CryptoKey) => {
            signed.push({ header, claims, key });
            return "synthetic-provider-jwt";
          },
          getNumericDate: () => 123456,
        },
      },
      fetchImpl: async (input, init) => {
        const url = String(input);
        fetched.push({ url, init: init ?? {} });
        const token = url.split("/").at(-1) ?? "";
        const status = options.statuses?.[token] ?? 200;
        if (status === -1) throw new Error("network unavailable");
        return new Response(null, { status });
      },
    },
  );
  const invoke = (
    body: unknown,
    auth: string | null = "Bearer synthetic-user-jwt",
    method = "POST",
  ) =>
    handler(
      new Request("https://synthetic.invalid", {
        method,
        headers: auth === null ? {} : { Authorization: auth },
        ...(method === "POST"
          ? { body: typeof body === "string" ? body : JSON.stringify(body) }
          : {}),
      }),
    );
  return { invoke, deleted, fetched, signed, queries };
}

for (const [name, id] of [
  ["friend-request-notify", "requestId"],
  ["message-notify", "messageId"],
  ["redeem-friend-code", "code"],
] as const) {
  describe(`${name} authentication and protocol`, () => {
    it("rejects missing/invalid bearer before private lookups", async () => {
      const missing = fixture(name);
      expect((await missing.invoke({}, null)).status).toBe(401);
      expect(missing.queries).toEqual([]);
      for (const config of [{ userId: null }, { authError: true }]) {
        const invalid = fixture(name, config);
        expect((await invalid.invoke({})).status).toBe(401);
        expect(invalid.queries).toEqual([]);
      }
    });
    it("retains preflight, method and body validation", async () => {
      const subject = fixture(name);
      const preflight = await subject.invoke({}, null, "OPTIONS");
      expect(preflight.status).toBe(204);
      expect(preflight.headers.get("Access-Control-Allow-Headers")).toBe(
        "Authorization, Content-Type",
      );
      expect((await subject.invoke({}, null, "GET")).status).toBe(405);
      expect((await subject.invoke("{")).status).toBe(400);
      expect(await (await subject.invoke({})).json()).toEqual({ error: `${id} is required` });
    });
  });
}

describe("production notification delivery", () => {
  it.each(["friend-request-notify", "message-notify"])(
    "%s retains resource ownership checks",
    async (name) => {
      const subject = fixture(name, { userId: "attacker" });
      expect((await subject.invoke({ requestId: "request", messageId: "message" })).status).toBe(
        403,
      );
      expect(subject.fetched).toEqual([]);
      expect(subject.queries).not.toContain("device_push_tokens");
    },
  );
  it.each(["friend-request-notify", "message-notify"])(
    "%s needs no APNs secrets when no devices exist",
    async (name) => {
      const subject = fixture(name, { noApns: true, rows: { device_push_tokens: [] } });
      expect(
        await (await subject.invoke({ requestId: "request", messageId: "message" })).json(),
      ).toEqual({ delivered: 0, total: 0 });
      expect(subject.signed).toEqual([]);
    },
  );
  it("delivers only to recipient devices; deletes 410 tokens and tolerates per-device failures", async () => {
    const subject = fixture("friend-request-notify", {
      rows: {
        device_push_tokens: ["good", "expired", "failed", "network", ""]
          .map((token) => ({ user_id: "recipient", token }))
          .concat([{ user_id: "caller", token: "sender-secret" }]),
      },
      statuses: { expired: 410, failed: 500, network: -1 },
      failDelete: true,
    });
    expect(await (await subject.invoke({ requestId: " request " })).json()).toEqual({
      delivered: 1,
      total: 4,
    });
    expect(subject.deleted).toEqual(["expired"]);
    expect(subject.fetched.map((r) => r.url.split("/").at(-1)).sort()).toEqual([
      "expired",
      "failed",
      "good",
      "network",
    ]);
    const request = subject.fetched[0]!;
    expect(request.url).toContain("https://api.sandbox.push.apple.com/3/device/");
    expect(request.init.headers).toMatchObject({
      authorization: "bearer synthetic-provider-jwt",
      "apns-topic": "test.topic",
      "apns-push-type": "alert",
      "apns-priority": "10",
    });
    expect(JSON.parse(String(request.init.body))).toEqual({
      aps: { alert: { title: "Traveler", body: "sent you a friend request" }, sound: "default" },
      type: "friend_request",
      requesterHandle: "Traveler",
      requesterEmoji: "🦊",
      requestId: "request",
    });
    expect(subject.signed[0]).toMatchObject({
      header: { alg: "ES256", kid: "key-id", typ: "JWT" },
      claims: { iss: "team-id", iat: 123456 },
    });
    expect(subject.signed[0]?.key.type).toBe("private");
  });
  it("message excludes sender/outside tokens and preserves bounded preview and host", async () => {
    const subject = fixture("message-notify", {
      host: "api.push.apple.com",
      rows: {
        chat_messages: [
          {
            id: "message",
            sender_id: "caller",
            conversation_id: "conversation",
            body: "x".repeat(200),
          },
        ],
      },
    });
    expect(await (await subject.invoke({ messageId: "message" })).json()).toEqual({
      delivered: 1,
      total: 1,
    });
    expect(subject.fetched[0]?.url).toBe("https://api.push.apple.com/3/device/good");
    expect(JSON.parse(String(subject.fetched[0]?.init.body))).toMatchObject({
      type: "message",
      conversationId: "conversation",
      senderHandle: "Traveler",
      preview: `${"x".repeat(139)}…`,
    });
  });
  it("retains empty message fallback and self-only conversation short-circuit", async () => {
    const fallback = fixture("message-notify", {
      metadata: {},
      rows: {
        chat_messages: [
          { id: "message", sender_id: "caller", conversation_id: "conversation", body: null },
        ],
      },
    });
    expect((await fallback.invoke({ messageId: "message" })).status).toBe(200);
    expect(JSON.parse(String(fallback.fetched[0]?.init.body))).toMatchObject({
      aps: { alert: { title: "🦊", body: "sent you a message" } },
      preview: "",
    });
    const selfOnly = fixture("message-notify", {
      noApns: true,
      rows: { conversations: [{ id: "conversation", participant_ids: ["caller", null] }] },
    });
    expect(await (await selfOnly.invoke({ messageId: "message" })).json()).toEqual({
      delivered: 0,
      total: 0,
    });
    expect(selfOnly.queries).not.toContain("device_push_tokens");
  });
  it.each(["friend-request-notify", "message-notify"])(
    "%s reports APNs config failure without delivery",
    async (name) => {
      const subject = fixture(name, { noApns: true });
      expect((await subject.invoke({ requestId: "request", messageId: "message" })).status).toBe(
        500,
      );
      expect(subject.fetched).toEqual([]);
    },
  );
  it("keeps lookup failures separate from missing records", async () => {
    expect(
      (
        await fixture("friend-request-notify", { errors: ["friend_requests"] }).invoke({
          requestId: "request",
        })
      ).status,
    ).toBe(500);
    expect((await fixture("friend-request-notify").invoke({ requestId: "unknown" })).status).toBe(
      404,
    );
  });
});

describe("friend-code resolution", () => {
  it("returns the same 404 for unknown, revoked, and self-owned codes", async () => {
    for (const row of [
      null,
      { user_id: "recipient", revoked_at: "2026-01-01" },
      { user_id: "caller", revoked_at: null },
    ]) {
      const subject = fixture("redeem-friend-code", {
        rows: { friend_codes: row ? [{ code: "SOLO-ABCD-1234", ...row }] : [] },
      });
      const response = await subject.invoke({ code: "solo-abcd-1234" });
      expect(response.status).toBe(404);
      expect(await response.json()).toEqual({ error: "not found" });
    }
  });
  it("normalizes input and retains public profile fallback", async () => {
    const subject = fixture("redeem-friend-code", { metadata: { displayHandle: "Public handle" } });
    expect(await (await subject.invoke({ code: " solo-abcd-1234 " })).json()).toEqual({
      userId: "recipient",
      handle: "Public handle",
      avatarEmoji: "🦉",
    });
  });
});
