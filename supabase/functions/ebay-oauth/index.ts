// Carddex `ebay-oauth` Edge Function — connect a user's eBay seller account.
//
// Two routes:
//   GET  ?action=start     → returns { consentUrl } (eBay OAuth consent page)
//   GET  ?action=callback  → eBay redirects here with ?code&state; we exchange the
//                            code for tokens and store them ENCRYPTED in ebay_accounts.
//
// Secrets (Edge Function env): EBAY_CLIENT_ID, EBAY_CLIENT_SECRET, EBAY_REDIRECT_URI.
// The app never sees eBay tokens. See docs/backend-plan.md §3.3.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
};

const SCOPES = [
  "https://api.ebay.com/oauth/api_scope/sell.inventory",
  "https://api.ebay.com/oauth/api_scope/sell.account",
].join(" ");

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const url = new URL(req.url);
  const action = url.searchParams.get("action");
  const clientId = Deno.env.get("EBAY_CLIENT_ID")!;
  const redirectUri = Deno.env.get("EBAY_REDIRECT_URI")!;

  if (action === "start") {
    // `state` must bind the Supabase user id (derive from the verified JWT) so the
    // callback can attribute the tokens. TODO: sign/verify state.
    const state = crypto.randomUUID();
    const consentUrl = `https://auth.ebay.com/oauth2/authorize?client_id=${clientId}` +
      `&response_type=code&redirect_uri=${encodeURIComponent(redirectUri)}` +
      `&scope=${encodeURIComponent(SCOPES)}&state=${state}`;
    return json({ consentUrl });
  }

  if (action === "callback") {
    const code = url.searchParams.get("code");
    if (!code) return json({ error: { code: "BAD_REQUEST", message: "missing code" } }, 400);

    // TODO: POST to https://api.ebay.com/identity/v1/oauth2/token with
    //   grant_type=authorization_code, code, redirect_uri, Basic(client:secret)
    //   → { access_token, refresh_token, expires_in, refresh_token_expires_in }.
    // Then encrypt and upsert into ebay_accounts (service role), keyed by the
    // user id recovered from `state`. Also fetch/create business policies +
    // merchant location and cache their ids (required to publish offers).
    const _supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Redirect back into the app via its deep link.
    return new Response(null, { status: 302, headers: { ...cors, Location: "carddex://ebay/connected" } });
  }

  return json({ error: { code: "BAD_REQUEST", message: "unknown action" } }, 400);
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "content-type": "application/json" },
  });
}
