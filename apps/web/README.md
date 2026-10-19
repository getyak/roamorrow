# apps/web

> Next.js + Mapbox. Web is **not** a stripped iOS app — it has its own job.

## What this app is for

The web app serves four scenarios the iOS app cannot:

1. **Pre-trip research center** — desktop, multiple tabs, deep planning
2. **Zero-install try** — phone browser, "let me see this before installing"
3. **Post-trip sharing** — public URLs, OG images, recap pages
4. **SEO entry** — Google indexes us; iOS App Store doesn't

**Read [`docs/WEB_DESIGN.md`](../../docs/WEB_DESIGN.md) before opening any web PR.** That document is the definitive answer to "what does the web do?" — including the anti-goals list (what web should _not_ do).

## Status

🚧 Foundation phase. Not yet running. See open issues:

- #41 — umbrella scenario tracking
- #42 — Scenario A (desktop research view)
- #43 — Scenario B (mobile zero-install funnel)
- #44 — Scenario C (recap pages)
- #45 — Scenario D (SEO static pages)
- #4 — bare map screen (foundation work)

## Stack

- **Framework**: Next.js 15 (App Router, RSC, mix of SSG + SSR)
- **Map**: Mapbox GL JS (custom warm-toned style)
- **Styling**: Tailwind + shadcn/ui
- **State**: URL-as-state, no Redux
- **Auth**: Supabase magic-link email (optional, never gating content)
- **Deploy**: Vercel

## Development

```bash
# from repo root
pnpm install
pnpm --filter @solo-compass/web dev
```

Open http://localhost:3000.

## Mobile responsive, not separate

There is **no separate mobile site**. The same Next.js app responds to mobile viewports via Tailwind breakpoints. Mobile is Scenario B (zero-install try) — not a second product.

# Independent Nomads service

`/nomads` and its descendants are served by the separate `cubxxw/RemoteAI-Nomads` Cloudflare Worker. `next.config.ts` forwards only this namespace to `https://nomads.cubxxw.com/nomads/:path*`; do not remove that upstream domain when retiring its public links. The databases, builds and release processes remain independent.

Nomads owns its directory trailing slashes, so `skipTrailingSlashRedirect` disables Next.js normalization, while a slash-specific rewrite before the general rule preserves directory slashes at the upstream. Both are required to avoid a Next.js/Worker redirect loop. Marketing navigation uses a full page navigation when entering Nomads rather than requesting a Next.js RSC payload. The root robots file advertises both sitemaps; only the canonical `/nomads` page enters this application's sitemap.

Deploy the compatible Worker before promoting a web deployment containing this rewrite. Verify the new entry and deep links before enabling legacy redirects. Local record transfer is user-triggered at `/nomads/local-data/`; backups never upload to the server. Roll back by disabling legacy redirects first, then restore the previous web deployment. No database restore is involved.

The agent-only middleware authenticates original network attribution using the server-only `NOMADS_PROXY_SECRET`, shared with the Worker as a Secret. It signs Vercel's platform-provided client IP with a short-lived HMAC; it grants no session/operator permission and never forwards the key. Missing signing configuration fails closed for the agent API. Do not trust arbitrary forwarded headers on the publicly reachable Worker or replace this Secret with the agent operator key.
