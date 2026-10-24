import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

interface ApnsConfig {
  keyId: string;
  teamId: string;
  topic: string;
  host: string;
  p8: string;
}

function readApnsConfig(getEnv: (name: string) => string | undefined): ApnsConfig {
  const p8 = getEnv("APNS_KEY_P8") ?? "";
  const keyId = getEnv("APNS_KEY_ID") ?? "";
  const teamId = getEnv("APNS_TEAM_ID") ?? "";
  const topic = getEnv("APNS_TOPIC") ?? "";
  const host = getEnv("APNS_HOST") ?? "api.sandbox.push.apple.com";
  if (!p8 || !keyId || !teamId || !topic) {
    throw new Error("missing APNS_KEY_P8 / APNS_KEY_ID / APNS_TEAM_ID / APNS_TOPIC");
  }
  return { keyId, teamId, topic, host, p8 };
}

function pemToDer(pem: string): ArrayBuffer {
  const base64 = pem
    .replace(/-----BEGIN [^-]+-----/g, "")
    .replace(/-----END [^-]+-----/g, "")
    .replace(/\s+/g, "");
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

export async function createApnsSender(getEnv: (name: string) => string | undefined) {
  const config = readApnsConfig(getEnv);
  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(config.p8),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const jwt = await create(
    { alg: "ES256", kid: config.keyId, typ: "JWT" },
    { iss: config.teamId, iat: getNumericDate(0) },
    privateKey,
  );

  return {
    async send(
      deviceTokens: string[],
      payload: string,
      removeExpiredToken: (token: string) => PromiseLike<unknown>,
    ): Promise<{ delivered: number; total: number }> {
      let delivered = 0;
      await Promise.all(
        deviceTokens.map(async (deviceToken) => {
          try {
            const response = await fetch(`https://${config.host}/3/device/${deviceToken}`, {
              method: "POST",
              headers: {
                authorization: `bearer ${jwt}`,
                "apns-topic": config.topic,
                "apns-push-type": "alert",
                "apns-priority": "10",
                "content-type": "application/json",
              },
              body: payload,
            });
            if (response.status === 200) delivered += 1;
            else if (response.status === 410) await removeExpiredToken(deviceToken);
          } catch {
            // Preserve best-effort delivery: one network/cleanup failure does not fail other devices.
          }
        }),
      );
      return { delivered, total: deviceTokens.length };
    },
  };
}
