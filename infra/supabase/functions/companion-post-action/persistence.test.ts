import { test } from "node:test";
import assert from "node:assert/strict";
import { createActionPersistence, type ActionDatabase } from "./persistence.ts";
function fixture(reads: object[], inserts: object[]) {
  const tokens: string[] = [];
  const filters: [string, unknown][] = [];
  const client: ActionDatabase = {
    read: async (_table, where) => {
      filters.push(...Object.entries(where));
      return reads.shift() as never;
    },
    insert: async () => inserts.shift() as never,
  };
  return {
    store: createActionPersistence((token) => {
      tokens.push(token);
      return client;
    }),
    tokens,
    filters,
  };
}
const row = {
  id: "one",
  requester_id: "caller",
  recipient_id: "author",
  post_id: "post",
  status: "pending",
};
test("concurrent unique collision rereads caller-owned receipt without replacing accepted state", async () => {
  const accepted = { ...row, status: "accepted" };
  const { store, tokens, filters } = fixture(
    [{ data: accepted, error: null }],
    [{ data: null, error: { code: "23505" } }],
  );
  assert.deepEqual(await store.perform("user-jwt", "request", row), accepted);
  assert.deepEqual(tokens, ["user-jwt"]);
  assert.deepEqual(filters, [["id", "one"]]);
});
test("id collision with another participant/post is never acknowledged", async () => {
  for (const different of [
    { ...row, requester_id: "someone" },
    { ...row, recipient_id: "someone" },
    { ...row, post_id: "different" },
  ]) {
    const { store } = fixture(
      [{ data: different, error: null }],
      [{ data: null, error: { code: "23505" } }],
    );
    await assert.rejects(store.perform("jwt", "request", row));
  }
});
test("block receipt checks both caller and target under the user JWT", async () => {
  const { store, filters } = fixture(
    [{ data: { blocker_id: "caller", blocked_id: "author" }, error: null }],
    [],
  );
  assert.equal(
    await store.completed(
      "jwt",
      "block",
      "intent",
      "caller",
      {
        id: "post",
        author_id: "author",
        is_deleted: true,
      },
      {},
    ),
    true,
  );
  assert.deepEqual(filters, [
    ["blocker_id", "caller"],
    ["blocked_id", "author"],
  ]);
});
test("empty and silent database responses do not acknowledge persistence", async () => {
  for (const response of [
    { data: null, error: null },
    { data: null, error: { code: "42501" } },
  ]) {
    const { store } = fixture([], [response]);
    await assert.rejects(store.perform("jwt", "request", row));
  }
});
test("receipt never acknowledges later-edited note or report details", async () => {
  for (const action of ["request", "friend", "report"] as const) {
    const receipt =
      action === "report"
        ? {
            id: "one",
            reporter_id: "caller",
            target_user_id: "author",
            reason: "spam",
            details: "original",
          }
        : { ...row, note: "original" };
    const { store } = fixture([{ data: receipt, error: null }], []);
    const intent = action === "report" ? { reason: "spam", details: "edited" } : { note: "edited" };
    assert.equal(
      await store.completed(
        "jwt",
        action,
        "one",
        "caller",
        { id: "post", author_id: "author", is_deleted: false },
        intent,
      ),
      "conflict",
    );
  }
});
test("concurrent receipt for different text is a conflict rather than success", async () => {
  const { store } = fixture(
    [{ data: { ...row, note: "original" }, error: null }],
    [{ data: null, error: { code: "23505" } }],
  );
  await assert.rejects(store.perform("jwt", "request", { ...row, note: "edited" }), {
    name: "Error",
    message: "intent conflict",
  });
});
