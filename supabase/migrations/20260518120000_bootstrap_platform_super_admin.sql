-- One-time bootstrap: first authenticated user becomes platform_super_admin when none exists.
-- After production setup, revoke: revoke execute on function public.bootstrap_platform_super_admin_if_vacant() from authenticated;

create or replace function public.bootstrap_platform_super_admin_if_vacant()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
  v_n int;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select count(*)::int into v_count
  from public.profiles
  where role in ('platform_super_admin', 'super_admin');

  if v_count > 0 then
    raise exception 'Platform operator already exists';
  end if;

  update public.profiles
  set
    role = 'platform_super_admin',
    updated_at = now()
  where id = auth.uid();

  get diagnostics v_n = row_count;
  if v_n = 0 then
    raise exception 'Profile row missing';
  end if;
end;
$$;

revoke all on function public.bootstrap_platform_super_admin_if_vacant() from public;
grant execute on function public.bootstrap_platform_super_admin_if_vacant() to authenticated;
