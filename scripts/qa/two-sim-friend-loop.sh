#!/usr/bin/env bash
# two-sim-friend-loop.sh — US-027 end-to-end loop harness for the Friends /
# Companion social graph.
#
# Drives TWO iOS simulators side-by-side (User A "scanner" + User B "owner")
# through the full loop:
#
#   scan-add-friend -> friend invites to a meetup -> meetup builds a group
#   chat -> someone in the group taps [Add Friend] -> mutual upgrade ->
#   DM + push arrives
#
# WHY half-automated: on Xcode 26.4 / iOS 26.4, idb and AppleScript-driven
# taps are unreliable (idb Abort trap, no accessibility permission). Only
# `simctl boot/install/launch/screenshot/openurl/push` are stable. So this
# harness OWNS the deterministic plumbing — booting both sims, installing the
# build, injecting per-user identity + feature-flag env, capturing labelled
# screenshots, delivering APNs payloads, and (optionally) asserting backend
# rows over SQL — while the human tester performs the in-app taps following
# docs/qa/friend-companion-loop-regression.md. Each step prints a PROMPT and
# waits, then screenshots the result as evidence.
#
# This is intentionally NOT a pass/fail CI gate; it is a guided, reproducible
# manual-verification rig that leaves a screenshot trail under artifacts/.
#
# Usage:
#   DEV_IOS_REASON="..." SIM_B="iPhone 16" scripts/qa/two-sim-friend-loop.sh
#   FLAG=off DEV_IOS_REASON="..." SIM_B="iPhone 16" scripts/qa/two-sim-friend-loop.sh
#   SIM_A="iPhone 17 Pro" SIM_B="iPhone 16" DEV_IOS_REASON="..." scripts/qa/two-sim-friend-loop.sh
#
# SIM_B has NO automatic default: this harness boots TWO devices, so it is an
# explicit manual exception to the daily one-device policy and must name both
# devices. It takes the SAME machine-wide shlock as dev-ios-session
# (/tmp/ios-automation.xcodebuild.lock, override IOS_AUTOMATION_LOCK_FILE)
# before any Simulator mutation and fails busy rather than racing another
# project. It refuses to run inside an owned single-device session, requires
# the shared allowlist to exist (a missing or empty allowlist FAILS CLOSED —
# it is never silently skipped), validates both devices against it, and only
# shuts down devices this run actually booted. See docs/development/ios-testing.md.
#
# Required env (both modes):
#   SIM_B                             explicit second device (no default)
#   DEV_IOS_REASON                    non-empty justification (manual reservation)
# Required for the flag-on real-backend run:
#   SUPABASE_URL, SUPABASE_ANON_KEY   (User A + User B authed sessions)
# Optional:
#   DEV_IOS_ALLOWLIST   allowlist TSV (default ~/.config/dev-storage-guard/simulator-allowlist.tsv)
#   IOS_AUTOMATION_LOCK_FILE   override the machine-wide lock path
#   APP_PATH      path to a built SoloCompass.app (else assumed pre-installed)
#   PUSH_A_JSON / PUSH_B_JSON   APNs payload files for simulated push delivery
#   DATABASE_URL  psql connection string to assert friendships/conversations
#
set -uo pipefail

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUNDLE_ID="com.solocompass.app"
SIM_A="${SIM_A:-iPhone 17 Pro}"   # User A — the scanner (adds via friend code)
SIM_B="${SIM_B:-}"               # User B — code owner / meetup host (required)
FLAG="${FLAG:-on}"                # on => FF_COMPANION=1 ; off => 0
ARTIFACTS="${ARTIFACTS:-$ROOT/artifacts/two-sim-friend-loop/$(date +%Y%m%d-%H%M%S)}"
APP_PATH="${APP_PATH:-}"

# ---------------------------------------------------------------------------
# Pretty logging
# ---------------------------------------------------------------------------
c_reset=$'\033[0m'; c_blue=$'\033[34m'; c_green=$'\033[32m'
c_yellow=$'\033[33m'; c_red=$'\033[31m'; c_bold=$'\033[1m'
log()    { printf '%s[loop]%s %s\n' "$c_blue" "$c_reset" "$*"; }
ok()     { printf '%s[ ok ]%s %s\n' "$c_green" "$c_reset" "$*"; }
warn()   { printf '%s[warn]%s %s\n' "$c_yellow" "$c_reset" "$*"; }
err()    { printf '%s[fail]%s %s\n' "$c_red" "$c_reset" "$*" >&2; }
prompt() {
  printf '\n%s%s>>> MANUAL STEP:%s %s\n' "$c_bold" "$c_yellow" "$c_reset" "$*"
  printf '    Press [Enter] when done (or "s" + Enter to skip)... '
  read -r _ans
  [[ "${_ans:-}" == "s" ]] && { warn "skipped"; return 1; }
  return 0
}

# ---------------------------------------------------------------------------
# Pre-flight validation — before any mkdir/boot/install mutation.
# ---------------------------------------------------------------------------
if [[ -z "${SIM_B:-}" ]]; then
  err "SIM_B must be set explicitly, e.g. SIM_B=\"iPhone 16\"."
  err "This harness boots TWO devices; there is no automatic second-device default."
  err "List available devices: xcrun simctl list devices available"
  exit 1
fi
if [[ -z "${DEV_IOS_REASON:-}" ]]; then
  err "DEV_IOS_REASON is required: a two-device run takes an exclusive manual reservation."
  err "Example: DEV_IOS_REASON=\"US-027 friend loop manual regression\" $0"
  exit 1
fi

# The allowlist is mandatory. A missing or empty allowlist fails closed here,
# before the lock or any simulator interaction, instead of silently skipping
# membership validation later.
allowlist_path() {
  printf '%s' "${DEV_IOS_ALLOWLIST:-${HOME:-}/.config/dev-storage-guard/simulator-allowlist.tsv}"
}

allowlist_udids() {
  # $1 = allowlist path; echoes the non-comment UDID column.
  awk -F'\t' '!/^[[:space:]]*(#|$)/ {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1); if ($1 != "") print $1}' "$1"
}

check_allowlist() {
  local path allowed
  path="$(allowlist_path)"
  if [[ ! -f "$path" ]]; then
    err "simulator allowlist not found: $path"
    err "set DEV_IOS_ALLOWLIST or create the shared allowlist (UDID<TAB>label per line)."
    err "this two-device exception never runs without allowlist validation."
    return 1
  fi
  allowed="$(allowlist_udids "$path")"
  if [[ -z "$allowed" ]]; then
    err "simulator allowlist is empty: $path"
    return 1
  fi
  return 0
}

check_allowlist || exit 1

# ---------------------------------------------------------------------------
# Exclusive machine-wide reservation
# ---------------------------------------------------------------------------
# This harness is the explicit two-DEVICE exception. It cannot ride the
# single-device dev-ios-session lock, so it takes the SAME shlock itself,
# before any Simulator mutation, and fails busy rather than racing another
# project. See docs/development/ios-testing.md.
LOCK_FILE="${IOS_AUTOMATION_LOCK_FILE:-/tmp/ios-automation.xcodebuild.lock}"
SHLOCK_BIN="/usr/bin/shlock"
_CLEANUP_DONE=0
STARTED_A=0
STARTED_B=0
UDID_A=""
UDID_B=""

_refuse_if_owned_session() {
  # If we are already inside an owned dev-ios-session, the single-device lock
  # is held by an ancestor; a dual-device run must not proceed.
  local helper="${DEV_IOS_SESSION_BIN:-${DEV_IOS_SESSION_HELPER:-}}"
  [[ -n "$helper" ]] || helper="${HOME:-}/.local/bin/dev-ios-session"
  if [[ -x "$helper" ]] && "$helper" is-owner >/dev/null 2>&1; then
    err "refusing to run the two-device harness inside an owned dev-ios-session."
    err "Exit the shared session first; this harness is a manual exclusive exception."
    exit 1
  fi
}

lock_owner() {
  # Echo the pid recorded in the lock file (empty when absent/unreadable).
  [[ -f "$LOCK_FILE" ]] || return 0
  head -n1 "$LOCK_FILE" 2>/dev/null | tr -d '[:space:]'
}

release_lock() {
  # Ownership-checked: remove only a lock this process actually holds.
  local owner
  owner="$(lock_owner)"
  if [[ -n "$owner" && "$owner" == "$$" ]]; then
    rm -f "$LOCK_FILE"
  fi
}

cleanup() {
  local original_status=$? cleanup_failed=0
  [[ "$_CLEANUP_DONE" == "1" ]] && return 0
  _CLEANUP_DONE=1
  trap - EXIT
  trap '' INT TERM
  # Only shut down devices THIS run started; never `shutdown all`, never a
  # borrowed/foreign device.
  if [[ "$STARTED_A" == "1" && -n "$UDID_A" ]]; then
    log "shutting down $SIM_A ($UDID_A) because this run booted it"
    if ! xcrun simctl shutdown "$UDID_A" >/dev/null 2>&1; then
      err "could not shut down session-started device $UDID_A"
      cleanup_failed=1
    fi
  fi
  if [[ "$STARTED_B" == "1" && -n "$UDID_B" ]]; then
    log "shutting down $SIM_B ($UDID_B) because this run booted it"
    if ! xcrun simctl shutdown "$UDID_B" >/dev/null 2>&1; then
      err "could not shut down session-started device $UDID_B"
      cleanup_failed=1
    fi
  fi
  release_lock
  if [[ "$original_status" == "0" && "$cleanup_failed" == "1" ]]; then
    original_status=70
  fi
  exit "$original_status"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

_refuse_if_owned_session

if [[ ! -x "$SHLOCK_BIN" ]]; then
  err "shlock not found at $SHLOCK_BIN — cannot reserve $LOCK_FILE exclusively"
  exit 1
fi
if ! "$SHLOCK_BIN" -f "$LOCK_FILE" -p "$$"; then
  owner="$(lock_owner)"
  err "another iOS session already holds $LOCK_FILE (owner pid ${owner:-unknown})."
  err "This two-device harness needs the machine-wide reservation; retry once it is free."
  exit 1
fi
if [[ "$(lock_owner)" != "$$" ]]; then
  err "failed to take ownership of $LOCK_FILE"
  exit 1
fi
ok "holding exclusive reservation $LOCK_FILE (pid $$) for this manual dual-device run"

mkdir -p "$ARTIFACTS"

# ---------------------------------------------------------------------------
# Simulator helpers
# ---------------------------------------------------------------------------
command -v jq >/dev/null 2>&1 || { err "missing dependency: jq"; exit 1; }

# Snapshot the live inventory once, after the exclusive reservation is held.
SIMCTL_JSON="$(xcrun simctl list devices available -j 2>/dev/null || printf '{}')"

udid_for() {
  # $1 = device name; echoes the first matching available UDID.
  printf '%s' "$SIMCTL_JSON" | jq -r --arg n "$1" '
    .devices | to_entries[] | .value[] | select(.name == $n) | .udid' \
    | head -n1
}

state_for() {
  # $1 = UDID; echoes its current state (empty when unknown).
  printf '%s' "$SIMCTL_JSON" | jq -r --arg u "$1" '
    .devices | to_entries[] | .value[] | select(.udid == $u) | .state' \
    | head -n1
}

validate_allowlist() {
  # Both selected devices must be in the shared allowlist. The allowlist is
  # never optional: check_allowlist fails closed in pre-flight when the file
  # is missing or empty.
  local path allowed udid missing=0
  check_allowlist || return 1
  path="$(allowlist_path)"
  allowed="$(allowlist_udids "$path")"
  for udid in "$UDID_A" "$UDID_B"; do
    if ! grep -qxF "$udid" <<<"$allowed"; then
      err "selected device $udid is not in the allowlist ($path)"
      missing=1
    fi
  done
  if [[ "$missing" == "1" ]]; then
    err "allowlisted devices: $(tr '\n' ' ' <<<"$allowed")"
    return 1
  fi
  return 0
}

ensure_no_foreign_active() {
  # Reject (never shut down) any active device other than the two selected.
  local active line
  active="$(printf '%s' "$SIMCTL_JSON" | jq -r --arg a "$UDID_A" --arg b "$UDID_B" '
    .devices | to_entries[] | .value[]
    | select(.udid != $a and .udid != $b and .state != "Shutdown")
    | "\(.name) (\(.udid), \(.state))"' | sort)"
  if [[ -n "$active" ]]; then
    err "refusing to start while other simulators are active:"
    while IFS= read -r line; do
      [[ -n "$line" ]] && err "  $line"
    done <<<"$active"
    err "shut them down yourself; this harness never shuts down devices it does not own."
    return 1
  fi
  return 0
}

boot_sim() {
  # $1 udid, $2 name, $3 user-label (A|B). Records devices THIS run starts so
  # cleanup only ever shuts those down.
  local udid="$1" name="$2" who="$3"
  if [[ -z "$udid" ]]; then
    err "no available simulator named '$name' — run: xcrun simctl list devices available"
    exit 1
  fi
  local state
  state="$(state_for "$udid")"
  if [[ "$state" == "Shutdown" ]]; then
    log "booting $name ($udid)"
    # Register lifecycle responsibility before boot: a pending signal may run
    # the EXIT trap immediately when the foreground simctl command returns.
    if [[ "$who" == "A" ]]; then
      STARTED_A=1
    else
      STARTED_B=1
    fi
    if ! xcrun simctl boot "$udid"; then
      err "could not boot selected device $udid"
      exit 1
    fi
  elif [[ "$state" == "Booted" ]]; then
    ok "$name already booted (borrowed; left running at closeout)"
  else
    err "selected device $udid is in transitional or unknown state: $state"
    exit 1
  fi
}

install_app() {
  local udid="$1"
  if [[ -z "$APP_PATH" ]]; then
    warn "APP_PATH not set; assuming app already installed on $udid (build it first)"
    return 0
  fi
  log "installing app on $udid"
  xcrun simctl install "$udid" "$APP_PATH"
}

launch_app() {
  # $1 udid, $2 user-label (A|B). Injects feature-flag + backend env.
  local udid="$1" who="$2"
  local -a env_args=()
  if [[ "$FLAG" == "on" ]]; then
    env_args+=("SIMCTL_CHILD_FF_COMPANION=1")
    env_args+=("SIMCTL_CHILD_SUPABASE_URL=${SUPABASE_URL:-}")
    env_args+=("SIMCTL_CHILD_SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY:-}")
  else
    # flag-off: FF_COMPANION != "1"; app must stay local-only & not crash.
    env_args+=("SIMCTL_CHILD_FF_COMPANION=0")
  fi
  log "launching User $who on $udid (FLAG=$FLAG)"
  env "${env_args[@]}" xcrun simctl launch "$udid" "$BUNDLE_ID" >/dev/null 2>&1 \
    || warn "launch returned non-zero (app may already be foreground)"
}

shot() {
  # $1 udid, $2 label. Captures a labelled PNG under ARTIFACTS.
  local udid="$1" label="$2"
  local out="$ARTIFACTS/${label}.png"
  if xcrun simctl io "$udid" screenshot "$out" >/dev/null 2>&1; then
    ok "screenshot: ${out#"$ROOT"/}"
  else
    warn "screenshot failed for $label"
  fi
}

push() {
  # $1 udid, $2 payload-file. Simulated APNs delivery (works in Simulator).
  local udid="$1" payload="$2"
  if [[ -z "$payload" || ! -f "$payload" ]]; then
    warn "no APNs payload for push step — deliver a real push from the backend instead"
    return 1
  fi
  log "delivering simulated push to $udid"
  xcrun simctl push "$udid" "$BUNDLE_ID" "$payload"
}

sql_assert() {
  # $1 = human label, $2 = SQL returning a count; passes if count > 0.
  local label="$1" query="$2"
  if [[ -z "${DATABASE_URL:-}" ]]; then
    warn "DATABASE_URL unset — skipping backend assert: $label"
    return 0
  fi
  if ! command -v psql >/dev/null 2>&1; then
    warn "psql not found — skipping backend assert: $label"
    return 0
  fi
  local n
  n="$(psql "$DATABASE_URL" -tAc "$query" 2>/dev/null | tr -d '[:space:]')"
  if [[ "${n:-0}" -gt 0 ]]; then
    ok "backend assert PASS ($label): count=$n"
  else
    err "backend assert FAIL ($label): count=${n:-0}"
  fi
}

# ---------------------------------------------------------------------------
# Reservation held: resolve, validate, then mutate
# ---------------------------------------------------------------------------
log "US-027 two-sim friend loop — FLAG=$FLAG (reason: $DEV_IOS_REASON)"
log "artifacts -> $ARTIFACTS"
if [[ "$FLAG" == "on" && ( -z "${SUPABASE_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" ) ]]; then
  err "FLAG=on requires SUPABASE_URL and SUPABASE_ANON_KEY for the real-backend run"
  err "for the local no-crash smoke test run: FLAG=off $0"
  exit 1
fi

UDID_A="$(udid_for "$SIM_A")"
UDID_B="$(udid_for "$SIM_B")"
[[ -n "$UDID_A" ]] || { err "no available simulator named '$SIM_A'"; exit 1; }
[[ -n "$UDID_B" ]] || { err "no available simulator named '$SIM_B'"; exit 1; }
if [[ "$UDID_A" == "$UDID_B" ]]; then
  err "SIM_A and SIM_B resolve to the same device ($UDID_A); choose two distinct devices"
  exit 1
fi
validate_allowlist || exit 1
ensure_no_foreign_active || exit 1

boot_sim "$UDID_A" "$SIM_A" "A"
boot_sim "$UDID_B" "$SIM_B" "B"
for _ready in "$UDID_A" "$UDID_B"; do
  # Readiness gate: a bootstatus failure must abort (with cleanup), never be
  # hidden while the run keeps installing/launching against a dead device.
  if ! xcrun simctl bootstatus "$_ready" -b >/dev/null 2>&1; then
    err "simulator $_ready never became ready (simctl bootstatus failed)"
    exit 1
  fi
done

install_app "$UDID_A"
install_app "$UDID_B"
launch_app "$UDID_A" "A"
launch_app "$UDID_B" "B"
sleep 4
shot "$UDID_A" "00-A-launch"
shot "$UDID_B" "00-B-launch"

# ---------------------------------------------------------------------------
# FLAG-OFF short-circuit: only verify no-crash + local-only behaviour.
# ---------------------------------------------------------------------------
if [[ "$FLAG" == "off" ]]; then
  warn "FLAG=off run — verifying the app does NOT crash with Companion disabled."
  prompt "On BOTH sims: open Me sheet, try to reach Friends/Add Friend. Confirm the gated entry points are hidden OR no-op, and neither app crashes." || true
  shot "$UDID_A" "01-A-flagoff-me"
  shot "$UDID_B" "01-B-flagoff-me"
  ok "flag-off no-crash pass — see $ARTIFACTS"
  exit 0
fi

# ---------------------------------------------------------------------------
# FLAG-ON full loop (real backend)
# ---------------------------------------------------------------------------

# Step 1 — User B reveals friend code; User A scans/redeems it.
prompt "User B ($SIM_B): Me sheet -> Add Friend -> show MY friend code (QR + text). User A ($SIM_A): Add Friend -> Scan/Enter B's code -> redeem." || true
shot "$UDID_B" "10-B-friend-code"
shot "$UDID_A" "11-A-redeemed"
sql_assert "friendship A<->B exists" \
  "select count(*) from public.friendships where status in ('accepted','active');"

# Step 2 — B invites A to a meetup (route companion), which spins up a group chat.
prompt "User B: open a Route -> Invite friends -> select User A -> send meetup invite. User A: accept the meetup invite." || true
shot "$UDID_B" "20-B-invite-sent"
shot "$UDID_A" "21-A-invite-accepted"
# Backend has no conversations.type column (it's an iOS-model field). A route
# group chat is keyed by an accepted companion_request whose conversation has
# >1 participant. Assert a multi-party conversation exists instead.
sql_assert "group conversation created" \
  "select count(*) from public.conversations where jsonb_array_length(participant_ids) > 1;"
shot "$UDID_A" "22-A-group-chat"
shot "$UDID_B" "23-B-group-chat"

# Step 3 — In the group chat, someone taps [Add Friend] on the OTHER member -> mutual upgrade.
prompt "In the GROUP CHAT, tap [+ Add Friend] on the other participant's row/avatar. Other side: accept -> mutual friendship upgrade." || true
shot "$UDID_A" "30-A-addfriend-in-group"
shot "$UDID_B" "31-B-addfriend-accept"

# Step 4 — Mutual friends can now open a direct (friendDirect) DM thread.
prompt "Open the now-mutual friend's profile -> Message -> send a DM. Confirm a direct (1:1) thread opens (requestId is nil for friendDirect)." || true
shot "$UDID_A" "40-A-dm-sent"
# friendDirect DMs are backed by a Friendship, not a companion_request, so the
# backend marks them with request_id IS NULL (migration 0008 relaxed the NOT
# NULL). That is the durable backend signal for a direct thread.
sql_assert "friendDirect DM thread exists (request_id is null)" \
  "select count(*) from public.conversations where request_id is null;"

# Step 5 — Push arrives on the recipient (message-notify -> APNs).
log "Waiting for the message-notify Edge Function to deliver a push to User B..."
if ! push "$UDID_B" "${PUSH_B_JSON:-}"; then
  prompt "Confirm the real push notification from 'message-notify' arrives on User B's lock screen / banner." || true
fi
shot "$UDID_B" "50-B-push-received"

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
ok "End-to-end loop walk complete."
log "Evidence: $ARTIFACTS"
log "Fill in pass/fail in docs/qa/friend-companion-loop-regression.md"
