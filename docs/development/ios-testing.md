# iOS Simulator Testing Policy

Solo Compass shares one locally allowlisted set of iOS Simulator devices. This
policy keeps daily runs deterministic, serialized, and cheap. It is the owning
doc for how `scripts/sc-evaluator`, `scripts/user-story-rubric`,
`scripts/sc-executor`, and the `scripts/qa/two-sim-friend-loop.sh` exception
pick and use simulators.

## Profiles and daily policy

The frozen profile API matches the host helper (`dev-ios-session`):
`primary` (default), `compact`, and `ipad`. `daily` is accepted only as a
compatibility alias for `primary`.

- Run the tests affected by your change on **`primary`** only
  (`iPhone 17 Pro` by default). Do not boot extra devices "just in case".
- **`compact`** is for keyboard, Dynamic Type, and layout checks, plus targeted
  release verification. It is not a full regression suite.
- **`ipad`** is used only for changes that specifically target iPad support.
  It is never auto-selected.
- **Web/backend changes** do not need a simulator at all.
- This policy reduces simulator contention; it does **not** promise a specific
  percentage reduction in run time. Some changes still need a real device run.

The helper resolves devices from the shared allowlist at
`~/.config/dev-storage-guard/simulator-allowlist.tsv` (override
`DEV_IOS_ALLOWLIST`), whose tab-separated entries are `UDID<TAB>label`:

| Profile   | Allowlist label  | Use                                                  |
| --------- | ---------------- | ---------------------------------------------------- |
| `primary` | `Primary iPhone` | Default for daily affected unit and UI tests.        |
| `compact` | `Compact iPhone` | Layout, keyboard, Dynamic Type, targeted release.    |
| `ipad`    | `iPad`           | Only capabilities or layouts that are iPad-specific. |

Selecting `compact` or `ipad` requires a nonempty `DEV_IOS_REASON`; `primary`
always resolves the `Primary iPhone` entry even when another simulator is
booted. The helper enforces the reason when it owns the session, and the
portable fallback (below) enforces the same rule **outside CI whenever the
helper is absent**, so an unreasoned `compact`/`ipad` run cannot slip through
on a helper-less host. The `daily` alias (i.e. `primary`) never needs a reason.

## Device selection (deterministic fallback)

When the helper is not in play (CI, non-macOS, or no helper installed),
selection is shared by `scripts/ios/session.sh` and
`scripts/ios/select-simulator.py`:

1. An explicit `IOS_SIMULATOR_ID` and/or `SIMULATOR_UDID` (UDID or exact device
   name) is **honored and validated** against the live inventory. Names are
   canonicalized to UDIDs; `-destination id=` never receives a device name.
   Unknown devices, wrong-family devices, and watchOS/tvOS devices fail closed —
   they are never substituted.
2. When both IDs are exported (an owned helper session) they must agree, so a
   stale `SIMULATOR_UDID` cannot silently override `IOS_SIMULATOR_ID`.
3. Otherwise the best available **numbered iPhone on an iOS runtime** is
   chosen: `iPhone 17 Pro` if present, else the newest numbered iPhone, else
   any non-numbered iPhone, with **iPhone SE strictly last**. Entries under
   non-iOS runtimes (watchOS/tvOS) are never auto-selected, even when named
   like an iPhone.
4. A **booted SE/iPad is ignored** for auto-selection. Boot state never
   overrides the declared preference, and other booted devices are left
   running.
5. **iPads are only used when explicitly requested** via `IOS_SIMULATOR_ID`
   with `DEV_IOS_PROFILE=ipad`. The portable fallback requires an explicit ID
   for both auxiliary profiles (`compact` and `ipad`); it never substitutes the
   primary phone for a compact-device request. The host helper supplies this ID
   from the allowlist.

No script creates a new simulator. All selection is over already-available
devices.

A `simctl boot` or `simctl bootstatus` failure **fails the run** (the evaluator
records it as a `simulator.boot` failure step); it is never swallowed while
the run keeps installing or launching against a device that never became
ready.

## Shared-device ownership: `dev-ios-session`

On a configured macOS host the shared helper lives at
`~/.local/bin/dev-ios-session` (override with `DEV_IOS_SESSION_BIN`;
`DEV_IOS_SESSION_HELPER` and `dev-ios-session` on `PATH` are also honored). It
owns `/tmp/ios-automation.xcodebuild.lock` (override
`IOS_AUTOMATION_LOCK_FILE`), selects the allowlisted device, and exports
`IOS_SIMULATOR_ID` / `SIMULATOR_UDID` / `DEV_IOS_PROFILE`. Auto-shutdown only
ever targets the device it booted for the owned session.

Entrypoints reexec themselves inside the helper before any simulator
interaction or costly `xcodebuild`:

```bash
# Local macOS, outside CI, helper installed:
scripts/sc-evaluator/run.sh home-screen-cold-start --no-build
# -> reexecs as: dev-ios-session run -- scripts/sc-evaluator/run.sh ...
```

Rules:

- Nesting is decided by `dev-ios-session is-owner` (a **true ancestor** owns
  the lock and the selected device matches). We never trust `SIMULATOR_UDID`
  being present in the environment as proof of ownership.
- `CI=true` and `CI=1` skip the helper and use the portable selector, so CI
  needs no helper installed.
- If an explicitly configured helper is not executable, entrypoints **fail
  closed** rather than silently falling back.
- An explicit `IOS_SIMULATOR_ID` passed by a runner is forwarded and validated,
  so a helper-selected device and a caller-selected device stay consistent.

Useful env:

```bash
# Explicit device (validated; never substituted):
IOS_SIMULATOR_ID="iPhone 17 Pro" scripts/user-story-rubric/run.sh

# Compact vs iPad profile (both need an explicit ID in the portable
# fallback; the installed host helper supplies it):
DEV_IOS_PROFILE=compact DEV_IOS_REASON="keyboard layout check" \
  scripts/sc-evaluator/run.sh home-screen-cold-start

# Custom output locations: use a REGISTERED artifact root (dev-storage-guard,
# see AGENTS.md), never a bare /tmp path.
ARTIFACT_ROOT="$(dev-storage-guard new-artifact solo-compass-ios-qa)"
IOS_DERIVED_DATA_PATH="$ARTIFACT_ROOT/DerivedData" \
  scripts/sc-executor/run.sh --apply
IOS_DERIVED_DATA_PATH="$ARTIFACT_ROOT/DerivedData" \
IOS_ARTIFACT_DIR="$ARTIFACT_ROOT/evaluator" \
  scripts/sc-evaluator/run.sh home-screen-cold-start

# ...and remove the local copy once the delivery evidence is preserved:
#   dev-storage-guard remove-artifact "$ARTIFACT_ROOT"
```

An explicit `IOS_DERIVED_DATA_PATH` is **authoritative**: the evaluator fails
`app.locate` when the app is not under it and never falls back to the global
`~/Library/Developer/Xcode/DerivedData`, so a stale binary from an unrelated
build cannot satisfy the run.

## Two-device exception (manual, exclusive)

`scripts/qa/two-sim-friend-loop.sh` drives **two** simulators at once for the
Friends/Companion social graph. It is an explicit manual integration exception,
**not** a daily gate, and it is **enforced** as an exclusive reservation:

- It requires an explicit `SIM_B`; there is no automatic second-device default.
- It requires a non-empty `DEV_IOS_REASON` before it mutates anything.
- It takes the **same machine-wide `shlock`** as `dev-ios-session`
  (`/usr/bin/shlock` on `IOS_AUTOMATION_LOCK_FILE`, default
  `/tmp/ios-automation.xcodebuild.lock`) before any Simulator mutation and
  **fails busy** instead of racing another project. It refuses to run inside
  an owned single-device session.
- It requires the shared allowlist to exist: a missing or empty allowlist
  **fails closed** before the lock or any simulator interaction — it is never
  silently skipped. Both selected devices must be members.
- It rejects any other active simulator instead of shutting it down.
- A `simctl bootstatus` failure aborts the run (after cleanup) instead of
  continuing against a device that never became ready.
- It snapshots the selected devices' initial states and, on exit/interrupt,
  shuts down only the devices it started. It never runs `shutdown all`, never
  shuts down a borrowed or foreign device, and releases the lock only while it
  still owns it.

The harness needs macOS (`/usr/bin/shlock`); its lock tests are marked
macOS-only accordingly.

```bash
ARTIFACT_ROOT="$(dev-storage-guard new-artifact solo-compass-ios-qa)"
DEV_IOS_REASON="US-027 friend loop manual regression" \
  SIM_A="iPhone 17 Pro" SIM_B="iPhone SE (3rd generation)" \
  ARTIFACTS="$ARTIFACT_ROOT/two-sim-friend-loop" \
  scripts/qa/two-sim-friend-loop.sh
```

## Verification

`python3 -m unittest discover -s scripts/ios -p 'test_*.py' -v` runs the
policy tests with subprocess fakes (every simulator tool is a fake on `PATH`),
so it never touches a real Simulator.

Where they run:

- `.github/workflows/ci.yml` (Linux build job) runs the portable tests and
  the `bash -n` syntax checks.
- `.github/workflows/ios-ci.yml` (macOS SwiftLint job) runs the **full suite
  with skips disallowed**, so the macOS-only tests actually execute there.

A skipped test is never counted as passed: on Linux the macOS-only tests
(helper reexec, `/usr/bin/shlock` reservation) skip with their exact
requirement and must be green on the macOS job.

These runs verify the policy scripts only. They do **not** verify the
SoloCompass app or its UI: journey taps/asserts are recorded as unfulfilled
(no XCUITest backend yet) and screenshots are evidence for human review, not
an automated app/UI verdict.

## Related

- [`docs/CI_TEST_MATRIX.md`](../CI_TEST_MATRIX.md) — what CI runs.
- [`AGENTS.md`](../../AGENTS.md) Testing section — the short version.
