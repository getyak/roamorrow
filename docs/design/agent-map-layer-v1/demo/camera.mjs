export const mercator = ([lng, lat]) => [
  (lng + 180) / 360,
  (1 - Math.asinh(Math.tan((lat * Math.PI) / 180)) / Math.PI) / 2,
];
export function fitCamera(coordinates, width, height, screenWidth, screenHeight) {
  if (!coordinates.length) return { center: mercator([139.751, 35.6895]), zoom: 13 };
  const points = coordinates.map(mercator);
  const xs = points.map((p) => p[0]),
    ys = points.map((p) => p[1]);
  const minX = Math.min(...xs),
    maxX = Math.max(...xs),
    minY = Math.min(...ys),
    maxY = Math.max(...ys);
  // Keep 60 physical pixels around the pins, including on narrow mobile viewports.
  const paddingX = Math.min(width * 0.4, Math.max(70, (width * 60) / screenWidth));
  const paddingY = Math.min(height * 0.4, Math.max(70, (height * 60) / screenHeight));
  const world = Math.min(
    (width - 2 * paddingX) / Math.max(1e-9, maxX - minX),
    (height - 2 * paddingY) / Math.max(1e-9, maxY - minY),
  );
  return {
    center: [(minX + maxX) / 2, (minY + maxY) / 2],
    zoom: Math.min(15, Math.max(1, Math.floor(Math.log2(world / 256)))),
  };
}
