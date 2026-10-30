#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${COMPANION_CHAT_ARTIFACT_DIR:?Set a registered task artifact directory}"
mkdir -p "$OUT"
IOS="$ROOT/apps/ios/SoloCompass"
CORE="$IOS/Services/AgentRuntime"
SOURCES=(
  "$CORE/AgentRuntimeModels.swift" "$CORE/AgentToolPolicy.swift"
  "$CORE/AgentMemory.swift" "$IOS/Views/CompanionHome/CompanionHomeModels.swift"
  "$IOS/Views/CompanionHome/CompanionMediaModels.swift"
  "$IOS/Views/CompanionHome/CompanionTimeline.swift" "$IOS/Services/CompanionHomeStore.swift"
  "$ROOT/scripts/qa/companion-chat-host-boundaries.swift" "$ROOT/scripts/qa/companion-chat-host.swift"
)
for file in "$IOS/Services/CompanionSnapshotWriter.swift" "$IOS/Services/CompanionHistoryEncoder.swift" "$IOS/Views/CompanionHome/CompanionScrollIntent.swift"; do
  if [[ -f "$file" ]]; then SOURCES+=("$file"); fi
done
swiftc -O -swift-version 5 -strict-concurrency=complete -warnings-as-errors -parse-as-library \
  "${SOURCES[@]}" \
  -o "$OUT/companion-chat-host" > "$OUT/compile.log" 2>&1 || { cat "$OUT/compile.log"; exit 1; }
"$OUT/companion-chat-host" "$OUT" 2>&1 | tee "$OUT/run.log"
if [[ "${COMPANION_CHAT_TYPECHECK_TESTS:-0}" == 1 ]]; then
  swiftc -swift-version 5 -strict-concurrency=complete -warnings-as-errors -parse-as-library \
    -emit-module -enable-testing -module-name SoloCompass "${SOURCES[@]}" \
    -emit-module-path "$OUT/SoloCompass.swiftmodule" > "$OUT/module.log" 2>&1 || { cat "$OUT/module.log"; exit 1; }
  MAC_PLATFORM="$(xcrun --sdk macosx --show-sdk-platform-path)"
  FRAMEWORKS="$MAC_PLATFORM/Developer/Library/Frameworks"
  swiftc -swift-version 5 -strict-concurrency=complete -warnings-as-errors -typecheck \
    -F "$FRAMEWORKS" -I "$MAC_PLATFORM/Developer/usr/lib" -I "$OUT" \
    "$IOS/Tests/CompanionChatPerformanceTests.swift" "$IOS/Tests/CompanionHomeDataManagementTests.swift" \
    > "$OUT/xctest-typecheck.log" 2>&1 || { tail -80 "$OUT/xctest-typecheck.log"; exit 1; }
fi
