#!/usr/bin/env python3
"""Rebuild coarse MapKit routing geometry from a frozen local Natural Earth file."""
import argparse
import hashlib
import json
from pathlib import Path

SOURCE_SHA = "239eec57ac17f100a11e2536cffc56752c318b50ae765b0918ff7aab4ce8f255"
SOURCE_URL = "https://github.com/nvkelso/natural-earth-vector/blob/master/geojson/ne_10m_admin_0_countries.geojson"
FOREIGN = {"KOR", "PRK", "JPN", "VNM", "LAO", "MMR", "THA", "KHM", "NPL", "BTN", "IND", "PAK", "AFG", "TJK", "KGZ", "KAZ", "MNG", "RUS", "TWN"}
BBOX = [70, 10, 140, 60]


def clip_ring(ring):
    points = ring[:-1] if ring and ring[0] == ring[-1] else ring
    for axis, bound, above in [(0, 70, True), (0, 140, False), (1, 10, True), (1, 60, False)]:
        if not points:
            return []
        output = []
        previous = points[-1]
        previous_inside = previous[axis] >= bound if above else previous[axis] <= bound
        for point in points:
            inside = point[axis] >= bound if above else point[axis] <= bound
            if inside != previous_inside:
                ratio = (bound - previous[axis]) / (point[axis] - previous[axis])
                crossing = [previous[i] + ratio * (point[i] - previous[i]) for i in range(2)]
                crossing[axis] = bound
                output.append(crossing)
            if inside:
                output.append(point)
            previous, previous_inside = point, inside
        points = output
    return points + [points[0]] if len(points) >= 3 else []


def collection(features, **extra):
    return {"type": "FeatureCollection", "properties": {
        "source": "Natural Earth 1:10m Admin 0 Countries", "source_url": SOURCE_URL,
        "upstream_sha256": SOURCE_SHA, "license": "Public domain",
        "purpose": "Coarse API routing evidence, not a survey boundary or territorial claim", **extra}, "features": features}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    content = args.input.read_bytes()
    if hashlib.sha256(content).hexdigest() != SOURCE_SHA:
        raise SystemExit("Natural Earth input changed; review geometry before updating the frozen source SHA")
    foreign, special = [], []
    for feature in json.loads(content)["features"]:
        code = feature["properties"]["ADM0_A3"]
        geometry = feature["geometry"]
        polygons = [geometry["coordinates"]] if geometry["type"] == "Polygon" else geometry["coordinates"]
        if code in {"HKG", "MAC", "TWN"}:
            special.append({"type": "Feature", "properties": {"region": code},
                            "geometry": {"type": "MultiPolygon", "coordinates": polygons}})
        if code in FOREIGN:
            clipped = []
            for rings in polygons:
                outer = clip_ring(rings[0])
                if outer:
                    clipped.append([outer] + [r for ring in rings[1:] if (r := clip_ring(ring))])
            if clipped:
                foreign.append({"type": "Feature", "properties": {"code": code},
                                "geometry": {"type": "MultiPolygon", "coordinates": clipped}})
    args.output.mkdir(parents=True, exist_ok=True)
    for name, result in [("mapkit_foreign_land.geojson", collection(foreign, clip_bbox=BBOX)),
                         ("mapkit_special_regions.geojson", collection(special))]:
        (args.output / name).write_text(json.dumps(result, separators=(",", ":")) + "\n")


if __name__ == "__main__":
    main()
