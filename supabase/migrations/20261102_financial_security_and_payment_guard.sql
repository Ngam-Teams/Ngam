-- =========================================================================================
-- NGAM ECOSYSTEM: FINANCIAL SECURITY, RLS HARDENING & ATOMIC VOUCHER/STOCK RPC (2026-11-02)
-- Run in: Supabase Dashboard -> SQL Editor
-- =========================================================================================

-- 1. Pastikan jadual orders mempunyai semua kolum kewangan & audit yang diperlukan
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS payment_status TEXT DEFAULT 'unpaid',
  ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'cash',
  ADD COLUMN IF NOT EXISTS payment_splits JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS payment_ref TEXT,
  ADD COLUMN IF NOT EXISTS paid_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- 2. Pastikan jadual bookings mempunyai kolum total_price untuk kiraan hasil tepat
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS total_price NUMERIC(12, 2) DEFAULT 0.00;

-- 3. Kekangan (Constraint) keselamatan nilai kewangan supaya tiada pesanan/baucar bernilai negatif
DO $$
BEGIN
  ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_total_non_negative;
  ALTER TABLE public.orders
    ADD CONSTRAINT orders_total_non_negative CHECK (total >= 0);
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE public.vouchers DROP CONSTRAINT IF EXISTS vouchers_discount_non_negative;
  ALTER TABLE public.vouchers
    ADD CONSTRAINT vouchers_discount_non_negative CHECK (discount_value >= 0 AND min_spend >= 0);
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- =========================================================================================
-- 4. ATOMIC SERVER-SIDE VOUCHER VALIDATION RPC (validate_voucher_discount)
--    Menyemak kesahan baucar, tarikh mula/luput, belanja minimum, kuota keseluruhan,
--    dan had penebusan setiap pengguna secara atomik di peringkat pangkalan data.
-- =========================================================================================
CREATE OR REPLACE FUNCTION public.validate_voucher_discount(
  p_business_id UUID,
  p_code TEXT,
  p_subtotal NUMERIC,
  p_user_id UUID DEFAULT NULL,
  p_customer_phone TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row RECORD;
  v_user_uses INT := 0;
  v_discount NUMERIC := 0;
  v_final NUMERIC := 0;
BEGIN
  IF p_subtotal IS NULL OR p_subtotal <= 0 THEN
    RETURN jsonb_build_object('valid', false, 'message', 'Jumlah pesanan tidak sah.');
  END IF;

  SELECT *
  INTO v_row
  FROM public.vouchers
  WHERE UPPER(TRIM(code)) = UPPER(TRIM(p_code))
    AND (business_id = p_business_id OR business_id IS NULL)
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('valid', false, 'message', 'Kod baucar tidak wujud atau tidak sah untuk kedai ini.');
  END IF;

  IF v_row.is_active IS DISTINCT FROM true THEN
    RETURN jsonb_build_object('valid', false, 'message', 'Baucar ini telah dinyahaktifkan.');
  END IF;

  IF v_row.start_date IS NOT NULL AND v_row.start_date > now() THEN
    RETURN jsonb_build_object('valid', false, 'message', 'Tempoh promosi baucar ini belum bermula.');
  END IF;

  IF v_row.end_date IS NOT NULL AND v_row.end_date < now() THEN
    RETURN jsonb_build_object('valid', false, 'message', 'Baucar ini telah tamat tempoh.');
  END IF;

  IF v_row.total_usage_limit IS NOT NULL AND v_row.total_usage_limit > 0
     AND COALESCE(v_row.times_used, 0) >= v_row.total_usage_limit THEN
    RETURN jsonb_build_object('valid', false, 'message', 'Kuota penebusan baucar ini telah habis.');
  END IF;

  IF p_subtotal < COALESCE(v_row.min_spend, 0) THEN
    RETURN jsonb_build_object(
      'valid', false,
      'message', 'Belanja minimum RM ' || TO_CHAR(v_row.min_spend, 'FM999990.00') || ' diperlukan.'
    );
  END IF;

  -- Semak had penebusan per pelanggan (berdasarkan user_id atau customer_phone)
  IF COALESCE(v_row.usage_limit_per_user, 0) > 0 AND (p_user_id IS NOT NULL OR (p_customer_phone IS NOT NULL AND LENGTH(TRIM(p_customer_phone)) > 0)) THEN
    SELECT COUNT(*)
    INTO v_user_uses
    FROM public.voucher_usages vu
    WHERE vu.voucher_id = v_row.id
      AND (
        (p_user_id IS NOT NULL AND vu.user_id = p_user_id)
        OR (p_customer_phone IS NOT NULL AND LENGTH(TRIM(p_customer_phone)) > 0 AND vu.customer_phone = TRIM(p_customer_phone))
      );

    IF v_user_uses >= v_row.usage_limit_per_user THEN
      RETURN jsonb_build_object('valid', false, 'message', 'Anda telah mencapai had penebusan untuk baucar ini.');
    END IF;
  END IF;

  -- Kira nilai diskaun
  IF LOWER(COALESCE(v_row.discount_type, 'fixed')) = 'percentage' THEN
    v_discount := ROUND((p_subtotal * COALESCE(v_row.discount_value, 0) / 100.0)::numeric, 2);
    IF v_row.max_discount_amount IS NOT NULL AND v_row.max_discount_amount > 0 AND v_discount > v_row.max_discount_amount THEN
      v_discount := v_row.max_discount_amount;
    END IF;
  ELSIF LOWER(COALESCE(v_row.discount_type, '')) = 'free_item' THEN
    v_discount := 0;
  ELSE
    v_discount := COALESCE(v_row.discount_value, 0);
  END IF;

  IF v_discount > p_subtotal THEN
    v_discount := p_subtotal;
  END IF;

  v_final := GREATEST(0, p_subtotal - v_discount);

  RETURN jsonb_build_object(
    'valid', true,
    'voucher_id', v_row.id,
    'code', v_row.code,
    'title', v_row.title,
    'discount_type', v_row.discount_type,
    'discount_amount', v_discount,
    'final_total', v_final,
    'is_free_item', LOWER(COALESCE(v_row.discount_type, '')) = 'free_item',
    'message', 'Baucar ' || v_row.code || ' sah digunakan!'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.validate_voucher_discount(UUID, TEXT, NUMERIC, UUID, TEXT) TO anon, authenticated;

-- =========================================================================================
-- 5. TRIGGER PERLINDUNGAN INTEGRITI KEWANGAN ORDERS (prevent_illegal_order_mutation)
--    Menghalang pelanggan biasa (bukan pemilik perniagaan & bukan service_role) daripada:
--      a) Mengubah jumlah `total` atau `business_id` selepas pesanan dibuat
--      b) Membatalkan pesanan yang sudah berstatus 'preparing', 'ready', atau 'completed'
-- =========================================================================================
CREATE OR REPLACE FUNCTION public.guard_order_financial_integrity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_merchant BOOLEAN := false;
BEGIN
  -- Benarkan service_role (Edge Functions / Webhook Bank) melakukan sebarang kemas kini sah
  IF current_setting('request.jwt.claim.role', true) = 'service_role' THEN
    RETURN NEW;
  END IF;

  -- Semak sama ada pengguna semasa ialah pemilik perniagaan bagi pesanan ini
  SELECT EXISTS (
    SELECT 1 FROM public.businesses b
    WHERE b.id = OLD.business_id
      AND (b.owner_id = auth.uid() OR b.id = auth.uid())
  ) INTO v_is_merchant;

  -- Jika BUKAN peniaga (iaitu pelanggan biasa):
  IF NOT v_is_merchant THEN
    -- 1. Pelanggan tidak boleh mengubah nilai total atau business_id pesanan
    IF NEW.total IS DISTINCT FROM OLD.total OR NEW.business_id IS DISTINCT FROM OLD.business_id THEN
      RAISE EXCEPTION 'Tidak dibenarkan mengubah jumlah harga pesanan selepas dihantar.';
    END IF;

    -- 2. Pelanggan hanya boleh membatalkan pesanan ketika status masih 'pending'
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
-- 6. SECURE WALLET TOP-UP & WITHDRAWAL HARDENING
--    Menghalang pengguna daripada memanggil top_up_wallet atau withdraw_wallet untuk
--    user_id orang lain atau memasukkan nilai negatif.
-- =========================================================================================
CREATE OR REPLACE FUNCTION public.top_up_wallet(
  p_user_id UUID,
  p_amount DECIMAL
) RETURNS json AS $$
DECLARE
  new_balance DECIMAL;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Amaun tambah nilai mestilah lebih besar daripada RM 0.00';
  END IF;

  IF current_setting('request.jwt.claim.role', true) <> 'service_role' AND auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Akses ditolak: Tidak dibenarkan mengubah dompet pengguna lain.';
  END IF;

  UPDATE public.users
  SET user_balance = COALESCE(user_balance, 0) + p_amount
  WHERE id = p_user_id
  RETURNING user_balance INTO new_balance;

  INSERT INTO public.transactions (user_id, type, amount)
  VALUES (p_user_id, 'topup', p_amount);

  RETURN json_build_object('success', true, 'new_balance', new_balance);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.withdraw_wallet(
  p_user_id UUID,
  p_amount DECIMAL
) RETURNS json AS $$
DECLARE
  current_balance DECIMAL;
  new_balance DECIMAL;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Amaun pengeluaran mestilah lebih besar daripada RM 0.00';
  END IF;

  IF current_setting('request.jwt.claim.role', true) <> 'service_role' AND auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Akses ditolak: Tidak dibenarkan mengeluarkan dana daripada dompet pengguna lain.';
  END IF;

  SELECT COALESCE(user_balance, 0) INTO current_balance FROM public.users WHERE id = p_user_id FOR UPDATE;

  IF current_balance < p_amount THEN
    RAISE EXCEPTION 'Baki tidak mencukupi. Baki semasa: RM%, diperlukan: RM%.', current_balance, p_amount;
  END IF;

  UPDATE public.users
  SET user_balance = current_balance - p_amount
  WHERE id = p_user_id
  RETURNING user_balance INTO new_balance;

  INSERT INTO public.transactions (user_id, type, amount)
  VALUES (p_user_id, 'withdrawal', -p_amount);

  RETURN json_build_object('success', true, 'new_balance', new_balance);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

NOTIFY pgrst, 'reload schema';
