-- Realtime publication completeness fix.
--
-- The Flutter client (PharmacyWorkspaceRealtimeHost) subscribes to postgres_changes
-- on every workspace table, but several of them were never added to the
-- `supabase_realtime` publication. Without publication membership Postgres emits no
-- replication events for those tables, so the subscriptions are silent — customers,
-- suppliers, categories, barcodes, returns and per-line item changes never reach
-- other devices in real time. This adds the missing tables idempotently.
--
-- RLS still governs which rows each subscriber receives (tenant_id = kpms_my_tenant_id()),
-- so this does not weaken tenant isolation.

-- REPLICA IDENTITY FULL: workspace tables key rows by (tenant_id, client_id), not by
-- the `id` primary key. With the default replica identity, realtime DELETE events only
-- carry the primary key in `oldRecord`, so the client cannot read tenant_id/client_id —
-- the tenant_id channel filter drops the event and the reconciler's delete handlers bail
-- out (no client_id). FULL makes the full old row available so deletes propagate and stay
-- tenant-scoped. (No-op for tables already FULL.)
do $$
declare
  tbl text;
begin
  foreach tbl in array array[
    'pharmacy_inventory',
    'pharmacy_sales',
    'pharmacy_sale_items',
    'pharmacy_sale_returns',
    'pharmacy_purchases',
    'pharmacy_purchase_items',
    'pharmacy_purchase_returns',
    'pharmacy_customers',
    'pharmacy_suppliers',
    'pharmacy_expenses',
    'pharmacy_medicine_categories',
    'pharmacy_product_barcodes',
    'pharmacy_staff_activity'
  ]
  loop
    begin
      execute format('alter table public.%I replica identity full', tbl);
    exception
      when undefined_table then null;
    end;
  end loop;
end;
$$;

do $$
declare
  tbl text;
begin
  foreach tbl in array array[
    'pharmacy_sale_items',
    'pharmacy_sale_returns',
    'pharmacy_purchase_items',
    'pharmacy_purchase_returns',
    'pharmacy_customers',
    'pharmacy_suppliers',
    'pharmacy_medicine_categories',
    'pharmacy_product_barcodes',
    'pharmacy_staff_activity'
  ]
  loop
    -- Skip tables already in the publication to stay idempotent across reruns.
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = tbl
    ) then
      begin
        execute format('alter publication supabase_realtime add table public.%I', tbl);
      exception
        when duplicate_object then null;
        when undefined_table then null;
      end;
    end if;
  end loop;
end;
$$;
