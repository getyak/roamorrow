#!/usr/bin/env bash
# user-story-rubric — drive 10 solo-traveler user stories through the iOS
# simulator, screenshot each landing screen, and stage evidence for agent
# teams to score against the per-story aesthetic rubric.
#
# Depends on: xcrun simctl, jq, xcodebuild, an already-built .app.
#
# Fixtures: apps/ios/SoloCompass/Tests/fixtures/user_stories.json
# Evidence: apps/ios/rubric_evidence/user_stories/<story_id>/
#
# Convention matches scripts/sc-evaluator/run.sh (iPhone 17 Pro / iOS latest).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
FIXTURE="$REPO_ROOT/apps/ios/SoloCompass/Tests/fixtures/user_stories.json"
EVIDENCE_ROOT="$REPO_ROOT/apps/ios/rubric_evidence/user_stories"
APP_BUNDLE_ID="${SC_BUNDLE_ID:-com.solocompass.app}"
IOS_APP_DIR="$REPO_ROOT/apps/ios"

log() { printf "\033[36m[user-story-rubric]\033[0m %s\n" "$*" >&2; }
die() { printf "\033[31m[user-story-rubric]\033[0m %s\n" "$*" >&2; exit 1; }

require() {
  command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1"
}

require jq
require xcrun

[[ -f "$FIXTURE" ]] || die "fixture not found: $FIXTURE"

# ---- shared local simulator session policy ----
# Reexec inside the shared host helper before touching the simulator. On local
# macOS outside CI this acquires the shared lock and exports IOS_SIMULATOR_ID /
# SIMULATOR_UDID; nesting is validated with `is-owner`, not env alone. An
# explicit but unusable DEV_IOS_SESSION_BIN fails closed.
# shellcheck source=../ios/session.sh
[[ -f "$REPO_ROOT/scripts/ios/session.sh" ]] || die "shared session library missing: $REPO_ROOT/scripts/ios/session.sh"
# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/ios/session.sh"
ios_session_reexec_if_needed "$SCRIPT_PATH" "$@"

# ---- deterministic simulator selection (shared policy) ----
# Never inherit an arbitrary booted device: a booted SE/iPad must not override
# the declared iPhone 17 Pro preference. Explicit IOS_SIMULATOR_ID is honored
# and validated (see docs/development/ios-testing.md).
SEL_ERR="$(mktemp)"
if SEL_JSON="$(ios_select_simulator_json "iPhone 17 Pro" 2>"$SEL_ERR")" \
  && [[ -n "$SEL_JSON" ]]; then
  UDID="$(ios_json_field "$SEL_JSON" udid)"
  SIM_NAME="$(ios_json_field "$SEL_JSON" name)"
  SIM_STATE="$(ios_json_field "$SEL_JSON" state)"
  rm -f "$SEL_ERR"
else
  cat "$SEL_ERR" >&2 || true
  rm -f "$SEL_ERR"
  die "no suitable iPhone simulator (need iPhone 17 Pro or any numbered iPhone)"
fi
[[ -n "$UDID" ]] || die "simulator selector returned no UDID"
log "using simulator $SIM_NAME ($UDID)"

if [[ "$SIM_STATE" != "Booted" ]]; then
  log "booting $UDID"
  xcrun simctl boot "$UDID" || true
  for _ in {1..30}; do
    state="$(xcrun simctl list devices -j | jq -r --arg u "$UDID" '.devices | to_entries[] | .value[] | select(.udid==$u) | .state')"
    [[ "$state" == "Booted" ]] && break
    sleep 1
  done
fi

# Pre-grant location permission so the CLLocationManager prompt does not gate
# the first frame and obscure every screenshot. Silent no-op if the app isn't
# installed yet — installer step below will re-grant.
xcrun simctl privacy "$UDID" grant location "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl privacy "$UDID" grant location-always "$APP_BUNDLE_ID" >/dev/null 2>&1 || true

# ---- ensure app is installed (build if not) ----
if ! xcrun simctl get_app_container "$UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1; then
  log "app $APP_BUNDLE_ID not installed — building"
  (
    cd "$IOS_APP_DIR"
    DERIVED_DATA="${IOS_DERIVED_DATA_PATH:-build}"
    xcodebuild build \
      -project SoloCompass.xcodeproj \
      -scheme SoloCompass \
      -destination "platform=iOS Simulator,id=$UDID" \
      -derivedDataPath "$DERIVED_DATA" \
      -parallel-testing-enabled NO \
      -quiet
    APP_PATH="$(find "$DERIVED_DATA/Build/Products" -maxdepth 3 -name 'SoloCompass.app' | head -n1)"
    [[ -n "$APP_PATH" ]] || exit 1
    xcrun simctl install "$UDID" "$APP_PATH"
  ) || die "app build/install failed"
fi

mkdir -p "$EVIDENCE_ROOT"

STORY_COUNT="$(jq 'length' "$FIXTURE")"
log "running $STORY_COUNT user stories"

for i in $(seq 0 $((STORY_COUNT - 1))); do
  ID="$(jq -r ".[$i].id" "$FIXTURE")"
  STORY_DIR="$EVIDENCE_ROOT/$ID"
  mkdir -p "$STORY_DIR"

  # macOS ships bash 3.2 which has no mapfile; portable read-into-array instead.
  LAUNCH_ARGS=()
  while IFS= read -r line; do
    LAUNCH_ARGS+=("$line")
  done < <(jq -r ".[$i].launch_args[]" "$FIXTURE")
  LAT="$(jq -r ".[$i].scenario.coords[1]" "$FIXTURE")"
  LNG="$(jq -r ".[$i].scenario.coords[0]" "$FIXTURE")"
  HOUR="$(jq -r ".[$i].scenario.hour" "$FIXTURE")"

  # iOS 26 simctl requires a full ISO-8601 date, not bare HH:MM, or the override
  # silently no-ops and the status bar keeps wall-clock time.
  TIME_HHMM="$(printf '2026-07-03T%02d:00:00' "$HOUR")"

  log "[$((i+1))/$STORY_COUNT] $ID  →  ($LNG, $LAT) @ ${TIME_HHMM}  args=${LAUNCH_ARGS[*]}"

  xcrun simctl terminate "$UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true

  xcrun simctl status_bar "$UDID" clear >/dev/null 2>&1 || true
  xcrun simctl status_bar "$UDID" override \
    --time "$TIME_HHMM" \
    --dataNetwork wifi \
    --wifiMode active \
    --wifiBars 3 \
    --cellularMode active \
    --cellularBars 4 \
    --batteryState charged \
    --batteryLevel 100 >/dev/null 2>&1 || true

  xcrun simctl location "$UDID" set "$LAT","$LNG" >/dev/null 2>&1 || true

  xcrun simctl launch "$UDID" "$APP_BUNDLE_ID" "${LAUNCH_ARGS[@]}" >/dev/null || {
    log "  launch failed — skipping"
    continue
  }

  # First-paint + async city fetch tuned from sc-evaluator experience.
  # 8s covers cold-start CAMetalLayer + tile-fetch on unseeded cities (SGN/NYC).
  sleep 8
  xcrun simctl io "$UDID" screenshot "$STORY_DIR/screen_01_home.png" >/dev/null

  # Second beat covers stories whose sheet/overlay animates in later, plus
  # the AI-orchestrator round-trip (Anthropic API) that s02 depends on.
  # Bumped from 5s → 12s in round 14 to catch ChatCards after the auto-seed
  # query dispatches — previously screenshot fired while still "Searching
  # nearby…" and s02 kept losing ai_content_quality dimension points.
  sleep 12
  xcrun simctl io "$UDID" screenshot "$STORY_DIR/screen_02_settled.png" >/dev/null

  log "  → $STORY_DIR"
done

xcrun simctl status_bar "$UDID" clear >/dev/null 2>&1 || true
xcrun simctl terminate "$UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true

log "all $STORY_COUNT stories captured → $EVIDENCE_ROOT"
