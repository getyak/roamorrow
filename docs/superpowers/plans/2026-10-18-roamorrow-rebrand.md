# Roamorrow Rebrand Implementation Plan

> **For agentic workers:** Use the repository development guide and focused,
> independent implementation tasks; integrate and review before publishing.

**Goal:** Publish a consistent Roamorrow identity across the existing product,
project records, and https://roamorrow.com without losing existing user data.

**Architecture:** Update public brand surfaces and centralize web identity.
Preserve compatibility identifiers and historical records. Use the current
hosting project and account where available; bind and verify the new domain.

**Tech stack:** Next.js, SwiftUI, XcodeGen, pnpm, GitHub, Cloudflare, existing host.

**Spec:** `BRAND.md`; the user's approved Roamorrow name and English-first scope.

## Constraints and review focus

- Preserve the original checkout's 32 dirty/untracked paths; work in the attached
  rebrand worktree.
- Keep bundle/signing IDs, data-store keys, auth callbacks, and paid product IDs.
- Keep working public links and honest download/support destinations.
- Verify web metadata, mobile navigation, OG/favicon assets, and bilingual copy.
- Run native build/localization checks and appropriate TS/SEO checks; distinguish
  local acceptance, CI, deployment, and provider branding states.

## Task 1: Web brand and public URLs

Ownership: `apps/web/**`, excluding `apps/web/vercel.json` provider binding.

- [ ] Inventory public naming, canonicals, structured data, share cards, and CTAs.
- [ ] Add a central brand module and Roamorrow wordmark/mark/favicon assets.
- [ ] Update English/Chinese pages, metadata, copy, and existing SEO assertions.
- [ ] Verify type checking, web tests, build, and desktop/mobile browser paths.

## Task 2: Native public identity

Ownership: `apps/ios/**` and `docs/APP_STORE_METADATA.md` in this worktree only.

- [ ] Update display name, bilingual strings, permission copy, share branding,
  public links, and native brand artwork consistent with `BRAND.md`.
- [ ] Preserve app identity, storage keys, receipt/product IDs, and legacy auth.
- [ ] Regenerate Xcode project and run localization/build/relevant tests.
- [ ] Verify the name in Simulator and record any store-provider publication gate.

## Task 3: Repository and operational identity

Ownership: root files, `docs/**` except App Store metadata, `apps/bot/**`,
`packages/**`, `infra/**`, `scripts/**`, and deployment configuration.

- [ ] Update active docs, bot copy, AI-facing brand names, and public origins.
- [ ] Document intentional legacy technical identifiers and historical archives.
- [ ] Align GitHub description/homepage/name and linked Notion/Linear records.
- [ ] Ensure contact addresses used by the public product have working routing.

## Task 4: Publish and verify

- [ ] Review the complete diff and address independent review findings.
- [ ] Run fresh required checks, commit, push, and complete PR/CI integration.
- [ ] Deploy the verified commit, add apex/www domains and Cloudflare DNS.
- [ ] Verify HTTPS, canonical/robots/sitemap, favicon/OG, and real user paths.
- [ ] Read external branding settings back and report provider gates accurately.
- [ ] Verify original checkout hashes remain unchanged and update this ledger.
