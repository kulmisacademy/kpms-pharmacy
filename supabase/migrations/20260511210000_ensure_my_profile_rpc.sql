-- Ensures public.profiles has a row for the current user (e.g. trigger was added after signup).
-- Called once from the client before reading tenant_id — avoids hammering Auth refresh tokens.

create or replace function public.ensure_my_profile()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  select u.id,
    coalesce(
      nullif(trim(u.raw_user_meta_data->>'full_name'), ''),
      split_part(coalesce(u.email, ''), '@', 1)
    )
  from auth.users u
  where u.id = auth.uid()
  on conflict (id) do nothing;
end;
$$;

grant execute on function public.ensure_my_profile() to authenticated;
