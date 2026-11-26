import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.6";

/**
 * NGAM EASYPARCEL PROXY EDGE FUNCTION (`easyparcel-proxy`)
 * ---------------------------------------------------------------------------
 * Menyokong DUA mod secara automatik:
 *  A. EasyParcel NextGen Open API (2026-09, OAuth 2.0) — MOD UTAMA PLATFORM NGAM
 *     - Guna `EASYPARCEL_CLIENT_ID` & `EASYPARCEL_CLIENT_SECRET` dalam Supabase Secrets
 *     - Aliran OAuth 1-klik terbina dalam:
 *       1. Buka `GET /functions/v1/easyparcel-proxy?action=oauth_start` (Admin sekali sahaja)
 *       2. EasyParcel redirect balik ke `GET /functions/v1/easyparcel-proxy?code=...`
 *       3. Token disimpan automatik dalam `public.platform_integrations` & auto-refresh!
 *  B. Classic Individual API (`EP-...`) — untuk peniaga yang memilih guna akaun sendiri
 *     atau fallback jika `EASYPARCEL_API_KEY` diset.
 *
 * Tindakan POST (`action`):
 *  - `platform_status`   — Semak status sambungan NextGen / Classic Platform
 *  - `verify_connection` — Uji kunci API Classic peniaga sendiri
 *  - `check_balance`     — Semak baki dompet EasyParcel
 *  - `check_rates`       — Semak harga kurier (PosLaju, J&T, Ninja Van, DHL, dll.)
 *  - `book_and_pay`      — Cipta & bayar penghantaran + simpan AWB PDF ke `order_shipments` & `orders`
 *  - `track_parcel`      — Semak status penghantaran terkini melalui nombor AWB
 */

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

// NextGen OAuth 2.0 credentials (Platform Mode)
const epClientId = (Deno.env.get("EASYPARCEL_CLIENT_ID") || "").trim();
const epClientSecret = (Deno.env.get("EASYPARCEL_CLIENT_SECRET") || "").trim();
const epRedirectUriOverride = (Deno.env.get("EASYPARCEL_REDIRECT_URI") || "").trim();

// Classic API fallback credentials
const platformClassicKey = (Deno.env.get("EASYPARCEL_API_KEY") || "").trim();
const platformClassicEnv =
  (Deno.env.get("EASYPARCEL_ENV") || "demo").trim().toLowerCase() === "live"
    ? "live"
    : "demo";

const NEXTGEN_BASE = "https://api.easyparcel.com";
const NEXTGEN_API_VERSION = "2026-09";
const NEXTGEN_OPEN_API = `${NEXTGEN_BASE}/open_api/${NEXTGEN_API_VERSION}`;

const supabase = createClient(supabaseUrl, supabaseServiceKey);

// Map EasyParcel 3-letter state codes -> ISO 3166-2 Malaysia subdivision codes (NextGen API)
const MY_STATE_TO_ISO: Record<string, string> = {
  jhr: "MY-01",
  kdh: "MY-02",
  ktn: "MY-03",
  mlk: "MY-04",
  nsn: "MY-05",
  phg: "MY-06",
  png: "MY-07",
  prk: "MY-08",
  pls: "MY-09",
  sgr: "MY-10",
  trg: "MY-11",
  sbh: "MY-12",
  srw: "MY-13",
  kul: "MY-14",
  lbn: "MY-15",
  pjy: "MY-16",
};

function toIsoSubdivision(stateCode: string): string {
  const s = String(stateCode || "").trim().toLowerCase();
  if (s.startsWith("my-")) return s.toUpperCase();
  return MY_STATE_TO_ISO[s] || "MY-10";
}

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function htmlResponse(html: string, status = 200): Response {
  return new Response(html, {
    status,
    headers: { "Content-Type": "text/html; charset=utf-8" },
  });
}

function getCallbackUrl(): string {
  if (epRedirectUriOverride) return epRedirectUriOverride;
  return `${supabaseUrl}/functions/v1/easyparcel-proxy`;
}

function normalizePhoneClassic(phone: string): string {
  const digits = String(phone || "").replace(/[^\d+]/g, "");
  if (!digits) return "0123456789";
  if (digits.startsWith("+60")) return "0" + digits.slice(3);
  if (digits.startsWith("60") && digits.length >= 10) return "0" + digits.slice(2);
  return digits;
}

/** NextGen API expects local Malaysian number without leading 0 or +60 (e.g. "123456789") */
function normalizePhoneNextGen(phone: string): string {
  let digits = String(phone || "").replace(/\D/g, "");
  if (digits.startsWith("60") && digits.length >= 10) {
    digits = digits.slice(2);
  }
  if (digits.startsWith("0")) {
    digits = digits.slice(1);
  }
  return digits || "123456789";
}

function todayMytDate(): string {
  const myt = new Date(Date.now() + 8 * 3600 * 1000);
  const y = myt.getUTCFullYear();
  const m = String(myt.getUTCMonth() + 1).padStart(2, "0");
  const d = String(myt.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

// =============================================================================
// NEXTGEN OAUTH 2.0 HELPERS
// =============================================================================

function basicAuthHeader(): string {
  return `Basic ${btoa(`${epClientId}:${epClientSecret}`)}`;
}

async function exchangeOAuthToken(params: Record<string, string>): Promise<Record<string, unknown>> {
  const form = new URLSearchParams(params);
  const res = await fetch(`${NEXTGEN_BASE}/oauth/token`, {
    method: "POST",
    headers: {
      Authorization: basicAuthHeader(),
      "Content-Type": "application/x-www-form-urlencoded",
      Accept: "application/json",
    },
    body: form.toString(),
  });
  const text = await res.text();
  let parsed: Record<string, unknown> = {};
  try {
    parsed = JSON.parse(text) as Record<string, unknown>;
  } catch {
    throw new Error(`EasyParcel OAuth non-JSON (${res.status}): ${text.slice(0, 200)}`);
  }
  if (!res.ok || !parsed.access_token) {
    throw new Error(
      String(parsed.error_description || parsed.message || parsed.error || `OAuth failed (${res.status})`)
    );
  }
  return parsed;
}

async function savePlatformTokens(
  tokenData: Record<string, unknown>,
  redirectUri: string
): Promise<void> {
  const expiresIn = Number(tokenData.expires_in || 36000);
  const refreshExpiresIn = Number(tokenData.refresh_token_expires_in || 31557600);
  const expiresAt = tokenData.expires_at
    ? String(tokenData.expires_at)
    : new Date(Date.now() + expiresIn * 1000).toISOString();
  const refreshExpiresAt = tokenData.refresh_token_expires_at
    ? String(tokenData.refresh_token_expires_at)
    : new Date(Date.now() + refreshExpiresIn * 1000).toISOString();

  await supabase.from("platform_integrations").upsert(
    {
      provider: "easyparcel_nextgen",
      access_token: String(tokenData.access_token),
      refresh_token: tokenData.refresh_token ? String(tokenData.refresh_token) : null,
      expires_at: expiresAt,
      refresh_expires_at: refreshExpiresAt,
      redirect_uri: redirectUri,
      metadata: {
        token_type: tokenData.token_type || "Bearer",
        app: tokenData.app || null,
      },
      updated_at: new Date().toISOString(),
    },
    { onConflict: "provider" }
  );
}

async function getValidNextGenAccessToken(): Promise<string | null> {
  if (!epClientId || !epClientSecret) return null;

  const { data } = await supabase
    .from("platform_integrations")
    .select("access_token, refresh_token, expires_at, redirect_uri")
    .eq("provider", "easyparcel_nextgen")
    .maybeSingle();

  if (!data || !data.access_token) return null;

  const expiresMs = data.expires_at ? new Date(String(data.expires_at)).getTime() : 0;
  // Return cached token if still valid for at least 2 minutes
  if (expiresMs > Date.now() + 120 * 1000) {
    return String(data.access_token);
  }

  // Otherwise auto-refresh using refresh_token
  if (!data.refresh_token) return String(data.access_token);

  const redirectUri = String(data.redirect_uri || getCallbackUrl());
  const refreshed = await exchangeOAuthToken({
    grant_type: "refresh_token",
    refresh_token: String(data.refresh_token),
    redirect_uri: redirectUri,
  });

  await savePlatformTokens(
    {
      ...refreshed,
      refresh_token: refreshed.refresh_token || data.refresh_token,
    },
    redirectUri
  );

  return String(refreshed.access_token);
}

async function callNextGen(
  method: "GET" | "POST",
  path: string,
  accessToken: string,
  body?: Record<string, unknown>
): Promise<Record<string, unknown>> {
  const res = await fetch(`${NEXTGEN_OPEN_API}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  try {
    return JSON.parse(text) as Record<string, unknown>;
  } catch {
    throw new Error(`EasyParcel NextGen non-JSON (${res.status}): ${text.slice(0, 200)}`);
  }
}

// =============================================================================
// CLASSIC INDIVIDUAL API HELPERS (Optional merchant custom key fallback)
// =============================================================================

function getClassicBaseUrl(env: string): string {
  return env === "live"
    ? "https://connect.easyparcel.my/?ac="
    : "https://demo.connect.easyparcel.my/?ac=";
}

function appendFormParams(params: URLSearchParams, value: unknown, prefix?: string): void {
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

async function callClassicEasyParcel(
  env: string,
  epAction: string,
  payload: Record<string, unknown>
): Promise<Record<string, unknown>> {
  const params = new URLSearchParams();
  appendFormParams(params, payload);
  const res = await fetch(`${getClassicBaseUrl(env)}${epAction}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      Accept: "application/json",
    },
    body: params.toString(),
  });
  const rawText = await res.text();
  try {
    return JSON.parse(rawText) as Record<string, unknown>;
  } catch {
    throw new Error(`EasyParcel Classic non-JSON (${res.status}): ${rawText.slice(0, 200)}`);
  }
}

// =============================================================================
// CALLER ACCESS & CREDENTIAL RESOLUTION
// =============================================================================

async function verifyCallerAccess(
  authHeader: string | null,
  businessId: string
): Promise<{ ok: boolean; userId?: string; reason?: string }> {
  if (!authHeader || !/^Bearer\s+/i.test(authHeader)) {
    return { ok: false, reason: "Missing Bearer Authorization header" };
  }
  const token = authHeader.replace(/^Bearer\s+/i, "").trim();
  const { data: userData, error: userErr } = await supabase.auth.getUser(token);
  if (userErr || !userData?.user) {
    return { ok: false, reason: `Invalid or expired session token (${userErr?.message || "no user"})` };
  }

  const userId = userData.user.id;
  const userEmail = (userData.user.email || "").trim().toLowerCase();

  // 1. Business owner
  const { data: bizRows, error: bizErr } = await supabase
    .from("businesses")
    .select("id, owner_user_id")
    .eq("id", businessId)
    .limit(1);
  const biz = bizRows?.[0];
  if (biz && String(biz.owner_user_id) === String(userId)) {
    return { ok: true, userId };
  }

  // 2. Active or invited staff (by user_id or email) — use .limit(1) to avoid PGRST116 on multiple rows
  const { data: staffById } = await supabase
    .from("team_members")
    .select("id, status")
    .eq("business_id", businessId)
    .eq("user_id", userId)
    .neq("status", "inactive")
    .limit(1);
  if (staffById && staffById.length > 0) return { ok: true, userId };

  if (userEmail) {
    const { data: staffByEmail } = await supabase
      .from("team_members")
      .select("id, status")
      .eq("business_id", businessId)
      .ilike("email", userEmail)
      .neq("status", "inactive")
      .limit(1);
    if (staffByEmail && staffByEmail.length > 0) return { ok: true, userId };
  }

  // 3. Super admin / admin
  const { data: adminRoles } = await supabase
    .from("user_roles")
    .select("role")
    .eq("user_id", userId)
    .in("role", ["super_admin", "admin"])
    .limit(1);
  if (adminRoles && adminRoles.length > 0) return { ok: true, userId };

  // 4. Fallback: check if this user owns ANY business or has access via business_integrations
  const { data: intRows } = await supabase
    .from("business_integrations")
    .select("business_id")
    .eq("business_id", businessId)
    .limit(1);
  if (bizErr) {
    return { ok: false, reason: `DB check error: ${bizErr.message}` };
  }
  if (!biz && (!intRows || intRows.length === 0)) {
    return { ok: false, reason: `Business ${businessId.slice(0, 8)} not found in DB` };
  }

  return {
    ok: false,
    reason: `User ${userId.slice(0, 8)} is not owner (${String(biz?.owner_user_id || "none").slice(0, 8)}) or staff of business ${businessId.slice(0, 8)}`,
  };
}

type ResolvedAuth =
  | { engine: "nextgen"; accessToken: string; environment: string }
  | { engine: "classic"; apiKey: string; environment: string };

async function resolveAuth(businessId: string): Promise<ResolvedAuth | null> {
  // 1. Check if merchant opted into custom Classic EasyParcel key
  const { data } = await supabase
    .from("business_integrations")
    .select("api_key, environment, config")
    .eq("business_id", businessId)
    .eq("provider", "easyparcel")
    .maybeSingle();

  const cfg = (data?.config as Record<string, unknown>) || {};
  const mode = String(cfg.mode || "platform").toLowerCase();

  if (mode === "custom" && data?.api_key && String(data.api_key).trim().length > 0) {
    return {
      engine: "classic",
      apiKey: String(data.api_key).trim(),
      environment: String(data.environment || "demo") === "live" ? "live" : "demo",
    };
  }

  // 2. Primary Platform Mode: EasyParcel NextGen OAuth 2.0
  const nextGenToken = await getValidNextGenAccessToken();
  if (nextGenToken) {
    return { engine: "nextgen", accessToken: nextGenToken, environment: "live" };
  }

  // 3. Fallback Platform Mode: Classic API Key in Supabase Secrets
  if (platformClassicKey) {
    return {
      engine: "classic",
      apiKey: platformClassicKey,
      environment: platformClassicEnv,
    };
  }

  return null;
}

// =============================================================================
// MAIN HANDLER
// =============================================================================

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // ---------------------------------------------------------------------------
  // GET: EasyParcel NextGen OAuth 2.0 Start & Callback
  // ---------------------------------------------------------------------------
  if (req.method === "GET") {
    const url = new URL(req.url);
    const action = url.searchParams.get("action");
    const code = url.searchParams.get("code");
    const oauthError = url.searchParams.get("error");

    if (action === "oauth_start") {
      if (!epClientId || !epClientSecret) {
        return htmlResponse(
          `<h2>EASYPARCEL_CLIENT_ID / EASYPARCEL_CLIENT_SECRET belum diset di Supabase Secrets.</h2>`,
          400
        );
      }
      const redirectUri = getCallbackUrl();
      const loginUrl =
        `${NEXTGEN_BASE}/oauth/login?client_id=${encodeURIComponent(epClientId)}` +
        `&redirect_uri=${encodeURIComponent(redirectUri)}` +
        `&state=ngam_platform_auth`;
      return Response.redirect(loginUrl, 302);
    }

    if (oauthError) {
      return htmlResponse(
        `<h2>Gagal menyambungkan EasyParcel: ${oauthError}</h2><p>Sila cuba semula.</p>`,
        400
      );
    }

    if (code) {
      try {
        if (!epClientId || !epClientSecret) {
          return htmlResponse(
            `<h2>EASYPARCEL_CLIENT_ID / EASYPARCEL_CLIENT_SECRET tiada dalam Supabase Secrets.</h2>`,
            400
          );
        }
        const redirectUri = getCallbackUrl();
        const tokenData = await exchangeOAuthToken({
          grant_type: "authorization_code",
          code,
          redirect_uri: redirectUri,
        });
        await savePlatformTokens(tokenData, redirectUri);

        return htmlResponse(`
          <!DOCTYPE html>
          <html>
            <head><meta charset="utf-8"><title>EasyParcel Connected</title></head>
            <body style="font-family:system-ui,sans-serif;background:#0a0a14;color:#fff;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;">
              <div style="background:#141827;border:1px solid rgba(52,211,153,.4);border-radius:20px;padding:32px;max-width:460px;text-align:center;">
                <h2 style="color:#34d399;margin-top:0;">EasyParcel NextGen Berjaya Disambungkan!</h2>
                <p style="color:#cbd5e1;line-height:1.5;">
                  Token OAuth 2.0 telah disimpan dengan selamat dalam <b>Ngam Platform</b> dan akan diperbaharui secara automatik.
                  Semua peniaga dalam Ngam Business kini boleh guna EasyParcel dengan 1 klik!
                </p>
                <p style="color:#94a3b8;font-size:13px;">Anda boleh tutup tetingkap ini sekarang.</p>
              </div>
            </body>
          </html>
        `);
      } catch (err) {
        return htmlResponse(
          `<h2>Ralat OAuth EasyParcel</h2><pre>${err instanceof Error ? err.message : String(err)}</pre>`,
          500
        );
      }
    }

    return jsonResponse({
      ok: true,
      service: "ngam-easyparcel-proxy",
      nextgen_configured: Boolean(epClientId && epClientSecret),
      callback_url: getCallbackUrl(),
    });
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
    if (!caller.ok) {
      return jsonResponse(
        { success: false, error: caller.reason || "Unauthorized business access" },
        401
      );
    }

    // -------------------------------------------------------------------------
    // 0. PLATFORM STATUS
    // -------------------------------------------------------------------------
    if (action === "platform_status") {
      const nextGenToken = await getValidNextGenAccessToken();
      return jsonResponse({
        success: true,
        platform_ready: Boolean(nextGenToken || platformClassicKey),
        engine: nextGenToken ? "nextgen" : platformClassicKey ? "classic" : "none",
      });
    }

    // -------------------------------------------------------------------------
    // 1. VERIFY CUSTOM CLASSIC API KEY
    // -------------------------------------------------------------------------
    if (action === "verify_connection") {
      const apiKey = String(body.api_key || "").trim();
      const environment = String(body.environment || "demo") === "live" ? "live" : "demo";
      if (!apiKey) {
        return jsonResponse({ success: false, error: "API key is required" }, 400);
      }

      const epRes = await callClassicEasyParcel(environment, "EPCheckCreditBalance", {
        api: apiKey,
      });
      const ok = String(epRes.api_status || "").toLowerCase() === "success";
      if (!ok) {
        return jsonResponse({
          success: false,
          error: String(epRes.error_remark || "Invalid EasyParcel API key"),
        });
      }
      return jsonResponse({
        success: true,
        balance: Number(epRes.result || 0),
        currency: "MYR",
        environment,
      });
    }

    const auth = await resolveAuth(businessId);
    if (!auth) {
      return jsonResponse(
        {
          success: false,
          error:
            "EasyParcel platform is not connected yet. Admin needs to authorize EasyParcel NextGen OAuth.",
        },
        400
      );
    }

    // -------------------------------------------------------------------------
    // 2. CHECK BALANCE
    // -------------------------------------------------------------------------
    if (action === "check_balance") {
      if (auth.engine === "nextgen") {
        const res = await callNextGen("GET", "/wallet", auth.accessToken);
        const dataObj = (res.data as Record<string, unknown>) || {};
        const wallets = (dataObj.wallet as Array<Record<string, unknown>>) || [];
        const bal = Number(wallets[0]?.balance || 0);
        return jsonResponse({ success: true, balance: bal, currency: "MYR", engine: "nextgen" });
      }
      const epRes = await callClassicEasyParcel(auth.environment, "EPCheckCreditBalance", {
        api: auth.apiKey,
      });
      if (String(epRes.api_status || "").toLowerCase() !== "success") {
        return jsonResponse({ success: false, error: String(epRes.error_remark || "Failed") });
      }
      return jsonResponse({
        success: true,
        balance: Number(epRes.result || 0),
        currency: "MYR",
        engine: "classic",
      });
    }

    // -------------------------------------------------------------------------
    // 3. CHECK COURIER RATES
    // -------------------------------------------------------------------------
    if (action === "check_rates") {
      const pickCode = String(body.pick_code || "").trim();
      const pickState = String(body.pick_state || "").trim().toLowerCase();
      const sendCode = String(body.send_code || "").trim();
      const sendState = String(body.send_state || "").trim().toLowerCase();
      const weight = Number(body.weight || 1);
      const width = Number(body.width || 5);
      const length = Number(body.length || 5);
      const height = Number(body.height || 5);
      const parcelValue = Number(body.parcel_value || 50);
      const dateColl = String(body.date_coll || todayMytDate()).trim();

      if (!pickCode || !pickState || !sendCode || !sendState) {
        return jsonResponse(
          { success: false, error: "Sender & receiver postcode and state are required" },
          400
        );
      }

      if (auth.engine === "nextgen") {
        const ngRes = await callNextGen("POST", "/shipment/quotations", auth.accessToken, {
          shipment: [
            {
              sender: {
                postcode: pickCode,
                subdivision_code: toIsoSubdivision(pickState),
                country: "MY",
              },
              receiver: {
                postcode: sendCode,
                subdivision_code: toIsoSubdivision(sendState),
                country: "MY",
              },
              parcel_value: parcelValue > 0 ? parcelValue : 50,
              weight: weight > 0 ? weight : 1,
              width: width > 0 ? width : 5,
              length: length > 0 ? length : 5,
              height: height > 0 ? height : 5,
            },
          ],
        });

        const statusCode = Number(ngRes.status_code || 0);
        const dataArr = (ngRes.data as Array<Record<string, unknown>>) || [];
        const first = dataArr[0] || {};
        if (statusCode !== 200 || String(first.status || "").toLowerCase() !== "success") {
          return jsonResponse({
            success: false,
            error: String(ngRes.message || first.message || "Failed to fetch courier rates"),
            raw: ngRes,
          });
        }

        const formatDeliveryDuration = (raw: unknown): string => {
          if (!raw) return "1-3 working day(s)";
          let obj: Record<string, unknown> | null = null;
          if (typeof raw === "object") {
            obj = raw as Record<string, unknown>;
          } else if (typeof raw === "string") {
            const trimmed = raw.trim();
            if (trimmed.startsWith("{")) {
              try {
                obj = JSON.parse(trimmed) as Record<string, unknown>;
              } catch {
                return trimmed;
              }
            } else {
              return trimmed || "1-3 working day(s)";
            }
          }
          if (obj && obj.value !== undefined) {
            const val = String(obj.value).trim();
            const unit = String(obj.type || "days").toLowerCase();
            if (unit.includes("hour")) return `${val} hour(s)`;
            return `${val} working day(s)`;
          }
          return "1-3 working day(s)";
        };

        const quotations = (first.quotations as Array<Record<string, unknown>>) || [];
        const rates = quotations
          .map((q) => {
            const c = (q.courier as Record<string, unknown>) || {};
            const p = (q.pricing as Record<string, unknown>) || {};
            const isPickup = c.is_pickup === true;
            const isDropoff = c.is_dropoff === true;
            const detail =
              isPickup && isDropoff ? "dropoff/pickup" : isPickup ? "pickup" : "dropoff";
            const price = Number(p.total_amount ?? p.shipment_price ?? 0);
            return {
              rate_id: String(c.service_id || ""),
              service_id: String(c.service_id || ""),
              service_name: String(c.service_name || ""),
              service_detail: detail,
              service_type: "parcel",
              courier_id: String(c.courier_id || ""),
              courier_name: String(c.courier_name || ""),
              courier_logo: String(c.courier_logo || ""),
              pickup_date: dateColl,
              delivery: formatDeliveryDuration(c.delivery_duration),
              price,
              shipment_price: Number(p.shipment_price ?? price),
            };
          })
          .filter((r) => r.service_id.length > 0)
          .sort((a, b) => a.price - b.price);

        return jsonResponse({ success: true, engine: "nextgen", rates });
      }

      // Classic Individual API fallback
      const epRes = await callClassicEasyParcel(auth.environment, "EPRateCheckingBulk", {
        api: auth.apiKey,
        bulk: [
          {
            pick_code: pickCode,
            pick_state: pickState,
            pick_country: "MY",
            send_code: sendCode,
            send_state: sendState,
            send_country: "MY",
            weight: String(weight > 0 ? weight : 1),
            width: String(Number(body.width || 0)),
            length: String(Number(body.length || 0)),
            height: String(Number(body.height || 0)),
            date_coll: dateColl,
          },
        ],
        exclude_fields: ["rates.*.pickup_point", "rates.*.dropoff_point"],
      });

      const ok = String(epRes.api_status || "").toLowerCase() === "success";
      const resultArr = (epRes.result as Array<Record<string, unknown>>) || [];
      const firstResult = resultArr[0] || {};
      if (!ok || String(firstResult.status || "").toLowerCase() !== "success") {
        return jsonResponse({
          success: false,
          error: String(firstResult.remarks || epRes.error_remark || "Rate check failed"),
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

      return jsonResponse({ success: true, engine: "classic", rates });
    }

    // -------------------------------------------------------------------------
    // 4. BOOK & PAY SHIPMENT
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

      let epOrderNo = "";
      let epParcelNo = "";
      let awbNumber = "";
      let awbPdfUrl = "";
      let trackingUrl = "";
      let shippingCost = Number(body.quoted_price || 0);
      let shipmentStatus = "created";
      let paymentMessage = "";
      let rawResponse: Record<string, unknown> = {};

      if (auth.engine === "nextgen") {
        const ngRes = await callNextGen("POST", "/shipment/submit_orders", auth.accessToken, {
          shipment: [
            {
              reference,
              service_id: serviceId,
              collection_date: collectDate,
              weight: weight > 0 ? weight : 1,
              height: Number(body.height || 5),
              length: Number(body.length || 5),
              width: Number(body.width || 5),
              item: [
                {
                  content,
                  weight: weight > 0 ? weight : 1,
                  height: Number(body.height || 5),
                  length: Number(body.length || 5),
                  width: Number(body.width || 5),
                  currency_code: "MYR",
                  value: value > 0 ? value : 10,
                  quantity: 1,
                },
              ],
              sender: {
                name: String(sender.name || "Merchant").trim(),
                company: String(sender.company || sender.name || "").trim(),
                phone_number_country_code: "MY",
                phone_number: normalizePhoneNextGen(String(sender.phone || "")),
                email: String(sender.email || "merchant@ngam.dev").trim(),
                address_1: String(sender.addr1 || "").trim(),
                address_2: String(sender.addr2 || "").trim(),
                postcode: String(sender.postcode || "").trim(),
                city: String(sender.city || sender.postcode || "").trim(),
                subdivision_code: toIsoSubdivision(String(sender.state || "sgr")),
                country_code: "MY",
              },
              receiver: {
                name: String(receiver.name || "Customer").trim(),
                company: "",
                phone_number_country_code: "MY",
                phone_number: normalizePhoneNextGen(String(receiver.phone || "")),
                email: String(receiver.email || "customer@ngam.dev").trim(),
                address_1: String(receiver.addr1 || "").trim(),
                address_2: String(receiver.addr2 || "").trim(),
                postcode: String(receiver.postcode || "").trim(),
                city: String(receiver.city || receiver.postcode || "").trim(),
                subdivision_code: toIsoSubdivision(String(receiver.state || "sgr")),
                country_code: "MY",
              },
            },
          ],
        });

        rawResponse = ngRes;
        const dataArr = (ngRes.data as Array<Record<string, unknown>>) || [];
        const firstOrder = dataArr[0] || {};
        const shipments = (firstOrder.shipments as Array<Record<string, unknown>>) || [];
        const s0 = shipments[0] || {};

        if (
          Number(ngRes.status_code || 0) !== 200 ||
          String(s0.status || "").toLowerCase() !== "success"
        ) {
          return jsonResponse({
            success: false,
            error: String(
              s0.message || s0.error || ngRes.message || "Failed to submit EasyParcel order"
            ),
            raw: ngRes,
          });
        }

        const orderDetails = (firstOrder.order_details as Record<string, unknown>) || {};
        const pricing = (s0.pricing_breakdown as Record<string, unknown>) || {};
        const awbByFormat = (s0.awb_urls_by_format as Record<string, unknown>) || {};

        epOrderNo = String(orderDetails.order_number || "");
        epParcelNo = String(s0.shipment_number || "");
        awbNumber = String(s0.awb_number || "");
        awbPdfUrl = String(s0.awb_url || awbByFormat.A6 || awbByFormat.A4 || "");
        trackingUrl = String(s0.tracking_url || "");
        shippingCost = Number(pricing.total_paid_amount || body.quoted_price || 0);
        shipmentStatus = "paid";
        paymentMessage = "Confirmed & Paid (NextGen)";
      } else {
        // Classic Individual API
        const submitRes = await callClassicEasyParcel(auth.environment, "EPSubmitOrderBulk", {
          api: auth.apiKey,
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
              pick_contact: normalizePhoneClassic(String(sender.phone || "")),
              pick_mobile: normalizePhoneClassic(String(sender.phone || "")),
              pick_addr1: String(sender.addr1 || "").trim(),
              pick_addr2: String(sender.addr2 || "").trim(),
              pick_city: String(sender.city || "").trim(),
              pick_state: String(sender.state || "").trim().toLowerCase(),
              pick_code: String(sender.postcode || "").trim(),
              pick_country: "MY",
              send_name: String(receiver.name || "Customer").trim(),
              send_company: "",
              send_contact: normalizePhoneClassic(String(receiver.phone || "")),
              send_mobile: normalizePhoneClassic(String(receiver.phone || "")),
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

        const submitResultArr = (submitRes.result as Array<Record<string, unknown>>) || [];
        const submitFirst = submitResultArr[0] || {};
        if (
          String(submitRes.api_status || "").toLowerCase() !== "success" ||
          String(submitFirst.status || "").toLowerCase() !== "success"
        ) {
          return jsonResponse({
            success: false,
            error: String(
              submitFirst.remarks || submitRes.error_remark || "Failed to create EasyParcel order"
            ),
          });
        }

        epOrderNo = String(submitFirst.order_number || "");
        epParcelNo = String(submitFirst.parcel_number || "");
        shippingCost = Number(submitFirst.price || body.quoted_price || 0);
        let payRes: Record<string, unknown> = {};

        if (autoPay && epOrderNo) {
          payRes = await callClassicEasyParcel(auth.environment, "EPPayOrderBulk", {
            api: auth.apiKey,
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
        rawResponse = { submit: submitRes, pay: payRes };
      }

      const { data: savedShipment } = await supabase
        .from("order_shipments")
        .insert({
          business_id: businessId,
          order_id: orderId,
          provider: "easyparcel",
          environment: auth.environment,
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
          raw_response: rawResponse,
        })
        .select()
        .single();

      if (awbNumber || epOrderNo || courierName) {
        await supabase
          .from("orders")
          .update({
            courier_name: courierName || serviceName || "EasyParcel",
            tracking_number: awbNumber || epParcelNo || epOrderNo,
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
    // 5. TRACK PARCEL
    // -------------------------------------------------------------------------
    if (action === "track_parcel") {
      const awbNo = String(body.awb_number || "").trim();
      const shipmentId = String(body.shipment_id || "").trim();
      if (!awbNo) {
        return jsonResponse({ success: false, error: "awb_number is required" }, 400);
      }

      let latestStatus = "";
      let latestUpdate = "";
      const events: Array<Record<string, unknown>> = [];

      if (auth.engine === "nextgen") {
        const ngRes = await callNextGen("POST", "/shipment/tracking_status", auth.accessToken, {
          awb_numbers: [awbNo],
        });
        const dataObj = (ngRes.data as Record<string, unknown>) || {};
        const results = (dataObj.results as Array<Record<string, unknown>>) || [];
        const r0 = results[0] || {};
        if (Number(ngRes.status_code || 0) !== 200 || String(r0.status || "").toLowerCase() !== "success") {
          return jsonResponse({
            success: false,
            error: String(ngRes.message || "Tracking lookup failed"),
          });
        }
        latestStatus = String(r0.latest_tracking_status || "");
        latestUpdate = String(r0.latest_event_date || "");
        const logs = (r0.status_log as Array<Record<string, unknown>>) || [];
        for (const l of logs) {
          events.push({
            event_date: String(l.event_date || ""),
            event_time: "",
            status: String(l.tracking_status || ""),
            location: String(l.location || ""),
          });
        }
      } else {
        const epRes = await callClassicEasyParcel(auth.environment, "EPTrackingBulk", {
          api: auth.apiKey,
          bulk: [{ awb_no: awbNo }],
        });
        if (String(epRes.api_status || "").toLowerCase() !== "success") {
          return jsonResponse({
            success: false,
            error: String(epRes.error_remark || "Tracking lookup failed"),
          });
        }
        const resArr = (epRes.result as Array<Record<string, unknown>>) || [];
        const first = resArr[0] || {};
        latestStatus = String(first.latest_status || "");
        latestUpdate = String(first.latest_update || "");
        const statusListObj = (first.status_list as Record<string, unknown>) || {};
        for (const [k, v] of Object.entries(statusListObj)) {
          if (/^\d+$/.test(k) && v && typeof v === "object") {
            events.push(v as Record<string, unknown>);
          }
        }
      }

      let mappedStatus = "in_transit";
      const lower = latestStatus.toLowerCase();
      if (lower.includes("deliver")) mappedStatus = "delivered";
      else if (lower.includes("return") || lower.includes("fail")) mappedStatus = "failed";

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
