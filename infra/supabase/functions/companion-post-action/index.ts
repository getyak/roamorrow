// Deploy alongside the iOS discovery update. companion-discover stays anonymous.
// Gateway JWT verification must remain enabled.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { createPostActionHandler, type PostActionBackend } from "./handler.ts";
import { createActionPersistence } from "./persistence.ts";

const url = Deno.env.get("SUPABASE_URL")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false },
});
const clientFor = (token: string) =>
  createClient(url, anonKey, {
    global: { headers: { Authorization: "Bearer " + token } },
    auth: { persistSession: false },
  });
const backend: PostActionBackend = {
  async authenticate(token) {
    const { data, error } = await clientFor(token).auth.getUser(token);
    return error ? null : (data.user?.id ?? null);
  },
  async post(id) {
    const { data, error } = await admin
      .from("companion_posts")
      .select("id,author_id,is_deleted")
      .eq("id", id)
      .maybeSingle();
    if (error) throw error;
    return data;
  },
  async profile(id) {
    const { data, error } = await admin
      .from("companion_profiles")
      .select("visibility,reporter_weight")
      .eq("user_id", id)
      .maybeSingle();
    if (error) throw error;
    return data;
  },
  async blocked(a, b) {
    const { data, error } = await admin
      .from("companion_blocks")
      .select("blocker_id")
      .or(
        "and(blocker_id.eq." +
          a +
          ",blocked_id.eq." +
          b +
          "),and(blocker_id.eq." +
          b +
          ",blocked_id.eq." +
          a +
          ")",
      )
      .limit(1);
    if (error) throw error;
    return Boolean(data?.length);
  },
  ...createActionPersistence((token) => ({
    async read(table, filters) {
      let query = clientFor(token).from(table).select("*");
      for (const [key, value] of Object.entries(filters)) query = query.eq(key, value);
      return await query.maybeSingle();
    },
    async insert(table, row) {
      return await clientFor(token).from(table).insert(row).select("*").single();
    },
  })),
};
Deno.serve(createPostActionHandler(backend));
