import { createHmac } from "node:crypto";
import { describe, expect, it } from "vitest";
import { nomadsNetworkHeaders } from "./nomads-proxy";

describe("Nomads network attribution", () => {
  it("overwrites client-supplied proof using the platform IP and never forwards the shared key", async () => {
    const secret = "fixture-narrow-network-key",
      time = 1900000000000;
    const headers = await nomadsNetworkHeaders(
      new Headers({
        "x-forwarded-for": "203.0.113.1",
        "x-nomads-network-ip": "192.0.2.9",
        "x-nomads-network-signature": "forged",
      }),
      secret,
      time,
    );
    expect(headers.get("x-nomads-network-ip")).toBe("203.0.113.1");
    expect(headers.get("x-nomads-network-time")).toBe(String(time));
    expect(headers.get("x-nomads-network-signature")).toBe(
      createHmac("sha256", secret)
        .update(time + "\n203.0.113.1")
        .digest("hex"),
    );
    expect([...headers.values()]).not.toContain(secret);
  });
  it("refuses to assert a network identity when signing configuration or the platform IP is missing", async () => {
    await expect(
      nomadsNetworkHeaders(new Headers({ "x-forwarded-for": "203.0.113.1" }), undefined),
    ).rejects.toThrow();
    await expect(nomadsNetworkHeaders(new Headers(), "fixture-key")).rejects.toThrow();
  });
});
