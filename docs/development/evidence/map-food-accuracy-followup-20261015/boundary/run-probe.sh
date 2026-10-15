#!/usr/bin/env bash
set -euo pipefail
cd /private/tmp/ai-test-solo-map-accuracy-followup.EKqFN8
sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
xcrun --sdk iphonesimulator swiftc -parse-as-library -sdk "$sdk" -target arm64-apple-ios17.0-simulator -module-cache-path ./ModuleCache main.swift CoordinateConverter.swift MainlandChinaBoundary.swift -o CoordinateBoundary.app/CoordinateBoundary
codesign --force --sign - CoordinateBoundary.app
state="$(xcrun simctl list devices --json | python3 -c 'import json,os,sys; print(next(d["state"] for ds in json.load(sys.stdin)["devices"].values() for d in ds if d["udid"]==os.environ["IOS_SIMULATOR_ID"]))')"
if [[ "$state" != Booted ]]; then xcrun simctl boot "$IOS_SIMULATOR_ID"; fi
xcrun simctl bootstatus "$IOS_SIMULATOR_ID" -b
xcrun simctl install "$IOS_SIMULATOR_ID" CoordinateBoundary.app
trap 'xcrun simctl terminate "$IOS_SIMULATOR_ID" com.solocompass.accuracyprobe >/dev/null 2>&1 || true; xcrun simctl uninstall "$IOS_SIMULATOR_ID" com.solocompass.accuracyprobe >/dev/null 2>&1 || true' EXIT
for case_name in haodian hongkong empty; do
  args=(--live-poi)
  if [[ "$case_name" == hongkong ]]; then args+=(--hong-kong); fi
  if [[ "$case_name" == empty ]]; then args+=(--empty-query); fi
  xcrun simctl launch "$IOS_SIMULATOR_ID" com.solocompass.accuracyprobe "${args[@]}"
  data_root="$(xcrun simctl get_app_container "$IOS_SIMULATOR_ID" com.solocompass.accuracyprobe data)"
  for poll in {1..15}; do
    python3 -c 'import time; time.sleep(3)'
    if [[ -f "$data_root/Documents/result.json" ]] && python3 -c 'import json,sys; d=json.load(open(sys.argv[1]));sys.exit(0 if (d["status"]!="pending" and d["query"]=={"haodian":"湖北省广水市郝店镇人民政府","hongkong":"香港大會堂 Hong Kong City Hall","empty":""}[sys.argv[2]]) else 1)' "$data_root/Documents/result.json" "$case_name"; then break; fi
  done
  cp "$data_root/Documents/result.json" "$case_name-result.json"
  python3 -c 'import time; time.sleep(5)'
  xcrun simctl io "$IOS_SIMULATOR_ID" screenshot "$case_name.png"
  xcrun simctl terminate "$IOS_SIMULATOR_ID" com.solocompass.accuracyprobe
done
xcrun simctl uninstall "$IOS_SIMULATOR_ID" com.solocompass.accuracyprobe
