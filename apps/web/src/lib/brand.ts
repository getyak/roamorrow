/** Public identity only. Compatibility package, auth and storage IDs stay unchanged. */
export const BRAND = {
  name: "Roamorrow",
  origin: "https://roamorrow.com",
  host: "roamorrow.com",
  tagline: "Find your way. Feel at home.",
  supportingLineZh: "一个人出发，也能在远方过好日常。",
  description:
    "A personal companion for solo travel and life on the move. Explore local experiences, find your own way, and feel at home in a new place.",
  webAppPath: "/app",
  repositoryUrl: "https://github.com/getyak/roamorrow",
  supportEmail: "hello@roamorrow.com",
  privacyEmail: "privacy@roamorrow.com",
  colors: {
    paper: "#FAF8F6",
    ink: "#1F1A14",
    brown: "#5D3000",
    gold: "#C9A677",
  },
} as const;

export const SITE_URL = BRAND.origin;

export function publicUrl(path = "/"): string {
  return new URL(path, `${BRAND.origin}/`).toString();
}
