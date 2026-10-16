import { describe, expect, it } from "vitest";
import { projectIllustratedPin } from "./illustrated-map";

describe("illustrated map pin alignment", () => {
  it("preserves canvas positions at its native aspect ratio", () => {
    expect(projectIllustratedPin(640, 290, "0 0 1000 700", 1000, 700)).toEqual({
      left: 640,
      top: 290,
    });
  });
  it("centres the same location on a narrow cropped map", () => {
    expect(projectIllustratedPin(500, 350, "0 0 1000 700", 320, 700)).toEqual({
      left: 160,
      top: 350,
    });
    expect(projectIllustratedPin(0, 0, "0 0 1000 700", 320, 700)).toEqual({ left: -340, top: 0 });
  });
  it("keeps hit targets aligned after zoom and pan", () => {
    expect(projectIllustratedPin(500, 350, "250 175 500 350", 320, 700)).toEqual({
      left: 160,
      top: 350,
    });
    expect(projectIllustratedPin(600, 400, "250 175 500 350", 320, 700)).toEqual({
      left: 360,
      top: 450,
    });
  });
  it("supports horizontal letterboxing through slice cropping", () => {
    expect(projectIllustratedPin(500, 350, "0 0 1000 700", 1000, 350)).toEqual({
      left: 500,
      top: 175,
    });
  });
  it("rejects malformed or zero-size viewports", () => {
    for (const box of ["", "0 0 0 700", "0 0 1000 -1", "a 0 1000 700", "0 0 1000 700 5"])
      expect(projectIllustratedPin(500, 350, box, 320, 700)).toBeNull();
    expect(projectIllustratedPin(500, 350, "0 0 1000 700", 0, 700)).toBeNull();
  });
});
