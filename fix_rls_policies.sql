-- =========================================================================================
-- FAIL INI TELAH DIKEMASKINI DENGAN TAHAP KESELAMATAN KUKUH (HARDENED RLS)
-- Sila rujuk skrip penuh sistem di: C:\Project\supabase_rls_hardening.sql
-- =========================================================================================

-- Buang polisi lama yang tidak selamat (WITH CHECK true / USING true)
DO $$ BEGIN
  DROP POLICY IF EXISTS "Business owners can insert their products" ON public.business_products;
  DROP POLICY IF EXISTS "Business owners can update their products" ON public.business_products;
  DROP POLICY IF EXISTS "Business owners can delete their products" ON public.business_products;
  DROP POLICY IF EXISTS "Public can view active products" ON public.business_products;
  DROP POLICY IF EXISTS "Owners manage products" ON public.business_products;
  DROP POLICY IF EXISTS "Products select policy" ON public.business_products;
  DROP POLICY IF EXISTS "Products insert policy" ON public.business_products;
  DROP POLICY IF EXISTS "Products update policy" ON public.business_products;
  DROP POLICY IF EXISTS "Products delete policy" ON public.business_products;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- 1. Pelanggan boleh lihat produk aktif; Pemilik/staf boleh lihat semua produk kedai mereka
CREATE POLICY "Products select policy"
  ON public.business_products FOR SELECT
  USING (
    is_active = true OR 
    EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = business_products.shop_id AND b.owner_user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.business_id = business_products.shop_id AND tm.user_id = auth.uid() AND tm.status = 'active') OR
    EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin')
  );

-- 2. HANYA Pemilik Kedai atau Pengurus/Super Admin boleh cipta produk
CREATE POLICY "Products insert policy"
  ON public.business_products FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = business_products.shop_id AND b.owner_user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.business_id = business_products.shop_id AND tm.user_id = auth.uid() AND tm.role IN ('tenant_admin', 'manager') AND tm.status = 'active') OR
    EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin')
  );

-- 3. HANYA Pemilik Kedai atau Pengurus/Super Admin boleh kemaskini produk kedai mereka sendiri
CREATE POLICY "Products update policy"
  ON public.business_products FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = business_products.shop_id AND b.owner_user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.business_id = business_products.shop_id AND tm.user_id = auth.uid() AND tm.role IN ('tenant_admin', 'manager') AND tm.status = 'active') OR
    EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = business_products.shop_id AND b.owner_user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.business_id = business_products.shop_id AND tm.user_id = auth.uid() AND tm.role IN ('tenant_admin', 'manager') AND tm.status = 'active') OR
    EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin')
  );

-- 4. HANYA Pemilik Kedai atau Pengurus/Super Admin boleh padam produk kedai mereka sendiri
CREATE POLICY "Products delete policy"
  ON public.business_products FOR DELETE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = business_products.shop_id AND b.owner_user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.business_id = business_products.shop_id AND tm.user_id = auth.uid() AND tm.role IN ('tenant_admin', 'manager') AND tm.status = 'active') OR
    EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin')
  );
