import { RoamorrowMark } from "@/components/brand/RoamorrowMark";
import { BRAND } from "@/lib/brand";

/** Static markup stays visible while the map's client code is loading. */
export function MapLoading() {
  return (
    <main id="main" className="flex min-h-dvh items-center justify-center bg-bg-warm px-6">
      <div
        role="status"
        aria-label="Opening your map"
        aria-live="polite"
        aria-atomic="true"
        className="flex flex-col items-center text-center"
      >
        <RoamorrowMark size={64} />
        <p className="mt-4 font-display text-[26px] font-medium tracking-tight text-fg-primary">
          {BRAND.name}
        </p>
        <p className="mt-3 font-body text-[16px] text-fg-muted">Opening your map…</p>
      </div>
    </main>
  );
}
