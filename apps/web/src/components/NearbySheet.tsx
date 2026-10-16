"use client";

import { useMemo, useRef, useState } from "react";
import type { NearbyResult } from "@/app/api/experiences/nearby/route";
import { categoryEmoji, categoryLabel } from "@/lib/category";
import { healthColor, healthLabel } from "@/lib/health";
import { TimelineList } from "@/components/TimelineList";

export type SheetTab = "nearby" | "timeline";

interface NearbySheetProps {
  readonly cityName: string;
  readonly results: readonly NearbyResult[];
  readonly loading: boolean;
  readonly degraded: boolean;
  readonly offline: boolean;
  readonly selectedId: string | null;
  readonly onSelect: (id: string) => void;
  readonly error?: string;
  readonly onRetry?: () => void;
  readonly onExpandedChange?: (expanded: boolean) => void;
}

// Three snap points: peek (collapsed pill, ~120px), mid (half), full (95%).
type PanelLevel = "peek" | "half" | "full";

export function NearbySheet({
  cityName,
  results,
  loading,
  degraded,
  offline,
  selectedId,
  onSelect,
  onExpandedChange,
  error,
  onRetry,
}: NearbySheetProps) {
  const [level, setLevel] = useState<PanelLevel>("peek");
  const dragStart = useRef<number | null>(null);
  const dragged = useRef(false);
  function setPanelLevel(next: PanelLevel) {
    setLevel(next);
    onExpandedChange?.(next !== "peek");
  }
  const [tab, setTab] = useState<SheetTab>("nearby");

  const isPeek = level === "peek";

  return (
    <section
      aria-label="Nearby experiences and footprint"
      className="fixed inset-x-0 bottom-0 z-20 mx-auto flex max-h-[95dvh] flex-col rounded-t-2xl bg-paper-cream shadow-2xl ring-1 ring-ink-warm/10 transition-[height] duration-200 motion-reduce:transition-none"
      style={{ height: level === "peek" ? 120 : level === "half" ? "55dvh" : "95dvh" }}
    >
      {/* Drag handle — 44pt target with expand/collapse semantics (W09). */}
      <button
        type="button"
        onClick={() => {
          if (dragged.current) {
            dragged.current = false;
            return;
          }
          setPanelLevel(isPeek ? "half" : "peek");
        }}
        onPointerDown={(event) => {
          dragged.current = false;
          dragStart.current = event.clientY;
          event.currentTarget.setPointerCapture(event.pointerId);
        }}
        onPointerUp={(event) => {
          if (dragStart.current !== null) {
            const delta = event.clientY - dragStart.current;
            dragged.current = Math.abs(delta) > 30;
            if (delta < -30) setPanelLevel(level === "peek" ? "half" : "full");
            else if (delta > 30) setPanelLevel(level === "full" ? "half" : "peek");
          }
          dragStart.current = null;
        }}
        onPointerCancel={() => {
          dragStart.current = null;
        }}
        onKeyDown={(event) => {
          if (event.key === "Enter" || event.key === " ") dragged.current = false;
          if (event.key === "ArrowUp") {
            event.preventDefault();
            setPanelLevel(level === "peek" ? "half" : "full");
          }
          if (event.key === "ArrowDown" || event.key === "Escape") {
            event.preventDefault();
            setPanelLevel("peek");
          }
        }}
        style={{ touchAction: "none" }}
        aria-controls="nearby-panel-content"
        className="mx-auto mt-2 mb-1 flex min-h-[44px] w-24 flex-shrink-0 cursor-grab items-center justify-center"
        aria-label={isPeek ? "Expand nearby list" : "Collapse nearby list"}
        aria-expanded={!isPeek}
      >
        <span className="h-1.5 w-12 rounded-full bg-ink-warm/30" aria-hidden="true" />
      </button>

      <PeekHeader
        cityName={cityName}
        results={results}
        loading={loading}
        degraded={degraded}
        offline={offline}
        isPeek={isPeek}
        onExpand={() => setPanelLevel("half")}
      />

      {!isPeek && (
        <div
          role="tablist"
          aria-label="Nearby and footprint"
          className="flex flex-shrink-0 border-b border-ink-warm/10 px-4"
        >
          <TabButton active={tab === "nearby"} onClick={() => setTab("nearby")}>
            Nearby {results.length > 0 ? `· ${results.length}` : ""}
          </TabButton>
          <TabButton active={tab === "timeline"} onClick={() => setTab("timeline")}>
            My footprint
          </TabButton>
        </div>
      )}

      {!isPeek && (
        <div
          id="nearby-panel-content"
          className="flex-1 overflow-y-auto overscroll-contain px-4 pb-8 pt-2"
        >
          {tab === "nearby" && error ? (
            <div role="alert" className="p-4 text-sm text-ink-warm">
              {error}
              <button
                type="button"
                onClick={onRetry}
                className="mt-3 block min-h-[44px] rounded-full bg-deep-teal px-5 py-2 text-paper-cream"
              >
                Try again
              </button>
            </div>
          ) : tab === "nearby" ? (
            <NearbyList
              results={results}
              loading={loading}
              degraded={degraded}
              offline={offline}
              selectedId={selectedId}
              onSelect={onSelect}
            />
          ) : (
            <TimelineList onSelect={onSelect} />
          )}
        </div>
      )}
    </section>
  );
}

function PeekHeader({
  cityName,
  results,
  loading,
  degraded,
  offline,
  isPeek,
  onExpand,
}: {
  readonly cityName: string;
  readonly results: readonly NearbyResult[];
  readonly loading: boolean;
  readonly degraded: boolean;
  readonly offline: boolean;
  readonly isPeek: boolean;
  readonly onExpand: () => void;
}) {
  const count = results.length;

  return (
    <button
      type="button"
      onClick={onExpand}
      className="flex min-h-[44px] flex-shrink-0 items-center gap-3 px-5 pb-3 pt-1 text-left"
      aria-expanded={!isPeek}
      aria-label={isPeek ? "Show the experience list" : "Experience list is open"}
    >
      <span className="text-base" aria-hidden="true">
        📍
      </span>
      <span className="text-sm font-medium text-ink-warm">{cityName}</span>
      <span className="text-ink-warm/40">·</span>
      {loading && count === 0 ? (
        <span className="text-sm text-ink-warm/60">looking…</span>
      ) : offline ? (
        <span className="text-sm text-ink-warm/60">offline · showing what loaded</span>
      ) : count === 0 ? (
        <span className="text-sm text-ink-warm/60">no experiences nearby</span>
      ) : (
        <span className="text-sm text-ink-warm">
          {count} experience{count === 1 ? "" : "s"} nearby
        </span>
      )}
      {isPeek && <span className="ml-auto text-xs text-ink-warm/50">show list ↑</span>}
    </button>
  );
}

function TabButton({
  active,
  onClick,
  children,
}: {
  readonly active: boolean;
  readonly onClick: () => void;
  readonly children: React.ReactNode;
}) {
  return (
    <button
      type="button"
      role="tab"
      aria-selected={active}
      onClick={onClick}
      className={[
        "relative min-h-[44px] px-4 py-3 text-sm font-medium transition",
        active ? "text-deep-teal" : "text-ink-warm/60 hover:text-ink-warm",
      ].join(" ")}
    >
      {children}
      {active && (
        <span
          className="absolute inset-x-3 bottom-0 h-0.5 rounded-full bg-deep-teal"
          aria-hidden="true"
        />
      )}
    </button>
  );
}

function NearbyList({
  results,
  loading,
  degraded,
  offline,
  selectedId,
  onSelect,
}: {
  readonly results: readonly NearbyResult[];
  readonly loading: boolean;
  readonly degraded: boolean;
  readonly offline: boolean;
  readonly selectedId: string | null;
  readonly onSelect: (id: string) => void;
}) {
  const grouped = useMemo(() => groupByWalkBand(results), [results]);

  if (loading && results.length === 0) {
    return <EmptyState>Looking around you…</EmptyState>;
  }
  if (results.length === 0) {
    return (
      <EmptyState>
        {offline
          ? "You're offline, and nothing was loaded yet. Reconnect and move the map to refresh."
          : degraded
            ? "Sample data only — the ranking service isn't reachable here. Move the map to try again."
            : "Nothing nearby here. Try moving the map."}
      </EmptyState>
    );
  }

  return (
    <div className="space-y-5">
      {grouped.map(({ label, items }) => (
        <section key={label}>
          <h3 className="mb-2 text-xs font-semibold uppercase tracking-wider text-ink-warm/50">
            {label}
          </h3>
          <ul className="space-y-2">
            {items.map((r) => (
              <li key={r.experience.id}>
                <NearbyCard
                  result={r}
                  selected={r.experience.id === selectedId}
                  onSelect={onSelect}
                />
              </li>
            ))}
          </ul>
        </section>
      ))}
    </div>
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
  return (
    <button
      type="button"
      onClick={() => onSelect(exp.id)}
      className={[
        "flex w-full items-start gap-3 rounded-xl p-3 text-left ring-1 transition",
        selected
          ? "bg-warm-amber/10 ring-2 ring-warm-amber"
          : "bg-paper-cream/70 ring-ink-warm/10 hover:bg-paper-cream hover:ring-ink-warm/20",
      ].join(" ")}
    >
      <span className="text-2xl leading-none" aria-hidden="true">
        {categoryEmoji[exp.category]}
      </span>
      <div className="min-w-0 flex-1">
        <div className="flex items-baseline justify-between gap-2">
          <h4 className="truncate text-sm font-semibold text-ink-warm">{exp.title}</h4>
          <span className="flex-shrink-0 text-xs font-semibold text-deep-teal">
            {exp.soloScore.overall.toFixed(1)}
          </span>
        </div>
        <p className="mt-0.5 truncate text-xs text-ink-warm/70">{exp.oneLiner}</p>
        <div className="mt-1.5 flex items-center gap-2 text-[11px] text-ink-warm/60">
          <span>{categoryLabel[exp.category]}</span>
          <span className="text-ink-warm/30">·</span>
          <span>{result.walkingMinutes} min walk</span>
          <span className="text-ink-warm/30">·</span>
          <span className="flex items-center gap-1">
            <span
              className="h-1.5 w-1.5 rounded-full"
              style={{ backgroundColor: healthColor[result.health] }}
              aria-hidden="true"
            />
            {healthLabel[result.health]}
          </span>
        </div>
      </div>
    </button>
  );
}

function EmptyState({ children }: { readonly children: React.ReactNode }) {
  return (
    <div className="flex h-32 items-center justify-center text-sm text-ink-warm/50">{children}</div>
  );
}

interface Group {
  readonly label: string;
  readonly items: readonly NearbyResult[];
}

function groupByWalkBand(results: readonly NearbyResult[]): readonly Group[] {
  const close: NearbyResult[] = [];
  const mid: NearbyResult[] = [];
  const far: NearbyResult[] = [];
  for (const r of results) {
    if (r.walkingMinutes < 5) close.push(r);
    else if (r.walkingMinutes < 15) mid.push(r);
    else far.push(r);
  }
  const groups: Group[] = [];
  if (close.length > 0) groups.push({ label: "Within 5 min", items: close });
  if (mid.length > 0) groups.push({ label: "5–15 min walk", items: mid });
  if (far.length > 0) groups.push({ label: "15+ min walk", items: far });
  return groups;
}
