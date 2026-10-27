"use client";

import { useReducer, useRef } from "react";
import { Drawer } from "vaul";
import type { Experience, HealthStatus, TimeWindow } from "@solo-compass/core";
import { categoryEmoji, categoryLabel } from "@/lib/category";
import { healthColor, healthLabel } from "@/lib/health";
import { checkinReducer, initialCheckinState, ratingForSubmit } from "@/lib/checkin-state";
import { directionsUrl, walkEstimate } from "@/lib/directions";
import { knownSoloScore } from "@/lib/solo-score-label";

interface SheetResult {
  readonly experience: Experience;
  /** Absent when the pick came from the user's footprint (W13). */
  readonly health?: HealthStatus;
  readonly reason?: string;
  readonly walkingMinutes?: number;
  readonly fromFootprint?: boolean;
}

interface ExperienceSheetProps {
  readonly result: SheetResult | null;
  readonly sampleMode?: boolean;
  readonly onOpenChange: (open: boolean) => void;
  readonly onCheckin: (experienceId: string, rating?: number) => Promise<void> | void;
}

function formatDuration(d: Experience["durationMinutes"]): string {
  return d.min === d.max ? `${d.min} min` : `${d.min}–${d.max} min`;
}

function formatTimeWindow(t: TimeWindow): string {
  const window = `${String(t.startHour).padStart(2, "0")}:00–${String(t.endHour).padStart(2, "0")}:00`;
  return t.note ? `${window} (${t.note})` : window;
}

const DAY_NAMES = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"] as const;

export function ExperienceSheet({
  result,
  sampleMode = false,
  onOpenChange,
  onCheckin,
}: ExperienceSheetProps) {
  const open = result !== null;
  // W05/W06: rating is a selection; submit is explicit; a failed save keeps
  // the rating and shows a retry; success is only shown after acknowledgement.
  const openerRef = useRef<HTMLElement | null>(null);
  const [checkin, dispatch] = useReducer(checkinReducer, initialCheckinState);

  async function handleCheckin() {
    if (!result || checkin.status === "saving" || checkin.status === "success") return;
    dispatch({ type: "submit" });
    try {
      await onCheckin(result.experience.id, ratingForSubmit(checkin));
      dispatch({ type: "resolve" });
    } catch (err) {
      dispatch({
        type: "fail",
        message: err instanceof Error ? err.message : "Check-in failed",
      });
    }
  }

  return (
    <Drawer.Root open={open} onOpenChange={onOpenChange} shouldScaleBackground={false} autoFocus>
      <Drawer.Portal>
        <Drawer.Overlay className="fixed inset-0 z-30 bg-ink-warm/30 backdrop-blur-[2px]" />
        <Drawer.Content
          className="map-workspace fixed inset-x-0 bottom-0 z-40 flex max-h-[90dvh] flex-col rounded-t-2xl bg-paper-cream shadow-2xl outline-none md:left-auto md:right-4 md:w-[480px]"
          aria-describedby={undefined}
          onOpenAutoFocus={() => {
            openerRef.current =
              document.activeElement instanceof HTMLElement ? document.activeElement : null;
          }}
          onCloseAutoFocus={(event) => {
            event.preventDefault();
            if (openerRef.current?.isConnected) openerRef.current.focus();
          }}
        >
          <Drawer.Close asChild>
            <button
              type="button"
              aria-label="Close experience"
              className="absolute right-2 top-2 z-10 flex h-11 w-11 items-center justify-center rounded-full bg-paper-cream text-xl text-ink-warm hover:bg-ink-warm/10"
            >
              ×
            </button>
          </Drawer.Close>
          <div
            className="mx-auto mt-2 mb-1 h-1.5 w-12 rounded-full bg-ink-warm/20"
            aria-hidden="true"
          />
          {result ? (
            <SheetBody
              result={result}
              sampleMode={sampleMode}
              checkin={checkin}
              onRate={(r) => dispatch({ type: "rate", rating: r })}
              onCheckin={handleCheckin}
              onRetry={handleCheckin}
            />
          ) : null}
          {result && <Directions experience={result.experience} />}
        </Drawer.Content>
      </Drawer.Portal>
    </Drawer.Root>
  );
}

function SheetBody({
  result,
  sampleMode,
  checkin,
  onRate,
  onCheckin,
  onRetry,
}: {
  readonly result: SheetResult;
  readonly sampleMode: boolean;
  readonly checkin: ReturnType<typeof checkinReducer>;
  readonly onRate: (rating: number) => void;
  readonly onCheckin: () => void;
  readonly onRetry: () => void;
}) {
  const exp = result.experience;
  const score = knownSoloScore(exp.soloScore);
  const verifiedDate = new Date(exp.confidence.lastVerifiedAt);

  return (
    <div className="min-h-0 flex-1 overflow-y-auto px-5 pb-6 pt-3">
      <Drawer.Title className="sr-only">{exp.title}</Drawer.Title>
      {sampleMode && (
        <p className="mb-2 pr-10 text-sm font-medium text-deep-teal">
          Preview sample · not live data
        </p>
      )}
      <div className="mb-2 flex flex-wrap items-center gap-2 pr-10 text-sm font-medium text-deep-teal">
        <span className="text-base leading-none" aria-hidden="true">
          {categoryEmoji[exp.category]}
        </span>
        <span>{categoryLabel[exp.category]}</span>
        <span className="text-ink-warm/40">·</span>
        <span className="text-ink-warm/70">{formatDuration(exp.durationMinutes)}</span>
        {result.fromFootprint && (
          <>
            <span className="text-ink-warm/40">·</span>
            <span className="text-ink-warm/70">from your footprint</span>
          </>
        )}
      </div>

      <h2 className="mb-2 pr-10 text-xl font-semibold leading-snug text-ink-warm">{exp.title}</h2>
      <p className="mb-2 text-base text-ink-warm">
        {exp.location.placeNameRomanized ||
          exp.location.placeNameLocal ||
          exp.location.addressHint ||
          exp.location.cityCode}
      </p>
      <p className="mb-2 text-sm text-ink-warm/80">{walkEstimate(result.walkingMinutes)}</p>
      <p className="mb-4 text-base leading-relaxed text-ink-warm/80">{exp.oneLiner}</p>

      {result.reason && (
        <div className="mb-5 rounded-xl bg-paper-cream/60 p-3 ring-1 ring-ink-warm/10">
          <p className="text-sm italic leading-relaxed text-ink-warm/90">
            &ldquo;{result.reason}&rdquo;
          </p>
        </div>
      )}

      <Section title="Why it matters">
        <p className="text-sm leading-relaxed text-ink-warm/80">{exp.whyItMatters}</p>
      </Section>

      <Section title="How to">
        <ol className="space-y-1.5 text-sm leading-relaxed text-ink-warm/80">
          {exp.howTo.map((step) => (
            <li key={step.order} className="flex gap-2">
              <span className="flex-shrink-0 font-mono text-ink-warm/50">{step.order}.</span>
              <span>{step.text}</span>
            </li>
          ))}
        </ol>
      </Section>

      {exp.realInconveniences.length > 0 && (
        <Section title="Real inconveniences">
          <ul className="space-y-1.5 text-sm leading-relaxed text-ink-warm/80">
            {exp.realInconveniences.map((r, i) => (
              <li key={i} className="flex gap-2">
                <span className="text-ink-warm/50">•</span>
                <span>
                  <span className="text-sm font-medium text-ink-warm/80">{r.category}</span>{" "}
                  {r.text}
                </span>
              </li>
            ))}
          </ul>
        </Section>
      )}

      {exp.bestTimes.length > 0 && (
        <Section title="Best times">
          <ul className="space-y-1 text-sm text-ink-warm/80">
            {exp.bestTimes.map((t, i) => (
              <li key={i}>
                {formatTimeWindow(t)}
                {t.dayOfWeek && t.dayOfWeek.length > 0 && (
                  <span className="ml-1 text-ink-warm/60">
                    · {t.dayOfWeek.map((d) => DAY_NAMES[d]).join(", ")}
                  </span>
                )}
              </li>
            ))}
          </ul>
        </Section>
      )}

      <Section title="Solo score">
        <div className="flex items-baseline gap-2">
          {score !== null ? (
            <>
              <span className="text-2xl font-semibold text-ink-warm">{score}</span>
              <span className="text-sm text-ink-warm/80">
                / 10 · based on {exp.soloScore.basedOnCount} reports
              </span>
            </>
          ) : (
            <span className="text-base text-ink-warm/80">Not rated yet</span>
          )}
        </div>
        {exp.soloScore.hint && (
          <p className="mt-1 text-sm text-ink-warm/70">{exp.soloScore.hint}</p>
        )}
      </Section>

      <Section title="Confidence">
        <div className="flex items-center gap-2 text-sm text-ink-warm/80">
          {result.health ? (
            <>
              <span
                className="h-2.5 w-2.5 rounded-full"
                aria-hidden="true"
                style={{ backgroundColor: healthColor[result.health] }}
              />
              <span className="capitalize">{healthLabel[result.health]}</span>
            </>
          ) : (
            <span>From your saved footprint — no live confidence refresh.</span>
          )}
          <span className="text-ink-warm/50">·</span>
          <span className="text-ink-warm/60">
            verified {verifiedDate.toISOString().slice(0, 10)}
          </span>
        </div>
        <p className="mt-1 text-xs text-ink-warm/60">{exp.confidence.reason}</p>
      </Section>

      {exp.sources.length > 0 && (
        <Section title="Sources">
          <ul className="space-y-0.5 text-xs text-ink-warm/60">
            {exp.sources.map((s, i) => (
              <li key={i}>
                <span className="font-medium text-ink-warm/80">{s.type}</span>
                {s.attribution && <> · {s.attribution}</>}
                {s.url && (
                  <>
                    {" · "}
                    <a
                      className="inline-flex min-h-[44px] items-center text-deep-teal hover:underline"
                      href={s.url}
                      target="_blank"
                      rel="noopener noreferrer"
                    >
                      link
                    </a>
                  </>
                )}
              </li>
            ))}
          </ul>
        </Section>
      )}

      <CheckinControl checkin={checkin} onRate={onRate} onCheckin={onCheckin} onRetry={onRetry} />
    </div>
  );
}

function Directions({ experience }: { readonly experience: Experience }) {
  const href = directionsUrl(experience.location.coordinates);
  return (
    <div className="shrink-0 border-t border-ink-warm/15 bg-paper-cream px-5 py-3 pb-[max(12px,env(safe-area-inset-bottom))]">
      {href ? (
        <a
          href={href}
          target="_blank"
          rel="noopener noreferrer"
          className="flex min-h-12 items-center justify-center rounded-full bg-accent-interactive px-5 py-3 text-center text-base font-semibold text-on-accent"
        >
          Get walking directions
        </a>
      ) : (
        <p role="status" className="text-base text-ink-warm">
          Directions unavailable: this experience has no valid map coordinates.
        </p>
      )}
      <p className="mt-2 text-sm leading-snug text-ink-warm/80">
        Opens Google Maps in a new tab. Choose your starting point there; check the route and
        opening hours before leaving.
      </p>
    </div>
  );
}

function Section({
  title,
  children,
}: {
  readonly title: string;
  readonly children: React.ReactNode;
}) {
  return (
    <section className="mb-4">
      <h3 className="mb-1 text-base font-semibold text-ink-warm/80">{title}</h3>
      {children}
    </section>
  );
}

function CheckinControl({
  checkin,
  onRate,
  onCheckin,
  onRetry,
}: {
  readonly checkin: ReturnType<typeof checkinReducer>;
  readonly onRate: (rating: number) => void;
  readonly onCheckin: () => void;
  readonly onRetry: () => void;
}) {
  const busy = checkin.status === "saving";

  if (checkin.status === "success") {
    return (
      <div className="mt-2 rounded-xl bg-soft-green/30 px-4 py-3 text-center text-sm text-ink-warm">
        Marked as done{checkin.rating ? ` · ${checkin.rating}/5` : ""}. Thanks — this lifts the
        confidence dot.
      </div>
    );
  }

  return (
    <div className="mt-2 flex flex-col gap-3">
      {/* Rating is a selection (W06): 44px targets, explicit commit below. */}
      <fieldset className="flex flex-col gap-2">
        <legend className="text-xs text-ink-warm/60">
          Optional rating — pick one, then mark done:
        </legend>
        <div className="flex items-center justify-center gap-2">
          {[1, 2, 3, 4, 5].map((r) => (
            <button
              key={r}
              type="button"
              aria-pressed={checkin.rating === r}
              onClick={() => onRate(r)}
              disabled={busy}
              aria-label={`Rate ${r} out of 5`}
              className={[
                "flex h-11 w-11 items-center justify-center rounded-full text-base",
                "focus:outline-none focus:ring-2 focus:ring-deep-teal",
                checkin.rating === r
                  ? "bg-deep-teal text-on-accent"
                  : "hover:bg-ink-warm/10 text-ink-warm",
                busy ? "opacity-60" : "",
              ].join(" ")}
            >
              {r}
            </button>
          ))}
        </div>
      </fieldset>

      {checkin.status === "error" && (
        <div role="alert" className="rounded-xl bg-warm-amber/15 px-4 py-2 text-sm text-ink-warm">
          Could not save your check-in. Your rating is kept.
          <button
            type="button"
            onClick={onRetry}
            className="ml-2 inline-flex min-h-[44px] min-w-[44px] items-center justify-center underline"
            disabled={busy}
          >
            Retry
          </button>
        </div>
      )}

      <button
        type="button"
        onClick={onCheckin}
        disabled={busy}
        aria-busy={busy}
        className="w-full min-h-[44px] rounded-xl bg-deep-teal py-3 text-sm font-semibold text-on-accent transition hover:bg-deep-teal/90 disabled:opacity-60"
      >
        {busy ? "Saving…" : checkin.rating ? `I did this · ${checkin.rating}/5` : "I did this"}
      </button>
    </div>
  );
}
