-- Phase E: enterprise RBAC extensions, device sessions, permission revocation nonce,
-- profile realtime, expanded staff roles (tenant-scoped).

-- ─── Profiles ───────────────────────────────────────────────────────────────

alter table public.profiles
  add column if not exists avatar_url text;

alter table public.profiles
  add column if not exists created_by uuid references auth.users (id) on delete set null;

alter table public.profiles
  add column if not exists must_change_password boolean not null default false;

alter table public.profiles
  add column if not exists permission_revoke_nonce bigint not null default 0;

-- Bump nonce when auth-sensitive profile fields change (per-user row only).
create or replace function public.kpms_profiles_bump_revoke_nonce()
returns trigger
language plpgsql
as $$
begin
  if tg_op <> 'UPDATE' then
    return new;
  end if;
  if new.role is distinct from old.role
     or new.permissions is distinct from old.permissions
     or new.staff_status is distinct from old.staff_status
  then
    new.permission_revoke_nonce := coalesce(old.permission_revoke_nonce, 0) + 1;
  end if;
  return new;
end;
$$;

drop trigger if exists kpms_profiles_bump_revoke_nonce_trg on public.profiles;
create trigger kpms_profiles_bump_revoke_nonce_trg
  before update on public.profiles
  for each row execute function public.kpms_profiles_bump_revoke_nonce();

-- ─── Device / session registry (tenant-isolated, RLS) ────────────────────────

create table if not exists public.pharmacy_staff_device_sessions (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  device_id text not null,
  platform text not null default 'android',
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  unique (user_id, device_id)
);

create index if not exists pharmacy_staff_device_sessions_tenant_idx
  on public.pharmacy_staff_device_sessions (tenant_id, user_id);

alter table public.pharmacy_staff_device_sessions enable row level security;

drop policy if exists pharmacy_staff_device_sessions_select on public.pharmacy_staff_device_sessions;
create policy pharmacy_staff_device_sessions_select on public.pharmacy_staff_device_sessions
  for select to authenticated
  using (tenant_id = public.kpms_my_tenant_id());

drop policy if exists pharmacy_staff_device_sessions_ins on public.pharmacy_staff_device_sessions;
create policy pharmacy_staff_device_sessions_ins on public.pharmacy_staff_device_sessions
  for insert to authenticated
  with check (tenant_id = public.kpms_my_tenant_id() and user_id = auth.uid());

drop policy if exists pharmacy_staff_device_sessions_upd on public.pharmacy_staff_device_sessions;
create policy pharmacy_staff_device_sessions_upd on public.pharmacy_staff_device_sessions
  for update to authenticated
  using (tenant_id = public.kpms_my_tenant_id() and user_id = auth.uid())
  with check (tenant_id = public.kpms_my_tenant_id() and user_id = auth.uid());

grant select, insert, update on table public.pharmacy_staff_device_sessions to authenticated;

-- ─── RPC: register / heartbeat this device ───────────────────────────────────

create or replace function public.kpms_register_staff_device_session(p_device_id text, p_platform text default 'android')
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant uuid;
  v_uid uuid := auth.uid();
  v_did text := nullif(trim(coalesce(p_device_id, '')), '');
  v_row public.pharmacy_staff_device_sessions%rowtype;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  if v_did is null then
    raise exception 'device_id required';
  end if;

  select tenant_id into v_tenant from public.profiles where id = v_uid;
  if v_tenant is null then
    raise exception 'No tenant';
  end if;

  insert into public.pharmacy_staff_device_sessions as s (
    tenant_id, user_id, device_id, platform, last_seen_at, revoked_at
  )
  values (
    v_tenant, v_uid, v_did, lower(trim(coalesce(p_platform, 'android'))), now(), null
  )
  on conflict (user_id, device_id) do update
    set last_seen_at = now(),
        revoked_at = null,
        platform = excluded.platform
  returning * into v_row;

  return v_row.id;
end;
$$;

revoke all on function public.kpms_register_staff_device_session(text, text) from public;
grant execute on function public.kpms_register_staff_device_session(text, text) to authenticated;

-- ─── RPC: list own device sessions ───────────────────────────────────────────

create or replace function public.kpms_list_my_device_sessions()
returns setof public.pharmacy_staff_device_sessions
language sql
stable
security definer
set search_path = public
as $$
  select *
  from public.pharmacy_staff_device_sessions s
  where s.user_id = auth.uid()
    and s.tenant_id = public.kpms_my_tenant_id()
  order by s.last_seen_at desc
  limit 50;
$$;

revoke all on function public.kpms_list_my_device_sessions() from public;
grant execute on function public.kpms_list_my_device_sessions() to authenticated;

-- ─── RPC: revoke one session (self or tenant admin) ─────────────────────────

create or replace function public.kpms_revoke_staff_device_session(p_session_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_my_tenant uuid;
  v_my_role text;
  v_manage boolean;
  v_target public.pharmacy_staff_device_sessions%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select tenant_id, role, coalesce((permissions->>'manage_staff')::boolean, false)
  into v_my_tenant, v_my_role, v_manage
  from public.profiles where id = auth.uid();

  select * into v_target
  from public.pharmacy_staff_device_sessions
  where id = p_session_id;

  if not found then
    raise exception 'Not found';
  end if;

  if v_target.tenant_id is distinct from v_my_tenant then
    raise exception 'Forbidden';
  end if;

  if v_target.user_id = auth.uid() then
    update public.pharmacy_staff_device_sessions
    set revoked_at = now()
    where id = p_session_id;
    return;
  end if;

  if v_my_role not in ('pharmacy_owner', 'pharmacist', 'pharmacy_admin') and not v_manage then
    raise exception 'Forbidden';
  end if;

  update public.pharmacy_staff_device_sessions
  set revoked_at = now()
  where id = p_session_id;
end;
$$;

revoke all on function public.kpms_revoke_staff_device_session(uuid) from public;
grant execute on function public.kpms_revoke_staff_device_session(uuid) to authenticated;

-- ─── RPC: force logout staff member (nonce + revoke open sessions) ───────────

create or replace function public.kpms_force_logout_staff_member(p_staff_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_my_tenant uuid;
  v_my_role text;
  v_manage boolean;
  v_target_tenant uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select tenant_id, role, coalesce((permissions->>'manage_staff')::boolean, false)
  into v_my_tenant, v_my_role, v_manage
  from public.profiles where id = auth.uid();

  if v_my_tenant is null or (v_my_role not in ('pharmacy_owner', 'pharmacist', 'pharmacy_admin') and not v_manage) then
    raise exception 'Forbidden';
  end if;

  if p_staff_id = auth.uid() then
    raise exception 'Use sign out';
  end if;

  select tenant_id into v_target_tenant from public.profiles where id = p_staff_id;
  if v_target_tenant is distinct from v_my_tenant then
    raise exception 'Forbidden';
  end if;

  update public.profiles
  set permission_revoke_nonce = coalesce(permission_revoke_nonce, 0) + 1,
      updated_at = now()
  where id = p_staff_id;

  update public.pharmacy_staff_device_sessions
  set revoked_at = now()
  where user_id = p_staff_id and tenant_id = v_my_tenant and revoked_at is null;
end;
$$;

revoke all on function public.kpms_force_logout_staff_member(uuid) from public;
grant execute on function public.kpms_force_logout_staff_member(uuid) to authenticated;

-- ─── Permission profile RPC ─────────────────────────────────────────────────

create or replace function public.kpms_my_permission_profile()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  (
    select jsonb_build_object(
      'role', p.role,
      'tenant_id', p.tenant_id,
      'permissions', coalesce(p.permissions, '{}'::jsonb),
      'staff_status', coalesce(p.staff_status, 'active'),
      'permission_revoke_nonce', coalesce(p.permission_revoke_nonce, 0),
      'must_change_password', coalesce(p.must_change_password, false),
      'avatar_url', p.avatar_url
    )
    from public.profiles p
    where p.id = auth.uid()
    limit 1
  );
$$;

revoke all on function public.kpms_my_permission_profile() from public;
grant execute on function public.kpms_my_permission_profile() to authenticated;

-- ─── staff_invitations policies: include pharmacy_admin ─────────────────────

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
        and p.role in ('pharmacy_owner', 'pharmacist', 'pharmacy_admin')
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
        and p.role in ('pharmacy_owner', 'pharmacist', 'pharmacy_admin')
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
        and p.role in ('pharmacy_owner', 'pharmacist', 'pharmacy_admin')
    )
  );

-- ─── Invitations / staff update: expanded roles ────────────────────────────

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
  v_can_manage boolean;
  v_staff_role text := lower(trim(coalesce(p_role, '')));
  v_allowed boolean;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select tenant_id, role,
    coalesce((permissions->>'manage_staff')::boolean, false)
  into v_tenant, v_role, v_can_manage
  from public.profiles where id = auth.uid();

  if v_tenant is null or (v_role not in ('pharmacy_owner', 'pharmacist', 'pharmacy_admin') and not v_can_manage) then
    raise exception 'Only authorized managers can invite staff';
  end if;

  if v_email !~ '^[^@]+@[^@]+\.[^@]+$' then
    raise exception 'Invalid email';
  end if;

  v_allowed := v_staff_role in (
    'staff', 'cashier', 'pharmacist', 'manager', 'pharmacy_admin',
    'accountant', 'inventory_manager', 'clinical_pharmacist'
  );
  if not v_allowed then
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
    v_staff_role,
    coalesce(p_permissions, '{}'::jsonb),
    auth.uid()
  )
  returning token into v_token;

  return v_token;
end;
$$;

grant execute on function public.create_staff_invitation(text, text, text, text, jsonb) to authenticated;

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
    must_change_password = true,
    updated_at = now()
  where id = auth.uid();

  delete from public.staff_invitations where id = inv.id;
end;
$$;

grant execute on function public.claim_staff_invitation(text) to authenticated;

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
  v_my_manage boolean;
  v_target_tenant uuid;
  v_target_role text;
  v_role text := lower(trim(coalesce(p_role, '')));
  v_status text := lower(trim(coalesce(p_staff_status, '')));
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select tenant_id, role,
    coalesce((permissions->>'manage_staff')::boolean, false)
  into v_my_tenant, v_my_role, v_my_manage
  from public.profiles where id = auth.uid();

  if v_my_tenant is null or (v_my_role not in ('pharmacy_owner', 'pharmacist', 'pharmacy_admin') and not v_my_manage) then
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

  if v_my_manage and v_my_role not in ('pharmacy_owner', 'pharmacist', 'pharmacy_admin') and v_target_role in ('pharmacy_owner', 'pharmacist', 'pharmacy_admin') then
    raise exception 'Forbidden';
  end if;

  if v_role is not null and v_role <> '' then
    if v_role not in (
      'staff', 'cashier', 'pharmacist', 'manager', 'pharmacy_owner', 'pharmacy_admin',
      'accountant', 'inventory_manager', 'clinical_pharmacist'
    ) then
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

-- ─── Realtime: profiles + device sessions ────────────────────────────────────

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'profiles'
  ) then
    execute 'alter publication supabase_realtime add table public.profiles';
  end if;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'pharmacy_staff_device_sessions'
  ) then
    execute 'alter publication supabase_realtime add table public.pharmacy_staff_device_sessions';
  end if;
exception
  when duplicate_object then null;
end $$;
