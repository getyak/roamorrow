/**
 * Footprint → detail resolution (W13).
 *
 * A completion ("footprint" entry) carries the FULL experience snapshot it
 * was recorded against. The old flow resolved selections only inside the
 * current nearby results, so a historical experience outside the current map
 * window silently did nothing. Resolution order is now:
 *   1. live nearby result (freshest ranking data),
 *   2. the completion's own snapshot (honest historical data),
 *   3. explicit "unavailable" — visible and recoverable, never a no-op.
 */

export interface SnapshotExperience {
  readonly id: string;
  readonly title: string;
}

export interface NearbyLike {
  readonly experience: { readonly id: string };
}

export type DetailResolution<TSnapshot extends SnapshotExperience> =
  | { readonly status: "nearby"; readonly experienceId: string }
  | { readonly status: "snapshot"; readonly experience: TSnapshot }
  | { readonly status: "unavailable"; readonly experienceId: string };

export function resolveDetail<TSnapshot extends SnapshotExperience>(
  experienceId: string,
  nearby: readonly NearbyLike[],
  snapshots: readonly TSnapshot[],
): DetailResolution<TSnapshot> {
  if (nearby.some((r) => r.experience.id === experienceId)) {
    return { status: "nearby", experienceId };
  }
  const snapshot = snapshots.find((s) => s.id === experienceId);
  if (snapshot) {
    return { status: "snapshot", experience: snapshot };
  }
  return { status: "unavailable", experienceId };
}
