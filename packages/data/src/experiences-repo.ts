/**
 * ExperiencesRepo — typed access to the `experiences` table.
 *
 * The repo translates between the SQL row shape (snake_case, JSONB blobs)
 * and the domain Experience type from @solo-compass/core. Callers should
 * never see raw rows.
 */

import type { SupabaseClient } from "@supabase/supabase-js";
import type { Coordinates, Experience, ExperienceCategory } from "@solo-compass/core";
import { rowToExperience, type Database, type ExperienceRow } from "./db";

export interface FindNearbyParams {
  /** [longitude, latitude] — GeoJSON order. */
  readonly center: Coordinates;
  /** Search radius in meters. */
  readonly radiusMeters: number;
  /** Max rows to return. */
  readonly limit?: number;
  /** Optional category filter. */
  readonly category?: ExperienceCategory;
  /** Optional city filter (cheaper than geo for "give me everything in CMI"). */
  readonly cityCode?: string;
}

export class ExperiencesRepo {
  constructor(private readonly client: SupabaseClient<Database>) {}

  /** Filter and order in PostgreSQL before limiting; the invoker RPC keeps RLS. */
  async findNearby(params: FindNearbyParams): Promise<Experience[]> {
    const { center, radiusMeters, limit = 50, category, cityCode } = params;
    const { data, error } = await this.client.rpc("find_nearby_experiences", {
      p_longitude: center[0],
      p_latitude: center[1],
      p_radius_meters: radiusMeters,
      p_limit: limit,
      p_category: category ?? null,
      p_city_code: cityCode ?? null,
    });
    if (error) throw new Error(`findNearby failed: ${error.message}`);
    return ((data ?? []) as ExperienceRow[]).map(rowToExperience);
  }

  /** Single experience by id. Returns null when missing. */
  async findById(id: string): Promise<Experience | null> {
    const { data, error } = await this.client
      .from("experiences")
      .select("*")
      .eq("id", id)
      .maybeSingle();
    if (error) throw new Error(`findById failed: ${error.message}`);
    if (!data) return null;
    return rowToExperience(data as ExperienceRow);
  }

  /** Alias for findById — preferred name going forward. */
  async getById(id: string): Promise<Experience | null> {
    return this.findById(id);
  }

  /**
   * List active experiences in a city, ordered by solo score descending.
   * Useful for "give me everything in Chiang Mai" without a geo query.
   */
  async listByCity(cityCode: string, limit = 100): Promise<Experience[]> {
    const { data, error } = await this.client
      .from("experiences")
      .select("*")
      .eq("city_code", cityCode)
      .eq("status", "active")
      .order("solo_score->overall" as "id", { ascending: false, nullsFirst: false })
      .limit(limit);
    if (error) throw new Error(`listByCity failed: ${error.message}`);
    if (!data) return [];
    return (data as ExperienceRow[]).map(rowToExperience);
  }

  /**
   * Full-text search across experience titles and descriptions.
   * Uses PostgREST `textSearch` on `title` (falls back gracefully if
   * `search_vector` column is not present in the live schema).
   *
   * Results are ordered by relevance descending (PostgREST default for
   * textSearch). An optional `cityCode` narrows the search to one city.
   */
  async searchByIntent(query: string, cityCode?: string, limit = 20): Promise<Experience[]> {
    let q = this.client
      .from("experiences")
      .select("*")
      .eq("status", "active")
      .textSearch("title", query, { type: "websearch", config: "english" })
      .limit(limit);

    if (cityCode) q = q.eq("city_code", cityCode);

    const { data, error } = await q;
    if (error) throw new Error(`searchByIntent failed: ${error.message}`);
    if (!data) return [];
    return (data as ExperienceRow[]).map(rowToExperience);
  }
}
