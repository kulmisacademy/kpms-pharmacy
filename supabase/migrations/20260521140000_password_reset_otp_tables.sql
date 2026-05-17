-- KPMS custom password reset (OTP + challenge) — Edge Functions (service_role) only.
-- No client/anon access; RLS blocks direct reads/writes from the app.

create table if not exists public.password_reset_otps (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  otp_hash text not null,
  expires_at timestamptz not null,
  used boolean not null default false,
  verify_attempts int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_password_reset_otps_email_created
  on public.password_reset_otps (email, created_at desc);

create table if not exists public.password_reset_challenges (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  token_hash text not null,
  expires_at timestamptz not null,
  used boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_password_reset_challenges_email_token
  on public.password_reset_challenges (email, token_hash)
  where used = false;

alter table public.password_reset_otps enable row level security;
alter table public.password_reset_challenges enable row level security;

-- Intentionally no policies: only service_role (Edge) bypasses RLS.

-- Resolve auth user id by email (service_role / Edge only).
create or replace function public.kpms_auth_user_id_by_email(p_email text)
returns uuid
language sql
security definer
set search_path = auth, public
stable
as $$
  select u.id
  from auth.users u
  where lower(trim(u.email)) = lower(trim(p_email))
  limit 1;
$$;

revoke all on function public.kpms_auth_user_id_by_email(text) from public;
grant execute on function public.kpms_auth_user_id_by_email(text) to service_role;
