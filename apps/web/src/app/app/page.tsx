"use client";

import { Suspense, useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useSearchParams } from "next/navigation";
import type { Experience } from "@solo-compass/core";
import { MapView } from "@/components/MapView";
import { MapLoading } from "@/components/MapLoading";
import { ExperienceSheet } from "@/components/ExperienceSheet";
import { NearbySheet } from "@/components/NearbySheet";
import { VoiceIntent } from "@/components/VoiceIntent";
import { TodayBanner } from "@/components/TodayBanner";
import { useNearby } from "@/lib/use-nearby";
import { useCompletions } from "@/lib/use-completions";
import { resolveDetail } from "@/lib/detail-resolution";
import { track } from "@/lib/analytics";
import { useQueryClient } from "@tanstack/react-query";

/**
 * Selection state (W13): a pick can come from the live nearby list or from
 * the user's footprint, whose entries carry a full experience snapshot.
 * Unresolvable ids surface as a visible, recoverable notice — never a
 * silent no-op.
 */
type Selection =
  | { readonly kind: "nearby"; readonly experienceId: string }
  | { readonly kind: "snapshot"; readonly experience: Experience }
  | { readonly kind: "unavailable"; readonly experienceId: string };

function HomeInner() {
  const [center, setCenter] = useState<[number, number] | null>(null);
  const [nearbyExpanded, setNearbyExpanded] = useState(false);
  const [intent, setIntent] = useState<string | null>(null);
  const [selection, setSelection] = useState<Selection | null>(null);
  const [online, setOnline] = useState(true);
  useEffect(() => {
    const update = () => setOnline(navigator.onLine);
    update();
    window.addEventListener("online", update);
    window.addEventListener("offline", update);
    return () => {
      window.removeEventListener("online", update);
      window.removeEventListener("offline", update);
    };
  }, []);
  const queryClient = useQueryClient();
  const searchParams = useSearchParams();

  const { data, isLoading, isError, refetch } = useNearby({ center, intent: intent ?? undefined });
  const { data: completions } = useCompletions();
  const results = data?.results ?? [];
  const sampleMode = data?.source === "sample";

  const snapshots = useMemo(
    () => (completions?.entries ?? []).map((e) => e.experience),
    [completions],
  );

  // Deep link: /app?experience=<id> selects that experience once data lands
  // (used by the city guide and experience detail pages — W16).
  const appliedDeepLink = useRef(false);
  useEffect(() => {
    if (appliedDeepLink.current) return;
    const wanted = searchParams.get("experience");
    if (!wanted) return;
    if (results.length === 0 && snapshots.length === 0) return;
    appliedDeepLink.current = true;
    const r = resolveDetail(wanted, results, snapshots);
    if (r.status === "unavailable") {
      setSelection({ kind: "unavailable", experienceId: wanted });
    } else if (r.status === "snapshot") {
      setSelection({ kind: "snapshot", experience: r.experience });
    } else {
      setSelection({ kind: "nearby", experienceId: wanted });
    }
  }, [searchParams, results, snapshots]);

  const selectedResult = useMemo(() => {
    if (selection?.kind !== "nearby") return null;
    return results.find((r) => r.experience.id === selection.experienceId) ?? null;
  }, [results, selection]);

  const handleSelect = useCallback(
    (id: string | null) => {
      if (!id) {
        setSelection(null);
        return;
      }
      const r = resolveDetail(id, results, snapshots);
      if (r.status === "unavailable") {
        setSelection({ kind: "unavailable", experienceId: id });
        return;
      }
      if (r.status === "snapshot") {
        setSelection({ kind: "snapshot", experience: r.experience });
        return;
      }
      setSelection({ kind: "nearby", experienceId: id });
      const found = results.find((x) => x.experience.id === id);
      if (found) {
        track({
          name: "marker_view",
          props: { experienceId: id, category: found.experience.category },
        });
        track({
          name: "sheet_open",
          props: { experienceId: id, category: found.experience.category },
        });
      }
    },
    [results, snapshots],
  );

  const handleIntentChange = useCallback((next: string | null) => {
    setIntent(next);
    if (next) {
      track({ name: "intent_set", props: { length: next.length, source: "voice" } });
    }
  }, []);

  const handleCheckin = useCallback(
    async (experienceId: string, rating?: number) => {
      const res = await fetch(`/api/experiences/${experienceId}/checkin`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(rating ? { rating } : {}),
      });
      if (!res.ok) throw new Error("Could not save your check-in. Your rating is kept; try again.");
      track({ name: "checkin", props: { experienceId, rated: rating !== undefined } });
      // Refresh the footprint timeline so the new entry shows up immediately.
      void queryClient.invalidateQueries({ queryKey: ["me", "completions"] });
    },
    [queryClient],
  );

  return (
    <main id="main" className="relative h-dvh w-full overflow-hidden bg-paper-cream">
      <MapView
        results={results}
        onSelect={handleSelect}
        selectedId={selection?.kind === "nearby" ? selection.experienceId : null}
        onCenterChange={setCenter}
        sampleMode={sampleMode}
      />

      <TodayBanner results={results} onSelect={handleSelect} />

      <VoiceIntent
        intent={intent}
        onIntentChange={handleIntentChange}
        hidden={nearbyExpanded || selection !== null}
        fallbackNotice={
          intent && data?.degraded
            ? sampleMode
              ? "This preview shows sample experiences; your request has not been ranked by AI."
              : "AI ranking is unavailable; showing nearby picks by score and distance."
            : undefined
        }
      />

      <ExperienceSheet
        key={
          selection?.kind === "snapshot"
            ? `snap-${selection.experience.id}`
            : (selectedResult?.experience.id ?? "none")
        }
        result={
          selectedResult ??
          (selection?.kind === "snapshot"
            ? {
                experience: selection.experience,
                health: undefined,
                reason: undefined,
                walkingMinutes: undefined,
                fromFootprint: true,
              }
            : null)
        }
        onOpenChange={(open) => !open && setSelection(null)}
        onCheckin={handleCheckin}
      />

      {selection?.kind === "unavailable" && (
        <div
          role="status"
          className="absolute inset-x-4 top-20 z-30 mx-auto max-w-md rounded-xl bg-paper-cream/95 p-4 text-sm text-ink-warm shadow-lg"
        >
          That experience isn&apos;t available right now (id: {selection.experienceId}). It may have
          moved out of range — try another pick from the list.
          <button
            type="button"
            onClick={() => setSelection(null)}
            className="mt-2 block min-h-[44px] w-full rounded-full bg-deep-teal px-4 py-2 font-medium text-paper-cream"
          >
            Back to the map
          </button>
        </div>
      )}

      <NearbySheet
        cityName={sampleMode ? "Sample picks" : center ? "Here" : "Loading…"}
        results={results}
        loading={isLoading || center === null}
        degraded={data?.degraded === true}
        offline={!online}
        selectedId={selection?.kind === "nearby" ? selection.experienceId : null}
        onSelect={handleSelect}
        error={
          isError ? "Could not load experiences. Check your connection and try again." : undefined
        }
        onRetry={() => {
          void refetch();
        }}
        onExpandedChange={setNearbyExpanded}
      />
    </main>
  );
}

export default function Home() {
  return (
    <Suspense fallback={<MapLoading />}>
      <HomeInner />
    </Suspense>
  );
}
