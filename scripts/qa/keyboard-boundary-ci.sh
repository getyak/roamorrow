#!/usr/bin/env bash
# Discovery only: the unchanged complete iOS gate remains required separately.
set -euo pipefail
if [[ "${GITHUB_ACTIONS:-}" != true ]]; then
  echo "Keyboard boundary replay is restricted to an owned CI runner" >&2
  exit 2
fi
: "${SIMULATOR_UDID:?}" "${RUNNER_TEMP:?}" "${GITHUB_WORKSPACE:?}"
KEYBOARD_BOUNDARY_ROOT="$RUNNER_TEMP/keyboard-boundary"
python3 - "$RUNNER_TEMP" "$KEYBOARD_BOUNDARY_ROOT" "$SIMULATOR_UDID" <<'PY'
from pathlib import Path
import sys, uuid
root = Path(sys.argv[1]).resolve(strict=True)
assert Path(sys.argv[2]).resolve().is_relative_to(root)
uuid.UUID(sys.argv[3])
PY
mkdir -p "$KEYBOARD_BOUNDARY_ROOT"
cd "$GITHUB_WORKSPACE/apps/ios"
xcodebuild build-for-testing -project SoloCompass.xcodeproj -scheme CompanionAcceptance \
  -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" \
  -derivedDataPath "$KEYBOARD_BOUNDARY_ROOT/DerivedData" \
  -configuration Debug CODE_SIGNING_ALLOWED=NO 2>&1 | tee "$KEYBOARD_BOUNDARY_ROOT/build.log"

# Initialize the real app/preferences via the existing guest/login UI cases.
xcodebuild test-without-building -project SoloCompass.xcodeproj -scheme CompanionAcceptance \
  -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" \
  -derivedDataPath "$KEYBOARD_BOUNDARY_ROOT/DerivedData" \
  -only-testing:CompanionAcceptanceUITests/AccountOnboardingUITests \
  -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 60 \
  -maximum-test-execution-time-allowance 120 -configuration Debug CODE_SIGNING_ALLOWED=NO \
  -resultBundlePath "$KEYBOARD_BOUNDARY_ROOT/bootstrap.xcresult" \
  2>&1 | tee "$KEYBOARD_BOUNDARY_ROOT/bootstrap.log"

cd "$GITHUB_WORKSPACE"
xcrun simctl bootstatus "$SIMULATOR_UDID" -b
KEYBOARD_APP_CONTAINER="$(xcrun simctl get_app_container "$SIMULATOR_UDID" com.solocompass.app data)"
python3 scripts/qa/seed-v4-ui-fixture.py --container "$KEYBOARD_APP_CONTAINER" \
  --receipt "$KEYBOARD_BOUNDARY_ROOT/public-fixture/receipt.json"
xcrun simctl shutdown "$SIMULATOR_UDID"
python3 scripts/qa/seed-chat-performance-fixture.py --container "$KEYBOARD_APP_CONTAINER" \
  --receipt "$KEYBOARD_BOUNDARY_ROOT/empty/fixture.json"
xcrun simctl bootstatus "$SIMULATOR_UDID" -b
xcrun simctl ui "$SIMULATOR_UDID" appearance light
xcrun simctl ui "$SIMULATOR_UDID" content_size large
xcrun simctl spawn "$SIMULATOR_UDID" log stream --level debug --style compact \
  --predicate 'subsystem == "com.solocompass.chat-scroll" OR subsystem == "com.solocompass.audio-lifecycle"' \
  > "$KEYBOARD_BOUNDARY_ROOT/scroll-intent.log" 2>&1 &
KEYBOARD_TRACE_PID=$!
trap 'kill "$KEYBOARD_TRACE_PID" 2>/dev/null || true; wait "$KEYBOARD_TRACE_PID" 2>/dev/null || true' EXIT
cd apps/ios
xcodebuild test-without-building -project SoloCompass.xcodeproj -scheme CompanionAcceptance \
  -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" \
  -derivedDataPath "$KEYBOARD_BOUNDARY_ROOT/DerivedData" \
  -only-testing:CompanionAcceptanceUITests/ChatAndMeUITests/testColdLongHistoryScrollWithoutKeyboard \
  -only-testing:CompanionAcceptanceUITests/ChatAndMeUITests/testLongHistoryNativeScrollingMetrics \
  -only-testing:CompanionAcceptanceUITests/ChatAndMeUITests/testLongHistoryScrollAndSendRetainTheNewDraftAndKeyboard \
  -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 180 \
  -maximum-test-execution-time-allowance 240 -configuration Debug CODE_SIGNING_ALLOWED=NO \
  -resultBundlePath "$KEYBOARD_BOUNDARY_ROOT/diagnostic.xcresult" \
  2>&1 | tee "$KEYBOARD_BOUNDARY_ROOT/diagnostic.log"
