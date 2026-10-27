import type { SoloScore } from "@solo-compass/core";

/** No reports means unknown, even when a provider stores a numeric zero. */
export function knownSoloScore(score: Pick<SoloScore, "overall" | "basedOnCount">): string | null {
  return score.basedOnCount > 0 && Number.isFinite(score.overall) ? score.overall.toFixed(1) : null;
}
