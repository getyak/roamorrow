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
