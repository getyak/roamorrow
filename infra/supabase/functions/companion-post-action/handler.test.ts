import { test } from "node:test";
import assert from "node:assert/strict";
import { createPostActionHandler, type PostActionBackend } from "./handler.ts";
function fixture(overrides: Partial<PostActionBackend> = {}) {
  const writes: Record<string, unknown>[] = [];
  const backend: PostActionBackend = {
    authenticate: async () => "caller",
    post: async () => ({ id: "post", author_id: "actual-author", is_deleted: false }),
    profile: async () => ({ visibility: "itinerary_only", reporter_weight: 1 }),
    blocked: async () => false,
    completed: async () => false,
    perform: async (_token, _action, row) => {
      writes.push(row);
      return row;
    },
    ...overrides,
  };
  const handler = createPostActionHandler(backend);
  const run = (
    body: unknown = {
      action: "request",
      actionId: "stable_1",
      postId: "post",
      recipientId: "forged-author",
    },
    token = "valid",
  ) =>
    handler(
      new Request("https://local.test", {
        method: "POST",
        headers: token ? { Authorization: "Bearer " + token } : {},
        body: JSON.stringify(body),
      }),
    );
  return { run, writes };
}
test("all actions resolve actual author and ignore forged recipient/requester", async () => {
  for (const action of ["request", "friend", "report", "block"]) {
    const { run, writes } = fixture();
    const response = await run({
      action,
      actionId: "stable_1",
      postId: "post",
      recipientId: "wrong",
      requesterId: "wrong",
      reason: "spam",
    });
    assert.equal(response.status, 200);
    assert.equal(writes.length, 1);
    const row = writes[0]!;
    assert.equal(row.recipient_id ?? row.target_user_id ?? row.blocked_id, "actual-author");
    assert.equal(row.requester_id ?? row.reporter_id ?? row.blocker_id, "caller");
    assert.deepEqual(await response.json(), { saved: true });
  }
});
test("unauthenticated actions never read or write", async () => {
  const { run, writes } = fixture({
    authenticate: async () => null,
    post: async () => {
      throw Error("must not read");
    },
  });
  assert.equal((await run(undefined, "")).status, 401);
  assert.equal((await run()).status, 401);
  assert.equal(writes.length, 0);
});
test("deleted, own, hidden, low-trust, missing and blocked targets fail closed", async () => {
  const cases: Partial<PostActionBackend>[] = [
    { post: async () => null },
    { post: async () => ({ id: "post", author_id: "actual-author", is_deleted: true }) },
    { post: async () => ({ id: "post", author_id: "caller", is_deleted: false }) },
    { profile: async () => null },
    { profile: async () => ({ visibility: "off", reporter_weight: 1 }) },
    { profile: async () => ({ visibility: "itinerary_only", reporter_weight: 0.2 }) },
    { blocked: async () => true },
  ];
  for (const overrides of cases) {
    const { run, writes } = fixture(overrides);
    assert.equal((await run()).status, 404);
    assert.equal(writes.length, 0);
  }
});
test("block lookup/storage failures and empty success do not acknowledge", async () => {
  for (const overrides of [
    {
      blocked: async () => {
        throw Error("db secret");
      },
    },
    {
      perform: async () => {
        throw Error("db secret");
      },
    },
    { perform: async () => ({}) },
  ]) {
    const { run } = fixture(overrides);
    const response = await run();
    assert.equal(response.status, 503);
    assert.ok(!(await response.text()).includes("db secret"));
  }
});
test("validation and note caps apply before storage", async () => {
  const { run, writes } = fixture();
  for (const body of [
    null,
    [],
    { action: "delete", actionId: "one", postId: "post" },
    { action: "report", actionId: "one", postId: "post", reason: "bad" },
  ]) {
    assert.equal((await run(body)).status, 400);
  }
  assert.equal(writes.length, 0);
  await run({ action: "friend", actionId: "one", postId: "post", note: "x".repeat(200) });
  assert.equal((writes[0]!.note as string).length, 120);
  assert.equal(writes[0]!.source, "discover");
});
test("low-trust caller cannot send discover friend requests", async () => {
  const { run, writes } = fixture({
    profile: async (id) => ({
      visibility: "itinerary_only",
      reporter_weight: id === "caller" ? 0.1 : 1,
    }),
  });
  assert.equal((await run({ action: "friend", actionId: "one", postId: "post" })).status, 403);
  assert.equal(writes.length, 0);
});
test("changed snapshot after lost acknowledgement returns409 and never writes", async () => {
  const { run, writes } = fixture({ completed: async () => "conflict" });
  const response = await run();
  assert.equal(response.status, 409);
  assert.equal(writes.length, 0);
});

test("lost block/report/request acknowledgements remain retryable after mutable eligibility changes", async () => {
  for (const action of ["block", "report", "request"]) {
    let written = false;
    const { run, writes } = fixture({
      blocked: async () => written,
      profile: async () => ({
        visibility: written ? "off" : "itinerary_only",
        reporter_weight: written ? 0.1 : 1,
      }),
      completed: async (_t, _a, id, caller, post) =>
        written && id === "stable_1" && caller === "caller" && post.author_id === "actual-author",
      perform: async (_t, _a, row) => {
        written = true;
        writes.push(row);
        return row;
      },
    });
    const body = { action, actionId: "stable_1", postId: "post", reason: "spam" };
    assert.equal((await run(body)).status, 200);
    assert.equal((await run(body)).status, 200);
    assert.equal(writes.length, 1);
    assert.equal((await run({ ...body, actionId: "different_intent" })).status, 404);
  }
});
