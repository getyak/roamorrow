import assert from "node:assert/strict";
import { createServer } from "node:http";
import { once } from "node:events";

const [mode, policyUrl, sdkUrl, openaiUrl] = process.argv.slice(2);
assert.ok(["control", "private"].includes(mode));
const sdkModule = await import(sdkUrl);
const Sentry = sdkModule.default?.init ? sdkModule.default : sdkModule;
const policy = await import(policyUrl);
const envelopes = [];
const canaries = {
  body: "privacy-test-request-body-canary",
  cookie: "privacy-test-cookie-canary",
  header: "privacy-test-header-canary",
  query: "privacy-test-query-canary",
  email: "privacy-test-email-canary@example.invalid",
  prompt: "privacy-test-model-input-canary",
  answer: "privacy-test-model-output-canary",
};
const server = createServer((request, response) => {
  request.resume();
  request.on("end", () => {
    response.writeHead(200, { "content-type": "application/json" });
    response.end(
      JSON.stringify({
        id: "chatcmpl-synthetic",
        object: "chat.completion",
        created: 0,
        model: "synthetic-local-test",
        choices: [
          {
            index: 0,
            message: { role: "assistant", content: canaries.answer },
            finish_reason: "stop",
          },
        ],
        usage: { prompt_tokens: 1, completion_tokens: 1, total_tokens: 2 },
      }),
    );
  });
});
server.listen(0, "127.0.0.1");
await once(server, "listening");
const address = server.address();
assert.ok(address && typeof address !== "string");
try {
  Sentry.init({
    dsn: "https://public@example.invalid/1",
    tracesSampleRate: 1,
    sendClientReports: false,
    ...(mode === "private"
      ? {
          dataCollection: policy.privateSentryDataCollection,
          beforeSend: policy.scrubSentryEvent ?? policy.scrubPII,
          beforeSendSpan: policy.scrubSentrySpan,
        }
      : {}),
    transport: () => ({
      send: async (envelope) => {
        envelopes.push(envelope);
        return { statusCode: 200 };
      },
      flush: async () => true,
    }),
  });
  const OpenAI = (await import(openaiUrl)).default;
  const client = new OpenAI({
    apiKey: "synthetic-not-a-credential",
    baseURL: "http://127.0.0.1:" + address.port + "/v1",
    maxRetries: 0,
  });
  await Sentry.withIsolationScope(async (scope) => {
    scope.setUser({ email: canaries.email, ip_address: "192.0.2.1" });
    scope.setSDKProcessingMetadata({
      normalizedRequest: {
        method: "POST",
        url: "http://127.0.0.1/synthetic?private=" + canaries.query,
        headers: { cookie: "synthetic=" + canaries.cookie, "x-synthetic": canaries.header },
        data: canaries.body,
      },
    });
    Sentry.captureException(new Error("Safe synthetic diagnostic"));
    await Sentry.startSpan({ name: "safe-synthetic-operation", op: "test.operation" }, async () => {
      const response = await client.chat.completions.create({
        model: "synthetic-local-test",
        messages: [{ role: "user", content: canaries.prompt }],
      });
      assert.equal(response.choices[0].message.content, canaries.answer);
    });
  });
  assert.equal(await Sentry.flush(5000), true);
  const serialized = JSON.stringify(envelopes);
  const items = envelopes.flatMap((envelope) => envelope[1]);
  const errorCount = items.filter((item) => item[0].type === "event").length;
  const spanItems = items.filter((item) => ["span", "transaction"].includes(item[0].type));
  const spanCount = spanItems.length;
  assert.ok(errorCount > 0, "A safe error must reach the memory transport");
  assert.ok(spanCount > 0, "Completed spans must reach the memory transport");
  assert.ok(serialized.includes("Safe synthetic diagnostic"));
  assert.ok(serialized.includes("safe-synthetic-operation"));
  const present = Object.fromEntries(
    Object.entries(canaries).map(([key, value]) => [key, serialized.includes(value)]),
  );
  const paths = Object.fromEntries(Object.keys(canaries).map((key) => [key, []]));
  const walk = (value, path = "") => {
    if (typeof value === "string") {
      for (const [key, canary] of Object.entries(canaries))
        if (value.includes(canary)) paths[key].push(path);
    } else if (value && typeof value === "object") {
      for (const [key, child] of Object.entries(value)) walk(child, path + "/" + key);
    }
  };
  walk(envelopes);
  // Do not print envelopes or request contents; only synthetic presence flags.
  console.log(
    JSON.stringify({
      mode,
      sdkVersion: Sentry.SDK_VERSION,
      errorCount,
      spanCount,
      present,
      paths,
      genAI: serialized.includes("gen_ai"),
    }),
  );
} finally {
  await Sentry.close(5000);
  server.closeAllConnections();
  await new Promise((resolve, reject) =>
    server.close((error) => (error ? reject(error) : resolve())),
  );
}
