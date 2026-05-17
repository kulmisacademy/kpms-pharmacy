-- Password-reset audit (service_role / Edge only) + session revocation after password change.

create table if not exists public.password_reset_audit (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  event text not null,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_password_reset_audit_created
  on public.password_reset_audit (created_at desc);

alter table public.password_reset_audit enable row level security;

-- Intentionally no policies: only service_role (Edge) bypasses RLS for writes.

create or replace function public.kpms_revoke_auth_user_refresh_tokens(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = auth, public
as $$
begin
  delete from auth.refresh_tokens where user_id = p_user_id;
end;
$$;

revoke all on function public.kpms_revoke_auth_user_refresh_tokens(uuid) from public;
grant execute on function public.kpms_revoke_auth_user_refresh_tokens(uuid) to service_role;
