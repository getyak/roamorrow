import { IntentConflict, type PostActionBackend } from "./handler.ts";
interface Result {
  data: Record<string, unknown> | null;
  error: { code?: string } | null;
}
export interface ActionDatabase {
  read(table: string, filters: Record<string, unknown>): PromiseLike<Result>;
  insert(table: string, row: Record<string, unknown>): PromiseLike<Result>;
}
const actionTable = {
  request: "companion_requests",
  friend: "friend_requests",
  report: "companion_reports",
  block: "companion_blocks",
};
function matches(
  row: Record<string, unknown>,
  action: string,
  caller: string,
  target: string,
  postId: string,
): boolean {
  const ownerKey =
    action === "report" ? "reporter_id" : action === "block" ? "blocker_id" : "requester_id";
  const targetKey =
    action === "report" ? "target_user_id" : action === "block" ? "blocked_id" : "recipient_id";
  return (
    row[ownerKey] === caller &&
    row[targetKey] === target &&
    (action !== "request" || row.post_id === postId)
  );
}
export function createActionPersistence(
  clientFor: (token: string) => ActionDatabase,
): Pick<PostActionBackend, "completed" | "perform"> {
  return {
    async completed(token, action, actionId, caller, post, intent) {
      const table = actionTable[action];
      const filters =
        action === "block" ? { blocker_id: caller, blocked_id: post.author_id } : { id: actionId };
      const { data, error } = await clientFor(token).read(table, filters);
      if (error) throw error;
      if (!data) return false;
      if (!matches(data, action, caller, post.author_id, post.id)) return false;
      return sameIntent(data, intent) ? true : "conflict";
    },
    async perform(token, action, row) {
      const client = clientFor(token); // Service role reads identities, never writes actions.
      const table = actionTable[action];
      const { data, error } = await client.insert(table, row);
      if (!error && data) return data;
      // Two concurrent retries can both miss the receipt. A unique conflict is
      // resolved by a scoped read, never an upsert overwriting accepted status.
      if (error?.code === "23505") {
        const filters =
          action === "block"
            ? { blocker_id: row.blocker_id, blocked_id: row.blocked_id }
            : { id: row.id };
        const existing = await client.read(table, filters);
        const owner = String(
          action === "report"
            ? row.reporter_id
            : action === "block"
              ? row.blocker_id
              : row.requester_id,
        );
        const target = String(
          action === "report"
            ? row.target_user_id
            : action === "block"
              ? row.blocked_id
              : row.recipient_id,
        );
        if (
          !existing.error &&
          existing.data &&
          matches(existing.data, action, owner, target, String(row.post_id ?? ""))
        ) {
          if (
            !sameIntent(
              existing.data,
              action === "report"
                ? { reason: row.reason, details: row.details }
                : action === "block"
                  ? {}
                  : { note: row.note },
            )
          )
            throw new IntentConflict("intent conflict");
          return existing.data;
        }
      }
      throw error ?? new Error("no acknowledgement");
    },
  };
}

function sameIntent(row: Record<string, unknown>, intent: Record<string, unknown>): boolean {
  return Object.entries(intent).every(([key, value]) => (row[key] ?? null) === (value ?? null));
}
