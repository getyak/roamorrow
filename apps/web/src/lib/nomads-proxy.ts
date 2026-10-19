// Vercel overwrites X-Forwarded-For with the actual connecting client:
// https://vercel.com/docs/headers/request-headers#x-forwarded-for
// Cloudflare must authenticate this attribution instead of trusting raw XFF.
export async function nomadsNetworkHeaders(
  incoming: Headers,
  secret: string | undefined,
  now = Date.now(),
): Promise<Headers> {
  const ip = incoming.get("x-forwarded-for")?.split(",")[0]?.trim();
  if (!secret || secret.length < 16 || !ip || !/^[0-9a-f:.]{3,64}$/i.test(ip)) {
    throw new Error("Nomads network attribution is unavailable");
  }
  const stamp = String(now);
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(stamp + "\n" + ip)),
  );
  const headers = new Headers(incoming);
  headers.set("x-nomads-network-ip", ip);
  headers.set("x-nomads-network-time", stamp);
  headers.set(
    "x-nomads-network-signature",
    [...signature].map((value) => value.toString(16).padStart(2, "0")).join(""),
  );
  return headers;
}
