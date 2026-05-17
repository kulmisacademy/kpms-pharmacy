-- If the user already has a pharmacy (tenant_id set), return it instead of creating another tenant.

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

  select tenant_id into v_tenant
  from public.profiles
  where id = auth.uid();

  if v_tenant is not null then
    return v_tenant;
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
