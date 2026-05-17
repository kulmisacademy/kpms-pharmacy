-- Role conventions (enforced in app; documented here):
-- platform_super_admin | pharmacy_owner | pharmacist | cashier | staff
--
-- Platform admins may list all tenants for the operator console. Pharmacy users only see their tenant.

drop policy if exists "tenants_select_platform_admin" on public.tenants;
create policy "tenants_select_platform_admin"
  on public.tenants
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.role = 'platform_super_admin'
    )
  );
