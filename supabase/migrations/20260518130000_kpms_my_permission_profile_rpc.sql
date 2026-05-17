-- Reliable permission read for the signed-in user.
-- Direct `select from profiles` can return no row under RLS misconfiguration or policy drift;
-- this RPC always reads the caller's row with definer rights (still scoped to auth.uid()).

create or replace function public.kpms_my_permission_profile()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  (
    select jsonb_build_object(
      'role', p.role,
      'tenant_id', p.tenant_id,
      'permissions', coalesce(p.permissions, '{}'::jsonb),
      'staff_status', coalesce(p.staff_status, 'active')
    )
    from public.profiles p
    where p.id = auth.uid()
    limit 1
  );
$$;

revoke all on function public.kpms_my_permission_profile() from public;
grant execute on function public.kpms_my_permission_profile() to authenticated;

-- Invoker helper can false-negative when nested inside RLS policy checks; definer read is stable.
create or replace function public.kpms_is_platform_super_admin()
returns boolean
language sql
stable
security definer
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
