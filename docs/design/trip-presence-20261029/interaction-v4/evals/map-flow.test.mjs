/** Real travel tasks expressed against V4's pure prototype state contract.
 * These are fixture-based state tests, not live iOS/provider acceptance. */
import test from "node:test";
import assert from "node:assert/strict";
import vm from "node:vm";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
const sandbox = { module: { exports: {} } };
const source = readFileSync(new URL("../assets/map-flow.js", import.meta.url), "utf8");
console.log("prototype_state_sha256=" + createHash("sha256").update(source).digest("hex"));
vm.runInNewContext(source, sandbox);
const flow = sandbox.module.exports;
const normalize = (value) => JSON.parse(JSON.stringify(value));
const catalog = [
  { id: "park", name: "Parkside Café", city: "tokyo", category: "coffee" },
  { id: "lane", name: "Lane Coffee", city: "tokyo", category: "coffee" },
  { id: "museum", name: "Museum fixture", city: "tokyo", category: "culture" },
  { id: "chiangmai", name: "Chiang Mai fixture", city: "cmi", category: "coffee" },
];
test("PF01: recommendation map carries exactly that answer and a copied return anchor", () => {
  const initial = flow.create(),
    source = { roomId: 1, turn: 2, scrollTop: 380 };
  const map = flow.fromAnswer(initial, source, ["park", "lane"], "lane");
  source.scrollTop = 0;
  assert.equal(map.mode, "nearby");
  assert.equal(map.selectedId, "lane");
  assert.equal(flow.ids(map, catalog, []).join(","), "park,lane");
  assert.equal(map.source.scrollTop, 380);
  assert.equal(initial.source, null);
});
test("PF02: looking at another pin does not silently change an existing question scope", () => {
  const scope = flow.scopeForPlace("park");
  let map = flow.create();
  map.selectedId = "lane";
  assert.equal(flow.experienceId(scope), "park");
  assert.equal(flow.label(scope, catalog), "Parkside Café");
});
test("PF03: panning preserves the original answer result until explicit search-this-area", () => {
  const map = flow.fromAnswer(flow.create(), { roomId: 1, turn: 0 }, ["park", "lane"], "park");
  const panned = flow.pan(map, 90, 40);
  assert.equal(panned.areaDirty, true);
  assert.equal(flow.ids(panned, catalog, []).join(","), "park,lane");
  assert.deepEqual(normalize(panned.searchedCamera), { x: 0, y: 0 });
  const searched = flow.searchArea(panned);
  assert.equal(searched.areaDirty, false);
  assert.equal(searched.contextIds, null);
  assert.deepEqual(normalize(searched.searchedCamera), { x: 90, y: 40 });
  assert.equal(map.camera.x, 0);
});
test("PF04: saved places can be scoped to this city without deleting another city collection", () => {
  const saved = ["park", "chiangmai"];
  const map = { ...flow.create(), mode: "saved" };
  assert.equal(flow.ids(map, catalog, saved).join(","), "park");
  map.favoriteScope = "all";
  assert.equal(flow.ids(map, catalog, saved).join(","), "park,chiangmai");
  assert.deepEqual(saved, ["park", "chiangmai"]);
});
test("PF05: an empty saved map has no invented selected place", () => {
  const map = flow.reconcile({ ...flow.create(), mode: "saved" }, catalog, []);
  assert.equal(map.selectedId, null);
  assert.equal(flow.ids(map, catalog, []).length, 0);
});
test("PF06: filtering a selected coffee result to culture moves selection to a visible item", () => {
  const map = flow.reconcile({ ...flow.create(), category: "culture" }, catalog, []);
  assert.equal(map.selectedId, "museum");
  assert.equal(flow.ids(map, catalog, []).join(","), "museum");
});
test("PF07: an area question freezes its viewport and category at the time of asking", () => {
  const map = { ...flow.create(), camera: { x: 90, y: 40 }, category: "coffee" };
  const scope = flow.scopeForArea(map);
  map.camera.x = 150;
  map.category = "all";
  assert.deepEqual(normalize(scope.viewport), { x: 90, y: 40 });
  assert.equal(scope.category, "coffee");
  assert.equal(flow.experienceId(scope), null);
  assert.match(flow.label(scope, catalog), /这片地图/);
});
test("PF08: independent map revisits preserve the camera rather than recentring on every tab", () => {
  const entered = { ...flow.independent(flow.create()), camera: { x: 82, y: 55 } };
  const again = flow.independent(entered);
  assert.deepEqual(normalize(again.camera), { x: 82, y: 55 });
});
test("PF09: denied GPS can remain manual; the state contract does not invent a current location", () => {
  const map = { ...flow.create(), location: "denied" };
  const panned = flow.pan(map, 40, 0);
  assert.equal(panned.location, "denied");
  assert.equal("userCoordinates" in panned, false);
});

test("PF10: opening a recommendation clears a previous unmatched map query and fits its candidates", () => {
  const old = {
    ...flow.create(),
    query: "missing ramen",
    camera: { x: 100, y: 80 },
    category: "culture",
  };
  const next = flow.fromAnswer(old, { roomId: 2, turn: 1 }, ["park", "lane"], "not-in-this-answer");
  assert.equal(next.query, "");
  assert.equal(next.selectedId, "park");
  assert.equal(next.category, "all");
  assert.deepEqual(normalize(next.camera), { x: 0, y: 0 });
  assert.equal(flow.ids(next, catalog, []).join(","), "park,lane");
  assert.equal(old.query, "missing ramen");
});

test("PF11: a query with no matching fixture stays empty rather than recycling an unrelated result", () => {
  const next = flow.reconcile({ ...flow.create(), query: "ramen-no-such-fixture" }, catalog, []);
  assert.equal(flow.ids(next, catalog, []).length, 0);
  assert.equal(next.selectedId, null);
});

test("PF12: cafe and bookstore aliases constrain the visible fixture types", () => {
  const queryCatalog = [
    {
      id: "coffee",
      title: "Coffee fixture",
      name: "Coffee corner",
      category: "cafe",
      city: "tokyo",
    },
    {
      id: "books",
      title: "Book fixture",
      name: "Book corner",
      category: "bookstore",
      city: "tokyo",
    },
  ];
  assert.equal(flow.ids({ ...flow.create(), query: "咖啡" }, queryCatalog, []).join(","), "coffee");
  assert.equal(flow.ids({ ...flow.create(), query: "书店" }, queryCatalog, []).join(","), "books");
});

test("PF13: area question keeps query/viewport/category after further panning and edits", () => {
  const original = { ...flow.create(), query: "咖啡", category: "cafe", camera: { x: 80, y: 40 } };
  const scope = flow.scopeForArea(original);
  const changed = flow.pan(original, 1000, -1000);
  changed.query = "书店";
  changed.category = "bookstore";
  assert.equal(scope.query, "咖啡");
  assert.equal(scope.category, "cafe");
  assert.deepEqual(normalize(scope.viewport), { x: 80, y: 40 });
  assert.deepEqual(normalize(changed.camera), { x: 120, y: -120 });
});

test("PF14: two short map pans accumulate into a new search area", () => {
  const first = flow.pan(flow.create(), 24, 0);
  assert.equal(first.areaDirty, false);
  const second = flow.pan(first, 24, 0);
  assert.equal(second.areaDirty, true);
  assert.deepEqual(normalize(second.camera), { x: 48, y: 0 });
  assert.deepEqual(normalize(second.searchedCamera), { x: 0, y: 0 });
});

test("PF15: an area question freezes saved scope and the visible Experience IDs", () => {
  const ids = ["park", "lane"];
  const map = {
    ...flow.create(),
    mode: "saved",
    favoriteScope: "city",
    category: "cafe",
    query: "咖啡",
  };
  const scope = flow.scopeForArea(map, ids);
  ids.push("unrelated");
  map.mode = "nearby";
  map.favoriteScope = "all";
  map.query = "书店";
  assert.equal(scope.mode, "saved");
  assert.equal(scope.favoriteScope, "city");
  assert.deepEqual(normalize(scope.experienceIds), ["park", "lane"]);
  assert.equal(scope.query, "咖啡");
  assert.match(scope.label, /收藏/);
});
