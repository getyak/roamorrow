import test from "node:test";
import assert from "node:assert/strict";
import { assertRuntimeIdentity, assertResponseIdentity, assertMoveResult } from "./integrity.mjs";
const stop = { stop_id: "s", coordinates: [139, 35] },
  before = {
    map_id: "m",
    version: 3,
    days: [
      { day_id: "d1", stops: [stop] },
      { day_id: "d2", stops: [] },
      { day_id: "d3", stops: [] },
    ],
  },
  after = {
    map_id: "m",
    version: 4,
    days: [
      { day_id: "d1", stops: [] },
      { day_id: "d2", stops: [stop] },
      { day_id: "d3", stops: [] },
    ],
  },
  intent = { stopId: "s", fromDayId: "d1", toDayId: "d2" },
  finished = { normalFinish: true, finalMessage: "已移到第二天" };
test("old running process cannot be labelled current candidate", () => {
  assert.throws(
    () =>
      assertRuntimeIdentity(
        { runtime_id: "r", candidate_digest: "old", rubric_sha256: "rule", source_revision: "rev" },
        "new",
        "rule",
      ),
    /identity/,
  );
});
test("response headers must match runtime identity", () => {
  assert.throws(
    () =>
      assertResponseIdentity(new Headers({ "x-map-candidate": "old" }), {
        candidate_digest: "new",
        source_revision: "r",
        runtime_id: "i",
      }),
    /identity/,
  );
});
test("requested move succeeds", () =>
  assert.equal(assertMoveResult(before, after, intent, finished), true));
test("unrelated successful update is not a requested move", () =>
  assert.throws(
    () => assertMoveResult(before, { ...before, version: 4 }, intent, finished),
    /not moved/,
  ));
test("edit without final model response is incomplete", () =>
  assert.throws(
    () => assertMoveResult(before, after, intent, { normalFinish: false, finalMessage: "" }),
    /finish/,
  ));
test("third day must remain unchanged", () => {
  const wrong = structuredClone(after);
  wrong.days[2].stops.push({ stop_id: "bad", coordinates: [139, 35] });
  assert.throws(() => assertMoveResult(before, wrong, intent, finished), /duplicated|unrelated/);
});
test("truncated model output is not a normal successful finish", async () => {
  const { assertCompletedJourney } = await import("./integrity.mjs");
  assert.throws(
    () =>
      assertCompletedJourney({
        beforeEdit: before,
        lastSnapshot: after,
        expectedEdit: intent,
        normalFinish: true,
        finalMessage: "已移动…",
        finishReason: "length",
      }),
    /finish_reason/,
  );
});
test("stale afterEdit cannot hide later mutation of third day", async () => {
  const { assertCompletedJourney } = await import("./integrity.mjs");
  const changed = structuredClone(after);
  changed.days[2].start_minute = 600;
  assert.throws(
    () =>
      assertCompletedJourney({
        beforeEdit: before,
        afterEdit: after,
        lastSnapshot: changed,
        expectedEdit: intent,
        normalFinish: true,
        finalMessage: "已移动",
        finishReason: "stop",
      }),
    /unrelated/,
  );
});
test("moving a stop cannot silently shorten its stay", () => {
  const b = structuredClone(before),
    a = structuredClone(after);
  b.days[0].stops[0].duration_minutes = 90;
  a.days[1].stops[0].duration_minutes = 60;
  assert.throws(() => assertMoveResult(b, a, intent, finished), /duration|immutable/);
});
