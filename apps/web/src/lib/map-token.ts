/**
 * Mapbox token sanity — decide BEFORE constructing a mapbox-gl.Map.
 *
 * Verified gap (root's real /app run): without private env the client env
 * falls back to `pk.placeholder_token`, Mapbox logs "valid Mapbox access
 * token required" and the basemap stays permanently blank while the list
 * still loads. Constructing the map on a known-bad token is a silent
 * failure; the caller must instead render an honest map-unavailable state.
 *
 * Never invent or substitute a working key here — this only says whether
 * the configured one is plausibly real.
 */

/** The exact fallback baked into `lib/env.ts`. */
export const PLACEHOLDER_MAPBOX_TOKEN = "pk.placeholder_token";

// Public tokens are `pk.<payload>.<signature>` — dots inside the token are
// normal, so the shape must allow them.
const TOKEN_SHAPE = /^pk\.[A-Za-z0-9_\-.]{20,}$/;

export function isUsableMapboxToken(token: string | null | undefined): boolean {
  if (!token) return false;
  const trimmed = token.trim();
  if (trimmed.length === 0) return false;
  if (trimmed === PLACEHOLDER_MAPBOX_TOKEN) return false;
  // Any token that still looks like a template/placeholder is unusable.
  if (/placeholder|your[_-]?token|insert|example|<[a-z]+>/i.test(trimmed)) return false;
  return TOKEN_SHAPE.test(trimmed);
}
