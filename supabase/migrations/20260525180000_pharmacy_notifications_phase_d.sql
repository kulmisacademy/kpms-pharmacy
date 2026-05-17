-- Phase D: extend existing pharmacy_notifications + per-user reads, preferences, push tokens.
-- Base table created in 20260523120000_pharmacy_operational_cloud.sql

alter table public.pharmacy_notifications
  add column if not exists kind text not null default 'general';

-- ─── Per-user read state (multi-staff tenants) ───────────────────────────────

create table if not exists public.pharmacy_notification_reads (
  notification_id uuid not null references public.pharmacy_notifications (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (notification_id, user_id)
);

create index if not exists pharmacy_notification_reads_user_idx
  on public.pharmacy_notification_reads (user_id, read_at desc);

-- ─── Preferences (per user, tenant-scoped) ───────────────────────────────────

create table if not exists public.pharmacy_notification_preferences (
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  prefs jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (tenant_id, user_id)
);

-- ─── FCM tokens ────────────────────────────────────────────────────────────

create table if not exists public.pharmacy_push_tokens (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  token text not null,
  platform text not null default 'android',
  updated_at timestamptz not null default now(),
  unique (user_id, token)
);

create index if not exists pharmacy_push_tokens_tenant_idx on public.pharmacy_push_tokens (tenant_id);

-- ─── RLS ─────────────────────────────────────────────────────────────────────

alter table public.pharmacy_notification_reads enable row level security;
alter table public.pharmacy_notification_preferences enable row level security;
alter table public.pharmacy_push_tokens enable row level security;

drop policy if exists pharmacy_notification_reads_select on public.pharmacy_notification_reads;
create policy pharmacy_notification_reads_select on public.pharmacy_notification_reads
  for select to authenticated
  using (
    user_id = auth.uid()
    and exists (
      select 1 from public.pharmacy_notifications n
      where n.id = pharmacy_notification_reads.notification_id
        and n.tenant_id = public.kpms_my_tenant_id()
    )
  );

drop policy if exists pharmacy_notification_reads_insert on public.pharmacy_notification_reads;
create policy pharmacy_notification_reads_insert on public.pharmacy_notification_reads
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.pharmacy_notifications n
      where n.id = pharmacy_notification_reads.notification_id
        and n.tenant_id = public.kpms_my_tenant_id()
    )
  );

drop policy if exists pharmacy_notification_prefs_all on public.pharmacy_notification_preferences;
create policy pharmacy_notification_prefs_all on public.pharmacy_notification_preferences
  for all to authenticated
  using (tenant_id = public.kpms_my_tenant_id() and user_id = auth.uid())
  with check (tenant_id = public.kpms_my_tenant_id() and user_id = auth.uid());

drop policy if exists pharmacy_push_tokens_select on public.pharmacy_push_tokens;
create policy pharmacy_push_tokens_select on public.pharmacy_push_tokens
  for select to authenticated
  using (tenant_id = public.kpms_my_tenant_id() and user_id = auth.uid());

drop policy if exists pharmacy_push_tokens_insert on public.pharmacy_push_tokens;
create policy pharmacy_push_tokens_insert on public.pharmacy_push_tokens
  for insert to authenticated
  with check (tenant_id = public.kpms_my_tenant_id() and user_id = auth.uid());

drop policy if exists pharmacy_push_tokens_update on public.pharmacy_push_tokens;
create policy pharmacy_push_tokens_update on public.pharmacy_push_tokens
  for update to authenticated
  using (tenant_id = public.kpms_my_tenant_id() and user_id = auth.uid())
  with check (tenant_id = public.kpms_my_tenant_id() and user_id = auth.uid());

drop policy if exists pharmacy_push_tokens_delete on public.pharmacy_push_tokens;
create policy pharmacy_push_tokens_delete on public.pharmacy_push_tokens
  for delete to authenticated
  using (tenant_id = public.kpms_my_tenant_id() and user_id = auth.uid());

grant select, insert on table public.pharmacy_notification_reads to authenticated;
grant select, insert, update, delete on table public.pharmacy_notification_preferences to authenticated;
grant select, insert, update, delete on table public.pharmacy_push_tokens to authenticated;

-- Realtime for notification inserts/updates (idempotent)
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'pharmacy_notifications'
  ) then
    execute 'alter publication supabase_realtime add table public.pharmacy_notifications';
  end if;
exception
  when duplicate_object then null;
end $$;
