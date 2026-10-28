/** Shared cron contract: no network, environment access or credential logging. */
export const BRIEF_CITY_CODES = ["vte"] as const;
export const BRIEF_COOLDOWN_MS = { events: 72 * 60 * 60 * 1000, kit: 240 * 60 * 60 * 1000 };
export type BriefTarget = "events" | "kit";
interface BriefInput {
  city_code: "vte";
  target: BriefTarget | "both";
  force: boolean;
}
function record(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
function reject(): never {
  throw new Error("Invalid or unsuccessful city brief contract");
}
export function authorizeBriefRequest(
  headers: Headers,
  serviceKey?: string,
  cronSecret?: string,
): boolean {
  const bearer = (headers.get("authorization") ?? "").match(/^Bearer (.+)$/i)?.[1];
  return Boolean(
    (serviceKey?.trim() && bearer === serviceKey) ||
    (cronSecret?.trim() && headers.get("x-cron-secret") === cronSecret),
  );
}
export function validateBriefInput(value: unknown): BriefInput {
  if (
    !record(value) ||
    !BRIEF_CITY_CODES.includes(value.city_code as "vte") ||
    typeof value.target !== "string" ||
    !["events", "kit", "both"].includes(value.target) ||
    (value.force !== undefined && typeof value.force !== "boolean")
  )
    reject();
  return {
    city_code: value.city_code as "vte",
    target: value.target as BriefInput["target"],
    force: value.force === true,
  };
}
export function validateBriefResponse(
  value: unknown,
  city: string,
  target: string,
  now = Date.now(),
): Array<{ target: BriefTarget; kind: "refreshed" | "cooldown"; itemsWritten: number }> {
  const input = validateBriefInput({ city_code: city, target });
  const expected: BriefTarget[] = input.target === "both" ? ["events", "kit"] : [input.target];
  if (
    !record(value) ||
    value.city_code !== city ||
    !Array.isArray(value.outcomes) ||
    value.outcomes.length !== expected.length
  )
    reject();
  const seen = new Set<string>();
  return value.outcomes.map((outcome: unknown) => {
    if (
      !record(outcome) ||
      outcome.status !== "ok" ||
      !expected.includes(outcome.target as BriefTarget) ||
      seen.has(String(outcome.target)) ||
      !Number.isSafeInteger(outcome.itemsWritten) ||
      Number(outcome.itemsWritten) < 0
    )
      reject();
    const t = outcome.target as BriefTarget;
    seen.add(t);
    const r = outcome.receipt;
    if (
      !record(r) ||
      typeof r.id !== "string" ||
      !r.id ||
      r.city_code !== city ||
      r.target !== t ||
      r.status !== "ok" ||
      !Number.isSafeInteger(r.items_written) ||
      Number(r.items_written) < 0 ||
      typeof r.started_at !== "string" ||
      typeof r.finished_at !== "string"
    )
      reject();
    const start = Date.parse(r.started_at);
    const finish = Date.parse(r.finished_at);
    if (
      !Number.isFinite(start) ||
      !Number.isFinite(finish) ||
      start > finish ||
      finish > now + 60_000
    )
      reject();
    const cooldown = outcome.error === "cooldown";
    if (outcome.error !== undefined && !cooldown) reject();
    if (
      cooldown
        ? outcome.itemsWritten !== 0 || now - finish >= BRIEF_COOLDOWN_MS[t]
        : outcome.itemsWritten !== r.items_written || now - finish > 10 * 60 * 1000
    )
      reject();
    return {
      target: t,
      kind: cooldown ? "cooldown" : "refreshed",
      itemsWritten: Number(outcome.itemsWritten),
    };
  });
}
