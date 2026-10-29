import test from "node:test";
import assert from "node:assert/strict";
import { fitCamera, mercator } from "../demo/camera.mjs";
const points = [
  [139.6917, 35.6896],
  [139.8107, 35.7101],
  [139.7016, 35.658],
  [139.8829, 35.6329],
];
for (const [sw, sh] of [
  [1050, 780],
  [330, 400],
]) {
  test(`every actual coordinate fits with physical pin clearance at ${sw}x${sh}`, () => {
    const w = Math.max(1050, (780 * sw) / sh),
      h = (w * sh) / sw;
    const camera = fitCamera(points, w, h, sw, sh),
      world = 256 * 2 ** camera.zoom;
    for (const coordinate of points) {
      const p = mercator(coordinate),
        x = (((p[0] - camera.center[0]) * world + w / 2) * sw) / w,
        y = (((p[1] - camera.center[1]) * world + h / 2) * sh) / h;
      assert(x >= 44 && x <= sw - 44);
      assert(y >= 44 && y <= sh - 44);
    }
    assert.deepEqual(camera, fitCamera([...points].reverse(), w, h, sw, sh));
  });
}
