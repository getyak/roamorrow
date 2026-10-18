"use client";

import { useMemo, useState } from "react";
import type { NearbyResult } from "@/app/api/experiences/nearby/route";
import { categoryEmoji } from "@/lib/category";
import { buildTodayBrief } from "@/lib/today-copy";

interface TodayBannerProps {
  readonly results: readonly NearbyResult[];
  readonly onSelect: (experienceId: string) => void;
}

/**
 * Dismissable evidence-bound picks under the top controls. Uses only client data — no extra API call.
 * Dismissal persists for the session via sessionStorage.
 */
export function TodayBanner({ results, onSelect }: TodayBannerProps) {
  const [dismissed, setDismissed] = useState(() => readDismissed());

  // W02: the brief ranks by real evidence and the copy claims nothing live.
  const { headline, basis, picks } = useMemo(() => buildTodayBrief(results), [results]);

  if (dismissed) return null;
  if (picks.length === 0) return null;

  const handleDismiss = () => {
    setDismissed(true);
    writeDismissed();
  };

  return (
    <div className="pointer-events-none absolute inset-x-0 top-12 z-10 flex justify-center px-3">
      <div className="pointer-events-auto relative w-full max-w-xl rounded-2xl bg-paper-cream/95 px-3 py-2 text-ink-warm shadow-sm ring-1 ring-ink-warm/10 backdrop-blur-md">
        <div className="min-w-0 flex-1">
          <p className="flex min-h-[36px] items-center pr-10 text-sm font-medium leading-snug">
            {headline}
          </p>
          <p className="hidden text-xs leading-snug text-ink-warm/70 sm:block">{basis}</p>
          <ul className="mt-1 flex gap-2 overflow-x-auto pb-1">
            {picks.map((p) => (
              <li key={p.experience.id} className="min-w-[220px] flex-1">
                <button
                  type="button"
                  onClick={() => onSelect(p.experience.id)}
                  className="flex min-h-[56px] w-full flex-wrap items-center gap-x-2 rounded-xl bg-ink-warm/5 px-3 py-2 text-left text-xs font-medium text-ink-warm transition hover:bg-ink-warm/10"
                >
                  <span aria-hidden="true">{categoryEmoji[p.experience.category]}</span>
                  <span className="min-w-0 flex-1 truncate">{p.experience.title}</span>
                  <span className="block w-full pl-5 text-ink-warm/70">{p.evidence}</span>
                </button>
              </li>
            ))}
          </ul>
        </div>
        <button
          type="button"
          onClick={handleDismiss}
          aria-label="Dismiss today's picks"
          className="absolute right-1 top-1 flex h-11 w-11 items-center justify-center rounded-full text-ink-warm/70 transition hover:bg-ink-warm/10 hover:text-ink-warm"
        >
          ×
        </button>
      </div>
    </div>
  );
}

const STORAGE_KEY = "sc_today_banner_dismissed";

function readDismissed(): boolean {
  if (typeof window === "undefined") return false;
  try {
    return sessionStorage.getItem(STORAGE_KEY) === "1";
  } catch {
    return false;
  }
}

function writeDismissed() {
  if (typeof window === "undefined") return;
  try {
    sessionStorage.setItem(STORAGE_KEY, "1");
  } catch {
    // sessionStorage blocked — fall back to in-memory state.
  }
}
