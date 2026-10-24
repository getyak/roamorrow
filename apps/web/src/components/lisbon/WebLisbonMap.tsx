"use client";

/**
 * WebLisbonMap — pure SVG hand-drawn map for Scenario A (`/lisbon`).
 *
 * 1000 × 700 viewBox. Same DNA as the iOS map but darker by default to fit
 * the Linear/Arc software-tool aesthetic. Pin coordinates are in the same
 * canvas space (see `WebExperience.x` / `.y`).
 *
 * Not Mapbox. Not geographic. Editorial.
 */

import { useEffect, useRef, useState, type CSSProperties } from "react";
import { projectIllustratedPin } from "@/lib/illustrated-map";
import { WEB_CATS, type WebCategoryId, type WebExperience } from "@/lib/lisbon-data";
import type { WebCityMapConfig } from "@/lib/cities-data";

import { LISBON_MAP_CONFIG as LISBON_DEFAULT_MAP } from "@/lib/lisbon-map-config";

interface WebLisbonMapProps {
  readonly lang?: "zh" | "en";
  readonly pins: readonly WebExperience[];
  readonly hoverId?: string | null;
  readonly focusedId?: string | null;
  readonly onHover?: (id: string | null) => void;
  readonly onTap?: (id: string) => void;
  readonly dark?: boolean;
  readonly style?: CSSProperties;
  /** Optional per-city config; defaults to Lisbon for back-compat. */
  readonly mapConfig?: WebCityMapConfig;
  /** Live viewBox (zoom/pan) — defaults to the full illustrated canvas. */
  readonly viewBox?: string;
}

export function WebLisbonMap({
  lang = "zh",
  pins,
  hoverId = null,
  focusedId = null,
  onHover,
  onTap,
  dark = true,
  style,
  mapConfig = LISBON_DEFAULT_MAP,
  viewBox = "0 0 1000 700",
}: WebLisbonMapProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [viewport, setViewport] = useState({ width: 0, height: 0 });
  const interactive = Boolean(onTap);
  useEffect(() => {
    const container = containerRef.current;
    if (!container || !interactive) return;
    const measure = () => {
      const { width, height } = container.getBoundingClientRect();
      setViewport((previous) =>
        previous.width === width && previous.height === height ? previous : { width, height },
      );
    };
    measure();
    const observer = new ResizeObserver(measure);
    observer.observe(container);
    return () => observer.disconnect();
  }, [interactive]);

  const bg = dark ? "#1A1714" : "#F4ECDD";
  const water = dark ? "#221C16" : "#E6D8B6";
  const land = dark ? "#28221B" : "#EFE5CB";
  const street = dark ? "rgba(229,205,160,0.12)" : "rgba(93,48,0,0.16)";
  const streetMain = dark ? "rgba(229,205,160,0.22)" : "rgba(93,48,0,0.30)";
  const label = dark ? "rgba(229,205,160,0.55)" : "rgba(43,30,12,0.55)";
  const sub = dark ? "rgba(229,205,160,0.32)" : "rgba(43,30,12,0.32)";
  const dustOpacity = dark ? "rgba(229,205,160,0.025)" : "rgba(93,48,0,0.04)";
  const riverEdge = dark ? "rgba(229,205,160,0.25)" : "rgba(93,48,0,0.30)";
  const waveStroke = dark ? "rgba(229,205,160,0.10)" : "rgba(93,48,0,0.12)";
  const contour = dark ? "rgba(229,205,160,0.06)" : "rgba(93,48,0,0.08)";
  const tramStroke = dark ? "rgba(201,134,40,0.45)" : "rgba(201,134,40,0.55)";
  const pinHole = dark ? "#1A1714" : "#F4ECDD";

  const mapNotice =
    lang === "zh"
      ? "体验示意图 · 位置与步行时间仅作演示"
      : "Illustrated demo · locations and walk times are illustrative";

  return (
    <div
      ref={containerRef}
      role={interactive ? "group" : undefined}
      aria-label={interactive ? mapNotice : undefined}
      style={{ position: "relative", width: "100%", height: "100%", overflow: "hidden", ...style }}
    >
      <svg
        role={interactive ? undefined : "img"}
        aria-hidden={interactive ? true : undefined}
        aria-label={interactive ? undefined : mapNotice}
        viewBox={viewBox}
        preserveAspectRatio="xMidYMid slice"
        style={{
          width: "100%",
          height: "100%",
          display: "block",
          background: bg,
        }}
      >
        <defs>
          <radialGradient id="webMapVignette" cx="50%" cy="55%" r="65%">
            <stop offset="0%" stopColor={bg} stopOpacity="0" />
            <stop offset="100%" stopColor={bg} stopOpacity={dark ? 0.6 : 0.3} />
          </radialGradient>
          <pattern id="webPaper" width="3" height="3" patternUnits="userSpaceOnUse">
            <rect width="3" height="3" fill={bg} />
            <circle cx="1" cy="1" r="0.4" fill={dustOpacity} />
          </pattern>
        </defs>

        <rect width="1000" height="700" fill="url(#webPaper)" />

        {/* Water body (river / harbor) */}
        {mapConfig.riverPath && <path d={mapConfig.riverPath} fill={water} />}
        {mapConfig.riverEdgePath && (
          <path d={mapConfig.riverEdgePath} fill="none" stroke={riverEdge} strokeWidth="1" />
        )}

        {[0, 1, 2, 3, 4, 5, 6, 7, 8].map((i) => (
          <path
            key={i}
            d={`M ${50 + i * 110} ${640 + (i % 2) * 8} q 12 -3 24 0 t 24 0`}
            fill="none"
            stroke={waveStroke}
            strokeWidth="0.8"
          />
        ))}

        {/* Land overlay */}
        <path
          d="M -20 -20 L 1020 -20 L 1020 600 C 880 600, 720 580, 560 555 C 380 525, 200 500, -20 510 Z"
          fill={land}
          opacity="0.5"
        />

        {/* Av da Liberdade spine */}
        <path
          d="M 480 100 L 470 280 L 460 380"
          fill="none"
          stroke={streetMain}
          strokeWidth="3"
          strokeLinecap="round"
        />
        <path
          d="M 460 380 L 440 420 L 380 460"
          fill="none"
          stroke={streetMain}
          strokeWidth="2"
          strokeLinecap="round"
        />

        {/* Optional ribbon route (Lisbon: Tram 28; Porto: Dom Luís bridge) */}
        {mapConfig.ribbonPath && (
          <path
            d={mapConfig.ribbonPath}
            fill="none"
            stroke={tramStroke}
            strokeWidth="1.5"
            strokeDasharray="3 4"
            strokeLinecap="round"
          />
        )}

        <g stroke={street} strokeWidth="1" strokeLinecap="round" fill="none">
          <path d="M 200 200 L 720 220" />
          <path d="M 180 280 L 760 300" />
          <path d="M 220 340 L 740 360" />
          <path d="M 260 410 L 720 420" />
          <path d="M 300 470 L 700 470" />
          <path d="M 350 200 L 340 540" />
          <path d="M 420 180 L 410 540" />
          <path d="M 530 200 L 540 555" />
          <path d="M 600 180 L 620 545" />
          <path d="M 670 200 L 690 530" />
        </g>

        {/* Optional accent landmark (Lisbon: Castelo de São Jorge) */}
        {mapConfig.landmark && (
          <g transform={`translate(${mapConfig.landmark.x} ${mapConfig.landmark.y})`}>
            <path
              d={mapConfig.landmark.d}
              fill="none"
              stroke={label}
              strokeWidth="1.2"
              strokeLinejoin="round"
            />
          </g>
        )}

        {/* Optional concentric contour ellipses (hill behind landmark) */}
        {mapConfig.contour && (
          <g fill="none" stroke={contour} strokeWidth="0.8">
            {mapConfig.contour.radii.map((r, i) => (
              <ellipse
                key={i}
                cx={mapConfig.contour!.cx}
                cy={mapConfig.contour!.cy}
                rx={r.rx}
                ry={r.ry}
              />
            ))}
          </g>
        )}

        <rect width="1000" height="700" fill="url(#webMapVignette)" pointerEvents="none" />

        {/* Neighborhood labels */}
        {mapConfig.labels && mapConfig.labels.length > 0 && (
          <g
            style={{
              fontFamily: "JetBrains Mono, ui-monospace, monospace",
              fontSize: 9,
              letterSpacing: 1.5,
              textTransform: "uppercase",
              userSelect: "none",
            }}
          >
            {mapConfig.labels.map((l) => (
              <text
                key={`${l.text}-${l.x}-${l.y}`}
                x={l.x}
                y={l.y}
                fill={l.muted ? sub : label}
                textAnchor="middle"
              >
                {l.text}
              </text>
            ))}
          </g>
        )}

        {/* Pins */}
        {pins.map((p) => {
          const cat = WEB_CATS[p.cat as WebCategoryId];
          const isHover = hoverId === p.id;
          const isFocus = focusedId === p.id;
          const r = isFocus ? 8 : isHover ? 7 : 5;
          const ringR = isHover || isFocus ? 22 : 14;
          return (
            <g key={p.id} transform={`translate(${p.x} ${p.y})`}>
              {(isHover || isFocus) && (
                <circle r={ringR} fill={cat.color} opacity="0.18" className="sc-halo" />
              )}
              <circle r={r + 2} fill={pinHole} />
              <circle r={r} fill={cat.color} />
              {isFocus && (
                <circle r={r + 4} fill="none" stroke={cat.color} strokeWidth="1.2" opacity="0.7" />
              )}
            </g>
          );
        })}
      </svg>
      {onTap &&
        pins.map((p) => {
          const point = projectIllustratedPin(p.x, p.y, viewBox, viewport.width, viewport.height);
          if (
            !point ||
            viewport.width < 44 ||
            viewport.height < 44 ||
            point.left < 0 ||
            point.top < 0 ||
            point.left > viewport.width ||
            point.top > viewport.height
          )
            return null;
          return (
            <button
              key={p.id}
              type="button"
              className="illustrated-map-pin"
              aria-label={`${lang === "zh" ? p.titleZh : p.title} — ${lang === "zh" ? p.placeZh : p.place}, ${p.walkMin} ${lang === "zh" ? "分钟步行" : "min walk"}`}
              aria-pressed={focusedId === p.id}
              onClick={() => onTap(p.id)}
              onMouseEnter={() => onHover?.(p.id)}
              onMouseLeave={() => onHover?.(null)}
              onFocus={() => onHover?.(p.id)}
              onBlur={() => onHover?.(null)}
              style={{
                position: "absolute",
                left: Math.max(0, Math.min(viewport.width - 44, point.left - 22)),
                top: Math.max(0, Math.min(viewport.height - 44, point.top - 22)),
                width: 44,
                height: 44,
                padding: 0,
                border: 0,
                borderRadius: "50%",
                background: "transparent",
                cursor: "pointer",
              }}
            />
          );
        })}
      <span
        style={{
          position: "absolute",
          bottom: 12,
          left: 12,
          right: 12,
          width: "fit-content",
          maxWidth: "calc(100% - 24px)",
          padding: "5px 8px",
          borderRadius: 4,
          color: dark ? "#E5CDA0" : "#2B1E0C",
          background: dark ? "rgba(26,23,20,0.9)" : "rgba(244,236,221,0.9)",
          fontSize: 11,
          lineHeight: 1.4,
          pointerEvents: "none",
        }}
      >
        {mapNotice}
      </span>
    </div>
  );
}
