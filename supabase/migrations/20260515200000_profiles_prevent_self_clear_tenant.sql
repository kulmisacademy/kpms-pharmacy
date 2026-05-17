-- Prevent authenticated users from accidentally NULLing their own profiles.tenant_id via PostgREST.
-- Server-side RPCs acting on other users still run as the invoker; this only blocks self-row updates.

create or replace function public.kpms_prevent_profiles_self_clear_tenant()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if tg_op = 'UPDATE'
     and old.tenant_id is not null
     and new.tenant_id is null
     and new.id = auth.uid() then
    raise exception 'tenant_id cannot be cleared on your own profile';
  end if;
  return new;
end;
$$;

drop trigger if exists kpms_prevent_profiles_self_clear_tenant on public.profiles;
create trigger kpms_prevent_profiles_self_clear_tenant
before update on public.profiles
for each row execute procedure public.kpms_prevent_profiles_self_clear_tenant();
