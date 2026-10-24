# Dependency security gates

The dependency gate remains `pnpm audit --audit-level=low`. Security updates
must preserve the frozen lockfile and the workspace supply-chain settings.

## 2026-10-24 remediation

The follow-up audit reported 21 untriaged advisories: 3 critical, 5 high,
9 moderate and 4 low. These dependency floors address that set:

| Dependency      | Selected version |
| --------------- | ---------------- |
| @sentry/nextjs  | 10.75.2          |
| Next.js         | 15.5.28          |
| DOMPurify       | 3.4.17           |
| Vite            | 7.3.7            |
| Vitest / mocker | 4.1.12           |
| Zod             | 4.6.6            |
| undici          | 7.30.1           |
| fast-uri        | 3.1.9            |

Sentry's Node SDK is kept at the same release as its Next.js SDK. The Zod
advisory has no fixed v3 release, so the Web app uses v4 with explicit record
key schemas. API and environment regression tests cover existing defaults,
trimming, coordinate order and bounds, nested JSON, authentication boundaries,
strict input handling, and secret/public environment separation.

`pnpm security:patch-check` also checks every affected lockfile entry and
exercises oversized Zod arrays, the real Ajv URI dependency, and an Undici
response with excessive encodings followed by an early close. The existing
braces exception and its source patch checks remain mandatory.

`pnpm --filter @solo-compass/web security:browser` runs the actual PostHog
DOMPurify dependency in Chromium, including the attached Shadow DOM template
expression regression. It starts no application server and sends no analytics.
CI installs Playwright's Chromium first. Local verification can select an
existing Chrome with `SC_SECURITY_BROWSER_CHANNEL=chrome` and put artifacts
in a registered directory using `SC_SECURITY_ARTIFACT_DIR`.

The Go gate additionally found reachable
[GO-2026-6809](https://pkg.go.dev/vuln/GO-2026-6809) in the previous toolchain.
The module now requires Go 1.27.3 and the Docker builder uses the matching
official Alpine image pinned by OCI index digest. Module dependencies and
historical migrations are unchanged.

The verbose Go scan also lists GO-2026-5932 for the unmaintained OpenPGP
package inside x/crypto. The application does not import that package, the
scanner reports zero affected code paths and zero imported vulnerable
packages, and upstream lists no fixed release. No exception is added.

Local verification: frozen installation; all 21 audit findings cleared;
369 host tests; 7 Node security tests; 2 browser security tests; 86 fake-tool
simulator policy tests; typecheck, formatting, schema dry-run, parity and
production build. A standalone production smoke test checks home, robots,
sitemap and invalid API inputs. This does not replace remote CI or real
database/provider acceptance. Historical migrations and schemas remain unchanged.

The full remote iOS suite exposed two existing source-audit failures on main:
two Studio artwork labels lacked localization keys, and two public web-search
types lacked doc comments. The CI follow-up changes five native source/resource
files: both artwork strings retain their exact existing English brand copy in
both locales, and the search types gain documentation. The four original source
audit tests pass on the macOS host without a Simulator; the full iOS suite is
verified separately on the latest PR commit. The original 803-file hash manifest
is retained with these five explicit deltas, rather than rewriting its baseline.

Primary records: [Sentry](https://github.com/advisories/GHSA-mchm-gjx6-7h55),
[Next.js](https://github.com/advisories/GHSA-2464-fhr4-w9xw),
[DOMPurify](https://github.com/advisories/GHSA-cg2g-xh64-v4q7),
[Zod](https://github.com/advisories/GHSA-mrhx-c7xc-m3w5),
[Undici](https://github.com/advisories/GHSA-xjj6-f33q-929c),
[fast-uri](https://github.com/advisories/GHSA-w74x-v6f9-j3xg),
[Vite](https://github.com/advisories/GHSA-587h-7wmj-h5pm),
[mocker](https://github.com/advisories/GHSA-qxg6-89mg-rqv8).

## 2026-10-13 remediation

The main-branch audit reported 27 advisories. Targeted updates resolve 26:

| Dependency              | Selected version |
| ----------------------- | ---------------- |
| Next.js                 | 15.5.27          |
| sharp                   | 0.35.5           |
| undici                  | 7.29.1           |
| brace-expansion         | 2.1.7 / 5.0.12   |
| fast-uri                | 3.1.8            |
| source-map-js           | 1.2.2            |
| postcss-selector-parser | 7.1.6            |
| DOMPurify               | 3.4.16           |

The remaining advisory is
[GHSA-vfj7-8cjw-p6xm](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm).
Upstream lists no patched release. This repository consumes `braces@3.0.3`
through Tailwind's development dependencies (`micromatch` and `chokidar`).

## Local braces mitigation

`patches/braces@3.0.3.patch` bounds the parser's AST nesting at 100 before a
recursive walker can receive excessive input. The bound counts both braces
and parentheses, including mixed nesting. Quotes, escaping and character
classes keep their existing behavior. The existing input-length and expansion
limits remain in effect. This mitigation follows the nesting-bound approach
described in the [upstream report](https://github.com/micromatch/braces/issues/70).

The audit exception names only this GHSA because registry audits identify the
original package version, not the patched source. It is coupled to a mandatory
`pnpm security:patch-check` before the audit in CI. That check:

- Exercises excessive input through parse, compile, expand and the default API
  for both actual Tailwind consumers.
- Verifies depth 100, ordinary expansion, escaping, quotes and character classes.
- Requires every braces lockfile snapshot to be version 3.0.3 with the exact
  SHA-256 of the committed patch. A newly introduced unpatched version fails.

Patch application failures fail installation. Do not expand the exception or
raise the audit severity threshold to suppress unrelated findings. Once an
upstream fixed version is available, review and install it, then remove this
patch, exception and the version-specific guard together.

```bash
pnpm security:patch-check
pnpm audit --audit-level=low
```

Local verification can use `SC_BRACES_FIXTURE_PACKAGE` pointing to an isolated
package manifest that installs the same patched version. CI leaves it unset
and verifies the real dependency paths. An audit with this exception passing
means no **untriaged** advisories; it does not mean the registry advisory has
been withdrawn.

References: [pnpm audit](https://pnpm.io/cli/audit),
[versioned patches](https://pnpm.io/cli/patch),
[Next.js advisory](https://github.com/advisories/GHSA-4jqv-mc3x-m676),
[sharp advisory](https://github.com/advisories/GHSA-wq5f-xc86-pv6w).

## Go security remediation

The same delivery's `govulncheck` failed on nine reachable advisories in Go
1.27.0 and `golang.org/x/net@v0.58.0`. The scanner identifies Go 1.27.2 and
`x/net@v0.60.0` as the fixes. See the
[official Go release](https://go.dev/doc/devel/release#go1.27.2) and
[HTTP/2 vulnerability record](https://pkg.go.dev/vuln/GO-2026-6603).

`apps/api/go.mod` now requires Go 1.27.2 and x/net 0.60.0, including the
crypto/sys/text versions required by that module. `go.sum` records the public
Go checksum database entries. The Docker builder uses the official
`golang:1.27.2-alpine` image, pinned to its registry-verified OCI index digest.
CI continues to verify module checksums, run `go test ./...`, and run
`govulncheck`; no Go advisory exceptions are introduced.
