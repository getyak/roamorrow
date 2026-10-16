import { describe, expect, it } from "vitest";
import { PLACEHOLDER_MAPBOX_TOKEN, isUsableMapboxToken } from "./map-token";

describe("isUsableMapboxToken", () => {
  it("rejects the env fallback placeholder", () => {
    expect(isUsableMapboxToken(PLACEHOLDER_MAPBOX_TOKEN)).toBe(false);
  });

  it("rejects empty / missing values", () => {
    expect(isUsableMapboxToken(undefined)).toBe(false);
    expect(isUsableMapboxToken(null)).toBe(false);
    expect(isUsableMapboxToken("")).toBe(false);
    expect(isUsableMapboxToken("   ")).toBe(false);
  });

  it("rejects template-looking tokens", () => {
    expect(isUsableMapboxToken("pk.your_token_here_please")).toBe(false);
    expect(isUsableMapboxToken("pk.insert_token_here_0123456789")).toBe(false);
    expect(isUsableMapboxToken("pk.<MAPBOX_TOKEN>")).toBe(false);
    expect(isUsableMapboxToken("pk.this_is_a_placeholder_token_value")).toBe(false);
  });

  it("rejects tokens with the wrong shape (secret tokens, short stubs)", () => {
    expect(isUsableMapboxToken("sk.abcdef0123456789abcdef01")).toBe(false);
    expect(isUsableMapboxToken("pk.short")).toBe(false);
    expect(isUsableMapboxToken("nonsense")).toBe(false);
  });

  it("accepts a plausibly real public token", () => {
    expect(
      isUsableMapboxToken("pk.eyJ1Ijoic29sb2NvbXBhc3MiLCJhIjoiY2xhbXAxMjMifQ.abcdef0123456789abcd"),
    ).toBe(true);
  });

  it("trims surrounding whitespace before judging", () => {
    expect(
      isUsableMapboxToken(
        "  pk.eyJ1Ijoic29sb2NvbXBhc3MiLCJhIjoiY2xhbXAxMjMifQ.abcdef0123456789abcd  ",
      ),
    ).toBe(true);
  });
});
