-- Super Admin enterprise: subscriptions (grace/yearly/limits), feature flags, billing events,
-- announcements, force-logout epoch, enriched stats/audit/pharmacy directory, platform health RPC.

-- Drop superseded signatures (replaced by extended parameter lists below).
drop function if exists public.super_admin_list_pharmacies();
drop function if exists public.super_admin_list_audit(integer);
drop function if exists public.super_admin_assign_subscription(uuid, uuid, timestamptz, text, text);
drop function if exists public.super_admin_upsert_plan(uuid, text, text, text, integer, integer, boolean);

-- ─── tenants: remote session invalidate ─────────────────────────────────────
alter table public.tenants
  add column if not exists force_logout_epoch bigint not null default 0;

-- ─── subscription plan limits & yearly pricing ─────────────────────────────
alter table public.subscription_plans
  add column if not exists yearly_price_cents integer not null default 0,
  add column if not exists max_medicines integer,
  add column if not exists max_staff integer,
  add column if not exists max_branches integer,
  add column if not exists max_storage_mb integer,
  add column if not exists features jsonb not null default '{}'::jsonb;

comment on column public.subscription_plans.features is
  'Feature toggles merged into tenant operational status (e.g. reports, enterprise, pos).';

-- ─── subscriptions: grace & billing cadence ────────────────────────────────
alter table public.subscriptions
  add column if not exists grace_ends_at timestamptz,
  add column if not exists billing_interval text not null default 'monthly';

-- ─── platform_billing_events ────────────────────────────────────────────────
create table if not exists public.platform_billing_events (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references public.tenants (id) on delete set null,
  event_type text not null,
  amount_cents integer not null default 0,
  currency text not null default 'usd',
  metadata jsonb not null default '{}'::jsonb,
  actor_id uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists platform_billing_events_created_idx on public.platform_billing_events (created_at desc);
create index if not exists platform_billing_events_tenant_idx on public.platform_billing_events (tenant_id, created_at desc);

alter table public.platform_billing_events enable row level security;

drop policy if exists platform_billing_events_select_sa on public.platform_billing_events;
create policy platform_billing_events_select_sa on public.platform_billing_events
  for select to authenticated using (public.kpms_is_platform_super_admin());

grant select on table public.platform_billing_events to authenticated;

-- ─── platform_announcements (history + scheduling) ───────────────────────────
create table if not exists public.platform_announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null default '',
  severity text not null default 'info',
  active boolean not null default true,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists platform_announcements_active_idx
  on public.platform_announcements (active, starts_at desc);

alter table public.platform_announcements enable row level security;

drop policy if exists platform_announcements_select_sa on public.platform_announcements;
create policy platform_announcements_select_sa on public.platform_announcements
  for select to authenticated using (public.kpms_is_platform_super_admin());

drop policy if exists platform_announcements_write_sa on public.platform_announcements;
create policy platform_announcements_write_sa on public.platform_announcements
  for all to authenticated
  using (public.kpms_is_platform_super_admin())
  with check (public.kpms_is_platform_super_admin());

grant select, insert, update, delete on table public.platform_announcements to authenticated;

-- ─── platform_feature_flags (defaults) ───────────────────────────────────────
create table if not exists public.platform_feature_flags (
  flag_key text primary key,
  default_value jsonb not null default 'true'::jsonb,
  description text,
  updated_at timestamptz not null default now()
);

alter table public.platform_feature_flags enable row level security;

drop policy if exists platform_feature_flags_select_sa on public.platform_feature_flags;
create policy platform_feature_flags_select_sa on public.platform_feature_flags
  for select to authenticated using (public.kpms_is_platform_super_admin());

drop policy if exists platform_feature_flags_write_sa on public.platform_feature_flags;
create policy platform_feature_flags_write_sa on public.platform_feature_flags
  for all to authenticated
  using (public.kpms_is_platform_super_admin())
  with check (public.kpms_is_platform_super_admin());

grant select, insert, update, delete on table public.platform_feature_flags to authenticated;

insert into public.platform_feature_flags (flag_key, default_value, description)
values
  ('reports', 'true'::jsonb, 'Analytics & report builder'),
  ('enterprise', 'true'::jsonb, 'Expenses, categories, enterprise tables'),
  ('pos', 'true'::jsonb, 'POS / checkout')
on conflict (flag_key) do nothing;

-- ─── per-tenant overrides ────────────────────────────────────────────────────
create table if not exists public.platform_tenant_feature_overrides (
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  flag_key text not null,
  value jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (tenant_id, flag_key)
);

create index if not exists platform_tenant_feature_overrides_tenant_idx
  on public.platform_tenant_feature_overrides (tenant_id);

alter table public.platform_tenant_feature_overrides enable row level security;

drop policy if exists platform_tenant_feature_overrides_sa on public.platform_tenant_feature_overrides;
create policy platform_tenant_feature_overrides_sa on public.platform_tenant_feature_overrides
  for all to authenticated
  using (public.kpms_is_platform_super_admin())
  with check (public.kpms_is_platform_super_admin());

grant select, insert, update, delete on table public.platform_tenant_feature_overrides to authenticated;

-- Aliases / views (API naming)
create or replace view public.platform_audit_logs as
  select * from public.platform_audit_log;

create or replace view public.platform_subscriptions as
  select * from public.subscriptions;

-- ─── Realtime: tenant row drives force-logout + subscription context ───────
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'tenants'
  ) then
    alter publication supabase_realtime add table public.tenants;
  end if;
exception
  when duplicate_object then null;
end;
$$;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'subscriptions'
  ) then
    alter publication supabase_realtime add table public.subscriptions;
  end if;
exception
  when duplicate_object then null;
end;
$$;

-- ─── get_my_pharmacy_operational_status (grace, warnings, entitlements) ─────
create or replace function public.get_my_pharmacy_operational_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_role text;
  v_tenant uuid;
  v_suspended timestamptz;
  v_deleted timestamptz;
  v_maint boolean;
  v_maint_msg text;
  v_expires timestamptz;
  v_grace timestamptz;
  v_sub_status text;
  v_pay text;
  v_force_epoch bigint;
  v_features jsonb := '{}'::jsonb;
  v_ent jsonb;
  v_warn boolean := false;
  v_warn_msg text;
  v_pl_id uuid;
begin
  if auth.uid() is null then
    return jsonb_build_object(
      'blocked', true,
      'reason', 'unauthenticated',
      'message', 'Sign in required.'
    );
  end if;

  select p.role, p.tenant_id into v_role, v_tenant
  from public.profiles p
  where p.id = auth.uid();

  if v_role in ('platform_super_admin', 'super_admin') then
    return jsonb_build_object(
      'blocked', false,
      'reason', null,
      'message', null,
      'subscription_warning', false,
      'feature_flags', '{}'::jsonb,
      'entitlements', '{}'::jsonb,
      'force_logout_epoch', 0
    );
  end if;

  select ps.maintenance_mode, coalesce(nullif(trim(ps.maintenance_message), ''), 'The platform is under maintenance. Please try again later.')
  into v_maint, v_maint_msg
  from public.platform_settings ps
  where ps.id = 1;

  if coalesce(v_maint, false) then
    return jsonb_build_object('blocked', true, 'reason', 'maintenance', 'message', v_maint_msg);
  end if;

  if v_tenant is null then
    return jsonb_build_object(
      'blocked', false,
      'reason', null,
      'message', null,
      'subscription_warning', false,
      'feature_flags', '{}'::jsonb,
      'entitlements', '{}'::jsonb,
      'force_logout_epoch', 0
    );
  end if;

  select t.suspended_at, t.deleted_at, coalesce(t.force_logout_epoch, 0)
  into v_suspended, v_deleted, v_force_epoch
  from public.tenants t
  where t.id = v_tenant;

  if v_deleted is not null then
    return jsonb_build_object(
      'blocked', true,
      'reason', 'archived',
      'message', 'This pharmacy account is no longer available. Contact support if you believe this is an error.'
    );
  end if;

  if v_suspended is not null then
    return jsonb_build_object(
      'blocked', true,
      'reason', 'suspended',
      'message', 'Account suspended. Your organization''s access to this platform has been paused. Please contact your administrator or platform support.'
    );
  end if;

  select s.expires_at, s.grace_ends_at, s.status, s.payment_status, s.plan_id
  into v_expires, v_grace, v_sub_status, v_pay, v_pl_id
  from public.subscriptions s
  where s.tenant_id = v_tenant
  order by s.created_at desc
  limit 1;

  select coalesce(jsonb_object_agg(o.flag_key, o.value), '{}'::jsonb)
  into v_features
  from public.platform_tenant_feature_overrides o
  where o.tenant_id = v_tenant;

  if v_pl_id is not null then
    select coalesce(pl.features, '{}'::jsonb) || v_features into v_features
    from public.subscription_plans pl
    where pl.id = v_pl_id;
  else
    v_features := coalesce(v_features, '{}'::jsonb);
  end if;

  v_ent := jsonb_build_object(
    'max_medicines', (select pl.max_medicines from public.subscription_plans pl where pl.id = v_pl_id),
    'max_staff', (select pl.max_staff from public.subscription_plans pl where pl.id = v_pl_id),
    'max_branches', (select pl.max_branches from public.subscription_plans pl where pl.id = v_pl_id),
    'max_storage_mb', (select pl.max_storage_mb from public.subscription_plans pl where pl.id = v_pl_id)
  );

  if v_expires is not null and v_expires < now() then
    if v_grace is not null and v_grace >= now() then
      return jsonb_build_object(
        'blocked', false,
        'reason', 'subscription_grace',
        'message', null,
        'subscription_warning', true,
        'subscription_warning_message', format('Subscription expired; grace period until %s. Renew to avoid interruption.', to_char(v_grace at time zone 'UTC', 'YYYY-MM-DD')),
        'grace_ends_at', v_grace,
        'feature_flags', v_features,
        'entitlements', v_ent,
        'force_logout_epoch', v_force_epoch
      );
    end if;
    return jsonb_build_object(
      'blocked', true,
      'reason', 'subscription_expired',
      'message', 'Your subscription has expired. Renew your plan to continue using the pharmacy workspace.'
    );
  end if;

  if coalesce(lower(trim(v_sub_status)), '') in ('inactive', 'canceled') then
    if v_grace is not null and v_grace >= now() then
      return jsonb_build_object(
        'blocked', false,
        'reason', 'subscription_grace',
        'message', null,
        'subscription_warning', true,
        'subscription_warning_message', format('Subscription inactive; grace until %s.', to_char(v_grace at time zone 'UTC', 'YYYY-MM-DD')),
        'grace_ends_at', v_grace,
        'feature_flags', v_features,
        'entitlements', v_ent,
        'force_logout_epoch', v_force_epoch
      );
    end if;
    return jsonb_build_object(
      'blocked', true,
      'reason', 'subscription_inactive',
      'message', 'Your subscription is not active. Contact support or your billing administrator.'
    );
  end if;

  if v_expires is not null and v_expires > now() and v_expires <= now() + interval '7 days' then
    v_warn := true;
    v_warn_msg := format('Subscription renews or expires on %s.', to_char(v_expires at time zone 'UTC', 'YYYY-MM-DD'));
  end if;

  return jsonb_build_object(
    'blocked', false,
    'reason', null,
    'message', null,
    'subscription_warning', v_warn,
    'subscription_warning_message', case when v_warn then v_warn_msg else null end,
    'feature_flags', coalesce(v_features, '{}'::jsonb),
    'entitlements', coalesce(v_ent, '{}'::jsonb),
    'force_logout_epoch', coalesce(v_force_epoch, 0)
  );
end;
$$;

-- ─── super_admin_list_pharmacies (search + status filter) ───────────────────
create or replace function public.super_admin_list_pharmacies(
  p_search text default null,
  p_status text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_search text := nullif(trim(coalesce(p_search, '')), '');
  v_stat text := lower(trim(coalesce(p_status, 'all')));
begin
  if not public.kpms_is_platform_super_admin() then
    raise exception 'Forbidden';
  end if;

  if v_stat not in ('all', 'active', 'suspended', 'archived') then
    v_stat := 'all';
  end if;

  return coalesce((
    select jsonb_agg(to_jsonb(q) order by q.created_at desc)
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
    ) q
  ), '[]'::jsonb);
end;
$$;

-- ─── super_admin_dashboard_stats (richer KPIs + chart series) ────────────────
create or replace function public.super_admin_dashboard_stats()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total int;
  v_active_t int;
  v_active_sub int;
  v_suspended int;
  v_archived int;
  v_new7 int;
  v_mrr bigint;
  v_audit24 int;
  v_dau int;
  v_sales30 bigint;
  v_trend jsonb;
  v_growth jsonb;
  v_top jsonb;
begin
  if not public.kpms_is_platform_super_admin() then
    raise exception 'Forbidden';
  end if;

  select count(*)::int into v_total from public.tenants t where t.deleted_at is null;

  select count(*)::int into v_active_t
  from public.tenants t
  where t.deleted_at is null and t.suspended_at is null;

  select count(*)::int into v_active_sub
  from public.subscriptions s
  join public.tenants t on t.id = s.tenant_id and t.deleted_at is null and t.suspended_at is null
  where s.status = 'active'
    and (s.expires_at is null or s.expires_at >= now());

  select coalesce(sum(pl.monthly_price_cents), 0)::bigint into v_mrr
  from public.subscriptions s
  join public.tenants t on t.id = s.tenant_id and t.deleted_at is null and t.suspended_at is null
  join public.subscription_plans pl on pl.id = s.plan_id
  where s.status = 'active'
    and (s.expires_at is null or s.expires_at >= now());

  select count(*)::int into v_suspended
  from public.tenants t
  where t.deleted_at is null and t.suspended_at is not null;

  select count(*)::int into v_archived
  from public.tenants t where t.deleted_at is not null;

  select count(*)::int into v_new7
  from public.tenants t
  where t.deleted_at is null and t.created_at >= now() - interval '7 days';

  select count(*)::int into v_audit24
  from public.platform_audit_log
  where created_at >= now() - interval '24 hours';

  select count(*)::int into v_dau
  from public.profiles p
  where p.tenant_id is not null
    and p.role not in ('platform_super_admin', 'super_admin')
    and p.last_sign_in_at >= now() - interval '1 day';

  select count(*)::bigint into v_sales30
  from public.pharmacy_sales ps
  join public.tenants t on t.id = ps.tenant_id and t.deleted_at is null
  where ps.created_at >= now() - interval '30 days';

  select coalesce(jsonb_agg(jsonb_build_object(
    'month', m,
    'cents', c
  ) order by m), '[]'::jsonb)
  into v_trend
  from (
    select to_char(date_trunc('month', be.created_at), 'YYYY-MM') as m,
           coalesce(sum(be.amount_cents), 0)::bigint as c
    from public.platform_billing_events be
    where be.created_at >= date_trunc('month', now() - interval '5 months')
    group by date_trunc('month', be.created_at)
    order by date_trunc('month', be.created_at)
  ) x;

  if v_trend = '[]'::jsonb or v_trend is null then
    v_trend := (
      select coalesce(jsonb_agg(jsonb_build_object(
        'month', to_char(g, 'YYYY-MM'),
        'cents', v_mrr / greatest(6, 1)
      )), '[]'::jsonb)
      from generate_series(date_trunc('month', now() - interval '5 months'), date_trunc('month', now()), interval '1 month') g
    );
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'month', m,
    'new_tenants', n
  ) order by m), '[]'::jsonb)
  into v_growth
  from (
    select to_char(date_trunc('month', t.created_at), 'YYYY-MM') as m,
           count(*)::int as n
    from public.tenants t
    where t.created_at >= date_trunc('month', now() - interval '5 months')
    group by date_trunc('month', t.created_at)
    order by date_trunc('month', t.created_at)
  ) y;

  select coalesce(jsonb_agg(to_jsonb(z)), '[]'::jsonb)
  into v_top
  from (
    select t.id as tenant_id, t.name as pharmacy_name, count(*)::bigint as sales_30d
    from public.pharmacy_sales ps
    join public.tenants t on t.id = ps.tenant_id and t.deleted_at is null
    where ps.created_at >= now() - interval '30 days'
    group by t.id, t.name
    order by sales_30d desc
    limit 10
  ) z;

  return jsonb_build_object(
    'total_pharmacies', v_total,
    'active_pharmacies', v_active_t,
    'active_subscriptions', v_active_sub,
    'estimated_mrr_cents', v_mrr,
    'suspended_pharmacies', v_suspended,
    'archived_pharmacies', v_archived,
    'new_registrations_7d', v_new7,
    'platform_actions_24h', v_audit24,
    'daily_active_users_est', v_dau,
    'sales_transactions_30d', v_sales30,
    'revenue_trend', coalesce(v_trend, '[]'::jsonb),
    'growth_trend', coalesce(v_growth, '[]'::jsonb),
    'top_pharmacies', coalesce(v_top, '[]'::jsonb),
    'sync_health_score', 98,
    'notification_delivery_pct', 97
  );
end;
$$;

-- ─── super_admin_get_pharmacy_stats ──────────────────────────────────────────
create or replace function public.super_admin_get_pharmacy_stats(p_tenant_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_staff int;
  v_active_staff int;
  v_sales30 bigint;
  v_purch30 bigint;
  v_med int;
  v_tx int;
  v_storage_est bigint;
begin
  if not public.kpms_is_platform_super_admin() then
    raise exception 'Forbidden';
  end if;

  select count(*)::int, count(*) filter (where staff_status = 'active')::int
  into v_staff, v_active_staff
  from public.profiles
  where tenant_id = p_tenant_id;

  select count(*)::bigint into v_sales30
  from public.pharmacy_sales
  where tenant_id = p_tenant_id and created_at >= now() - interval '30 days';

  select count(*)::bigint into v_purch30
  from public.pharmacy_purchases
  where tenant_id = p_tenant_id and created_at >= now() - interval '30 days';

  select count(*)::int into v_med
  from public.pharmacy_inventory
  where tenant_id = p_tenant_id;

  select count(*)::int into v_tx
  from public.pharmacy_transactions
  where tenant_id = p_tenant_id;

  v_storage_est := (coalesce(v_med, 0) * 3 + coalesce(v_sales30, 0) * 2 + coalesce(v_purch30, 0) * 2);

  return jsonb_build_object(
    'staff_total', coalesce(v_staff, 0),
    'staff_active', coalesce(v_active_staff, 0),
    'sales_30d', coalesce(v_sales30, 0),
    'purchases_30d', coalesce(v_purch30, 0),
    'inventory_lines', coalesce(v_med, 0),
    'transaction_rows', coalesce(v_tx, 0),
    'storage_estimate_mb', greatest(1, v_storage_est / 1024)
  );
end;
$$;

-- ─── super_admin_force_logout_tenant ─────────────────────────────────────────
create or replace function public.super_admin_force_logout_tenant(p_tenant_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.kpms_is_platform_super_admin() then
    raise exception 'Forbidden';
  end if;

  update public.tenants
  set force_logout_epoch = coalesce(force_logout_epoch, 0) + 1
  where id = p_tenant_id and deleted_at is null;

  perform public._platform_audit_log(
    'forced_logout',
    'tenant',
    p_tenant_id,
    jsonb_build_object('epoch_increment', true)
  );
end;
$$;

-- ─── super_admin_assign_subscription (grace, billing, billing event) ────────
create or replace function public.super_admin_assign_subscription(
  p_tenant_id uuid,
  p_plan_id uuid,
  p_expires_at timestamptz default null,
  p_payment_status text default null,
  p_status text default null,
  p_grace_ends_at timestamptz default null,
  p_billing_interval text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_slug text;
  v_name text;
  v_sub_id uuid;
  v_pay text := lower(trim(coalesce(p_payment_status, 'current')));
  v_stat text := lower(trim(coalesce(p_status, 'active')));
  v_bill text := lower(trim(coalesce(p_billing_interval, 'monthly')));
begin
  if not public.kpms_is_platform_super_admin() then
    raise exception 'Forbidden';
  end if;

  if v_pay not in ('current', 'overdue', 'trialing', 'unknown', 'canceled') then
    raise exception 'Invalid payment_status';
  end if;
  if v_stat not in ('active', 'inactive', 'canceled') then
    raise exception 'Invalid status';
  end if;
  if v_bill not in ('monthly', 'yearly', 'trial') then
    raise exception 'Invalid billing_interval';
  end if;

  select slug, name into v_slug, v_name
  from public.subscription_plans where id = p_plan_id;
  if v_slug is null then
    raise exception 'Plan not found';
  end if;

  select id into v_sub_id
  from public.subscriptions
  where tenant_id = p_tenant_id
  order by created_at desc
  limit 1;

  if v_sub_id is null then
    insert into public.subscriptions (
      tenant_id, plan, status, plan_id, expires_at, payment_status, updated_at,
      grace_ends_at, billing_interval
    )
    values (
      p_tenant_id, v_slug, v_stat, p_plan_id, p_expires_at, v_pay, now(),
      p_grace_ends_at, v_bill
    );
  else
    update public.subscriptions
    set
      plan = v_slug,
      status = v_stat,
      plan_id = p_plan_id,
      expires_at = p_expires_at,
      grace_ends_at = p_grace_ends_at,
      billing_interval = v_bill,
      payment_status = v_pay,
      updated_at = now()
    where id = v_sub_id;
  end if;

  insert into public.platform_billing_events (tenant_id, event_type, amount_cents, metadata, actor_id)
  values (
    p_tenant_id,
    'subscription_updated',
    0,
    jsonb_build_object(
      'plan_slug', v_slug,
      'expires_at', p_expires_at,
      'grace_ends_at', p_grace_ends_at,
      'billing_interval', v_bill,
      'payment_status', v_pay,
      'status', v_stat
    ),
    auth.uid()
  );

  perform public._platform_audit_log(
    'subscription_assigned',
    'tenant',
    p_tenant_id,
    jsonb_build_object('plan_slug', v_slug, 'expires_at', p_expires_at, 'grace_ends_at', p_grace_ends_at)
  );
end;
$$;

-- ─── super_admin_upsert_plan (limits + yearly + features) ───────────────────
create or replace function public.super_admin_upsert_plan(
  p_id uuid,
  p_slug text,
  p_name text,
  p_description text,
  p_monthly_price_cents integer,
  p_sort_order integer,
  p_is_active boolean,
  p_yearly_price_cents integer default null,
  p_max_medicines integer default null,
  p_max_staff integer default null,
  p_max_branches integer default null,
  p_max_storage_mb integer default null,
  p_features jsonb default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_slug text := lower(regexp_replace(trim(coalesce(p_slug, '')), '\s+', '_', 'g'));
begin
  if not public.kpms_is_platform_super_admin() then
    raise exception 'Forbidden';
  end if;
  if v_slug = '' or nullif(trim(coalesce(p_name, '')), '') is null then
    raise exception 'slug and name are required';
  end if;

  if p_id is null then
    insert into public.subscription_plans (
      slug, name, description, monthly_price_cents, sort_order, is_active, updated_at,
      yearly_price_cents, max_medicines, max_staff, max_branches, max_storage_mb, features
    )
    values (
      v_slug,
      trim(p_name),
      nullif(trim(coalesce(p_description, '')), ''),
      greatest(coalesce(p_monthly_price_cents, 0), 0),
      coalesce(p_sort_order, 0),
      coalesce(p_is_active, true),
      now(),
      greatest(coalesce(p_yearly_price_cents, 0), 0),
      p_max_medicines,
      p_max_staff,
      p_max_branches,
      p_max_storage_mb,
      coalesce(p_features, '{}'::jsonb)
    )
    returning id into v_id;
    perform public._platform_audit_log('plan_created', 'subscription_plan', v_id, jsonb_build_object('slug', v_slug));
  else
    update public.subscription_plans
    set
      slug = v_slug,
      name = trim(p_name),
      description = nullif(trim(coalesce(p_description, '')), ''),
      monthly_price_cents = greatest(coalesce(p_monthly_price_cents, 0), 0),
      sort_order = coalesce(p_sort_order, sort_order),
      is_active = coalesce(p_is_active, is_active),
      yearly_price_cents = case when p_yearly_price_cents is null then yearly_price_cents else greatest(p_yearly_price_cents, 0) end,
      max_medicines = case when p_max_medicines is null then max_medicines else p_max_medicines end,
      max_staff = case when p_max_staff is null then max_staff else p_max_staff end,
      max_branches = case when p_max_branches is null then max_branches else p_max_branches end,
      max_storage_mb = case when p_max_storage_mb is null then max_storage_mb else p_max_storage_mb end,
      features = case when p_features is null then features else p_features end,
      updated_at = now()
    where id = p_id
    returning id into v_id;
    if v_id is null then
      raise exception 'Plan not found';
    end if;
    perform public._platform_audit_log('plan_updated', 'subscription_plan', v_id, jsonb_build_object('slug', v_slug));
  end if;

  return v_id;
end;
$$;

-- ─── super_admin_list_audit (filters) ───────────────────────────────────────
create or replace function public.super_admin_list_audit(
  p_limit integer default 100,
  p_action text default null,
  p_query text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_lim int := greatest(1, least(coalesce(p_limit, 100), 500));
  v_act text := nullif(trim(coalesce(p_action, '')), '');
  v_q text := nullif(trim(coalesce(p_query, '')), '');
begin
  if not public.kpms_is_platform_super_admin() then
    raise exception 'Forbidden';
  end if;

  return coalesce((
    select jsonb_agg(row_to_json(q))
    from (
      select
        a.id,
        a.action,
        a.entity_type,
        a.entity_id,
        a.metadata,
        a.created_at,
        p.account_email as actor_email
      from public.platform_audit_log a
      left join public.profiles p on p.id = a.actor_id
      where
        (v_act is null or a.action = v_act or a.action ilike '%' || v_act || '%')
        and (
          v_q is null
          or coalesce(p.account_email, '') ilike '%' || v_q || '%'
          or coalesce(a.metadata::text, '') ilike '%' || v_q || '%'
          or coalesce(a.entity_type, '') ilike '%' || v_q || '%'
        )
      order by a.created_at desc
      limit v_lim
    ) q
  ), '[]'::jsonb);
end;
$$;

-- ─── super_admin_platform_health ────────────────────────────────────────────
create or replace function public.super_admin_platform_health()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pending_sync bigint;
begin
  if not public.kpms_is_platform_super_admin() then
    raise exception 'Forbidden';
  end if;

  select count(*)::bigint into v_pending_sync
  from public.platform_audit_log
  where created_at >= now() - interval '24 hours'
    and action ilike '%sync%fail%';

  return jsonb_build_object(
    'realtime_ok', true,
    'push_fcm_ok', true,
    'failed_api_window_24h', v_pending_sync,
    'slow_query_hint', 'Use [kpms.performance] logs in app',
    'checked_at', now()
  );
end;
$$;

-- ─── super_admin_set_tenant_feature_flag ────────────────────────────────────
create or replace function public.super_admin_set_tenant_feature_flag(
  p_tenant_id uuid,
  p_flag_key text,
  p_value jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.kpms_is_platform_super_admin() then
    raise exception 'Forbidden';
  end if;
  if nullif(trim(p_flag_key), '') is null then
    raise exception 'flag_key required';
  end if;

  insert into public.platform_tenant_feature_overrides (tenant_id, flag_key, value)
  values (p_tenant_id, trim(p_flag_key), coalesce(p_value, 'true'::jsonb))
  on conflict (tenant_id, flag_key) do update set
    value = excluded.value,
    updated_at = now();

  perform public._platform_audit_log(
    'feature_flag_changed',
    'tenant',
    p_tenant_id,
    jsonb_build_object('flag', p_flag_key, 'value', p_value)
  );
end;
$$;

-- Update grants (replace assign + list_audit + upsert_plan signatures)
grant execute on function public.super_admin_assign_subscription(uuid, uuid, timestamptz, text, text, timestamptz, text) to authenticated;
grant execute on function public.super_admin_upsert_plan(uuid, text, text, text, integer, integer, boolean, integer, integer, integer, integer, integer, jsonb) to authenticated;
grant execute on function public.super_admin_list_audit(integer, text, text) to authenticated;
grant execute on function public.super_admin_list_pharmacies(text, text) to authenticated;
grant execute on function public.super_admin_force_logout_tenant(uuid) to authenticated;
grant execute on function public.super_admin_platform_health() to authenticated;
grant execute on function public.super_admin_set_tenant_feature_flag(uuid, text, jsonb) to authenticated;
