-- ==============================================================================
-- BUSINESS: PLATFORM INTEGRATIONS OAUTH TOKEN STORE
-- Tarikh : 2026-11-26
-- Fail   : 20261126_platform_integrations_oauth.sql
-- ==============================================================================

-- Jadual selamat peringkat platform untuk menyimpan token OAuth 2.0
-- (cth: EasyParcel NextGen, Lalamove, dll.) — hanya boleh diakses oleh Service Role & Super Admin.
CREATE TABLE IF NOT EXISTS public.platform_integrations (
  provider           TEXT PRIMARY KEY, -- cth: 'easyparcel_nextgen'
  access_token       TEXT,
  refresh_token      TEXT,
  expires_at         TIMESTAMPTZ,
  refresh_expires_at TIMESTAMPTZ,
  redirect_uri       TEXT,
  metadata           JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.platform_integrations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Platform integrations super admin only" ON public.platform_integrations;

CREATE POLICY "Platform integrations super admin only"
  ON public.platform_integrations FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.user_roles ur
      WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.user_roles ur
      WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin'
    )
  );
