import test from "node:test";
import assert from "node:assert/strict";
import { modelSchema } from "./model-schema.mjs";
import { tools, validate } from "../demo/contract.mjs";
test("function API receives object items, original strict MCP tuple stays unchanged", () => {
  const tool = tools.find((t) => t.name === "search_places");
  const adapted = modelSchema(tool.inputSchema);
  const tuple = adapted.properties.area.properties.coordinates.items.items;
  assert(!Array.isArray(tuple.items));
  assert.match(tuple.description, /longitude, latitude/);
  assert(Array.isArray(tool.inputSchema.properties.area.properties.coordinates.items.items.items));
  assert.throws(() =>
    validate(tool.inputSchema, {
      map_id: "m",
      queries: ["Tokyo"],
      area: {
        type: "Polygon",
        coordinates: [
          [
            [139, 95],
            [140, 95],
            [140, 96],
            [139, 95],
          ],
        ],
      },
    }),
  );
});
