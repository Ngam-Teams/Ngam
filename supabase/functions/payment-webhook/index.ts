import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.6";

/**
 * NGAM PAYMENT WEBHOOK EDGE FUNCTION (`payment-webhook`)
 * ---------------------------------------------------------------------------
 * Mengesahkan status pembayaran sebenar daripada Payment Gateway (CHIP / ToyyibPay /
 * Stripe / Billplz) menggunakan HMAC Signature / Secret Token menggunakan
 * SUPABASE_SERVICE_ROLE_KEY, dan mengemas kini `orders` atau `bookings` secara atomik.
 *
 * Cara guna:
 * 1. Tetapkan secret di Supabase:
 *    supabase secrets set PAYMENT_WEBHOOK_SECRET="your_webhook_signing_secret"
 * 2. Deploy fungsi:
 *    supabase functions deploy payment-webhook --no-verify-jwt
 */

const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const webhookSecret = Deno.env.get("PAYMENT_WEBHOOK_SECRET") || "";

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function verifyHmacSignature(rawBody: string, signatureHeader: string | null): Promise<boolean> {
  if (!webhookSecret) {
    // Jika PAYMENT_WEBHOOK_SECRET belum ditetapkan dalam pembangunan, log amaran
    console.warn("[payment-webhook] PAYMENT_WEBHOOK_SECRET not configured.");
    return false;
  }
  if (!signatureHeader) return false;

  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(webhookSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sigBuffer = await crypto.subtle.sign("HMAC", key, encoder.encode(rawBody));
  const computedHex = Array.from(new Uint8Array(sigBuffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  return computedHex.toLowerCase() === signatureHeader.trim().toLowerCase();
}

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const rawBody = await req.text();
    const signature =
      req.headers.get("x-signature") ||
      req.headers.get("x-webhook-signature") ||
      req.headers.get("x-chip-signature");

    // Sahkan tandatangan HMAC jika secret ditetapkan
    if (webhookSecret) {
      const valid = await verifyHmacSignature(rawBody, signature);
      if (!valid) {
        console.error("[payment-webhook] Invalid HMAC signature rejected.");
        return new Response(JSON.stringify({ error: "Invalid webhook signature" }), {
          status: 401,
          headers: { "Content-Type": "application/json" },
        });
      }
    }

    const payload = JSON.parse(rawBody);
    console.log("[payment-webhook] Received event:", payload);

    // Sokong format payload standard Ngam / CHIP / FPX
    const targetType: string = (payload.target_type || payload.metadata?.target_type || "order").toLowerCase();
    const targetId: string = payload.order_id || payload.booking_id || payload.reference || payload.metadata?.order_id || "";
    const statusRaw: string = (payload.status || payload.payment_status || "").toLowerCase();
    const paidAmount: number = Number(payload.amount || payload.paid_amount || 0);
    const paymentMethod: string = payload.payment_method || payload.channel || "online";
    const transactionRef: string = payload.transaction_id || payload.id || payload.ref || "";

    if (!targetId) {
      return new Response(JSON.stringify({ error: "Missing order_id or booking_id in payload" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const isPaid = ["paid", "success", "succeeded", "completed", "captured", "1"].includes(statusRaw);
    const isRefunded = ["refunded", "reversed"].includes(statusRaw);

    if (targetType === "booking" || targetId.startsWith("RZRV-")) {
      // 1. Kemas kini Tempahan (Bookings)
      const query = targetId.startsWith("RZRV-")
        ? supabase.from("bookings").select("id, total_price, booking_metadata").eq("booking_metadata->>booking_id", targetId).maybeSingle()
        : supabase.from("bookings").select("id, total_price, booking_metadata").eq("id", targetId).maybeSingle();

      const { data: booking, error: fetchErr } = await query;
      if (fetchErr || !booking) {
        return new Response(JSON.stringify({ error: "Booking not found", details: fetchErr?.message }), {
          status: 404,
          headers: { "Content-Type": "application/json" },
        });
      }

      const existingMeta = (booking.booking_metadata && typeof booking.booking_metadata === "object")
        ? booking.booking_metadata
        : {};

      const updatedMeta = {
        ...existingMeta,
        payment_status: isPaid ? "paid" : (isRefunded ? "refunded" : existingMeta.payment_status),
        payment_method: paymentMethod,
        transaction_ref: transactionRef,
        verified_by_webhook: true,
        paid_at: isPaid ? new Date().toISOString() : existingMeta.paid_at,
      };

      const { error: updateErr } = await supabase
        .from("bookings")
        .update({
          booking_metadata: updatedMeta,
        })
        .eq("id", booking.id);

      if (updateErr) throw updateErr;

      return new Response(
        JSON.stringify({ success: true, type: "booking", id: booking.id, payment_status: updatedMeta.payment_status }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    } else {
      // 2. Kemas kini Pesanan Kedai (Orders)
      const { data: order, error: fetchErr } = await supabase
        .from("orders")
        .select("id, total, status, payment_status")
        .eq("id", targetId)
        .maybeSingle();

      if (fetchErr || !order) {
        return new Response(JSON.stringify({ error: "Order not found", details: fetchErr?.message }), {
          status: 404,
          headers: { "Content-Type": "application/json" },
        });
      }

      // Pastikan jumlah yang dibayar tidak kurang daripada jumlah pesanan sebenar (toleransi 5 sen)
      const expectedTotal = Number(order.total || 0);
      if (isPaid && paidAmount > 0 && paidAmount + 0.05 < expectedTotal) {
        console.error(`[payment-webhook] Amount mismatch for order ${order.id}: expected ${expectedTotal}, got ${paidAmount}`);
        return new Response(
          JSON.stringify({ error: "Paid amount is less than order total", expected: expectedTotal, received: paidAmount }),
          { status: 422, headers: { "Content-Type": "application/json" } }
        );
      }

      const newPaymentStatus = isPaid ? "paid" : (isRefunded ? "refunded" : order.payment_status);

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
        JSON.stringify({ success: true, type: "order", id: order.id, payment_status: newPaymentStatus }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }
  } catch (err) {
    console.error("[payment-webhook] Error:", err);
    const msg = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ error: msg }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
