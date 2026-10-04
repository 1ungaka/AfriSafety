-- The Edge Function's service role must work without relying on
-- Supabase's "automatically expose new tables" default.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(5);

select ok(has_table_privilege('service_role', 'public.alerts', 'SELECT, UPDATE'),
  'dispatch-alert can read and claim alerts');
select ok(has_table_privilege('service_role', 'public.circle_members', 'SELECT'),
  'dispatch-alert can find recipients');
select ok(has_table_privilege('service_role', 'public.device_push_tokens', 'SELECT, DELETE'),
  'dispatch-alert can read and prune push tokens');
select ok(has_table_privilege('service_role', 'public.devices', 'SELECT'),
  'dispatch-alert can skip revoked devices');
select ok(not has_table_privilege('authenticated', 'public.circle_invites', 'SELECT'),
  'signed-in users still cannot read invite rows');

select * from finish();
rollback;
