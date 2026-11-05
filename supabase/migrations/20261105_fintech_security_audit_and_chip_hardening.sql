-- =========================================================================================
-- NGAM FINTECH & SECURITY ARCHITECTURE HARDENING MIGRATION (2026-11-05)
-- Non-Destructive Incremental Migration:
--   1. Zero Auto-Withdrawal (Manual Payout Gate via `payout_requests`)
--   2. Integer Cents & NUMERIC(12,2) Financial Integrity + Non-Negative Constraints
--   3. Auto-Initialization of `merchant_balances` on Business Creation + Backfill
--   4. Strict RLS Lockdown & Column-Level Financial Mutation Guards (Orders, Users, Businesses)
--   5. Server-Side Order/Booking, Voucher, Commission & Gateway Fee Calculation RPC
--   6. Webhook Idempotency Ledger & Atomic Merchant Settlement Credit RPC
-- =========================================================================================

BEGIN;

-- =========================================================================================
-- 1. FINANCIAL INTEGRITY: STANDARDIZE NUMERIC(12,2), CENTS COLUMNS & CHECK (>= 0) CONSTRAINTS
-- =========================================================================================

-- 1.1 Ensure `users.user_balance` is NUMERIC(12,2) and strictly non-negative
ALTER TABLE public.users
  ALTER COLUMN user_balance TYPE NUMERIC(12, 2) USING ROUND(COALESCE(user_balance, 0)::numeric, 2),
  ALTER COLUMN user_balance SET DEFAULT 0.00,
  ALTER COLUMN user_balance SET NOT NULL;

DO $$ BEGIN
  ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_balance_non_negative;
  ALTER TABLE public.users ADD CONSTRAINT users_balance_non_negative CHECK (user_balance >= 0.00);
EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- 1.2 Ensure `orders` financial columns have exact precision and integer cents representation
ALTER TABLE public.orders
  ALTER COLUMN total TYPE NUMERIC(12, 2) USING ROUND(COALESCE(total, 0)::numeric, 2),
  ADD COLUMN IF NOT EXISTS subtotal_cents BIGINT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS discount_cents BIGINT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS gateway_fee_cents BIGINT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS platform_commission_cents BIGINT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS merchant_net_cents BIGINT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_cents BIGINT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS chip_purchase_id TEXT;

DO $$ BEGIN
  ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_financial_non_negative;
  ALTER TABLE public.orders ADD CONSTRAINT orders_financial_non_negative CHECK (
    total >= 0.00 AND
    subtotal_cents >= 0 AND
    discount_cents >= 0 AND
    gateway_fee_cents >= 0 AND
    platform_commission_cents >= 0 AND
    merchant_net_cents >= 0 AND
    total_cents >= 0
  );
EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- 1.3 Merchant Wallets / Balances Ledger Table (Integer Cents + NUMERIC(12,2))
CREATE TABLE IF NOT EXISTS public.merchant_balances (
  business_id             UUID PRIMARY KEY REFERENCES public.businesses(id) ON DELETE RESTRICT,
  available_balance_cents BIGINT NOT NULL DEFAULT 0 CHECK (available_balance_cents >= 0),
  pending_payout_cents    BIGINT NOT NULL DEFAULT 0 CHECK (pending_payout_cents >= 0),
  lifetime_gross_cents    BIGINT NOT NULL DEFAULT 0 CHECK (lifetime_gross_cents >= 0),
  lifetime_net_cents      BIGINT NOT NULL DEFAULT 0 CHECK (lifetime_net_cents >= 0),
  available_balance       NUMERIC(12, 2) GENERATED ALWAYS AS (ROUND((available_balance_cents / 100.0)::numeric, 2)) STORED,
  pending_payout_balance  NUMERIC(12, 2) GENERATED ALWAYS AS (ROUND((pending_payout_cents / 100.0)::numeric, 2)) STORED,
  currency                TEXT NOT NULL DEFAULT 'MYR',
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 1.3b Auto-initialize `merchant_balances` (0 balance) for all existing businesses
INSERT INTO public.merchant_balances (
  business_id,
  available_balance_cents,
  pending_payout_cents,
  lifetime_gross_cents,
  lifetime_net_cents
)
SELECT id, 0, 0, 0, 0
FROM public.businesses
ON CONFLICT (business_id) DO NOTHING;

-- 1.3c Trigger to auto-initialize `merchant_balances` (0 balance) whenever a new business is created
CREATE OR REPLACE FUNCTION public.init_merchant_balance_on_business_create()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.merchant_balances (
    business_id,
    available_balance_cents,
    pending_payout_cents,
    lifetime_gross_cents,
    lifetime_net_cents,
    updated_at
  ) VALUES (
    NEW.id,
    0,
    0,
    0,
    0,
    NOW()
  )
  ON CONFLICT (business_id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auto_init_merchant_balance ON public.businesses;
CREATE TRIGGER trg_auto_init_merchant_balance
  AFTER INSERT ON public.businesses
  FOR EACH ROW
  EXECUTE FUNCTION public.init_merchant_balance_on_business_create();

-- 1.4 Immutable Financial Ledger Entries Table (Double-Entry Audit Trail)
CREATE TABLE IF NOT EXISTS public.merchant_ledger_entries (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id         UUID NOT NULL REFERENCES public.businesses(id) ON DELETE RESTRICT,
  entry_type          TEXT NOT NULL CHECK (entry_type IN ('sale_credit', 'payout_hold', 'payout_completed', 'payout_rejected_refund', 'dispute_refund', 'adjustment')),
  amount_cents        BIGINT NOT NULL, -- positive for credit, negative for debit
  balance_after_cents BIGINT NOT NULL CHECK (balance_after_cents >= 0),
  reference_type      TEXT NOT NULL,   -- 'order', 'booking', 'payout_request'
  reference_id        TEXT NOT NULL,
  chip_purchase_id    TEXT,
  description         TEXT NOT NULL,
  metadata            JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_merchant_ledger_business_created
  ON public.merchant_ledger_entries(business_id, created_at DESC);

-- 1.5 Webhook Idempotency Table (Prevents Replay & Duplicate CHIP Callbacks)
CREATE TABLE IF NOT EXISTS public.processed_payment_webhooks (
  chip_purchase_id TEXT PRIMARY KEY,
  event_type       TEXT NOT NULL,
  target_type      TEXT NOT NULL, -- 'order' or 'booking'
  target_id        TEXT NOT NULL,
  paid_cents       BIGINT NOT NULL CHECK (paid_cents >= 0),
  raw_payload      JSONB NOT NULL,
  processed_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =========================================================================================
-- 2. ZERO AUTO-WITHDRAWAL: MANUAL PAYOUT GATE (`payout_requests`)
-- =========================================================================================

CREATE TABLE IF NOT EXISTS public.payout_requests (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id          UUID NOT NULL REFERENCES public.businesses(id) ON DELETE RESTRICT,
  requested_by_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  amount_cents         BIGINT NOT NULL CHECK (amount_cents >= 1000), -- Minimum RM 10.00 (1000 sen)
  amount               NUMERIC(12, 2) GENERATED ALWAYS AS (ROUND((amount_cents / 100.0)::numeric, 2)) STORED,
  bank_name            TEXT NOT NULL,
  bank_account_number  TEXT NOT NULL,
  bank_account_holder  TEXT NOT NULL,
  status               TEXT NOT NULL DEFAULT 'pending_approval'
                       CHECK (status IN ('pending_approval', 'approved_processing', 'completed', 'rejected')),
  admin_reviewer_id    UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  admin_reference_no   TEXT, -- Manual bank transfer / DuitNow receipt ref entered by Super Admin
  admin_notes          TEXT,
  reviewed_at          TIMESTAMPTZ,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payout_requests_business_status
  ON public.payout_requests(business_id, status, created_at DESC);

-- 2.1 Atomic RPC for Merchant Withdrawal Request (Manual Gate ONLY - Never calls Bank/CHIP API)
CREATE OR REPLACE FUNCTION public.request_merchant_payout(
  p_business_id UUID,
  p_amount_cents BIGINT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_owner_id UUID;
  v_avail_cents BIGINT;
  v_new_avail_cents BIGINT;
  v_bank_name TEXT;
  v_acc_no TEXT;
  v_acc_holder TEXT;
  v_payout_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Pengesahan diperlukan (Unauthenticated).';
  END IF;

  IF p_amount_cents IS NULL OR p_amount_cents < 1000 THEN
    RAISE EXCEPTION 'Amaun pengeluaran minimum ialah RM 10.00 (1000 sen).';
  END IF;

  -- 1. Verify caller is the legitimate owner of this business
  SELECT owner_user_id INTO v_owner_id
  FROM public.businesses
  WHERE id = p_business_id AND status = 'active';

  IF v_owner_id IS NULL OR v_owner_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Akses ditolak: Hanya pemilik sah perniagaan boleh memohon pengeluaran dana.';
  END IF;

  -- 2. Fetch verified bank compliance details
  SELECT bank_name, account_number, account_holder
  INTO v_bank_name, v_acc_no, v_acc_holder
  FROM public.business_compliance
  WHERE business_id = p_business_id;

  IF v_bank_name IS NULL OR TRIM(v_bank_name) = '' OR v_acc_no IS NULL OR TRIM(v_acc_no) = '' THEN
    RAISE EXCEPTION 'Sila lengkapkan maklumat akaun bank perniagaan sebelum memohon pengeluaran.';
  END IF;

  -- 3. Ensure a row exists in `merchant_balances`, then lock it atomically (`FOR UPDATE`)
  INSERT INTO public.merchant_balances (business_id)
  VALUES (p_business_id)
  ON CONFLICT (business_id) DO NOTHING;

  SELECT available_balance_cents
  INTO v_avail_cents
  FROM public.merchant_balances
  WHERE business_id = p_business_id
  FOR UPDATE;

  IF NOT FOUND OR v_avail_cents < p_amount_cents THEN
    RAISE EXCEPTION 'Baki tidak mencukupi. Baki tersedia: RM %, diminta: RM %.',
      TO_CHAR(COALESCE(v_avail_cents, 0) / 100.0, 'FM999999990.00'),
      TO_CHAR(p_amount_cents / 100.0, 'FM999999990.00');
  END IF;

  v_new_avail_cents := v_avail_cents - p_amount_cents;

  -- 4. Move funds from `available_balance_cents` to `pending_payout_cents`
  UPDATE public.merchant_balances
  SET available_balance_cents = v_new_avail_cents,
      pending_payout_cents = pending_payout_cents + p_amount_cents,
      updated_at = NOW()
  WHERE business_id = p_business_id;

  -- 5. Insert payout request strictly with status 'pending_approval' (Zero Auto-Withdrawal)
  INSERT INTO public.payout_requests (
    business_id,
    requested_by_user_id,
    amount_cents,
    bank_name,
    bank_account_number,
    bank_account_holder,
    status
  ) VALUES (
    p_business_id,
    auth.uid(),
    p_amount_cents,
    v_bank_name,
    v_acc_no,
    COALESCE(v_acc_holder, ''),
    'pending_approval'
  ) RETURNING id INTO v_payout_id;

  -- 6. Record immutable ledger entry
  INSERT INTO public.merchant_ledger_entries (
    business_id,
    entry_type,
    amount_cents,
    balance_after_cents,
    reference_type,
    reference_id,
    description
  ) VALUES (
    p_business_id,
    'payout_hold',
    -p_amount_cents,
    v_new_avail_cents,
    'payout_request',
    v_payout_id::text,
    'Permohonan pengeluaran dana (Menunggu semakan & pindahan manual Super Admin)'
  );

  RETURN jsonb_build_object(
    'success', true,
    'payout_request_id', v_payout_id,
    'status', 'pending_approval',
    'amount_cents', p_amount_cents,
    'remaining_balance_cents', v_new_avail_cents
  );
END;
$$;

REVOKE ALL ON FUNCTION public.request_merchant_payout(UUID, BIGINT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.request_merchant_payout(UUID, BIGINT) TO authenticated;

-- 2.2 Disable direct client-side `top_up_wallet` and `withdraw_wallet` from `authenticated`
--     Top-ups must only be credited by the verified CHIP webhook (`service_role`),
--     and withdrawals must go through `request_merchant_payout`.
REVOKE EXECUTE ON FUNCTION public.top_up_wallet(UUID, DECIMAL) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.withdraw_wallet(UUID, DECIMAL) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.top_up_wallet(UUID, DECIMAL) TO service_role;
GRANT EXECUTE ON FUNCTION public.withdraw_wallet(UUID, DECIMAL) TO service_role;


-- =========================================================================================
-- 3. STRICT SUPABASE ROW LEVEL SECURITY (RLS) & COLUMN-LEVEL PROTECTION TRIGGERS
-- =========================================================================================

ALTER TABLE public.merchant_balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.merchant_ledger_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payout_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.processed_payment_webhooks ENABLE ROW LEVEL SECURITY;

-- 3.1 Revoke direct write privileges on financial ledger/balance tables from `anon` and `authenticated`
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.merchant_balances FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.merchant_ledger_entries FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.payout_requests FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.wallet_transactions FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.business_platform_transactions FROM anon, authenticated;
REVOKE ALL ON public.processed_payment_webhooks FROM anon, authenticated;

-- 3.2 Strict SELECT-only RLS policies for `merchant_balances`, `merchant_ledger_entries`, `payout_requests`
DROP POLICY IF EXISTS "Merchant read own balance" ON public.merchant_balances;
CREATE POLICY "Merchant read own balance"
  ON public.merchant_balances FOR SELECT TO authenticated
  USING (public.is_business_owner(business_id) OR public.is_super_admin());

DROP POLICY IF EXISTS "Merchant read own ledger" ON public.merchant_ledger_entries;
CREATE POLICY "Merchant read own ledger"
  ON public.merchant_ledger_entries FOR SELECT TO authenticated
  USING (public.is_business_owner(business_id) OR public.is_super_admin());

DROP POLICY IF EXISTS "Merchant read own payout requests" ON public.payout_requests;
CREATE POLICY "Merchant read own payout requests"
  ON public.payout_requests FOR SELECT TO authenticated
  USING (public.is_business_owner(business_id) OR public.is_super_admin());

-- 3.3 Guard `users.user_balance` & `users.role` against client-side UPDATE tampering
CREATE OR REPLACE FUNCTION public.guard_user_sensitive_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Only `service_role` or internal SECURITY DEFINER RPCs (where current_user is postgres/supabase_admin) may mutate balance or role
  IF current_setting('request.jwt.claim.role', true) IS DISTINCT FROM 'service_role'
     AND current_user NOT IN ('postgres', 'supabase_admin') THEN
    IF NEW.user_balance IS DISTINCT FROM OLD.user_balance THEN
      RAISE EXCEPTION 'Pelanggaran Keselamatan: Baki dompet tidak boleh diubah secara terus dari klien.';
    END IF;
    IF NEW.role IS DISTINCT FROM OLD.role THEN
      RAISE EXCEPTION 'Pelanggaran Keselamatan: Peranan pengguna tidak boleh diubah secara terus dari klien.';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_user_sensitive_columns ON public.users;
CREATE TRIGGER trg_guard_user_sensitive_columns
  BEFORE UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_user_sensitive_columns();

-- 3.4 Guard `businesses.platform_fee_percent` & `business_subscription_tier` against merchant tampering
CREATE OR REPLACE FUNCTION public.guard_business_financial_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF current_setting('request.jwt.claim.role', true) IS DISTINCT FROM 'service_role'
     AND current_user NOT IN ('postgres', 'supabase_admin')
     AND NOT public.is_super_admin() THEN
    IF NEW.platform_fee_percent IS DISTINCT FROM OLD.platform_fee_percent
       OR NEW.business_subscription_tier IS DISTINCT FROM OLD.business_subscription_tier THEN
      RAISE EXCEPTION 'Pelanggaran Keselamatan: Kadar komisen platform dan pelan langganan hanya boleh diubah oleh Super Admin.';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_business_financial_columns ON public.businesses;
CREATE TRIGGER trg_guard_business_financial_columns
  BEFORE UPDATE ON public.businesses
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_business_financial_columns();

-- 3.5 Harden `guard_order_financial_integrity` on `public.orders`
--     Even when `v_is_merchant = true`, merchants/staff CANNOT manually set `payment_status = 'paid'`
--     on online/CHIP orders or alter calculated order financial columns.
CREATE OR REPLACE FUNCTION public.guard_order_financial_integrity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_merchant BOOLEAN := false;
BEGIN
  -- 1. Allow `service_role` (Verified CHIP Webhook Edge Function) or internal SECURITY DEFINER RPCs
  IF current_setting('request.jwt.claim.role', true) = 'service_role'
     OR current_user IN ('postgres', 'supabase_admin') THEN
    NEW.updated_at := now();
    RETURN NEW;
  END IF;

  -- 2. Block ALL clients (both customers AND merchants/staff) from mutating financial columns after creation
  IF NEW.total IS DISTINCT FROM OLD.total
     OR NEW.total_cents IS DISTINCT FROM OLD.total_cents
     OR NEW.subtotal_cents IS DISTINCT FROM OLD.subtotal_cents
     OR NEW.discount_cents IS DISTINCT FROM OLD.discount_cents
     OR NEW.gateway_fee_cents IS DISTINCT FROM OLD.gateway_fee_cents
     OR NEW.platform_commission_cents IS DISTINCT FROM OLD.platform_commission_cents
     OR NEW.merchant_net_cents IS DISTINCT FROM OLD.merchant_net_cents
     OR NEW.business_id IS DISTINCT FROM OLD.business_id
     OR NEW.chip_purchase_id IS DISTINCT FROM OLD.chip_purchase_id THEN
    RAISE EXCEPTION 'Pelanggaran Integriti Kewangan: Jumlah pesanan, komisen, dan ID transaksi tidak boleh diubah dari klien.';
  END IF;

  -- 3. Block ALL clients (including merchants & staff, even when v_is_merchant = true)
  --    from manually setting `payment_status = 'paid'` on online/CHIP orders!
  IF NEW.payment_status = 'paid' AND OLD.payment_status IS DISTINCT FROM 'paid' THEN
    IF OLD.chip_purchase_id IS NOT NULL
       OR COALESCE(OLD.source, '') <> 'pos'
       OR COALESCE(NEW.payment_method, '') NOT IN ('cash', 'split') THEN
      RAISE EXCEPTION 'Pelanggaran Keselamatan: Status bayaran dalam talian (CHIP) hanya boleh disahkan oleh Webhook CHIP rasmi (service_role).';
    END IF;
  END IF;

  -- 4. Prevent reverting an already 'paid' order's payment_status from the client
  IF OLD.payment_status = 'paid' AND NEW.payment_status IS DISTINCT FROM 'paid' THEN
    RAISE EXCEPTION 'Pelanggaran Keselamatan: Status pesanan yang telah dibayar tidak boleh diubah secara manual dari klien.';
  END IF;

  -- 5. Check if current user is the merchant/staff for operational status updates (e.g., preparing -> ready -> completed)
  SELECT EXISTS (
    SELECT 1 FROM public.businesses b
    WHERE b.id = OLD.business_id
      AND (b.owner_user_id = auth.uid() OR public.is_business_owner_or_staff(OLD.business_id))
  ) INTO v_is_merchant;

  IF NOT v_is_merchant THEN
    -- Customers cannot change payment_status at all
    IF NEW.payment_status IS DISTINCT FROM OLD.payment_status THEN
      RAISE EXCEPTION 'Pelanggaran Keselamatan: Pelanggan tidak dibenarkan mengubah status pembayaran.';
    END IF;

    -- Customers can only cancel an order while it is still 'pending' or 'holding'
    IF NEW.status = 'cancelled' AND OLD.status NOT IN ('pending', 'holding') THEN
      RAISE EXCEPTION 'Pesanan sedang disediakan oleh kedai dan tidak boleh dibatalkan sendiri.';
    END IF;
  END IF;

  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_order_financial_integrity ON public.orders;
CREATE TRIGGER trg_guard_order_financial_integrity
  BEFORE UPDATE ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_order_financial_integrity();


-- =========================================================================================
-- 4. SERVER-SIDE ORDER & FEE CALCULATION RPC (`calculate_and_lock_order_for_chip`)
--    Calculates item prices from DB, validates vouchers, computes platform commission &
--    gateway fees strictly on the backend before CHIP checkout creation.
--    Supports both `orders` (UUID) and `bookings` (UUID or `RZRV-...` reference).
-- =========================================================================================

CREATE OR REPLACE FUNCTION public.calculate_and_lock_order_for_chip(
  p_order_id TEXT,
  p_payment_channel TEXT DEFAULT 'fpx' -- 'fpx', 'duitnow_qr', 'card'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order RECORD;
  v_booking RECORD;
  v_business RECORD;
  v_is_uuid BOOLEAN := false;
  v_order_uuid UUID;
  v_calc_subtotal_cents BIGINT := 0;
  v_discount_cents BIGINT := 0;
  v_discounted_subtotal_cents BIGINT := 0;
  v_gateway_fee_cents BIGINT := 0;
  v_commission_rate NUMERIC(5, 2) := 5.00;
  v_commission_cents BIGINT := 0;
  v_customer_total_cents BIGINT := 0;
  v_merchant_net_cents BIGINT := 0;
BEGIN
  IF p_order_id IS NULL OR TRIM(p_order_id) = '' THEN
    RAISE EXCEPTION 'Order/Booking reference is required.';
  END IF;

  -- Check if p_order_id is a valid UUID
  BEGIN
    v_order_uuid := TRIM(p_order_id)::uuid;
    v_is_uuid := true;
  EXCEPTION WHEN OTHERS THEN
    v_is_uuid := false;
  END;

  -- CASE A: Booking reference starting with 'RZRV-' or matching `bookings` table
  IF p_order_id LIKE 'RZRV-%' THEN
    SELECT * INTO v_booking
    FROM public.bookings
    WHERE booking_metadata->>'booking_id' = p_order_id
    FOR UPDATE;
  ELSIF v_is_uuid THEN
    -- Try locking in `orders` first
    SELECT * INTO v_order
    FROM public.orders
    WHERE id = v_order_uuid
    FOR UPDATE;

    -- If not found in `orders`, check `bookings` by UUID
    IF NOT FOUND THEN
      SELECT * INTO v_booking
      FROM public.bookings
      WHERE id = v_order_uuid
      FOR UPDATE;
    END IF;
  END IF;

  -- Handle Booking calculation if target is a booking
  IF v_booking.id IS NOT NULL THEN
    IF COALESCE(v_booking.booking_metadata->>'payment_status', '') = 'paid' THEN
      RAISE EXCEPTION 'Tempahan ini telah pun dibayar.';
    END IF;

    SELECT id, business_name, COALESCE(platform_fee_percent, 5.0) AS fee_pct
    INTO v_business
    FROM public.businesses
    WHERE id = v_booking.business_id;

    v_calc_subtotal_cents := ROUND(COALESCE(v_booking.total_price, 0) * 100)::bigint;
    v_discounted_subtotal_cents := GREATEST(0, v_calc_subtotal_cents);

    IF v_discounted_subtotal_cents < 1000 THEN
      v_commission_cents := 0;
    ELSE
      v_commission_rate := COALESCE(v_business.fee_pct, 5.00);
      v_commission_cents := ROUND((v_discounted_subtotal_cents * v_commission_rate) / 100.0)::bigint;
    END IF;

    IF LOWER(p_payment_channel) = 'fpx' THEN
      v_gateway_fee_cents := GREATEST(100, ROUND(v_discounted_subtotal_cents * 0.015)::bigint);
    ELSIF LOWER(p_payment_channel) = 'card' THEN
      v_gateway_fee_cents := ROUND(v_discounted_subtotal_cents * 0.024)::bigint;
    ELSE
      v_gateway_fee_cents := GREATEST(20, ROUND(v_discounted_subtotal_cents * 0.010)::bigint);
    END IF;

    v_customer_total_cents := v_discounted_subtotal_cents;
    v_merchant_net_cents := GREATEST(0, v_customer_total_cents - v_commission_cents - v_gateway_fee_cents);

    RETURN jsonb_build_object(
      'target_type', 'booking',
      'order_id', p_order_id,
      'booking_uuid', v_booking.id,
      'business_id', v_booking.business_id,
      'business_name', v_business.business_name,
      'subtotal_cents', v_calc_subtotal_cents,
      'discount_cents', 0,
      'gateway_fee_cents', v_gateway_fee_cents,
      'platform_commission_cents', v_commission_cents,
      'merchant_net_cents', v_merchant_net_cents,
      'total_cents', v_customer_total_cents,
      'total_rm', ROUND((v_customer_total_cents / 100.0)::numeric, 2)
    );
  END IF;

  -- CASE B: Standard Order in `public.orders`
  IF v_order.id IS NULL THEN
    RAISE EXCEPTION 'Pesanan tidak ditemui untuk rujukan: %', p_order_id;
  END IF;

  IF v_order.payment_status = 'paid' THEN
    RAISE EXCEPTION 'Pesanan ini telah pun dibayar.';
  END IF;

  -- Fetch merchant commission configuration from `businesses`
  SELECT id, business_name, COALESCE(platform_fee_percent, 5.0) AS fee_pct
  INTO v_business
  FROM public.businesses
  WHERE id = v_order.business_id;

  -- Recompute subtotal strictly from `order_items` joined with authoritative `business_products` prices
  SELECT COALESCE(SUM(
    ROUND(COALESCE(bp.price, oi.unit_price, 0) * 100)::bigint * GREATEST(oi.quantity, 1)
  ), 0)
  INTO v_calc_subtotal_cents
  FROM public.order_items oi
  LEFT JOIN public.business_products bp ON bp.id = oi.product_id
  WHERE oi.order_id = v_order.id;

  -- Fallback if order has no separate `order_items` rows
  IF v_calc_subtotal_cents <= 0 THEN
    v_calc_subtotal_cents := ROUND(COALESCE(v_order.total, 0) * 100)::bigint;
  END IF;

  v_discount_cents := LEAST(COALESCE(v_order.discount_cents, 0), v_calc_subtotal_cents);
  v_discounted_subtotal_cents := GREATEST(0, v_calc_subtotal_cents - v_discount_cents);

  -- Calculate Gateway Fee & Platform Commission (Under RM 10.00 = 0% platform commission)
  IF v_discounted_subtotal_cents < 1000 THEN
    v_commission_cents := 0;
  ELSE
    v_commission_rate := COALESCE(v_business.fee_pct, 5.00);
    v_commission_cents := ROUND((v_discounted_subtotal_cents * v_commission_rate) / 100.0)::bigint;
  END IF;

  -- Gateway processing fee calculation:
  -- FPX: RM 1.00 (100 sen) minimum or 1.5%, whichever is higher
  -- Card: 2.4%
  -- DuitNow QR: 1.0% (minimum RM 0.20 / 20 sen)
  IF LOWER(p_payment_channel) = 'fpx' THEN
    v_gateway_fee_cents := GREATEST(100, ROUND(v_discounted_subtotal_cents * 0.015)::bigint);
  ELSIF LOWER(p_payment_channel) = 'card' THEN
    v_gateway_fee_cents := ROUND(v_discounted_subtotal_cents * 0.024)::bigint);
  ELSE
    v_gateway_fee_cents := GREATEST(20, ROUND(v_discounted_subtotal_cents * 0.010)::bigint);
  END IF;

  v_customer_total_cents := v_discounted_subtotal_cents;
  v_merchant_net_cents := GREATEST(0, v_customer_total_cents - v_commission_cents - v_gateway_fee_cents);

  -- Persist authoritative server-calculated cents onto `orders`
  UPDATE public.orders
  SET subtotal_cents = v_calc_subtotal_cents,
      discount_cents = v_discount_cents,
      gateway_fee_cents = v_gateway_fee_cents,
      platform_commission_cents = v_commission_cents,
      merchant_net_cents = v_merchant_net_cents,
      total_cents = v_customer_total_cents,
      total = ROUND((v_customer_total_cents / 100.0)::numeric, 2),
      updated_at = NOW()
  WHERE id = v_order.id;

  RETURN jsonb_build_object(
    'target_type', 'order',
    'order_id', v_order.id,
    'business_id', v_order.business_id,
    'business_name', v_business.business_name,
    'subtotal_cents', v_calc_subtotal_cents,
    'discount_cents', v_discount_cents,
    'gateway_fee_cents', v_gateway_fee_cents,
    'platform_commission_cents', v_commission_cents,
    'merchant_net_cents', v_merchant_net_cents,
    'total_cents', v_customer_total_cents,
    'total_rm', ROUND((v_customer_total_cents / 100.0)::numeric, 2)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.calculate_and_lock_order_for_chip(TEXT, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.calculate_and_lock_order_for_chip(TEXT, TEXT) TO service_role;


-- =========================================================================================
-- 5. ATOMIC IDEMPOTENT WEBHOOK SETTLEMENT RPC (`process_verified_chip_webhook`)
--    Executes inside a single locked PostgreSQL transaction:
--      a) Verifies idempotency (`processed_payment_webhooks`)
--      b) Verifies exact integer cents (`p_paid_cents >= expected_cents`)
--      c) Marks order or booking as `'paid'`
--      d) Auto-initializes or updates `merchant_balances` (`INSERT ... ON CONFLICT DO UPDATE`)
--      e) Appends `merchant_ledger_entries` and `business_platform_transactions`
-- =========================================================================================

CREATE OR REPLACE FUNCTION public.process_verified_chip_webhook(
  p_chip_purchase_id TEXT,
  p_event_type TEXT,
  p_reference_id TEXT,
  p_paid_cents BIGINT,
  p_payment_method TEXT,
  p_raw_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order RECORD;
  v_booking RECORD;
  v_is_uuid BOOLEAN := false;
  v_ref_uuid UUID;
  v_expected_cents BIGINT;
  v_net_cents BIGINT;
  v_comm_cents BIGINT;
  v_gateway_cents BIGINT;
  v_new_balance_cents BIGINT;
  v_existing_meta JSONB;
  v_updated_meta JSONB;
BEGIN
  IF p_chip_purchase_id IS NULL OR TRIM(p_chip_purchase_id) = '' THEN
    RAISE EXCEPTION 'Missing chip_purchase_id';
  END IF;

  -- 1. IDEMPOTENCY CHECK: Has this `chip_purchase_id` already been processed?
  IF EXISTS (
    SELECT 1 FROM public.processed_payment_webhooks
    WHERE chip_purchase_id = p_chip_purchase_id
  ) THEN
    RETURN jsonb_build_object(
      'success', true,
      'idempotent_skip', true,
      'message', 'Webhook already processed for purchase ' || p_chip_purchase_id
    );
  END IF;

  BEGIN
    v_ref_uuid := TRIM(p_reference_id)::uuid;
    v_is_uuid := true;
  EXCEPTION WHEN OTHERS THEN
    v_is_uuid := false;
  END;

  -- 2. Locate & lock target in `orders` or `bookings`
  IF p_reference_id LIKE 'RZRV-%' THEN
    SELECT * INTO v_booking
    FROM public.bookings
    WHERE booking_metadata->>'booking_id' = p_reference_id
    FOR UPDATE;
  ELSIF v_is_uuid THEN
    SELECT * INTO v_order
    FROM public.orders
    WHERE id = v_ref_uuid
    FOR UPDATE;

    IF NOT FOUND THEN
      SELECT * INTO v_booking
      FROM public.bookings
      WHERE id = v_ref_uuid
      FOR UPDATE;
    END IF;
  END IF;

  -- =====================================================================================
  -- BRANCH A: BOOKING SETTLEMENT
  -- =====================================================================================
  IF v_booking.id IS NOT NULL THEN
    v_existing_meta := CASE
      WHEN v_booking.booking_metadata IS NOT NULL AND jsonb_typeof(v_booking.booking_metadata) = 'object'
      THEN v_booking.booking_metadata
      ELSE '{}'::jsonb
    END;

    IF COALESCE(v_existing_meta->>'payment_status', '') = 'paid' THEN
      RETURN jsonb_build_object(
        'success', true,
        'idempotent_skip', true,
        'type', 'booking',
        'id', v_booking.id,
        'message', 'Booking already marked as paid'
      );
    END IF;

    v_expected_cents := ROUND(COALESCE(v_booking.total_price, 0) * 100)::bigint;
    IF p_paid_cents IS NULL OR p_paid_cents <= 0 OR p_paid_cents < v_expected_cents THEN
      RAISE EXCEPTION 'Amount mismatch for booking %: expected % cents, received % cents',
        v_booking.id, v_expected_cents, COALESCE(p_paid_cents, 0);
    END IF;

    v_comm_cents := CASE WHEN p_paid_cents < 1000 THEN 0 ELSE ROUND(p_paid_cents * 0.05)::bigint END;
    v_gateway_cents := GREATEST(20, ROUND(p_paid_cents * 0.015)::bigint);
    v_net_cents := GREATEST(0, p_paid_cents - v_comm_cents - v_gateway_cents);

    INSERT INTO public.processed_payment_webhooks (
      chip_purchase_id, event_type, target_type, target_id, paid_cents, raw_payload
    ) VALUES (
      p_chip_purchase_id, COALESCE(p_event_type, 'purchase.paid'), 'booking',
      v_booking.id::text, p_paid_cents, COALESCE(p_raw_payload, '{}'::jsonb)
    );

    v_updated_meta := v_existing_meta || jsonb_build_object(
      'payment_status', 'paid',
      'payment_method', COALESCE(p_payment_method, 'chip_online'),
      'transaction_ref', p_chip_purchase_id,
      'verified_by_webhook', true,
      'paid_cents', p_paid_cents,
      'paid_at', NOW()
    );

    UPDATE public.bookings
    SET booking_metadata = v_updated_meta
    WHERE id = v_booking.id;

    -- Auto-initialize or atomically credit `merchant_balances`
    INSERT INTO public.merchant_balances (
      business_id, available_balance_cents, lifetime_gross_cents, lifetime_net_cents, updated_at
    ) VALUES (
      v_booking.business_id, v_net_cents, p_paid_cents, v_net_cents, NOW()
    )
    ON CONFLICT (business_id) DO UPDATE
    SET available_balance_cents = public.merchant_balances.available_balance_cents + EXCLUDED.available_balance_cents,
        lifetime_gross_cents    = public.merchant_balances.lifetime_gross_cents + EXCLUDED.lifetime_gross_cents,
        lifetime_net_cents      = public.merchant_balances.lifetime_net_cents + EXCLUDED.lifetime_net_cents,
        updated_at              = NOW()
    RETURNING available_balance_cents INTO v_new_balance_cents;

    INSERT INTO public.merchant_ledger_entries (
      business_id, entry_type, amount_cents, balance_after_cents,
      reference_type, reference_id, chip_purchase_id, description, metadata
    ) VALUES (
      v_booking.business_id, 'sale_credit', v_net_cents, v_new_balance_cents,
      'booking', v_booking.id::text, p_chip_purchase_id,
      'Kredit tempahan servis bersih daripada CHIP (' || COALESCE(p_payment_method, 'online') || ')',
      jsonb_build_object(
        'gross_cents', p_paid_cents,
        'platform_commission_cents', v_comm_cents,
        'gateway_fee_cents', v_gateway_cents,
        'net_cents', v_net_cents
      )
    );

    INSERT INTO public.business_platform_transactions (
      business_id, customer_id, booking_id, amount, currency, platform_fee_amount, status
    ) VALUES (
      v_booking.business_id, v_booking.customer_id, v_booking.id,
      ROUND((p_paid_cents / 100.0)::numeric, 2), 'MYR',
      ROUND((v_comm_cents / 100.0)::numeric, 2), 'completed'
    );

    RETURN jsonb_build_object(
      'success', true,
      'idempotent_skip', false,
      'type', 'booking',
      'id', v_booking.id,
      'payment_status', 'paid',
      'paid_cents', p_paid_cents,
      'merchant_net_cents', v_net_cents,
      'new_available_balance_cents', v_new_balance_cents
    );
  END IF;

  -- =====================================================================================
  -- BRANCH B: ORDER SETTLEMENT
  -- =====================================================================================
  IF v_order.id IS NULL THEN
    RAISE EXCEPTION 'Order or Booking not found for reference: %', p_reference_id;
  END IF;

  IF v_order.payment_status = 'paid' THEN
    RETURN jsonb_build_object(
      'success', true,
      'idempotent_skip', true,
      'type', 'order',
      'id', v_order.id,
      'message', 'Order already marked as paid: ' || p_reference_id
    );
  END IF;

  -- 3. STRICT SERVER-SIDE INTEGER CENTS VALIDATION
  v_expected_cents := CASE
    WHEN COALESCE(v_order.total_cents, 0) > 0 THEN v_order.total_cents
    ELSE ROUND(COALESCE(v_order.total, 0) * 100)::bigint
  END;

  IF p_paid_cents IS NULL OR p_paid_cents <= 0 OR p_paid_cents < v_expected_cents THEN
    RAISE EXCEPTION 'Amount mismatch for order %: expected % cents, received % cents',
      v_order.id, v_expected_cents, COALESCE(p_paid_cents, 0);
  END IF;

  v_comm_cents := COALESCE(v_order.platform_commission_cents, 0);
  v_gateway_cents := COALESCE(v_order.gateway_fee_cents, 0);
  v_net_cents := CASE
    WHEN COALESCE(v_order.merchant_net_cents, 0) > 0 THEN v_order.merchant_net_cents
    ELSE GREATEST(0, p_paid_cents - v_comm_cents - v_gateway_cents)
  END;

  -- 4. Record webhook in idempotency table FIRST (Unique PK guarantees single execution)
  INSERT INTO public.processed_payment_webhooks (
    chip_purchase_id,
    event_type,
    target_type,
    target_id,
    paid_cents,
    raw_payload
  ) VALUES (
    p_chip_purchase_id,
    COALESCE(p_event_type, 'purchase.paid'),
    'order',
    v_order.id::text,
    p_paid_cents,
    COALESCE(p_raw_payload, '{}'::jsonb)
  );

  -- 5. Update order status to 'paid'
  UPDATE public.orders
  SET payment_status = 'paid',
      payment_method = COALESCE(p_payment_method, 'chip_online'),
      payment_ref = p_chip_purchase_id,
      chip_purchase_id = p_chip_purchase_id,
      paid_at = NOW(),
      updated_at = NOW()
  WHERE id = v_order.id;

  -- 6. Auto-initialize or atomically credit `merchant_balances` (`INSERT ... ON CONFLICT DO UPDATE`)
  INSERT INTO public.merchant_balances (
    business_id,
    available_balance_cents,
    lifetime_gross_cents,
    lifetime_net_cents,
    updated_at
  ) VALUES (
    v_order.business_id,
    v_net_cents,
    p_paid_cents,
    v_net_cents,
    NOW()
  )
  ON CONFLICT (business_id) DO UPDATE
  SET available_balance_cents = public.merchant_balances.available_balance_cents + EXCLUDED.available_balance_cents,
      lifetime_gross_cents    = public.merchant_balances.lifetime_gross_cents + EXCLUDED.lifetime_gross_cents,
      lifetime_net_cents      = public.merchant_balances.lifetime_net_cents + EXCLUDED.lifetime_net_cents,
      updated_at              = NOW()
  RETURNING available_balance_cents INTO v_new_balance_cents;

  -- 7. Insert immutable ledger credit entry
  INSERT INTO public.merchant_ledger_entries (
    business_id,
    entry_type,
    amount_cents,
    balance_after_cents,
    reference_type,
    reference_id,
    chip_purchase_id,
    description,
    metadata
  ) VALUES (
    v_order.business_id,
    'sale_credit',
    v_net_cents,
    v_new_balance_cents,
    'order',
    v_order.id::text,
    p_chip_purchase_id,
    'Kredit jualan bersih daripada CHIP (' || COALESCE(p_payment_method, 'online') || ')',
    jsonb_build_object(
      'gross_cents', p_paid_cents,
      'platform_commission_cents', v_comm_cents,
      'gateway_fee_cents', v_gateway_cents,
      'net_cents', v_net_cents
    )
  );

  -- 8. Record platform fee in `business_platform_transactions`
  INSERT INTO public.business_platform_transactions (
    business_id,
    customer_id,
    order_id,
    amount,
    currency,
    platform_fee_amount,
    status
  ) VALUES (
    v_order.business_id,
    v_order.customer_id,
    v_order.id,
    ROUND((p_paid_cents / 100.0)::numeric, 2),
    'MYR',
    ROUND((v_comm_cents / 100.0)::numeric, 2),
    'completed'
  );

  RETURN jsonb_build_object(
    'success', true,
    'idempotent_skip', false,
    'type', 'order',
    'id', v_order.id,
    'payment_status', 'paid',
    'paid_cents', p_paid_cents,
    'merchant_net_cents', v_net_cents,
    'new_available_balance_cents', v_new_balance_cents
  );
END;
$$;

REVOKE ALL ON FUNCTION public.process_verified_chip_webhook(TEXT, TEXT, TEXT, BIGINT, TEXT, JSONB) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_verified_chip_webhook(TEXT, TEXT, TEXT, BIGINT, TEXT, JSONB) TO service_role;

COMMIT;

NOTIFY pgrst, 'reload schema';
