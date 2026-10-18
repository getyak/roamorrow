import { BRAND } from "@/lib/brand";

/** A wandering route meets the horizon beneath a rising sun. */
export function RoamorrowMark({
  size = 24,
  strokeColor = BRAND.colors.brown,
}: {
  size?: number;
  strokeColor?: string;
}) {
  return (
    <svg width={size} height={size} viewBox="0 0 64 64" fill="none" aria-hidden="true">
      <path d="M34 26a10 10 0 0 1 20 0Z" fill={BRAND.colors.gold} />
      <path
        d="M10 28H54M22 55C48 48 47 41 31 38C17 35 18 28 32 28"
        stroke={strokeColor}
        strokeWidth="4.5"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

export function RoamorrowWordmark({ size = 28 }: { size?: number }) {
  return (
    <span className="inline-flex items-center gap-2 font-display font-medium tracking-tight">
      <RoamorrowMark size={size} />
      <span>{BRAND.name}</span>
    </span>
  );
}
