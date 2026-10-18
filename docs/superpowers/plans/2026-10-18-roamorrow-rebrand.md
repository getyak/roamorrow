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
  rebrand worktree. Integration with current main uses the isolated
  `roamorrow-integration` checkout because a full historical asset fetch failed.
- Keep bundle/signing IDs, data-store keys, auth callbacks, and paid product IDs.
- Keep working public links and honest download/support destinations.
- Verify web metadata, mobile navigation, OG/favicon assets, and bilingual copy.
- Run native build/localization checks and appropriate TS/SEO checks; distinguish
  local acceptance, CI, deployment, and provider branding states.

## Task 1: Web brand and public URLs

Ownership: `apps/web/**`, excluding `apps/web/vercel.json` provider binding.

- [x] Inventory public naming, canonicals, structured data, share cards, and CTAs.
- [x] Add a central brand module and Roamorrow wordmark/mark/favicon assets.
- [x] Update English/Chinese pages, metadata, copy, and existing SEO assertions.
- [x] Verify type checking, web tests, build, and desktop/mobile browser paths.
      Final loading/share corrections pass all seven focused production-browser checks.

## Task 2: Native public identity

Ownership: `apps/ios/**` and `docs/APP_STORE_METADATA.md` in this worktree only.

- [x] Update display name, bilingual strings, permission copy, share branding,
      public links, and native brand artwork consistent with `BRAND.md`.
- [x] Preserve app identity, storage keys, receipt/product IDs, and legacy auth.
- [x] Regenerate Xcode project and run localization/build/relevant tests.
      Hosted iOS CI at `8e22122f` built successfully: 1,913 tests, 14 explicitly
      skipped, zero failures. Native sources have not changed after that run.
- [ ] Verify the name in Simulator and record any store-provider publication gate.

## Task 3: Repository and operational identity

Ownership: root files, `docs/**` except App Store metadata, `apps/bot/**`,
`packages/**`, `infra/**`, `scripts/**`, and deployment configuration.

- [x] Update active docs, bot copy, AI-facing brand names, and public origins.
- [x] Document intentional legacy technical identifiers and historical archives.
- [x] Align GitHub description/homepage/name and linked Notion/Linear records.
- [x] Configure and read back Active routing for hello/privacy/support aliases.
      Actual end-to-end mail delivery is not claimed.

## Task 4: Publish and verify

- [x] Review the complete diff and address independent review findings.
- [ ] Run fresh required checks, commit, push, and complete PR/CI integration.
- [ ] Deploy the verified commit, add apex/www domains and Cloudflare DNS.
- [ ] Verify HTTPS, canonical/robots/sitemap, favicon/OG, and real user paths.
- [ ] Read external branding settings back and report provider gates accurately.
- [ ] Verify original checkout hashes remain unchanged and update this ledger.

## Provider readback before website publication

GitHub is `getyak/roamorrow`; the existing Notion and Linear project entries now
use Roamorrow. Cloudflare owns `roamorrow.com` with apex/www DNS pointing to the
Roamorrow Vercel project. The same Supabase project is Healthy on its existing
Free/Nano plan; default SMTP remains unchanged. App Store Connect saved the
Roamorrow name, subtitle and canonical marketing/support/privacy URLs on version
1.0, which remains Prepare for Submission. No App Store review was submitted.

The full approved legal text is now served by the website. Legacy Gist sources
are retained as historical records; access restrictions prevented edits to them.

## Final acceptance record

[PR #669](https://github.com/getyak/roamorrow/pull/669) carries the current CI,
review and production readback evidence. The original implementation passed
workspace type checking, 315 unit tests, production build, format/security/schema
checks and hosted native CI. The final browser corrections also pass the complete
seven-case focused browser suite, including delayed-script loading and four share
image routes. Subsequent commit/merge/deployment verification is recorded on the PR.

Launch verification found placeholder web credentials and a missing web schema
in the existing native backend. Actual provider credentials are now configured
securely. Reviewed additive migrations initialize 14 web/evidence tables with
RLS, preserve the 19 native tables and load no experience seed data. The guarded
PostGIS correction moves only two new empty columns into `extensions`; the
transactional role/spatial test passes and rolls its probe back. Mapbox's existing
public token passed an official style request; no payment method or upgrade was
added. Vercel's existing GitHub connection now points to `getyak/roamorrow`/`main`.
