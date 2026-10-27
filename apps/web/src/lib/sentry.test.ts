import { test } from "vitest";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { createRequire } from "node:module";
import { fileURLToPath, pathToFileURL } from "node:url";

test("Sentry retains diagnostics without automatically recording private request or model content", () => {
  const require = createRequire(import.meta.url);
  const botRequire = createRequire(new URL("../../../../apps/bot/package.json", import.meta.url));
  const fixture = fileURLToPath(
    new URL("../../../../scripts/sentry-privacy-fixture.mjs", import.meta.url),
  );
  const sdk = pathToFileURL(require.resolve("@sentry/nextjs")).href;
  const openai = pathToFileURL(botRequire.resolve("openai")).href;
  const policy = new URL("./sentry.ts", import.meta.url).href;
  const env: NodeJS.ProcessEnv = {
    NODE_ENV: "test",
    ...Object.fromEntries(
      ["PATH", "LANG", "TZ", "SYSTEMROOT", "TMPDIR"].flatMap((key) =>
        process.env[key] === undefined ? [] : [[key, process.env[key]!]],
      ),
    ),
  };
  const run = (mode: string) => {
    const output = execFileSync(
      process.execPath,
      ["--experimental-strip-types", fixture, mode, policy, sdk, openai],
      { env, encoding: "utf8", timeout: 25000, maxBuffer: 1024 * 1024 },
    );
    return JSON.parse(output.trim().split("\n").at(-1)!) as {
      sdkVersion: string;
      errorCount: number;
      spanCount: number;
      genAI: boolean;
      present: Record<string, boolean>;
    };
  };
  const declaredSdk = JSON.parse(
    readFileSync(new URL("../../package.json", import.meta.url), "utf8"),
  ).dependencies["@sentry/nextjs"];
  const control = run("control");
  assert.equal(control.sdkVersion, declaredSdk);
  assert.ok(control.errorCount > 0 && control.spanCount > 0 && control.genAI);
  for (const key of ["body", "cookie", "header", "query", "email", "prompt", "answer"])
    assert.equal(control.present[key], true, "The positive control must exercise " + key);
  const safe = run("private");
  assert.equal(safe.sdkVersion, declaredSdk);
  assert.ok(safe.errorCount > 0 && safe.spanCount > 0 && safe.genAI);
  for (const [key, present] of Object.entries(safe.present))
    assert.equal(present, false, "Private content in Sentry envelope: " + key);
}, 60000);
