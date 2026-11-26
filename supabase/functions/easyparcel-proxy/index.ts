import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.6";

/**
 * NGAM EASYPARCEL PROXY EDGE FUNCTION (`easyparcel-proxy`)
 * ---------------------------------------------------------------------------
 * Proksi selamat untuk EasyParcel Malaysia Individual API v1.4:
 * - Mengelakkan ralat CORS di Flutter Web/PWA
 * - Melindungi API Key EasyParcel di pelayan (disimpan dalam `business_integrations`)
 * - Menyokong mod Demo (`https://demo.connect.easyparcel.my/`) & Live (`https://connect.easyparcel.my/`)
 *
 * Tindakan (`action`):
 *  1. `verify_connection` — Uji API key & semak baki kredit (`EPCheckCreditBalance`)
 *  2. `check_balance`     — Semak baki kredit menggunakan kunci tersimpan (`EPCheckCreditBalance`)
 *  3. `check_rates`       — Semak harga kurier PosLaju/J&T/NinjaVan/DHL (`EPRateCheckingBulk`)
 *  4. `book_and_pay`      — Cipta pesanan (`EPSubmitOrderBulk`) + Bayar kredit (`EPPayOrderBulk`) & simpan AWB
 *  5. `track_parcel`      — Semak status penghantaran terkini (`EPTrackingBulk`) & kemas kini `order_shipments`
 */

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const supabase = createClient(supabaseUrl, supabaseServiceKey);

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function getBaseUrl(env: string): string {
  return env === "live"
    ? "https://connect.easyparcel.my/?ac="
    : "https://demo.connect.easyparcel.my/?ac=";
}

/**
 * Encode nested JS objects/arrays into PHP `http_build_query` format
 * required by EasyParcel API (e.g. `bulk[0][pick_code]=10050`).
 */
function appendFormParams(
  params: URLSearchParams,
  value: unknown,
  prefix?: string
): void {
  if (value === null || value === undefined) return;
  if (Array.isArray(value)) {
    value.forEach((item, index) => {
      const key = prefix ? `${prefix}[${index}]` : String(index);
      appendFormParams(params, item, key);
    });
  } else if (typeof value === "object") {
    for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
      const key = prefix ? `${prefix}[${k}]` : k;
      appendFormParams(params, v, key);
    }
  } else if (prefix) {
    params.append(prefix, String(value));
  }
}

async function callEasyParcel(
  env: string,
  epAction: string,
  payload: Record<string, unknown>
): Promise<Record<string, unknown>> {
  const params = new URLSearchParams();
  appendFormParams(params, payload);

  const url = `${getBaseUrl(env)}${epAction}`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      "Accept": "application/json",
    },
    body: params.toString(),
  });

  const rawText = await res.text();
  try {
    return JSON.parse(rawText) as Record<string, unknown>;
  } catch {
    throw new Error(`EasyParcel returned non-JSON (${res.status}): ${rawText.slice(0, 200)}`);
  }
}

async function verifyCallerAccess(
  authHeader: string | null,
  businessId: string
): Promise<{ userId: string } | null> {
  if (!authHeader || !authHeader.startsWith("Bearer ")) return null;
  const token = authHeader.replace("Bearer ", "").trim();
  const { data: userData, error: userErr } = await supabase.auth.getUser(token);
  if (userErr || !userData?.user) return null;

  const userId = userData.user.id;

  // 1. Check business owner
  const { data: biz } = await supabase
    .from("businesses")
    .select("id, owner_user_id")
    .eq("id", businessId)
    .maybeSingle();

  if (biz && biz.owner_user_id === userId) {
    return { userId };
  }

  // 2. Check active team member
  const { data: staff } = await supabase
    .from("team_members")
    .select("id, role, status")
    .eq("business_id", businessId)
    .eq("user_id", userId)
    .eq("status", "active")
    .maybeSingle();

  if (staff) {
    return { userId };
  }

  // 3. Check super_admin
  const { data: adminRole } = await supabase
    .from("user_roles")
    .select("role")
    .eq("user_id", userId)
    .eq("role", "super_admin")
    .maybeSingle();

  if (adminRole) {
    return { userId };
  }

  return null;
}

async function getSavedCredentials(businessId: string): Promise<{
  apiKey: string;
  environment: string;
  config: Record<string, unknown>;
} | null> {
  const { data, error } = await supabase
    .from("business_integrations")
    .select("api_key, environment, is_connected, config")
    .eq("business_id", businessId)
    .eq("provider", "easyparcel")
    .maybeSingle();

  if (error || !data || !data.api_key) return null;
  return {
    apiKey: String(data.api_key).trim(),
    environment: String(data.environment || "demo"),
    config: (data.config as Record<string, unknown>) || {},
  };
}

function normalizePhone(phone: string): string {
  const digits = String(phone || "").replace(/[^\d+]/g, "");
  if (!digits) return "0123456789";
  if (digits.startsWith("+60")) return "0" + digits.slice(3);
  if (digits.startsWith("60") && digits.length >= 10) return "0" + digits.slice(2);
  return digits;
}

function todayMytDate(): string {
  const myt = new Date(Date.now() + 8 * 3600 * 1000);
  const y = myt.getUTCFullYear();
  const m = String(myt.getUTCMonth() + 1).padStart(2, "0");
  const d = String(myt.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ success: false, error: "Method not allowed" }, 405);
  }

  try {
    const body = (await req.json()) as Record<string, unknown>;
    const action = String(body.action || "").trim();
    const businessId = String(body.business_id || "").trim();

    if (!action || !businessId) {
      return jsonResponse(
        { success: false, error: "Missing required fields: action, business_id" },
        400
      );
    }

    const caller = await verifyCallerAccess(req.headers.get("Authorization"), businessId);
    if (!caller) {
      return jsonResponse({ success: false, error: "Unauthorized business access" }, 401);
    }

    // -------------------------------------------------------------------------
    // 1. VERIFY CONNECTION (with explicit api_key & environment)
    // -------------------------------------------------------------------------
    if (action === "verify_connection") {
      const apiKey = String(body.api_key || "").trim();
      const environment = String(body.environment || "demo") === "live" ? "live" : "demo";

      if (!apiKey) {
        return jsonResponse({ success: false, error: "API key is required" }, 400);
      }

      const epRes = await callEasyParcel(environment, "EPCheckCreditBalance", {
        api: apiKey,
      });

      const ok = String(epRes.api_status || "").toLowerCase() === "success";
      if (!ok) {
        return jsonResponse({
          success: false,
          error: String(epRes.error_remark || "Invalid EasyParcel API key"),
          error_code: epRes.error_code,
          raw: epRes,
        });
      }

      return jsonResponse({
        success: true,
        balance: Number(epRes.result || 0),
        currency: "MYR",
        environment,
      });
    }

    // All subsequent actions use saved credentials from `business_integrations`
    const creds = await getSavedCredentials(businessId);
    if (!creds) {
      return jsonResponse(
        { success: false, error: "EasyParcel is not configured for this business" },
        400
      );
    }

    // -------------------------------------------------------------------------
    // 2. CHECK CREDIT BALANCE
    // -------------------------------------------------------------------------
    if (action === "check_balance") {
      const epRes = await callEasyParcel(creds.environment, "EPCheckCreditBalance", {
        api: creds.apiKey,
      });
      const ok = String(epRes.api_status || "").toLowerCase() === "success";
      if (!ok) {
        return jsonResponse({
          success: false,
          error: String(epRes.error_remark || "Failed to fetch balance"),
        });
      }
      return jsonResponse({
        success: true,
        balance: Number(epRes.result || 0),
        currency: "MYR",
        environment: creds.environment,
      });
    }

    // -------------------------------------------------------------------------
    // 3. CHECK COURIER RATES (`EPRateCheckingBulk`)
    // -------------------------------------------------------------------------
    if (action === "check_rates") {
      const pickCode = String(body.pick_code || "").trim();
      const pickState = String(body.pick_state || "").trim().toLowerCase();
      const sendCode = String(body.send_code || "").trim();
      const sendState = String(body.send_state || "").trim().toLowerCase();
      const weight = Number(body.weight || 1);
      const width = Number(body.width || 0);
      const length = Number(body.length || 0);
      const height = Number(body.height || 0);
      const dateColl = String(body.date_coll || todayMytDate()).trim();

      if (!pickCode || !pickState || !sendCode || !sendState) {
        return jsonResponse(
          { success: false, error: "Sender & receiver postcode and state are required" },
          400
        );
      }

      const epRes = await callEasyParcel(creds.environment, "EPRateCheckingBulk", {
        api: creds.apiKey,
        bulk: [
          {
            pick_code: pickCode,
            pick_state: pickState,
            pick_country: "MY",
            send_code: sendCode,
            send_state: sendState,
            send_country: "MY",
            weight: String(weight > 0 ? weight : 1),
            width: String(width),
            length: String(length),
            height: String(height),
            date_coll: dateColl,
          },
        ],
        exclude_fields: ["rates.*.pickup_point", "rates.*.dropoff_point"],
      });

      const ok = String(epRes.api_status || "").toLowerCase() === "success";
      if (!ok) {
        return jsonResponse({
          success: false,
          error: String(epRes.error_remark || "Rate check failed"),
          raw: epRes,
        });
      }

      const resultArr = (epRes.result as Array<Record<string, unknown>>) || [];
      const firstResult = resultArr[0] || {};
      const status = String(firstResult.status || "").toLowerCase();
      if (status !== "success") {
        return jsonResponse({
          success: false,
          error: String(firstResult.remarks || "No couriers available for this route"),
        });
      }

      const rawRates = (firstResult.rates as Array<Record<string, unknown>>) || [];
      const rates = rawRates
        .map((r) => ({
          rate_id: String(r.rate_id || ""),
          service_id: String(r.service_id || ""),
          service_name: String(r.service_name || ""),
          service_detail: String(r.service_detail || "pickup"),
          service_type: String(r.service_type || "parcel"),
          courier_id: String(r.courier_id || ""),
          courier_name: String(r.courier_name || ""),
          courier_logo: String(r.courier_logo || ""),
          pickup_date: String(r.pickup_date || dateColl),
          delivery: String(r.delivery || ""),
          price: Number(r.price || 0),
          shipment_price: Number(r.shipment_price || r.price || 0),
        }))
        .sort((a, b) => a.price - b.price);

      return jsonResponse({
        success: true,
        environment: creds.environment,
        rates,
      });
    }

    // -------------------------------------------------------------------------
    // 4. BOOK & PAY SHIPMENT (`EPSubmitOrderBulk` + `EPPayOrderBulk`)
    // -------------------------------------------------------------------------
    if (action === "book_and_pay") {
      const orderId = String(body.order_id || "").trim();
      const serviceId = String(body.service_id || "").trim();
      const courierId = String(body.courier_id || "").trim();
      const courierName = String(body.courier_name || "").trim();
      const serviceName = String(body.service_name || "").trim();
      const weight = Number(body.weight || 1);
      const content = String(body.content || "Order Parcel").trim().slice(0, 100);
      const value = Number(body.value || 10);
      const collectDate = String(body.collect_date || todayMytDate()).trim();
      const reference = String(body.reference || orderId.slice(0, 14)).trim();
      const autoPay = body.auto_pay !== false;

      const sender = (body.sender as Record<string, unknown>) || {};
      const receiver = (body.receiver as Record<string, unknown>) || {};

      if (!orderId || !serviceId) {
        return jsonResponse(
          { success: false, error: "order_id and service_id are required" },
          400
        );
      }

      // Step 4A: Submit Order to EasyParcel
      const submitRes = await callEasyParcel(creds.environment, "EPSubmitOrderBulk", {
        api: creds.apiKey,
        bulk: [
          {
            weight: String(weight > 0 ? weight : 1),
            width: String(Number(body.width || 0)),
            length: String(Number(body.length || 0)),
            height: String(Number(body.height || 0)),
            content,
            value: String(value > 0 ? value : 10),
            service_id: serviceId,
            pick_name: String(sender.name || "Merchant").trim(),
            pick_company: String(sender.company || sender.name || "").trim(),
            pick_contact: normalizePhone(String(sender.phone || "")),
            pick_mobile: normalizePhone(String(sender.phone || "")),
            pick_addr1: String(sender.addr1 || "").trim(),
            pick_addr2: String(sender.addr2 || "").trim(),
            pick_city: String(sender.city || "").trim(),
            pick_state: String(sender.state || "").trim().toLowerCase(),
            pick_code: String(sender.postcode || "").trim(),
            pick_country: "MY",
            send_name: String(receiver.name || "Customer").trim(),
            send_company: "",
            send_contact: normalizePhone(String(receiver.phone || "")),
            send_mobile: normalizePhone(String(receiver.phone || "")),
            send_addr1: String(receiver.addr1 || "").trim(),
            send_addr2: String(receiver.addr2 || "").trim(),
            send_city: String(receiver.city || "").trim(),
            send_state: String(receiver.state || "").trim().toLowerCase(),
            send_code: String(receiver.postcode || "").trim(),
            send_country: "MY",
            collect_date: collectDate,
            reference,
          },
        ],
      });

      const submitOk = String(submitRes.api_status || "").toLowerCase() === "success";
      const submitResultArr = (submitRes.result as Array<Record<string, unknown>>) || [];
      const submitFirst = submitResultArr[0] || {};

      if (!submitOk || String(submitFirst.status || "").toLowerCase() !== "success") {
        return jsonResponse({
          success: false,
          error: String(
            submitFirst.remarks || submitRes.error_remark || "Failed to create EasyParcel order"
          ),
          raw: submitRes,
        });
      }

      const epOrderNo = String(submitFirst.order_number || "");
      const epParcelNo = String(submitFirst.parcel_number || "");
      const shippingCost = Number(submitFirst.price || body.quoted_price || 0);

      let awbNumber = "";
      let awbPdfUrl = "";
      let trackingUrl = "";
      let shipmentStatus = "created";
      let paymentMessage = "Order Created (Unpaid)";
      let payRes: Record<string, unknown> = {};

      // Step 4B: Pay Order using EasyParcel Credit Balance
      if (autoPay && epOrderNo) {
        payRes = await callEasyParcel(creds.environment, "EPPayOrderBulk", {
          api: creds.apiKey,
          bulk: [{ order_no: epOrderNo }],
        });

        const payResultArr = (payRes.result as Array<Record<string, unknown>>) || [];
        const payFirst = payResultArr[0] || {};
        paymentMessage = String(payFirst.messagenow || "");

        const parcels = (payFirst.parcel as Array<Record<string, unknown>>) || [];
        const p0 = parcels[0] || {};

        if (p0.awb) {
          awbNumber = String(p0.awb || "");
          awbPdfUrl = String(p0.awb_id_link || "");
          trackingUrl = String(p0.tracking_url || "");
          shipmentStatus = "paid";
        } else if (paymentMessage.toLowerCase().includes("insufficient")) {
          shipmentStatus = "unpaid_insufficient_credit";
        }
      }

      // Step 4C: Persist in `order_shipments`
      const { data: savedShipment, error: insertErr } = await supabase
        .from("order_shipments")
        .insert({
          business_id: businessId,
          order_id: orderId,
          provider: "easyparcel",
          environment: creds.environment,
          ep_order_no: epOrderNo,
          ep_parcel_no: epParcelNo,
          courier_id: courierId,
          courier_name: courierName,
          service_id: serviceId,
          service_name: serviceName,
          awb_number: awbNumber || null,
          awb_pdf_url: awbPdfUrl || null,
          tracking_url: trackingUrl || null,
          shipping_cost: shippingCost,
          weight_kg: weight,
          pickup_date: collectDate,
          status: shipmentStatus,
          latest_tracking_status: paymentMessage,
          sender_info: sender,
          receiver_info: receiver,
          raw_response: { submit: submitRes, pay: payRes },
        })
        .select()
        .single();

      if (insertErr) {
        console.error("[easyparcel-proxy] Failed to save order_shipments:", insertErr);
      }

      // Step 4D: Sync tracking info back to `orders` table
      if (awbNumber || courierName) {
        await supabase
          .from("orders")
          .update({
            courier_name: courierName || serviceName || "EasyParcel",
            tracking_number: awbNumber || epOrderNo,
            tracking_url: trackingUrl || null,
            awb_pdf_url: awbPdfUrl || null,
          })
          .eq("id", orderId);
      }

      return jsonResponse({
        success: true,
        shipment: savedShipment || {
          ep_order_no: epOrderNo,
          ep_parcel_no: epParcelNo,
          courier_name: courierName,
          service_name: serviceName,
          awb_number: awbNumber,
          awb_pdf_url: awbPdfUrl,
          tracking_url: trackingUrl,
          shipping_cost: shippingCost,
          status: shipmentStatus,
        },
        payment_message: paymentMessage,
        insufficient_credit: shipmentStatus === "unpaid_insufficient_credit",
      });
    }

    // -------------------------------------------------------------------------
    // 5. TRACK PARCEL (`EPTrackingBulk`)
    // -------------------------------------------------------------------------
    if (action === "track_parcel") {
      const awbNo = String(body.awb_number || "").trim();
      const shipmentId = String(body.shipment_id || "").trim();

      if (!awbNo) {
        return jsonResponse({ success: false, error: "awb_number is required" }, 400);
      }

      const epRes = await callEasyParcel(creds.environment, "EPTrackingBulk", {
        api: creds.apiKey,
        bulk: [{ awb_no: awbNo }],
      });

      const ok = String(epRes.api_status || "").toLowerCase() === "success";
      if (!ok) {
        return jsonResponse({
          success: false,
          error: String(epRes.error_remark || "Tracking lookup failed"),
        });
      }

      const resArr = (epRes.result as Array<Record<string, unknown>>) || [];
      const first = resArr[0] || {};
      const latestStatus = String(first.latest_status || "");
      const latestUpdate = String(first.latest_update || "");

      // EasyParcel returns `status_list` as an object with numeric keys ("0", "1", ...) plus metadata keys
      const statusListObj = (first.status_list as Record<string, unknown>) || {};
      const events: Array<Record<string, unknown>> = [];
      for (const [k, v] of Object.entries(statusListObj)) {
        if (/^\d+$/.test(k) && v && typeof v === "object") {
          events.push(v as Record<string, unknown>);
        }
      }

      // Map EasyParcel status to simplified status
      let mappedStatus = "in_transit";
      const lower = latestStatus.toLowerCase();
      if (lower.includes("deliver")) {
        mappedStatus = "delivered";
      } else if (lower.includes("return") || lower.includes("fail")) {
        mappedStatus = "failed";
      }

      if (shipmentId) {
        await supabase
          .from("order_shipments")
          .update({
            status: mappedStatus,
            latest_tracking_status: latestStatus || null,
            tracking_events: events,
            updated_at: new Date().toISOString(),
          })
          .eq("id", shipmentId);
      }

      return jsonResponse({
        success: true,
        awb: awbNo,
        latest_status: latestStatus,
        latest_update: latestUpdate,
        status: mappedStatus,
        events,
      });
    }

    return jsonResponse({ success: false, error: `Unknown action: ${action}` }, 400);
  } catch (err) {
    console.error("[easyparcel-proxy] Error:", err);
    return jsonResponse(
      { success: false, error: err instanceof Error ? err.message : String(err) },
      500
    );
  }
});
