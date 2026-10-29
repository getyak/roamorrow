/* Deterministic prototype state contract. This does not call native tools. */
(function (root) {
  const copy = (value) => JSON.parse(JSON.stringify(value));
  function create() {
    return {
      mode: "nearby",
      category: "all",
      favoriteScope: "city",
      selectedId: "park",
      contextIds: null,
      source: null,
      entered: false,
      camera: { x: 0, y: 0 },
      searchedCamera: { x: 0, y: 0 },
      areaDirty: false,
      location: "manual",
    };
  }
  function ids(state, catalog, saved) {
    const items =
      state.mode === "saved"
        ? catalog.filter(
            (p) => saved.includes(p.id) && (state.favoriteScope === "all" || p.city === "tokyo"),
          )
        : catalog.filter(
            (p) =>
              (!state.contextIds || state.contextIds.includes(p.id)) &&
              (state.category === "all" || p.category === state.category),
          );
    const query = (state.query || "").trim().toLocaleLowerCase();
    return items
      .filter(
        (p) =>
          !query ||
          `${p.title} ${p.name} ${p.category === "cafe" ? "咖啡 cafe coffee" : "书店 bookstore book"}`
            .toLocaleLowerCase()
            .includes(query),
      )
      .map((p) => p.id);
  }
  function reconcile(state, catalog, saved) {
    const visible = ids(state, catalog, saved);
    if (!visible.includes(state.selectedId)) state.selectedId = visible[0] || null;
    return state;
  }
  function fromAnswer(state, source, candidates, selectedId) {
    return {
      ...state,
      entered: true,
      mode: "nearby",
      category: "all",
      source: copy(source),
      contextIds: [...candidates],
      selectedId: candidates.includes(selectedId) ? selectedId : candidates[0] || null,
      query: "",
      camera: { x: 0, y: 0 },
      searchedCamera: { x: 0, y: 0 },
      areaDirty: false,
    };
  }
  function independent(state) {
    if (state.entered) return state;
    return { ...state, entered: true, source: null, contextIds: null };
  }
  function pan(state, dx, dy) {
    const camera = {
      x: Math.max(-120, Math.min(120, state.camera.x + dx)),
      y: Math.max(-120, Math.min(120, state.camera.y + dy)),
    };
    return {
      ...state,
      camera,
      areaDirty:
        Math.hypot(camera.x - state.searchedCamera.x, camera.y - state.searchedCamera.y) >= 32,
    };
  }

  function searchArea(state) {
    return { ...state, contextIds: null, searchedCamera: { ...state.camera }, areaDirty: false };
  }
  function scopeForPlace(id) {
    return { kind: "experience", experienceId: id };
  }
  function scopeForArea(state, experienceIds) {
    const detail = [
      state.mode === "saved" ? "收藏" : "上野周边",
      state.category === "cafe" ? "咖啡" : state.category === "bookstore" ? "书店" : "",
      state.query ? `搜索：${state.query}` : "",
    ]
      .filter(Boolean)
      .join(" · ");
    return {
      kind: "area",
      label: `这片地图 · ${detail}`,
      viewport: { ...state.camera },
      category: state.category,
      query: state.query || "",
      mode: state.mode,
      favoriteScope: state.favoriteScope,
      ...(experienceIds ? { experienceIds: [...experienceIds] } : {}),
    };
  }

  function experienceId(scope) {
    return typeof scope === "string"
      ? scope
      : scope?.kind === "experience"
        ? scope.experienceId
        : null;
  }
  function label(scope, catalog) {
    if (scope?.kind === "area") return scope.label;
    const id = experienceId(scope);
    return catalog.find((p) => p.id === id)?.name || "";
  }
  const api = {
    create,
    ids,
    reconcile,
    fromAnswer,
    independent,
    pan,
    searchArea,
    scopeForPlace,
    scopeForArea,
    experienceId,
    label,
    copy,
  };
  root.TravelMapFlow = api;
  if (typeof module !== "undefined") module.exports = api;
})(typeof window !== "undefined" ? window : globalThis);
