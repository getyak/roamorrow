#!/usr/bin/env bash
# scripts/ios/session.sh — shared Solo Compass local-simulator session policy.
#
# Source this from any entrypoint that touches the iOS Simulator or runs a
# costly xcodebuild. It centralizes three things:
#
#   1. Reexec inside the shared host helper (dev-ios-session, installed at
#      ~/.local/bin/dev-ios-session; override with DEV_IOS_SESSION_BIN, or
#      DEV_IOS_SESSION_HELPER for the dev-storage-guard naming). On local
#      macOS, outside CI, an entrypoint that does NOT already own the shared
#      device reexecs itself via `dev-ios-session run -- <entrypoint>
#      <args...>` so the helper acquires /tmp/ios-automation.xcodebuild.lock
#      (override IOS_AUTOMATION_LOCK_FILE) and exports IOS_SIMULATOR_ID /
#      SIMULATOR_UDID / DEV_IOS_PROFILE=primary|compact|ipad. Nesting is
#      decided by `is-owner` (a true ancestor owns the lock), never by
#      trusting env alone.
#
#   2. Deterministic selection via scripts/ios/select-simulator.py. Explicit
#      IOS_SIMULATOR_ID / SIMULATOR_UDID are honored and validated against
#      the live inventory; otherwise the best available numbered iPhone is
#      chosen. Booted SE/iPad devices are ignored.
#
#   3. Fail-closed handling of an explicitly configured but unusable helper.
#
# See docs/development/ios-testing.md for the policy and examples.

if [[ -n "${_IOS_SESSION_SH_SOURCED:-}" ]]; then
  return 0
fi
_IOS_SESSION_SH_SOURCED=1

# Resolved helper path (empty when unavailable). Explicit-but-invalid helper
# configuration fails closed.
IOS_SESSION_HELPER=""

# True for CI values the host uses (true/1/yes/on). Both CI=true and CI=1 must
# skip the local helper so CI jobs never touch the shared device lock.
ios_session_ci_truthy() {
  case "$(printf '%s' "${CI:-}" | tr '[:upper:]' '[:lower:]')" in
    true | 1 | yes | on) return 0 ;;
    *) return 1 ;;
  esac
}

# Resolve the helper path. Explicit DEV_IOS_SESSION_BIN (or the
# dev-storage-guard DEV_IOS_SESSION_HELPER alias) that is not executable fails
# closed; otherwise dev-ios-session on PATH, then ~/.local/bin, is used.
ios_session_helper_init() {
  IOS_SESSION_HELPER=""
  local explicit="" label=""
  if [[ -n "${DEV_IOS_SESSION_BIN:-}" ]]; then
    explicit="$DEV_IOS_SESSION_BIN"
    label="DEV_IOS_SESSION_BIN"
  elif [[ -n "${DEV_IOS_SESSION_HELPER:-}" ]]; then
    explicit="$DEV_IOS_SESSION_HELPER"
    label="DEV_IOS_SESSION_HELPER"
  fi
  if [[ -n "$explicit" ]]; then
    if [[ ! -x "$explicit" ]]; then
      printf 'error: %s is set but not executable: %s\n' "$label" "$explicit" >&2
      return 1
    fi
    IOS_SESSION_HELPER="$explicit"
    return 0
  fi
  local on_path
  on_path="$(command -v dev-ios-session 2>/dev/null || true)"
  if [[ -n "$on_path" && -x "$on_path" ]]; then
    IOS_SESSION_HELPER="$on_path"
    return 0
  fi
  local default="${HOME:-}/.local/bin/dev-ios-session"
  if [[ -x "$default" ]]; then
    IOS_SESSION_HELPER="$default"
  fi
  return 0
}

# Reexec the entrypoint inside the owned helper session when required.
#
# Usage: ios_session_reexec_if_needed <absolute-entrypoint> [args...]
#
# CI (true/1) and non-macOS hosts never resolve or run the helper. Outside CI,
# an explicitly configured helper that is not executable fails clearly.
ios_session_reexec_if_needed() {
  local entrypoint="$1"
  shift
  ios_session_ci_truthy && return 0
  [[ "$(uname -s 2>/dev/null || echo unknown)" == "Darwin" ]] || return 0
  if ! ios_session_helper_init; then
    exit 2
  fi
  [[ -n "$IOS_SESSION_HELPER" ]] || return 0
  if "$IOS_SESSION_HELPER" is-owner >/dev/null 2>&1; then
    return 0
  fi
  printf '→ acquiring shared iOS session via %s\n' "$IOS_SESSION_HELPER" >&2
  exec "$IOS_SESSION_HELPER" run -- "$entrypoint" "$@"
}

# Echo one field of a selector JSON object.
ios_json_field() {
  # ios_json_field <json> <key>
  python3 -c 'import json, sys
d = json.loads(sys.argv[1])
v = d.get(sys.argv[2])
print("" if v is None else v)' "$1" "$2"
}

# Print the selector JSON for the current host.
#
# Usage: ios_select_simulator_json [preferred-name]
#
# Uses `xcrun simctl list devices available --json`; explicit IOS_SIMULATOR_ID,
# SIMULATOR_UDID and DEV_IOS_PROFILE are forwarded so the selector validates
# both the caller-selected and helper-owned device.
ios_select_simulator_json() {
  local preferred="${1:-iPhone 17 Pro}"
  local selector="${REPO_ROOT:-$(pwd)}/scripts/ios/select-simulator.py"
  if [[ ! -f "$selector" ]]; then
    printf 'error: simulator selector missing at %s\n' "$selector" >&2
    return 1
  fi
  local -a args=(--preferred "$preferred")
  [[ -n "${IOS_SIMULATOR_ID:-}" ]] && args+=(--explicit "$IOS_SIMULATOR_ID")
  [[ -n "${SIMULATOR_UDID:-}" ]] && args+=(--owner-udid "$SIMULATOR_UDID")
  [[ -n "${DEV_IOS_PROFILE:-}" ]] && args+=(--profile "$DEV_IOS_PROFILE")
  xcrun simctl list devices available --json 2>/dev/null \
    | python3 "$selector" "${args[@]}"
}

# Echo an xcodebuild `-destination` value for the selected simulator.
#
# Every device is resolved through the shared selector against the live
# inventory, so IOS_SIMULATOR_ID and SIMULATOR_UDID are both validated (and must
# agree), names are canonicalized to UDIDs, and a bogus or wrong-family device
# fails instead of producing an unusable `id=<name>` destination.
ios_xcodebuild_destination() {
  local preferred="${1:-iPhone 17 Pro}"
  local selected udid
  selected="$(ios_select_simulator_json "$preferred")" || return 1
  udid="$(ios_json_field "$selected" udid)" || return 1
  [[ -n "$udid" ]] || return 1
  printf 'id=%s' "$udid"
}
