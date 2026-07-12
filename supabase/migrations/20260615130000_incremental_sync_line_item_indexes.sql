-- Delta-sync indexes for line-item and return tables (incremental pull by updated_at).

create index if not exists pharmacy_sale_items_tenant_updated_idx
  on public.pharmacy_sale_items (tenant_id, updated_at desc);

create index if not exists pharmacy_sale_returns_tenant_updated_idx
  on public.pharmacy_sale_returns (tenant_id, updated_at desc);

create index if not exists pharmacy_purchase_items_tenant_updated_idx
  on public.pharmacy_purchase_items (tenant_id, updated_at desc);

create index if not exists pharmacy_purchase_returns_tenant_updated_idx
  on public.pharmacy_purchase_returns (tenant_id, updated_at desc);

create index if not exists pharmacy_medicine_categories_tenant_updated_idx
  on public.pharmacy_medicine_categories (tenant_id, updated_at desc);

create index if not exists pharmacy_product_barcodes_tenant_updated_idx
  on public.pharmacy_product_barcodes (tenant_id, updated_at desc);

create index if not exists pharmacy_expenses_tenant_updated_idx
  on public.pharmacy_expenses (tenant_id, updated_at desc);
