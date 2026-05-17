-- Super Admin operational SaaS: plans, subscriptions, tenant lifecycle, platform settings, audit.

-- ─── Helpers ───────────────────────────────────────────────────────────────
create or replace function public.kpms_is_platform_super_admin()
returns boolean
language sql
stable
security invoker
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role in ('platform_super_admin', 'super_admin')
  );
$$;

revoke all on function public.kpms_is_platform_super_admin() from public;
grant execute on function public.kpms_is_platform_super_admin() to authenticated;

-- ─── subscription_plans ───────────────────────────────────────────────────
create table if not exists public.subscription_plans (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description text,
  monthly_price_cents integer not null default 0,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists subscription_plans_active_idx on public.subscription_plans (is_active, sort_order);

alter table public.subscription_plans enable row level security;

drop policy if exists "subscription_plans_select_authenticated" on public.subscription_plans;
create policy "subscription_plans_select_authenticated"
  on public.subscription_plans
  for select
  to authenticated
  using (
    is_active = true
    or public.kpms_is_platform_super_admin()
  );

drop policy if exists "subscription_plans_write_super_admin" on public.subscription_plans;
create policy "subscription_plans_write_super_admin"
  on public.subscription_plans
  for all
  to authenticated
  using (public.kpms_is_platform_super_admin())
  with check (public.kpms_is_platform_super_admin());

grant select on table public.subscription_plans to authenticated;
grant insert, update, delete on table public.subscription_plans to authenticated;

-- ─── platform_settings (singleton id = 1) ───────────────────────────────────
create table if not exists public.platform_settings (
  id integer primary key default 1 check (id = 1),
  branding_app_name text,
  branding_tagline text,
  maintenance_mode boolean not null default false,
  maintenance_message text,
  global_notification_title text,
  global_notification_body text,
  global_notification_active boolean not null default false,
  default_trial_days integer not null default 14,
  updated_at timestamptz not null default now()
);

insert into public.platform_settings (id)
values (1)
on conflict (id) do nothing;

alter table public.platform_settings enable row level security;

drop policy if exists "platform_settings_select_super_admin" on public.platform_settings;
create policy "platform_settings_select_super_admin"
  on public.platform_settings
  for select
  to authenticated
  using (public.kpms_is_platform_super_admin());

drop policy if exists "platform_settings_update_super_admin" on public.platform_settings;
create policy "platform_settings_update_super_admin"
  on public.platform_settings
  for update
  to authenticated
  using (public.kpms_is_platform_super_admin())
  with check (public.kpms_is_platform_super_admin());

grant select, update on table public.platform_settings to authenticated;

-- ─── platform_audit_log ─────────────────────────────────────────────────────
create table if not exists public.platform_audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references public.profiles (id) on delete restrict,
  action text not null,
  entity_type text,
  entity_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists platform_audit_log_created_idx on public.platform_audit_log (created_at desc);

alter table public.platform_audit_log enable row level security;

drop policy if exists "platform_audit_select_super_admin" on public.platform_audit_log;
create policy "platform_audit_select_super_admin"
  on public.platform_audit_log
  for select
  to authenticated
  using (public.kpms_is_platform_super_admin());

grant select on table public.platform_audit_log to authenticated;

-- Internal audit writer (not granted to clients).
create or replace function public._platform_audit_log(
  p_action text,
  p_entity_type text,
  p_entity_id uuid,
  p_metadata jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return;
  end if;
  insert into public.platform_audit_log (actor_id, action, entity_type, entity_id, metadata)
  values (
    auth.uid(),
    nullif(trim(p_action), ''),
    nullif(trim(p_entity_type), ''),
    p_entity_id,
    coalesce(p_metadata, '{}'::jsonb)
  );
end;
$$;

revoke all on function public._platform_audit_log(text, text, uuid, jsonb) from public;

-- ─── tenants lifecycle columns ─────────────────────────────────────────────
alter table public.tenants
  add column if not exists suspended_at timestamptz,
  add column if not exists suspended_reason text,
  add column if not exists deleted_at timestamptz,
  add column if not exists last_activity_at timestamptz;

-- ─── subscriptions extensions ──────────────────────────────────────────────
alter table public.subscriptions
  add column if not exists plan_id uuid references public.subscription_plans (id) on delete set null,
  add column if not exists expires_at timestamptz,
  add column if not exists payment_status text not null default 'unknown',
  add column if not exists updated_at timestamptz not null default now();

-- Seed plans
insert into public.subscription_plans (slug, name, description, monthly_price_cents, sort_order, is_active)
values
  ('free_trial', 'Free Trial', 'Trial access with core features', 0, 10, true),
  ('basic', 'Basic', 'Single branch, core reports', 2900, 20, true),
  ('standard', 'Standard', 'More seats and advanced reports', 7900, 30, true),
  ('premium', 'Premium', 'Full analytics and priority support', 14900, 40, true),
  ('enterprise', 'Enterprise', 'Custom limits and SLA', 49900, 50, true)
on conflict (slug) do update set
  name = excluded.name,
  description = excluded.description,
  monthly_price_cents = excluded.monthly_price_cents,
  sort_order = excluded.sort_order,
  updated_at = now();

-- Backfill plan_id from legacy text plan
update public.subscriptions s
set plan_id = p.id,
    payment_status = case when lower(trim(coalesce(s.status, ''))) = 'active' then 'current' else coalesce(s.payment_status, 'unknown') end
from public.subscription_plans p
where s.plan_id is null
  and lower(trim(s.plan)) = p.slug;

update public.subscriptions s
set plan_id = p.id
from public.subscription_plans p
where s.plan_id is null
  and lower(trim(s.plan)) in ('starter', 'trial')
  and p.slug = 'free_trial';

-- RLS: super admin reads all subscriptions
drop policy if exists "subscriptions_select_platform_admin" on public.subscriptions;
create policy "subscriptions_select_platform_admin"
  on public.subscriptions
  for select
  to authenticated
  using (public.kpms_is_platform_super_admin());

drop policy if exists "subscriptions_update_platform_admin" on public.subscriptions;
create policy "subscriptions_update_platform_admin"
  on public.subscriptions
  for update
  to authenticated
  using (public.kpms_is_platform_super_admin())
  with check (public.kpms_is_platform_super_admin());

drop policy if exists "subscriptions_insert_platform_admin" on public.subscriptions;
create policy "subscriptions_insert_platform_admin"
  on public.subscriptions
  for insert
  to authenticated
  with check (public.kpms_is_platform_super_admin());

grant insert, update on table public.subscriptions to authenticated;

-- Tenants: exclude soft-deleted from member visibility
drop policy if exists "tenants_select_member" on public.tenants;
create policy "tenants_select_member"
  on public.tenants
  for select
  to authenticated
  using (
    deleted_at is null
    and exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.tenant_id = tenants.id
    )
  );

drop policy if exists "tenants_update_platform_admin" on public.tenants;
create policy "tenants_update_platform_admin"
  on public.tenants
  for update
  to authenticated
  using (public.kpms_is_platform_super_admin())
  with check (public.kpms_is_platform_super_admin());

-- Super admin can insert tenants if needed (optional; RPC uses definer path via bypass — keep for direct fixes)
drop policy if exists "tenants_select_platform_admin" on public.tenants;
create policy "tenants_select_platform_admin"
  on public.tenants
  for select
  to authenticated
  using (
    public.kpms_is_platform_super_admin()
  );

-- Pharmacy admins must not update suspended-only fields via generic policy — keep existing tenants_update_pharmacy_admin for settings
-- (Super admin updates go through policy tenants_update_platform_admin)

-- Profiles: super admin can read cross-tenant for directory
drop policy if exists "profiles_select_platform_admin" on public.profiles;
create policy "profiles_select_platform_admin"
  on public.profiles
  for select
  to authenticated
  using (public.kpms_is_platform_super_admin());

-- ─── Pharmacy operational status (for app gate) ────────────────────────────
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
  v_sub_status text;
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
    return jsonb_build_object('blocked', false, 'reason', null, 'message', null);
  end if;

  select ps.maintenance_mode, coalesce(nullif(trim(ps.maintenance_message), ''), 'The platform is under maintenance. Please try again later.')
  into v_maint, v_maint_msg
  from public.platform_settings ps
  where ps.id = 1;

  if coalesce(v_maint, false) then
    return jsonb_build_object('blocked', true, 'reason', 'maintenance', 'message', v_maint_msg);
  end if;

  if v_tenant is null then
    return jsonb_build_object('blocked', false, 'reason', null, 'message', null);
  end if;

  select t.suspended_at, t.deleted_at into v_suspended, v_deleted
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

  select s.expires_at, s.status
  into v_expires, v_sub_status
  from public.subscriptions s
  where s.tenant_id = v_tenant
  order by s.created_at desc
  limit 1;

  if v_expires is not null and v_expires < now() then
    return jsonb_build_object(
      'blocked', true,
      'reason', 'subscription_expired',
      'message', 'Your subscription has expired. Renew your plan to continue using the pharmacy workspace.'
    );
  end if;

  if coalesce(lower(trim(v_sub_status)), '') in ('inactive', 'canceled') then
    return jsonb_build_object(
      'blocked', true,
      'reason', 'subscription_inactive',
      'message', 'Your subscription is not active. Contact support or your billing administrator.'
    );
  end if;

  return jsonb_build_object('blocked', false, 'reason', null, 'message', null);
end;
$$;

revoke all on function public.get_my_pharmacy_operational_status() from public;
grant execute on function public.get_my_pharmacy_operational_status() to authenticated;

-- Allow any signed-in user to read non-sensitive maintenance flag (optional lightweight read)
create or replace function public.get_public_platform_banner()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'maintenance_mode', coalesce(ps.maintenance_mode, false),
    'maintenance_message', coalesce(nullif(trim(ps.maintenance_message), ''), ''),
    'global_notification_active', coalesce(ps.global_notification_active, false),
    'global_notification_title', coalesce(ps.global_notification_title, ''),
    'global_notification_body', coalesce(ps.global_notification_body, '')
  )
  from public.platform_settings ps
  where ps.id = 1;
$$;

revoke all on function public.get_public_platform_banner() from public;
grant execute on function public.get_public_platform_banner() to authenticated, anon;

create or replace function public.touch_my_tenant_activity()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant uuid;
  v_role text;
begin
  if auth.uid() is null then
    return;
  end if;
  select tenant_id, role into v_tenant, v_role
  from public.profiles where id = auth.uid();

  if v_role in ('platform_super_admin', 'super_admin') or v_tenant is null then
    return;
  end if;

  update public.tenants
  set last_activity_at = now()
  where id = v_tenant and deleted_at is null;
end;
$$;

revoke all on function public.touch_my_tenant_activity() from public;
grant execute on function public.touch_my_tenant_activity() to authenticated;

-- ─── register_pharmacy: owner role + trial subscription ─────────────────────
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
  v_plan uuid;
  v_trial_days int;
  v_expires timestamptz;
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

  select coalesce(ps.default_trial_days, 14) into v_trial_days
  from public.platform_settings ps where ps.id = 1;

  select id into v_plan
  from public.subscription_plans
  where slug = 'free_trial' and is_active = true
  limit 1;

  insert into public.tenants (name, address, phone, license_number, owner_name, last_activity_at)
  values (
    nullif(trim(p_name), ''),
    nullif(trim(p_address), ''),
    nullif(trim(p_phone), ''),
    nullif(trim(p_license), ''),
    nullif(trim(p_owner), ''),
    now()
  )
  returning id into v_tenant;

  if v_tenant is null then
    raise exception 'Failed to create tenant';
  end if;

  update public.profiles
  set
    tenant_id = v_tenant,
    full_name = coalesce(nullif(trim(p_owner), ''), full_name),
    role = 'pharmacy_owner',
    updated_at = now()
  where id = auth.uid();

  get diagnostics v_n = row_count;
  if v_n = 0 then
    raise exception 'Profile row missing; sign up again or contact support';
  end if;

  v_expires := case when v_plan is not null then now() + make_interval(days => greatest(v_trial_days, 1)) else null end;

  insert into public.subscriptions (tenant_id, plan, status, plan_id, expires_at, payment_status)
  values (
    v_tenant,
    case when v_plan is not null then 'free_trial' else 'starter' end,
    'active',
    v_plan,
    v_expires,
    case when v_plan is not null then 'trialing' else 'unknown' end
  );

  return v_tenant;
end;
$$;

-- ─── Super Admin RPCs ───────────────────────────────────────────────────────
create or replace function public.super_admin_list_pharmacies()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.kpms_is_platform_super_admin() then
    raise exception 'Forbidden';
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
    ) q
  ), '[]'::jsonb);
end;
$$;

create or replace function public.super_admin_dashboard_stats()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total int;
  v_active_sub int;
  v_suspended int;
  v_new7 int;
  v_mrr bigint;
  v_audit24 int;
begin
  if not public.kpms_is_platform_super_admin() then
    raise exception 'Forbidden';
  end if;

  select count(*)::int into v_total
  from public.tenants t
  where t.deleted_at is null;

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

  select count(*)::int into v_new7
  from public.tenants t
  where t.deleted_at is null and t.created_at >= now() - interval '7 days';

  select count(*)::int into v_audit24
  from public.platform_audit_log
  where created_at >= now() - interval '24 hours';

  return jsonb_build_object(
    'total_pharmacies', v_total,
    'active_subscriptions', v_active_sub,
    'estimated_mrr_cents', v_mrr,
    'suspended_pharmacies', v_suspended,
    'new_registrations_7d', v_new7,
    'platform_actions_24h', v_audit24
  );
end;
$$;

create or replace function public.super_admin_get_pharmacy_stats(p_tenant_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_staff int;
  v_active_staff int;
begin
  if not public.kpms_is_platform_super_admin() then
    raise exception 'Forbidden';
  end if;

  select count(*)::int, count(*) filter (where staff_status = 'active')::int
  into v_staff, v_active_staff
  from public.profiles
  where tenant_id = p_tenant_id;

  return jsonb_build_object(
    'staff_total', coalesce(v_staff, 0),
    'staff_active', coalesce(v_active_staff, 0)
  );
end;
$$;

create or replace function public.super_admin_update_pharmacy(
  p_tenant_id uuid,
  p_name text,
  p_address text,
  p_phone text,
  p_license text,
  p_owner_name text
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

  update public.tenants
  set
    name = coalesce(nullif(trim(p_name), ''), name),
    address = case when p_address is null then address else nullif(trim(p_address), '') end,
    phone = case when p_phone is null then phone else nullif(trim(p_phone), '') end,
    license_number = case when p_license is null then license_number else nullif(trim(p_license), '') end,
    owner_name = case when p_owner_name is null then owner_name else nullif(trim(p_owner_name), '') end
  where id = p_tenant_id;

  perform public._platform_audit_log(
    'pharmacy_updated',
    'tenant',
    p_tenant_id,
    jsonb_build_object('name', p_name)
  );
end;
$$;

create or replace function public.super_admin_suspend_pharmacy(p_tenant_id uuid, p_reason text)
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
  set suspended_at = now(), suspended_reason = nullif(trim(p_reason), '')
  where id = p_tenant_id and deleted_at is null;

  perform public._platform_audit_log(
    'pharmacy_suspended',
    'tenant',
    p_tenant_id,
    jsonb_build_object('reason', p_reason)
  );
end;
$$;

create or replace function public.super_admin_reactivate_pharmacy(p_tenant_id uuid)
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
  set suspended_at = null, suspended_reason = null
  where id = p_tenant_id and deleted_at is null;

  perform public._platform_audit_log('pharmacy_reactivated', 'tenant', p_tenant_id, '{}'::jsonb);
end;
$$;

create or replace function public.super_admin_archive_pharmacy(p_tenant_id uuid)
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
  set deleted_at = now(), suspended_at = coalesce(suspended_at, now())
  where id = p_tenant_id and deleted_at is null;

  update public.subscriptions
  set status = 'inactive', updated_at = now()
  where tenant_id = p_tenant_id;

  perform public._platform_audit_log('pharmacy_archived', 'tenant', p_tenant_id, '{}'::jsonb);
end;
$$;

create or replace function public.super_admin_delete_pharmacy_hard(p_tenant_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.kpms_is_platform_super_admin() then
    raise exception 'Forbidden';
  end if;

  perform public._platform_audit_log('pharmacy_deleted_hard', 'tenant', p_tenant_id, '{}'::jsonb);

  delete from public.tenants where id = p_tenant_id;
end;
$$;

create or replace function public.super_admin_reset_pharmacy_account(p_tenant_id uuid)
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
  set settings = coalesce(settings, '{}'::jsonb) || jsonb_build_object(
    'kpms_admin_reset_at', to_jsonb(to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))
  )
  where id = p_tenant_id;

  perform public._platform_audit_log('pharmacy_account_reset_flag', 'tenant', p_tenant_id, '{}'::jsonb);
end;
$$;

create or replace function public.super_admin_assign_subscription(
  p_tenant_id uuid,
  p_plan_id uuid,
  p_expires_at timestamptz default null,
  p_payment_status text default null,
  p_status text default null
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
    insert into public.subscriptions (tenant_id, plan, status, plan_id, expires_at, payment_status, updated_at)
    values (p_tenant_id, v_slug, v_stat, p_plan_id, p_expires_at, v_pay, now());
  else
    update public.subscriptions
    set
      plan = v_slug,
      status = v_stat,
      plan_id = p_plan_id,
      expires_at = p_expires_at,
      payment_status = v_pay,
      updated_at = now()
    where id = v_sub_id;
  end if;

  perform public._platform_audit_log(
    'subscription_assigned',
    'tenant',
    p_tenant_id,
    jsonb_build_object('plan_slug', v_slug, 'expires_at', p_expires_at, 'payment_status', v_pay, 'status', v_stat)
  );
end;
$$;

create or replace function public.super_admin_list_plans()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.kpms_is_platform_super_admin() then
    raise exception 'Forbidden';
  end if;

  return coalesce((
    select jsonb_agg(to_jsonb(p) order by p.sort_order, p.name)
    from public.subscription_plans p
  ), '[]'::jsonb);
end;
$$;

create or replace function public.super_admin_upsert_plan(
  p_id uuid,
  p_slug text,
  p_name text,
  p_description text,
  p_monthly_price_cents integer,
  p_sort_order integer,
  p_is_active boolean
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
    insert into public.subscription_plans (slug, name, description, monthly_price_cents, sort_order, is_active, updated_at)
    values (
      v_slug,
      trim(p_name),
      nullif(trim(coalesce(p_description, '')), ''),
      greatest(coalesce(p_monthly_price_cents, 0), 0),
      coalesce(p_sort_order, 0),
      coalesce(p_is_active, true),
      now()
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

create or replace function public.super_admin_delete_plan(p_plan_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_n int;
begin
  if not public.kpms_is_platform_super_admin() then
    raise exception 'Forbidden';
  end if;

  select count(*) into v_n from public.subscriptions where plan_id = p_plan_id;
  if v_n > 0 then
    raise exception 'Plan is assigned to one or more pharmacies';
  end if;

  delete from public.subscription_plans where id = p_plan_id;
  perform public._platform_audit_log('plan_deleted', 'subscription_plan', p_plan_id, '{}'::jsonb);
end;
$$;

create or replace function public.super_admin_get_global_settings()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.kpms_is_platform_super_admin() then
    raise exception 'Forbidden';
  end if;

  return (
    select to_jsonb(ps) - 'id'::text
    from public.platform_settings ps
    where ps.id = 1
  );
end;
$$;

create or replace function public.super_admin_set_global_settings(
  p_branding_app_name text,
  p_branding_tagline text,
  p_maintenance_mode boolean,
  p_maintenance_message text,
  p_global_notification_title text,
  p_global_notification_body text,
  p_global_notification_active boolean,
  p_default_trial_days integer
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

  update public.platform_settings
  set
    branding_app_name = case when p_branding_app_name is null then branding_app_name else nullif(trim(p_branding_app_name), '') end,
    branding_tagline = case when p_branding_tagline is null then branding_tagline else nullif(trim(p_branding_tagline), '') end,
    maintenance_mode = coalesce(p_maintenance_mode, maintenance_mode),
    maintenance_message = case when p_maintenance_message is null then maintenance_message else nullif(trim(p_maintenance_message), '') end,
    global_notification_title = case when p_global_notification_title is null then global_notification_title else nullif(trim(p_global_notification_title), '') end,
    global_notification_body = case when p_global_notification_body is null then global_notification_body else nullif(trim(p_global_notification_body), '') end,
    global_notification_active = coalesce(p_global_notification_active, global_notification_active),
    default_trial_days = case when p_default_trial_days is null then default_trial_days else greatest(p_default_trial_days, 1) end,
    updated_at = now()
  where id = 1;

  perform public._platform_audit_log('global_settings_updated', 'platform_settings', null, '{}'::jsonb);
end;
$$;

create or replace function public.super_admin_list_audit(p_limit integer default 100)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
      order by a.created_at desc
      limit greatest(1, least(coalesce(p_limit, 100), 500))
    ) q
  ), '[]'::jsonb);
end;
$$;

create or replace function public.super_admin_list_users(p_limit integer default 200)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.kpms_is_platform_super_admin() then
    raise exception 'Forbidden';
  end if;

  return coalesce((
    select jsonb_agg(row_to_json(q))
    from (
      select
        p.id as user_id,
        p.full_name,
        p.account_email,
        p.phone,
        p.role,
        p.staff_status,
        p.tenant_id,
        t.name as pharmacy_name,
        p.created_at,
        p.last_sign_in_at
      from public.profiles p
      left join public.tenants t on t.id = p.tenant_id and t.deleted_at is null
      where p.role not in ('platform_super_admin', 'super_admin')
      order by p.created_at desc
      limit greatest(1, least(coalesce(p_limit, 200), 500))
    ) q
  ), '[]'::jsonb);
end;
$$;

create or replace function public.super_admin_publish_global_notification(p_title text, p_body text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.kpms_is_platform_super_admin() then
    raise exception 'Forbidden';
  end if;

  update public.platform_settings
  set
    global_notification_title = nullif(trim(p_title), ''),
    global_notification_body = nullif(trim(p_body), ''),
    global_notification_active = true,
    updated_at = now()
  where id = 1;

  perform public._platform_audit_log(
    'global_notification_published',
    'platform_settings',
    null,
    jsonb_build_object('title', p_title)
  );
end;
$$;

-- Grants for RPCs
grant execute on function public.super_admin_list_pharmacies() to authenticated;
grant execute on function public.super_admin_dashboard_stats() to authenticated;
grant execute on function public.super_admin_get_pharmacy_stats(uuid) to authenticated;
grant execute on function public.super_admin_update_pharmacy(uuid, text, text, text, text, text) to authenticated;
grant execute on function public.super_admin_suspend_pharmacy(uuid, text) to authenticated;
grant execute on function public.super_admin_reactivate_pharmacy(uuid) to authenticated;
grant execute on function public.super_admin_archive_pharmacy(uuid) to authenticated;
grant execute on function public.super_admin_delete_pharmacy_hard(uuid) to authenticated;
grant execute on function public.super_admin_reset_pharmacy_account(uuid) to authenticated;
grant execute on function public.super_admin_assign_subscription(uuid, uuid, timestamptz, text, text) to authenticated;
grant execute on function public.super_admin_list_plans() to authenticated;
grant execute on function public.super_admin_upsert_plan(uuid, text, text, text, integer, integer, boolean) to authenticated;
grant execute on function public.super_admin_delete_plan(uuid) to authenticated;
grant execute on function public.super_admin_get_global_settings() to authenticated;
grant execute on function public.super_admin_set_global_settings(text, text, boolean, text, text, text, boolean, integer) to authenticated;
grant execute on function public.super_admin_list_audit(integer) to authenticated;
grant execute on function public.super_admin_list_users(integer) to authenticated;
grant execute on function public.super_admin_publish_global_notification(text, text) to authenticated;
