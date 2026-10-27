#!/usr/bin/env bash
# One allowlisted device, one build, affected tests only. Run inside dev-ios-session.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARTIFACT_ROOT="${1:?Pass a directory created by dev-storage-guard new-artifact}"
source "$ROOT/scripts/ios/session.sh"
ios_session_reexec_if_needed "$0" "$@"
[[ -n "${IOS_SIMULATOR_ID:-}" ]] || { echo 'An owned iOS session is required' >&2; exit 2; }
[[ -d "$ARTIFACT_ROOT" ]] || { echo 'Artifact directory does not exist' >&2; exit 2; }
ARTIFACT_ROOT="$(cd "$ARTIFACT_ROOT" && pwd -P)"
grep -Fxq "$ARTIFACT_ROOT" "$HOME/.local/state/dev-storage-guard/artifacts.list" \
    || { echo 'Artifact directory is not registered' >&2; exit 2; }
export IOS_DERIVED_DATA_PATH="$ARTIFACT_ROOT/DerivedData"
# The host xcodebuild wrapper uses this value even when -jobs is supplied.
export IOS_XCODE_JOBS=2
cd "$ROOT/apps/ios"
xcodegen generate >"$ARTIFACT_ROOT/project-generation.log" 2>&1
ARGS=(-project SoloCompass.xcodeproj -scheme AccountAcceptance
    -destination "platform=iOS Simulator,id=$IOS_SIMULATOR_ID"
    -derivedDataPath "$IOS_DERIVED_DATA_PATH" -jobs 2
    -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1
    -only-testing:AccountRegressionTests
    -only-testing:CompanionAcceptanceUITests/AccountOnboardingUITests
    CODE_SIGNING_ALLOWED=NO)
echo 'Building the real app and affected test bundles (2 jobs, 1 device).'
xcodebuild build-for-testing "${ARGS[@]}" >"$ARTIFACT_ROOT/build.log" 2>&1
echo 'Running affected native tests from that build.'
xcodebuild test-without-building "${ARGS[@]}" \
    -resultBundlePath "$ARTIFACT_ROOT/AccountAcceptance.xcresult" >"$ARTIFACT_ROOT/test.log" 2>&1
echo 'Native account acceptance completed; result bundle is in the registered directory.'
