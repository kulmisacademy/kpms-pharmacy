-- Denormalized sign-in email on profiles (staff directory + admin tools).
-- Staff activity log for enterprise audit trail.

alter table public.profiles
  add column if not exists account_email text;

update public.profiles p
set account_email = lower(trim(u.email))
from auth.users u
where p.id = u.id
  and coalesce(nullif(trim(p.account_email), ''), '') = '';

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, account_email)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data->>'full_name'), ''),
      split_part(coalesce(new.email, ''), '@', 1)
    ),
    nullif(lower(trim(coalesce(new.email, ''))), '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create table if not exists public.staff_activity_log (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  actor_id uuid not null references public.profiles (id) on delete cascade,
  action text not null,
  entity_type text,
  entity_ref text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists staff_activity_log_tenant_idx on public.staff_activity_log (tenant_id);
create index if not exists staff_activity_log_actor_idx on public.staff_activity_log (actor_id);
create index if not exists staff_activity_log_created_idx on public.staff_activity_log (created_at desc);

alter table public.staff_activity_log enable row level security;

drop policy if exists "staff_activity_select_tenant" on public.staff_activity_log;
create policy "staff_activity_select_tenant"
  on public.staff_activity_log
  for select
  to authenticated
  using (
    tenant_id in (
      select p.tenant_id from public.profiles p
      where p.id = auth.uid() and p.tenant_id is not null
    )
  );

grant select on table public.staff_activity_log to authenticated;

create or replace function public.log_staff_activity(
  p_action text,
  p_entity_type text default null,
  p_entity_ref text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant uuid;
  v_status text;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select tenant_id, staff_status into v_tenant, v_status
  from public.profiles where id = auth.uid();

  if v_tenant is null then
    raise exception 'No tenant';
  end if;

  if lower(trim(coalesce(v_status, 'active'))) = 'inactive' then
    raise exception 'Inactive staff';
  end if;

  insert into public.staff_activity_log (
    tenant_id, actor_id, action, entity_type, entity_ref, metadata
  )
  values (
    v_tenant,
    auth.uid(),
    nullif(trim(p_action), ''),
    nullif(trim(p_entity_type), ''),
    nullif(trim(p_entity_ref), ''),
    coalesce(p_metadata, '{}'::jsonb)
  );
end;
$$;

grant execute on function public.log_staff_activity(text, text, text, jsonb) to authenticated;
