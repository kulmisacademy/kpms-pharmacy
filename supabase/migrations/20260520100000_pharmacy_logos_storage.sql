-- Tenant-scoped pharmacy logos (Supabase Storage). Public read; write limited to own tenant prefix.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'pharmacy-logos',
  'pharmacy-logos',
  true,
  5242880,
  array['image/png', 'image/jpeg', 'image/webp']::text[]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Policies (idempotent)
drop policy if exists "pharmacy_logos_public_read" on storage.objects;
drop policy if exists "pharmacy_logos_insert_own_tenant" on storage.objects;
drop policy if exists "pharmacy_logos_update_own_tenant" on storage.objects;
drop policy if exists "pharmacy_logos_delete_own_tenant" on storage.objects;

create policy "pharmacy_logos_public_read"
  on storage.objects for select
  to public
  using (bucket_id = 'pharmacy-logos');

create policy "pharmacy_logos_insert_own_tenant"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'pharmacy-logos'
    and split_part(name, '/', 1) = (
      select p.tenant_id::text
      from public.profiles p
      where p.id = auth.uid()
      limit 1
    )
  );

create policy "pharmacy_logos_update_own_tenant"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'pharmacy-logos'
    and split_part(name, '/', 1) = (
      select p.tenant_id::text
      from public.profiles p
      where p.id = auth.uid()
      limit 1
    )
  )
  with check (
    bucket_id = 'pharmacy-logos'
    and split_part(name, '/', 1) = (
      select p.tenant_id::text
      from public.profiles p
      where p.id = auth.uid()
      limit 1
    )
  );

create policy "pharmacy_logos_delete_own_tenant"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'pharmacy-logos'
    and split_part(name, '/', 1) = (
      select p.tenant_id::text
      from public.profiles p
      where p.id = auth.uid()
      limit 1
    )
  );
