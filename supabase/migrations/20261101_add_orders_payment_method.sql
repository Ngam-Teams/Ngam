-- =========================================================================================
-- MIGRATION: Add payment_method and payment_splits to public.orders
-- =========================================================================================

-- 1. Tambah kolum payment_method dan payment_splits jika belum wujud
ALTER TABLE public.orders 
  ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'cash',
  ADD COLUMN IF NOT EXISTS payment_splits JSONB DEFAULT '[]'::jsonb;

-- 2. Pastikan CHECK constraint untuk source menyokong pesanan online, pos, table, dan pre_order
DO $$
BEGIN
  -- Gugurkan kekangan CHECK sedia ada jika terlalu ketat
  ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_source_check;
  
  -- Tambah kekangan CHECK baru yang lebih fleksibel
  ALTER TABLE public.orders 
    ADD CONSTRAINT orders_source_check 
    CHECK (source IN ('pos', 'online', 'table', 'pre_order', 'takeaway'));
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END $$;

-- 3. Muat semula schema cache PostgREST dalam Supabase
NOTIFY pgrst, 'reload schema';
