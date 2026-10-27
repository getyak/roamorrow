/** Google Maps URLs need no API key. Coordinates here remain GeoJSON [lng, lat]. */
export function directionsUrl(coordinates: readonly [number, number]): string | null {
  const [longitude, latitude] = coordinates;
  if (
    !Number.isFinite(longitude) ||
    !Number.isFinite(latitude) ||
    Math.abs(longitude) > 180 ||
    Math.abs(latitude) > 90
  )
    return null;
  const params = new URLSearchParams({
    api: "1",
    destination: `${latitude},${longitude}`,
    travelmode: "walking",
  });
  // Leave origin to the traveler. The viewed map center is not their location.
  return `https://www.google.com/maps/dir/?${params}`;
}

export function walkEstimate(minutes: number | null | undefined): string {
  if (minutes == null || !Number.isFinite(minutes) || minutes < 0) return "Walk time unknown";
  return minutes < 1
    ? "Under 1 min from map center · estimate"
    : `About ${Math.round(minutes)} min from map center · estimate`;
}
