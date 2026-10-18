/**
 * Today banner — bounded-evidence copy (W02).
 *
 * The old banner asserted live facts ("Open right now", "open and
 * uncrowded", "safe after dark") that nothing in the data supports: the
 * ranking sees soloScore, traveler best-hour windows and walking minutes —
 * never live opening hours, crowd counts or safety. This module keeps the
 * real ranking and replaces the copy with statements the evidence can carry.
 *
 * No place timezone is inferred from the viewer’s device clock.
 */

import type { ExperienceCategory } from "@solo-compass/core";

export interface TodayCandidate {
  readonly experience: {
    readonly id: string;
    readonly title: string;
    readonly category: ExperienceCategory;
    readonly soloScore: { readonly overall: number };
    readonly bestTimes: readonly { readonly startHour: number; readonly endHour: number }[];
  };
  readonly walkingMinutes: number;
}

export interface TodayPick {
  readonly experience: TodayCandidate["experience"];
  readonly score: number;
  /** Always false until the data supplies a verified place timezone. */
  readonly fitsBestHours: boolean;
  /** Evidence badge shown on the chip — only real fields. */
  readonly evidence: string;
}

export interface TodayBrief {
  readonly headline: string;
  /** Clarifies what the ranking is (and is not) based on. */
  readonly basis: string;
  readonly picks: readonly TodayPick[];
}

/** No place timezone is available here: rank only known score and distance. */
export function buildTodayBrief(results: readonly TodayCandidate[]): TodayBrief {
  const basis =
    "Ranked by solo score and estimated walk time. Place-local best hours, opening hours and crowds are not verified.";
  const picks = results
    .map((r): TodayPick => ({
      experience: r.experience,
      score: r.experience.soloScore.overall * 10 - Math.min(15, r.walkingMinutes * 0.6),
      fitsBestHours: false,
      evidence: `solo ${r.experience.soloScore.overall.toFixed(1)} · ${Math.round(r.walkingMinutes)} min walk`,
    }))
    .sort((a, b) => b.score - a.score)
    .slice(0, 3);
  return { headline: picks.length ? "Nearby experiences worth a look" : "", basis, picks };
}
