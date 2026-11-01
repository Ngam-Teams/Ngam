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
const webhookSecret = Deno.env.get("PAYMENT_WEBHOOK_SECRET") || "";

const supabase = createClient(supabaseUrl, supabaseServiceKey);
const CHIP_BASE_URL = "https://gate.chip-in.asia/api/v1";

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
    const payload = JSON.parse(rawBody || "{}");

    // =========================================================================
    // MOD 1: CREATE CHIP PURCHASE (Dipanggil oleh Ngam / Ngam Business App)
    // =========================================================================
    if (payload.action === "create_purchase") {
      if (!chipApiKey) {
        return new Response(
          JSON.stringify({ error: "CHIP_API_KEY belum ditetapkan dalam Supabase Secrets." }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const amount = Number(payload.amount || 0);
      const cents = Math.round(amount * 100);
      const orderTitle = payload.order_title || "Pesanan Ngam";
      const reference = payload.reference || payload.order_id || "";
      const clientEmail = payload.client_email || "pelanggan@ngam.dev";
      const clientName = payload.client_name || "Pelanggan Ngam";
      const clientPhone = payload.client_phone || "+601115892468";
      const whitelist = payload.payment_method_whitelist;

      const webhookCallbackUrl = `${supabaseUrl}/functions/v1/payment-webhook`;

      const chipPayload: Record<string, unknown> = {
        brand_id: payload.brand_id || chipBrandId,
        reference: reference,
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
              price: cents,
              quantity: 1,
            },
          ],
        },
        success_callback: webhookCallbackUrl,
        success_redirect:
          payload.success_redirect ||
          (reference
            ? `https://ngam.dev/receipt/success?order_id=${encodeURIComponent(reference)}`
            : "https://ngam.dev/receipt/success"),
        failure_redirect:
          payload.failure_redirect ||
          (reference
            ? `https://ngam.dev/receipt/failed?order_id=${encodeURIComponent(reference)}`
            : "https://ngam.dev/receipt/failed"),
        cancel_redirect:
          payload.cancel_redirect ||
          (reference
            ? `https://ngam.dev/receipt/cancel?order_id=${encodeURIComponent(reference)}`
            : "https://ngam.dev/receipt/cancel"),
      };

      if (Array.isArray(whitelist) && whitelist.length > 0) {
        chipPayload.payment_method_whitelist = whitelist;
      }

      const chipRes = await fetch(`${CHIP_BASE_URL}/purchases/`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${chipApiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(chipPayload),
      });

      const chipData = await chipRes.json();
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
      return new Response(JSON.stringify(chipData), {
        status: chipRes.status,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // =========================================================================
    // MOD 3: WEBHOOK CALLBACK DARIPADA CHIP ASIA / GERBANG PEMBAYARAN
    // =========================================================================
    console.log("[payment-webhook] Incoming webhook payload:", payload);

    // CHIP menghantar objek Purchase secara terus (mempunyai `id`, `status`, `reference`, `purchase.total`)
    const targetId: string =
      payload.reference ||
      payload.order_id ||
      payload.booking_id ||
      payload.metadata?.order_id ||
      "";
    const statusRaw: string = (payload.status || payload.payment_status || "").toLowerCase();
    const chipCents = payload.purchase?.total;
    const paidAmount: number =
      typeof chipCents === "number"
        ? chipCents / 100.0
        : Number(payload.amount || payload.paid_amount || 0);
    const paymentMethod: string =
      payload.transaction_data?.payment_method ||
      payload.payment_method ||
      payload.channel ||
      "online";
    const transactionRef: string = payload.id || payload.transaction_id || payload.ref || "";

    if (!targetId) {
      return new Response(
        JSON.stringify({ received: true, message: "No reference/order_id attached to webhook" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const isPaid = ["paid", "success", "succeeded", "completed", "captured", "1"].includes(statusRaw);
    const isRefunded = ["refunded", "reversed"].includes(statusRaw);

    if (targetId.startsWith("RZRV-") || payload.target_type === "booking") {
      // 1. Kemas kini Tempahan (Bookings)
      const query = targetId.startsWith("RZRV-")
        ? supabase
            .from("bookings")
            .select("id, total_price, booking_metadata")
            .eq("booking_metadata->>booking_id", targetId)
            .maybeSingle()
        : supabase
            .from("bookings")
            .select("id, total_price, booking_metadata")
            .eq("id", targetId)
            .maybeSingle();

      const { data: booking, error: fetchErr } = await query;
      if (fetchErr || !booking) {
        return new Response(
          JSON.stringify({ error: "Booking not found", details: fetchErr?.message }),
          { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const existingMeta =
        booking.booking_metadata && typeof booking.booking_metadata === "object"
          ? booking.booking_metadata
          : {};

      const updatedMeta = {
        ...existingMeta,
        payment_status: isPaid
          ? "paid"
          : isRefunded
          ? "refunded"
          : existingMeta.payment_status,
        payment_method: paymentMethod,
        transaction_ref: transactionRef,
        verified_by_webhook: true,
        paid_at: isPaid ? new Date().toISOString() : existingMeta.paid_at,
      };

      const { error: updateErr } = await supabase
        .from("bookings")
        .update({ booking_metadata: updatedMeta })
        .eq("id", booking.id);

      if (updateErr) throw updateErr;

      return new Response(
        JSON.stringify({
          success: true,
          type: "booking",
          id: booking.id,
          payment_status: updatedMeta.payment_status,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    } else {
      // 2. Kemas kini Pesanan Kedai (Orders)
      const { data: order, error: fetchErr } = await supabase
        .from("orders")
        .select("id, total, status, payment_status")
        .eq("id", targetId)
        .maybeSingle();

      if (fetchErr || !order) {
        return new Response(
          JSON.stringify({ error: "Order not found", details: fetchErr?.message }),
          { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const expectedTotal = Number(order.total || 0);
      if (isPaid && paidAmount > 0 && paidAmount + 0.05 < expectedTotal) {
        console.error(
          `[payment-webhook] Amount mismatch for order ${order.id}: expected ${expectedTotal}, got ${paidAmount}`
        );
        return new Response(
          JSON.stringify({
            error: "Paid amount is less than order total",
            expected: expectedTotal,
            received: paidAmount,
          }),
          { status: 422, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const newPaymentStatus = isPaid
        ? "paid"
        : isRefunded
        ? "refunded"
        : order.payment_status;

      const { error: updateErr } = await supabase
        .from("orders")
        .update({
          payment_status: newPaymentStatus,
          payment_method: paymentMethod,
          payment_ref: transactionRef || null,
          paid_at: isPaid ? new Date().toISOString() : null,
          updated_at: new Date().toISOString(),
        })
        .eq("id", order.id);

      if (updateErr) throw updateErr;

      return new Response(
        JSON.stringify({
          success: true,
          type: "order",
          id: order.id,
          payment_status: newPaymentStatus,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
  } catch (err) {
    console.error("[payment-webhook] Error:", err);
    const msg = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ error: msg }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
