-- =============================================================================
-- Help Center, Bug Reports & Feedback Tickets (Ngam, Ngam Business & Ngam Admin)
-- Idempotent migration: safe to run multiple times in Supabase SQL Editor.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.support_tickets (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_code     TEXT UNIQUE NOT NULL,
  user_id         UUID NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  business_id     UUID NULL REFERENCES public.businesses(id) ON DELETE SET NULL,
  source_app      TEXT NOT NULL DEFAULT 'ngam'
                    CHECK (source_app IN ('ngam', 'ngam_business', 'ngam_admin')),
  reporter_name   TEXT NOT NULL DEFAULT '',
  reporter_email  TEXT NOT NULL DEFAULT '',
  reporter_phone  TEXT NULL,
  category        TEXT NOT NULL DEFAULT 'bug'
                    CHECK (category IN ('bug', 'feature', 'order_issue', 'payment', 'account', 'hardware', 'other')),
  priority        TEXT NOT NULL DEFAULT 'normal'
                    CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  subject         TEXT NOT NULL,
  description     TEXT NOT NULL,
  attachment_urls JSONB NOT NULL DEFAULT '[]'::jsonb,
  app_version     TEXT NULL,
  platform        TEXT NULL,
  device_info     TEXT NULL,
  status          TEXT NOT NULL DEFAULT 'open'
                    CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),
  admin_reply     TEXT NULL,
  replied_by      UUID NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  replied_at      TIMESTAMPTZ NULL,
  resolved_at     TIMESTAMPTZ NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_support_tickets_user_created
  ON public.support_tickets (user_id, created_at DESC)
  WHERE user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_support_tickets_business_created
  ON public.support_tickets (business_id, created_at DESC)
  WHERE business_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_support_tickets_status_created
  ON public.support_tickets (status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_support_tickets_source_app
  ON public.support_tickets (source_app, created_at DESC);

-- Auto-update updated_at timestamp trigger
CREATE OR REPLACE FUNCTION public.fn_touch_support_tickets_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := timezone('utc'::text, now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_support_tickets_updated_at ON public.support_tickets;
CREATE TRIGGER trg_support_tickets_updated_at
  BEFORE UPDATE ON public.support_tickets
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_touch_support_tickets_updated_at();

-- Enable Row-Level Security
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  DROP POLICY IF EXISTS "Users can view own support tickets" ON public.support_tickets;
  DROP POLICY IF EXISTS "Authenticated users can submit support tickets" ON public.support_tickets;
  DROP POLICY IF EXISTS "Guests can submit anonymous support tickets" ON public.support_tickets;
  DROP POLICY IF EXISTS "Super admins manage all support tickets" ON public.support_tickets;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- 1. Reporter, active staff of the business, and super_admins can SELECT
CREATE POLICY "Users can view own support tickets"
  ON public.support_tickets FOR SELECT TO authenticated
  USING (
    auth.uid() = user_id
    OR (
      business_id IS NOT NULL AND (
        EXISTS (
          SELECT 1 FROM public.businesses b
          WHERE b.id = support_tickets.business_id
            AND b.owner_user_id = auth.uid()
        )
        OR EXISTS (
          SELECT 1 FROM public.team_members tm
          WHERE tm.business_id = support_tickets.business_id
            AND tm.user_id = auth.uid()
            AND tm.status = 'active'
        )
      )
    )
    OR EXISTS (
      SELECT 1 FROM public.user_roles ur
      WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin'
    )
  );

-- 2. Authenticated users can INSERT their own tickets
CREATE POLICY "Authenticated users can submit support tickets"
  ON public.support_tickets FOR INSERT TO authenticated
  WITH CHECK (
    user_id IS NULL OR auth.uid() = user_id
  );

-- 3. Guests (pre-login / unsigned) can INSERT anonymous tickets with contact info
CREATE POLICY "Guests can submit anonymous support tickets"
  ON public.support_tickets FOR INSERT TO anon
  WITH CHECK (
    user_id IS NULL
  );

-- 4. Super Admins have full control (SELECT, INSERT, UPDATE, DELETE)
CREATE POLICY "Super admins manage all support tickets"
  ON public.support_tickets FOR ALL TO authenticated
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

GRANT SELECT, INSERT ON public.support_tickets TO authenticated;
GRANT UPDATE, DELETE ON public.support_tickets TO authenticated;
GRANT INSERT ON public.support_tickets TO anon;

-- Enable Supabase Realtime so Admin & Users see ticket updates immediately
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'support_tickets'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.support_tickets;
  END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
