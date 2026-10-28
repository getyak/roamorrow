// Edge Function: compile-city-brief
// Solo City OS v2 — server-side curation of the landing kit (落地包) and the
// live/在地 events for a city. NOT user-triggered: content is city-level and
// shared, so a user "refresh" is just a re-read of the tables. This function is
// invoked by GitHub Actions cron (x-cron-secret) or with the service-role key.
//
// Flow:
//   1. Auth: Authorization Bearer == SUPABASE_SERVICE_ROLE_KEY, OR
//      x-cron-secret == CITY_BRIEF_CRON_SECRET. Else 401.
//   2. Validate {city_code, target, force?}; city must exist + brief_enabled.
//   3. Cooldown via city_brief_runs (events 72h / kit 240h) unless force.
//   4. Tavily search (advanced, max_results 6) → normalize to Candidates,
//      dedup by URL, cap 18 / ~15k chars.
//   5. DeepSeek (json_object, retry once) → parse → quality gates in _shared.
//   6. Upsert: kit confirm→bump last_verified_at+green; omit→untouched; then
//      downgrade rows older than 45d to yellow. events upsert by deterministic
//      id + normalized-name ±2d dedup; never delete (expiry is by status).
//   7. Write a city_brief_runs row with usage numbers + status ok|partial|failed.
//
// Deploy: `supabase functions deploy compile-city-brief`
// Secrets: TAVILY_API_KEY, DEEPSEEK_API_KEY, CITY_BRIEF_CRON_SECRET,
//          (optional DEEPSEEK_BASE_URL, DEEPSEEK_MODEL). SUPABASE_URL /
//          SUPABASE_SERVICE_ROLE_KEY are provided by the runtime.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  authorizeBriefRequest,
  BRIEF_COOLDOWN_MS,
  validateBriefInput,
  validateBriefResponse,
} from "../_shared/city-brief-contract.ts";
import {
  tavilyQueries,
  buildEventsPrompt,
  buildKitPrompt,
  parseModelJSON,
  validateEvents,
  validateKit,
  eventId,
  normalizeName,
  type Candidate,
  type CityContext,
  type CompileTarget,
  type KitSection,
} from "../_shared/city-brief-core.ts";
import {
  buildDeepSeekChatBody,
  deepSeekBaseUrl,
  normalizeDeepSeekModel,
  parseDeepSeekContent,
  parseDeepSeekUsage,
} from "../_shared/deepseek.ts";

// ─── Budget constants ────────────────────────────────────────────────────────

const TAVILY_URL = "https://api.tavily.com/search";
const TAVILY_MAX_RESULTS = 6;
const TAVILY_SEARCH_DEPTH = "advanced";
const MAX_CANDIDATES = 18;
const MAX_CANDIDATE_CHARS = 15_000;
const MAX_RAWTEXT_CHARS = 1_200;
const DEEPSEEK_MAX_TOKENS = 3_000;
const KIT_STALE_YELLOW_MS = 45 * 24 * 60 * 60 * 1000; // 45 days

// ─── Types ───────────────────────────────────────────────────────────────────

interface RequestBody {
  city_code: string;
  target: CompileTarget | "both";
  force?: boolean;
}

interface CityRow {
  city_code: string;
  name_en: string;
  name_zh: string;
  name_local: string;
  timezone: string;
  brief_enabled: boolean;
}

interface RunOutcome {
  target: CompileTarget;
  status: "ok" | "partial" | "failed";
  searchCalls: number;
  promptTokens: number;
  outputTokens: number;
  itemsWritten: number;
  error?: string;
  receipt?: RunReceipt;
}
interface RunReceipt {
  id: string;
  city_code: string;
  target: CompileTarget;
  status: "ok" | "partial" | "failed";
  items_written: number;
  started_at: string;
  finished_at: string;
}

// ─── Entry ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const cronSecret = Deno.env.get("CITY_BRIEF_CRON_SECRET");
  const tavilyKey = Deno.env.get("TAVILY_API_KEY");
  const deepseekKey = Deno.env.get("DEEPSEEK_API_KEY");

  // Fail closed before database or provider work; no header or key is logged.
  if (!authorizeBriefRequest(req.headers, serviceKey, cronSecret)) {
    return json({ error: "unauthorized" }, 401);
  }
  let body: RequestBody;
  try {
    body = validateBriefInput(await req.json());
  } catch {
    return json({ error: "invalid bounded city brief request" }, 400);
  }
  if (!tavilyKey || !deepseekKey || !supabaseUrl || !serviceKey) {
    return json({ error: "server misconfigured" }, 500);
  }
  const cityCode = body.city_code;
  const target = body.target;
  const force = body.force === true;

  const admin = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } });

  // City must exist and be brief-enabled.
  const { data: cityRow } = await admin
    .from("sc_cities")
    .select("city_code, name_en, name_zh, name_local, timezone, brief_enabled")
    .eq("city_code", cityCode)
    .maybeSingle();
  const city = cityRow as CityRow | null;
  if (!city) return json({ error: "city not found" }, 404);
  if (!city.brief_enabled) return json({ error: "brief not enabled for city" }, 409);

  const cityCtx: CityContext = {
    cityCode: city.city_code,
    nameEn: city.name_en,
    nameZh: city.name_zh,
    timezone: city.timezone,
  };

  const targets: CompileTarget[] = target === "both" ? ["events", "kit"] : [target];
  const outcomes: RunOutcome[] = [];

  for (const t of targets) {
    // 3. Cooldown check (unless forced).
    if (!force) {
      const recent = await recentSuccessfulRun(admin, cityCode, t);
      if (recent) {
        outcomes.push({
          target: t,
          status: "ok",
          searchCalls: 0,
          promptTokens: 0,
          outputTokens: 0,
          itemsWritten: 0,
          error: "cooldown",
          receipt: recent,
        });
        continue;
      }
    }

    const startedAt = new Date().toISOString();
    let outcome: RunOutcome;
    try {
      outcome =
        t === "events"
          ? await compileEvents(admin, cityCtx, tavilyKey, deepseekKey)
          : await compileKit(admin, cityCtx, tavilyKey, deepseekKey);
    } catch (err) {
      outcome = {
        target: t,
        status: "failed",
        searchCalls: 0,
        promptTokens: 0,
        outputTokens: 0,
        itemsWritten: 0,
        error: (err as Error).message,
      };
    }
    try {
      outcome.receipt = await writeRun(admin, cityCode, outcome, startedAt);
    } catch {
      return json({ error: "city brief accounting could not be persisted" }, 503);
    }
    outcomes.push(outcome);
  }

  return json({ city_code: cityCode, outcomes });
});

// ─── Cooldown ────────────────────────────────────────────────────────────────

async function recentSuccessfulRun(
  admin: SupabaseAdmin,
  cityCode: string,
  target: CompileTarget,
): Promise<RunReceipt | null> {
  const { data, error } = await admin
    .from("city_brief_runs")
    .select("id, city_code, target, status, items_written, started_at, finished_at")
    .eq("city_code", cityCode)
    .eq("target", target)
    .eq("status", "ok")
    .is("error", null)
    .order("finished_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) throw new Error("City brief accounting unavailable");
  if (!data) return null;
  const last = Date.parse(String(data.finished_at));
  if (!Number.isFinite(last) || Date.now() - last >= BRIEF_COOLDOWN_MS[target]) return null;
  try {
    validateBriefResponse(
      {
        city_code: cityCode,
        outcomes: [
          {
            target,
            status: "ok",
            searchCalls: 0,
            promptTokens: 0,
            outputTokens: 0,
            itemsWritten: 0,
            error: "cooldown",
            receipt: data,
          },
        ],
      },
      cityCode,
      target,
    );
    return data as RunReceipt;
  } catch {
    return null;
  }
}

// ─── Tavily ──────────────────────────────────────────────────────────────────

interface TavilyResult {
  title?: string;
  url?: string;
  content?: string;
}

async function runTavily(
  tavilyKey: string,
  queries: ReturnType<typeof tavilyQueries>,
): Promise<{ candidates: Candidate[]; calls: number }> {
  const now = new Date().toISOString();
  const byUrl = new Map<string, Candidate>();
  let calls = 0;
  let totalChars = 0;

  for (const q of queries) {
    if (byUrl.size >= MAX_CANDIDATES || totalChars >= MAX_CANDIDATE_CHARS) break;
    const payload: Record<string, unknown> = {
      query: q.query,
      search_depth: TAVILY_SEARCH_DEPTH,
      max_results: TAVILY_MAX_RESULTS,
      topic: q.topic ?? "general",
    };
    if (q.topic === "news" && q.days) payload.days = q.days;

    let res: Response;
    try {
      res = await fetch(TAVILY_URL, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${tavilyKey}`,
          "content-type": "application/json",
        },
        body: JSON.stringify(payload),
      });
    } catch {
      continue; // skip a failed query; others may still yield candidates
    }
    calls++;
    if (!res.ok) continue;
    const data = (await res.json()) as { results?: TavilyResult[] };
    for (const r of data.results ?? []) {
      const url = (r.url ?? "").trim();
      if (!url || byUrl.has(url)) continue;
      if (byUrl.size >= MAX_CANDIDATES || totalChars >= MAX_CANDIDATE_CHARS) break;
      const rawText = (r.content ?? "").slice(0, MAX_RAWTEXT_CHARS);
      totalChars += rawText.length;
      byUrl.set(url, {
        sourceId: "tavily",
        title: r.title ?? "",
        rawText,
        url,
        fetchedAt: now,
      });
    }
  }

  return { candidates: [...byUrl.values()], calls };
}

// ─── DeepSeek ────────────────────────────────────────────────────────────────

interface DeepSeekUsage {
  prompt_tokens: number;
  completion_tokens: number;
}

/** Built-in DeepSeek model, mapping legacy `DEEPSEEK_MODEL` ids forward. */
function resolveModelName(): string {
  return normalizeDeepSeekModel(Deno.env.get("DEEPSEEK_MODEL"));
}

async function callDeepSeek(
  deepseekKey: string,
  prompt: string,
): Promise<{ content: string; usage: DeepSeekUsage }> {
  const base = deepSeekBaseUrl(Deno.env.get("DEEPSEEK_BASE_URL"));
  const model = resolveModelName();
  const res = await fetch(`${base}/chat/completions`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${deepseekKey}`,
      "content-type": "application/json",
    },
    body: JSON.stringify(
      buildDeepSeekChatBody({
        model,
        max_tokens: DEEPSEEK_MAX_TOKENS,
        response_format: { type: "json_object" },
        messages: [{ role: "user", content: prompt }],
      }),
    ),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`deepseek ${res.status}: ${text.slice(0, 200)}`);
  }
  const jsonRes: unknown = await res.json();
  return { content: parseDeepSeekContent(jsonRes), usage: parseDeepSeekUsage(jsonRes) };
}

/** Call DeepSeek, parse JSON, retry once on unparseable output. */
async function deepSeekJSON(
  deepseekKey: string,
  prompt: string,
): Promise<{ parsed: Record<string, unknown> | null; usage: DeepSeekUsage }> {
  const first = await callDeepSeek(deepseekKey, prompt);
  let parsed = parseModelJSON(first.content);
  let usage = first.usage;
  if (parsed === null) {
    const retry = await callDeepSeek(
      deepseekKey,
      `${prompt}\n\nYour previous reply was not valid JSON. Reply with ONLY the JSON object.`,
    );
    parsed = parseModelJSON(retry.content);
    usage = {
      prompt_tokens: usage.prompt_tokens + retry.usage.prompt_tokens,
      completion_tokens: usage.completion_tokens + retry.usage.completion_tokens,
    };
  }
  return { parsed, usage };
}

// ─── Events compile ──────────────────────────────────────────────────────────

const DAY_MS = 24 * 60 * 60 * 1000;

async function compileEvents(
  admin: SupabaseAdmin,
  city: CityContext,
  tavilyKey: string,
  deepseekKey: string,
): Promise<RunOutcome> {
  const now = new Date();
  const queries = tavilyQueries(city, "events", {
    now,
    earliest: new Date(now.getTime() - DAY_MS),
    latest: new Date(now.getTime() + 21 * DAY_MS),
  });
  const { candidates, calls } = await runTavily(tavilyKey, queries);
  if (candidates.length === 0) {
    return {
      target: "events",
      status: "failed",
      searchCalls: calls,
      promptTokens: 0,
      outputTokens: 0,
      itemsWritten: 0,
      error: "no search candidates",
    };
  }

  const prompt = buildEventsPrompt(city, candidates);
  const { parsed, usage } = await deepSeekJSON(deepseekKey, prompt);
  if (parsed === null) {
    return {
      target: "events",
      status: "failed",
      searchCalls: calls,
      promptTokens: usage.prompt_tokens,
      outputTokens: usage.completion_tokens,
      itemsWritten: 0,
      error: "model returned invalid JSON",
    };
  }
  if (parsed["action"] === "refuse") {
    return {
      target: "events",
      status: "ok",
      searchCalls: calls,
      promptTokens: usage.prompt_tokens,
      outputTokens: usage.completion_tokens,
      itemsWritten: 0,
      error: "model refused",
    };
  }

  const candidateURLs = candidates.map((c) => c.url);
  const { accepted, rejected } = validateEvents(parsed["events"], candidateURLs, now);

  // Fetch existing active events for this city for ±2-day normalized-name dedup.
  const { data: existingRows, error: existingReadError } = await admin
    .from("city_events")
    .select("id, name, ends_at")
    .eq("city_code", city.cityCode)
    .eq("status", "active");
  if (existingReadError) {
    return {
      target: "events",
      status: "failed",
      searchCalls: calls,
      promptTokens: usage.prompt_tokens,
      outputTokens: usage.completion_tokens,
      itemsWritten: 0,
      error: "Existing event deduplication read failed",
    };
  }
  const existing = (existingRows ?? []) as Array<{ id: string; name: string; ends_at: string }>;

  const model = resolveModelName();
  const nowIso = now.toISOString();
  let written = 0;
  let writeFailures = 0;

  for (const ev of accepted) {
    const anchor = ev.startsAt ?? ev.endsAt;
    let id = eventId(city.cityCode, ev.name, anchor);

    // Secondary dedup: an existing active row with the same normalized name
    // within ±2 days is the SAME event → update it in place rather than insert.
    const norm = normalizeName(ev.name);
    const endMs = Date.parse(ev.endsAt);
    const twin = existing.find(
      (r) =>
        normalizeName(r.name) === norm && Math.abs(Date.parse(r.ends_at) - endMs) <= 2 * DAY_MS,
    );
    if (twin) id = twin.id;

    try {
      const { data: saved, error } = await admin
        .from("city_events")
        .upsert(
          {
            id,
            city_code: city.cityCode,
            name: ev.name,
            category: ev.category,
            when_label: ev.whenLabel,
            starts_at: ev.startsAt,
            ends_at: ev.endsAt,
            solo_score: ev.soloScore,
            solo_note: ev.soloNote,
            health: ev.health,
            seen_label: ev.seenLabel,
            limited_label: ev.limitedLabel,
            source_url: ev.sourceUrl,
            verified_at: nowIso,
            model_name: model,
            status: "active",
          },
          { onConflict: "id" },
        )
        .select("id");
      if (error || !Array.isArray(saved) || saved.length !== 1 || saved[0]?.id !== id) {
        writeFailures++;
      } else {
        written++;
      }
    } catch {
      writeFailures++;
    }
  }

  const status: RunOutcome["status"] =
    writeFailures > 0 || rejected.length > 0 ? (written > 0 ? "partial" : "failed") : "ok";

  return {
    target: "events",
    status,
    searchCalls: calls,
    promptTokens: usage.prompt_tokens,
    outputTokens: usage.completion_tokens,
    itemsWritten: written,
    ...(writeFailures > 0 ? { error: "One or more event writes were not confirmed" } : {}),
  };
}

// ─── Kit compile (re-verify) ─────────────────────────────────────────────────

async function compileKit(
  admin: SupabaseAdmin,
  city: CityContext,
  tavilyKey: string,
  deepseekKey: string,
): Promise<RunOutcome> {
  const now = new Date();

  // Existing kit rows are what we re-verify. If none exist, there is nothing to
  // confirm/update — kit content is seeded first, then re-verified here.
  const { data: kitRows, error: kitReadError } = await admin
    .from("city_kits")
    .select("section, name, body, lens_line, last_verified_at")
    .eq("city_code", city.cityCode);
  if (kitReadError) throw new Error("Existing kit read failed");
  const current = (kitRows ?? []) as Array<{
    section: KitSection;
    name: string;
    body: string;
    lens_line: string | null;
    last_verified_at: string | null;
  }>;

  if (current.length === 0) {
    return {
      target: "kit",
      status: "ok",
      searchCalls: 0,
      promptTokens: 0,
      outputTokens: 0,
      itemsWritten: 0,
      error: "no kit rows to verify (seed first)",
    };
  }

  const queries = tavilyQueries(city, "kit", {
    now,
    earliest: new Date(now.getTime() - DAY_MS),
    latest: new Date(now.getTime() + 21 * DAY_MS),
  });
  const { candidates, calls } = await runTavily(tavilyKey, queries);
  if (candidates.length === 0) {
    // Still run the 45-day downgrade sweep even without fresh candidates.
    let downgraded = 0;
    try {
      downgraded = await downgradeStaleKit(admin, city.cityCode, now);
    } catch {
      return {
        target: "kit",
        status: "failed",
        searchCalls: calls,
        promptTokens: 0,
        outputTokens: 0,
        itemsWritten: 0,
        error: "Stale kit downgrade was not confirmed",
      };
    }
    return {
      target: "kit",
      status: "partial",
      searchCalls: calls,
      promptTokens: 0,
      outputTokens: 0,
      itemsWritten: downgraded,
      error: "no search candidates",
    };
  }

  const prompt = buildKitPrompt(
    city,
    current.map((r) => ({
      section: r.section,
      name: r.name,
      body: r.body,
      lensLine: r.lens_line,
    })),
    candidates,
  );
  const { parsed, usage } = await deepSeekJSON(deepseekKey, prompt);
  if (parsed === null) {
    return {
      target: "kit",
      status: "failed",
      searchCalls: calls,
      promptTokens: usage.prompt_tokens,
      outputTokens: usage.completion_tokens,
      itemsWritten: 0,
      error: "model returned invalid JSON",
    };
  }

  const candidateURLs = candidates.map((c) => c.url);
  const { decisions, rejected } = validateKit(parsed["decisions"], candidateURLs);
  const model = resolveModelName();
  const nowIso = now.toISOString();
  let written = 0;
  let writeFailures = 0;

  for (const d of decisions) {
    if (d.action === "omit") continue;
    // Confirm preserves copy and links. Update never changes link_url.
    const patch: Record<string, unknown> =
      d.action === "confirm"
        ? { last_verified_at: nowIso, health: "green", model_name: model }
        : {
            name: d.name,
            body: d.body,
            lens_line: d.lensLine,
            health: d.health,
            last_verified_at: nowIso,
            model_name: model,
          };
    if (d.action === "update") {
      if (d.linkLabel != null) patch.link_label = d.linkLabel;
      if (Array.isArray(d.sources) && d.sources.length > 0) patch.sources = d.sources;
    }
    try {
      const { data: saved, error } = await admin
        .from("city_kits")
        .update(patch)
        .eq("city_code", city.cityCode)
        .eq("section", d.section)
        .select("city_code, section");
      if (
        error ||
        !Array.isArray(saved) ||
        saved.length !== 1 ||
        saved[0]?.city_code !== city.cityCode ||
        saved[0]?.section !== d.section
      ) {
        writeFailures++;
      } else {
        written++;
      }
    } catch {
      writeFailures++;
    }
  }

  // A sweep failure must not erase counts from earlier confirmed updates.
  try {
    written += await downgradeStaleKit(admin, city.cityCode, now);
  } catch {
    writeFailures++;
  }
  const status: RunOutcome["status"] =
    writeFailures > 0 || rejected.length > 0 ? (written > 0 ? "partial" : "failed") : "ok";
  return {
    target: "kit",
    status,
    searchCalls: calls,
    promptTokens: usage.prompt_tokens,
    outputTokens: usage.completion_tokens,
    itemsWritten: written,
    ...(writeFailures > 0 ? { error: "One or more kit writes were not confirmed" } : {}),
  };
}

async function downgradeStaleKit(
  admin: SupabaseAdmin,
  cityCode: string,
  now: Date,
): Promise<number> {
  const cutoff = new Date(now.getTime() - KIT_STALE_YELLOW_MS).toISOString();
  const { data, error } = await admin
    .from("city_kits")
    .update({ health: "yellow" })
    .eq("city_code", cityCode)
    .in("health", ["green"])
    .lt("last_verified_at", cutoff)
    .select("city_code, section");
  if (
    error ||
    !Array.isArray(data) ||
    data.some(
      (row) =>
        row.city_code !== cityCode || !["net", "money", "visa", "safety"].includes(row.section),
    )
  ) {
    throw new Error("Stale kit downgrade was not confirmed");
  }
  return data.length;
}

// ─── Run accounting ──────────────────────────────────────────────────────────

async function writeRun(
  admin: SupabaseAdmin,
  cityCode: string,
  outcome: RunOutcome,
  startedAt: string,
): Promise<RunReceipt> {
  const { data, error } = await admin
    .from("city_brief_runs")
    .insert({
      city_code: cityCode,
      target: outcome.target,
      status: outcome.status,
      search_calls: outcome.searchCalls,
      prompt_tokens: outcome.promptTokens,
      output_tokens: outcome.outputTokens,
      items_written: outcome.itemsWritten,
      error: outcome.error ?? null,
      started_at: startedAt,
      finished_at: new Date().toISOString(),
    })
    .select("id, city_code, target, status, items_written, started_at, finished_at")
    .single();
  if (error || !data) throw new Error("City brief accounting write failed");
  return data as RunReceipt;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

// Loose alias so we don't depend on supabase-js generic types in Deno.
type SupabaseAdmin = ReturnType<typeof createClient>;

function json(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "content-type": "application/json" },
  });
}
