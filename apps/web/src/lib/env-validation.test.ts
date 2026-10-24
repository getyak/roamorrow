import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const envNames = [
  "NEXT_PUBLIC_MAPBOX_TOKEN",
  "NEXT_PUBLIC_POSTHOG_KEY",
  "NEXT_PUBLIC_POSTHOG_HOST",
  "SUPABASE_URL",
  "SUPABASE_KEY",
  "SUPABASE_ANON_KEY",
  "SUPABASE_SERVICE_ROLE_KEY",
  "DEEPSEEK_API_KEY",
  "VALHALLA_URL",
];
beforeEach(() => {
  vi.resetModules();
  for (const name of envNames) vi.stubEnv(name, undefined);
  vi.spyOn(console, "error").mockImplementation(() => {});
});
afterEach(() => {
  vi.unstubAllEnvs();
  vi.restoreAllMocks();
});
function serverFixture() {
  vi.stubEnv("SUPABASE_URL", "https://synthetic.invalid");
  vi.stubEnv("SUPABASE_ANON_KEY", "synthetic-anonymous-key-123456789");
  vi.stubEnv("SUPABASE_SERVICE_ROLE_KEY", "synthetic-service-key-123456789");
}

describe("environment validation after Zod security upgrade", () => {
  it("keeps public defaults and lazy server validation", async () => {
    const { clientEnv, getServerEnv } = await import("./env");
    expect(clientEnv).toMatchObject({
      NEXT_PUBLIC_MAPBOX_TOKEN: "pk.placeholder_token",
      NEXT_PUBLIC_POSTHOG_HOST: "https://us.i.posthog.com",
    });
    expect(() => getServerEnv()).toThrow("Invalid server environment configuration");
  });
  it("retains the legacy anon-key fallback and server cache", async () => {
    serverFixture();
    const { clientEnv, getServerEnv } = await import("./env");
    const env = getServerEnv();
    expect(env.SUPABASE_KEY).toBe("synthetic-anonymous-key-123456789");
    vi.stubEnv("SUPABASE_ANON_KEY", "changed-synthetic-anonymous-key");
    expect(getServerEnv()).toBe(env);
    expect(Object.keys(clientEnv).some((key) => key.startsWith("SUPABASE"))).toBe(false);
  });
  it("prefers the explicit server key when both keys exist", async () => {
    serverFixture();
    vi.stubEnv("SUPABASE_KEY", "explicit-synthetic-key-123456789");
    expect((await import("./env")).getServerEnv().SUPABASE_KEY).toBe(
      "explicit-synthetic-key-123456789",
    );
  });
  it.each(["NEXT_PUBLIC_MAPBOX_TOKEN", "NEXT_PUBLIC_POSTHOG_HOST"])(
    "rejects invalid public setting %s",
    async (name) => {
      vi.stubEnv(name, "bad");
      await expect(import("./env")).rejects.toThrow(
        "Invalid NEXT_PUBLIC_* environment configuration",
      );
    },
  );
  it.each(["SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY", "DEEPSEEK_API_KEY"])(
    "rejects invalid secret setting %s lazily",
    async (name) => {
      serverFixture();
      vi.stubEnv(name, "bad");
      const { getServerEnv } = await import("./env");
      expect(() => getServerEnv()).toThrow("Invalid server environment configuration");
    },
  );
});
