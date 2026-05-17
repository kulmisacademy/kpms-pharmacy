-- KPMS core schema: tenants, profiles, subscriptions + RLS + auth hook.
-- Apply via Supabase Dashboard (SQL) or: supabase db push

-- Extensions (gen_random_uuid)
create extension if not exists "pgcrypto";

-- ─── Tenants (pharmacies) ───────────────────────────────────────────────────
create table if not exists public.tenants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  address text,
  phone text,
  license_number text,
  owner_name text,
  created_at timestamptz not null default now()
);

-- RLS on tenants is applied after `profiles` exists (policy references profiles).

-- ─── Profiles (1:1 with auth.users) ───────────────────────────────────────
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  tenant_id uuid references public.tenants (id) on delete set null,
  full_name text,
  role text not null default 'pharmacist',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists profiles_tenant_id_idx on public.profiles (tenant_id);

alter table public.profiles enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
  on public.profiles
  for select
  to authenticated
  using (id = auth.uid());

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles
  for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- ─── Subscriptions (stub per PRD) ───────────────────────────────────────────
create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  plan text not null default 'starter',
  status text not null default 'active',
  created_at timestamptz not null default now()
);

create index if not exists subscriptions_tenant_id_idx on public.subscriptions (tenant_id);

alter table public.subscriptions enable row level security;

drop policy if exists "subscriptions_select_tenant" on public.subscriptions;
create policy "subscriptions_select_tenant"
  on public.subscriptions
  for select
  to authenticated
  using (
    tenant_id in (
      select p.tenant_id from public.profiles p where p.id = auth.uid() and p.tenant_id is not null
    )
  );

-- ─── Tenants RLS (depends on profiles) ─────────────────────────────────────
alter table public.tenants enable row level security;

drop policy if exists "tenants_select_member" on public.tenants;
create policy "tenants_select_member"
  on public.tenants
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.tenant_id = tenants.id
    )
  );

-- ─── New auth user → profile row ───────────────────────────────────────────
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data->>'full_name'), ''),
      split_part(new.email, '@', 1)
    )
  )
  on conflict (id) do nothing;
  return NEW;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ─── RPC: attach pharmacy (tenant) to current user ──────────────────────────
create or replace function public.register_pharmacy(
  p_name text,
  p_address text,
  p_phone text,
  p_license text,
  p_owner text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant uuid;
  v_n int;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if nullif(trim(p_name), '') is null then
    raise exception 'Pharmacy name is required';
  end if;

  insert into public.tenants (name, address, phone, license_number, owner_name)
  values (
    nullif(trim(p_name), ''),
    nullif(trim(p_address), ''),
    nullif(trim(p_phone), ''),
    nullif(trim(p_license), ''),
    nullif(trim(p_owner), '')
  )
  returning id into v_tenant;

  if v_tenant is null then
    raise exception 'Failed to create tenant';
  end if;

  update public.profiles
  set
    tenant_id = v_tenant,
    full_name = coalesce(nullif(trim(p_owner), ''), full_name),
    updated_at = now()
  where id = auth.uid();

  get diagnostics v_n = row_count;
  if v_n = 0 then
    raise exception 'Profile row missing; sign up again or contact support';
  end if;

  insert into public.subscriptions (tenant_id, plan, status)
  values (v_tenant, 'starter', 'active');

  return v_tenant;
end;
$$;

grant execute on function public.register_pharmacy(text, text, text, text, text) to authenticated;

grant select on table public.tenants to authenticated;
grant select, update on table public.profiles to authenticated;
grant select on table public.subscriptions to authenticated;
