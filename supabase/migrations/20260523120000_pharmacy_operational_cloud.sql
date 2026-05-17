-- KPMS operational data — multi-tenant cloud persistence (sales, inventory, purchases, AR/AP).
-- Client apps upsert via (tenant_id, client_id) for idempotent offline→cloud migration.

-- ─── Tenant helper (RLS) ─────────────────────────────────────────────────────

create or replace function public.kpms_my_tenant_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select p.tenant_id
  from public.profiles p
  where p.id = auth.uid()
    and p.tenant_id is not null
  limit 1;
$$;

revoke all on function public.kpms_my_tenant_id() from public;
grant execute on function public.kpms_my_tenant_id() to authenticated;

-- ─── Inventory (medicines) ───────────────────────────────────────────────────

create table if not exists public.pharmacy_inventory (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  client_id text not null,
  name text not null,
  expiry_date timestamptz,
  form_type text not null default 'tablet',
  custom_form_label text,
  quantity integer not null default 0,
  buying_price numeric(14, 4) not null default 0,
  selling_price numeric(14, 4) not null default 0,
  minimum_stock_alert integer not null default 0,
  batch_code text,
  barcode text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, client_id)
);

create index if not exists pharmacy_inventory_tenant_idx on public.pharmacy_inventory (tenant_id);
create index if not exists pharmacy_inventory_tenant_barcode_idx on public.pharmacy_inventory (tenant_id, barcode) where barcode is not null;

-- ─── Customers (debt / AR) ───────────────────────────────────────────────────

create table if not exists public.pharmacy_customers (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  client_id text not null,
  name text not null,
  phone_display text not null default '',
  phone_key text not null default '',
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, client_id),
  unique (tenant_id, phone_key)
);

create index if not exists pharmacy_customers_tenant_idx on public.pharmacy_customers (tenant_id);

-- ─── Suppliers ───────────────────────────────────────────────────────────────

create table if not exists public.pharmacy_suppliers (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  client_id text not null,
  name text not null,
  phone text not null default '',
  address text not null default '',
  notes text not null default '',
  balance_owed numeric(14, 4) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, client_id)
);

create index if not exists pharmacy_suppliers_tenant_idx on public.pharmacy_suppliers (tenant_id);

-- ─── Sales ───────────────────────────────────────────────────────────────────

create table if not exists public.pharmacy_sales (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  client_id text not null,
  invoice_number text not null,
  issued_at timestamptz not null,
  customer_name text not null default '',
  customer_phone text not null default '',
  payment_method text not null default '',
  cashier_name text not null default '',
  cashier_user_id uuid,
  subtotal numeric(14, 4) not null default 0,
  tax_rate numeric(8, 6) not null default 0,
  tax_amount numeric(14, 4) not null default 0,
  discount_amount numeric(14, 4) not null default 0,
  total numeric(14, 4) not null default 0,
  profit_at_sale numeric(14, 4) not null default 0,
  settlement_mode text not null default 'paidInFull',
  paid_toward_invoice numeric(14, 4) not null default 0,
  remaining_balance numeric(14, 4) not null default 0,
  debt_customer_client_id text,
  debt_customer_notes text not null default '',
  debt_ledger jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, client_id),
  unique (tenant_id, invoice_number)
);

create index if not exists pharmacy_sales_tenant_issued_idx on public.pharmacy_sales (tenant_id, issued_at desc);

create table if not exists public.pharmacy_sale_items (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  sale_client_id text not null,
  line_client_id text not null,
  medicine_client_id text not null,
  name text not null,
  quantity_sold integer not null default 0,
  quantity_returned integer not null default 0,
  unit_sell numeric(14, 4) not null default 0,
  unit_buy numeric(14, 4) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, sale_client_id, line_client_id)
);

create index if not exists pharmacy_sale_items_sale_idx on public.pharmacy_sale_items (tenant_id, sale_client_id);

create table if not exists public.pharmacy_sale_returns (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  client_id text not null,
  return_invoice_number text not null,
  original_invoice_number text not null,
  issued_at timestamptz not null,
  cashier_name text not null default '',
  reason text not null default 'other',
  notes text not null default '',
  lines jsonb not null default '[]'::jsonb,
  refund_total numeric(14, 4) not null default 0,
  profit_reduction numeric(14, 4) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, client_id),
  unique (tenant_id, return_invoice_number)
);

-- ─── Purchases ───────────────────────────────────────────────────────────────

create table if not exists public.pharmacy_purchases (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  client_id text not null,
  invoice_number text not null,
  issued_at timestamptz not null,
  supplier_client_id text not null,
  supplier_name text not null default '',
  supplier_phone text not null default '',
  supplier_address text not null default '',
  cashier_name text not null default '',
  notes text not null default '',
  subtotal numeric(14, 4) not null default 0,
  discount numeric(14, 4) not null default 0,
  tax_rate numeric(8, 6) not null default 0,
  tax_amount numeric(14, 4) not null default 0,
  grand_total numeric(14, 4) not null default 0,
  paid_amount numeric(14, 4) not null default 0,
  remaining_balance numeric(14, 4) not null default 0,
  settlement_mode text not null default 'paidInFull',
  payment_method text not null default '',
  return_credits_applied numeric(14, 4) not null default 0,
  returned_qty_by_medicine jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, client_id),
  unique (tenant_id, invoice_number)
);

create index if not exists pharmacy_purchases_tenant_issued_idx on public.pharmacy_purchases (tenant_id, issued_at desc);

create table if not exists public.pharmacy_purchase_items (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  purchase_client_id text not null,
  line_client_id text not null,
  medicine_client_id text not null,
  name text not null,
  form_type text not null default 'tablet',
  custom_form_label text,
  expiry_date timestamptz,
  quantity integer not null default 0,
  buying_price numeric(14, 4) not null default 0,
  selling_price numeric(14, 4) not null default 0,
  line_total numeric(14, 4) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, purchase_client_id, line_client_id)
);

create table if not exists public.pharmacy_purchase_returns (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  client_id text not null,
  return_invoice_number text not null,
  source_purchase_number text not null,
  issued_at timestamptz not null,
  supplier_name text not null default '',
  reason text not null default 'other',
  notes text not null default '',
  lines jsonb not null default '[]'::jsonb,
  total_credit_at_cost numeric(14, 4) not null default 0,
  credit_applied_to_invoice numeric(14, 4) not null default 0,
  supplier_balance_reduced numeric(14, 4) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, client_id)
);

-- ─── Transactions ledger (denormalized for reports) ──────────────────────────

create table if not exists public.pharmacy_transactions (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  client_id text not null,
  kind text not null,
  sort_at timestamptz not null,
  reference text not null,
  party text not null default '',
  amount numeric(14, 4) not null default 0,
  status text not null default '',
  staff_label text not null default '',
  payment_method text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, client_id)
);

create index if not exists pharmacy_transactions_tenant_sort_idx on public.pharmacy_transactions (tenant_id, sort_at desc);

-- ─── Staff activity (cloud mirror; primary log remains staff_activity_log) ───

create table if not exists public.pharmacy_staff_activity (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  client_id text,
  actor_id uuid references public.profiles (id) on delete set null,
  action text not null,
  entity_type text,
  entity_ref text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists pharmacy_staff_activity_tenant_created_idx on public.pharmacy_staff_activity (tenant_id, created_at desc);

-- ─── Notifications ───────────────────────────────────────────────────────────

create table if not exists public.pharmacy_notifications (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  client_id text not null,
  title text not null,
  body text not null default '',
  severity text not null default 'info',
  read_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, client_id)
);

create index if not exists pharmacy_notifications_tenant_unread_idx on public.pharmacy_notifications (tenant_id, created_at desc) where read_at is null;

-- ─── updated_at triggers ─────────────────────────────────────────────────────

create or replace function public.kpms_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'pharmacy_inventory',
    'pharmacy_customers',
    'pharmacy_suppliers',
    'pharmacy_sales',
    'pharmacy_sale_items',
    'pharmacy_sale_returns',
    'pharmacy_purchases',
    'pharmacy_purchase_items',
    'pharmacy_purchase_returns',
    'pharmacy_transactions',
    'pharmacy_notifications'
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

-- ─── RLS (tenant isolation) ──────────────────────────────────────────────────

alter table public.pharmacy_inventory enable row level security;
alter table public.pharmacy_customers enable row level security;
alter table public.pharmacy_suppliers enable row level security;
alter table public.pharmacy_sales enable row level security;
alter table public.pharmacy_sale_items enable row level security;
alter table public.pharmacy_sale_returns enable row level security;
alter table public.pharmacy_purchases enable row level security;
alter table public.pharmacy_purchase_items enable row level security;
alter table public.pharmacy_purchase_returns enable row level security;
alter table public.pharmacy_transactions enable row level security;
alter table public.pharmacy_staff_activity enable row level security;
alter table public.pharmacy_notifications enable row level security;

-- Macro-style policies per table
do $$
declare
  tbl text;
begin
  foreach tbl in array array[
    'pharmacy_inventory',
    'pharmacy_customers',
    'pharmacy_suppliers',
    'pharmacy_sales',
    'pharmacy_sale_items',
    'pharmacy_sale_returns',
    'pharmacy_purchases',
    'pharmacy_purchase_items',
    'pharmacy_purchase_returns',
    'pharmacy_transactions',
    'pharmacy_notifications'
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

drop policy if exists pharmacy_staff_activity_select on public.pharmacy_staff_activity;
create policy pharmacy_staff_activity_select on public.pharmacy_staff_activity
  for select to authenticated using (tenant_id = public.kpms_my_tenant_id());

drop policy if exists pharmacy_staff_activity_insert on public.pharmacy_staff_activity;
create policy pharmacy_staff_activity_insert on public.pharmacy_staff_activity
  for insert to authenticated with check (tenant_id = public.kpms_my_tenant_id());

grant select, insert, update, delete on table public.pharmacy_inventory to authenticated;
grant select, insert, update, delete on table public.pharmacy_customers to authenticated;
grant select, insert, update, delete on table public.pharmacy_suppliers to authenticated;
grant select, insert, update, delete on table public.pharmacy_sales to authenticated;
grant select, insert, update, delete on table public.pharmacy_sale_items to authenticated;
grant select, insert, update, delete on table public.pharmacy_sale_returns to authenticated;
grant select, insert, update, delete on table public.pharmacy_purchases to authenticated;
grant select, insert, update, delete on table public.pharmacy_purchase_items to authenticated;
grant select, insert, update, delete on table public.pharmacy_purchase_returns to authenticated;
grant select, insert, update, delete on table public.pharmacy_transactions to authenticated;
grant select, insert on table public.pharmacy_staff_activity to authenticated;
grant select, insert, update, delete on table public.pharmacy_notifications to authenticated;

-- Realtime (enable in Supabase Dashboard → Database → Publications if this block is skipped)
do $$
begin
  alter publication supabase_realtime add table public.pharmacy_inventory;
exception when others then null;
end $$;
do $$
begin
  alter publication supabase_realtime add table public.pharmacy_sales;
exception when others then null;
end $$;
do $$
begin
  alter publication supabase_realtime add table public.pharmacy_purchases;
exception when others then null;
end $$;
