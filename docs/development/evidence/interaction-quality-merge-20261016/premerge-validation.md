# PR #668 merge preflight

The branch originally failed secret scanning on 68 source-file digest matches (62 unique fingerprints), audit-export formatting, and a CodeQL URL-taint warning in the offline HTML report. No runnable product behavior changed in these merge fixes.

- `.gitleaksignore` adds only those 62 exact immutable commit/path/rule/line fingerprints; original nine entries remain. Every reported digest was independently recomputed from source bytes; an independent reviewer also verified all 14 unique source/digest pairs. Rules and workflow remain enabled.
- Pinned gitleaks 8.30.1 release archive checksum was checked. Full history scan passed with zero findings. Private synthetic service and Sentry controls still triggered both implicated rules; they are not committed. See `secret-scan-validation.json` and redacted logs.
- The offline report now renders source paths as text rather than constructing an unnecessary dynamic GitHub URL. No CodeQL suppression was added. Its JavaScript and embedded JSON parse successfully.
- Formatting excludes are limited to generated audit exports and captured evidence, preserving their original bytes. Authored reports were formatted and remain checked by Prettier.
- The anti-pattern linter matched only the English phrase in the persistence test's documentation comment. The comment now describes the atomic route/conversation write; test logic is unchanged and the rule is not waived.

The existing native build/runtime receipts remain bound to source commit `7e30bf17`; this final test-comment wording has a different byte hash without changing executable test logic. Product UI source hashes and the 974-candidate inventory are unchanged. Latest-head GitHub CI remains the merge authority; previous green jobs are not treated as approval of a new head.

MiMo PR preparation refused the oversized inventory patch returned by GitHub, before any model call. No partial model review was published. Existing independent source/design review and the separately reviewed merge-only delta remain documented; no `@codex review` was triggered.
