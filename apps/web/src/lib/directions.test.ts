import { describe, expect, it } from "vitest";
import { directionsUrl, walkEstimate } from "./directions";

describe("directions handoff", () => {
  it("converts GeoJSON longitude/latitude at the Google Maps boundary", () => {
    const url = new URL(directionsUrl([98.9692, 18.7892])!);
    expect(url.origin + url.pathname).toBe("https://www.google.com/maps/dir/");
    expect(url.searchParams.get("api")).toBe("1");
    expect(url.searchParams.get("destination")).toBe("18.7892,98.9692");
    expect(url.searchParams.get("travelmode")).toBe("walking");
    expect(url.searchParams.has("origin")).toBe(false);
  });

  it.each([
    [NaN, 18],
    [98, Infinity],
    [181, 18],
    [98, -91],
  ])("does not navigate to invalid coordinates %s, %s", (longitude, latitude) =>
    expect(directionsUrl([longitude, latitude])).toBeNull(),
  );

  it("keeps missing estimates unknown and names their actual origin", () => {
    for (const value of [undefined, null, NaN, Infinity, -1]) {
      expect(walkEstimate(value)).toBe("Walk time unknown");
    }
    expect(walkEstimate(0)).toBe("Under 1 min from map center · estimate");
    expect(walkEstimate(7.4)).toBe("About 7 min from map center · estimate");
  });
});
