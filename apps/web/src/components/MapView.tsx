"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import mapboxgl, { type Map as MapboxMap, Marker } from "mapbox-gl";
import "mapbox-gl/dist/mapbox-gl.css";
import { distanceMeters } from "@solo-compass/core";
import type { NearbyResult } from "@/app/api/experiences/nearby/route";
import { healthColor, healthLabel } from "@/lib/health";
import { paperCreamStyle, paperPaint } from "@/lib/map-style";
import { clientEnv } from "@/lib/env";
import { isUsableMapboxToken } from "@/lib/map-token";
import { knownSoloScore } from "@/lib/solo-score-label";

const CHIANG_MAI_CENTER: [number, number] = [98.9853, 18.7883];
const DEFAULT_ZOOM = 14;
/** Refetch threshold — only ask the API again if the user panned this far. */
const REFETCH_PAN_METERS = 500;

interface MapViewProps {
  readonly results: readonly NearbyResult[];
  readonly onSelect: (id: string | null) => void;
  readonly selectedId: string | null;
  /** Called once on map ready and again whenever the user pans >500m. */
  readonly onCenterChange: (center: [number, number]) => void;
  /** Explains what data the list is showing when the basemap is unavailable. */
  readonly sampleMode: boolean;
}

export function MapView({
  results,
  onSelect,
  selectedId,
  onCenterChange,
  sampleMode,
}: MapViewProps) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<MapboxMap | null>(null);
  const markersRef = useRef<Map<string, Marker>>(new Map());
  const lastReportedCenterRef = useRef<[number, number] | null>(null);
  const [mapReady, setMapReady] = useState(false);
  /** Basemap unusable: missing/placeholder token or a runtime map error. */
  const [mapUnavailable, setMapUnavailable] = useState(false);
  const [locateState, setLocateState] = useState<"idle" | "locating" | "denied">("idle");
  /** Bumped by the honest retry action to rebuild the map after a runtime error. */
  const [mapEpoch, setMapEpoch] = useState(0);
  /** Monotonic id so geolocation callbacks from a previous mount are ignored. */
  const locateTokenRef = useRef(0);

  const usableToken = isUsableMapboxToken(clientEnv.NEXT_PUBLIC_MAPBOX_TOKEN);

  // Stable refs for handlers used inside map event listeners.
  const onCenterChangeRef = useRef(onCenterChange);
  const onSelectRef = useRef(onSelect);
  useEffect(() => {
    onCenterChangeRef.current = onCenterChange;
  }, [onCenterChange]);
  useEffect(() => {
    onSelectRef.current = onSelect;
  }, [onSelect]);

  const reportCenter = useCallback((center: [number, number]) => {
    const last = lastReportedCenterRef.current;
    if (last && distanceMeters(last, center) < REFETCH_PAN_METERS) return;
    lastReportedCenterRef.current = center;
    onCenterChangeRef.current(center);
  }, []);

  // The default sample centre must still load real list data even when the
  // basemap can't render.
  useEffect(() => {
    if (!usableToken) {
      reportCenter(CHIANG_MAI_CENTER);
    }
  }, [usableToken, reportCenter]);

  // ─── Mount the map (only with a plausible token) ─────────────────────────
  useEffect(() => {
    if (!usableToken || mapUnavailable || mapRef.current || !containerRef.current) return;

    mapboxgl.accessToken = clientEnv.NEXT_PUBLIC_MAPBOX_TOKEN;

    const map = new mapboxgl.Map({
      container: containerRef.current,
      style: paperCreamStyle,
      center: CHIANG_MAI_CENTER,
      zoom: DEFAULT_ZOOM,
      attributionControl: true,
    });

    map.addControl(new mapboxgl.NavigationControl({ showCompass: false }), "top-right");

    map.on("style.load", () => {
      for (const layer of map.getStyle()?.layers ?? []) {
        for (const [property, value] of paperPaint(layer)) {
          map.setPaintProperty(layer.id, property, value);
        }
      }
    });
    map.on("load", () => {
      setMapReady(true);
      const c = map.getCenter();
      reportCenter([c.lng, c.lat]);
    });
    map.on("idle", () => {
      const c = map.getCenter();
      reportCenter([c.lng, c.lat]);
    });
    // Runtime failures (bad style fetch, revoked token) must degrade to the
    // same honest fallback instead of leaving a permanent blank canvas — and
    // must still report the sample centre so the list keeps loading.
    map.on("error", (e) => {
      // eslint-disable-next-line no-console
      console.warn("mapbox runtime error:", e?.error?.message ?? e);
      reportCenter(CHIANG_MAI_CENTER);
      setMapReady(false);
      setMapUnavailable(true);
    });

    mapRef.current = map;

    return () => {
      markersRef.current.forEach((m) => m.remove());
      markersRef.current.clear();
      map.remove();
      mapRef.current = null;
      setMapReady(false);
    };
  }, [usableToken, mapUnavailable, mapEpoch, reportCenter]);

  // ─── Geolocation lifecycle guard (root review): unconditional ─────────────
  // The map-init effect above early-returns when no usable token exists, so
  // its cleanup never ran in the fallback path. This cleanup always runs on
  // unmount: bumping the token makes any in-flight geolocation callback stale
  // so it can never act on an unmounted surface.
  useEffect(() => {
    return () => {
      locateTokenRef.current += 1;
    };
  }, []);

  // When the basemap fails at runtime, tear the map down so the fallback
  // replaces it cleanly and "Try again" can re-initialise from scratch.
  useEffect(() => {
    if (!mapUnavailable) return;
    const map = mapRef.current;
    if (!map) return;
    markersRef.current.forEach((m) => m.remove());
    markersRef.current.clear();
    map.remove();
    mapRef.current = null;
    setMapReady(false);
  }, [mapUnavailable]);

  // ─── Explicit locate action only — never on mount ────────────────────────
  const handleLocate = useCallback(() => {
    if (!("geolocation" in navigator)) {
      setLocateState("denied");
      return;
    }
    const token = ++locateTokenRef.current;
    setLocateState("locating");
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        // Ignore late callbacks: the map may be gone or a newer request ran.
        if (token !== locateTokenRef.current) return;
        const center: [number, number] = [pos.coords.longitude, pos.coords.latitude];
        setLocateState("idle");
        const map = mapRef.current;
        if (map) {
          map.flyTo({
            center,
            zoom: DEFAULT_ZOOM,
            duration: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? 0 : 1500,
          });
        } else {
          reportCenter(center);
        }
      },
      () => {
        if (token !== locateTokenRef.current) return;
        setLocateState("denied");
      },
      { timeout: 5000, maximumAge: 60_000 },
    );
  }, [reportCenter]);

  // ─── Render markers when results change ───────────────────────────────────
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !mapReady) return;

    markersRef.current.forEach((m) => m.remove());
    markersRef.current.clear();

    for (const result of results) {
      const { experience: exp, health } = result;
      const isSelected = exp.id === selectedId;
      const score = knownSoloScore(exp.soloScore);

      const el = document.createElement("button");
      el.type = "button";
      el.setAttribute(
        "aria-label",
        `${exp.title}, ${score !== null ? `solo score ${score}` : "solo score not rated"}, ${healthLabel[health]}`,
      );
      el.className = [
        "relative flex h-11 w-11 items-center justify-center rounded-full",
        "bg-paper-cream/95 shadow-md ring-1 ring-ink-warm/15",
        "text-deep-teal",
        "cursor-pointer focus:outline-none focus:ring-2 focus:ring-deep-teal",
        isSelected ? "scale-125 ring-2 ring-warm-amber" : "",
      ].join(" ");

      // An authored map pin keeps the cartography quiet; the accessible name
      // carries the full experience and confidence, independent of the icon.
      const pin = document.createElementNS("http://www.w3.org/2000/svg", "svg");
      pin.setAttribute("viewBox", "0 0 24 24");
      pin.setAttribute("width", "24");
      pin.setAttribute("height", "24");
      pin.setAttribute("fill", "none");
      pin.setAttribute("stroke", "currentColor");
      pin.setAttribute("stroke-width", "1.5");
      pin.setAttribute("aria-hidden", "true");
      const outline = document.createElementNS("http://www.w3.org/2000/svg", "path");
      outline.setAttribute(
        "d",
        "M12 22s8-7.5 8-13a8 8 0 1 0-16 0c0 5.5 8 13 8 13Z M15 9a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z",
      );
      pin.appendChild(outline);
      el.appendChild(pin);

      // Solo-score badge (top-right)
      const badge = document.createElement("span");
      badge.textContent = score;
      badge.setAttribute("aria-hidden", "true");
      badge.className = [
        "absolute -top-1 -right-1 flex h-4 min-w-[1rem] items-center justify-center",
        "rounded-full bg-deep-teal px-1 text-[10px] font-semibold leading-none text-on-accent",
        "ring-1 ring-paper-cream",
      ].join(" ");
      if (score !== null) el.appendChild(badge);

      // Confidence dot (bottom-right)
      const dot = document.createElement("span");
      dot.setAttribute("aria-hidden", "true");
      dot.className =
        "absolute -bottom-0.5 -right-0.5 h-2.5 w-2.5 rounded-full ring-1 ring-paper-cream";
      dot.style.backgroundColor = healthColor[health];
      el.appendChild(dot);

      el.addEventListener("click", (event) => {
        event.stopPropagation();
        onSelectRef.current(exp.id);
      });

      const [lon, lat] = exp.location.coordinates;
      const marker = new mapboxgl.Marker({ element: el }).setLngLat([lon, lat]).addTo(map);
      markersRef.current.set(exp.id, marker);
    }
  }, [results, mapReady, selectedId]);

  // ─── Click on empty map dismisses ─────────────────────────────────────────
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !mapReady) return;
    const handler = () => onSelectRef.current(null);
    map.on("click", handler);
    return () => {
      map.off("click", handler);
    };
  }, [mapReady]);

  return (
    <div className="absolute inset-0 h-full w-full">
      {/* Real locate action — user-triggered geolocation only. */}
      <button
        type="button"
        onClick={handleLocate}
        disabled={locateState === "locating"}
        aria-label="Use my location"
        className="absolute right-3 top-3 z-10 flex h-11 w-11 items-center justify-center rounded-full bg-paper-cream/95 text-lg shadow-md ring-1 ring-ink-warm/15 disabled:opacity-60"
      >
        {locateState === "locating" ? (
          <span aria-hidden="true">…</span>
        ) : (
          <svg
            aria-hidden="true"
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.5"
          >
            <circle cx="12" cy="12" r="7" />
            <circle cx="12" cy="12" r="2" />
            <path d="M12 2v3m0 14v3M2 12h3m14 0h3" />
          </svg>
        )}
      </button>
      {locateState === "denied" && (
        <p
          role="status"
          className="absolute right-3 top-28 z-10 max-w-[260px] rounded-xl bg-paper-cream/95 p-3 text-base text-ink-warm shadow-md"
        >
          Location permission was declined. Move the map to explore another area.
        </p>
      )}

      {usableToken && !mapUnavailable ? (
        <div ref={containerRef} className="absolute inset-0 h-full w-full" />
      ) : (
        <MapUnavailableFallback
          sampleMode={sampleMode}
          resultCount={results.length}
          onRetry={
            usableToken
              ? () => {
                  // Honest recovery for a runtime map failure: rebuild the map.
                  setMapUnavailable(false);
                  setMapEpoch((e) => e + 1);
                }
              : undefined
          }
        />
      )}
    </div>
  );
}

function MapUnavailableFallback({
  sampleMode,
  resultCount,
  onRetry,
}: {
  readonly sampleMode: boolean;
  readonly resultCount: number;
  /** Present only when the failure is recoverable (token configured). */
  readonly onRetry?: () => void;
}) {
  return (
    <div className="absolute inset-x-0 top-[18dvh] flex flex-col items-center justify-center gap-3 bg-paper-cream px-6 text-center md:left-[404px] md:top-[30dvh]">
      {/* Quiet compass motif — decorative, hidden from assistive tech. */}
      <svg width="48" height="48" viewBox="0 0 96 96" fill="none" aria-hidden="true">
        <circle cx="48" cy="48" r="40" stroke="#C68E3F" strokeWidth="1.5" opacity="0.5" />
        <circle cx="48" cy="48" r="28" stroke="#C68E3F" strokeWidth="1" opacity="0.3" />
        <path d="M48 14 L54 48 L48 82 L42 48 Z" fill="#5D3000" opacity="0.6" />
      </svg>
      <h2 className="text-lg font-semibold text-ink-warm">Map imagery unavailable</h2>
      <p className="max-w-sm text-sm text-ink-warm/70">
        {sampleMode
          ? `The map background is unavailable. You can still explore ${resultCount} sample experiences in the list below.`
          : "The map background is unavailable. You can still use the experience cards."}
      </p>

      {onRetry && (
        <button
          type="button"
          onClick={onRetry}
          className="min-h-[44px] rounded-full bg-accent-interactive px-5 py-2 text-base font-medium text-on-accent shadow hover:bg-accent-interactive-hover"
        >
          Try loading the map again
        </button>
      )}
    </div>
  );
}
