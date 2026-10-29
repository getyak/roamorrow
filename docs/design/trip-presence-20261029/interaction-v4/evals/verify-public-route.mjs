/** Replays the recorded actual public route through the existing map domain.
 * No network. Uses explicit benchmark entity choices, not model disambiguation. */
import assert from "node:assert/strict";
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { createHash } from "node:crypto";
import { gunzipSync } from "node:zlib";
import { createDomain } from "../../../agent-map-layer-v1/demo/domain.mjs";
import { tools, validate } from "../../../agent-map-layer-v1/demo/contract.mjs";

const resultPath = new URL("./results/tools-eval-results.json", import.meta.url),
  directPath = new URL("./results/public-route-direct.response.json.gz", import.meta.url);
const directSummary = JSON.parse(
  readFileSync(new URL("./results/public-route-direct.json", import.meta.url), "utf8"),
);
assert(Number.isFinite(Date.parse(directSummary.recordedAt)));
const previous = JSON.parse(readFileSync(resultPath, "utf8")),
  direct = JSON.parse(gunzipSync(readFileSync(directPath)));
assert.equal(direct.ok, true);
assert.equal(direct.payload.code, "Ok");
const expected = ["wikidata:Q746216", "wikidata:Q615183"];
const catalog = previous.live.queries.map((q, i) =>
  q.candidates.find((p) => p.place_ref === expected[i]),
);
assert(catalog.every(Boolean));
const route = direct.payload.routes[0];
assert(route.geometry.coordinates.length > 2);
assert(route.distance > 0);
assert(route.duration > 0);
assert(
  direct.payload.waypoints.every((p) => p.distance <= 500),
  "routing snap must not silently choose a distant entrance",
);
const dir = mkdtempSync(join(tmpdir(), "get324-real-route-domain-"));
try {
  const domain = createDomain(dir, "http://127.0.0.1:1", {
    catalog,
    mode: "live",
    routeLookup: (a, b, mode) =>
      a.place_ref === expected[0] && b.place_ref === expected[1] && mode === "walking"
        ? {
            duration_seconds: route.duration,
            distance_meters: route.distance,
            geometry: route.geometry,
            source_url: direct.url,
            fetched_at: directSummary.recordedAt,
          }
        : null,
  });
  let response = domain.call(
    "create_map",
    {
      title: "Recorded public route domain check",
      city: "Tokyo",
      day_count: 1,
      timezone: "Asia/Tokyo",
      idempotency_key: "create",
    },
    "isolated-eval",
  );
  let map = response.data.snapshot;
  response = domain.call(
    "plot_places",
    {
      map_id: map.map_id,
      expected_version: map.version,
      idempotency_key: "plot",
      items: catalog.map((p) => ({
        place_ref: p.place_ref,
        day_id: map.days[0].day_id,
        duration_minutes: 30,
      })),
    },
    "isolated-eval",
  );
  map = response.data.snapshot;
  response = domain.call(
    "build_route",
    {
      map_id: map.map_id,
      expected_version: map.version,
      idempotency_key: "build",
      transport_mode: "walking",
      allow_unknown_travel: false,
      day_plans: [
        {
          day_id: map.days[0].day_id,
          stop_ids: map.days[0].stops.map((s) => s.stop_id),
          start_minute: 540,
          end_minute: 1080,
          order_policy: "preserve",
        },
      ],
    },
    "isolated-eval",
  );
  validate(tools.find((t) => t.name === "build_route").outputSchema, response);
  const leg = response.data.snapshot.days[0].legs[0];
  assert.equal(leg.evidence_status, "resolved");
  assert.equal(leg.geometry_status, "routed");
  assert.equal(leg.duration_minutes, Math.ceil(route.duration / 60));
  assert.deepEqual(leg.geometry, route.geometry);
  const proof = {
    status: "passed",
    sourceRecordedAt: directSummary.recordedAt,
    replayedAt: new Date().toISOString(),
    scope:
      "actual recorded public foot route injected into standalone acceptance domain; not native or model orchestration",
    sourceURL: direct.url,
    sourceResponseSha256: createHash("sha256")
      .update(gunzipSync(readFileSync(directPath)))
      .digest("hex"),
    durationSeconds: route.duration,
    durationMinutes: leg.duration_minutes,
    distanceMeters: route.distance,
    geometryPoints: route.geometry.coordinates.length,
    snappedDistanceMeters: direct.payload.waypoints.map((p) => p.distance),
    schema: "existing strict build_route outputSchema",
    mapDemo: response.data.snapshot.demo,
  };
  writeFileSync(
    new URL("./results/public-route-domain.json", import.meta.url),
    JSON.stringify(proof, null, 2) + "\n",
  );
  console.log(JSON.stringify(proof));
} finally {
  rmSync(dir, { recursive: true, force: true });
}
