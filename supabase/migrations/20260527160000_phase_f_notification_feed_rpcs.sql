-- Phase F: server-side unread count and mark-all-read for paginated notification feeds.

create or replace function public.kpms_notification_unread_count()
returns bigint
language sql
stable
security invoker
set search_path = public
as $$
  select count(*)::bigint
  from public.pharmacy_notifications n
  where n.tenant_id = public.kpms_my_tenant_id()
    and not exists (
      select 1
      from public.pharmacy_notification_reads r
      where r.notification_id = n.id
        and r.user_id = auth.uid()
    );
$$;

create or replace function public.kpms_notification_mark_all_read()
returns bigint
language sql
security invoker
set search_path = public
as $$
  with ins as (
    insert into public.pharmacy_notification_reads (notification_id, user_id, read_at)
    select n.id, auth.uid(), now()
    from public.pharmacy_notifications n
    where n.tenant_id = public.kpms_my_tenant_id()
      and not exists (
        select 1
        from public.pharmacy_notification_reads r
        where r.notification_id = n.id
          and r.user_id = auth.uid()
      )
    returning 1
  )
  select count(*)::bigint from ins;
$$;

grant execute on function public.kpms_notification_unread_count() to authenticated;
grant execute on function public.kpms_notification_mark_all_read() to authenticated;
