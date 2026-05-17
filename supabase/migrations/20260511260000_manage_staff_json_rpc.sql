-- Allow profiles.permissions.manage_staff = true to invite/update staff (same tenant),
-- in addition to pharmacy_owner / pharmacist roles.

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
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select tenant_id, role,
    coalesce((permissions->>'manage_staff')::boolean, false)
  into v_tenant, v_role, v_can_manage
  from public.profiles where id = auth.uid();

  if v_tenant is null or (v_role not in ('pharmacy_owner', 'pharmacist') and not v_can_manage) then
    raise exception 'Only authorized managers can invite staff';
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

drop policy if exists "staff_invitations_insert_staff_manager" on public.staff_invitations;
create policy "staff_invitations_insert_staff_manager"
  on public.staff_invitations
  for insert
  to authenticated
  with check (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and p.tenant_id = staff_invitations.tenant_id
        and coalesce((p.permissions->>'manage_staff')::boolean, false)
    )
  );

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

  if v_my_tenant is null or (v_my_role not in ('pharmacy_owner', 'pharmacist') and not v_my_manage) then
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

  if v_my_manage and v_my_role not in ('pharmacy_owner', 'pharmacist') and v_target_role in ('pharmacy_owner', 'pharmacist') then
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
