# Public legal documents

These repository files are the sources for Roamorrow's public, bilingual legal pages:

| Document         | Public reading page                                               |
| ---------------- | ----------------------------------------------------------------- |
| Privacy Policy   | [Privacy Policy / 隐私政策](https://roamorrow.com/privacy/policy) |
| Terms of Service | [Terms of Service / 用户协议](https://roamorrow.com/terms)        |

Privacy and deletion requests use `privacy@roamorrow.com`; support uses `hello@roamorrow.com`. These addresses forward to the maintainer's verified mailbox through Cloudflare Email Routing. The documents identify the publicly documented maintainer; they do not invent a registered corporate entity or a governing jurisdiction.

`publication.json` records canonical URLs, repository sources and source hashes. Its `legacyGists` section retains the prior public Gist identifiers and publication evidence for historical compatibility. Those Gists are no longer the current publication destination. Their content was not changed during the Roamorrow migration because the authenticated account did not have edit access.

## Updating

1. Recheck the actual data flows, enabled providers, permissions, storage, deletion and purchase configuration. Edit the Markdown source and date material changes.
2. Independently review factual accuracy and Chinese/English consistency. Do not copy old claims that all data stays local, all reports are anonymous, a local reset deletes a cloud account or a local StoreKit file proves an active offer.
3. Copy the reviewed Markdown into the web's static content modules (`privacy-content.ts` and `terms-content.ts`) without omitting either language, table, section or commitment. Update source hashes in `publication.json` and verify that joining the exported sections reconstructs each source exactly. The shared `PolicyText` renderer displays this trusted content.
4. Build and deploy the website. Read both unauthenticated canonical pages back; verify title, complete English/Chinese text, tables, contacts and mutual links. Record live verification separately from this declarative publication configuration before claiming publication complete.
5. Keep native `LegalDocuments`, Web `LEGAL_URLS`, the bot privacy summary and release metadata aligned. Native releases, website/bot deployments and App Store Connect updates are separate operations.

Evidence for the earlier Gist publication is in [checkpoint 05](../design/interaction-quality/evidence/checkpoint-05-legal.md), [data-flow audit](../design/interaction-quality/evidence/legal-data-audit.md) and [independent review](../design/interaction-quality/evidence/legal-document-review.md). The service Terms reference Apple's Standard EULA conditionally; no custom EULA has been installed by this work.
