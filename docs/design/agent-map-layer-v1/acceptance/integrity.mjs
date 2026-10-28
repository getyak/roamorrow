export function assertRuntimeIdentity(runtime, digest, rubric) {
  if (
    !runtime.runtime_id ||
    runtime.candidate_digest !== digest ||
    runtime.rubric_sha256 !== rubric ||
    !runtime.source_revision
  )
    throw Error("runtime build identity does not match current candidate; restart runtime");
}
export function assertResponseIdentity(headers, runtime) {
  if (
    headers.get("x-map-candidate") !== runtime.candidate_digest ||
    headers.get("x-map-revision") !== runtime.source_revision ||
    headers.get("x-map-runtime") !== runtime.runtime_id
  )
    throw Error("actual MCP process build identity mismatch");
}
export function assertMoveResult(before, after, expected, { normalFinish, finalMessage } = {}) {
  if (!normalFinish || !finalMessage?.trim())
    throw Error("model did not finish the edit conversation normally");
  if (before.map_id !== after.map_id || after.version <= before.version)
    throw Error("edit did not commit a newer version of the same map");
  const originBefore = before.days.find((d) => d.day_id === expected.fromDayId),
    targetAfter = after.days.find((d) => d.day_id === expected.toDayId),
    originAfter = after.days.find((d) => d.day_id === expected.fromDayId);
  const original = originBefore?.stops.find((s) => s.stop_id === expected.stopId),
    moved = targetAfter?.stops.find((s) => s.stop_id === expected.stopId);
  if (!original || !moved || originAfter?.stops.some((s) => s.stop_id === expected.stopId))
    throw Error("requested stop was not moved to the requested day");
  if (JSON.stringify(original.coordinates) !== JSON.stringify(moved.coordinates))
    throw Error("move changed geographic coordinates");
  const all = after.days.flatMap((d) => d.stops);
  if (
    all.length !== before.days.flatMap((d) => d.stops).length ||
    all.filter((s) => s.stop_id === expected.stopId).length !== 1
  )
    throw Error("move duplicated or lost stops");
  for (const day of before.days.filter(
    (d) => ![expected.fromDayId, expected.toDayId].includes(d.day_id),
  ))
    if (JSON.stringify(day) !== JSON.stringify(after.days.find((d) => d.day_id === day.day_id)))
      throw Error("edit changed an unrelated day");
  return true;
}
