-- Ensure Edge (service_role) can write audit rows.
grant insert, select on public.password_reset_audit to service_role;
