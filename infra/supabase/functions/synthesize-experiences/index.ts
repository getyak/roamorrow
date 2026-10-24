// Edge Function: synthesize-experiences
// Epic E US-030 — server-side AI synthesis so the iOS bundle never
// contains a DeepSeek API key.
//
// Flow:
//   1. Verify Supabase JWT from Authorization header.
//   2. Look up profiles.entitlement_tier; free tier rejected with 402.
//   3. Rate-limit: count today's calls in sc_function_calls; cap at 30.
//   4. Read SHA256 cache key from body; if synthesized_experiences row
//      exists, return it without calling DeepSeek.
//   5. Call DeepSeek (OpenAI-compatible chat/completions, thinking disabled)
//      with the prompt + POI batch.
//   6. Validate response shape, write to synthesized_experiences,
//      return to client.
//
// Deploy: `supabase functions deploy synthesize-experiences`
// Required secrets: DEEPSEEK_API_KEY, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
// Optional: DEEPSEEK_BASE_URL (defaults to https://api.deepseek.com/v1),
//           DEEPSEEK_MODEL (defaults to deepseek-flash).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { bearerToken, verifiedUserId } from "../_shared/request-auth.ts";
import {
  buildDeepSeekChatBody,
  deepSeekBaseUrl,
  normalizeDeepSeekModel,
  parseDeepSeekContent,
  parseJsonArrayFromText,
} from "../_shared/deepseek.ts";

const DAILY_QUOTA_PRO = 30;
const MAX_POIS_PER_CALL = 60; // US-MR-03: raised from 15 to accommodate the full 4-ring merge
const SYNTHESIS_VERSION = "facts-v2";
const CACHE_TTL_MS = 7 * 24 * 60 * 60 * 1000;

interface POI {
  osmId: number | string;
  name: string;
  nameEn?: string | null;
  lat: number;
  lon: number;
  tags: Record<string, string>;
}

interface RequestBody {
  pois: POI[];
  cityCode: string;
  locale: string;
  cacheKey: string;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json({ error: "method not allowed" }, 405);
  }

  // 1. Auth: extract user_id from JWT in Authorization header.
  const jwt = bearerToken(req);
  if (!jwt) return json({ error: "missing bearer token" }, 401);

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const deepseekKey = Deno.env.get("DEEPSEEK_API_KEY");
  if (!deepseekKey) return json({ error: "server misconfigured" }, 500);

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  // Verify JWT and extract user_id.
  const userId = await verifiedUserId(admin, jwt);
  if (userId === null) return json({ error: "invalid jwt" }, 401);

  // 2. Entitlement check.
  const { data: profile } = await admin
    .from("profiles")
    .select("entitlement_tier")
    .eq("user_id", userId)
    .maybeSingle();
  const tier = profile?.entitlement_tier ?? "free";
  if (tier === "free" || tier === "pro_expired") {
    return json({ error: "subscription required" }, 402);
  }

  // 3. Rate-limit: today's call count.
  const dayStart = new Date();
  dayStart.setUTCHours(0, 0, 0, 0);
  const { count } = await admin
    .from("sc_function_calls")
    .select("*", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("function_name", "synthesize-experiences")
    .gte("called_at", dayStart.toISOString());
  if ((count ?? 0) >= DAILY_QUOTA_PRO) {
    return json({ error: "daily quota exceeded", quota: DAILY_QUOTA_PRO }, 429);
  }

  // 4. Parse + cache check.
  let body: RequestBody;
  try {
    const parsed = await req.json();
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      return json({ error: "request body must be an object" }, 400);
    }
    body = parsed;
  } catch {
    return json({ error: "invalid json" }, 400);
  }
  if (
    typeof body.cacheKey !== "string" ||
    !body.cacheKey.trim() ||
    !Array.isArray(body.pois) ||
    body.pois.length === 0
  ) {
    return json({ error: "cacheKey + non-empty pois required" }, 400);
  }
  if (body.pois.length > MAX_POIS_PER_CALL) {
    return json({ error: `max ${MAX_POIS_PER_CALL} POIs per call` }, 400);
  }
  if (
    body.pois.some((poi) => !validPOI(poi)) ||
    typeof body.cityCode !== "string" ||
    typeof body.locale !== "string"
  ) {
    return json({ error: "invalid POI facts" }, 400);
  }

  // Resolve the target model BEFORE the cache lookup: a cached payload is
  // only reusable for the same model, so a legacy Claude/deepseek-chat entry
  // can never be served for a deepseek-flash request.
  const model = normalizeDeepSeekModel(Deno.env.get("DEEPSEEK_MODEL"));
  const cacheKey = await factsCacheKey(body, model);

  const { data: cached } = await admin
    .from("synthesized_experiences")
    .select("payload,synthesized_at")
    .eq("source_cache_key", cacheKey)
    .eq("model_name", model)
    .limit(1)
    .maybeSingle();
  const cacheAge = Date.now() - Date.parse(cached?.synthesized_at ?? "");
  if (cacheAge >= 0 && cacheAge < CACHE_TTL_MS && validItems(cached?.payload, body.pois)) {
    return json({ experiences: cached.payload, cached: true });
  }

  // 5. Call DeepSeek (OpenAI-compatible chat/completions, thinking disabled).
  const prompt = buildPrompt(body);
  const deepseekReq = await fetch(
    `${deepSeekBaseUrl(Deno.env.get("DEEPSEEK_BASE_URL"))}/chat/completions`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${deepseekKey}`,
        "content-type": "application/json",
      },
      body: JSON.stringify(
        buildDeepSeekChatBody({
          model,
          max_tokens: 2048,
          messages: [{ role: "user", content: prompt }],
        }),
      ),
    },
  );
  if (!deepseekReq.ok) {
    const text = await deepseekReq.text();
    return json({ error: `deepseek error ${deepseekReq.status}: ${text}` }, 502);
  }
  const deepseekJson = await deepseekReq.json();
  const text = parseDeepSeekContent(deepseekJson);

  // 6. Validate response shape. Reject empty arrays and null / non-object
  //    items with a controlled 502 BEFORE any cache write, so a bad upstream
  //    payload never poisons the cache or crashes on items[0]/item.osmId.
  const items = parseJsonArrayFromText(text);
  if (!items) {
    return json({ error: "deepseek returned no JSON array" }, 502);
  }
  if (items.length === 0) {
    return json({ error: "deepseek returned an empty array" }, 502);
  }
  for (const item of items) {
    if (item === null || typeof item !== "object" || Array.isArray(item)) {
      return json({ error: "deepseek item is not an object" }, 502);
    }
    const fields = item as Record<string, unknown>;
    if (
      !Number.isSafeInteger(fields.osmId) ||
      typeof fields.title !== "string" ||
      typeof fields.oneLiner !== "string" ||
      typeof fields.whyItMatters !== "string" ||
      typeof fields.category !== "string"
    ) {
      return json({ error: "deepseek item missing required fields" }, 502);
    }
  }
  // The model only sees small batch aliases. Restore the exact provider IDs
  // before caching or returning, including IDs above JavaScript's 2^53 limit.
  const restored = items.map((item) => {
    const fields = item as Record<string, unknown>;
    const alias = fields.osmId as number;
    return { ...fields, osmId: body.pois[alias - 1]?.osmId };
  });
  if (!validItems(restored, body.pois)) {
    return json({ error: "deepseek returned invalid place identity or category" }, 502);
  }

  // Write to cache and accounting tables.
  await admin.from("synthesized_experiences").upsert({
    id: `exp_osm_${restored[0]?.osmId}`,
    city_code: body.cityCode,
    payload: restored,
    model_name: model,
    source_cache_key: cacheKey,
    synthesized_at: new Date().toISOString(),
  });
  await admin.from("sc_function_calls").insert({
    user_id: userId,
    function_name: "synthesize-experiences",
  });

  return json({ experiences: restored, cached: false });
});

function buildPrompt(body: RequestBody): string {
  const lines = body.pois
    .map(
      (p, index) =>
        `- osmId=${index + 1} name="${p.name}" nameEn="${p.nameEn ?? p.name}" lat=${p.lat} lon=${p.lon} tags=${JSON.stringify(p.tags)}`,
    )
    .join("\n");
  return `You are writing solo-traveler-focused entries for real OpenStreetMap places.

CRITICAL: Use ONLY the provided place facts. Do NOT invent menu items, hours, prices, owner backstories, seating positions, or business status. A suggested visit window is not opening hours. When timing is unsupported omit bestStartHour/bestEndHour. Missing facts stay unknown. Provider ratings are not solo-traveler observations.

DISTANCE AWARENESS: POIs span 0–12 km from the query center (a Pro radial Explore covers 4 rings: 1.5/3/6/12 km). The query center is not provided, so do not infer distance bands or walk times from the POIs relative to each other. Preserve input order.

For each POI, return a JSON object with: osmId(int), title, oneLiner, whyItMatters, category(food|coffee|culture|nature|work|wellness|nightlife|hidden), bestStartHour(0-23), bestEndHour(0-23), durationMinMinutes(int), durationMaxMinutes(int), howTo(string[] navigation only), soloHint, soloOverall(number 0–10 or null when unsupported; never derive it from a provider rating alone).

Output a JSON array, one object per POI. No prose, no markdown fences.

Output language: ${body.locale}.
City code: ${body.cityCode}.

POIs:
${lines}`;
}

function validSourceId(value: unknown): boolean {
  if (typeof value === "number") return Number.isSafeInteger(value);
  if (typeof value !== "string" || !/^-?\d{1,19}$/.test(value)) return false;
  const id = BigInt(value);
  return id >= -9223372036854775808n && id <= 9223372036854775807n;
}

function validPOI(value: unknown): value is POI {
  if (!value || typeof value !== "object") return false;
  const poi = value as POI;
  return (
    validSourceId(poi.osmId) &&
    typeof poi.name === "string" &&
    Number.isFinite(poi.lat) &&
    Math.abs(poi.lat) <= 90 &&
    Number.isFinite(poi.lon) &&
    Math.abs(poi.lon) <= 180 &&
    !!poi.tags &&
    typeof poi.tags === "object" &&
    !Array.isArray(poi.tags) &&
    Object.values(poi.tags).every((value) => typeof value === "string")
  );
}

function nonEmptyText(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0;
}

function optionalInteger(value: unknown, min: number, max = Number.MAX_SAFE_INTEGER): boolean {
  return (
    value == null ||
    (typeof value === "number" && Number.isSafeInteger(value) && value >= min && value <= max)
  );
}

function validItems(value: unknown, pois: POI[]): value is Record<string, unknown>[] {
  if (!Array.isArray(value) || value.length === 0 || value.length !== pois.length) return false;
  const ids = new Set(pois.map((poi) => poi.osmId));
  const seen = new Set<number | string>();
  const categories = new Set([
    "food",
    "coffee",
    "culture",
    "nature",
    "work",
    "wellness",
    "nightlife",
    "hidden",
  ]);
  return value.every((item) => {
    if (
      !item ||
      typeof item !== "object" ||
      Array.isArray(item) ||
      !ids.has(item.osmId) ||
      seen.has(item.osmId) ||
      !categories.has(item.category) ||
      !nonEmptyText(item.title) ||
      !nonEmptyText(item.oneLiner) ||
      !nonEmptyText(item.whyItMatters) ||
      !optionalInteger(item.bestStartHour, 0, 23) ||
      !optionalInteger(item.bestEndHour, 0, 23) ||
      !optionalInteger(item.durationMinMinutes, 1) ||
      !optionalInteger(item.durationMaxMinutes, 1) ||
      (item.durationMinMinutes != null &&
        item.durationMaxMinutes != null &&
        item.durationMaxMinutes < item.durationMinMinutes) ||
      (item.soloOverall != null &&
        (typeof item.soloOverall !== "number" ||
          !Number.isFinite(item.soloOverall) ||
          item.soloOverall < 0 ||
          item.soloOverall > 10)) ||
      (item.howTo != null && (!Array.isArray(item.howTo) || !item.howTo.every(nonEmptyText))) ||
      (item.soloHint != null && typeof item.soloHint !== "string")
    )
      return false;
    seen.add(item.osmId);
    return true;
  });
}

/** Bind server cache reuse to the actual facts, not a caller-controlled opaque key. */
async function factsCacheKey(body: RequestBody, model: string): Promise<string> {
  const pois = body.pois
    .map((poi) => ({
      osmId: poi.osmId,
      name: poi.name,
      nameEn: poi.nameEn ?? null,
      lat: poi.lat,
      lon: poi.lon,
      tags: Object.fromEntries(Object.entries(poi.tags).sort(([a], [b]) => a.localeCompare(b))),
    }))
    .sort((a, b) => String(a.osmId).localeCompare(String(b.osmId)));
  const canonical = JSON.stringify({
    version: SYNTHESIS_VERSION,
    model,
    city: body.cityCode,
    locale: body.locale,
    pois,
  });
  const bytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(canonical));
  const hash = Array.from(new Uint8Array(bytes), (byte) => byte.toString(16).padStart(2, "0")).join(
    "",
  );
  return `${SYNTHESIS_VERSION}:${hash}`;
}

function json(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "content-type": "application/json" },
  });
}
