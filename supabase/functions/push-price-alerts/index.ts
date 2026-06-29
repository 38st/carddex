// Carddex `push-price-alerts` Edge Function.
//
// Scheduled (pg_cron, see migration 0016). For every active price alert whose
// card has reached its target, sends an APNs push to the owner's devices so the
// alert fires while the app is closed. Each alert pushes once (sets
// `last_triggered_at`) and re-arms when the price falls back past target.
//
// Secrets required (set with `supabase secrets set ...`):
//   APNS_KEY_P8     — contents of the AuthKey_XXXX.p8 (the EC private key)
//   APNS_KEY_ID     — 10-char key id
//   APNS_TEAM_ID    — 10-char Apple team id
//   APNS_BUNDLE_ID  — e.g. com.carddex.app   (the apns-topic)
//   APNS_HOST       — api.push.apple.com (prod) | api.sandbox.push.apple.com (dev)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async () => {
  try {
    // deno-lint-ignore no-explicit-any
    const supabase: any = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: alerts } = await supabase
      .from("price_alerts")
      .select("id, user_id, card_id, direction, target_price, last_triggered_at, card:cards(name, market_price)")
      .eq("active", true);

    if (!alerts?.length) return json({ pushed: 0, rearmed: 0 });

    // Group device tokens by user so we push to every device once.
    const { data: devices } = await supabase.from("device_tokens").select("user_id, token");
    const tokensByUser = new Map<string, string[]>();
    for (const d of devices ?? []) {
      const list = tokensByUser.get(d.user_id) ?? [];
      list.push(d.token);
      tokensByUser.set(d.user_id, list);
    }

    let apnsJwt: string | null = null;
    let pushed = 0, rearmed = 0;

    for (const a of alerts) {
      const price = Number(a.card?.market_price);
      const target = Number(a.target_price);
      if (!isFinite(price) || !isFinite(target) || target <= 0) continue;

      const reached = a.direction === "down" ? price <= target : price >= target;

      if (reached && !a.last_triggered_at) {
        const tokens = tokensByUser.get(a.user_id) ?? [];
        if (tokens.length) {
          apnsJwt ??= await makeAPNsToken();
          if (apnsJwt) {
            const title = "Price target reached";
            const body = `${a.card?.name ?? "Your card"} hit $${target.toFixed(2)}.`;
            for (const token of tokens) await sendAPNs(apnsJwt, token, title, body);
          }
        }
        await supabase.from("price_alerts").update({ last_triggered_at: new Date().toISOString() }).eq("id", a.id);
        pushed++;
      } else if (!reached && a.last_triggered_at) {
        await supabase.from("price_alerts").update({ last_triggered_at: null }).eq("id", a.id);
        rearmed++;
      }
    }
    return json({ pushed, rearmed });
  } catch (err) {
    return json({ error: String(err) }, 500);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}

// ---- APNs provider token (ES256 JWT) ---------------------------------------

async function makeAPNsToken(): Promise<string | null> {
  const p8 = Deno.env.get("APNS_KEY_P8");
  const kid = Deno.env.get("APNS_KEY_ID");
  const iss = Deno.env.get("APNS_TEAM_ID");
  if (!p8 || !kid || !iss) return null;

  const header = b64url(JSON.stringify({ alg: "ES256", kid }));
  const claims = b64url(JSON.stringify({ iss, iat: Math.floor(Date.now() / 1000) }));
  const signingInput = `${header}.${claims}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToBytes(p8),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${b64urlBytes(new Uint8Array(sig))}`;
}

async function sendAPNs(jwt: string, deviceToken: string, title: string, body: string) {
  const host = Deno.env.get("APNS_HOST") ?? "api.sandbox.push.apple.com";
  const topic = Deno.env.get("APNS_BUNDLE_ID") ?? "com.carddex.app";
  try {
    await fetch(`https://${host}/3/device/${deviceToken}`, {
      method: "POST",
      headers: {
        "authorization": `bearer ${jwt}`,
        "apns-topic": topic,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "content-type": "application/json",
      },
      body: JSON.stringify({ aps: { alert: { title, body }, sound: "default" } }),
    });
  } catch { /* a dead token shouldn't fail the whole batch */ }
}

// ---- encoding helpers -------------------------------------------------------

function b64url(s: string): string {
  return b64urlBytes(new TextEncoder().encode(s));
}
function b64urlBytes(bytes: Uint8Array): string {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
function pemToBytes(pem: string): Uint8Array {
  const b64 = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}
