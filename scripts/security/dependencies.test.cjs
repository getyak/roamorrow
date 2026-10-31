const assert = require("node:assert/strict");
const { readFileSync, readdirSync } = require("node:fs");
const { createRequire } = require("node:module");
const { resolve } = require("node:path");
const { createServer } = require("node:net");
const { once } = require("node:events");
const { setTimeout: delay } = require("node:timers/promises");
const { test } = require("node:test");

const root = resolve(__dirname, "../..");
const web = createRequire(resolve(root, "apps/web/package.json"));
const floors = {
  "@sentry/nextjs": "10.75.2",
  next: "15.5.28",
  dompurify: "3.4.17",
  vite: "7.3.7",
  "@vitest/mocker": "4.1.12",
  zod: "4.6.6",
  undici: "7.30.1",
  "fast-uri": "3.1.9",
  glob: "14.0.2",
  minimatch: "11.0.1",
};
function versionParts(version) {
  assert.match(version, /^\d+\.\d+\.\d+$/, "security floors require stable releases");
  return version.split(".").map(Number);
}
function atLeast(version, floor) {
  const actual = versionParts(version),
    minimum = versionParts(floor);
  for (let i = 0; i < 3; i++) {
    if (actual[i] !== minimum[i]) return actual[i] > minimum[i];
  }
  return true;
}

test("every locked copy meets the reviewed security floor", () => {
  const lock = readFileSync(resolve(root, "pnpm-lock.yaml"), "utf8");
  const packages = lock.split("\npackages:\n")[1]?.split("\nsnapshots:\n")[0];
  assert.ok(packages);
  for (const [name, floor] of Object.entries(floors)) {
    const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const versions = [
      ...packages.matchAll(new RegExp(`^  ['"]?${escaped}@([^'":]+)['"]?:$`, "gm")),
    ].map((match) => match[1]);
    assert.ok(versions.length, `missing lock entries for ${name}`);
    for (const version of versions)
      assert.ok(atLeast(version, floor), `${name}@${version} is below fixed ${floor}`);
  }
});

test("oversized Zod collections fail before validating each element", () => {
  // Upstream fix: https://github.com/colinhacks/zod/commit/a0ebf97
  const { z } = web("zod");
  const schema = z.array(z.string().trim()).max(3);
  const result = schema.safeParse(Array(2048).fill(42));
  assert.equal(result.success, false);
  assert.equal(result.error.issues.length, 1, "must not allocate one issue per rejected element");
  assert.equal(result.error.issues[0].code, "too_big");
  assert.deepEqual(schema.parse([" one ", "two", "three"]), ["one", "two", "three"]);
});

test("actual Ajv URI consumers never promote encoded text into a live scheme", () => {
  // https://github.com/advisories/GHSA-w74x-v6f9-j3xg
  const virtualStore = resolve(root, "node_modules/.pnpm");
  const consumers = readdirSync(virtualStore).filter((name) => name.startsWith("ajv@8."));
  assert.ok(consumers.length, "expected real Ajv8 consumers");
  for (const consumer of consumers) {
    const require = createRequire(resolve(virtualStore, consumer, "node_modules/ajv/package.json"));
    const uri = require("fast-uri");
    for (const attack of ["%6Aavascript:alert(1)", "%u006Aavascript:alert(1)"]) {
      assert.notEqual(uri.parse(attack).scheme, "javascript");
      assert.ok(!/^javascript:/i.test(uri.normalize(attack)));
      assert.throws(() => uri.resolve("https://a.example/", attack), /URI scheme is malformed/);
    }
    assert.equal(uri.equal("%68ttp://a/", "http://a/"), false);
    assert.equal(uri.resolve("https://a.example/base/", "../ok"), "https://a.example/ok");
  }
});

test("excessive encodings plus an early close cannot crash the HTTP client", async () => {
  // Exact early-close condition: https://github.com/advisories/GHSA-xjj6-f33q-929c
  const bot = createRequire(resolve(root, "apps/bot/package.json"));
  const openai = createRequire(bot.resolve("openai"));
  const undici = openai("undici");
  const server = createServer((socket) => {
    socket.once("data", () =>
      socket.end(
        "HTTP/1.1 200 OK\r\nContent-Length: 1\r\nContent-Encoding: gzip, gzip, gzip, gzip, gzip, gzip\r\n\r\n",
      ),
    );
  });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  try {
    await assert.rejects(
      undici.fetch(`http://127.0.0.1:${server.address().port}/`, {
        signal: AbortSignal.timeout(2000),
      }),
    );
    await delay(30); // Allow a formerly orphaned stream error to surface.
  } finally {
    await undici.getGlobalDispatcher().close();
    server.close();
    await once(server, "close");
  }
});
