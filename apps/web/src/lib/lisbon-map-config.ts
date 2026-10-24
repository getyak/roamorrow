import type { WebCityMapConfig } from "./cities-data";

/** Small shared map geometry; no runtime dependency on multi-city experience data. */
export const LISBON_MAP_CONFIG: WebCityMapConfig = {
  riverPath:
    "M -20 540 C 200 530, 380 555, 560 590 C 720 620, 880 640, 1020 645 L 1020 720 L -20 720 Z",
  riverEdgePath: "M -20 540 C 200 530, 380 555, 560 590 C 720 620, 880 640, 1020 645",
  ribbonPath: "M 240 410 Q 380 380 480 410 Q 580 430 700 360 Q 760 320 800 250",
  labels: [
    { text: "CASTELO", x: 640, y: 245 },
    { text: "CHIADO", x: 430, y: 380 },
    { text: "BAIRRO ALTO", x: 490, y: 450 },
    { text: "ALFAMA", x: 700, y: 335 },
    { text: "GRAÇA", x: 610, y: 270 },
    { text: "BELÉM", x: 240, y: 540, muted: true },
    { text: "RIO TEJO", x: 800, y: 618, muted: true },
  ],
  landmark: {
    x: 640,
    y: 290,
    d: "M -16 0 L -16 -10 L -10 -10 L -10 -14 L -4 -14 L -4 -10 L 4 -10 L 4 -14 L 10 -14 L 10 -10 L 16 -10 L 16 0 Z",
  },
  contour: {
    cx: 640,
    cy: 290,
    radii: [
      { rx: 80, ry: 55 },
      { rx: 60, ry: 42 },
      { rx: 40, ry: 28 },
    ],
  },
};
