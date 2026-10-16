/**
 * Check-in flow state (W05/W06).
 *
 * Requirements this encodes:
 *  - a failed check-in must KEEP the selected rating and surface a retry,
 *  - success is only ever shown after the server acknowledged,
 *  - a rating chip is a SELECTION, not a hidden submit,
 *  - re-entry while saving is impossible (busy guard).
 *
 * Pure reducer so the behavior is testable without React.
 */

export type CheckinStatus = "idle" | "saving" | "success" | "error";

export interface CheckinState {
  readonly status: CheckinStatus;
  /** Rating selected (not yet submitted) or the rating that was submitted. */
  readonly rating: number | null;
  readonly errorMessage: string | null;
}

export type CheckinEvent =
  | { readonly type: "rate"; readonly rating: number }
  | { readonly type: "clearRating" }
  | { readonly type: "submit" }
  | { readonly type: "resolve" }
  | { readonly type: "fail"; readonly message: string }
  | { readonly type: "reset" };

export const initialCheckinState: CheckinState = {
  status: "idle",
  rating: null,
  errorMessage: null,
};

export function checkinReducer(state: CheckinState, event: CheckinEvent): CheckinState {
  switch (event.type) {
    case "rate": {
      if (state.status === "saving" || state.status === "success") return state;
      const rating = Math.min(5, Math.max(1, Math.round(event.rating)));
      return { ...state, rating, errorMessage: null };
    }
    case "clearRating": {
      if (state.status === "saving" || state.status === "success") return state;
      return { ...state, rating: null };
    }
    case "submit": {
      // Busy guard: never start a second request, never submit "done" twice.
      if (state.status === "saving" || state.status === "success") return state;
      return { ...state, status: "saving", errorMessage: null };
    }
    case "resolve": {
      if (state.status !== "saving") return state;
      return { ...state, status: "success", errorMessage: null };
    }
    case "fail": {
      if (state.status !== "saving") return state;
      // Keep the selected rating so the retry reuses it (W05).
      return { ...state, status: "error", errorMessage: event.message };
    }
    case "reset":
      return initialCheckinState;
  }
}

/** The rating that should accompany the next submit. */
export function ratingForSubmit(state: CheckinState): number | undefined {
  return state.rating ?? undefined;
}
