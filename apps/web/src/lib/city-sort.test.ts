import { describe, expect, it } from "vitest";
import { applySort, parseSortParam, sortParamFor } from "./city-sort";
import type { WebExperience } from "./lisbon-data";

function exp(id: string, lastVerified: string, walkMin: number): WebExperience {
  return {
    id,
    title: `Title ${id}`,
    titleZh: `标题 ${id}`,
    place: `Place ${id}`,
    placeZh: `地点 ${id}`,
    cat: "cafe",
    x: 0,
    y: 0,
    walkMin,
    neighborhood: "Centro",
    bestHours: [10, 11],
    durationMin: 45,
    why: "why",
    whyZh: "为什么",
    moment: "moment",
    momentZh: "时刻",
    crowd: "calm",
    soloScore: 8,
    sources: 3,
    lastVerified,
    aiReason: "reason",
    aiReasonZh: "理由",
    tags: [],
    tagsZh: [],
    pricePill: "€0",
  };
}

const LIST = [exp("a", "2026-01-10", 20), exp("b", "2026-04-22", 5), exp("c", "2026-03-01", 12)];

describe("applySort", () => {
  it("keeps curated order untouched", () => {
    expect(applySort(LIST, "curated").map((e) => e.id)).toEqual(["a", "b", "c"]);
  });

  it("sorts by real lastVerified date, newest first (not by label alone)", () => {
    expect(applySort(LIST, "verified").map((e) => e.id)).toEqual(["b", "c", "a"]);
  });

  it("sorts by real walkMin, shortest first", () => {
    expect(applySort(LIST, "walk").map((e) => e.id)).toEqual(["b", "c", "a"]);
  });

  it("is stable on ties so rows never jump", () => {
    const ties = [
      exp("t1", "2026-01-01", 10),
      exp("t2", "2026-01-01", 10),
      exp("t3", "2026-01-01", 10),
    ];
    expect(applySort(ties, "walk").map((e) => e.id)).toEqual(["t1", "t2", "t3"]);
    expect(applySort(ties, "verified").map((e) => e.id)).toEqual(["t1", "t2", "t3"]);
  });

  it("does not mutate the input array", () => {
    const before = LIST.map((e) => e.id);
    applySort(LIST, "walk");
    expect(LIST.map((e) => e.id)).toEqual(before);
  });
});

describe("sort URL state round-trips", () => {
  it("parses unknown or missing params to curated", () => {
    expect(parseSortParam(null)).toBe("curated");
    expect(parseSortParam("")).toBe("curated");
    expect(parseSortParam("bogus")).toBe("curated");
    expect(parseSortParam("verified")).toBe("verified");
    expect(parseSortParam("walk")).toBe("walk");
  });

  it("serialises back to the same value it parses", () => {
    for (const mode of ["curated", "verified", "walk"] as const) {
      const raw = sortParamFor(mode);
      expect(parseSortParam(raw)).toBe(mode);
    }
  });
});
