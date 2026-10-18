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
#      SIMULATOR_UDID / DEV_IOS_PROFILE=primary|compact|ipad. Before the
#      helper is invoked, the selection env is normalized to the helper's
#      strict contract (ios_session_prepare_helper_selection): profile
#      aliases (daily -> primary) resolved and explicit device names
#      canonicalized to UDIDs via one read-only inventory read. Nesting is
#      decided by `is-owner` (a true ancestor owns the lock), never by
#      trusting env alone.
#
#   2. Deterministic selection via scripts/ios/select-simulator.py. Explicit
#      IOS_SIMULATOR_ID / SIMULATOR_UDID are honored and validated against
#      the live inventory; otherwise the best available numbered iPhone is
#      chosen. Booted SE/iPad devices are ignored.
#
#   3. Fail-closed handling when the required local macOS helper is missing or
#      unusable. Only CI and non-macOS hosts use the portable fallback.
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

# Echo the UDID assigned to a helper profile in the shared tab-separated
# allowlist. A missing entry is left empty: unique names can still be
# canonicalized, while duplicate names fail closed in the selector.
ios_session_profile_allowlisted_udid() {
  local profile="$1" label path
  case "$profile" in
    primary) label="Primary iPhone" ;;
    compact) label="Compact iPhone" ;;
    ipad) label="iPad" ;;
    *) return 0 ;;
  esac
  path="${DEV_IOS_ALLOWLIST:-${HOME:-}/.config/dev-storage-guard/simulator-allowlist.tsv}"
  [[ -r "$path" ]] || return 0
  awk -F '\t' -v label="$label" '
    $2 == label && $1 !~ /^[[:space:]]*#/ && $1 != "" { print $1; exit }
  ' "$path"
}

# Prepare the selection env for the host helper's strict resolve_selection
# contract before is-owner/run. Read-only: the only host touch is one
# `simctl list` inventory read used to canonicalize explicit names to UDIDs.
# Device policy (allowlist membership, family, availability) stays with the
# host helper.
#
#   * DEV_IOS_PROFILE is normalized (case/whitespace; daily -> primary) and
#     must resolve to primary|compact|ipad.
#   * Explicit IOS_SIMULATOR_ID / SIMULATOR_UDID (UDID or exact device name)
#     are canonicalized to UDIDs, must agree with each other, and are both
#     exported as UDIDs so the helper can validate them against its allowlist.
#   * With no explicit selection nothing is exported: the helper's allowlist
#     selection stays authoritative — we never pre-pick an inventory device.
ios_session_prepare_helper_selection() {
  local profile raw_id raw_owner
  profile="$(printf '%s' "${DEV_IOS_PROFILE:-}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  case "$profile" in
    "") profile="primary" ;;
    daily) profile="primary" ;;
    primary | compact | ipad) ;;
    *)
      printf "error: unknown profile '%s' (expected one of primary, compact, ipad; daily is an alias for primary)\n" "${DEV_IOS_PROFILE:-}" >&2
      return 1
      ;;
  esac
  export DEV_IOS_PROFILE="$profile"

  raw_id="${IOS_SIMULATOR_ID:-}"
  raw_owner="${SIMULATOR_UDID:-}"
  if [[ -z "$raw_id" && -z "$raw_owner" ]]; then
    return 0
  fi

  local selector="${REPO_ROOT:-$(pwd)}/scripts/ios/select-simulator.py"
  if [[ ! -f "$selector" ]]; then
    printf 'error: simulator selector missing at %s\n' "$selector" >&2
    return 1
  fi
  local inventory
  if ! inventory="$(xcrun simctl list devices available --json 2>/dev/null)"; then
    printf 'error: could not read the simulator inventory to canonicalize IOS_SIMULATOR_ID/SIMULATOR_UDID\n' >&2
    return 1
  fi
  local allowlisted_udid="" udid_id="" udid_owner=""
  allowlisted_udid="$(ios_session_profile_allowlisted_udid "$profile")" || return 1
  if [[ -n "$raw_id" ]]; then
    local -a id_args=(--resolve "$raw_id")
    [[ -n "$allowlisted_udid" ]] && id_args+=(--allowlisted-udid "$allowlisted_udid")
    udid_id="$(printf '%s' "$inventory" | python3 "$selector" "${id_args[@]}")" || return 1
  fi
  if [[ -n "$raw_owner" ]]; then
    local -a owner_args=(--resolve "$raw_owner")
    [[ -n "$allowlisted_udid" ]] && owner_args+=(--allowlisted-udid "$allowlisted_udid")
    udid_owner="$(printf '%s' "$inventory" | python3 "$selector" "${owner_args[@]}")" || return 1
  fi
  if [[ -n "$udid_id" && -n "$udid_owner" && "$udid_id" != "$udid_owner" ]]; then
    printf 'error: IOS_SIMULATOR_ID and SIMULATOR_UDID disagree; refusing to substitute a device\n' >&2
    return 1
  fi
  local resolved="${udid_id:-$udid_owner}"
  export IOS_SIMULATOR_ID="$resolved"
  export SIMULATOR_UDID="$resolved"
  return 0
}

# Reexec the entrypoint inside the owned helper session when required.
#
# Usage: ios_session_reexec_if_needed <absolute-entrypoint> [args...]
#
# CI (true/1) and non-macOS hosts never resolve or run the helper. Outside CI,
# local macOS requires the helper so no Simulator or xcodebuild operation can
# bypass the machine-wide lock.
ios_session_reexec_if_needed() {
  local entrypoint="$1"
  shift
  ios_session_ci_truthy && return 0
  [[ "$(uname -s 2>/dev/null || echo unknown)" == "Darwin" ]] || return 0
  if ! ios_session_helper_init; then
    exit 2
  fi
  if [[ -z "$IOS_SESSION_HELPER" ]]; then
    printf 'error: dev-ios-session is required for local macOS iOS work\n' >&2
    printf '       install it at ~/.local/bin/dev-ios-session or set DEV_IOS_SESSION_BIN\n' >&2
    exit 2
  fi
  # Speak the helper's strict selection contract before touching it: profile
  # aliases normalized and explicit names canonicalized to UDIDs (one
  # read-only inventory read), IOS_SIMULATOR_ID/SIMULATOR_UDID agreement
  # enforced. Mismatched or bogus selections fail here — before is-owner or
  # run — and an empty selection keeps the helper's authoritative allowlist
  # selection. No mutation happens before the helper session is acquired.
  if ! ios_session_prepare_helper_selection; then
    exit 2
  fi
  if "$IOS_SESSION_HELPER" is-owner >/dev/null 2>&1; then
    return 0
  fi
  printf '→ acquiring shared iOS session via %s\n' "$IOS_SESSION_HELPER" >&2
  exec "$IOS_SESSION_HELPER" run -- "$entrypoint" "$@"
}

# Enforce a nonempty DEV_IOS_REASON for auxiliary profiles in the portable
# fallback.
#
# An owned host-helper session enforces this itself (dev-ios-session refuses
# compact|ipad without a nonempty --reason/DEV_IOS_REASON). In every other
# non-CI path, including non-macOS hosts where a helper binary merely happens
# to exist, the portable fallback applies the same rule. `daily` is the primary
# alias and never needs a reason.
ios_session_require_aux_reason() {
  ios_session_ci_truthy && return 0
  local platform
  platform="$(uname -s 2>/dev/null || echo unknown)"
  if [[ "$platform" == "Darwin" ]]; then
    if ! ios_session_helper_init; then
      return 1
    fi
    if [[ -n "$IOS_SESSION_HELPER" ]] \
        && "$IOS_SESSION_HELPER" is-owner >/dev/null 2>&1; then
      return 0
    fi
  fi
  local profile
  profile="$(printf '%s' "${DEV_IOS_PROFILE:-}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  [[ "$profile" == "daily" ]] && profile="primary"
  case "$profile" in
    compact | ipad)
      if [[ -z "${DEV_IOS_REASON:-}" || -z "${DEV_IOS_REASON//[[:space:]]/}" ]]; then
        printf 'error: DEV_IOS_PROFILE=%s selects a secondary simulator and requires\n' "$profile" >&2
        printf '       a nonempty DEV_IOS_REASON (the host helper enforces this;\n' >&2
        printf '       the portable fallback does too when the helper is absent)\n' >&2
        return 1
      fi
      ;;
  esac
  return 0
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
# both the caller-selected and helper-owned device. Auxiliary profiles are
# reason-checked first (see ios_session_require_aux_reason).
ios_select_simulator_json() {
  local preferred="${1:-iPhone 17 Pro}"
  ios_session_require_aux_reason || return 1
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
