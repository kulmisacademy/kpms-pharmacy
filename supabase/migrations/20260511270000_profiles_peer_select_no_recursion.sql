-- Fix Postgres 42P17 "infinite recursion detected in policy for relation profiles".
-- `profiles_select_tenant_peers` must not subquery `profiles`: RLS re-applies the same
-- policy when resolving auth.uid()'s row inside the subquery → unbounded recursion.
--
-- Read caller tenant_id via SECURITY DEFINER so the lookup bypasses RLS safely.

create or replace function public.kpms_auth_profile_tenant_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select tenant_id from public.profiles where id = auth.uid() limit 1;
$$;

revoke all on function public.kpms_auth_profile_tenant_id() from public;
grant execute on function public.kpms_auth_profile_tenant_id() to authenticated;

drop policy if exists "profiles_select_tenant_peers" on public.profiles;
create policy "profiles_select_tenant_peers"
  on public.profiles
  for select
  to authenticated
  using (
    tenant_id is not null
    and tenant_id = public.kpms_auth_profile_tenant_id()
  );
