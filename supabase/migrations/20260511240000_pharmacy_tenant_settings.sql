-- Pharmacy-level settings (JSON) + allow pharmacy admins to update their tenant row.

alter table public.tenants
  add column if not exists settings jsonb not null default '{}'::jsonb;

drop policy if exists "tenants_update_pharmacy_admin" on public.tenants;
create policy "tenants_update_pharmacy_admin"
  on public.tenants
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.tenant_id = tenants.id
        and p.role in ('pharmacy_owner', 'pharmacist')
    )
  )
  with check (
    exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.tenant_id = tenants.id
        and p.role in ('pharmacy_owner', 'pharmacist')
    )
  );

grant update on table public.tenants to authenticated;
