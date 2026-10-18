import { describe, expect, it } from "vitest";
import { resolveDetail, type SnapshotExperience } from "./detail-resolution";

const SNAP_A: SnapshotExperience = { id: "a", title: "Snapshot A" };
const SNAP_B: SnapshotExperience = { id: "b", title: "Snapshot B" };

describe("resolveDetail", () => {
  it("prefers the live nearby result when the id is currently visible", () => {
    const r = resolveDetail("a", [{ experience: { id: "a" } }], [SNAP_A]);
    expect(r).toEqual({ status: "nearby", experienceId: "a" });
  });

  it("falls back to the completion's own snapshot for historical experiences", () => {
    const r = resolveDetail("b", [{ experience: { id: "a" } }], [SNAP_A, SNAP_B]);
    expect(r.status).toBe("snapshot");
    if (r.status === "snapshot") {
      expect(r.experience.title).toBe("Snapshot B");
    }
  });

  it("reports an explicit unavailable state instead of silently doing nothing", () => {
    const r = resolveDetail("ghost", [{ experience: { id: "a" } }], [SNAP_A]);
    expect(r).toEqual({ status: "unavailable", experienceId: "ghost" });
  });

  it("handles empty inputs without throwing", () => {
    expect(resolveDetail("x", [], []).status).toBe("unavailable");
  });
});
