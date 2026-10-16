import { describe, expect, it } from "vitest";
import { buildTodayBrief, type TodayCandidate } from "./today-copy";
const candidate = (
  id: string,
  score: number,
  minutes: number,
  bestTimes: { startHour: number; endHour: number }[] = [],
): TodayCandidate => ({
  experience: { id, title: id, category: "coffee", soloScore: { overall: score }, bestTimes },
  walkingMinutes: minutes,
});
describe("today picks respect available evidence", () => {
  it("keeps empty state empty", () => expect(buildTodayBrief([]).picks).toEqual([]));
  it("ranks known scores and distance without rewarding unverified place-local hours", () => {
    const brief = buildTodayBrief([
      candidate("low", 4, 1),
      candidate("high", 9, 5),
      candidate("mid", 8, 5),
      candidate("far", 8, 30),
    ]);
    expect(brief.picks.map((p) => p.experience.id)).toEqual(["high", "mid", "far"]);
  });
  it("does not infer best-hour fit from the viewer's clock or supplied windows", () => {
    const a = candidate("same", 8, 5, [{ startHour: 0, endHour: 24 }]);
    const b = candidate("same", 8, 5, []);
    expect(buildTodayBrief([a]).picks[0]?.score).toBe(buildTodayBrief([b]).picks[0]?.score);
    expect(buildTodayBrief([a]).picks[0]?.fitsBestHours).toBe(false);
    expect(buildTodayBrief([a]).picks[0]?.evidence).not.toMatch(/best hours|open|safe|crowd/i);
  });
  it("explains the limitation without making live claims", () => {
    const brief = buildTodayBrief([candidate("a", 8.2, 6)]);
    expect(brief.basis).toContain("not verified");
    expect(brief.picks[0]?.evidence).toContain("solo 8.2");
    expect(brief.headline).not.toMatch(/right now|morning|evening|night|safe|uncrowded/i);
  });
});
