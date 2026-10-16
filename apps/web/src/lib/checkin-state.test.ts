import { describe, expect, it } from "vitest";
import {
  checkinReducer,
  initialCheckinState,
  ratingForSubmit,
  type CheckinState,
} from "./checkin-state";

function saving(rating: number | null = null): CheckinState {
  return checkinReducer({ ...initialCheckinState, rating }, { type: "submit" });
}

describe("checkinReducer", () => {
  it("treats rating as a selection, not a submit", () => {
    const s = checkinReducer(initialCheckinState, { type: "rate", rating: 4 });
    expect(s.status).toBe("idle");
    expect(s.rating).toBe(4);
  });

  it("clamps ratings into 1–5", () => {
    expect(checkinReducer(initialCheckinState, { type: "rate", rating: 0 }).rating).toBe(1);
    expect(checkinReducer(initialCheckinState, { type: "rate", rating: 9 }).rating).toBe(5);
    expect(checkinReducer(initialCheckinState, { type: "rate", rating: 3.6 }).rating).toBe(4);
  });

  it("enters saving on submit and refuses re-entry while busy", () => {
    const s1 = saving(3);
    expect(s1.status).toBe("saving");
    const s2 = checkinReducer(s1, { type: "submit" });
    // A second submit while saving must be ignored.
    expect(s2).toBe(s1);
  });

  it("keeps the selected rating through a failed check-in", () => {
    const failed = checkinReducer(saving(5), { type: "fail", message: "HTTP 500" });
    expect(failed.status).toBe("error");
    // Retry must reuse the traveler's rating.
    expect(failed.rating).toBe(5);
    expect(failed.errorMessage).toBe("HTTP 500");
  });

  it("lets a failed check-in retry and succeed later", () => {
    const failed = checkinReducer(saving(2), { type: "fail", message: "offline" });
    const retry = checkinReducer(failed, { type: "submit" });
    expect(retry.status).toBe("saving");
    expect(retry.rating).toBe(2);
    const done = checkinReducer(retry, { type: "resolve" });
    expect(done.status).toBe("success");
  });

  it("only reports success after an explicit resolve", () => {
    const s = saving();
    expect(s.status).not.toBe("success");
    expect(checkinReducer(s, { type: "resolve" }).status).toBe("success");
  });

  it("ignores resolve/fail outside of saving", () => {
    expect(checkinReducer(initialCheckinState, { type: "resolve" })).toBe(initialCheckinState);
    expect(checkinReducer(initialCheckinState, { type: "fail", message: "x" })).toBe(
      initialCheckinState,
    );
  });

  it("locks the rating once submitted so it cannot flip mid-flight", () => {
    const s = saving(4);
    const re = checkinReducer(s, { type: "rate", rating: 1 });
    expect(re).toBe(s);
  });

  it("resets cleanly when the sheet moves to another experience", () => {
    const failed = checkinReducer(saving(3), { type: "fail", message: "x" });
    expect(checkinReducer(failed, { type: "reset" })).toEqual(initialCheckinState);
  });

  it("clears an explicit rating without touching status", () => {
    const rated = checkinReducer(initialCheckinState, { type: "rate", rating: 4 });
    expect(checkinReducer(rated, { type: "clearRating" }).rating).toBeNull();
    expect(ratingForSubmit(initialCheckinState)).toBeUndefined();
    expect(ratingForSubmit(rated)).toBe(4);
  });
});
