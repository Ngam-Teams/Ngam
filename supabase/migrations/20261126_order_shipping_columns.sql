-- ==============================================================================
-- ORDER: ADD SHIPPING_FEE AND SHIPPING_SERVICE_ID TO ORDERS
-- Tarikh : 2026-11-26
-- Fail   : 20261126_order_shipping_columns.sql
-- ==============================================================================
-- Asingkan kos penghantaran kurier daripada hasil jualan produk supaya laporan
-- jualan & payout peniaga lebih tepat, serta simpan service_id & courier_id untuk
-- fungsi 1-klik "Atur Penghantaran & Cetak AWB".

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS shipping_fee NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS shipping_service_id TEXT,
  ADD COLUMN IF NOT EXISTS shipping_courier_id TEXT;

COMMENT ON COLUMN public.orders.shipping_fee IS 'Courier postage paid by customer (RM), separated from merchant product sales for payout calculation';
COMMENT ON COLUMN public.orders.shipping_service_id IS 'EasyParcel service_id chosen at customer checkout for 1-click AWB arrangement';
COMMENT ON COLUMN public.orders.shipping_courier_id IS 'EasyParcel courier_id chosen at customer checkout';

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
