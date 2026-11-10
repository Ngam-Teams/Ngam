import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.6";

/**
 * NGAM PAYMENT WEBHOOK & CHIP ASIA PROXY EDGE FUNCTION (`payment-webhook`)
 * ---------------------------------------------------------------------------
 * Fungsi 3-dalam-1 untuk Ekosistem Ngam & Ngam Business:
 *  1. `action: 'create_purchase'` — Cipta transaksi CHIP Collect (mengelakkan ralat CORS di Web & menyembunyikan CHIP_API_KEY di pelayan).
 *  2. `action: 'check_status'`    — Semak status transaksi CHIP secara langsung dari pelayan CHIP (`/purchases/{id}/`).
 *  3. Webhook Callback CHIP/Bank  — Menerima POST callback automatik daripada CHIP (`event_type: 'purchase.paid'` dll.) dan mengemas kini `orders` atau `bookings` di Supabase.
 */

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-signature, x-webhook-signature, x-chip-signature",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const chipBrandId = Deno.env.get("CHIP_BRAND_ID") || "844a8f74-4426-4285-9a90-3c39e1259e75";
const chipApiKey = Deno.env.get("CHIP_API_KEY") || "";
const chipPublicKeyPem = Deno.env.get("CHIP_PUBLIC_KEY") || Deno.env.get("PAYMENT_WEBHOOK_SECRET") || "";

const supabase = createClient(supabaseUrl, supabaseServiceKey);
const CHIP_BASE_URL = "https://gate.chip-in.asia/api/v1";

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PUBLIC KEY-----/g, "")
    .replace(/-----END PUBLIC KEY-----/g, "")
    .replace(/\\n/g, "")
    .replace(/"/g, "")
    .replace(/\s+/g, "");
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

async function verifyChipSignature(
  rawBody: string,
  signatureBase64: string,
  publicKeyPem: string
): Promise<boolean> {
  if (!publicKeyPem || !signatureBase64) return false;
  try {
    const keyBuffer = pemToArrayBuffer(publicKeyPem);
    const cryptoKey = await crypto.subtle.importKey(
      "spki",
      keyBuffer,
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["verify"]
    );

    const sigBinary = atob(signatureBase64.trim());
    const sigBytes = new Uint8Array(sigBinary.length);
    for (let i = 0; i < sigBinary.length; i++) {
      sigBytes[i] = sigBinary.charCodeAt(i);
    }

    const dataBytes = new TextEncoder().encode(rawBody);
    return await crypto.subtle.verify(
      "RSASSA-PKCS1-v1_5",
      cryptoKey,
      sigBytes,
      dataBytes
    );
  } catch (err) {
    console.error("[payment-webhook] RSA-SHA256 signature verification error:", err);
    return false;
  }
}

serve(async (req: Request) => {
  // Handle CORS preflight for Flutter Web
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const rawBody = await req.text();
    const xSignature =
      req.headers.get("x-signature") ||
      req.headers.get("X-Signature") ||
      req.headers.get("x-chip-signature") ||
      "";

    // Pre-parse Cryptographic Signature Verification if X-Signature header is present
    let isWebhookSignatureVerified = false;
    if (xSignature) {
      isWebhookSignatureVerified = await verifyChipSignature(
        rawBody,
        xSignature,
        chipPublicKeyPem
      );
      if (!isWebhookSignatureVerified) {
        console.error("[payment-webhook] REJECTED before JSON.parse: Invalid X-Signature");
        return new Response(
          JSON.stringify({ error: "Invalid webhook cryptographic signature" }),
          { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    const payload = JSON.parse(rawBody || "{}");

    // =========================================================================
    // MOD 1: CREATE CHIP PURCHASE (STRICT SERVER-SIDE PRICE & FEE CALCULATION)
    // =========================================================================
    if (payload.action === "create_purchase") {
      if (!chipApiKey) {
        return new Response(
          JSON.stringify({ error: "CHIP_API_KEY belum ditetapkan dalam Supabase Secrets." }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const orderId = String(payload.order_id || payload.reference || "").trim();
      const paymentChannel = String(payload.payment_channel || "fpx").toLowerCase();

      if (!orderId) {
        return new Response(
          JSON.stringify({ error: "order_id diperlukan untuk pengiraan harga di pelayan (server-side)." }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // 1. Kira & kunci harga sebenar, diskaun baucar, komisen platform, dan caj gerbang di PostgreSQL
      let calcData: Record<string, unknown> | null = null;
      const { data: rpcCalcData, error: calcErr } = await supabase.rpc(
        "calculate_and_lock_order_for_chip",
        {
          p_order_id: orderId,
          p_payment_channel: paymentChannel,
        }
      );

      if (!calcErr && rpcCalcData) {
        calcData = rpcCalcData as Record<string, unknown>;
      } else {
        // Fallback server-side calculation (contoh: untuk pesanan mikro < RM 1.00 seperti RM 0.50 atau booking holding)
        console.warn("[payment-webhook] RPC fallback triggered:", calcErr?.message);
        const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(orderId);
        if (isUuid) {
          const { data: ordRow } = await supabase
            .from("orders")
            .select("id, business_id, total, status, payment_status")
            .eq("id", orderId)
            .maybeSingle();

          if (ordRow) {
            const { data: itemsRows } = await supabase
              .from("order_items")
              .select("quantity, unit_price, subtotal")
              .eq("order_id", orderId);

            let totalCents = Math.round(Number(ordRow.total || 0) * 100);
            if (Array.isArray(itemsRows) && itemsRows.length > 0 && totalCents <= 0) {
              totalCents = itemsRows.reduce((acc, it) => {
                const sub = Number(it.subtotal ?? (Number(it.unit_price || 0) * Number(it.quantity || 1)));
                return acc + Math.round(sub * 100);
              }, 0);
            }
            const { data: bizRow } = await supabase
              .from("businesses")
              .select("business_name")
              .eq("id", ordRow.business_id)
              .maybeSingle();

            await supabase
              .from("orders")
              .update({
                total_cents: totalCents,
                payment_method: paymentChannel,
              })
              .eq("id", orderId);

            calcData = {
              target_type: "order",
              order_id: ordRow.id,
              business_id: ordRow.business_id,
              business_name: bizRow?.business_name || "Kedai Ngam",
              total_cents: totalCents,
            };
          }
        }

        if (!calcData) {
          // Semak dalam jadual bookings (sama ada UUID atau short_ref)
          const bookingQuery = isUuid
            ? supabase.from("bookings").select("id, business_id, total_price, booking_metadata").eq("id", orderId).maybeSingle()
            : supabase
                .from("bookings")
                .select("id, business_id, total_price, booking_metadata")
                .or(`booking_metadata->>short_ref.eq.${orderId},booking_metadata->>booking_id.eq.${orderId}`)
                .maybeSingle();

          const { data: bkRow } = await bookingQuery;
          if (bkRow) {
            const totalCents = Math.round(Number(bkRow.total_price || 0) * 100);
            const { data: bizRow } = await supabase
              .from("businesses")
              .select("business_name")
              .eq("id", bkRow.business_id)
              .maybeSingle();

            const prevMeta = (bkRow.booking_metadata && typeof bkRow.booking_metadata === "object")
              ? bkRow.booking_metadata as Record<string, unknown>
              : {};
            await supabase
              .from("bookings")
              .update({
                booking_metadata: {
                  ...prevMeta,
                  expected_amount_cents: totalCents,
                  payment_channel: paymentChannel,
                },
              })
              .eq("id", bkRow.id);

            calcData = {
              target_type: "booking",
              booking_id: bkRow.id,
              business_id: bkRow.business_id,
              business_name: bizRow?.business_name || "Kedai Ngam",
              total_cents: totalCents,
            };
          }
        }
      }

      if (!calcData) {
        return new Response(
          JSON.stringify({ error: calcErr?.message || "Gagal mengira jumlah pesanan di pelayan." }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const verifiedCents = Number(calcData.total_cents);
      if (!Number.isInteger(verifiedCents) || verifiedCents < 1) {
        return new Response(
          JSON.stringify({ error: "Jumlah pesanan tidak sah untuk pembayaran dalam talian." }),
          { status: 422, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Perlindungan Had Minima FPX: Perbankan FPX & Kad memerlukan minima RM 10.00 (1000 sen)
      if (paymentChannel === "fpx" && verifiedCents < 1000) {
        return new Response(
          JSON.stringify({ error: "Perbankan dalam talian FPX memerlukan pesanan minima RM 10.00. Sila gunakan DuitNow QR atau Tunai." }),
          { status: 422, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const orderTitle = payload.order_title || `Pesanan ${calcData.business_name || "Ngam"}`;
      const clientEmail = payload.client_email || "pelanggan@ngam.dev";
      const clientName = payload.client_name || "Pelanggan Ngam";
      const clientPhone = payload.client_phone || "+601115892468";

      const webhookCallbackUrl = `${supabaseUrl}/functions/v1/payment-webhook`;

      const chipPayload: Record<string, unknown> = {
        brand_id: chipBrandId,
        reference: orderId,
        client: {
          email: clientEmail,
          full_name: clientName,
          phone: clientPhone,
        },
        purchase: {
          currency: "MYR",
          products: [
            {
              name: orderTitle,
              price: verifiedCents, // Authoritative server-calculated integer cents
              quantity: 1,
            },
          ],
        },
        success_callback: webhookCallbackUrl,
        success_redirect:
          payload.success_redirect ||
          `https://ngam.dev/receipt/success?order_id=${encodeURIComponent(orderId)}`,
        failure_redirect:
          payload.failure_redirect ||
          `https://ngam.dev/receipt/failed?order_id=${encodeURIComponent(orderId)}`,
        cancel_redirect:
          payload.cancel_redirect ||
          `https://ngam.dev/receipt/cancel?order_id=${encodeURIComponent(orderId)}`,
      };

      const chipRes = await fetch(`${CHIP_BASE_URL}/purchases/`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${chipApiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(chipPayload),
      });

      const chipData = await chipRes.json();

      if (chipRes.ok && chipData.id && calcData.target_type === "order") {
        await supabase
          .from("orders")
          .update({ chip_purchase_id: String(chipData.id) })
          .eq("id", calcData.order_id);
      }

      return new Response(JSON.stringify(chipData), {
        status: chipRes.status,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // =========================================================================
    // MOD 2: CHECK CHIP PURCHASE STATUS (Dipanggil oleh App semasa Polling)
    // =========================================================================
    if (payload.action === "check_status") {
      const purchaseId = payload.purchase_id;
      if (!purchaseId || !chipApiKey) {
        return new Response(JSON.stringify({ status: "pending" }), {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const chipRes = await fetch(`${CHIP_BASE_URL}/purchases/${purchaseId}/`, {
        method: "GET",
        headers: {
          Authorization: `Bearer ${chipApiKey}`,
          "Content-Type": "application/json",
        },
      });

      const chipData = await chipRes.json();

      // Jika CHIP mengesahkan status === 'paid', terus kemas kini pesanan/tempahan secara idempoten di pelayan!
      if (chipRes.ok && String(chipData.status || "").toLowerCase() === "paid") {
        const refId = String(chipData.reference || payload.order_id || "").trim();
        const paidCents =
          typeof chipData.purchase?.total === "number"
            ? Math.round(chipData.purchase.total)
            : 0;
        const payMethod =
          chipData.transaction_data?.payment_method ||
          chipData.payment?.payment_type ||
          "chip_online";

        if (refId && paidCents > 0) {
          const { data: settleData, error: settleErr } = await supabase.rpc(
            "process_verified_chip_webhook",
            {
              p_chip_purchase_id: String(chipData.id || purchaseId),
              p_event_type: "purchase.paid",
              p_reference_id: refId,
              p_paid_cents: paidCents,
              p_payment_method: payMethod,
              p_raw_payload: chipData,
            }
          );
          if (settleErr) {
            console.warn("[payment-webhook] check_status settlement warning:", settleErr.message);
          } else if (settleData?.target_type === "booking" && settleData?.booking_id) {
            await supabase
              .from("bookings")
              .update({ status: "pending" })
              .eq("id", settleData.booking_id)
              .eq("status", "holding");
          }
        }
      }

      return new Response(JSON.stringify(chipData), {
        status: chipRes.status,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // =========================================================================
    // MOD 3: HARDENED WEBHOOK CALLBACK DARIPADA CHIP ASIA (RSA-SHA256 + IDEMPOTENT)
    // =========================================================================
    if (!isWebhookSignatureVerified) {
      console.error("[payment-webhook] REJECTED: Missing or unverified X-Signature on webhook callback");
      return new Response(
        JSON.stringify({ error: "Missing or invalid X-Signature header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const chipPurchaseId: string = String(payload.id || "").trim();
    const targetId: string = String(
      payload.reference ||
      payload.order_id ||
      payload.booking_id ||
      payload.metadata?.order_id ||
      ""
    ).trim();
    const statusRaw: string = String(payload.status || payload.payment_status || "").toLowerCase();
    const eventType: string = String(payload.event_type || `purchase.${statusRaw}`);
    const paidCents: number =
      typeof payload.purchase?.total === "number"
        ? Math.round(payload.purchase.total)
        : -1;
    const paymentMethod: string =
      payload.transaction_data?.payment_method ||
      payload.payment?.payment_type ||
      payload.payment_method ||
      "chip_online";

    if (!chipPurchaseId || !targetId) {
      return new Response(
        JSON.stringify({ error: "Missing CHIP purchase.id or reference" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Ignore non-paid lifecycle notifications safely (e.g. 'created', 'viewed', 'Pending')
    if (statusRaw !== "paid") {
      return new Response(
        JSON.stringify({ received: true, status: statusRaw, action: "ignored" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (paidCents <= 0) {
      return new Response(
        JSON.stringify({ error: "Invalid paid amount in cents" }),
        { status: 422, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Execute Atomic Idempotent Verification & Balance Credit inside PostgreSQL
    const { data: settlementResult, error: rpcErr } = await supabase.rpc(
      "process_verified_chip_webhook",
      {
        p_chip_purchase_id: chipPurchaseId,
        p_event_type: eventType,
        p_reference_id: targetId,
        p_paid_cents: paidCents,
        p_payment_method: paymentMethod,
        p_raw_payload: payload,
      }
    );

    if (rpcErr) {
      console.error("[payment-webhook] Settlement RPC error:", rpcErr.message);
      const statusCode = rpcErr.message.includes("Amount mismatch") ? 422 : 500;
      return new Response(
        JSON.stringify({ error: rpcErr.message }),
        { status: statusCode, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (settlementResult?.target_type === "booking" && settlementResult?.booking_id) {
      await supabase
        .from("bookings")
        .update({ status: "pending" })
        .eq("id", settlementResult.booking_id)
        .eq("status", "holding");
    }

    return new Response(JSON.stringify(settlementResult), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("[payment-webhook] Error:", err);
    const msg = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ error: msg }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
