/** Keep the account-authorized basemap, sources, geometry and attribution. */
export const paperCreamStyle = "mapbox://styles/mapbox/light-v11";

interface PaperLayer {
  readonly type: string;
  readonly "source-layer"?: string;
}

/** Only recolor known cartographic surfaces; never replace labels or geometry. */
export function paperPaint(
  layer: PaperLayer,
): readonly ["background-color" | "fill-color", string][] {
  if (layer.type === "background") return [["background-color", "#f5f0e5"]];
  if (layer.type !== "fill") return [];
  switch (layer["source-layer"]) {
    case "water":
      return [["fill-color", "#bcd2cc"]];
    case "landuse":
    case "landcover":
      return [["fill-color", "#e3e8d7"]];
    case "building":
      return [["fill-color", "#e8dfcf"]];
    default:
      return [];
  }
}
