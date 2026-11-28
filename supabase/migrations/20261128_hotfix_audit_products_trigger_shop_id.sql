-- ==============================================================================
-- HOTFIX: FIX AUDIT PRODUCTS TRIGGER SHOP_ID FIELD
-- Tarikh : 2026-11-28
-- Fail   : 20261128_hotfix_audit_products_trigger_shop_id.sql
-- ==============================================================================
-- Punca: `public.business_products` menggunakan kolum `shop_id` (bukan `business_id`),
-- menyebabkan ralat PostgreSQL 42703 (`record "new" has no field "business_id"`)
-- setiap kali harga produk diubah atau produk dipadam.
-- Penyelesaian: Guna `to_jsonb(NEW/OLD)` dengan fallback `business_id` -> `shop_id`
-- supaya trigger sentiasa selamat tanpa ralat kolum.
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.trg_audit_products_critical_fn()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_business_id UUID;
  v_old_price TEXT;
  v_new_price TEXT;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_business_id := COALESCE(
      NULLIF(to_jsonb(OLD)->>'business_id', '')::UUID,
      NULLIF(to_jsonb(OLD)->>'shop_id', '')::UUID
    );

    IF v_business_id IS NOT NULL THEN
      PERFORM public._record_system_audit_log(
        v_business_id,
        'PRODUCT_DELETED',
        'critical',
        'product',
        OLD.id::TEXT,
        format('Item "%s" telah dipadam daripada katalog.', COALESCE(OLD.name, 'Item')),
        jsonb_build_object(
          'target_label', COALESCE(OLD.name, 'Item'),
          'details', jsonb_build_object(
            'name', COALESCE(OLD.name, 'Item'),
            'price', COALESCE(OLD.price, 0)
          )
        )
      );
    END IF;
    RETURN OLD;

  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.price IS DISTINCT FROM NEW.price THEN
      v_business_id := COALESCE(
        NULLIF(to_jsonb(NEW)->>'business_id', '')::UUID,
        NULLIF(to_jsonb(NEW)->>'shop_id', '')::UUID
      );

      IF v_business_id IS NOT NULL THEN
        v_old_price := 'RM ' || TO_CHAR(COALESCE(OLD.price, 0), 'FM999999990.00');
        v_new_price := 'RM ' || TO_CHAR(COALESCE(NEW.price, 0), 'FM999999990.00');
        PERFORM public._record_system_audit_log(
          v_business_id,
          'PRODUCT_PRICE_CHANGED',
          'warning',
          'product',
          NEW.id::TEXT,
          format('Harga "%s" diubah: Harga Jualan (%s → %s).', COALESCE(NEW.name, 'Item'), v_old_price, v_new_price),
          jsonb_build_object(
            'target_label', COALESCE(NEW.name, 'Item'),
            'changes', jsonb_build_array(
              jsonb_build_object(
                'field', 'price',
                'label', 'Harga Jualan',
                'from', v_old_price,
                'to', v_new_price
              )
            )
          )
        );
      END IF;
    END IF;
    RETURN NEW;
  END IF;

  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_products_critical ON public.business_products;
CREATE TRIGGER trg_audit_products_critical
  AFTER UPDATE OR DELETE ON public.business_products
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_audit_products_critical_fn();
