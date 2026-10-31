-- =========================================================================================
-- NGAM ECOSYSTEM: ORDER PAYMENT METHODS & MULTI-CHANNEL COMMERCE ENGINE
-- Menyokong kaedah bayaran pesanan (Cash, Splits) & pelbagai saluran (Online, Table, Pre-Order, POS)
-- =========================================================================================

-- 1. Tambah kolum payment_method dan payment_splits pada jadual orders jika belum wujud
ALTER TABLE public.orders 
  ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'cash',
  ADD COLUMN IF NOT EXISTS payment_splits JSONB DEFAULT '[]'::jsonb;

-- 2. Kemas kini kekangan CHECK source supaya menyokong semua saluran pesanan ekosistem Ngam
DO $$
BEGIN
  -- Gugurkan kekangan CHECK sedia ada jika terlalu terhad
  ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_source_check;
  
  -- Tambah kekangan CHECK fleksibel (pos, online, table, pre_order, takeaway)
  ALTER TABLE public.orders 
    ADD CONSTRAINT orders_source_check 
    CHECK (source IN ('pos', 'online', 'table', 'pre_order', 'takeaway'));
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END $$;

-- 3. Muat semula PostgREST schema cache untuk pengemaskinian serta-merta
NOTIFY pgrst, 'reload schema';
