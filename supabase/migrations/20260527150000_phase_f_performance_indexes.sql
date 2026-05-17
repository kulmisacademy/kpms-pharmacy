-- Phase F: production-scale indexes and query-friendly composites.
-- Safe to re-apply: all IF NOT EXISTS.

-- ─── Notifications (tenant feed; per-user read state is separate table) ────

create index if not exists pharmacy_notifications_tenant_created_idx
  on public.pharmacy_notifications (tenant_id, created_at desc);

-- Optional: filter reports that still use legacy row read_at
create index if not exists pharmacy_notifications_tenant_unread_legacy_idx
  on public.pharmacy_notifications (tenant_id, created_at desc)
  where read_at is null;

-- ─── Purchase line items (sale items already indexed in operational migration) ─

create index if not exists pharmacy_purchase_items_tenant_purchase_client_idx
  on public.pharmacy_purchase_items (tenant_id, purchase_client_id);

-- ─── Sale / purchase headers (time-range reports) ────────────────────────────

create index if not exists pharmacy_sales_tenant_created_idx
  on public.pharmacy_sales (tenant_id, created_at desc);

create index if not exists pharmacy_purchases_tenant_created_idx
  on public.pharmacy_purchases (tenant_id, created_at desc);

-- ─── Inventory / catalog search helpers ──────────────────────────────────────

create index if not exists pharmacy_inventory_tenant_medicine_name_idx
  on public.pharmacy_inventory (tenant_id, lower(name));

-- ─── Customers & suppliers (directory + finance) ─────────────────────────────

create index if not exists pharmacy_customers_tenant_name_idx
  on public.pharmacy_customers (tenant_id, lower(name));

create index if not exists pharmacy_suppliers_tenant_name_idx
  on public.pharmacy_suppliers (tenant_id, lower(name));

-- ─── Audit log (tenant history paging) ───────────────────────────────────────
-- pharmacy_audit_log_tenant_created_idx exists in enterprise extensions

create index if not exists pharmacy_audit_log_tenant_action_idx
  on public.pharmacy_audit_log (tenant_id, action, created_at desc);
