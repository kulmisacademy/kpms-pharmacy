-- 10K+ tenant scalability: pagination, delta-friendly indexes, tenant storage, safety caps.

create extension if not exists pg_trgm;

-- ─── Delta-sync friendly indexes (tenant + updated_at) ───────────────────────
create index if not exists pharmacy_inventory_tenant_updated_idx
  on public.pharmacy_inventory (tenant_id, updated_at desc);

create index if not exists pharmacy_sales_tenant_updated_idx
  on public.pharmacy_sales (tenant_id, updated_at desc);

create index if not exists pharmacy_purchases_tenant_updated_idx
  on public.pharmacy_purchases (tenant_id, updated_at desc);

create index if not exists pharmacy_customers_tenant_updated_idx
  on public.pharmacy_customers (tenant_id, updated_at desc);

create index if not exists pharmacy_suppliers_tenant_updated_idx
  on public.pharmacy_suppliers (tenant_id, updated_at desc);

create index if not exists pharmacy_notifications_tenant_updated_idx
  on public.pharmacy_notifications (tenant_id, updated_at desc);

-- pharmacy_audit_log: created in 20260524120000_pharmacy_enterprise_extensions.sql (index there too).
-- Skip here so this migration runs even if enterprise extensions are not applied yet.

-- Directory search (super admin)
create index if not exists tenants_name_trgm_idx
  on public.tenants using gin (name gin_trgm_ops)
  where deleted_at is null;

-- ─── Paginated super-admin pharmacy directory ────────────────────────────────
drop function if exists public.super_admin_list_pharmacies(text, text);

create or replace function public.super_admin_list_pharmacies(
  p_search text default null,
  p_status text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_search text := nullif(trim(coalesce(p_search, '')), '');
  v_stat text := lower(trim(coalesce(p_status, 'all')));
  v_limit int := greatest(1, least(coalesce(p_limit, 50), 200));
  v_offset int := greatest(0, coalesce(p_offset, 0));
  v_total bigint;
  v_rows jsonb;
begin
  if not public.kpms_is_platform_super_admin() then
    raise exception 'Forbidden';
  end if;

  if v_stat not in ('all', 'active', 'suspended', 'archived') then
    v_stat := 'all';
  end if;

  select count(*)::bigint into v_total
  from public.tenants t
  left join lateral (
    select p.account_email, p.phone
    from public.profiles p
    where p.tenant_id = t.id
    order by (p.role = 'pharmacy_owner') desc, p.created_at asc
    limit 1
  ) op on true
  where
    (v_search is null or t.name ilike '%' || v_search || '%'
      or coalesce(op.account_email, '') ilike '%' || v_search || '%'
      or coalesce(op.phone, t.phone, '') ilike '%' || v_search || '%')
    and (
      v_stat = 'all'
      or (v_stat = 'active' and t.deleted_at is null and t.suspended_at is null)
      or (v_stat = 'suspended' and t.deleted_at is null and t.suspended_at is not null)
      or (v_stat = 'archived' and t.deleted_at is not null)
    );

  select coalesce(jsonb_agg(to_jsonb(q)), '[]'::jsonb)
  into v_rows
  from (
    select
      t.id as tenant_id,
      t.name as pharmacy_name,
      t.phone as pharmacy_phone,
      t.owner_name,
      t.created_at,
      t.suspended_at,
      t.deleted_at,
      t.last_activity_at,
      case
        when t.deleted_at is not null then 'archived'
        when t.suspended_at is not null then 'suspended'
        else 'active'
      end as operational_status,
      op.full_name as owner_name_display,
      op.account_email as owner_email,
      op.phone as owner_phone,
      coalesce(pl.name, s.plan) as plan_name,
      pl.slug as plan_slug,
      s.status as subscription_status,
      s.expires_at,
      s.grace_ends_at,
      s.billing_interval,
      s.payment_status,
      case
        when s.expires_at is null then null
        else greatest(0, floor(extract(epoch from (s.expires_at - now())) / 86400)::integer)
      end as remaining_days
    from public.tenants t
    left join lateral (
      select p.*
      from public.profiles p
      where p.tenant_id = t.id
      order by (p.role = 'pharmacy_owner') desc, p.created_at asc
      limit 1
    ) op on true
    left join lateral (
      select s1.*
      from public.subscriptions s1
      where s1.tenant_id = t.id
      order by s1.created_at desc
      limit 1
    ) s on true
    left join public.subscription_plans pl on pl.id = s.plan_id
    where
      (v_search is null or t.name ilike '%' || v_search || '%'
        or coalesce(op.account_email, '') ilike '%' || v_search || '%'
        or coalesce(op.phone, t.phone, '') ilike '%' || v_search || '%')
      and (
        v_stat = 'all'
        or (v_stat = 'active' and t.deleted_at is null and t.suspended_at is null)
        or (v_stat = 'suspended' and t.deleted_at is null and t.suspended_at is not null)
        or (v_stat = 'archived' and t.deleted_at is not null)
      )
    order by t.created_at desc
    limit v_limit
    offset v_offset
  ) q;

  return jsonb_build_object(
    'total', coalesce(v_total, 0),
    'limit', v_limit,
    'offset', v_offset,
    'rows', coalesce(v_rows, '[]'::jsonb)
  );
end;
$$;

grant execute on function public.super_admin_list_pharmacies(text, text, integer, integer) to authenticated;

-- ─── Tenant-scoped object storage (reports, backups, exports) ────────────────
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'tenant-assets',
  'tenant-assets',
  false,
  52428800,
  array['image/png', 'image/jpeg', 'image/webp', 'application/pdf', 'text/csv', 'application/json']
)
on conflict (id) do nothing;

drop policy if exists "tenant_assets_select" on storage.objects;
create policy "tenant_assets_select"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'tenant-assets'
    and (storage.foldername(name))[1] = (
      select p.tenant_id::text
      from public.profiles p
      where p.id = auth.uid()
      limit 1
    )
  );

drop policy if exists "tenant_assets_insert" on storage.objects;
create policy "tenant_assets_insert"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'tenant-assets'
    and (storage.foldername(name))[1] = (
      select p.tenant_id::text
      from public.profiles p
      where p.id = auth.uid()
      limit 1
    )
  );

drop policy if exists "tenant_assets_update" on storage.objects;
create policy "tenant_assets_update"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'tenant-assets'
    and (storage.foldername(name))[1] = (
      select p.tenant_id::text
      from public.profiles p
      where p.id = auth.uid()
      limit 1
    )
  );

drop policy if exists "tenant_assets_delete" on storage.objects;
create policy "tenant_assets_delete"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'tenant-assets'
    and (storage.foldername(name))[1] = (
      select p.tenant_id::text
      from public.profiles p
      where p.id = auth.uid()
      limit 1
    )
  );

-- Super admin may read any tenant prefix (platform operator)
drop policy if exists "tenant_assets_super_admin_select" on storage.objects;
create policy "tenant_assets_super_admin_select"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'tenant-assets'
    and public.kpms_is_platform_super_admin()
  );
