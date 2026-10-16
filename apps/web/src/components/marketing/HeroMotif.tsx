/**
 * HeroMotif — quiet compass/route illustration behind the hero.
 *
 * Replaces the rotating Three.js aurora+dust canvas: a travel-decision
 * product should open on its own subject (a compass rose over a route
 * between experience pins), not on ambient decoration. Static SVG, no
 * infinite animation, no WebGL import — and nothing here pretends to be a
 * control.
 */

export function HeroMotif() {
  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden" aria-hidden="true">
      <svg
        className="absolute -right-24 top-1/2 h-[130%] w-[70%] -translate-y-1/2 opacity-[0.16]"
        viewBox="0 0 600 600"
        fill="none"
      >
        {/* Compass rose */}
        <circle cx="330" cy="290" r="190" stroke="var(--accent)" strokeWidth="1" />
        <circle cx="330" cy="290" r="132" stroke="var(--sun-gold-deep)" strokeWidth="0.8" />
        <circle cx="330" cy="290" r="6" fill="var(--sun-gold)" />
        <path d="M330 92 L346 290 L330 488 L314 290 Z" fill="var(--accent)" opacity="0.7" />
        <path d="M132 290 L330 302 L528 290 L330 278 Z" fill="var(--sun-gold-deep)" opacity="0.5" />
        {/* Route between three experience pins */}
        <path
          d="M150 470 C 210 420, 220 360, 280 330 C 340 300, 380 250, 430 180"
          stroke="var(--accent)"
          strokeWidth="2"
          strokeLinecap="round"
          strokeDasharray="2 8"
        />
        <g>
          <circle cx="150" cy="470" r="9" fill="var(--sun-gold)" />
          <circle cx="280" cy="330" r="9" fill="var(--sun-gold)" />
          <circle cx="430" cy="180" r="11" fill="var(--accent)" />
        </g>
        {/* Quiet distance ticks */}
        {Array.from({ length: 24 }).map((_, i) => (
          <line
            key={i}
            x1={330 + 196 * Math.cos((i * Math.PI) / 12)}
            y1={290 + 196 * Math.sin((i * Math.PI) / 12)}
            x2={330 + 204 * Math.cos((i * Math.PI) / 12)}
            y2={290 + 204 * Math.sin((i * Math.PI) / 12)}
            stroke="var(--sun-gold-deep)"
            strokeWidth="1"
          />
        ))}
      </svg>
    </div>
  );
}
