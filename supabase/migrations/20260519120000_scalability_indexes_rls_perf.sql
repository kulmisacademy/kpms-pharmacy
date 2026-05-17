-- Scalability: composite indexes for multi-tenant SaaS hot paths + leaner RLS predicates.
-- Targets 10k+ tenants: fewer seq scans on profiles/subscriptions/staff tables.

-- ─── Profiles: tenant directory & ordering (staff list) ───────────────────
create index if not exists profiles_tenant_full_name_idx
  on public.profiles (tenant_id, full_name)
  where tenant_id is not null;

create index if not exists profiles_tenant_role_idx
  on public.profiles (tenant_id, role)
  where tenant_id is not null;

-- ─── Subscriptions: latest row per tenant (common query pattern) ───────────
create index if not exists subscriptions_tenant_created_at_idx
  on public.subscriptions (tenant_id, created_at desc);

-- ─── Staff invitations: admin UI sorted by recency ─────────────────────────
create index if not exists staff_invitations_tenant_created_idx
  on public.staff_invitations (tenant_id, created_at desc);

-- ─── Tenants: platform directory (super-admin lists) ───────────────────────
create index if not exists tenants_created_at_idx
  on public.tenants (created_at desc)
  where deleted_at is null;

-- ─── RLS: scalar subquery for tenant scope (stable plan vs IN list) ─────────
drop policy if exists "subscriptions_select_tenant" on public.subscriptions;
create policy "subscriptions_select_tenant"
  on public.subscriptions
  for select
  to authenticated
  using (
    tenant_id = (
      select p.tenant_id
      from public.profiles p
      where p.id = auth.uid()
      limit 1
    )
  );

-- ─── Staff activity: tenant-scoped audit reads ───────────────────────────────
drop policy if exists "staff_activity_select_tenant" on public.staff_activity_log;
create policy "staff_activity_select_tenant"
  on public.staff_activity_log
  for select
  to authenticated
  using (
    tenant_id = (
      select p.tenant_id
      from public.profiles p
      where p.id = auth.uid()
        and p.tenant_id is not null
      limit 1
    )
  );

create index if not exists staff_activity_log_tenant_created_idx
  on public.staff_activity_log (tenant_id, created_at desc);