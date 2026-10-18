import { describe, expect, it } from "vitest";
import { localHourAt } from "./local-hour";

describe("place local hour", () => {
  const now = new Date("2026-10-15T10:30:00Z");

  it("leaves missing and invalid place timezones unknown", () => {
    expect(localHourAt(now)).toBeNull();
    expect(localHourAt(now, "not/a-timezone")).toBeNull();
    expect(localHourAt(new Date("invalid"), "Asia/Shanghai")).toBeNull();
  });

  it("uses the selected place timezone instead of server UTC", () => {
    expect(localHourAt(now, "Asia/Shanghai")).toBe(18);
    expect(localHourAt(now, "Asia/Bangkok")).toBe(17);
    expect(localHourAt(now, "America/New_York")).toBe(6);
  });

  it("handles midnight and seasonal time changes", () => {
    expect(localHourAt(new Date("2026-10-15T16:30:00Z"), "Asia/Shanghai")).toBe(0);
    expect(localHourAt(new Date("2026-01-15T10:30:00Z"), "America/New_York")).toBe(5);
  });
});
