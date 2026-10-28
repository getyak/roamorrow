import test from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createDomain } from "../demo/domain.mjs";
const point = (id, name, c) => ({
  place_ref: id,
  name,
  coordinates: c,
  provider: "unit-live-adapter",
  source_url: "https://www.wikidata.org/" + id,
  evidence_status: "resolved",
  duration_minutes: 30,
});
function setup(routeLookup) {
  const dir = mkdtempSync(join(tmpdir(), "map-live-unit-"));
  const catalog = [point("Q1", "A", [139.7, 35.7]), point("Q2", "B", [139.71, 35.71])];
  const domain = createDomain(dir, "http://127.0.0.1:1", { catalog, routeLookup, mode: "live" });
  const create = domain.call(
    "create_map",
    { title: "Tokyo", city: "Tokyo", day_count: 1, timezone: "Asia/Tokyo", idempotency_key: "c" },
    "unit",
  );
  return { dir, domain, catalog, map: create.data.snapshot };
}
test("live mode uses injected catalog and exact provider time without fixture fallback", () => {
  const s = setup(() => ({
    duration_seconds: 123,
    distance_meters: 100,
    geometry: {
      type: "LineString",
      coordinates: [
        [139.7, 35.7],
        [139.71, 35.71],
      ],
    },
    source_url: "https://routing.openstreetmap.de",
    fetched_at: new Date().toISOString(),
  }));
  try {
    assert.equal(s.map.demo, false);
    let m = s.domain.call(
      "plot_places",
      {
        map_id: s.map.map_id,
        expected_version: 1,
        idempotency_key: "p",
        items: s.catalog.map((p) => ({
          place_ref: p.place_ref,
          day_id: s.map.days[0].day_id,
          duration_minutes: 30,
        })),
      },
      "unit",
    ).data.snapshot;
    const r = s.domain.call(
      "build_route",
      {
        map_id: m.map_id,
        expected_version: m.version,
        idempotency_key: "b",
        transport_mode: "walking",
        allow_unknown_travel: false,
        day_plans: [
          {
            day_id: m.days[0].day_id,
            stop_ids: m.days[0].stops.map((s) => s.stop_id),
            start_minute: 540,
            end_minute: 1080,
            order_policy: "preserve",
          },
        ],
      },
      "unit",
    );
    const leg = r.data.snapshot.days[0].legs[0];
    assert.equal(leg.duration_minutes, 3);
    assert.equal(leg.evidence_status, "resolved");
    assert.equal(leg.geometry_status, "routed");
    assert.equal(leg.geometry.coordinates.length, 2);
    assert(!r.warnings.some((w) => w.code === "demo_fixture"));
  } finally {
    rmSync(s.dir, { recursive: true, force: true });
  }
});
test("live mode with missing network data never generates straight-line ETA", () => {
  const s = setup(() => null);
  try {
    const m = s.domain.call(
      "plot_places",
      {
        map_id: s.map.map_id,
        expected_version: 1,
        idempotency_key: "p",
        items: s.catalog.map((p) => ({
          place_ref: p.place_ref,
          day_id: s.map.days[0].day_id,
          duration_minutes: 30,
        })),
      },
      "unit",
    ).data.snapshot;
    assert.throws(
      () =>
        s.domain.call(
          "build_route",
          {
            map_id: m.map_id,
            expected_version: m.version,
            idempotency_key: "b",
            transport_mode: "walking",
            allow_unknown_travel: false,
            day_plans: [
              {
                day_id: m.days[0].day_id,
                stop_ids: m.days[0].stops.map((s) => s.stop_id),
                start_minute: 540,
                end_minute: 1080,
                order_policy: "preserve",
              },
            ],
          },
          "unit",
        ),
      (e) => e.code === "PROVIDER_UNAVAILABLE",
    );
    assert.equal(s.domain.get(m.map_id, "unit").version, 2);
  } finally {
    rmSync(s.dir, { recursive: true, force: true });
  }
});
test("internal preparation preview leaves neither map nor idempotency result on disk", () => {
  const s = setup(() => null);
  try {
    const r = s.domain.call(
      "create_map",
      {
        title: "preview",
        city: "Tokyo",
        day_count: 1,
        timezone: "Asia/Tokyo",
        idempotency_key: "internal-preview",
      },
      "unit",
      { previewOnly: true },
    );
    assert.throws(() => s.domain.get(r.data.snapshot.map_id, "unit"));
  } finally {
    rmSync(s.dir, { recursive: true, force: true });
  }
});
