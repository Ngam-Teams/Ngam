-- =============================================================================
-- NGAM ECOSYSTEM — TAMPER-RESISTANT AUDIT TRAILS & AUTO-TRIGGERS
-- File: supabase/migrations/20261123_audit_logs_and_triggers.sql
--
-- Menyediakan:
--  1. Jadual `public.audit_logs` (append-only, kalis ubah suai)
--  2. Indeks pantas mengikut `business_id`, `severity`, `action`, `created_at`
--  3. Polisi RLS ketat (Pemilik, Staf Aktif & Super Admin sahaja; TIADA UPDATE/DELETE)
--  4. Auto-Trigger pangkalan data untuk perubahan kritikal pada `orders`,
--     `business_products`, dan `bookings` (dengan anti-duplikasi 5 saat)
--  5. Rekod pengaktifan permulaan bagi perniagaan sedia ada
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  actor_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  actor_name TEXT NOT NULL DEFAULT 'System',
  actor_email TEXT,
  actor_role TEXT NOT NULL DEFAULT 'staff',
  action TEXT NOT NULL,
  severity TEXT NOT NULL DEFAULT 'info' CHECK (severity IN ('info', 'warning', 'critical')),
  target_type TEXT,
  target_id TEXT,
  description TEXT NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_biz_created
  ON public.audit_logs (business_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_logs_biz_severity
  ON public.audit_logs (business_id, severity, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_logs_biz_action
  ON public.audit_logs (business_id, action);

-- ── 2. Tamper-Resistant Row Level Security (Append-Only) ─────────────────────

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Sekat sebarang cubaan UPDATE atau DELETE oleh klien biasa/staf
REVOKE UPDATE, DELETE ON public.audit_logs FROM anon, authenticated;
GRANT SELECT, INSERT ON public.audit_logs TO authenticated;

DROP POLICY IF EXISTS "Business owner and staff can view own audit logs" ON public.audit_logs;
CREATE POLICY "Business owner and staff can view own audit logs"
  ON public.audit_logs
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.businesses b
      WHERE b.id = audit_logs.business_id
        AND b.owner_user_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.team_members tm
      WHERE tm.business_id = audit_logs.business_id
        AND tm.user_id = auth.uid()
        AND COALESCE(LOWER(tm.status), 'active') <> 'inactive'
    )
    OR EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid()
        AND LOWER(COALESCE(u.role, '')) IN ('super_admin', 'admin')
    )
  );

DROP POLICY IF EXISTS "Business owner and staff can insert own audit logs" ON public.audit_logs;
CREATE POLICY "Business owner and staff can insert own audit logs"
  ON public.audit_logs
  FOR INSERT
  TO authenticated
  WITH CHECK (
    (actor_user_id IS NULL OR actor_user_id = auth.uid())
    AND (
      EXISTS (
        SELECT 1 FROM public.businesses b
        WHERE b.id = audit_logs.business_id
          AND b.owner_user_id = auth.uid()
      )
      OR EXISTS (
        SELECT 1 FROM public.team_members tm
        WHERE tm.business_id = audit_logs.business_id
          AND tm.user_id = auth.uid()
          AND COALESCE(LOWER(tm.status), 'active') <> 'inactive'
      )
      OR EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = auth.uid()
          AND LOWER(COALESCE(u.role, '')) IN ('super_admin', 'admin')
      )
    )
  );

-- ── 3. Helper Function: Insert Audit Entry Safely (Anti-Duplicate 5s) ────────

CREATE OR REPLACE FUNCTION public._record_system_audit_log(
  p_business_id UUID,
  p_action TEXT,
  p_severity TEXT,
  p_target_type TEXT,
  p_target_id TEXT,
  p_description TEXT,
  p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_actor_name TEXT := 'System';
  v_actor_email TEXT := NULL;
  v_actor_role TEXT := 'system';
  v_is_owner BOOLEAN := FALSE;
BEGIN
  IF p_business_id IS NULL THEN
    RETURN;
  END IF;

  -- Elak log berganda jika aplikasi sudah pun merekodkan tindakan yang sama dalam 5 saat terakhir
  IF p_target_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.audit_logs al
    WHERE al.business_id = p_business_id
      AND al.target_id = p_target_id
      AND al.action = p_action
      AND al.created_at > NOW() - INTERVAL '5 seconds'
  ) THEN
    RETURN;
  END IF;

  IF v_uid IS NOT NULL THEN
    SELECT
      COALESCE(NULLIF(TRIM(u.user_name), ''), SPLIT_PART(COALESCE(u.user_email, ''), '@', 1), 'Staff'),
      u.user_email
    INTO v_actor_name, v_actor_email
    FROM public.users u
    WHERE u.id = v_uid
    LIMIT 1;

    SELECT EXISTS (
      SELECT 1 FROM public.businesses b
      WHERE b.id = p_business_id AND b.owner_user_id = v_uid
    ) INTO v_is_owner;

    IF v_is_owner THEN
      v_actor_role := 'tenant_admin';
    ELSE
      SELECT COALESCE(NULLIF(TRIM(tm.role), ''), 'staff')
      INTO v_actor_role
      FROM public.team_members tm
      WHERE tm.business_id = p_business_id AND tm.user_id = v_uid
      LIMIT 1;
      IF v_actor_role IS NULL THEN
        v_actor_role := 'staff';
      END IF;
    END IF;
  END IF;

  INSERT INTO public.audit_logs (
    business_id,
    actor_user_id,
    actor_name,
    actor_email,
    actor_role,
    action,
    severity,
    target_type,
    target_id,
    description,
    metadata
  ) VALUES (
    p_business_id,
    v_uid,
    COALESCE(NULLIF(TRIM(v_actor_name), ''), 'System'),
    v_actor_email,
    COALESCE(NULLIF(TRIM(v_actor_role), ''), 'system'),
    p_action,
    CASE WHEN p_severity IN ('info', 'warning', 'critical') THEN p_severity ELSE 'info' END,
    p_target_type,
    p_target_id,
    p_description,
    COALESCE(p_metadata, '{}'::jsonb)
  );
EXCEPTION WHEN OTHERS THEN
  -- Jangan sesekali menyekat transaksi utama sekiranya log audit gagal
  NULL;
END;
$$;

-- ── 4. Automatic Critical Triggers (Orders, Products, Bookings) ──────────────

CREATE OR REPLACE FUNCTION public.trg_audit_orders_critical_fn()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old_st TEXT := LOWER(COALESCE(OLD.status, ''));
  v_new_st TEXT := LOWER(COALESCE(NEW.status, ''));
  v_old_pay TEXT := LOWER(COALESCE(OLD.payment_status, ''));
  v_new_pay TEXT := LOWER(COALESCE(NEW.payment_status, ''));
  v_short TEXT := UPPER(LEFT(NEW.id::TEXT, 8));
  v_changes JSONB := '[]'::jsonb;
BEGIN
  IF v_new_st = 'cancelled' AND v_old_st <> 'cancelled' THEN
    v_changes := v_changes || jsonb_build_object(
      'field', 'status',
      'label', 'Status',
      'from', UPPER(REPLACE(COALESCE(NULLIF(v_old_st, ''), 'pending'), '_', ' ')),
      'to', 'CANCELLED'
    );
    IF v_new_pay IS DISTINCT FROM v_old_pay AND v_new_pay <> '' THEN
      v_changes := v_changes || jsonb_build_object(
        'field', 'payment_status',
        'label', 'Status Bayaran',
        'from', UPPER(REPLACE(COALESCE(NULLIF(v_old_pay, ''), 'unpaid'), '_', ' ')),
        'to', UPPER(REPLACE(v_new_pay, '_', ' '))
      );
    END IF;
    PERFORM public._record_system_audit_log(
      NEW.business_id,
      'ORDER_CANCELLED',
      CASE WHEN v_new_pay IN ('refunded', 'refund_pending') THEN 'critical' ELSE 'warning' END,
      'order',
      NEW.id::TEXT,
      format('Pesanan #%s dibatalkan (RM %s).', v_short, TO_CHAR(COALESCE(NEW.total, 0), 'FM999999990.00')),
      jsonb_build_object(
        'target_label', v_short,
        'order_ref', v_short,
        'changes', v_changes,
        'details', jsonb_build_object('total', COALESCE(NEW.total, 0))
      )
    );
  ELSIF v_new_pay IN ('refunded', 'refund_pending') AND v_old_pay NOT IN ('refunded', 'refund_pending') THEN
    v_changes := jsonb_build_array(
      jsonb_build_object(
        'field', 'payment_status',
        'label', 'Status Bayaran',
        'from', UPPER(REPLACE(COALESCE(NULLIF(v_old_pay, ''), 'paid'), '_', ' ')),
        'to', UPPER(REPLACE(v_new_pay, '_', ' '))
      )
    );
    PERFORM public._record_system_audit_log(
      NEW.business_id,
      'ORDER_REFUNDED',
      'critical',
      'order',
      NEW.id::TEXT,
      format('Status bayaran pesanan #%s ditukar kepada %s (RM %s).', v_short, UPPER(REPLACE(v_new_pay, '_', ' ')), TO_CHAR(COALESCE(NEW.total, 0), 'FM999999990.00')),
      jsonb_build_object(
        'target_label', v_short,
        'order_ref', v_short,
        'changes', v_changes,
        'details', jsonb_build_object('total', COALESCE(NEW.total, 0))
      )
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_orders_critical ON public.orders;
CREATE TRIGGER trg_audit_orders_critical
  AFTER UPDATE ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_audit_orders_critical_fn();

CREATE OR REPLACE FUNCTION public.trg_audit_products_critical_fn()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old_price TEXT;
  v_new_price TEXT;
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM public._record_system_audit_log(
      OLD.business_id,
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
    RETURN OLD;
  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.price IS DISTINCT FROM NEW.price THEN
      v_old_price := 'RM ' || TO_CHAR(COALESCE(OLD.price, 0), 'FM999999990.00');
      v_new_price := 'RM ' || TO_CHAR(COALESCE(NEW.price, 0), 'FM999999990.00');
      PERFORM public._record_system_audit_log(
        NEW.business_id,
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

CREATE OR REPLACE FUNCTION public.trg_audit_bookings_critical_fn()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old_st TEXT := LOWER(COALESCE(OLD.status, ''));
  v_new_st TEXT := LOWER(COALESCE(NEW.status, ''));
  v_ref TEXT := COALESCE(
    NULLIF(TRIM(NEW.booking_metadata->>'booking_id'), ''),
    NULLIF(TRIM(NEW.booking_metadata->>'short_ref'), ''),
    UPPER(LEFT(NEW.id::TEXT, 8))
  );
BEGIN
  IF v_new_st IN ('cancelled', 'disputed') AND v_old_st <> v_new_st THEN
    PERFORM public._record_system_audit_log(
      NEW.business_id,
      CASE WHEN v_new_st = 'disputed' THEN 'BOOKING_DISPUTED' ELSE 'BOOKING_CANCELLED' END,
      CASE WHEN v_new_st = 'disputed' THEN 'critical' ELSE 'warning' END,
      'booking',
      NEW.id::TEXT,
      format('Tempahan #%s: Status (%s → %s).', v_ref, UPPER(REPLACE(COALESCE(NULLIF(v_old_st, ''), 'pending'), '_', ' ')), UPPER(REPLACE(v_new_st, '_', ' '))),
      jsonb_build_object(
        'target_label', v_ref,
        'booking_ref', v_ref,
        'changes', jsonb_build_array(
          jsonb_build_object(
            'field', 'status',
            'label', 'Status',
            'from', UPPER(REPLACE(COALESCE(NULLIF(v_old_st, ''), 'pending'), '_', ' ')),
            'to', UPPER(REPLACE(v_new_st, '_', ' '))
          )
        )
      )
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_bookings_critical ON public.bookings;
CREATE TRIGGER trg_audit_bookings_critical
  AFTER UPDATE ON public.bookings
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_audit_bookings_critical_fn();

-- ── 5. Seed Initial Audit Activation Record for Existing Businesses ──────────

INSERT INTO public.audit_logs (
  business_id,
  actor_user_id,
  actor_name,
  actor_role,
  action,
  severity,
  target_type,
  description,
  metadata
)
SELECT
  b.id,
  b.owner_user_id,
  'Ngam Security',
  'system',
  'SECURITY_AUDIT_INIT',
  'info',
  'system',
  'Sistem Jejak Audit & Keselamatan kalis ubah suai telah diaktifkan.',
  jsonb_build_object('source', 'migration_20261123')
FROM public.businesses b
WHERE NOT EXISTS (
  SELECT 1 FROM public.audit_logs al WHERE al.business_id = b.id
);
