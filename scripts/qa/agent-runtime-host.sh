#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -n "${AGENT_RUNTIME_ARTIFACT_DIR:-}" ]]; then
  OUT="$AGENT_RUNTIME_ARTIFACT_DIR"
  mkdir -p "$OUT"
else
  OUT="$(mktemp -d "${TMPDIR:-/tmp}/agent-runtime-host.XXXXXX")"
  trap 'rm -rf "$OUT"' EXIT
fi
CORE="$ROOT/apps/ios/SoloCompass/Services/AgentRuntime"
swiftc -swift-version 5 -strict-concurrency=complete -warnings-as-errors -parse-as-library \
  "$CORE/AgentRuntimeModels.swift" "$CORE/AgentToolPolicy.swift" \
  "$CORE/AgentToolExecutor.swift" "$CORE/FileAgentExecutionJournal.swift" \
  "$ROOT/scripts/qa/agent-runtime-host.swift" -o "$OUT/agent-runtime-host"
"$OUT/agent-runtime-host"
