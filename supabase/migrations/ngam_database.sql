-- =========================================================================================
-- NGAM ECOSYSTEM UNIFIED DATABASE SCHEMA (ngam_database.sql)
-- Applications: Ngam (Customer), Ngam Admin (Super Admin), Ngam Business (Merchant), Ngam Teams (Staff)
-- Database Engine: Supabase PostgreSQL 15+
-- =========================================================================================

-- Enable Required Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
DO $$ BEGIN
  CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA extensions;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- =========================================================================================
-- 1. CORE IDENTITY & ROLES LAYER
-- =========================================================================================

-- 1.1 Global User Roles Table (Controls Authorization across all 4 apps)
CREATE TABLE IF NOT EXISTS public.user_roles (
  user_id    UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role       TEXT NOT NULL CHECK (role IN ('super_admin', 'tenant_admin', 'staff', 'customer')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  DROP POLICY IF EXISTS "Users read own role" ON public.user_roles;
  DROP POLICY IF EXISTS "Users insert own role" ON public.user_roles;
  DROP POLICY IF EXISTS "Super admins all access user_roles" ON public.user_roles;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

CREATE POLICY "Users read own role"
  ON public.user_roles FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users insert own role"
  ON public.user_roles FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Super admins all access user_roles"
  ON public.user_roles FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin'));

-- 1.2 Customer / Public Users Profile Table (Pure Customer Profile - No Runner Logic)
CREATE TABLE IF NOT EXISTS public.users (
  id                      UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role                    VARCHAR(50) NOT NULL DEFAULT 'customer' CHECK (role IN ('customer', 'business', 'admin')),
  user_name               VARCHAR(255),
  user_email              VARCHAR(255),
  user_phone              VARCHAR(50),
  user_bio                TEXT,
  user_gender             VARCHAR(20),
  user_birth_date         DATE,
  user_address            TEXT,
  user_address_lat        DOUBLE PRECISION,
  user_address_lng        DOUBLE PRECISION,
  user_avatar_url         VARCHAR,
  user_fcm_token          TEXT,
  user_balance            DECIMAL(10, 2) DEFAULT 0.00,
  created_at              TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at              TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  DROP POLICY IF EXISTS "Users can be viewed by anyone" ON public.users;
  DROP POLICY IF EXISTS "Users can insert their own profile" ON public.users;
  DROP POLICY IF EXISTS "Users can update their own profile" ON public.users;
  DROP POLICY IF EXISTS "Users can delete their own profile" ON public.users;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

CREATE POLICY "Users can be viewed by anyone" 
  ON public.users FOR SELECT USING (true);

CREATE POLICY "Users can insert their own profile" 
  ON public.users FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile" 
  ON public.users FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can delete their own profile" 
  ON public.users FOR DELETE USING (auth.uid() = id);


-- =========================================================================================
-- 2. BUSINESS & STORE MANAGEMENT LAYER (CENTRAL ANCHOR)
-- =========================================================================================

-- 2.1 Core Businesses Table
CREATE TABLE IF NOT EXISTS public.businesses (
  id                           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id                UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  business_name                TEXT NOT NULL,
  business_industry            TEXT NOT NULL DEFAULT 'services' CHECK (business_industry IN ('fnb', 'barber', 'retail', 'services')),
  business_registration_number TEXT NOT NULL DEFAULT 'PENDING-REG',
  sst_number                   TEXT,
  business_logo_url            TEXT,
  business_cover_url           TEXT,
  address_line                 TEXT NOT NULL DEFAULT '',
  postcode                     TEXT NOT NULL DEFAULT '',
  business_city                TEXT NOT NULL DEFAULT '',
  state                        TEXT NOT NULL DEFAULT '',
  business_country             TEXT DEFAULT 'Malaysia',
  business_email               TEXT,
  business_phone               TEXT,
  business_website             TEXT,
  business_subscription_tier   TEXT DEFAULT 'free',
  latitude                     FLOAT8,
  longitude                    FLOAT8,
  platform_fee_percent         NUMERIC NOT NULL DEFAULT 2.0 CHECK (platform_fee_percent >= 0.0), -- Configurable fee per business (default 2%)
  status                       TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('trial', 'active', 'suspended')),
  created_at                   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.businesses ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  DROP POLICY IF EXISTS "Public can view active businesses" ON public.businesses;
  DROP POLICY IF EXISTS "Owners manage own business" ON public.businesses;
  DROP POLICY IF EXISTS "Super admins manage all businesses" ON public.businesses;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- Anyone (customers in Ngam) can view active businesses on the explore map
CREATE POLICY "Public can view active businesses"
  ON public.businesses FOR SELECT 
  USING (status != 'suspended' OR auth.uid() = owner_user_id);

CREATE POLICY "Owners manage own business"
  ON public.businesses FOR ALL TO authenticated
  USING (auth.uid() = owner_user_id)
  WITH CHECK (auth.uid() = owner_user_id);

CREATE POLICY "Super admins manage all businesses"
  ON public.businesses FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin'));

-- 2.2 Business Compliance & Banking (Super Admin / Owner Only)
CREATE TABLE IF NOT EXISTS public.business_compliance (
  business_id      UUID PRIMARY KEY REFERENCES public.businesses(id) ON DELETE CASCADE,
  bank_name        TEXT,
  account_holder   TEXT,
  account_number   TEXT,
  epf_number       TEXT,
  socso_number     TEXT,
  eis_number       TEXT
);

ALTER TABLE public.business_compliance ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Compliance owner and admin access"
  ON public.business_compliance FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = business_compliance.business_id AND b.owner_user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin')
  );

-- 2.3 Business Settings & Operating Hours
CREATE TABLE IF NOT EXISTS public.business_settings (
  business_id      UUID PRIMARY KEY REFERENCES public.businesses(id) ON DELETE CASCADE,
  operating_hours  JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_halal         BOOLEAN NOT NULL DEFAULT FALSE,
  total_chairs     INTEGER DEFAULT 1,
  slot_duration    INTEGER NOT NULL DEFAULT 30
);

ALTER TABLE public.business_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Settings public view"
  ON public.business_settings FOR SELECT USING (true);

CREATE POLICY "Settings owner and admin access"
  ON public.business_settings FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = business_settings.business_id AND b.owner_user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin')
  );

-- 2.4 Super Admin Tenant View
DROP VIEW IF EXISTS public.admin_tenant_view CASCADE;
CREATE VIEW public.admin_tenant_view AS
SELECT b.*
FROM public.businesses b
JOIN public.user_roles ur ON ur.user_id = auth.uid()
WHERE ur.role = 'super_admin';


-- =========================================================================================
-- 3. PRODUCTS & CATALOGUE LAYER
-- =========================================================================================

CREATE TABLE IF NOT EXISTS public.business_products (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id     UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  price       NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
  category    TEXT DEFAULT 'General',
  description TEXT DEFAULT '',
  sku         TEXT,
  stock       INTEGER NOT NULL DEFAULT 0,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  image_url   TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.business_products ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  DROP POLICY IF EXISTS "Public can view active products" ON public.business_products;
  DROP POLICY IF EXISTS "Owners manage products" ON public.business_products;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

CREATE POLICY "Public can view active products"
  ON public.business_products FOR SELECT 
  USING (is_active = true OR EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = business_products.shop_id AND b.owner_user_id = auth.uid()));

CREATE POLICY "Owners manage products"
  ON public.business_products FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = business_products.shop_id AND b.owner_user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin')
  );

-- Compatibility view aliasing is_active as is_available for POS
DROP VIEW IF EXISTS public.products CASCADE;
CREATE VIEW public.products AS
SELECT 
  id,
  shop_id,
  name,
  price,
  category,
  description,
  sku,
  stock,
  is_active AS is_available,
  image_url,
  created_at
FROM public.business_products;


-- =========================================================================================
-- 4. ORDERS & POS LAYER
-- =========================================================================================

CREATE TABLE IF NOT EXISTS public.orders (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id   UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  owner_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  customer_id   UUID REFERENCES public.users(id) ON DELETE SET NULL,
  total         NUMERIC(10, 2) NOT NULL CHECK (total >= 0),
  status        TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'cancelled')),
  source        TEXT NOT NULL DEFAULT 'pos' CHECK (source IN ('pos', 'online')),
  customer_name TEXT,
  notes         TEXT,
  payment_method TEXT DEFAULT 'cash',
  payment_splits JSONB DEFAULT '[]'::jsonb,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.orders 
  ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'cash',
  ADD COLUMN IF NOT EXISTS payment_splits JSONB DEFAULT '[]'::jsonb;

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Orders read policy"
  ON public.orders FOR SELECT TO authenticated
  USING (
    owner_user_id = auth.uid() OR
    customer_id = auth.uid() OR
    EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = orders.business_id AND b.owner_user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin')
  );

CREATE POLICY "Orders insert policy"
  ON public.orders FOR INSERT TO authenticated
  WITH CHECK (
    owner_user_id = auth.uid() OR
    EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = orders.business_id AND b.owner_user_id = auth.uid())
  );

CREATE POLICY "Orders update policy"
  ON public.orders FOR UPDATE TO authenticated
  USING (
    owner_user_id = auth.uid() OR
    EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = orders.business_id AND b.owner_user_id = auth.uid())
  );

-- Order Items Table
CREATE TABLE IF NOT EXISTS public.order_items (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id     UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  product_id   UUID REFERENCES public.business_products(id) ON DELETE SET NULL,
  product_name TEXT NOT NULL,
  quantity     INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
  unit_price   NUMERIC(10, 2) NOT NULL,
  subtotal     NUMERIC(10, 2) NOT NULL
);

ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Order items read"
  ON public.order_items FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.orders o WHERE o.id = order_items.order_id AND (o.owner_user_id = auth.uid() OR o.customer_id = auth.uid())));

CREATE POLICY "Order items insert"
  ON public.order_items FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.orders o WHERE o.id = order_items.order_id AND (o.owner_user_id = auth.uid() OR o.customer_id = auth.uid())));


-- =========================================================================================
-- 5. TEAMS & STAFF MANAGEMENT LAYER (NGAM TEAMS BACKEND)
-- =========================================================================================

-- 5.1 Team Members / Staff Roster
CREATE TABLE IF NOT EXISTS public.team_members (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id   UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  user_id       UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  staff_code    TEXT NOT NULL,
  name          TEXT NOT NULL,
  email         TEXT NOT NULL,
  phone         TEXT,
  department    TEXT NOT NULL DEFAULT 'General',
  designation   TEXT NOT NULL DEFAULT 'Staff',
  role          TEXT NOT NULL DEFAULT 'staff' CHECK (role IN ('tenant_admin', 'staff', 'manager', 'cashier')),
  reporting_to  TEXT,
  office_base   TEXT,
  joined_date   DATE NOT NULL DEFAULT CURRENT_DATE,
  status        TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'pending_invite', 'inactive')),
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.team_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Team members read"
  ON public.team_members FOR SELECT TO authenticated
  USING (
    user_id = auth.uid() OR
    EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = team_members.business_id AND b.owner_user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin')
  );

CREATE POLICY "Team members write"
  ON public.team_members FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = team_members.business_id AND b.owner_user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin')
  );

-- 5.2 Staff Attendance Tracking
CREATE TABLE IF NOT EXISTS public.staff_attendance (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id    UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  user_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date           DATE NOT NULL DEFAULT CURRENT_DATE,
  check_in_time  TIMESTAMPTZ,
  check_out_time TIMESTAMPTZ,
  status         TEXT NOT NULL DEFAULT 'present' CHECK (status IN ('present', 'late', 'absent', 'on_leave')),
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT staff_attendance_user_date_key UNIQUE (business_id, user_id, date)
);

ALTER TABLE public.staff_attendance ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Attendance read"
  ON public.staff_attendance FOR SELECT TO authenticated
  USING (
    user_id = auth.uid() OR
    EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = staff_attendance.business_id AND b.owner_user_id = auth.uid())
  );

CREATE POLICY "Attendance write"
  ON public.staff_attendance FOR ALL TO authenticated
  USING (
    user_id = auth.uid() OR
    EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = staff_attendance.business_id AND b.owner_user_id = auth.uid())
  );

-- 5.3 Staff Leave Requests
CREATE TABLE IF NOT EXISTS public.staff_leaves (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  leave_type  TEXT NOT NULL CHECK (leave_type IN ('Annual Leave', 'Medical Leave', 'Emergency Leave', 'Unpaid Leave')),
  start_date  DATE NOT NULL,
  end_date    DATE NOT NULL,
  days_count  INTEGER NOT NULL DEFAULT 1,
  reason      TEXT NOT NULL,
  status      TEXT NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending', 'Approved', 'Rejected')),
  approved_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.staff_leaves ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Leaves read and manage"
  ON public.staff_leaves FOR ALL TO authenticated
  USING (
    user_id = auth.uid() OR
    EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = staff_leaves.business_id AND b.owner_user_id = auth.uid())
  );

-- 5.4 Internal Business Announcements
CREATE TABLE IF NOT EXISTS public.business_announcements (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  author_id   UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  author_name TEXT NOT NULL DEFAULT 'Management',
  title       TEXT NOT NULL,
  body        TEXT NOT NULL,
  priority    TEXT NOT NULL DEFAULT 'Info' CHECK (priority IN ('Important', 'Info', 'Reminder', 'Notice')),
  is_pinned   BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.business_announcements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Announcements read"
  ON public.business_announcements FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.business_id = business_announcements.business_id AND tm.user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = business_announcements.business_id AND b.owner_user_id = auth.uid())
  );

CREATE POLICY "Announcements write"
  ON public.business_announcements FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = business_announcements.business_id AND b.owner_user_id = auth.uid()));


-- =========================================================================================
-- 6. RESERVATIONS & BOOKINGS LAYER (TEMPAHAN ENGINE)
-- =========================================================================================

CREATE TABLE IF NOT EXISTS public.bookings (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id      UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  customer_id      UUID REFERENCES public.users(id) ON DELETE SET NULL,
  staff_id         UUID REFERENCES public.team_members(id) ON DELETE SET NULL,
  customer_name    TEXT NOT NULL,
  service_name     TEXT NOT NULL,
  booking_date     DATE NOT NULL,
  booking_time     VARCHAR(20) NOT NULL,
  status           VARCHAR(50) NOT NULL DEFAULT 'holding' CHECK (status IN ('holding', 'pending', 'confirmed', 'completed', 'cancelled')),
  total_price      NUMERIC(10, 2) DEFAULT 0.00,
  pax              INTEGER NOT NULL DEFAULT 1,
  booking_metadata JSONB DEFAULT '{}'::jsonb,
  created_at       TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS staff_id UUID REFERENCES public.team_members(id) ON DELETE SET NULL;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS total_price NUMERIC(10, 2) DEFAULT 0.00;
DO $$ BEGIN
  ALTER TABLE public.bookings DROP CONSTRAINT IF EXISTS bookings_status_check;
  ALTER TABLE public.bookings ADD CONSTRAINT bookings_status_check CHECK (status IN ('holding', 'pending', 'confirmed', 'completed', 'cancelled'));
EXCEPTION WHEN OTHERS THEN NULL; END $$;

ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  DROP POLICY IF EXISTS "Public can view bookings for slot check" ON public.bookings;
  DROP POLICY IF EXISTS "Users can insert booking hold" ON public.bookings;
  DROP POLICY IF EXISTS "Users can update own booking" ON public.bookings;
  DROP POLICY IF EXISTS "Business owners can view and manage their bookings" ON public.bookings;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- Allow public read so real-time calendar can see taken slots
CREATE POLICY "Public can view bookings for slot check"
  ON public.bookings FOR SELECT USING (true);

-- Allow authenticated users to insert a hold
CREATE POLICY "Users can insert booking hold"
  ON public.bookings FOR INSERT TO authenticated WITH CHECK (true);

-- Customers can update/cancel their own bookings
CREATE POLICY "Users can update own booking"
  ON public.bookings FOR UPDATE TO authenticated
  USING (customer_id = auth.uid() OR (booking_metadata->>'customer_auth_id')::TEXT = auth.uid()::TEXT);

-- Business owners can manage all bookings for their business
CREATE POLICY "Business owners can view and manage their bookings"
  ON public.bookings FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = bookings.business_id AND b.owner_user_id = auth.uid()));


-- =========================================================================================
-- 7. DIGITAL WALLET & FINANCE LAYER (CUSTOMER WALLET)
-- =========================================================================================

-- 7.1 Customer Digital Wallet Transactions
CREATE TABLE IF NOT EXISTS public.wallet_transactions (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  type         VARCHAR(50) NOT NULL CHECK (type IN ('topup', 'payment', 'refund', 'withdrawal', 'earning')),
  amount       DECIMAL(10, 2) NOT NULL,
  reference_id TEXT,
  created_at   TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read own wallet transactions"
  ON public.wallet_transactions FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users insert own wallet transactions"
  ON public.wallet_transactions FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- 7.2 Customer Payment Methods (Cards, Banks, QR)
CREATE TABLE IF NOT EXISTS public.payment_methods (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  type        VARCHAR(50) NOT NULL CHECK (type IN ('card', 'bank', 'duitnow_qr')),
  is_primary  BOOLEAN DEFAULT FALSE,
  color_index INTEGER DEFAULT 0,
  holder_name VARCHAR(255),
  name        VARCHAR(255),
  details     VARCHAR(255),
  expiry      VARCHAR(10),
  created_at  TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.payment_methods ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own payment methods"
  ON public.payment_methods FOR ALL TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);


-- =========================================================================================
-- 8. PLATFORM BILLING & FEE LEDGER LAYER (ADMIN & MERCHANT)
-- =========================================================================================

-- 8.1 Platform Order Fee Tracking (Configurable % per business)
CREATE TABLE IF NOT EXISTS public.business_platform_transactions (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id          UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  customer_id          UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  order_id             UUID REFERENCES public.orders(id) ON DELETE SET NULL,
  booking_id           UUID REFERENCES public.bookings(id) ON DELETE SET NULL,
  amount               NUMERIC NOT NULL CHECK (amount >= 0),
  currency             TEXT NOT NULL DEFAULT 'MYR',
  platform_fee_percent NUMERIC NOT NULL DEFAULT 2.0, -- Configurable (can be altered per transaction/business)
  platform_fee_amount  NUMERIC NOT NULL CHECK (platform_fee_amount >= 0),
  status               TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'refunded', 'failed')),
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.business_platform_transactions ADD COLUMN IF NOT EXISTS booking_id UUID REFERENCES public.bookings(id) ON DELETE SET NULL;
ALTER TABLE public.business_platform_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Platform transactions read"
  ON public.business_platform_transactions FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = business_platform_transactions.business_id AND b.owner_user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin')
  );

-- 8.2 Monthly Billing Invoices
CREATE TABLE IF NOT EXISTS public.billing_invoices (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id            UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  billing_month          DATE NOT NULL,
  transaction_count      INTEGER NOT NULL DEFAULT 0,
  gross_volume           NUMERIC NOT NULL DEFAULT 0.0,
  transaction_fees_total NUMERIC NOT NULL DEFAULT 0.0,
  is_waived              BOOLEAN NOT NULL DEFAULT FALSE,
  amount_due             NUMERIC NOT NULL DEFAULT 0.0,
  status                 TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'unpaid', 'paid', 'waived', 'overdue')),
  transaction_volume     INT DEFAULT 0,
  gateway_id             TEXT,
  paid_at                TIMESTAMPTZ,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT billing_invoices_business_month_key UNIQUE (business_id, billing_month)
);

ALTER TABLE public.billing_invoices ADD COLUMN IF NOT EXISTS paid_at TIMESTAMPTZ;
DO $$ BEGIN
  ALTER TABLE public.billing_invoices DROP CONSTRAINT IF EXISTS billing_invoices_status_check;
  ALTER TABLE public.billing_invoices ADD CONSTRAINT billing_invoices_status_check CHECK (status IN ('draft', 'unpaid', 'paid', 'waived', 'overdue'));
EXCEPTION WHEN OTHERS THEN NULL; END $$;

ALTER TABLE public.billing_invoices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Invoices read and manage"
  ON public.billing_invoices FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = billing_invoices.business_id AND b.owner_user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin')
  );


-- =========================================================================================
-- 9. REAL-TIME CHAT & MESSAGING LAYER
-- =========================================================================================

CREATE TABLE IF NOT EXISTS public.conversations (
  id                     UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user1_id               UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  user2_id               UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  last_message           TEXT,
  last_message_sender_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  last_message_is_read   BOOLEAN DEFAULT FALSE,
  task_last_messages     JSONB DEFAULT '{}'::jsonb,
  task_unread_counts     JSONB DEFAULT '{}'::jsonb,
  updated_at             TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users view own conversations"
  ON public.conversations FOR SELECT TO authenticated
  USING (auth.uid() = user1_id OR auth.uid() = user2_id);

CREATE POLICY "Users insert own conversations"
  ON public.conversations FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user1_id OR auth.uid() = user2_id);

CREATE POLICY "Users update own conversations"
  ON public.conversations FOR UPDATE TO authenticated
  USING (auth.uid() = user1_id OR auth.uid() = user2_id);

-- Messages Table
CREATE TABLE IF NOT EXISTS public.messages (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  conversation_id  UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_id        UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  content          TEXT NOT NULL,
  image_url        TEXT,
  message_type     TEXT NOT NULL DEFAULT 'text',
  file_name        TEXT,
  file_size        INTEGER,
  reply_to_message JSONB,
  is_read          BOOLEAN DEFAULT FALSE,
  created_at       TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users view messages in own conversations"
  ON public.messages FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.conversations c WHERE c.id = messages.conversation_id AND (c.user1_id = auth.uid() OR c.user2_id = auth.uid())));

CREATE POLICY "Users insert messages in own conversations"
  ON public.messages FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = sender_id AND EXISTS (SELECT 1 FROM public.conversations c WHERE c.id = messages.conversation_id AND (c.user1_id = auth.uid() OR c.user2_id = auth.uid())));


-- =========================================================================================
-- 10. STORED PROCEDURES & RPC FUNCTIONS
-- =========================================================================================

-- 10.1 RPC: Wallet Top Up
CREATE OR REPLACE FUNCTION public.top_up_wallet(
  p_user_id UUID,
  p_amount DECIMAL
) RETURNS json AS $$
DECLARE
  new_balance DECIMAL;
BEGIN
  UPDATE public.users 
  SET user_balance = COALESCE(user_balance, 0) + p_amount 
  WHERE id = p_user_id 
  RETURNING user_balance INTO new_balance;

  INSERT INTO public.wallet_transactions (user_id, type, amount, reference_id)
  VALUES (p_user_id, 'topup', p_amount, 'MANUAL_TOPUP');

  RETURN json_build_object('success', true, 'new_balance', new_balance);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10.2 RPC: Wallet Withdrawal
CREATE OR REPLACE FUNCTION public.withdraw_wallet(
  p_user_id UUID,
  p_amount DECIMAL
) RETURNS json AS $$
DECLARE
  current_bal DECIMAL;
  new_balance DECIMAL;
BEGIN
  SELECT COALESCE(user_balance, 0) INTO current_bal 
  FROM public.users 
  WHERE id = p_user_id FOR UPDATE;
  
  IF current_bal < p_amount THEN
    RAISE EXCEPTION 'Insufficient balance. You have RM%, but RM% is required.', current_bal, p_amount;
  END IF;

  UPDATE public.users 
  SET user_balance = user_balance - p_amount 
  WHERE id = p_user_id 
  RETURNING user_balance INTO new_balance;

  INSERT INTO public.wallet_transactions (user_id, type, amount, reference_id)
  VALUES (p_user_id, 'withdrawal', -p_amount, 'BANK_WITHDRAWAL');

  RETURN json_build_object('success', true, 'new_balance', new_balance);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10.3 RPC: Update Conversation Message & Reset Unread Counts
CREATE OR REPLACE FUNCTION public.update_conversation_task_message(
  p_conversation_id UUID,
  p_sender_id UUID,
  p_message_content TEXT,
  p_gig_id UUID DEFAULT NULL
) RETURNS void AS $$
BEGIN
  UPDATE public.conversations
  SET 
    last_message = p_message_content,
    last_message_sender_id = p_sender_id,
    last_message_is_read = false,
    updated_at = NOW()
  WHERE id = p_conversation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10.4 RPC: Get Real Database Health Metrics (For Ngam Admin)
CREATE OR REPLACE FUNCTION public.get_db_health_metrics()
RETURNS json AS $$
DECLARE
  v_active_conn INT;
  v_max_conn INT;
  v_db_size BIGINT;
  v_cache_hit NUMERIC;
BEGIN
  SELECT count(*) INTO v_active_conn FROM pg_stat_activity WHERE state = 'active';
  SELECT setting::INT INTO v_max_conn FROM pg_settings WHERE name = 'max_connections';
  SELECT pg_database_size(current_database()) INTO v_db_size;

  SELECT 
    CASE WHEN (sum(heap_blks_hit) + sum(heap_blks_read)) > 0 
         THEN round((sum(heap_blks_hit)::numeric / (sum(heap_blks_hit) + sum(heap_blks_read))) * 100, 2)
         ELSE 99.5 
    END INTO v_cache_hit
  FROM pg_statio_user_tables;

  RETURN json_build_object(
    'active_connections', COALESCE(v_active_conn, 8),
    'max_connections', COALESCE(v_max_conn, 60),
    'db_size_bytes', COALESCE(v_db_size, 15000000),
    'cache_hit_rate', COALESCE(v_cache_hit, 99.5)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10.5 RPC: Auto-generate Monthly Invoices for Businesses
CREATE OR REPLACE FUNCTION public.generate_monthly_invoices(target_date DATE DEFAULT CURRENT_DATE)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  start_of_target_month DATE;
  end_of_target_month DATE;
  business_record RECORD;
  total_volume INT;
  total_fee NUMERIC;
  gross_vol NUMERIC;
  invoice_is_waived BOOLEAN;
BEGIN
  start_of_target_month := date_trunc('month', target_date - INTERVAL '1 month')::DATE;
  end_of_target_month := (date_trunc('month', target_date) - INTERVAL '1 day')::DATE;

  FOR business_record IN 
    SELECT id, created_at, status, platform_fee_percent 
    FROM public.businesses 
    WHERE status != 'suspended'
  LOOP
    SELECT 
      COALESCE(SUM(platform_fee_amount), 0),
      COALESCE(SUM(amount), 0),
      COUNT(id)
    INTO total_fee, gross_vol, total_volume
    FROM public.business_platform_transactions
    WHERE business_id = business_record.id
      AND created_at >= start_of_target_month
      AND created_at < (end_of_target_month + INTERVAL '1 day');
    
    -- 1 month grace period
    invoice_is_waived := (start_of_target_month < (business_record.created_at + INTERVAL '1 month'));

    IF total_fee > 0 THEN
      INSERT INTO public.billing_invoices (
        business_id, 
        billing_month, 
        gross_volume,
        transaction_fees_total,
        amount_due, 
        status, 
        is_waived,
        transaction_volume
      ) VALUES (
        business_record.id,
        start_of_target_month,
        gross_vol,
        total_fee,
        CASE WHEN invoice_is_waived THEN 0 ELSE total_fee END,
        CASE WHEN invoice_is_waived THEN 'waived' ELSE 'unpaid' END,
        invoice_is_waived,
        total_volume
      )
      ON CONFLICT (business_id, billing_month) DO NOTHING;
    END IF;
  END LOOP;
END;
$$;


-- =========================================================================================
-- 11. STORAGE BUCKETS SETUP
-- =========================================================================================

INSERT INTO storage.buckets (id, name, public) 
VALUES 
  ('avatars', 'avatars', true),
  ('chat_images', 'chat_images', true),
  ('business-assets', 'business-assets', true)
ON CONFLICT (id) DO NOTHING;

DO $$ BEGIN
  DROP POLICY IF EXISTS "Public View Avatars" ON storage.objects;
  DROP POLICY IF EXISTS "Auth Upload Avatars" ON storage.objects;
  DROP POLICY IF EXISTS "Public View Chat Images" ON storage.objects;
  DROP POLICY IF EXISTS "Auth Upload Chat Images" ON storage.objects;
  DROP POLICY IF EXISTS "Public View Business Assets" ON storage.objects;
  DROP POLICY IF EXISTS "Auth Upload Business Assets" ON storage.objects;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

CREATE POLICY "Public View Avatars" ON storage.objects FOR SELECT USING (bucket_id = 'avatars');
CREATE POLICY "Auth Upload Avatars" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'avatars');

CREATE POLICY "Public View Chat Images" ON storage.objects FOR SELECT USING (bucket_id = 'chat_images');
CREATE POLICY "Auth Upload Chat Images" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'chat_images');

CREATE POLICY "Public View Business Assets" ON storage.objects FOR SELECT USING (bucket_id = 'business-assets');
CREATE POLICY "Auth Upload Business Assets" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'business-assets');


-- =========================================================================================
-- 12. CENTRALIZED NOTIFICATIONS LAYER (NOTIFIKASI BERPUSAT)
-- =========================================================================================

CREATE TABLE IF NOT EXISTS public.notifications (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  business_id  UUID REFERENCES public.businesses(id) ON DELETE CASCADE,
  title        TEXT NOT NULL,
  message      TEXT NOT NULL,
  type         VARCHAR(50) NOT NULL DEFAULT 'tempahan' CHECK (type IN ('tempahan', 'pesanan', 'invois', 'sistem')),
  reference_id TEXT,
  is_read      BOOLEAN NOT NULL DEFAULT false,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
  DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

CREATE POLICY "Users can view own notifications"
  ON public.notifications FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can update own notifications"
  ON public.notifications FOR UPDATE TO authenticated
  USING (user_id = auth.uid());


-- =========================================================================================
-- 13. AUTOMATED DATABASE TRIGGERS (PLATFORM FEE & NOTIFIKASI)
-- =========================================================================================

-- 13.1 Auto-record 2% (configurable) platform fee when order is completed
CREATE OR REPLACE FUNCTION public.fn_auto_record_order_platform_fee()
RETURNS TRIGGER AS $$
DECLARE
  v_fee_percent NUMERIC := 2.0;
  v_fee_amount  NUMERIC := 0.0;
BEGIN
  IF NEW.status = 'completed' AND (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM 'completed') THEN
    SELECT COALESCE(platform_fee_percent, 2.0)
    INTO v_fee_percent
    FROM public.businesses
    WHERE id = NEW.business_id;

    v_fee_amount := ROUND((NEW.total * (v_fee_percent / 100.0)), 2);

    IF NOT EXISTS (SELECT 1 FROM public.business_platform_transactions WHERE order_id = NEW.id) THEN
      INSERT INTO public.business_platform_transactions (
        business_id,
        customer_id,
        order_id,
        amount,
        currency,
        platform_fee_percent,
        platform_fee_amount,
        status,
        created_at
      ) VALUES (
        NEW.business_id,
        NEW.customer_id,
        NEW.id,
        NEW.total,
        'MYR',
        v_fee_percent,
        v_fee_amount,
        'completed',
        NOW()
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_order_completed_platform_fee ON public.orders;
CREATE TRIGGER trg_order_completed_platform_fee
AFTER INSERT OR UPDATE OF status ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.fn_auto_record_order_platform_fee();


-- 13.2 Auto-record platform fee when tempahan (booking) is completed
CREATE OR REPLACE FUNCTION public.fn_auto_record_booking_platform_fee()
RETURNS TRIGGER AS $$
DECLARE
  v_fee_percent   NUMERIC := 2.0;
  v_fee_amount    NUMERIC := 0.0;
  v_booking_total NUMERIC := 0.0;
BEGIN
  IF NEW.status = 'completed' AND (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM 'completed') THEN
    IF NEW.total_price IS NOT NULL AND NEW.total_price > 0 THEN
      v_booking_total := NEW.total_price;
    ELSE
      BEGIN
        v_booking_total := COALESCE(
          REPLACE(NEW.booking_metadata->>'total_price', 'RM', '')::NUMERIC,
          0.0
        );
      EXCEPTION WHEN OTHERS THEN
        v_booking_total := 0.0;
      END;
    END IF;

    IF v_booking_total > 0 THEN
      SELECT COALESCE(platform_fee_percent, 2.0)
      INTO v_fee_percent
      FROM public.businesses
      WHERE id = NEW.business_id;

      v_fee_amount := ROUND((v_booking_total * (v_fee_percent / 100.0)), 2);

      IF NOT EXISTS (SELECT 1 FROM public.business_platform_transactions WHERE booking_id = NEW.id) THEN
        INSERT INTO public.business_platform_transactions (
          business_id,
          customer_id,
          booking_id,
          amount,
          currency,
          platform_fee_percent,
          platform_fee_amount,
          status,
          created_at
        ) VALUES (
          NEW.business_id,
          NEW.customer_id,
          NEW.id,
          v_booking_total,
          'MYR',
          v_fee_percent,
          v_fee_amount,
          'completed',
          NOW()
        );
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_booking_completed_platform_fee ON public.bookings;
CREATE TRIGGER trg_booking_completed_platform_fee
AFTER INSERT OR UPDATE OF status ON public.bookings
FOR EACH ROW
EXECUTE FUNCTION public.fn_auto_record_booking_platform_fee();


-- 13.3 Auto-notify business owner & assigned staff when new tempahan is created
CREATE OR REPLACE FUNCTION public.fn_notify_on_new_tempahan()
RETURNS TRIGGER AS $$
DECLARE
  v_owner_user_id UUID;
  v_staff_user_id UUID;
  v_notif_title   TEXT;
  v_notif_msg     TEXT;
BEGIN
  IF (NEW.status IN ('pending', 'confirmed')) AND (TG_OP = 'INSERT' OR (OLD.status = 'holding' AND NEW.status != 'holding')) THEN
    SELECT owner_user_id
    INTO v_owner_user_id
    FROM public.businesses
    WHERE id = NEW.business_id;

    v_notif_title := 'Tempahan Baru Diterima';
    v_notif_msg := 'Pelanggan ' || NEW.customer_name || ' telah membuat tempahan untuk ' || NEW.service_name || ' pada ' || TO_CHAR(NEW.booking_date, 'DD Mon YYYY') || ' (' || NEW.booking_time || ').';

    -- 1. Hantar notifikasi kepada pemilik kedai
    IF v_owner_user_id IS NOT NULL THEN
      INSERT INTO public.notifications (
        user_id,
        business_id,
        title,
        message,
        type,
        reference_id,
        created_at
      ) VALUES (
        v_owner_user_id,
        NEW.business_id,
        v_notif_title,
        v_notif_msg,
        'tempahan',
        NEW.id::TEXT,
        NOW()
      );
    END IF;

    -- 2. Hantar notifikasi kepada staf bertugas (jika staff_id dipilih)
    IF NEW.staff_id IS NOT NULL THEN
      SELECT user_id
      INTO v_staff_user_id
      FROM public.team_members
      WHERE id = NEW.staff_id;

      IF v_staff_user_id IS NOT NULL AND v_staff_user_id != v_owner_user_id THEN
        INSERT INTO public.notifications (
          user_id,
          business_id,
          title,
          message,
          type,
          reference_id,
          created_at
        ) VALUES (
          v_staff_user_id,
          NEW.business_id,
          'Tugasan Tempahan Baru',
          'Anda telah ditugaskan untuk tempahan ' || NEW.service_name || ' bagi pelanggan ' || NEW.customer_name || ' pada ' || TO_CHAR(NEW.booking_date, 'DD Mon YYYY') || ' (' || NEW.booking_time || ').',
          'tempahan',
          NEW.id::TEXT,
          NOW()
        );
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_notify_new_tempahan ON public.bookings;
CREATE TRIGGER trg_notify_new_tempahan
AFTER INSERT OR UPDATE OF status ON public.bookings
FOR EACH ROW
EXECUTE FUNCTION public.fn_notify_on_new_tempahan();


-- 13.4 Auto-sync Billplz paid invoice (reactivate business and notify owner)
CREATE OR REPLACE FUNCTION public.fn_sync_billplz_paid_invoice()
RETURNS TRIGGER AS $$
DECLARE
  v_owner_user_id UUID;
BEGIN
  IF NEW.status = 'paid' AND (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM 'paid') THEN
    IF NEW.paid_at IS NULL THEN
      NEW.paid_at := NOW();
    END IF;

    -- Aktifkan semula bisnes jika sebelum ini suspended kerana invois tertunggak
    UPDATE public.businesses
    SET status = 'active'
    WHERE id = NEW.business_id AND status = 'suspended';

    -- Beri notifikasi kepada pemilik bisnes
    SELECT owner_user_id INTO v_owner_user_id
    FROM public.businesses
    WHERE id = NEW.business_id;

    IF v_owner_user_id IS NOT NULL THEN
      INSERT INTO public.notifications (
        user_id,
        business_id,
        title,
        message,
        type,
        reference_id,
        created_at
      ) VALUES (
        v_owner_user_id,
        NEW.business_id,
        'Invois Billplz Disahkan',
        'Bayaran invois yuran platform anda sebanyak RM ' || ROUND(NEW.amount_due, 2) || ' telah disahkan. Akaun bisnes anda aktif sepenuhnya.',
        'invois',
        NEW.id::TEXT,
        NOW()
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_billplz_invoice_paid ON public.billing_invoices;
CREATE TRIGGER trg_billplz_invoice_paid
BEFORE INSERT OR UPDATE OF status ON public.billing_invoices
FOR EACH ROW
EXECUTE FUNCTION public.fn_sync_billplz_paid_invoice();


-- =========================================================================================
-- 14. REALTIME PUBLICATIONS
-- =========================================================================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'conversations') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'messages') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'businesses') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.businesses;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'business_products') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.business_products;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'bookings') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.bookings;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'orders') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'billing_invoices') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.billing_invoices;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'notifications') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END $$;

