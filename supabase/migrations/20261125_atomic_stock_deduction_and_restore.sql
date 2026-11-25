-- ==============================================================================
-- Migration: 20261125_atomic_stock_deduction_and_restore.sql
-- Purpose:
--   Fixes the critical inventory stock bug where customer purchases in Ngam
--   failed to deduct `business_products.stock` due to RLS ("Owners manage
--   products"), Web same-tab redirects bypassing client-side code, and lack of
--   idempotent tracking on cancellations/refunds.
--
-- Features:
--   1. Adds `stock_deducted` and `stock_restored` boolean flags to `public.orders`.
--   2. Atomic `SECURITY DEFINER` RPC `public.deduct_order_stock(p_order_id UUID)`
--      with row-level `FOR UPDATE` locking (prevents race conditions & double
--      deduction across client, POS, webhook, and DB triggers).
--   3. Atomic `SECURITY DEFINER` RPC `public.restore_order_stock(p_order_id UUID)`
--      that ONLY restores stock if `stock_deducted = TRUE AND stock_restored = FALSE`
--      (prevents stock inflation when cancelling unpaid/never-deducted orders).
--   4. Automatic `AFTER UPDATE` trigger on `public.orders` so:
--      - Marking an order `payment_status = 'paid'` ALWAYS deducts stock.
--      - Marking an order `status = 'cancelled'` ALWAYS restores deducted stock.
-- ==============================================================================

-- 1. Idempotency tracking columns on public.orders
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS stock_deducted BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS stock_restored BOOLEAN NOT NULL DEFAULT FALSE;

-- 2. Atomic SECURITY DEFINER stock deduction RPC
CREATE OR REPLACE FUNCTION public.deduct_order_stock(p_order_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order RECORD;
  v_item RECORD;
  v_cur_stock INTEGER;
  v_new_stock INTEGER;
  v_deducted_items INTEGER := 0;
BEGIN
  IF p_order_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'null_order_id');
  END IF;

  -- Lock the order row so concurrent calls (client + webhook + trigger) serialize cleanly
  SELECT id, status, payment_status, stock_deducted
  INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'order_not_found');
  END IF;

  IF COALESCE(v_order.stock_deducted, FALSE) = TRUE THEN
    RETURN jsonb_build_object('ok', true, 'already_deducted', true);
  END IF;

  IF LOWER(COALESCE(v_order.status, '')) = 'cancelled' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'order_cancelled');
  END IF;

  -- Aggregate quantities per product_id in case same product appears on multiple order_items lines
  FOR v_item IN
    SELECT oi.product_id, SUM(GREATEST(0, COALESCE(oi.quantity, 0)))::INTEGER AS total_qty
    FROM public.order_items oi
    WHERE oi.order_id = p_order_id
      AND oi.product_id IS NOT NULL
    GROUP BY oi.product_id
    ORDER BY oi.product_id
  LOOP
    IF v_item.total_qty <= 0 THEN
      CONTINUE;
    END IF;

    SELECT bp.stock
    INTO v_cur_stock
    FROM public.business_products bp
    WHERE bp.id = v_item.product_id
      AND LOWER(COALESCE(bp.item_type, 'product')) <> 'service'
      AND COALESCE(bp.track_inventory, TRUE) = TRUE
    FOR UPDATE;

    IF FOUND THEN
      v_new_stock := GREATEST(0, COALESCE(v_cur_stock, 0) - v_item.total_qty);
      UPDATE public.business_products
      SET stock = v_new_stock
      WHERE id = v_item.product_id;
      v_deducted_items := v_deducted_items + 1;
    END IF;
  END LOOP;

  UPDATE public.orders
  SET stock_deducted = TRUE,
      stock_restored = FALSE
  WHERE id = p_order_id;

  RETURN jsonb_build_object(
    'ok', true,
    'deducted_products', v_deducted_items
  );
END;
$$;

-- 3. Atomic SECURITY DEFINER stock restoration RPC (on cancel / void / refund)
CREATE OR REPLACE FUNCTION public.restore_order_stock(p_order_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order RECORD;
  v_item RECORD;
  v_cur_stock INTEGER;
  v_restored_items INTEGER := 0;
BEGIN
  IF p_order_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'null_order_id');
  END IF;

  SELECT id, stock_deducted, stock_restored
  INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'order_not_found');
  END IF;

  -- Strictly restore ONLY if stock was actually deducted and not yet restored
  IF COALESCE(v_order.stock_deducted, FALSE) = FALSE THEN
    RETURN jsonb_build_object('ok', true, 'skipped', 'never_deducted');
  END IF;

  IF COALESCE(v_order.stock_restored, FALSE) = TRUE THEN
    RETURN jsonb_build_object('ok', true, 'already_restored', true);
  END IF;

  FOR v_item IN
    SELECT oi.product_id, SUM(GREATEST(0, COALESCE(oi.quantity, 0)))::INTEGER AS total_qty
    FROM public.order_items oi
    WHERE oi.order_id = p_order_id
      AND oi.product_id IS NOT NULL
    GROUP BY oi.product_id
    ORDER BY oi.product_id
  LOOP
    IF v_item.total_qty <= 0 THEN
      CONTINUE;
    END IF;

    SELECT bp.stock
    INTO v_cur_stock
    FROM public.business_products bp
    WHERE bp.id = v_item.product_id
      AND LOWER(COALESCE(bp.item_type, 'product')) <> 'service'
      AND COALESCE(bp.track_inventory, TRUE) = TRUE
    FOR UPDATE;

    IF FOUND THEN
      UPDATE public.business_products
      SET stock = GREATEST(0, COALESCE(v_cur_stock, 0) + v_item.total_qty)
      WHERE id = v_item.product_id;
      v_restored_items := v_restored_items + 1;
    END IF;
  END LOOP;

  UPDATE public.orders
  SET stock_restored = TRUE
  WHERE id = p_order_id;

  RETURN jsonb_build_object(
    'ok', true,
    'restored_products', v_restored_items
  );
END;
$$;

-- 4. Grant execution rights to authenticated users (customers & merchants) and service_role
REVOKE ALL ON FUNCTION public.deduct_order_stock(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.restore_order_stock(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.deduct_order_stock(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.restore_order_stock(UUID) TO authenticated, service_role;

-- 5. Automatic server-side trigger on public.orders for paid & cancelled transitions
CREATE OR REPLACE FUNCTION public.fn_orders_auto_stock_sync()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Auto-deduct when order transitions to paid (covers CHIP webhook, Web redirect, Pay Later)
  IF LOWER(COALESCE(NEW.payment_status, '')) = 'paid'
     AND LOWER(COALESCE(NEW.status, '')) <> 'cancelled'
     AND COALESCE(NEW.stock_deducted, FALSE) = FALSE THEN
    PERFORM public.deduct_order_stock(NEW.id);
  END IF;

  -- Auto-restore when order transitions to cancelled (covers customer cancel, merchant cancel, void, expiry)
  IF LOWER(COALESCE(NEW.status, '')) = 'cancelled'
     AND LOWER(COALESCE(OLD.status, '')) <> 'cancelled'
     AND COALESCE(NEW.stock_deducted, FALSE) = TRUE
     AND COALESCE(NEW.stock_restored, FALSE) = FALSE THEN
    PERFORM public.restore_order_stock(NEW.id);
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_orders_auto_stock_sync ON public.orders;
CREATE TRIGGER trg_orders_auto_stock_sync
  AFTER UPDATE OF status, payment_status ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_orders_auto_stock_sync();
