#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -n "${MAP_ACCURACY_ARTIFACT_DIR:-}" ]]; then
  task_artifact="$MAP_ACCURACY_ARTIFACT_DIR"
else
  task_artifact="$(/Users/cubxxw/.local/bin/dev-storage-guard new-artifact solo-map-accuracy-host)"
fi
mkdir -p "$task_artifact/host"
python3 - "$ROOT" "$task_artifact/host" <<'PY'
from pathlib import Path
import sys, shutil
root, out = map(Path, sys.argv[1:])
parts = [(root / 'scripts/qa/map-accuracy-host.swift').read_text()]
for name in ['Geo/MainlandChinaBoundary.swift', 'Geo/CoordinateConverter.swift', 'POIRating.swift', 'POIMerger.swift']:
    p = root / 'apps/ios/SoloCompass/Services' / name
    if p.exists(): parts.append(p.read_text())
parts.append((root / 'scripts/qa/map-accuracy-cases.swift').read_text())
(out / 'main.swift').write_text('\n'.join(parts))
boundary = root / 'apps/ios/SoloCompass/Resources/JSON/mainland_china_boundary.json'
if boundary.exists(): shutil.copy2(boundary, out / boundary.name)
PY
xcrun swiftc -module-cache-path "$task_artifact/ModuleCache" \
  "$task_artifact/host/main.swift" -o "$task_artifact/host/map-accuracy-tests"
"$task_artifact/host/map-accuracy-tests"
