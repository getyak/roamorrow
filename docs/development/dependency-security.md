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
