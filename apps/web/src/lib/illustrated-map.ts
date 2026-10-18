/** Project editorial SVG coordinates through xMidYMid slice, not geographic coordinates. */
export function projectIllustratedPin(
  x: number,
  y: number,
  viewBox: string,
  width: number,
  height: number,
): { left: number; top: number } | null {
  const values = viewBox
    .trim()
    .split(/[\s,]+/)
    .map(Number);
  const [vx, vy, vw, vh] = values;
  if (
    values.length !== 4 ||
    values.some((v) => !Number.isFinite(v)) ||
    vx === undefined ||
    vy === undefined ||
    vw === undefined ||
    vh === undefined ||
    vw <= 0 ||
    vh <= 0 ||
    width <= 0 ||
    height <= 0 ||
    ![x, y, width, height].every(Number.isFinite)
  )
    return null;
  const scale = Math.max(width / vw, height / vh);
  return {
    left: (x - vx) * scale - (vw * scale - width) / 2,
    top: (y - vy) * scale - (vh * scale - height) / 2,
  };
}
