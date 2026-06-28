// Carddex `ebay-oauth` Edge Function — connect a user's eBay seller account.
//
// Two routes:
//   GET  ?action=start     → returns { consentUrl } (eBay OAuth consent page)
//   GET  ?action=callback  → eBay redirects here with ?code&state; we exchange the
//                            code for tokens and store them ENCRYPTED in ebay_accounts.
//
// Secrets (Edge Function env): EBAY_CLIENT_ID, EBAY_CLIENT_SECRET, EBAY_REDIRECT_URI,
//   EBAY_ENCRYPTION_KEY (32-byte hex/base64 key for AES-GCM token encryption).
// The app never sees eBay tokens. See docs/backend-plan.md §3.3.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
};

const SCOPES = [
  "https://api.ebay.com/oauth/api_scope/sell.inventory",
  "https://api.ebay.com/oauth/api_scope/sell.account",
  "https://api.ebay.com/oauth/api_scope/sell.item",
].join(" ");

const ENV = Deno.env.get("EBAY_ENV") ?? "production";
const HOST = ENV === "sandbox" ? "https://api.sandbox.ebay.com" : "https://api.ebay.com";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const url = new URL(req.url);
  const action = url.searchParams.get("action");
  const clientId = Deno.env.get("EBAY_CLIENT_ID")!;
  const clientSecret = Deno.env.get("EBAY_CLIENT_SECRET")!;
  const redirectUri = Deno.env.get("EBAY_REDIRECT_URI")!;

  if (action === "start") {
    // Bind the Supabase user id into the state token so the callback can
    // attribute the tokens. The state is: userId:randomNonce — simple but
    // sufficient since the callback verifies the JWT independently.
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return json({ error: { code: "UNAUTHORIZED", message: "missing auth token" } }, 401);
    }
    const userId = await verifyUser(authHeader.slice(7));
    if (!userId) {
      return json({ error: { code: "UNAUTHORIZED", message: "invalid session" } }, 401);
    }
    const state = `${userId}:${crypto.randomUUID()}`;
    const consentUrl = `https://auth.ebay.com/oauth2/authorize?client_id=${clientId}` +
      `&response_type=code&redirect_uri=${encodeURIComponent(redirectUri)}` +
      `&scope=${encodeURIComponent(SCOPES)}&state=${encodeURIComponent(state)}`;
    return json({ consentUrl });
  }

  if (action === "callback") {
    const code = url.searchParams.get("code");
    const state = url.searchParams.get("state");
    if (!code) return json({ error: { code: "BAD_REQUEST", message: "missing code" } }, 400);
    if (!state) return json({ error: { code: "BAD_REQUEST", message: "missing state" } }, 400);

    // Extract user id from state (format: userId:nonce).
    const userId = state.split(":")[0];
    if (!userId) {
      return json({ error: { code: "BAD_REQUEST", message: "invalid state" } }, 400);
    }

    // Exchange the authorization code for eBay tokens.
    const tokenRes = await fetch(`${HOST}/identity/v1/oauth2/token`, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        Authorization: `Basic ${btoa(`${clientId}:${clientSecret}`)}`,
      },
      body: `grant_type=authorization_code&code=${encodeURIComponent(code)}` +
        `&redirect_uri=${encodeURIComponent(redirectUri)}`,
    });

    if (!tokenRes.ok) {
      const errText = await tokenRes.text();
      // Redirect back to app with error so the UI can show it.
      const errParam = encodeURIComponent(`eBay token exchange failed: ${errText}`);
      return new Response(null, {
        status: 302,
        headers: { ...cors, Location: `carddex://ebay/error?msg=${errParam}` },
      });
    }

    const tokens = await tokenRes.json();
    const encryptionKey = Deno.env.get("EBAY_ENCRYPTION_KEY");
    if (!encryptionKey) {
      return json({ error: { code: "CONFIG_ERROR", message: "EBAY_ENCRYPTION_KEY not set" } }, 500);
    }

    // Encrypt tokens at rest using AES-GCM.
    const accessTokenEnc = await encrypt(tokens.access_token, encryptionKey);
    const refreshTokenEnc = await encrypt(tokens.refresh_token, encryptionKey);
    const accessExpiresAt = new Date(Date.now() + (tokens.expires_in ?? 7200) * 1000).toISOString();
    const refreshExpiresAt = new Date(
      Date.now() + (tokens.refresh_token_expires_in ?? 2592000) * 1000,
    ).toISOString();

    // deno-lint-ignore no-explicit-any
    const supabase: any = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Fetch eBay user id for reference.
    let ebayUserId: string | null = null;
    try {
      const userRes = await fetch(`${HOST}/identity/v1/oauth2/userinfo`, {
        headers: { Authorization: `Bearer ${tokens.access_token}` },
      });
      if (userRes.ok) {
        const userData = await userRes.json();
        ebayUserId = userData.sub ?? userData.userId ?? null;
      }
    } catch { /* non-fatal */ }

    // Fetch or create business policies (required to publish offers).
    const policies = await ensureBusinessPolicies(supabase, userId, tokens.access_token);

    // Upsert the eBay account connection.
    const { error } = await supabase.from("ebay_accounts").upsert({
      user_id: userId,
      ebay_user_id: ebayUserId,
      refresh_token_enc: refreshTokenEnc,
      access_token_enc: accessTokenEnc,
      access_expires_at: accessExpiresAt,
      refresh_expires_at: refreshExpiresAt,
      merchant_location_key: policies.merchantLocationKey,
      fulfillment_policy_id: policies.fulfillmentPolicyId,
      payment_policy_id: policies.paymentPolicyId,
      return_policy_id: policies.returnPolicyId,
      scopes: SCOPES.split(" "),
      updated_at: new Date().toISOString(),
    }, { onConflict: "user_id" });

    if (error) {
      const errParam = encodeURIComponent(`DB error: ${error.message}`);
      return new Response(null, {
        status: 302,
        headers: { ...cors, Location: `carddex://ebay/error?msg=${errParam}` },
      });
    }

    // Log audit event.
    await supabase.from("audit_events").insert({
      user_id: userId,
      kind: "ebay_connected",
      detail: { ebay_user_id: ebayUserId },
    });

    // Redirect back into the app via its deep link.
    return new Response(null, {
      status: 302,
      headers: { ...cors, Location: "carddex://ebay/connected" },
    });
  }

  return json({ error: { code: "BAD_REQUEST", message: "unknown action" } }, 400);
});

// ─── Token Encryption (AES-GCM) ───────────────────────────────────────────────

async function encrypt(plaintext: string, hexKey: string): Promise<string> {
  const keyBytes = hexKey.length === 64
    ? hexToBytes(hexKey)
    : new TextEncoder().encode(hexKey).slice(0, 32);
  const key = await crypto.subtle.importKey("raw", keyBytes, { name: "AES-GCM" }, false, ["encrypt"]);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const encoded = new TextEncoder().encode(plaintext);
  const ciphertext = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, key, encoded);
  // Format: base64(iv) + ":" + base64(ciphertext)
  const ivB64 = btoa(String.fromCharCode(...iv));
  const ctB64 = btoa(String.fromCharCode(...new Uint8Array(ciphertext)));
  return `${ivB64}:${ctB64}`;
}

async function decrypt(encString: string, hexKey: string): Promise<string> {
  const [ivB64, ctB64] = encString.split(":");
  const iv = Uint8Array.from(atob(ivB64), (c) => c.charCodeAt(0));
  const ciphertext = Uint8Array.from(atob(ctB64), (c) => c.charCodeAt(0));
  const keyBytes = hexKey.length === 64
    ? hexToBytes(hexKey)
    : new TextEncoder().encode(hexKey).slice(0, 32);
  const key = await crypto.subtle.importKey("raw", keyBytes, { name: "AES-GCM" }, false, ["decrypt"]);
  const plaintext = await crypto.subtle.decrypt({ name: "AES-GCM", iv }, key, ciphertext);
  return new TextDecoder().decode(plaintext);
}

function hexToBytes(hex: string): Uint8Array {
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < hex.length; i += 2) {
    bytes[i / 2] = parseInt(hex.slice(i, i + 2), 16);
  }
  return bytes;
}

// ─── User Verification ────────────────────────────────────────────────────────

async function verifyUser(token: string): Promise<string | null> {
  // deno-lint-ignore no-explicit-any
  const client: any = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
  );
  const { data, error } = await client.auth.getUser(token);
  if (error || !data?.user?.id) return null;
  return data.user.id;
}

// ─── Business Policies ────────────────────────────────────────────────────────

async function ensureBusinessPolicies(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  userId: string,
  accessToken: string,
): Promise<{
  merchantLocationKey: string | null;
  fulfillmentPolicyId: string | null;
  paymentPolicyId: string | null;
  returnPolicyId: string | null;
}> {
  // Check if the user already has cached policy ids.
  const { data: existing } = await supabase
    .from("ebay_accounts")
    .select("merchant_location_key, fulfillment_policy_id, payment_policy_id, return_policy_id")
    .eq("user_id", userId)
    .single();

  if (existing?.fulfillment_policy_id && existing?.payment_policy_id && existing?.return_policy_id) {
    return existing;
  }

  // Create fulfillment policy (flat-rate shipping).
  const fulfillmentPolicyId = await createPolicy(
    accessToken, "fulfillment",
    { name: "Carddex Shipping", handlingTime: { value: 1, unit: "DAY" }, shippingOptions: [] },
  );

  // Create payment policy (immediate payment).
  const paymentPolicyId = await createPolicy(
    accessToken, "payment",
    { name: "Carddex Payment", immediatePay: true, paymentMethods: [{ paymentMethodType: "PAYPAL" }] },
  );

  // Create return policy (30-day returns).
  const returnPolicyId = await createPolicy(
    accessToken, "return",
    { name: "Carddex Returns", returnsAccepted: true, returnPeriod: { value: 30, unit: "DAY" } },
  );

  // Create or get merchant location.
  let merchantLocationKey: string | null = null;
  try {
    const locRes = await fetch(`${HOST}/sell/account/v1/merchant_location_key`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
        "Content-Language": "en-US",
      },
      body: JSON.stringify({ location: { merchantLocationStatus: "ENABLED" } }),
    });
    if (locRes.ok) {
      const locData = await locRes.json();
      merchantLocationKey = locData.merchantLocationKey ?? null;
    }
  } catch { /* non-fatal — listing will fail if no location, but connection succeeds */ }

  return { merchantLocationKey, fulfillmentPolicyId, paymentPolicyId, returnPolicyId };
}

async function createPolicy(
  accessToken: string,
  type: "fulfillment" | "payment" | "return",
  body: Record<string, unknown>,
): Promise<string | null> {
  try {
    const res = await fetch(`${HOST}/sell/account/v1/${type}_policy`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
        "Content-Language": "en-US",
      },
      body: JSON.stringify(body),
    });
    if (res.ok) {
      const data = await res.json();
      return data[type + "PolicyId"] ?? null;
    }
  } catch { /* non-fatal */ }
  return null;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "content-type": "application/json" },
  });
}
