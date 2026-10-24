# Dependency security gates

The dependency gate remains `pnpm audit --audit-level=low`. Security updates
must preserve the frozen lockfile and the workspace supply-chain settings.

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

That delivery set `apps/api/go.mod` to Go 1.27.2 and x/net 0.60.0, including the
crypto/sys/text versions required by that module. `go.sum` records the public
Go checksum database entries. The Docker builder then used the official
`golang:1.27.2-alpine` image, pinned to its registry-verified OCI index digest.
CI continues to verify module checksums, run `go test ./...`, and run
`govulncheck`; no Go advisory exceptions are introduced.

## 2026-10-24 CI remediation

PR #674 exposed new advisories after the earlier remediation. The Go standard
library check reports [GO-2026-6809](https://pkg.go.dev/vuln/GO-2026-6809), fixed
in Go 1.27.3. The module minimum and official Docker builder now use 1.27.3;
the builder index digest was read from Docker Registry and independently
recomputed before pinning it. No vulnerability suppression was added.

The Node updates target these fixed versions from the registry advisories:

| Dependency      | Selected version |
| --------------- | ---------------- |
| Next.js         | 15.5.28          |
| Sentry Next.js  | 10.75.2          |
| Vitest / mocker | 4.1.12           |
| Vite            | 7.3.7            |
| Zod             | 4.6.6            |
| DOMPurify       | 3.4.17           |
| undici          | 7.30.1           |
| fast-uri        | 3.1.9            |

Zod 3 is affected by [GHSA-mrhx-c7xc-m3w5](https://github.com/advisories/GHSA-mrhx-c7xc-m3w5).
The six application consumers were checked for Zod 4 compatibility; the route
compiler's recursive JSON record now supplies an explicit string key schema.
A request-level regression covers nested JSON constraints and invalid operators
before backend access. OpenAI 7.23.0 accepts Zod 4, so its SDK remains unchanged.

The 1440-minute minimum release age, strict mode, build allowlist, frozen
lockfile requirement and existing braces patch/exception remain in place.
The current audit, tests and scanner status are recorded in the
[Harness acceptance record](../qa/harness-ios-20261024/README.md); selecting a
fixed version or reviewing the manifest does not substitute for those checks.

The secret-scanning finding in the old acceptance JSON was an executable
SHA-256, independently recomputed from the retained binary. Only its exact
historical commit/file/rule/line fingerprint is ignored. Default scanning rules,
workflow execution and redaction remain unchanged.
