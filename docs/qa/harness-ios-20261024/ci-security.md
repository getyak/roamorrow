# PR #674 — CI remediation evidence

The first PR head was `25997ac7`. Its CI found a checksum false positive,
new dependency advisories, and two pre-existing native source-policy failures.
This record separates those results from the pending rerun of the revised head.

## Security checks

- Gitleaks 8.30.1, downloaded from the official release and checksum-verified,
  scanned the four existing branch commits locally with redaction: no leaks.
  The sole new ignore is an exact historical commit/path/rule/line fingerprint
  for an executable SHA-256 independently recomputed from the retained binary.
  Scanner rules and workflow execution are unchanged.
- `pnpm audit --audit-level=low` passed after the targeted updates. The single
  existing braces mitigation/exception remains; no new audit exception was added.
- `pnpm install --lockfile-only --frozen-lockfile --ignore-scripts` passed with
  the existing minimum-release-age and strict supply-chain policy.
- Go 1.27.3 and the independently verified official Docker index replace
  1.27.2 for [GO-2026-6809](https://pkg.go.dev/vuln/GO-2026-6809). The patched
  toolchain test/vulnerability rerun remains pending; pre-upgrade Go test/vet/race
  results alone do not establish that this security update passed.

## Native results from the first head

The [first iOS CI run](https://github.com/getyak/roamorrow/actions/runs/40054212400)
built the app and executed the full unit target. `EmailAccountServiceTests`
passed all 12 cases. The full target reported 2013 executed tests, 14 skipped,
and 2 failures, so this run was not green.

Both failures came from files unchanged against `origin/main`: two hardcoded
Studio strings and missing documentation on `WebSearchService.SearchOutcome`
and its status enum. The strings now have English/Chinese keys and the symbols
have documentation. The shell localization guard and strings-file validation
passed; the full native rerun remains required.

The iOS workflow now runs the three account-onboarding UI checks on the same
selected simulator after the full unit suite, preserving failure propagation
and uploading a result bundle for seven days. These checks cover invalid email,
guest continuation and password-entry recovery; they do not log in a real user.

## Reviews and acceptance limits

Independent incremental review found no new confirmed P0/P1 in the Go patch,
exact scanner fingerprint, focused UI workflow, dependency manifests or Zod 4
consumer migration. The recursive JSON record now has an explicit string key
schema, with request-level regressions for nested JSON and invalid operators.
Static review does not substitute for the latest-head install/typecheck/test/build
and security checks.

Real default-account profile/MCP round trips, the exact accepted HTTPS endpoint,
and usable native account-page evidence remain required before leaving Draft.
The optional Google source is unconfigured. No secrets, real mailbox content,
or private raw CI/model logs are included in this record.

## Verified head and subsequent main integration

Head `273ecf38406eb9ce505c593038edbed3b46c9831` passed all applicable CI,
including Go 1.27.3 tests/vulnerability scanning and the Web install, audit,
typecheck, test, build and formatting gates. Native run
[40057651261](https://github.com/getyak/roamorrow/actions/runs/40057651261)
reported 2013 unit tests executed, 14 skipped, zero failures, followed by all
three original account UI tests passing without skips. The earlier pending
entries above describe historical runs rather than the current result.

Main subsequently advanced to `145b5ec6247a466d41d0816d365d5f530330264e`.
Its dependency cleanup and browser security regressions are retained in this
branch integration. The main workspace policy and lockfile replace the
overlapping updates; strict release age, the braces patch and its sole audit
exception remain. Main's two exact synthetic-fixture scanner fingerprints and
the existing exact binary-checksum fingerprint are retained without broader
scanner exceptions. Harness migration packaging and serial account UI checks
remain in place; XcodeGen regenerated the combined native project.

Local syntax/plist/whitespace checks passed. The dependency security scripts
passed two static lockfile checks, while five runtime checks could not pass
because this worktree has no installed workspace dependencies. No local install,
Simulator or full build was added under the current process/swap warnings.
The integrated head requires a fresh complete CI run and independent review;
the preceding green head cannot establish integration success. Real-account
and exact HTTPS acceptance still prevent leaving Draft.
