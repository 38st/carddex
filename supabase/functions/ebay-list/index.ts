// Carddex `ebay-list` Edge Function — publish a collection item as an eBay listing.
//
// POST { collectionItemId, price: {amount,currencyCode}, condition, quantity, title?, description? }
//   → { listingId, viewUrl, status }
//
// Flow (eBay Sell API): refresh access token → create/replace inventory item →
// create offer → publish offer. Persists to ebay_listings. Requires eBay
// PRODUCTION access (application review) + business policies. See docs/backend-plan.md §3.4.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const body = await req.json();
    const { collectionItemId, price, condition, quantity, title } = body;
    if (!collectionItemId || !price?.amount) {
      return json({ error: { code: "BAD_REQUEST", message: "missing fields" } }, 400);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // TODO:
    // 1) Recover the user from the verified JWT; load + refresh their eBay token
    //    from ebay_accounts (service role only).
    // 2) PUT  /sell/inventory/v1/inventory_item/{sku}   (sku = carddex-{collectionItemId})
    //         with title, condition, image (catalog + user photo), aspects.
    // 3) POST /sell/inventory/v1/offer                  (price, business policy ids,
    //         merchant location, category, marketplace EBAY_US).
    // 4) POST /sell/inventory/v1/offer/{offerId}/publish → { listingId }.
    // 5) Upsert ebay_listings (status 'active', ebay_offer_id, ebay_listing_id, view_url).
    const sku = `carddex-${collectionItemId}`;
    const _ = { supabase, condition, quantity, title, sku };

    return json({
      error: { code: "EBAY_NOT_CONNECTED", message: "Connect an eBay account first", retryable: false },
    }, 409);
  } catch (err) {
    return json({ error: { code: "INTERNAL", message: String(err), retryable: false } }, 500);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "content-type": "application/json" },
  });
}
