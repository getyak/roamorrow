/** A map layout illustration, with no invented experience, rating or freshness facts. */
export function DayPageMock() {
  return (
    <div className="flex h-[540px] w-[264px] flex-col bg-bg-warm text-fg-primary">
      <div className="border-b border-border-default px-5 pb-4 pt-8">
        <p className="font-display text-[18px] font-medium">Roamorrow</p>
        <p className="mt-1 text-[14px] text-fg-muted">A few things to do. You choose.</p>
      </div>
      <div className="relative min-h-0 flex-1 overflow-hidden bg-accent-soft">
        <svg
          className="h-full w-full text-accent"
          viewBox="0 0 264 250"
          role="img"
          aria-label="Map layout illustration, not a live map or a route"
        >
          <path
            d="M0 45H264M0 115H264M0 205H264M48 0V250M124 0V250M214 0V250"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            opacity="0.15"
          />
          <path
            d="M-10 230Q90 130 145 95T280 20"
            fill="none"
            stroke="currentColor"
            strokeWidth="22"
            opacity="0.1"
          />
          <circle
            cx="124"
            cy="115"
            r="34"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.5"
            opacity="0.5"
          />
          <path d="M124 103V127M112 115H136" stroke="currentColor" strokeWidth="2" />
        </svg>
        <span className="absolute bottom-3 left-4 right-4 text-[14px] text-fg-muted">
          Map illustration · not live
        </span>
      </div>
      <div className="border-t border-border-default bg-bg-warm px-5 py-5">
        <p className="font-display text-[20px] font-medium leading-snug">Things to do here</p>
        <p className="mt-2 text-[16px] leading-relaxed text-fg-muted">
          Open an experience for the place, sources and directions.
        </p>
        <a
          href="/app"
          className="mt-4 flex min-h-[44px] items-center justify-center rounded-full bg-accent-interactive px-3 py-3 text-center text-[16px] font-medium text-on-accent"
        >
          Open the web map
        </a>
      </div>
    </div>
  );
}
