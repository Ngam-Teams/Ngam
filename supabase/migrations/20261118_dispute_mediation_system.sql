-- =========================================================================================
-- NGAM ECOSYSTEM: SHOPEE-STYLE DISPUTE RESOLUTION & 3-WAY MEDIATION SYSTEM ("PEMERHATI & PENENTU")
-- Date: 2026-11-18
-- Systems: Ngam (Customer) | Ngam Business (Merchant) | Ngam Admin (Observer & Adjudicator)
-- Idempotent migration: safe to run multiple times in Supabase SQL Editor.
-- =========================================================================================

BEGIN;

-- 1. Ensure `orders.status` allows 'preparing', 'in_progress', 'ready', 'disputed', 'refunded'
DO $$
DECLARE
  v_con RECORD;
BEGIN
  FOR v_con IN
    SELECT conname
    FROM pg_constraint
    WHERE conrelid = 'public.orders'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) ILIKE '%status%'
  LOOP
    EXECUTE format('ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS %I', v_con.conname);
  END LOOP;

  ALTER TABLE public.orders
    ADD CONSTRAINT orders_status_check
    CHECK (status IN ('pending', 'preparing', 'in_progress', 'ready', 'completed', 'cancelled', 'disputed', 'refunded'));
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

-- 2. Main `public.disputes` Table (Supports both Product Orders & Service Bookings)
CREATE TABLE IF NOT EXISTS public.disputes (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_number              TEXT NOT NULL UNIQUE,
  target_type              TEXT NOT NULL CHECK (target_type IN ('order', 'booking')),
  order_id                 UUID NULL REFERENCES public.orders(id) ON DELETE SET NULL,
  booking_id               UUID NULL REFERENCES public.bookings(id) ON DELETE SET NULL,
  booking_ref              TEXT NULL,
  business_id              UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  customer_id              UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  conversation_id          UUID NULL REFERENCES public.conversations(id) ON DELETE SET NULL,
  customer_name            TEXT,
  business_name            TEXT,
  item_summary             TEXT,
  reason_code              TEXT NOT NULL,
  reason_text              TEXT NOT NULL,
  total_amount             NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (total_amount >= 0),
  requested_refund_amount  NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (requested_refund_amount >= 0),
  approved_refund_amount   NUMERIC(12, 2) NULL CHECK (approved_refund_amount >= 0),
  merchant_release_amount  NUMERIC(12, 2) NULL CHECK (merchant_release_amount >= 0),
  customer_evidence_urls   JSONB NOT NULL DEFAULT '[]'::jsonb,
  business_evidence_urls   JSONB NOT NULL DEFAULT '[]'::jsonb,
  business_response_text   TEXT NULL,
  business_responded_at    TIMESTAMPTZ NULL,
  status                   TEXT NOT NULL DEFAULT 'open' CHECK (
    status IN (
      'open',
      'business_responded',
      'escalated',
      'under_review',
      'resolved_refund_full',
      'resolved_refund_partial',
      'resolved_release_business',
      'withdrawn'
    )
  ),
  resolution_type          TEXT NULL CHECK (
    resolution_type IS NULL OR resolution_type IN (
      'refund_full',
      'refund_partial',
      'release_business',
      'merchant_agreed_refund',
      'customer_withdrawn'
    )
  ),
  escalated_by             UUID NULL,
  escalated_at             TIMESTAMPTZ NULL,
  moderator_id             UUID NULL,
  moderator_note           TEXT NULL,
  response_deadline_at     TIMESTAMPTZ NULL,
  resolved_at              TIMESTAMPTZ NULL,
  created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_disputes_customer_created ON public.disputes (customer_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_disputes_business_created ON public.disputes (business_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_disputes_status_created ON public.disputes (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_disputes_order_id ON public.disputes (order_id) WHERE order_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_disputes_booking_id ON public.disputes (booking_id) WHERE booking_id IS NOT NULL;

-- Prevent multiple simultaneous active disputes on the exact same order or booking
CREATE UNIQUE INDEX IF NOT EXISTS uq_active_dispute_per_order
  ON public.disputes (order_id)
  WHERE order_id IS NOT NULL AND status IN ('open', 'business_responded', 'escalated', 'under_review');

CREATE UNIQUE INDEX IF NOT EXISTS uq_active_dispute_per_booking
  ON public.disputes (booking_id)
  WHERE booking_id IS NOT NULL AND status IN ('open', 'business_responded', 'escalated', 'under_review');

-- Auto-touch updated_at
CREATE OR REPLACE FUNCTION public.fn_touch_disputes_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_disputes_updated_at ON public.disputes;
CREATE TRIGGER trg_disputes_updated_at
  BEFORE UPDATE ON public.disputes
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_touch_disputes_updated_at();

-- 3. `public.dispute_messages` Table (3-Way Mediation Room: Customer + Business + Moderator + System)
CREATE TABLE IF NOT EXISTS public.dispute_messages (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  dispute_id   UUID NOT NULL REFERENCES public.disputes(id) ON DELETE CASCADE,
  sender_id    UUID NULL,
  sender_role  TEXT NOT NULL CHECK (sender_role IN ('customer', 'business', 'moderator', 'system')),
  sender_name  TEXT NOT NULL DEFAULT 'Pengguna Ngam',
  message      TEXT NOT NULL,
  attachments  JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_dispute_messages_dispute_created
  ON public.dispute_messages (dispute_id, created_at ASC);

-- 4. Row Level Security (RLS) for `disputes`, `dispute_messages`, and Admin Observer Access
ALTER TABLE public.disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dispute_messages ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  DROP POLICY IF EXISTS "Disputes participant & admin select" ON public.disputes;
  DROP POLICY IF EXISTS "Customer insert own dispute" ON public.disputes;
  DROP POLICY IF EXISTS "Customer withdraw own dispute" ON public.disputes;
  DROP POLICY IF EXISTS "Business staff update dispute" ON public.disputes;
  DROP POLICY IF EXISTS "Super admin manage all disputes" ON public.disputes;

  DROP POLICY IF EXISTS "Dispute messages participant & admin select" ON public.dispute_messages;
  DROP POLICY IF EXISTS "Dispute messages participant insert" ON public.dispute_messages;

  DROP POLICY IF EXISTS "Super admin observe conversations" ON public.conversations;
  DROP POLICY IF EXISTS "Super admin observe messages" ON public.messages;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

CREATE POLICY "Disputes participant & admin select"
  ON public.disputes FOR SELECT TO authenticated
  USING (
    customer_id = auth.uid()
    OR public.is_active_staff_of(business_id)
    OR EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = business_id AND b.owner_user_id = auth.uid())
    OR public.is_super_admin()
  );

CREATE POLICY "Customer insert own dispute"
  ON public.disputes FOR INSERT TO authenticated
  WITH CHECK (
    customer_id = auth.uid()
  );

CREATE POLICY "Customer withdraw own dispute"
  ON public.disputes FOR UPDATE TO authenticated
  USING (customer_id = auth.uid())
  WITH CHECK (customer_id = auth.uid());

CREATE POLICY "Business staff update dispute"
  ON public.disputes FOR UPDATE TO authenticated
  USING (
    public.is_active_staff_of(business_id)
    OR EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = business_id AND b.owner_user_id = auth.uid())
  )
  WITH CHECK (
    public.is_active_staff_of(business_id)
    OR EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = business_id AND b.owner_user_id = auth.uid())
  );

CREATE POLICY "Super admin manage all disputes"
  ON public.disputes FOR ALL TO authenticated
  USING (public.is_super_admin())
  WITH CHECK (public.is_super_admin());

CREATE POLICY "Dispute messages participant & admin select"
  ON public.dispute_messages FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.disputes d
      WHERE d.id = dispute_messages.dispute_id
        AND (
          d.customer_id = auth.uid()
          OR public.is_active_staff_of(d.business_id)
          OR EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = d.business_id AND b.owner_user_id = auth.uid())
          OR public.is_super_admin()
        )
    )
  );

CREATE POLICY "Dispute messages participant insert"
  ON public.dispute_messages FOR INSERT TO authenticated
  WITH CHECK (
    (sender_id IS NULL OR sender_id = auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.disputes d
      WHERE d.id = dispute_messages.dispute_id
        AND (
          (d.customer_id = auth.uid() AND sender_role = 'customer')
          OR ((public.is_active_staff_of(d.business_id) OR EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = d.business_id AND b.owner_user_id = auth.uid())) AND sender_role = 'business')
          OR (public.is_super_admin() AND sender_role IN ('moderator', 'system'))
        )
    )
  );

-- Observer Mode: Allow Super Admin to inspect original Customer <-> Business chats
CREATE POLICY "Super admin observe conversations"
  ON public.conversations FOR SELECT TO authenticated
  USING (public.is_super_admin());

CREATE POLICY "Super admin observe messages"
  ON public.messages FOR SELECT TO authenticated
  USING (public.is_super_admin());

GRANT SELECT, INSERT, UPDATE ON public.disputes TO authenticated;
GRANT SELECT, INSERT ON public.dispute_messages TO authenticated;

-- 5. RPC: Open Dispute Case (`open_dispute_case`)
CREATE OR REPLACE FUNCTION public.open_dispute_case(
  p_target_type             TEXT,
  p_order_id                UUID DEFAULT NULL,
  p_booking_id              UUID DEFAULT NULL,
  p_booking_ref             TEXT DEFAULT NULL,
  p_business_id             UUID DEFAULT NULL,
  p_reason_code             TEXT DEFAULT 'other',
  p_reason_text             TEXT DEFAULT '',
  p_requested_refund_amount NUMERIC DEFAULT NULL,
  p_evidence_urls           JSONB DEFAULT '[]'::jsonb,
  p_item_summary            TEXT DEFAULT NULL
)
RETURNS public.disputes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_customer_id   UUID := auth.uid();
  v_business_id   UUID := p_business_id;
  v_order         RECORD;
  v_booking       RECORD;
  v_existing      public.disputes;
  v_conv_id       UUID;
  v_total_amt     NUMERIC(12, 2) := 0.00;
  v_req_refund    NUMERIC(12, 2) := 0.00;
  v_cust_name     TEXT;
  v_biz_name      TEXT;
  v_owner_id      UUID;
  v_case_no       TEXT;
  v_dispute       public.disputes;
  v_meta          JSONB;
BEGIN
  IF v_customer_id IS NULL THEN
    RAISE EXCEPTION 'Log masuk diperlukan untuk memfailkan pertikaian.';
  END IF;

  IF TRIM(COALESCE(p_reason_text, '')) = '' THEN
    RAISE EXCEPTION 'Sila nyatakan sebab pertikaian dengan jelas.';
  END IF;

  PERFORM public.ensure_user_in_public_users(v_customer_id);
  SELECT COALESCE(NULLIF(TRIM(user_name), ''), user_email, 'Pelanggan Ngam')
  INTO v_cust_name
  FROM public.users WHERE id = v_customer_id;

  IF p_target_type = 'order' THEN
    IF p_order_id IS NULL THEN
      RAISE EXCEPTION 'ID pesanan diperlukan.';
    END IF;
    SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Pesanan tidak ditemui.';
    END IF;
    IF NULLIF(to_jsonb(v_order)->>'owner_user_id', '') IS DISTINCT FROM v_customer_id::TEXT
       AND NULLIF(to_jsonb(v_order)->>'customer_id', '') IS DISTINCT FROM v_customer_id::TEXT
       AND NOT public.is_super_admin() THEN
      RAISE EXCEPTION 'Akses ditolak: Ini bukan pesanan anda.';
    END IF;
    SELECT * INTO v_existing FROM public.disputes
    WHERE order_id = p_order_id
      AND status IN ('open', 'business_responded', 'escalated', 'under_review')
    LIMIT 1;
    IF FOUND THEN
      RETURN v_existing;
    END IF;
    v_business_id := v_order.business_id;
    v_total_amt := GREATEST(0, COALESCE(v_order.total, 0));

    UPDATE public.orders
    SET status = 'disputed'
    WHERE id = p_order_id;
  ELSIF p_target_type = 'booking' THEN
    IF p_booking_id IS NOT NULL THEN
      SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
    ELSIF p_booking_ref IS NOT NULL AND p_booking_ref <> '' THEN
      SELECT * INTO v_booking FROM public.bookings WHERE booking_metadata->>'booking_id' = p_booking_ref FOR UPDATE;
    END IF;

    IF v_booking.id IS NOT NULL THEN
      IF v_booking.customer_id IS DISTINCT FROM v_customer_id
         AND NULLIF(v_booking.booking_metadata->>'customer_auth_id', '') IS DISTINCT FROM v_customer_id::TEXT
         AND NOT public.is_super_admin() THEN
        RAISE EXCEPTION 'Akses ditolak: Ini bukan tempahan anda.';
      END IF;
      SELECT * INTO v_existing FROM public.disputes
      WHERE booking_id = v_booking.id
        AND status IN ('open', 'business_responded', 'escalated', 'under_review')
      LIMIT 1;
      IF FOUND THEN
        RETURN v_existing;
      END IF;
      v_business_id := v_booking.business_id;
      v_total_amt := GREATEST(0, COALESCE(v_booking.total_price, 0));
      v_meta := CASE
        WHEN v_booking.booking_metadata IS NOT NULL AND jsonb_typeof(v_booking.booking_metadata) = 'object'
        THEN v_booking.booking_metadata
        ELSE '{}'::jsonb
      END;
      UPDATE public.bookings
      SET status = 'disputed',
          booking_metadata = v_meta || jsonb_build_object(
            'is_disputed', true,
            'dispute_type', p_reason_code,
            'dispute_reason', p_reason_text,
            'dispute_date', NOW()
          )
      WHERE id = v_booking.id;
    END IF;
  ELSE
    RAISE EXCEPTION 'Jenis pertikaian tidak sah: %', p_target_type;
  END IF;

  IF v_business_id IS NULL THEN
    RAISE EXCEPTION 'ID perniagaan diperlukan.';
  END IF;

  SELECT business_name, owner_user_id INTO v_biz_name, v_owner_id
  FROM public.businesses WHERE id = v_business_id;

  IF v_owner_id IS NOT NULL THEN
    PERFORM public.ensure_user_in_public_users(v_owner_id);
  END IF;

  v_req_refund := LEAST(
    GREATEST(COALESCE(p_requested_refund_amount, v_total_amt), 0),
    GREATEST(v_total_amt, COALESCE(p_requested_refund_amount, 0))
  );

  -- Link Customer <-> Business conversation (using real user1_id / user2_id columns) so Admin Mediator can inspect original chat logs
  SELECT c.id INTO v_conv_id
  FROM public.conversations c
  WHERE (
    (c.user1_id = v_customer_id AND (c.user2_id = v_owner_id OR EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.business_id = v_business_id AND tm.user_id = c.user2_id)))
    OR
    (c.user2_id = v_customer_id AND (c.user1_id = v_owner_id OR EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.business_id = v_business_id AND tm.user_id = c.user1_id)))
  )
  ORDER BY c.updated_at DESC
  LIMIT 1;

  IF v_conv_id IS NULL AND v_owner_id IS NOT NULL AND v_owner_id <> v_customer_id THEN
    INSERT INTO public.conversations (
      user1_id, user2_id, updated_at
    ) VALUES (
      v_customer_id,
      v_owner_id,
      NOW()
    )
    ON CONFLICT DO NOTHING
    RETURNING id INTO v_conv_id;

    IF v_conv_id IS NULL THEN
      SELECT id INTO v_conv_id
      FROM public.conversations
      WHERE (user1_id = v_customer_id AND user2_id = v_owner_id)
         OR (user1_id = v_owner_id AND user2_id = v_customer_id)
      ORDER BY updated_at DESC
      LIMIT 1;
    END IF;
  END IF;

  v_case_no := 'DSP-' || TO_CHAR(NOW(), 'YYMMDD') || '-' || UPPER(SUBSTRING(REPLACE(gen_random_uuid()::text, '-', ''), 1, 5));

  INSERT INTO public.disputes (
    case_number,
    target_type,
    order_id,
    booking_id,
    booking_ref,
    business_id,
    customer_id,
    conversation_id,
    customer_name,
    business_name,
    item_summary,
    reason_code,
    reason_text,
    total_amount,
    requested_refund_amount,
    customer_evidence_urls,
    status,
    response_deadline_at
  ) VALUES (
    v_case_no,
    p_target_type,
    p_order_id,
    v_booking.id,
    COALESCE(p_booking_ref, v_booking.booking_metadata->>'booking_id'),
    v_business_id,
    v_customer_id,
    v_conv_id,
    COALESCE(v_cust_name, 'Pelanggan Ngam'),
    COALESCE(v_biz_name, 'Peniaga Ngam'),
    COALESCE(NULLIF(TRIM(p_item_summary), ''), CASE WHEN p_target_type = 'order' THEN 'Pesanan Produk' ELSE 'Tempahan Servis' END),
    p_reason_code,
    TRIM(p_reason_text),
    v_total_amt,
    v_req_refund,
    COALESCE(p_evidence_urls, '[]'::jsonb),
    'open',
    NOW() + INTERVAL '48 hours'
  )
  RETURNING * INTO v_dispute;

  -- Post initial system & customer statement into 3-way mediation timeline
  INSERT INTO public.dispute_messages (
    dispute_id, sender_id, sender_role, sender_name, message, attachments
  ) VALUES
  (
    v_dispute.id,
    NULL,
    'system',
    'Ngam Dispute Center',
    'Kes pertikaian #' || v_case_no || ' dibuka. Dana pesanan/tempahan sebanyak RM ' || TO_CHAR(v_req_refund, 'FM999990.00') || ' dibekukan sementara. Pihak kedai mempunyai 48 jam untuk memberi maklum balas.',
    '[]'::jsonb
  ),
  (
    v_dispute.id,
    v_customer_id,
    'customer',
    COALESCE(v_cust_name, 'Pelanggan'),
    TRIM(p_reason_text),
    COALESCE(p_evidence_urls, '[]'::jsonb)
  );

  RETURN v_dispute;
END;
$$;

-- 6. RPC: Business Responds to Dispute (`respond_dispute_case`)
CREATE OR REPLACE FUNCTION public.respond_dispute_case(
  p_dispute_id     UUID,
  p_action         TEXT, -- 'counter', 'agree_refund', 'escalate'
  p_response_text  TEXT DEFAULT '',
  p_evidence_urls  JSONB DEFAULT '[]'::jsonb
)
RETURNS public.disputes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid           UUID := auth.uid();
  v_dispute       public.disputes;
  v_biz_name      TEXT;
  v_refund_amt    NUMERIC(12, 2);
  v_refund_cents  BIGINT;
  v_curr_cents    BIGINT;
  v_debit_cents   BIGINT;
  v_new_cents     BIGINT;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT * INTO v_dispute FROM public.disputes WHERE id = p_dispute_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Kes pertikaian tidak ditemui.';
  END IF;

  IF NOT public.is_active_staff_of(v_dispute.business_id)
     AND NOT EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = v_dispute.business_id AND b.owner_user_id = v_uid)
     AND NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'Akses ditolak: Hanya pemilik atau staf kedai boleh membalas kes ini.';
  END IF;

  IF v_dispute.status NOT IN ('open', 'business_responded', 'escalated', 'under_review') THEN
    RAISE EXCEPTION 'Kes pertikaian ini telah pun diselesaikan.';
  END IF;

  v_biz_name := COALESCE(v_dispute.business_name, 'Pihak Kedai');

  IF p_action = 'agree_refund' THEN
    v_refund_amt := GREATEST(0, COALESCE(v_dispute.requested_refund_amount, v_dispute.total_amount, 0));
    v_refund_cents := ROUND(v_refund_amt * 100)::bigint;

    -- Credit customer wallet
    IF v_refund_amt > 0 THEN
      UPDATE public.users
      SET user_balance = COALESCE(user_balance, 0) + v_refund_amt
      WHERE id = v_dispute.customer_id;

      INSERT INTO public.wallet_transactions (user_id, type, amount, reference_id)
      VALUES (v_dispute.customer_id, 'refund', v_refund_amt, v_dispute.case_number);

      SELECT available_balance_cents INTO v_curr_cents
      FROM public.merchant_balances
      WHERE business_id = v_dispute.business_id
      FOR UPDATE;

      IF FOUND AND v_curr_cents > 0 THEN
        v_debit_cents := LEAST(v_curr_cents, v_refund_cents);
        v_new_cents := v_curr_cents - v_debit_cents;
        UPDATE public.merchant_balances
        SET available_balance_cents = v_new_cents, updated_at = NOW()
        WHERE business_id = v_dispute.business_id;

        INSERT INTO public.merchant_ledger_entries (
          business_id, entry_type, amount_cents, balance_after_cents,
          reference_type, reference_id, description, metadata
        ) VALUES (
          v_dispute.business_id, 'dispute_refund', -v_debit_cents, v_new_cents,
          v_dispute.target_type, COALESCE(v_dispute.order_id::text, v_dispute.booking_id::text, v_dispute.id::text),
          'Peniaga bersetuju refund pertikaian #' || v_dispute.case_number,
          jsonb_build_object('case_number', v_dispute.case_number, 'requested_cents', v_refund_cents)
        );
      END IF;
    END IF;

    IF v_dispute.order_id IS NOT NULL THEN
      UPDATE public.orders
      SET status = 'refunded', payment_status = 'refunded'
      WHERE id = v_dispute.order_id;
    END IF;
    IF v_dispute.booking_id IS NOT NULL THEN
      UPDATE public.bookings
      SET status = 'cancelled',
          booking_metadata = COALESCE(booking_metadata, '{}'::jsonb) || jsonb_build_object(
            'payment_status', 'refunded',
            'dispute_resolution', 'merchant_agreed_refund',
            'resolved_at', NOW()
          )
      WHERE id = v_dispute.booking_id;
    END IF;

    UPDATE public.disputes
    SET status = 'resolved_refund_full',
        resolution_type = 'merchant_agreed_refund',
        approved_refund_amount = v_refund_amt,
        merchant_release_amount = 0.00,
        business_response_text = COALESCE(NULLIF(TRIM(p_response_text), ''), business_response_text),
        business_responded_at = NOW(),
        resolved_at = NOW()
    WHERE id = p_dispute_id
    RETURNING * INTO v_dispute;

    INSERT INTO public.dispute_messages (
      dispute_id, sender_id, sender_role, sender_name, message
    ) VALUES (
      p_dispute_id, NULL, 'system', 'Ngam Dispute Center',
      v_biz_name || ' bersetuju dengan bayaran balik penuh RM ' || TO_CHAR(v_refund_amt, 'FM999990.00') || ' ke Ngam Wallet pelanggan. Kes ditutup.'
    );
    RETURN v_dispute;

  ELSIF p_action = 'escalate' THEN
    UPDATE public.disputes
    SET status = 'escalated',
        escalated_by = v_uid,
        escalated_at = NOW(),
        business_response_text = COALESCE(NULLIF(TRIM(p_response_text), ''), business_response_text),
        business_evidence_urls = COALESCE(business_evidence_urls, '[]'::jsonb) || COALESCE(p_evidence_urls, '[]'::jsonb),
        business_responded_at = COALESCE(business_responded_at, NOW())
    WHERE id = p_dispute_id
    RETURNING * INTO v_dispute;

    INSERT INTO public.dispute_messages (
      dispute_id, sender_id, sender_role, sender_name, message
    ) VALUES (
      p_dispute_id, NULL, 'system', 'Ngam Dispute Center',
      v_biz_name || ' telah memanggil Admin Ngam (Mediator) untuk menyemak bukti dan membuat keputusan muktamad.'
    );
    RETURN v_dispute;

  ELSE
    -- 'counter': Business submits rebuttal & evidence
    IF TRIM(COALESCE(p_response_text, '')) = '' AND jsonb_array_length(COALESCE(p_evidence_urls, '[]'::jsonb)) = 0 THEN
      RAISE EXCEPTION 'Sila masukkan penjelasan atau muat naik bukti balas.';
    END IF;

    UPDATE public.disputes
    SET status = CASE WHEN status IN ('escalated', 'under_review') THEN status ELSE 'business_responded' END,
        business_response_text = TRIM(COALESCE(p_response_text, '')),
        business_evidence_urls = COALESCE(business_evidence_urls, '[]'::jsonb) || COALESCE(p_evidence_urls, '[]'::jsonb),
        business_responded_at = NOW()
    WHERE id = p_dispute_id
    RETURNING * INTO v_dispute;

    INSERT INTO public.dispute_messages (
      dispute_id, sender_id, sender_role, sender_name, message, attachments
    ) VALUES (
      p_dispute_id,
      v_uid,
      'business',
      v_biz_name,
      COALESCE(NULLIF(TRIM(p_response_text), ''), 'Mengemukakan bukti balas pihak kedai.'),
      COALESCE(p_evidence_urls, '[]'::jsonb)
    );
    RETURN v_dispute;
  END IF;
END;
$$;

-- 7. RPC: Escalate Dispute to Admin Mediator (`escalate_dispute_case`)
CREATE OR REPLACE FUNCTION public.escalate_dispute_case(
  p_dispute_id UUID,
  p_note       TEXT DEFAULT ''
)
RETURNS public.disputes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid      UUID := auth.uid();
  v_dispute  public.disputes;
  v_actor    TEXT := 'Pengguna';
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT * INTO v_dispute FROM public.disputes WHERE id = p_dispute_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Kes pertikaian tidak ditemui.';
  END IF;

  IF v_dispute.customer_id = v_uid THEN
    v_actor := COALESCE(v_dispute.customer_name, 'Pelanggan');
  ELSIF public.is_active_staff_of(v_dispute.business_id)
     OR EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = v_dispute.business_id AND b.owner_user_id = v_uid) THEN
    v_actor := COALESCE(v_dispute.business_name, 'Pihak Kedai');
  ELSIF public.is_super_admin() THEN
    v_actor := 'Admin Ngam';
  ELSE
    RAISE EXCEPTION 'Akses ditolak.';
  END IF;

  IF v_dispute.status NOT IN ('open', 'business_responded', 'escalated', 'under_review') THEN
    RAISE EXCEPTION 'Kes pertikaian sudah ditutup.';
  END IF;

  UPDATE public.disputes
  SET status = CASE WHEN public.is_super_admin() THEN 'under_review' ELSE 'escalated' END,
      escalated_by = COALESCE(escalated_by, v_uid),
      escalated_at = COALESCE(escalated_at, NOW())
  WHERE id = p_dispute_id
  RETURNING * INTO v_dispute;

  INSERT INTO public.dispute_messages (
    dispute_id, sender_id, sender_role, sender_name, message
  ) VALUES (
    p_dispute_id, NULL, 'system', 'Ngam Dispute Center',
    v_actor || ' telah melibatkan Mediator Admin Ngam untuk semakan & keputusan rasmi.' ||
    CASE WHEN TRIM(COALESCE(p_note, '')) <> '' THEN E'\nNota: ' || TRIM(p_note) ELSE '' END
  );

  RETURN v_dispute;
END;
$$;

-- 7.5 RPC: Customer Withdraws Dispute Atomically (`withdraw_dispute_case`)
CREATE OR REPLACE FUNCTION public.withdraw_dispute_case(
  p_dispute_id UUID
)
RETURNS public.disputes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid     UUID := auth.uid();
  v_dispute public.disputes;
  v_actor   TEXT;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT * INTO v_dispute FROM public.disputes WHERE id = p_dispute_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Kes pertikaian tidak ditemui.';
  END IF;

  IF v_dispute.customer_id IS DISTINCT FROM v_uid AND NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'Akses ditolak: Hanya pelanggan yang memfailkan kes boleh menarik balik pertikaian ini.';
  END IF;

  IF v_dispute.status NOT IN ('open', 'business_responded', 'escalated', 'under_review') THEN
    RAISE EXCEPTION 'Kes ini telah pun ditutup.';
  END IF;

  v_actor := COALESCE(NULLIF(TRIM(v_dispute.customer_name), ''), 'Pelanggan');

  IF v_dispute.order_id IS NOT NULL THEN
    UPDATE public.orders
    SET status = CASE WHEN status = 'disputed' THEN 'completed' ELSE status END
    WHERE id = v_dispute.order_id;
  END IF;

  IF v_dispute.booking_id IS NOT NULL THEN
    UPDATE public.bookings
    SET status = CASE WHEN status = 'disputed' THEN 'completed' ELSE status END,
        booking_metadata = COALESCE(booking_metadata, '{}'::jsonb) || jsonb_build_object(
          'is_disputed', false,
          'dispute_resolution', 'customer_withdrawn',
          'resolved_at', NOW()
        )
    WHERE id = v_dispute.booking_id;
  END IF;

  UPDATE public.disputes
  SET status = 'withdrawn',
      resolution_type = 'customer_withdrawn',
      resolved_at = NOW()
  WHERE id = p_dispute_id
  RETURNING * INTO v_dispute;

  INSERT INTO public.dispute_messages (
    dispute_id, sender_id, sender_role, sender_name, message
  ) VALUES (
    p_dispute_id,
    NULL,
    'system',
    'Ngam Dispute Center',
    v_actor || ' telah menarik balik pertikaian dan menandakan isu selesai.'
  );

  RETURN v_dispute;
END;
$$;

-- 8. RPC: Super Admin Final Adjudication ("Penentu") (`resolve_dispute_case`)
CREATE OR REPLACE FUNCTION public.resolve_dispute_case(
  p_dispute_id      UUID,
  p_decision        TEXT, -- 'refund_full', 'refund_partial', 'release_business'
  p_refund_amount   NUMERIC DEFAULT 0.00,
  p_moderator_note  TEXT DEFAULT ''
)
RETURNS public.disputes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id      UUID := auth.uid();
  v_dispute       public.disputes;
  v_total         NUMERIC(12, 2);
  v_refund_amt    NUMERIC(12, 2) := 0.00;
  v_release_amt   NUMERIC(12, 2) := 0.00;
  v_refund_cents  BIGINT := 0;
  v_curr_cents    BIGINT := 0;
  v_debit_cents   BIGINT := 0;
  v_new_cents     BIGINT := 0;
  v_new_status    TEXT;
  v_verdict_text  TEXT;
BEGIN
  IF v_admin_id IS NULL OR NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'Akses ditolak: Hanya Super Admin (Penentu Ngam) boleh membuat keputusan muktamad.';
  END IF;

  IF TRIM(COALESCE(p_moderator_note, '')) = '' THEN
    RAISE EXCEPTION 'Sila masukkan nota keputusan rasmi Admin.';
  END IF;

  SELECT * INTO v_dispute FROM public.disputes WHERE id = p_dispute_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Kes pertikaian tidak ditemui.';
  END IF;

  IF v_dispute.status NOT IN ('open', 'business_responded', 'escalated', 'under_review') THEN
    RAISE EXCEPTION 'Kes ini telah pun ditutup dengan status %.', v_dispute.status;
  END IF;

  v_total := GREATEST(0, COALESCE(v_dispute.total_amount, v_dispute.requested_refund_amount, 0));

  IF p_decision = 'refund_full' THEN
    v_refund_amt := GREATEST(0, COALESCE(NULLIF(p_refund_amount, 0), v_dispute.requested_refund_amount, v_total));
    v_release_amt := GREATEST(0, v_total - v_refund_amt);
    v_new_status := 'resolved_refund_full';
    v_verdict_text := 'KEPUTUSAN MEDIATOR NGAM: Bayaran balik penuh sebanyak RM ' || TO_CHAR(v_refund_amt, 'FM999990.00') || ' diluluskan kepada Ngam Wallet pelanggan.';
  ELSIF p_decision = 'refund_partial' THEN
    v_refund_amt := LEAST(GREATEST(0, COALESCE(p_refund_amount, 0)), v_total);
    IF v_refund_amt <= 0 THEN
      RAISE EXCEPTION 'Jumlah refund separa mesti lebih daripada RM 0.00.';
    END IF;
    v_release_amt := GREATEST(0, v_total - v_refund_amt);
    v_new_status := 'resolved_refund_partial';
    v_verdict_text := 'KEPUTUSAN MEDIATOR NGAM: Bayaran balik separa RM ' || TO_CHAR(v_refund_amt, 'FM999990.00') || ' kepada pelanggan dan baki RM ' || TO_CHAR(v_release_amt, 'FM999990.00') || ' dilepaskan kepada pihak kedai.';
  ELSIF p_decision = 'release_business' THEN
    v_refund_amt := 0.00;
    v_release_amt := v_total;
    v_new_status := 'resolved_release_business';
    v_verdict_text := 'KEPUTUSAN MEDIATOR NGAM: Tuntutan bayaran balik ditolak. Dana RM ' || TO_CHAR(v_release_amt, 'FM999990.00') || ' dilepaskan kepada pihak kedai.';
  ELSE
    RAISE EXCEPTION 'Jenis keputusan tidak sah: %', p_decision;
  END IF;

  -- Execute wallet refund & merchant ledger entry atomically
  IF v_refund_amt > 0 THEN
    UPDATE public.users
    SET user_balance = COALESCE(user_balance, 0) + v_refund_amt
    WHERE id = v_dispute.customer_id;

    INSERT INTO public.wallet_transactions (user_id, type, amount, reference_id)
    VALUES (v_dispute.customer_id, 'refund', v_refund_amt, v_dispute.case_number);

    v_refund_cents := ROUND(v_refund_amt * 100)::bigint;
    SELECT available_balance_cents INTO v_curr_cents
    FROM public.merchant_balances
    WHERE business_id = v_dispute.business_id
    FOR UPDATE;

    IF FOUND AND v_curr_cents > 0 THEN
      v_debit_cents := LEAST(v_curr_cents, v_refund_cents);
      v_new_cents := v_curr_cents - v_debit_cents;

      UPDATE public.merchant_balances
      SET available_balance_cents = v_new_cents, updated_at = NOW()
      WHERE business_id = v_dispute.business_id;

      INSERT INTO public.merchant_ledger_entries (
        business_id, entry_type, amount_cents, balance_after_cents,
        reference_type, reference_id, description, metadata
      ) VALUES (
        v_dispute.business_id, 'dispute_refund', -v_debit_cents, v_new_cents,
        v_dispute.target_type, COALESCE(v_dispute.order_id::text, v_dispute.booking_id::text, v_dispute.id::text),
        'Potongan keputusan pertikaian #' || v_dispute.case_number || ' oleh Super Admin',
        jsonb_build_object(
          'case_number', v_dispute.case_number,
          'decision', p_decision,
          'refund_cents', v_refund_cents,
          'moderator_id', v_admin_id
        )
      );
    END IF;
  END IF;

  -- Sync linked Order / Booking final state
  IF v_dispute.order_id IS NOT NULL THEN
    UPDATE public.orders
    SET status = CASE
          WHEN p_decision = 'refund_full' THEN 'refunded'
          ELSE 'completed'
        END,
        payment_status = CASE
          WHEN p_decision = 'refund_full' THEN 'refunded'
          WHEN p_decision = 'refund_partial' THEN 'partial_refund'
          ELSE payment_status
        END
    WHERE id = v_dispute.order_id;
  END IF;

  IF v_dispute.booking_id IS NOT NULL THEN
    UPDATE public.bookings
    SET status = CASE
          WHEN p_decision = 'refund_full' THEN 'cancelled'
          ELSE 'completed'
        END,
        booking_metadata = COALESCE(booking_metadata, '{}'::jsonb) || jsonb_build_object(
          'dispute_resolution', p_decision,
          'approved_refund_amount', v_refund_amt,
          'moderator_note', TRIM(p_moderator_note),
          'resolved_at', NOW(),
          'payment_status', CASE
            WHEN p_decision = 'refund_full' THEN 'refunded'
            WHEN p_decision = 'refund_partial' THEN 'partial_refund'
            ELSE COALESCE(booking_metadata->>'payment_status', 'paid')
          END
        )
    WHERE id = v_dispute.booking_id;
  END IF;

  UPDATE public.disputes
  SET status = v_new_status,
      resolution_type = p_decision,
      approved_refund_amount = v_refund_amt,
      merchant_release_amount = v_release_amt,
      moderator_id = v_admin_id,
      moderator_note = TRIM(p_moderator_note),
      resolved_at = NOW()
  WHERE id = p_dispute_id
  RETURNING * INTO v_dispute;

  INSERT INTO public.dispute_messages (
    dispute_id, sender_id, sender_role, sender_name, message
  ) VALUES (
    p_dispute_id,
    NULL,
    'system',
    'Ngam Dispute Center',
    v_verdict_text || E'\nAlasan Admin: ' || TRIM(p_moderator_note)
  );

  RETURN v_dispute;
END;
$$;

REVOKE ALL ON FUNCTION public.open_dispute_case(TEXT, UUID, UUID, TEXT, UUID, TEXT, TEXT, NUMERIC, JSONB, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.open_dispute_case(TEXT, UUID, UUID, TEXT, UUID, TEXT, TEXT, NUMERIC, JSONB, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.respond_dispute_case(UUID, TEXT, TEXT, JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.respond_dispute_case(UUID, TEXT, TEXT, JSONB) TO authenticated;

REVOKE ALL ON FUNCTION public.escalate_dispute_case(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.escalate_dispute_case(UUID, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.withdraw_dispute_case(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.withdraw_dispute_case(UUID) TO authenticated;

REVOKE ALL ON FUNCTION public.resolve_dispute_case(UUID, TEXT, NUMERIC, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.resolve_dispute_case(UUID, TEXT, NUMERIC, TEXT) TO authenticated;

-- 9. Enable Realtime for live 3-way mediation chat & case updates
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'disputes'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.disputes;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'dispute_messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.dispute_messages;
  END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

COMMIT;
