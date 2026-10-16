/** Resolve an anonymized post after an explicit action. Client identities are
 * never trusted; every write uses the caller's RLS-scoped client. */
export interface PostActor {
  id: string;
  author_id: string;
  is_deleted: boolean;
}
export type PostAction = "request" | "friend" | "report" | "block";
export class IntentConflict extends Error {}
export interface PostActionBackend {
  authenticate(token: string): Promise<string | null>;
  post(id: string): Promise<PostActor | null>;
  profile(id: string): Promise<{ visibility: string; reporter_weight: number } | null>;
  blocked(a: string, b: string): Promise<boolean>;
  completed(
    token: string,
    action: PostAction,
    actionId: string,
    caller: string,
    post: PostActor,
    intent: Record<string, unknown>,
  ): Promise<boolean | "conflict">;
  perform(
    token: string,
    action: PostAction,
    row: Record<string, unknown>,
  ): Promise<Record<string, unknown>>;
}
const reasons = new Set(["spam", "harassment", "inappropriate_content", "fake_profile", "other"]);
const headers = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (value: unknown, status = 200) =>
  new Response(JSON.stringify(value), { status, headers });
export function createPostActionHandler(backend: PostActionBackend) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers });
    if (req.method !== "POST") return json({ error: "method not allowed" }, 405);
    const token = /^Bearer\s+(.+)$/i.exec(req.headers.get("Authorization") ?? "")?.[1];
    if (!token) return json({ error: "sign in required" }, 401);
    try {
      const caller = await backend.authenticate(token);
      if (!caller) return json({ error: "sign in required" }, 401);
      let body: Record<string, unknown>;
      try {
        body = await req.json();
      } catch {
        return json({ error: "invalid request" }, 400);
      }
      if (!body || typeof body !== "object" || Array.isArray(body))
        return json({ error: "invalid request" }, 400);
      const action = body.action as PostAction;
      if (
        !["request", "friend", "report", "block"].includes(action) ||
        typeof body.postId !== "string" ||
        !body.postId.trim() ||
        body.postId.length > 200 ||
        typeof body.actionId !== "string" ||
        !/^[a-zA-Z0-9_-]{1,100}$/.test(body.actionId)
      ) {
        return json({ error: "invalid action" }, 400);
      }
      if (action === "report" && (typeof body.reason !== "string" || !reasons.has(body.reason))) {
        return json({ error: "invalid report reason" }, 400);
      }
      if (
        (body.note != null && typeof body.note !== "string") ||
        (body.details != null && typeof body.details !== "string")
      ) {
        return json({ error: "invalid message" }, 400);
      }
      const post = await backend.post(body.postId.trim());
      // Hidden/deleted/own/blocked targets share one unavailable response.
      // A failed profile or block query throws and fails closed.
      if (!post || post.author_id === caller) return json({ error: "post unavailable" }, 404);
      const intent: Record<string, unknown> =
        action === "report"
          ? {
              reason: body.reason,
              details:
                typeof body.details === "string" ? body.details.trim().slice(0, 500) || null : null,
            }
          : action === "block"
            ? {}
            : {
                note:
                  typeof body.note === "string"
                    ? body.note.trim().slice(0, action === "friend" ? 120 : 200) || null
                    : null,
              };
      // Retry confirms exactly the submitted snapshot, never later-edited text.
      const completed = await backend.completed(token, action, body.actionId, caller, post, intent);
      if (completed === "conflict")
        return json(
          { error: "Previous submission was saved; edited text has not been sent." },
          409,
        );
      if (completed) return json({ saved: true });
      if (post.is_deleted) return json({ error: "post unavailable" }, 404);
      const profile = await backend.profile(post.author_id);
      if (
        !profile ||
        profile.visibility === "off" ||
        profile.reporter_weight < 0.3 ||
        (await backend.blocked(caller, post.author_id))
      )
        return json({ error: "post unavailable" }, 404);
      if (action === "friend") {
        const requester = await backend.profile(caller);
        if (requester && requester.reporter_weight < 0.3)
          return json({ error: "request unavailable" }, 403);
      }
      const now = new Date().toISOString();
      const row: Record<string, unknown> =
        action === "block"
          ? { blocker_id: caller, blocked_id: post.author_id }
          : action === "report"
            ? {
                id: body.actionId,
                reporter_id: caller,
                target_user_id: post.author_id,
                reason: body.reason,
                details:
                  typeof body.details === "string"
                    ? body.details.trim().slice(0, 500) || null
                    : null,
              }
            : {
                id: body.actionId,
                requester_id: caller,
                recipient_id: post.author_id,
                status: "pending",
                note:
                  typeof body.note === "string"
                    ? body.note.trim().slice(0, action === "friend" ? 120 : 200) || null
                    : null,
                ...(action === "request"
                  ? { post_id: post.id }
                  : {
                      source: "discover",
                      expires_at: new Date(Date.now() + 7 * 86400000).toISOString(),
                    }),
                created_at: now,
                updated_at: now,
              };
      const saved = await backend.perform(token, action, row);
      // Empty PostgREST 200 is not a persistence acknowledgement.
      if (action !== "block" && saved.id !== body.actionId)
        return json({ error: "action not saved" }, 503);
      if (
        action === "block" &&
        (saved.blocker_id !== caller || saved.blocked_id !== post.author_id)
      )
        return json({ error: "action not saved" }, 503);
      return json({ saved: true });
    } catch (error) {
      if (error instanceof IntentConflict)
        return json(
          { error: "Previous submission was saved; edited text has not been sent." },
          409,
        );
      return json({ error: "Could not save. Please retry." }, 503);
    }
  };
}
