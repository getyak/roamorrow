import { createClient } from "@supabase/supabase-js";
import { describe, expect, it } from "vitest";
import { ExperiencesRepo } from "./experiences-repo";
import type { Database, ExperienceRow } from "./db";

const center = [98.9853, 18.7883] as const;
function row(id: string, coordinates: [number, number]): ExperienceRow {
  return {
    id,
    title: id,
    one_liner: "Isolated lookup regression",
    why_it_matters: "Test only",
    category: "culture",
    location: { type: "Point", coordinates },
    city_code: "cmi",
    address_hint: null,
    place_name_local: null,
    place_name_romanized: null,
    best_times: [],
    duration_min: 10,
    duration_max: 20,
    how_to: [],
    real_inconveniences: [],
    solo_score: { overall: 5, breakdown: {}, basedOnCount: 0 },
    sources: [],
    confidence: { level: 0, signals: {} },
    nearby_experience_ids: [],
    completion_count: 0,
    average_rating: 0,
    last_completed_at: null,
    status: "active",
    created_at: "2026-10-28T00:00:00Z",
    updated_at: "2026-10-28T00:00:00Z",
  };
}

describe("nearby public experience lookup", () => {
  it("returns the nearby row even after 120 unrelated active rows", async () => {
    const nearby = row("nearby", [98.9853, 18.7883]);
    const globalRows = Array.from({ length: 120 }, (_, i) => row(`far-${i}`, [0, 0]));
    globalRows.push(nearby);
    const client = createClient<Database>("https://example.supabase.co", "isolated-anon", {
      auth: { persistSession: false, autoRefreshToken: false },
      global: {
        fetch: async (input, init) => {
          const url = new URL(String(input));
          if (url.pathname === "/rest/v1/experiences") {
            return Response.json(globalRows.slice(0, Number(url.searchParams.get("limit"))));
          }
          expect(url.pathname).toBe("/rest/v1/rpc/find_nearby_experiences");
          expect(JSON.parse(String(init?.body))).toEqual({
            p_longitude: 98.9853,
            p_latitude: 18.7883,
            p_radius_meters: 1500,
            p_limit: 30,
            p_category: null,
            p_city_code: null,
          });
          // The SQL acceptance suite owns spatial filtering and nearest-first order.
          return Response.json([nearby]);
        },
      },
    });
    const result = await new ExperiencesRepo(client).findNearby({
      center,
      radiusMeters: 1500,
      limit: 30,
    });
    expect(result.map((experience) => experience.id)).toEqual(["nearby"]);
    expect(result[0]?.location.coordinates).toEqual([98.9853, 18.7883]);
  });
});
