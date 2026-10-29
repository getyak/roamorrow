"use client";

import { useState } from "react";
import type { NearbyResult } from "@/app/api/experiences/nearby/route";
import { categoryLabel } from "@/lib/category";
import { healthColor, healthLabel } from "@/lib/health";
import { walkEstimate } from "@/lib/directions";
import { knownSoloScore } from "@/lib/solo-score-label";
import { TimelineList } from "@/components/TimelineList";

interface NearbySheetProps {
  readonly expanded: boolean;
  readonly results: readonly NearbyResult[];
  readonly loading: boolean;
  readonly degraded: boolean;
  readonly sampleMode: boolean;
  readonly offline: boolean;
  readonly selectedId: string | null;
  readonly onSelect: (id: string) => void;
  readonly error?: string;
  readonly onRetry: () => void;
  readonly onExpandedChange: (expanded: boolean) => void;
}

/** The first cards are usable without knowing that a bottom sheet can be dragged. */
export function NearbySheet({
  expanded,
  results,
  loading,
  degraded,
  sampleMode,
  offline,
  selectedId,
  onSelect,
  onExpandedChange,
  error,
  onRetry,
}: NearbySheetProps) {
  const [footprintTab, setFootprint] = useState(false);
  const footprint = expanded && footprintTab;
  const visible = expanded ? results : results.slice(0, 5);
  function setOpen(next: boolean) {
    if (!next) setFootprint(false);
    onExpandedChange(next);
  }
  return (
    <section
      aria-label="Nearby experiences and footprint"
      className={`nearby-panel ${expanded ? "nearby-panel-expanded" : ""}`}
    >
      <header className="nearby-heading flex shrink-0 flex-wrap items-center justify-between gap-x-2 px-4 py-2">
        <div>
          <h1 className="font-serif text-xl font-medium text-ink-warm">
            {footprint ? "My footprint" : sampleMode ? "Sample experiences" : "Things to do here"}
          </h1>
          {!footprint && results.length > 0 && (
            <p className="text-sm text-ink-warm/80">
              {sampleMode ? "Preview sample · not live data" : "Availability is not live."}
            </p>
          )}
        </div>
        <button
          type="button"
          aria-expanded={expanded}
          aria-controls="nearby-panel-content"
          className="min-h-11 rounded-full px-3 text-base font-medium text-deep-teal"
          onClick={() => setOpen(!expanded)}
        >
          {expanded ? "Back to map" : "See list"}
        </button>
      </header>
      <div
        id="nearby-panel-content"
        className="nearby-content min-h-0 overflow-y-auto overscroll-contain px-4 pb-4"
      >
        <div className="nearby-description flex flex-wrap items-center justify-between gap-x-3 py-2 text-sm text-ink-warm/80">
          <p>{footprint ? "Your saved visits" : "Choose a card for details and directions."}</p>
          <button
            type="button"
            aria-pressed={footprint}
            className="min-h-11 rounded-full px-2 text-deep-teal underline underline-offset-4"
            onClick={() => {
              setFootprint(!footprint);
              setOpen(true);
            }}
            hidden={!expanded}
          >
            {footprint ? "Nearby experiences" : "My footprint"}
          </button>
        </div>
        {!footprint && (
          <>
            {offline && (
              <p role="status" className="mb-3 text-base text-ink-warm">
                You are offline. Showing what already loaded; reconnect to refresh.
              </p>
            )}
            {error && (
              <div role="alert" className="mb-3 text-base text-ink-warm">
                <p>{error}</p>
                <Retry onRetry={onRetry} />
              </div>
            )}
            {loading && (
              <p role="status" className="py-3 text-base text-ink-warm">
                Loading experiences…
              </p>
            )}
            {!loading && !error && results.length === 0 && (
              <div className="py-3 text-base text-ink-warm" role="status">
                <p>No experiences found in this area.</p>
                <p className="mt-1 text-ink-warm/80">
                  Move the map or use your location to look somewhere else. Opening hours are not
                  verified.
                </p>
                <Retry onRetry={onRetry} />
              </div>
            )}
            {degraded && !sampleMode && (
              <p className="mb-3 text-sm text-ink-warm/80">
                AI ranking is unavailable. These choices use existing scores and distance.
              </p>
            )}
            {visible.length > 0 && (
              <ul className="nearby-choices" aria-label="Experience choices">
                {visible.map((result) => (
                  <li key={result.experience.id}>
                    <NearbyCard
                      result={result}
                      selected={result.experience.id === selectedId}
                      onSelect={onSelect}
                    />
                  </li>
                ))}
              </ul>
            )}
            {!expanded && results.length > 5 && (
              <p className="nearby-footnote pt-3 text-sm text-ink-warm/80">
                Showing 5 of {results.length} experiences. Open the list for more.
              </p>
            )}
            {results.length > 0 && (
              <p className="nearby-footnote pt-3 text-sm text-ink-warm/80">
                Check the best times and sources before you go. Availability is not live.
              </p>
            )}
          </>
        )}
        {footprint && <TimelineList onSelect={onSelect} />}
      </div>
    </section>
  );
}

function Retry({ onRetry }: { readonly onRetry: () => void }) {
  return (
    <button
      type="button"
      onClick={onRetry}
      className="mt-3 min-h-11 rounded-full bg-accent-interactive px-5 py-2 font-medium text-on-accent"
    >
      Try again
    </button>
  );
}

function NearbyCard({
  result,
  selected,
  onSelect,
}: {
  readonly result: NearbyResult;
  readonly selected: boolean;
  readonly onSelect: (id: string) => void;
}) {
  const exp = result.experience;
  const location = exp.location;
  const place =
    location.placeNameRomanized ||
    location.placeNameLocal ||
    location.addressHint ||
    location.cityCode;
  const score = knownSoloScore(exp.soloScore);
  return (
    <button
      type="button"
      data-experience-card={exp.id}
      onClick={() => onSelect(exp.id)}
      aria-pressed={selected}
      className={`nearby-card w-full text-left ${selected ? "nearby-card-selected" : ""}`}
    >
      <span className="block text-sm text-ink-warm/80">
        {categoryLabel[exp.category]} · {place}
      </span>
      <span className="nearby-card-title mt-1 block font-serif text-2xl font-medium leading-snug text-ink-warm">
        {exp.title}
      </span>
      <span className="mt-3 block text-sm text-ink-warm/80">
        {walkEstimate(result.walkingMinutes)}
      </span>
      <span className="mt-1 flex flex-wrap items-center gap-x-3 gap-y-1 text-sm text-ink-warm/80">
        <span>{score !== null ? `Solo score ${score}/10` : "Solo score not rated"}</span>
        <span className="inline-flex items-center gap-1.5">
          <span
            className="h-2 w-2 rounded-full"
            style={{ backgroundColor: healthColor[result.health] }}
            aria-hidden="true"
          />
          {healthLabel[result.health]}
        </span>
      </span>
      <span className="nearby-card-action mt-3 flex items-center gap-2 text-base font-medium text-deep-teal">
        Details &amp; directions
        <svg
          aria-hidden="true"
          width="18"
          height="18"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.5"
        >
          <path d="M4 12h16m-6-6 6 6-6 6" />
        </svg>
      </span>
    </button>
  );
}
