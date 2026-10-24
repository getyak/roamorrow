// Edge Function: message-notify
//
// US-024 / FRD-023: send an APNs push to the OTHER party of a 1:1 conversation
// when a new chat message arrives. Called by the client right after
// `ChatService.send` inserts a `chat_messages` row, so the recipient gets a
// "new message" banner even when the app is backgrounded (Realtime only fires
// while that conversation's channel is subscribed).
//
// Request:  POST { messageId } + Authorization: Bearer <JWT>
// Response: 200 { delivered: <int>, total: <int> }  — APNs accepted N of M tokens
//           400 { error: ... }                       — missing/invalid body
//           401 { error: ... }                       — missing/invalid JWT
//           403 { error: ... }                       — caller is not the sender
//           404 { error: "not found" }               — unknown message id
//           500 { error: ... }                       — lookup / APNs config failure
//
// APNs payload (aps.alert + custom keys):
//   { type: "message", conversationId, senderHandle, preview }
// The device's NotificationService routes `type == message` → deep link to the
// matching ChatView for `conversationId`.
//
// Security:
//   - Verifies the caller's Supabase JWT (must be signed in).
//   - Re-checks ownership: the caller MUST be the message's `sender_id`.
//     A client cannot fire a push on behalf of someone else's message.
//   - NEVER pushes the sender: recipients = conversation participants − sender.
//     A self-only conversation (no other party) delivers to nobody.
//   - Service role is used ONLY to read the other party's push tokens
//     (device_push_tokens has a self-only SELECT policy — the sender cannot
//     read the recipient's tokens under RLS). Tokens never leave this function.
//
// Deploy:  `supabase functions deploy message-notify`
// Secrets (token-based APNs, .p8 auth) — shared with friend-request-notify:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY   (auto-injected by Supabase)
//   APNS_KEY_P8     — contents of the AuthKey_XXXX.p8 (PEM, incl. BEGIN/END)
//   APNS_KEY_ID     — the 10-char Key ID for that .p8
//   APNS_TEAM_ID    — the 10-char Apple Developer Team ID
//   APNS_TOPIC      — the app bundle id (e.g. com.solocompass.app)
//   APNS_HOST       — "api.push.apple.com" (prod) | "api.sandbox.push.apple.com" (dev)
//                     defaults to the sandbox host when unset.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { authenticateBearerRequest, json } from "../_shared/request-auth.ts";
import { createApnsSender } from "../_shared/apns.ts";

interface NotifyResult {
  delivered: number;
  total: number;
}

/// Max characters of the message body surfaced in the banner. Keeps PII / long
/// text out of the push and respects the APNs alert-body size budget.
const PREVIEW_MAX = 140;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Authorization, Content-Type",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
      },
    });
  }
  if (req.method !== "POST") {
    return json({ error: "method not allowed" }, 405);
  }

  // 1. Verify JWT — caller must be signed in.
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const authentication = await authenticateBearerRequest(req, (jwt) =>
    createClient(supabaseUrl, jwt, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
      auth: { persistSession: false },
    }),
  );
  if (authentication instanceof Response) return authentication;
  const callerId = authentication.userId;

  // 2. Parse the message id.
  let body: { messageId?: unknown };
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid json body" }, 400);
  }
  const messageId = typeof body.messageId === "string" ? body.messageId.trim() : "";
  if (!messageId) return json({ error: "messageId is required" }, 400);

  // 3. Service-role client — read the message + conversation participants +
  //    recipient tokens (RLS would otherwise hide the recipient's tokens).
  const svc = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  const { data: msgRow, error: msgErr } = await svc
    .from("chat_messages")
    .select("conversation_id, sender_id, body")
    .eq("id", messageId)
    .maybeSingle();

  if (msgErr) return json({ error: "lookup failed" }, 500);
  if (!msgRow) return json({ error: "not found" }, 404);

  // 4. Ownership: only the message's sender may trigger this push.
  if (msgRow.sender_id !== callerId) {
    return json({ error: "forbidden" }, 403);
  }

  const conversationId = msgRow.conversation_id as string;

  // 5. Resolve the conversation's participants → recipients = everyone but the
  //    sender. NEVER push the sender (callerId).
  const { data: convRow, error: convErr } = await svc
    .from("conversations")
    .select("participant_ids")
    .eq("id", conversationId)
    .maybeSingle();

  if (convErr) return json({ error: "conversation lookup failed" }, 500);
  if (!convRow) return json({ error: "not found" }, 404);

  const participants = Array.isArray(convRow.participant_ids)
    ? (convRow.participant_ids as unknown[]).filter((p): p is string => typeof p === "string")
    : [];
  const recipientIds = participants.filter((id) => id !== callerId);

  if (recipientIds.length === 0) {
    // No other party (self-only conversation) → nobody to notify.
    const empty: NotifyResult = { delivered: 0, total: 0 };
    return json(empty, 200);
  }

  // 6. Resolve the sender's public handle for the banner title (same convention
  //    as friend-request-notify / redeem-friend-code: handle in auth metadata,
  //    avatar emoji on companion_profiles as the fallback).
  const { data: profile } = await svc
    .from("companion_profiles")
    .select("avatar_emoji")
    .eq("user_id", callerId)
    .maybeSingle();
  const senderEmoji = (profile?.avatar_emoji as string | undefined) ?? "🧭";

  let senderHandle = "";
  const { data: senderUser } = await svc.auth.admin.getUserById(callerId);
  const meta = senderUser?.user?.user_metadata as
    { display_handle?: unknown; displayHandle?: unknown } | undefined;
  if (typeof meta?.display_handle === "string") senderHandle = meta.display_handle;
  else if (typeof meta?.displayHandle === "string") senderHandle = meta.displayHandle;
  if (!senderHandle) senderHandle = senderEmoji; // never empty.

  // 7. Truncate the body for the preview — keep long text / PII out of the push.
  const rawBody = typeof msgRow.body === "string" ? msgRow.body : "";
  const preview = rawBody.length > PREVIEW_MAX ? `${rawBody.slice(0, PREVIEW_MAX - 1)}…` : rawBody;

  // 8. Look up the recipients' device tokens (every participant but the sender).
  //    No tokens → nothing to deliver. 200 with 0.
  const { data: tokens, error: tokensErr } = await svc
    .from("device_push_tokens")
    .select("token")
    .in("user_id", recipientIds);

  if (tokensErr) return json({ error: "token lookup failed" }, 500);
  const deviceTokens = (tokens ?? [])
    .map((r) => (typeof r.token === "string" ? r.token : ""))
    .filter((t) => t.length > 0);

  if (deviceTokens.length === 0) {
    const empty: NotifyResult = { delivered: 0, total: 0 };
    return json(empty, 200);
  }

  // 9. Build the APNs provider JWT (token-based auth, ES256 over the .p8 key).
  let sender: Awaited<ReturnType<typeof createApnsSender>>;
  try {
    sender = await createApnsSender((name) => Deno.env.get(name));
  } catch (error) {
    return json({ error: `apns config error: ${(error as Error).message}` }, 500);
  }

  // 10. Send to every registered device. APNs is one request per token.
  const apsPayload = JSON.stringify({
    aps: {
      alert: {
        title: senderHandle,
        body: preview.length > 0 ? preview : "sent you a message",
      },
      sound: "default",
    },
    type: "message",
    conversationId,
    senderHandle,
    preview,
  });

  const result = await sender.send(deviceTokens, apsPayload, async (token) => {
    await svc.from("device_push_tokens").delete().eq("token", token);
  });
  return json(result, 200);
});
