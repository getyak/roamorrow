import type { Config } from "tailwindcss";

/**
 * Roamorrow · Tailwind config
 *
 * Colors, radii, shadows, motion mirror the CT palette
 * (source: apps/ios/SoloCompass/Views/Shared/CompareTokens.swift
 *  + docs/WEB_LANDING_DESIGN.md §1).
 *
 * The `warm-*` / `fg-*` / `accent*` names below are the new marketing SoT.
 * Legacy tokens (`paper-cream` etc.) stay for existing pages under
 * src/components/lisbon/ and Scenario-A shells.
 */
const config: Config = {
  content: ["./src/**/*.{js,ts,jsx,tsx,mdx}"],
  theme: {
    extend: {
      colors: {
        // --- CT parity (new marketing SoT) ---
        "bg-warm": "var(--bg-warm)",
        "surface-white": "var(--surface-white)",
        "surface-sunken": "var(--surface-sunken)",

        "fg-primary": "var(--fg-primary)",
        "fg-muted": "var(--fg-muted)",
        "fg-subtle": "var(--fg-subtle)",

        "border-subtle": "var(--border-subtle)",
        "border-default": "var(--border-default)",

        accent: "var(--accent)",
        "accent-hover": "var(--accent-hover)",
        "accent-soft": "var(--accent-soft)",
        "accent-border": "var(--accent-border)",
        // Interaction roles (W08) — pair `accent-interactive` with `on-accent`.
        "accent-interactive": "var(--accent-interactive)",
        "accent-interactive-hover": "var(--accent-interactive-hover)",
        "on-accent": "var(--on-accent)",
        "focus-ring": "var(--focus-ring)",

        "sun-gold": "var(--sun-gold)",
        "sun-gold-deep": "var(--sun-gold-deep)",
        "sun-gold-soft": "var(--sun-gold-soft)",

        "capsule-glow": "var(--capsule-glow)",
        "omen-gold": "var(--omen-gold)",
        "blindbox-amber": "var(--blindbox-amber)",

        "tone-open": "var(--tone-open)",
        "tone-forming": "var(--tone-forming)",
        "tone-closed": "var(--tone-closed)",
        "tone-completed": "var(--tone-completed)",

        "warning-soft": "var(--warning-soft)",
        "warning-text": "var(--warning-text)",
        "success-soft": "var(--success-soft)",
        "success-text": "var(--success-text)",

        // --- Legacy palette (do not use in new marketing pages) ---
        "paper-cream": "rgb(var(--app-paper, 245 241 232) / <alpha-value>)",
        "ink-warm": "rgb(var(--app-ink, 44 42 38) / <alpha-value>)",
        "muted-road": "#D9D3C4",
        "soft-green": "#A8B89C",
        "deep-teal": "rgb(var(--app-teal, 47 107 107) / <alpha-value>)",
        "warm-amber": "#C68E3F",
      },
      fontFamily: {
        display: ["Karla", "system-ui", "sans-serif"],
        body: ["Karla", "system-ui", "sans-serif"],
        mono: ["JetBrains Mono", "ui-monospace", "monospace"],
        serif: ["Literata", "Georgia", "serif"],
        sans: ["Karla", "system-ui", "-apple-system", "sans-serif"],
      },
      fontSize: {
        "display-2xl": ["clamp(56px, 8vw, 96px)", { lineHeight: "1.02", letterSpacing: "-0.02em" }],
        "display-xl": ["clamp(44px, 6vw, 72px)", { lineHeight: "1.05", letterSpacing: "-0.015em" }],
        "display-lg": ["clamp(36px, 5vw, 56px)", { lineHeight: "1.08", letterSpacing: "-0.01em" }],
        "display-md": [
          "clamp(28px, 3.5vw, 40px)",
          { lineHeight: "1.15", letterSpacing: "-0.005em" },
        ],
        "display-sm": ["32px", { lineHeight: "1.2" }],
        "body-xl": ["22px", { lineHeight: "1.55" }],
        "body-lg": ["18px", { lineHeight: "1.6" }],
        "body-md": ["16px", { lineHeight: "1.6" }],
        "body-sm": ["14px", { lineHeight: "1.5" }],
        "body-xs": ["12px", { lineHeight: "1.4" }],
      },
      borderRadius: {
        sm: "6px",
        md: "10px",
        lg: "14px",
        xl: "20px",
        "2xl": "32px",
      },
      boxShadow: {
        xs: "var(--shadow-xs)",
        sm: "var(--shadow-sm)",
        md: "var(--shadow-md)",
        lg: "var(--shadow-lg)",
        "2xl": "var(--shadow-2xl)",
      },
      transitionTimingFunction: {
        standard: "cubic-bezier(0.4, 0, 0.2, 1)",
        decel: "cubic-bezier(0, 0, 0.2, 1)",
        accel: "cubic-bezier(0.4, 0, 1, 1)",
      },
      transitionDuration: {
        instant: "80ms",
        fast: "160ms",
        normal: "240ms",
        slow: "420ms",
        editorial: "640ms",
      },
      maxWidth: {
        narrow: "680px",
        default: "1120px",
        wide: "1360px",
        max: "1440px",
      },
      spacing: {
        "section-y": "160px",
        "section-y-sm": "96px",
      },
    },
  },
  plugins: [],
};

export default config;
