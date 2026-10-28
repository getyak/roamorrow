import { strict as assert } from "node:assert";
import test from "node:test";
import {
  authorizeBriefRequest,
  validateBriefInput,
  validateBriefResponse,
} from "../../infra/supabase/functions/_shared/city-brief-contract.ts";

const now = Date.parse("2026-10-28T06:00:00Z");
function result(overrides = {}) {
  return {
    city_code: "vte",
    outcomes: [
      {
        target: "events",
        status: "ok",
        itemsWritten: 2,
        receipt: {
          id: "run-1",
          city_code: "vte",
          target: "events",
          status: "ok",
          items_written: 2,
          started_at: "2026-10-28T05:59:00Z",
          finished_at: "2026-10-28T05:59:50Z",
        },
        ...overrides,
      },
    ],
  };
}

test("cron auth rejects missing or wrong secret without accepting an empty bearer", () => {
  assert.equal(authorizeBriefRequest(new Headers(), undefined, undefined), false);
  assert.equal(
    authorizeBriefRequest(new Headers({ authorization: "service" }), "service", undefined),
    false,
  );
  assert.equal(
    authorizeBriefRequest(new Headers({ "x-cron-secret": "wrong" }), "service", "correct"),
    false,
  );
  assert.equal(
    authorizeBriefRequest(new Headers({ "x-cron-secret": "correct" }), "service", "correct"),
    true,
  );
  assert.equal(
    authorizeBriefRequest(new Headers({ authorization: "Bearer service" }), "service", undefined),
    true,
  );
});
test("only the existing bounded city and target are accepted before provider work", () => {
  assert.deepEqual(validateBriefInput({ city_code: "vte", target: "events", force: false }), {
    city_code: "vte",
    target: "events",
    force: false,
  });
  for (const body of [
    { city_code: "unlisted", target: "events" },
    { city_code: "vte", target: "all" },
    { city_code: "vte", target: ["events"] },
    { city_code: "vte", target: "events", force: "false" },
  ]) {
    assert.throws(() => validateBriefInput(body));
  }
});
test("an HTTP 200 failed or partial target never passes refresh validation", () => {
  for (const status of ["failed", "partial"])
    assert.throws(() => validateBriefResponse(result({ status }), "vte", "events", now));
});
test("successful refresh needs matching persisted accounting", () => {
  assert.deepEqual(validateBriefResponse(result(), "vte", "events", now), [
    { target: "events", kind: "refreshed", itemsWritten: 2 },
  ]);
  assert.throws(() => validateBriefResponse(result({ receipt: null }), "vte", "events", now));
  const response = result();
  response.outcomes[0].receipt.city_code = "other";
  assert.throws(() => validateBriefResponse(response, "vte", "events", now));
});
test("missing, duplicate and wrong-city target outcomes are rejected", () => {
  assert.throws(() =>
    validateBriefResponse({ city_code: "vte", outcomes: [] }, "vte", "events", now),
  );
  const duplicate = result();
  duplicate.outcomes.push(duplicate.outcomes[0]);
  assert.throws(() => validateBriefResponse(duplicate, "vte", "events", now));
  assert.throws(() =>
    validateBriefResponse({ ...result(), city_code: "cmi" }, "vte", "events", now),
  );
  assert.throws(() => validateBriefResponse(result(), "vte", "both", now));
});
test("cooldown is accepted only with a fresh successful persisted run", () => {
  const cached = result({ error: "cooldown", itemsWritten: 0 });
  assert.deepEqual(validateBriefResponse(cached, "vte", "events", now), [
    { target: "events", kind: "cooldown", itemsWritten: 0 },
  ]);
  cached.outcomes[0].receipt.finished_at = "2026-10-20T06:00:00Z";
  assert.throws(() => validateBriefResponse(cached, "vte", "events", now));
});

test("workflow verifier exits nonzero without echoing a failed provider response", async () => {
  const { mkdtempSync, writeFileSync, rmSync } = await import("node:fs");
  const { tmpdir } = await import("node:os");
  const { join } = await import("node:path");
  const { fileURLToPath } = await import("node:url");
  const { spawnSync } = await import("node:child_process");
  const dir = mkdtempSync(join(tmpdir(), "city-brief-contract-"));
  try {
    const file = join(dir, "response.json");
    writeFileSync(
      file,
      JSON.stringify(result({ status: "failed", error: "provider-body-must-not-echo" })),
    );
    const run = spawnSync(
      process.execPath,
      [
        "--experimental-strip-types",
        fileURLToPath(new URL("../city-brief-refresh.mjs", import.meta.url)),
        "verify",
        file,
        "vte",
        "events",
      ],
      { encoding: "utf8" },
    );
    assert.equal(run.status, 1);
    assert.doesNotMatch(run.stdout + run.stderr, /provider-body-must-not-echo/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
