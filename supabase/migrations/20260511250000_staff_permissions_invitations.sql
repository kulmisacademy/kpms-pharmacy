-- Staff directory, per-user JSON permissions, invitations, tenant-scoped RLS, admin RPCs.

-- ─── Profiles extensions ─────────────────────────────────────────────────────
alter table public.profiles
  add column if not exists phone text;

alter table public.profiles
  add column if not exists staff_status text not null default 'active';

alter table public.profiles
  add column if not exists permissions jsonb not null default '{}'::jsonb;

do $$
begin
  if not exists (
    select 1 from pg_constraint c
    join pg_class t on c.conrelid = t.oid
    where t.relname = 'profiles' and c.conname = 'profiles_staff_status_check'
  ) then
    alter table public.profiles
      add constraint profiles_staff_status_check
      check (staff_status in ('active', 'inactive'));
  end if;
end $$;

alter table public.profiles
  add column if not exists last_sign_in_at timestamptz;

-- ─── Invitations (staff completes signup then claims token) ─────────────────
create table if not exists public.staff_invitations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  email text not null,
  full_name text,
  phone text,
  role text not null default 'staff',
  permissions jsonb not null default '{}'::jsonb,
  token text not null unique default replace(gen_random_uuid()::text, '-', ''),
  expires_at timestamptz not null default (now() + interval '14 days'),
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists staff_invitations_tenant_idx on public.staff_invitations (tenant_id);
create index if not exists staff_invitations_token_idx on public.staff_invitations (token);

alter table public.staff_invitations enable row level security;

drop policy if exists "staff_invitations_select_admin" on public.staff_invitations;
create policy "staff_invitations_select_admin"
  on public.staff_invitations
  for select
  to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and p.tenant_id = staff_invitations.tenant_id
        and p.role in ('pharmacy_owner', 'pharmacist')
    )
  );

drop policy if exists "staff_invitations_insert_admin" on public.staff_invitations;
create policy "staff_invitations_insert_admin"
  on public.staff_invitations
  for insert
  to authenticated
  with check (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and p.tenant_id = staff_invitations.tenant_id
        and p.role in ('pharmacy_owner', 'pharmacist')
    )
  );

drop policy if exists "staff_invitations_delete_admin" on public.staff_invitations;
create policy "staff_invitations_delete_admin"
  on public.staff_invitations
  for delete
  to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and p.tenant_id = staff_invitations.tenant_id
        and p.role in ('pharmacy_owner', 'pharmacist')
    )
  );

grant select, insert, delete on table public.staff_invitations to authenticated;

-- ─── Profiles: see colleagues in same tenant (staff directory) ─────────────
drop policy if exists "profiles_select_tenant_peers" on public.profiles;
create policy "profiles_select_tenant_peers"
  on public.profiles
  for select
  to authenticated
  using (
    tenant_id is not null
    and tenant_id in (
      select p.tenant_id from public.profiles p where p.id = auth.uid() and p.tenant_id is not null
    )
  );

-- ─── RPC: create invitation (returns token for deep link) ──────────────────
create or replace function public.create_staff_invitation(
  p_email text,
  p_full_name text,
  p_phone text,
  p_role text,
  p_permissions jsonb
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant uuid;
  v_role text;
  v_token text;
  v_email text := lower(trim(coalesce(p_email, '')));
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select tenant_id, role into v_tenant, v_role
  from public.profiles where id = auth.uid();

  if v_tenant is null or v_role not in ('pharmacy_owner', 'pharmacist') then
    raise exception 'Only pharmacy admins can invite staff';
  end if;

  if v_email !~ '^[^@]+@[^@]+\.[^@]+$' then
    raise exception 'Invalid email';
  end if;

  if coalesce(trim(p_role), '') not in ('staff', 'cashier', 'pharmacist') then
    raise exception 'Invalid role';
  end if;

  insert into public.staff_invitations (
    tenant_id, email, full_name, phone, role, permissions, created_by
  )
  values (
    v_tenant,
    v_email,
    nullif(trim(coalesce(p_full_name, '')), ''),
    nullif(trim(coalesce(p_phone, '')), ''),
    lower(trim(p_role)),
    coalesce(p_permissions, '{}'::jsonb),
    auth.uid()
  )
  returning token into v_token;

  return v_token;
end;
$$;

grant execute on function public.create_staff_invitation(text, text, text, text, jsonb) to authenticated;

-- ─── RPC: claim invitation after new user has signed up & session exists ─
create or replace function public.claim_staff_invitation(p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  inv public.staff_invitations%rowtype;
  v_email text := lower(trim(coalesce(auth.jwt()->>'email', '')));
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select * into inv
  from public.staff_invitations
  where token = nullif(trim(p_token), '')
    and expires_at > now();

  if not found then
    raise exception 'Invalid or expired invitation';
  end if;

  if lower(inv.email) is distinct from v_email then
    raise exception 'Signed-in email does not match invitation';
  end if;

  update public.profiles
  set
    tenant_id = inv.tenant_id,
    role = inv.role,
    permissions = inv.permissions,
    full_name = coalesce(inv.full_name, full_name),
    phone = coalesce(inv.phone, phone),
    staff_status = 'active',
    updated_at = now()
  where id = auth.uid();

  delete from public.staff_invitations where id = inv.id;
end;
$$;

grant execute on function public.claim_staff_invitation(text) to authenticated;

-- Public peek (no auth): invitation email for join UI (token is secret).
create or replace function public.peek_staff_invitation(p_token text)
returns table(email text, full_name text)
language sql
security definer
set search_path = public
stable
as $$
  select i.email::text, coalesce(i.full_name, '')::text
  from public.staff_invitations i
  where i.token = nullif(trim(p_token), '')
    and i.expires_at > now()
  limit 1;
$$;

grant execute on function public.peek_staff_invitation(text) to anon, authenticated;

-- ─── RPC: pharmacy admin updates another profile in same tenant ────────────
create or replace function public.update_tenant_staff_profile(
  p_staff_id uuid,
  p_full_name text,
  p_phone text,
  p_staff_status text,
  p_permissions jsonb,
  p_role text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_my_tenant uuid;
  v_my_role text;
  v_target_tenant uuid;
  v_target_role text;
  v_role text := lower(trim(coalesce(p_role, '')));
  v_status text := lower(trim(coalesce(p_staff_status, '')));
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select tenant_id, role into v_my_tenant, v_my_role
  from public.profiles where id = auth.uid();

  if v_my_tenant is null or v_my_role not in ('pharmacy_owner', 'pharmacist') then
    raise exception 'Forbidden';
  end if;

  if p_staff_id = auth.uid() then
    raise exception 'Use profile settings for your own account';
  end if;

  select tenant_id, role into v_target_tenant, v_target_role
  from public.profiles where id = p_staff_id;

  if v_target_tenant is distinct from v_my_tenant then
    raise exception 'Forbidden';
  end if;

  if v_target_role = 'platform_super_admin' then
    raise exception 'Forbidden';
  end if;

  if v_my_role = 'pharmacist' and v_target_role = 'pharmacy_owner' then
    raise exception 'Forbidden';
  end if;

  if v_role is not null and v_role <> '' then
    if v_role not in ('staff', 'cashier', 'pharmacist', 'pharmacy_owner') then
      raise exception 'Invalid role';
    end if;
    if v_target_role = 'pharmacy_owner' and v_my_role <> 'pharmacy_owner' then
      raise exception 'Forbidden';
    end if;
  end if;

  if v_status is not null and v_status <> '' and v_status not in ('active', 'inactive') then
    raise exception 'Invalid status';
  end if;

  update public.profiles
  set
    full_name = case when p_full_name is null then full_name else nullif(trim(p_full_name), '') end,
    phone = case when p_phone is null then phone else nullif(trim(p_phone), '') end,
    staff_status = case when v_status = '' then staff_status when v_status in ('active', 'inactive') then v_status else staff_status end,
    permissions = coalesce(p_permissions, permissions),
    role = case when v_role = '' then role else v_role end,
    updated_at = now()
  where id = p_staff_id;
end;
$$;

grant execute on function public.update_tenant_staff_profile(uuid, text, text, text, jsonb, text) to authenticated;
