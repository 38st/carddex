// Carddex `account-delete` Edge Function.
//
// Permanently deletes the signed-in user's account. Called from Settings →
// "Delete account" (App Store requirement 5.1.1(v)). Verifies the caller's
// JWT, then removes the auth user via the service-role admin API. All user
// tables (`collection_items`, `price_alerts`, `wishlists`, `subscriptions`,
// `scans`, `scan_usage`, `device_tokens`, `ebay_listings`) reference
// `auth.users(id) on delete cascade`, so deleting the auth user wipes every
// user-owned row automatically — no per-table deletes needed here.
//
// Request:  empty POST with `Authorization: Bearer <access_token>`
// Response: { deleted: true, userId } on success
//           401 when not signed in / token invalid
//           500 on admin failure

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  // Only the anon key is needed to verify the caller's JWT via getUser.
  // The service-role key is used solely for the admin delete below.
  // deno-lint-ignore no-explicit-any
  const anonClient: any = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
  );

  const auth = req.headers.get("Authorization");
  if (!auth?.startsWith("Bearer ")) {
    return json({ error: "missing authorization" }, 401);
  }
  const token = auth.slice(7);

  // Verify the caller's session and resolve their user id.
  const { data, error } = await anonClient.auth.getUser(token);
  if (error || !data?.user?.id) {
    return json({ error: "invalid or expired session" }, 401);
  }
  const userId = data.user.id;

  // Admin delete with the service-role key (bypasses RLS). Cascades to all
  // user tables via `on delete cascade` on `auth.users(id)`.
  // deno-lint-ignore no-explicit-any
  const adminClient: any = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { error: deleteError } = await adminClient.auth.admin.deleteUser(userId);
  if (deleteError) {
    return json({ error: deleteError.message }, 500);
  }

  return json({ deleted: true, userId });
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}
