// Carddex `ebay-list` Edge Function — publish a collection item as an eBay listing.
//
// POST { collectionItemId, price: {amount,currencyCode}, condition, quantity, title?, description? }
//   → { listingId, viewUrl, status }
//
// Flow (eBay Sell API): verify JWT → load + refresh eBay token → create/replace
// inventory item → create offer → publish offer → persist to ebay_listings.
// Requires eBay PRODUCTION access + business policies (created during OAuth).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const ENV = Deno.env.get("EBAY_ENV") ?? "production";
const HOST = ENV === "sandbox" ? "https://api.sandbox.ebay.com" : "https://api.ebay.com";
const MARKETPLACE = Deno.env.get("EBAY_MARKETPLACE_ID") ?? "EBAY_US";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    // 1) Verify the caller's JWT and resolve user id.
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return json({ error: { code: "UNAUTHORIZED", message: "missing auth token" } }, 401);
    }
    const token = authHeader.slice(7);
    // deno-lint-ignore no-explicit-any
    const anonClient: any = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
    );
    const { data: userData, error: userError } = await anonClient.auth.getUser(token);
    if (userError || !userData?.user?.id) {
      return json({ error: { code: "UNAUTHORIZED", message: "invalid session" } }, 401);
    }
    const userId = userData.user.id;

    // 2) Parse request body.
    const body = await req.json();
    const { collectionItemId, price, condition, quantity, title, description } = body;
    if (!collectionItemId || !price?.amount) {
      return json({ error: { code: "BAD_REQUEST", message: "missing fields" } }, 400);
    }

    // deno-lint-ignore no-explicit-any
    const supabase: any = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // 3) Load the user's eBay account + refresh token.
    const { data: ebayAccount, error: acctError } = await supabase
      .from("ebay_accounts")
      .select("*")
      .eq("user_id", userId)
      .single();

    if (acctError || !ebayAccount) {
      return json({
        error: { code: "EBAY_NOT_CONNECTED", message: "Connect an eBay account first", retryable: false },
      }, 409);
    }

    const encryptionKey = Deno.env.get("EBAY_ENCRYPTION_KEY");
    if (!encryptionKey) {
      return json({ error: { code: "CONFIG_ERROR", message: "EBAY_ENCRYPTION_KEY not set" } }, 500);
    }

    // Refresh the access token if expired (or close to expiring).
    let accessToken = await decryptToken(ebayAccount.access_token_enc, encryptionKey);
    const accessExpires = new Date(ebayAccount.access_expires_at).getTime();
    if (Date.now() > accessExpires - 60_000) {
      accessToken = await refreshEbayToken(
        await decryptToken(ebayAccount.refresh_token_enc, encryptionKey),
        supabase,
        userId,
        encryptionKey,
      );
    }

    // 4) Load the collection item + its card for listing details.
    const { data: item } = await supabase
      .from("collection_items")
      .select("*, card:cards(*)")
      .eq("id", collectionItemId)
      .eq("user_id", userId)
      .single();

    if (!item) {
      return json({ error: { code: "NOT_FOUND", message: "collection item not found" } }, 404);
    }

    const card = item.card;
    const listingTitle = title ?? `${card?.name ?? "Trading Card"} - ${card?.set_name ?? ""} ${card?.number ?? ""}`.trim();
    const listingCondition = mapCondition(condition ?? item.condition);
    const qty = quantity ?? item.quantity ?? 1;
    const sku = `carddex-${collectionItemId}`;

    // 5) Create or replace the inventory item.
    const inventoryBody = {
      availability: { shipToLocationAvailability: { quantity: qty } },
      condition: listingCondition,
      product: {
        title: listingTitle,
        description: description ?? `Listed via Carddex. Card: ${card?.name ?? "N/A"}, Set: ${card?.set_name ?? "N/A"}, Number: ${card?.number ?? "N/A"}.`,
        brand: "Trading Card",
        imageUrls: card?.image_url ? [card.image_url] : [],
      },
    };

    const invRes = await fetch(`${HOST}/sell/inventory/v1/inventory_item/${sku}`, {
      method: "PUT",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
        "Content-Language": "en-US",
      },
      body: JSON.stringify(inventoryBody),
    });

    if (!invRes.ok) {
      const errText = await invRes.text();
      return json({
        error: { code: "EBAY_API_ERROR", message: `Inventory item failed: ${errText}`, retryable: true },
      }, 502);
    }

    // 6) Create the offer (pricing + policies).
    const offerBody = {
      sku,
      marketplaceId: MARKETPLACE,
      format: "FIXED_PRICE",
      pricingSummary: {
        price: { value: String(price.amount), currency: price.currencyCode ?? "USD" },
      },
      listingPolicies: {
        fulfillmentPolicyId: ebayAccount.fulfillment_policy_id,
        paymentPolicyId: ebayAccount.payment_policy_id,
        returnPolicyId: ebayAccount.return_policy_id,
      },
      merchantLocationKey: ebayAccount.merchant_location_key,
    };

    const offerRes = await fetch(`${HOST}/sell/inventory/v1/offer`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
        "Content-Language": "en-US",
      },
      body: JSON.stringify(offerBody),
    });

    if (!offerRes.ok) {
      const errText = await offerRes.text();
      return json({
        error: { code: "EBAY_API_ERROR", message: `Offer creation failed: ${errText}`, retryable: true },
      }, 502);
    }

    const offerData = await offerRes.json();
    const offerId = offerData.offerId;

    // 7) Publish the offer.
    const publishRes = await fetch(`${HOST}/sell/inventory/v1/offer/${offerId}/publish`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Language": "en-US",
      },
    });

    if (!publishRes.ok) {
      const errText = await publishRes.text();
      return json({
        error: { code: "EBAY_API_ERROR", message: `Publish failed: ${errText}`, retryable: true },
      }, 502);
    }

    const publishData = await publishRes.json();
    const listingId = publishData.listingId;

    // 8) Fetch the listing's view URL.
    let viewUrl: string | null = null;
    try {
      const listingRes = await fetch(`${HOST}/sell/inventory/v1/listing/${listingId}`, {
        headers: { Authorization: `Bearer ${accessToken}` },
      });
      if (listingRes.ok) {
        const listingData = await listingRes.json();
        viewUrl = listingData.listingDetails?.viewItemURL ?? null;
      }
    } catch { /* non-fatal */ }

    // 9) Persist to ebay_listings.
    const { error: dbError } = await supabase.from("ebay_listings").upsert({
      user_id: userId,
      collection_item_id: collectionItemId,
      ebay_offer_id: offerId,
      ebay_listing_id: listingId,
      sku,
      status: "active",
      price: price.amount,
      currency: price.currencyCode ?? "USD",
      view_url: viewUrl,
      updated_at: new Date().toISOString(),
    }, { onConflict: "collection_item_id" });

    if (dbError) {
      // Listing is live on eBay but we couldn't persist — log but don't fail.
      console.error("ebay_listings upsert failed:", dbError.message);
    }

    // Log audit event.
    await supabase.from("audit_events").insert({
      user_id: userId,
      kind: "listing_created",
      detail: { collection_item_id: collectionItemId, listing_id: listingId },
    });

    return json({ listingId, viewUrl, status: "active", offerId, sku });
  } catch (err) {
    // deno-lint-ignore no-explicit-any
    const e = err as any;
    return json({ error: { code: "INTERNAL", message: e?.message ?? String(e), retryable: false } }, 500);
  }
});

// ─── Token Refresh ────────────────────────────────────────────────────────────

async function refreshEbayToken(
  refreshToken: string,
  // deno-lint-ignore no-explicit-any
  supabase: any,
  userId: string,
  encryptionKey: string,
): Promise<string> {
  const clientId = Deno.env.get("EBAY_CLIENT_ID")!;
  const clientSecret = Deno.env.get("EBAY_CLIENT_SECRET")!;
  const res = await fetch(`${HOST}/identity/v1/oauth2/token`, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      Authorization: `Basic ${btoa(`${clientId}:${clientSecret}`)}`,
    },
    body: `grant_type=refresh_token&refresh_token=${encodeURIComponent(refreshToken)}` +
      `&scope=${encodeURIComponent("https://api.ebay.com/oauth/api_scope/sell.inventory https://api.ebay.com/oauth/api_scope/sell.account https://api.ebay.com/oauth/api_scope/sell.item")}`,
  });

  if (!res.ok) throw new Error(`eBay token refresh failed: ${await res.text()}`);
  const tokens = await res.json();

  // Persist the new access token.
  const newAccessEnc = await encryptToken(tokens.access_token, encryptionKey);
  const accessExpiresAt = new Date(Date.now() + (tokens.expires_in ?? 7200) * 1000).toISOString();
  await supabase
    .from("ebay_accounts")
    .update({
      access_token_enc: newAccessEnc,
      access_expires_at: accessExpiresAt,
      updated_at: new Date().toISOString(),
    })
    .eq("user_id", userId);

  return tokens.access_token;
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

async function decryptToken(encString: string, hexKey: string): Promise<string> {
  const [ivB64, ctB64] = encString.split(":");
  const iv = Uint8Array.from(atob(ivB64), (c) => c.charCodeAt(0));
  const ciphertext = Uint8Array.from(atob(ctB64), (c) => c.charCodeAt(0));
  const keyBytes = hexKey.length === 64
    ? hexToBytes(hexKey)
    : new TextEncoder().encode(hexKey).slice(0, 32);
  const key = await crypto.subtle.importKey("raw", keyBytes as BufferSource, { name: "AES-GCM" }, false, ["decrypt"]);
  const plaintext = await crypto.subtle.decrypt({ name: "AES-GCM", iv }, key, ciphertext);
  return new TextDecoder().decode(plaintext);
}

async function encryptToken(plaintext: string, hexKey: string): Promise<string> {
  const keyBytes = hexKey.length === 64
    ? hexToBytes(hexKey)
    : new TextEncoder().encode(hexKey).slice(0, 32);
  const key = await crypto.subtle.importKey("raw", keyBytes as BufferSource, { name: "AES-GCM" }, false, ["encrypt"]);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const encoded = new TextEncoder().encode(plaintext);
  const ciphertext = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, key, encoded);
  const ivB64 = btoa(String.fromCharCode(...iv));
  const ctB64 = btoa(String.fromCharCode(...new Uint8Array(ciphertext)));
  return `${ivB64}:${ctB64}`;
}

function hexToBytes(hex: string): Uint8Array {
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < hex.length; i += 2) {
    bytes[i / 2] = parseInt(hex.slice(i, i + 2), 16);
  }
  return bytes;
}

/// Map Carddex conditions to eBay condition enum values.
function mapCondition(condition: string): string {
  const c = condition.toLowerCase();
  if (c.includes("mint") && !c.includes("near")) return "NEW";
  if (c.includes("near mint")) return "LIKE_NEW";
  if (c.includes("excellent") || c.includes("lightly played")) return "GOOD";
  if (c.includes("good") || c.includes("played")) return "ACCEPTABLE";
  if (c.includes("poor") || c.includes("heavily played")) return "USED";
  return "USED";
}

// deno-lint-ignore no-explicit-any
function json(body: any, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "content-type": "application/json" },
  });
}
