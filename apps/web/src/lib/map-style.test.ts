import { describe, expect, it } from "vitest";
import { paperCreamStyle, paperPaint } from "./map-style";

describe("paper cartography", () => {
  it("retains the authorized basemap and distinguishes water from land", () => {
    expect(paperCreamStyle).toBe("mapbox://styles/mapbox/light-v11");
    expect(paperPaint({ type: "fill", "source-layer": "water" })).not.toEqual(
      paperPaint({ type: "fill", "source-layer": "landuse" }),
    );
  });
  it("leaves road hierarchy, label contrast, and unknown layers to the basemap", () => {
    for (const type of ["line", "symbol", "fill-extrusion"]) {
      expect(paperPaint({ type, "source-layer": "water" })).toEqual([]);
    }
    expect(paperPaint({ type: "fill", "source-layer": "unknown" })).toEqual([]);
  });
});
