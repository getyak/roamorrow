#!/usr/bin/env bash
set -euo pipefail
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo 'This host check requires macOS SwiftData.' >&2
  exit 2
fi
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -n "${CHAT_HISTORY_ARTIFACT_DIR:-}" ]]; then
  OUT="$CHAT_HISTORY_ARTIFACT_DIR"
  mkdir -p "$OUT"
else
  OUT="$(mktemp -d "${TMPDIR:-/tmp}/chat-history-host.XXXXXX")"
  trap 'rm -f "$OUT/chat-history-host" "$OUT/compile.log"; rmdir "$OUT"' EXIT
fi
IOS="$ROOT/apps/ios/SoloCompass"
CORE="$IOS/Services/AgentRuntime"
if ! swiftc -swift-version 5 -strict-concurrency=complete -parse-as-library \
  "$IOS/Services/VoiceAgentSession.swift" "$IOS/Models/ChatDisplayText.swift" \
  "$IOS/Persistence/Models/ChatSessionRecord.swift" "$IOS/Persistence/Models/ChatMessageRecord.swift" \
  "$CORE/AgentRuntimeModels.swift" "$CORE/AgentToolPolicy.swift" \
  "$CORE/FileAgentExecutionJournal.swift" "$CORE/AgentMemory.swift" \
  "$IOS/Persistence/ChatHistoryStore.swift" "$ROOT/scripts/qa/chat-history-host.swift" \
  -o "$OUT/chat-history-host" >"$OUT/compile.log" 2>&1; then
  cat "$OUT/compile.log" >&2
  exit 1
fi
"$OUT/chat-history-host"
