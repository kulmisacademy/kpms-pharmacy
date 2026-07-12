-- Replace inline profile subqueries in storage RLS with kpms_my_tenant_id() (stable, indexed path).

-- tenant-assets bucket (private tenant prefix)
drop policy if exists "tenant_assets_select" on storage.objects;
create policy "tenant_assets_select"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'tenant-assets'
    and (storage.foldername(name))[1] = public.kpms_my_tenant_id()::text
  );

drop policy if exists "tenant_assets_insert" on storage.objects;
create policy "tenant_assets_insert"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'tenant-assets'
    and (storage.foldername(name))[1] = public.kpms_my_tenant_id()::text
  );

drop policy if exists "tenant_assets_update" on storage.objects;
create policy "tenant_assets_update"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'tenant-assets'
    and (storage.foldername(name))[1] = public.kpms_my_tenant_id()::text
  );

drop policy if exists "tenant_assets_delete" on storage.objects;
create policy "tenant_assets_delete"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'tenant-assets'
    and (storage.foldername(name))[1] = public.kpms_my_tenant_id()::text
  );

-- pharmacy-logos bucket (public read; tenant-scoped writes)
drop policy if exists "pharmacy_logos_insert_own_tenant" on storage.objects;
create policy "pharmacy_logos_insert_own_tenant"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'pharmacy-logos'
    and split_part(name, '/', 1) = public.kpms_my_tenant_id()::text
  );

drop policy if exists "pharmacy_logos_update_own_tenant" on storage.objects;
create policy "pharmacy_logos_update_own_tenant"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'pharmacy-logos'
    and split_part(name, '/', 1) = public.kpms_my_tenant_id()::text
  )
  with check (
    bucket_id = 'pharmacy-logos'
    and split_part(name, '/', 1) = public.kpms_my_tenant_id()::text
  );

drop policy if exists "pharmacy_logos_delete_own_tenant" on storage.objects;
create policy "pharmacy_logos_delete_own_tenant"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'pharmacy-logos'
    and split_part(name, '/', 1) = public.kpms_my_tenant_id()::text
  );
