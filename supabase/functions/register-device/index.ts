// Carddex `register-device` Edge Function.
//
// Stores the caller's APNs device token so the `push-price-alerts` job can push
// price alerts while the app is closed. Requires the user's JWT; upserts into
// `device_tokens (user_id, token)` (created in migration 0005).
//
// Request (POST):  { token: string, platform?: "ios" }
// Response:        { ok: true }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const auth = req.headers.get("Authorization");
    if (!auth?.startsWith("Bearer ")) return json({ error: "unauthorized" }, 401);

    const { token, platform } = await req.json();
    if (typeof token !== "string" || token.length < 16) {
      return json({ error: "invalid token" }, 400);
    }

    // deno-lint-ignore no-explicit-any
    const supabase: any = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const { data } = await supabase.auth.getUser(auth.slice(7));
    const userId = data?.user?.id;
    if (!userId) return json({ error: "unauthorized" }, 401);

    await supabase.from("device_tokens").upsert({
      user_id: userId,
      token,
      platform: platform ?? "ios",
      updated_at: new Date().toISOString(),
    }, { onConflict: "user_id,token" });

    return json({ ok: true });
  } catch (err) {
    return json({ error: String(err) }, 500);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "content-type": "application/json" },
  });
}
