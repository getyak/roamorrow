// Host-specific function schema view. MCP retains the strict draft-07 tuple.
export function modelSchema(schema) {
  if (Array.isArray(schema)) return schema.map(modelSchema);
  if (!schema || typeof schema !== "object") return schema;
  const out = Object.fromEntries(
    Object.entries(schema)
      .filter(([key]) => !["$schema", "$defs"].includes(key))
      .map(([k, v]) => [k, modelSchema(v)]),
  );
  if (schema.type === "array" && Array.isArray(schema.items)) {
    out.items = { anyOf: schema.items.map(modelSchema) };
    delete out.additionalItems;
    out.description = [
      out.description,
      "Tuple order is [longitude, latitude]. Longitude -180..180, latitude -90..90. The MCP server enforces each positional bound.",
    ]
      .filter(Boolean)
      .join(" ");
  }
  return out;
}
