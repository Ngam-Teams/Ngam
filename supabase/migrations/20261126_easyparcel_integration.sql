-- ==============================================================================
-- BUSINESS: EASYPARCEL LOGISTICS INTEGRATION & ORDER SHIPMENTS
-- Tarikh : 2026-11-26
-- Fail   : 20261126_easyparcel_integration.sql
-- ==============================================================================

-- 1. Jadual Konfigurasi Integrasi Perniagaan (Boleh diguna semula untuk EasyParcel, Lalamove, WhatsApp, Webhooks, dll.)
CREATE TABLE IF NOT EXISTS public.business_integrations (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id    UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  provider       TEXT NOT NULL, -- cth: 'easyparcel', 'lalamove', 'whatsapp_api', 'webhooks'
  is_connected   BOOLEAN NOT NULL DEFAULT FALSE,
  environment    TEXT NOT NULL DEFAULT 'demo' CHECK (environment IN ('demo', 'live')),
  api_key        TEXT,
  config         JSONB NOT NULL DEFAULT '{}'::jsonb,
  last_synced_at TIMESTAMPTZ,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_business_integrations_provider UNIQUE (business_id, provider)
);

CREATE INDEX IF NOT EXISTS idx_business_integrations_biz
  ON public.business_integrations (business_id, provider);

ALTER TABLE public.business_integrations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Business integrations owner and staff read" ON public.business_integrations;
DROP POLICY IF EXISTS "Business integrations owner and staff write" ON public.business_integrations;

CREATE POLICY "Business integrations owner and staff read"
  ON public.business_integrations FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.businesses b
      WHERE b.id = business_integrations.business_id
        AND b.owner_user_id = auth.uid()
    )
    OR public.is_active_staff_of(business_integrations.business_id, ARRAY['tenant_admin', 'manager', 'staff'])
    OR EXISTS (
      SELECT 1 FROM public.user_roles ur
      WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin'
    )
  );

CREATE POLICY "Business integrations owner and staff write"
  ON public.business_integrations FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.businesses b
      WHERE b.id = business_integrations.business_id
        AND b.owner_user_id = auth.uid()
    )
    OR public.is_active_staff_of(business_integrations.business_id, ARRAY['tenant_admin', 'manager'])
    OR EXISTS (
      SELECT 1 FROM public.user_roles ur
      WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.businesses b
      WHERE b.id = business_integrations.business_id
        AND b.owner_user_id = auth.uid()
    )
    OR public.is_active_staff_of(business_integrations.business_id, ARRAY['tenant_admin', 'manager'])
    OR EXISTS (
      SELECT 1 FROM public.user_roles ur
      WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin'
    )
  );

-- 2. Jadual Penghantaran Pesanan (Rekod AWB, Kurier & Tracking EasyParcel)
CREATE TABLE IF NOT EXISTS public.order_shipments (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id            UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  order_id               UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  provider               TEXT NOT NULL DEFAULT 'easyparcel',
  environment            TEXT NOT NULL DEFAULT 'demo' CHECK (environment IN ('demo', 'live')),
  ep_order_no            TEXT,
  ep_parcel_no           TEXT,
  courier_id             TEXT,
  courier_name           TEXT,
  service_id             TEXT,
  service_name           TEXT,
  awb_number             TEXT,
  awb_pdf_url            TEXT,
  tracking_url           TEXT,
  shipping_cost          NUMERIC(10, 2) NOT NULL DEFAULT 0,
  weight_kg              NUMERIC(8, 2) NOT NULL DEFAULT 1.00,
  pickup_date            DATE,
  status                 TEXT NOT NULL DEFAULT 'created', -- created, paid, in_transit, delivered, failed, cancelled
  latest_tracking_status TEXT,
  tracking_events        JSONB NOT NULL DEFAULT '[]'::jsonb,
  sender_info            JSONB NOT NULL DEFAULT '{}'::jsonb,
  receiver_info          JSONB NOT NULL DEFAULT '{}'::jsonb,
  raw_response           JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_order_shipments_order_id
  ON public.order_shipments (order_id);
CREATE INDEX IF NOT EXISTS idx_order_shipments_business_id
  ON public.order_shipments (business_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_order_shipments_awb
  ON public.order_shipments (awb_number) WHERE awb_number IS NOT NULL;

ALTER TABLE public.order_shipments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Order shipments read policy" ON public.order_shipments;
DROP POLICY IF EXISTS "Order shipments write policy" ON public.order_shipments;

CREATE POLICY "Order shipments read policy"
  ON public.order_shipments FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.businesses b
      WHERE b.id = order_shipments.business_id
        AND b.owner_user_id = auth.uid()
    )
    OR public.is_active_staff_of(order_shipments.business_id, ARRAY['tenant_admin', 'manager', 'staff'])
    OR EXISTS (
      SELECT 1 FROM public.orders o
      WHERE o.id = order_shipments.order_id
        AND (o.customer_id = auth.uid() OR o.owner_user_id = auth.uid())
    )
    OR EXISTS (
      SELECT 1 FROM public.user_roles ur
      WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin'
    )
  );

CREATE POLICY "Order shipments write policy"
  ON public.order_shipments FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.businesses b
      WHERE b.id = order_shipments.business_id
        AND b.owner_user_id = auth.uid()
    )
    OR public.is_active_staff_of(order_shipments.business_id, ARRAY['tenant_admin', 'manager', 'staff'])
    OR EXISTS (
      SELECT 1 FROM public.user_roles ur
      WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.businesses b
      WHERE b.id = order_shipments.business_id
        AND b.owner_user_id = auth.uid()
    )
    OR public.is_active_staff_of(order_shipments.business_id, ARRAY['tenant_admin', 'manager', 'staff'])
    OR EXISTS (
      SELECT 1 FROM public.user_roles ur
      WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin'
    )
  );

-- 3. Tambah lajur ringkas tracking pada jadual `orders` untuk paparan segera di aplikasi peniaga & pelanggan
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS courier_name TEXT,
  ADD COLUMN IF NOT EXISTS tracking_number TEXT,
  ADD COLUMN IF NOT EXISTS tracking_url TEXT,
  ADD COLUMN IF NOT EXISTS awb_pdf_url TEXT;
