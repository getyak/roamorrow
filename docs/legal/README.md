# Public legal documents

These repository files are the sources for two public, bilingual GitHub Gists:

| Document         | Public reading page                                                                            |
| ---------------- | ---------------------------------------------------------------------------------------------- |
| Privacy Policy   | [Privacy Policy / 隐私政策](https://gist.github.com/kubbot/e177b6ab042c8d5bd79417300031a5c9)   |
| Terms of Service | [Terms of Service / 用户协议](https://gist.github.com/kubbot/08f720b1191b6f9c913699c16227581a) |

The user specified `cubxxw@gmail.com` for private support, privacy and deletion requests. The documents identify the publicly documented maintainer; they do not invent a registered corporate entity or a governing jurisdiction.

`publication.json` records the two Gist IDs, owner, file names and content hashes. Keep the existing Gist IDs and normal reading URLs when updating; do not create new Gists on each release or link to a revision-pinned raw file.

## Updating

1. Recheck the actual data flows, enabled providers, permissions, storage, deletion and purchase configuration. Edit the Markdown source and date material changes.
2. Independently review factual accuracy and Chinese/English consistency. Do not copy old claims that all data stays local, all reports are anonymous, a local reset deletes a cloud account or a local StoreKit file proves an active offer.
3. Update each existing Gist with the reviewed local file under the current task's publication authorization:

```bash
gh gist edit e177b6ab042c8d5bd79417300031a5c9 --filename privacy-policy.md docs/legal/privacy-policy.md
gh gist edit 08f720b1191b6f9c913699c16227581a --filename terms-of-service.md docs/legal/terms-of-service.md
```

4. Read back both public API files and unauthenticated reading pages; compare the actual file hashes, title, English/Chinese text, contact and mutual links. Record the result before claiming publication complete.
5. Keep native `LegalDocuments`, Web `LEGAL_URLS`, the bot privacy summary and release metadata aligned. App/website/bot deployments and App Store Connect updates are separate operations; publishing Gists does not perform them.

Evidence for this publication is in [checkpoint 05](../design/interaction-quality/evidence/checkpoint-05-legal.md), [data-flow audit](../design/interaction-quality/evidence/legal-data-audit.md) and [independent review](../design/interaction-quality/evidence/legal-document-review.md). The service Terms reference Apple's Standard EULA conditionally; no custom EULA has been installed by this work.
