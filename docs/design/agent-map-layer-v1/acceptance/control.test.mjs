import test from "node:test";
import assert from "node:assert/strict";
import { startLiveServer } from "./live-server.mjs";
import { startServer } from "../demo/server.mjs";
test("private fault and clock seams cannot be enabled on public acceptance runtime", async () => {
  await assert.rejects(
    startLiveServer({
      dir: "/unused",
      publicBaseURL: "https://maps.invalid",
      faultMode: () => "provider",
    }),
    /must remain private/,
  );
  await assert.rejects(
    startLiveServer({ dir: "/unused", publicBaseURL: "https://maps.invalid", now: () => 1 }),
    /must remain private/,
  );
  await assert.rejects(
    startServer({
      publicBaseURL: "https://maps.invalid",
      executionOptions: () => ({ fault: "provider" }),
    }),
    /cannot be public/,
  );
});
