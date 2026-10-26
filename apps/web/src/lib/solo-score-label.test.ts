import { expect, it } from "vitest";
import { knownSoloScore } from "./solo-score-label";

it("keeps unrated map markers, cards and details unknown", () => {
  expect(knownSoloScore({ overall: 0, basedOnCount: 0 })).toBeNull();
  expect(knownSoloScore({ overall: 8, basedOnCount: 0 })).toBeNull();
  expect(knownSoloScore({ overall: NaN, basedOnCount: 5 })).toBeNull();
  expect(knownSoloScore({ overall: 0, basedOnCount: 5 })).toBe("0.0");
  expect(knownSoloScore({ overall: 8.64, basedOnCount: 5 })).toBe("8.6");
});
