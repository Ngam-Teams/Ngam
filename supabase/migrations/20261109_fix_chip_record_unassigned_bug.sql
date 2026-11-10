-- =========================================================================================
-- MIGRATION: 20261109_fix_chip_record_unassigned_bug.sql
-- DESCRIPTION: Fixes runtime PostgreSQL error 'record "v_booking" is not assigned yet'
--              in `calculate_and_lock_order_for_chip` and `process_verified_chip_webhook`.
--              Declares explicit %ROWTYPE variables and boolean flags so unassigned records
--              are never accessed when an order UUID is processed.
-- =========================================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.calculate_and_lock_order_for_chip(
  p_order_id TEXT,
  p_payment_channel TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order public.orders%ROWTYPE;
  v_booking public.bookings%ROWTYPE;
  v_business RECORD;
  v_is_uuid BOOLEAN := false;
  v_is_order BOOLEAN := false;
  v_is_booking BOOLEAN := false;
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
    IF FOUND THEN
      v_is_booking := true;
    END IF;
  ELSIF v_is_uuid THEN
    -- Try locking in `orders` first
    SELECT * INTO v_order
    FROM public.orders
    WHERE id = v_order_uuid
    FOR UPDATE;
    IF FOUND THEN
      v_is_order := true;
    ELSE
      -- If not found in `orders`, check `bookings` by UUID
      SELECT * INTO v_booking
      FROM public.bookings
      WHERE id = v_order_uuid
      FOR UPDATE;
      IF FOUND THEN
        v_is_booking := true;
      END IF;
    END IF;
  END IF;

  -- Handle Booking calculation if target is a booking
  IF v_is_booking THEN
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
  ELSIF v_is_order THEN
    -- CASE B: Standard Order in `public.orders`
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

    IF LOWER(p_payment_channel) = 'fpx' THEN
      v_gateway_fee_cents := GREATEST(100, ROUND(v_discounted_subtotal_cents * 0.015)::bigint);
    ELSIF LOWER(p_payment_channel) = 'card' THEN
      v_gateway_fee_cents := ROUND(v_discounted_subtotal_cents * 0.024)::bigint;
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
  ELSE
    RAISE EXCEPTION 'Pesanan atau tempahan tidak ditemui untuk rujukan: %', p_order_id;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.calculate_and_lock_order_for_chip(TEXT, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.calculate_and_lock_order_for_chip(TEXT, TEXT) TO service_role;


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
  v_order public.orders%ROWTYPE;
  v_booking public.bookings%ROWTYPE;
  v_is_uuid BOOLEAN := false;
  v_is_order BOOLEAN := false;
  v_is_booking BOOLEAN := false;
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
    IF FOUND THEN
      v_is_booking := true;
    END IF;
  ELSIF v_is_uuid THEN
    SELECT * INTO v_order
    FROM public.orders
    WHERE id = v_ref_uuid
    FOR UPDATE;
    IF FOUND THEN
      v_is_order := true;
    ELSE
      SELECT * INTO v_booking
      FROM public.bookings
      WHERE id = v_ref_uuid
      FOR UPDATE;
      IF FOUND THEN
        v_is_booking := true;
      END IF;
    END IF;
  END IF;

  -- =====================================================================================
  -- BRANCH A: BOOKING SETTLEMENT
  -- =====================================================================================
  IF v_is_booking THEN
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

    v_comm_cents := 0;
    v_gateway_cents := 0;
    v_net_cents := p_paid_cents;

    -- 3. Record webhook in idempotency table
    INSERT INTO public.processed_payment_webhooks (
      chip_purchase_id, event_type, target_type, target_id, paid_cents, raw_payload
    ) VALUES (
      p_chip_purchase_id, p_event_type, 'booking',
      v_booking.id::text, p_paid_cents, COALESCE(p_raw_payload, '{}'::jsonb)
    );

    v_updated_meta := jsonb_set(
      jsonb_set(
        jsonb_set(
          v_existing_meta,
          '{payment_status}', '"paid"'::jsonb, true
        ),
        '{chip_purchase_id}', to_jsonb(p_chip_purchase_id), true
      ),
      '{paid_at}', to_jsonb(NOW()::text), true
    );

    UPDATE public.bookings
    SET booking_metadata = v_updated_meta
    WHERE id = v_booking.id;

    -- Credit merchant balance
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
      'Kredit tempahan daripada CHIP (' || COALESCE(p_payment_method, 'online') || ')',
      jsonb_build_object(
        'gross_cents', p_paid_cents,
        'platform_commission_cents', 0,
        'gateway_fee_cents', 0,
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
  ELSIF v_is_order THEN
    -- =====================================================================================
    -- BRANCH B: ORDER SETTLEMENT
    -- =====================================================================================
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

    -- 4. Record webhook in idempotency table FIRST
    INSERT INTO public.processed_payment_webhooks (
      chip_purchase_id, event_type, target_type, target_id, paid_cents, raw_payload
    ) VALUES (
      p_chip_purchase_id, p_event_type, 'order',
      v_order.id::text, p_paid_cents, COALESCE(p_raw_payload, '{}'::jsonb)
    );

    -- 5. Mark order paid
    UPDATE public.orders
    SET payment_status = 'paid',
        payment_method = COALESCE(p_payment_method, payment_method, 'chip_online'),
        chip_purchase_id = p_chip_purchase_id,
        updated_at = NOW()
    WHERE id = v_order.id;

    -- 6. Credit merchant balance
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
  ELSE
    RAISE EXCEPTION 'Order or Booking not found for reference: %', p_reference_id;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.process_verified_chip_webhook(TEXT, TEXT, TEXT, BIGINT, TEXT, JSONB) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_verified_chip_webhook(TEXT, TEXT, TEXT, BIGINT, TEXT, JSONB) TO service_role;

COMMIT;

NOTIFY pgrst, 'reload schema';
