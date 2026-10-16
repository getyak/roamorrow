/**
 * City research-view sorting (W11).
 *
 * The old sort control only changed its own highlight — the list order never
 * moved. Only real `WebExperience` fields may drive an order; where a real
 * reference doesn't exist (there is no user coordinate on the static city
 * pages) the option must not pretend. `distance` is therefore honestly
 * "walk time from the city centre" — the dataset's own `walkMin` field.
 */

import type { WebExperience } from "@/lib/lisbon-data";

export type SortMode = "curated" | "verified" | "walk";

export const SORT_MODES: readonly SortMode[] = ["curated", "verified", "walk"];

export function parseSortParam(raw: string | null | undefined): SortMode {
  if (raw === "verified" || raw === "walk") return raw;
  return "curated";
}

export function sortParamFor(mode: SortMode): string | null {
  return mode === "curated" ? null : mode;
}

/** Stable sort — ties keep curated order so the list never jumps around. */
export function applySort(
  experiences: readonly WebExperience[],
  mode: SortMode,
): readonly WebExperience[] {
  const indexed = experiences.map((exp, index) => ({ exp, index }));
  switch (mode) {
    case "curated":
      return experiences;
    case "verified":
      // Real field: `lastVerified` (ISO date) — most recently verified first.
      indexed.sort((a, b) => {
        const cmp = b.exp.lastVerified.localeCompare(a.exp.lastVerified);
        return cmp !== 0 ? cmp : a.index - b.index;
      });
      break;
    case "walk":
      // Real field: `walkMin` — walk time from the city centre reference.
      indexed.sort((a, b) => {
        const cmp = a.exp.walkMin - b.exp.walkMin;
        return cmp !== 0 ? cmp : a.index - b.index;
      });
      break;
  }
  return indexed.map((x) => x.exp);
}
