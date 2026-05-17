-- KPMS enterprise extensions: categories, expenses, barcodes, audit trail, analytics snapshots.
-- All tenant-scoped with RLS matching existing pharmacy_* pattern.

-- ─── Medicine categories (optional parent for hierarchy) ───────────────────

create table if not exists public.pharmacy_medicine_categories (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  client_id text not null,
  name text not null,
  parent_client_id text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, client_id)
);

create index if not exists pharmacy_medicine_categories_tenant_idx
  on public.pharmacy_medicine_categories (tenant_id);

-- ─── Expenses ──────────────────────────────────────────────────────────────

create table if not exists public.pharmacy_expenses (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  client_id text not null,
  category text not null default 'general',
  amount numeric(14, 4) not null,
  note text not null default '',
  issued_at timestamptz not null,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, client_id)
);

create index if not exists pharmacy_expenses_tenant_issued_idx
  on public.pharmacy_expenses (tenant_id, issued_at desc);

-- ─── Barcode registry (extra barcodes per medicine SKU) ────────────────────

create table if not exists public.pharmacy_product_barcodes (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  client_id text not null,
  barcode text not null,
  medicine_client_id text not null,
  label text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, client_id),
  unique (tenant_id, barcode)
);

create index if not exists pharmacy_product_barcodes_medicine_idx
  on public.pharmacy_product_barcodes (tenant_id, medicine_client_id);

-- ─── Append-only audit log (compliance / security) ────────────────────────

create table if not exists public.pharmacy_audit_log (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  actor_id uuid references public.profiles (id) on delete set null,
  action text not null,
  entity_type text not null default '',
  entity_ref text not null default '',
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists pharmacy_audit_log_tenant_created_idx
  on public.pharmacy_audit_log (tenant_id, created_at desc);

-- ─── Daily analytics cache (optional server-side rollups for dashboards) ───

create table if not exists public.pharmacy_analytics_daily (
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  day date not null,
  gross_sales numeric(14, 4) not null default 0,
  net_profit numeric(14, 4) not null default 0,
  invoice_count integer not null default 0,
  return_count integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key (tenant_id, day)
);

create index if not exists pharmacy_analytics_daily_tenant_day_idx
  on public.pharmacy_analytics_daily (tenant_id, day desc);

-- ─── updated_at triggers (reuse kpms_set_updated_at) ──────────────────────

do $$
declare
  t text;
begin
  foreach t in array array[
    'pharmacy_medicine_categories',
    'pharmacy_expenses',
    'pharmacy_product_barcodes'
  ]
  loop
    execute format('drop trigger if exists kpms_set_updated_at on public.%I', t);
    execute format(
      'create trigger kpms_set_updated_at before update on public.%I for each row execute procedure public.kpms_set_updated_at()',
      t
    );
  end loop;
end;
$$;

drop trigger if exists kpms_analytics_daily_updated_at on public.pharmacy_analytics_daily;
create trigger kpms_analytics_daily_updated_at
  before update on public.pharmacy_analytics_daily
  for each row execute procedure public.kpms_set_updated_at();

-- ─── RLS ───────────────────────────────────────────────────────────────────

alter table public.pharmacy_medicine_categories enable row level security;
alter table public.pharmacy_expenses enable row level security;
alter table public.pharmacy_product_barcodes enable row level security;
alter table public.pharmacy_analytics_daily enable row level security;

alter table public.pharmacy_audit_log enable row level security;

do $$
declare
  tbl text;
begin
  foreach tbl in array array[
    'pharmacy_medicine_categories',
    'pharmacy_expenses',
    'pharmacy_product_barcodes',
    'pharmacy_analytics_daily'
  ]
  loop
    execute format('drop policy if exists %I_select on public.%I', tbl, tbl);
    execute format('drop policy if exists %I_insert on public.%I', tbl, tbl);
    execute format('drop policy if exists %I_update on public.%I', tbl, tbl);
    execute format('drop policy if exists %I_delete on public.%I', tbl, tbl);

    execute format(
      'create policy %I_select on public.%I for select to authenticated using (tenant_id = public.kpms_my_tenant_id())',
      tbl, tbl
    );
    execute format(
      'create policy %I_insert on public.%I for insert to authenticated with check (tenant_id = public.kpms_my_tenant_id())',
      tbl, tbl
    );
    execute format(
      'create policy %I_update on public.%I for update to authenticated using (tenant_id = public.kpms_my_tenant_id()) with check (tenant_id = public.kpms_my_tenant_id())',
      tbl, tbl
    );
    execute format(
      'create policy %I_delete on public.%I for delete to authenticated using (tenant_id = public.kpms_my_tenant_id())',
      tbl, tbl
    );
  end loop;
end;
$$;

drop policy if exists pharmacy_audit_log_select on public.pharmacy_audit_log;
create policy pharmacy_audit_log_select on public.pharmacy_audit_log
  for select to authenticated using (tenant_id = public.kpms_my_tenant_id());

drop policy if exists pharmacy_audit_log_insert on public.pharmacy_audit_log;
create policy pharmacy_audit_log_insert on public.pharmacy_audit_log
  for insert to authenticated with check (tenant_id = public.kpms_my_tenant_id());

-- Append-only for app users: no update/delete

grant select, insert, update, delete on table public.pharmacy_medicine_categories to authenticated;
grant select, insert, update, delete on table public.pharmacy_expenses to authenticated;
grant select, insert, update, delete on table public.pharmacy_product_barcodes to authenticated;
grant select, insert, update, delete on table public.pharmacy_analytics_daily to authenticated;
grant select, insert on table public.pharmacy_audit_log to authenticated;

-- Realtime (best-effort; ignore if publication already contains table)
do $$
begin
  alter publication supabase_realtime add table public.pharmacy_notifications;
exception when duplicate_object then null;
when others then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.pharmacy_expenses;
exception when duplicate_object then null;
when others then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.pharmacy_analytics_daily;
exception when duplicate_object then null;
when others then null;
end $$;
