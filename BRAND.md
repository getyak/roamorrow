# Roamorrow

Roamorrow is a personal companion for solo travel and life on the move.

**Public name:** Roamorrow
**Canonical origin:** https://roamorrow.com
**Tagline:** Find your way. Feel at home.
**Chinese supporting line:** 一个人出发，也能在远方过好日常。

## Identity

Lead with independent exploration, local experiences, and feeling at home in a
new place. Solo travel is the starting point; the identity also accommodates
longer stays and people who work while traveling. Describe only capabilities
that actually exist. Recommendations offer choices and visible sources.

Use the existing warm travel palette: paper `#FAF8F6`, ink `#1F1A14`, deep brown
`#5D3000`, and sun gold `#C9A677`. Retain Space Grotesk for the web wordmark and
headings, Inter for body text, and the established native typography. The mark
connects a wandering path with a rising sun; it must remain legible at favicon
size. Keep layouts and motion quiet and consistent with the existing product.

## Naming and copy

- Write **Roamorrow**, including in Chinese interfaces. Do not introduce a new
  translated product name.
- Use the same name in navigation, permissions, share cards, legal copy, social
  previews, app display names, and store metadata.
- Use `https://roamorrow.com` for public web links and canonical metadata.
- Do not advertise an App Store release, social account, support mailbox, or
  provider verification until its destination is confirmed to exist.
- Retain historical changelogs, archives, migration provenance, and accurate
  descriptions of the former Solo Compass identity.

## Compatibility

The public rebrand must preserve installed-app identity and existing user data.
Keep signing and bundle identifiers, StoreKit product IDs, persistence keys,
Keychain/service identifiers, existing OAuth callbacks, certificate-repository
names, and internal Swift/module/package paths unless an explicit migration is
implemented and verified. These strings are compatibility identifiers, not
public brand copy. New public links use Roamorrow; legacy links remain supported
where the application already accepts them.

## Release evidence

A source edit is not a deployment. Record the deployed commit, verify the
Cloudflare DNS and hosting-domain state, and open representative pages over
HTTPS. Provider branding is complete only after provider readback confirms it.

## Public deployment

The GitHub repository is `getyak/roamorrow`. Its `main` branch is connected to
the Vercel project `roamorrow`, with `apps/web` as the root directory and workspace
sources included. Use Node 22 and the exact pnpm version pinned in `package.json`.
Cloudflare retains registration and nameservers; apex and `www` use DNS-only
CNAME records to the Vercel-recommended target. Vercel redirects `www` to the
HTTPS apex with status 308.

Use actual provider credentials for `SUPABASE_URL`, `SUPABASE_KEY` (the existing
anonymous key), `SUPABASE_SERVICE_ROLE_KEY`, and optional `DEEPSEEK_API_KEY`.
Values in example files are not deployment configuration. Transfer credentials
through secure provider settings or CLI stdin; do not put them in source, shell
arguments or release evidence. The web basemap additionally requires a real
`NEXT_PUBLIC_MAPBOX_TOKEN`; a placeholder must keep the explicit imagery-unavailable
state. Use Mapbox's `light-v11` style through that configured token. Verify actual
roads and labels in a rendered screenshot: an HTTP 200 tile can still be an
authentication placeholder. Analytics remains optional.

Native sync and the web use distinct tables in the same existing Supabase
project. `0018_web_bootstrap.sql` initializes the web's missing tables without
replacing native tables or inserting seed data. The existing evidence, work and
route schemas are in migrations `0014`–`0016`. Check the live schema and migration
ledger before applying any script; retain row-level security and service-only
access for internal traffic/evidence records.

Apply `0019_private_postgis_schema.sql` before loading web data. It moves only
the two newly created, empty geography columns to PostGIS in `extensions`,
preserving their types and constraints. It locks and checks both tables, fails
if either contains a row, and drops the extension without `CASCADE` so unexpected
dependencies abort the transaction. The live migration ledger records this
bootstrap separately from pre-existing native tables. Follow
[Supabase's PostGIS guidance](https://supabase.com/docs/guides/database/extensions/postgis)
for any later extension migration involving data; never run an empty-table
bootstrap as a reset of an existing database.

Cloudflare Email Routing provides the `hello`, `privacy` and `support` aliases
at `roamorrow.com`. App Store Connect keeps app ID `6766460734`; saved store
branding becomes public with the next submitted and approved version. Updating
the website does not publish a native release.
