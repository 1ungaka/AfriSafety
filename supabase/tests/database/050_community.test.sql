-- Phase 4: community reports are k-anonymous, rate limited, moderated.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;

select no_plan();

insert into auth.users (id, email) values
  ('a0000000-0000-4000-8000-000000000001', 'alice@example.com'),
  ('b0000000-0000-4000-8000-000000000002', 'bob@example.com'),
  ('c0000000-0000-4000-8000-000000000003', 'carol@example.com'),
  ('d0000000-0000-4000-8000-000000000004', 'dan@example.com'),
  ('e0000000-0000-4000-8000-000000000005', 'eve@example.com'),
  ('f0000000-0000-4000-8000-000000000006', 'mod@example.com');
insert into private.moderators (user_id) values ('f0000000-0000-4000-8000-000000000006');

create function pg_temp.act_as(p uuid) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p, 'role', 'authenticated')::text, true);
$$;
grant execute on function pg_temp.act_as(uuid) to authenticated;

set local role authenticated;

select pg_temp.act_as('a0000000-0000-4000-8000-000000000001');
select throws_ok(
  $$ select submit_report('theft', -2620, 2804, current_date, 3::smallint) $$,
  'P0001', 'consent_required', 'reporting needs the separate community consent');

-- Everyone consents to the community feature.
select pg_temp.act_as('a0000000-0000-4000-8000-000000000001');
insert into consents (consent_type, policy_version) values ('community', '1');
select pg_temp.act_as('b0000000-0000-4000-8000-000000000002');
insert into consents (consent_type, policy_version) values ('community', '1');
select pg_temp.act_as('c0000000-0000-4000-8000-000000000003');
insert into consents (consent_type, policy_version) values ('community', '1');
select pg_temp.act_as('d0000000-0000-4000-8000-000000000004');
insert into consents (consent_type, policy_version) values ('community', '1');
select pg_temp.act_as('e0000000-0000-4000-8000-000000000005');
insert into consents (consent_type, policy_version) values ('community', '1');

select pg_temp.act_as('a0000000-0000-4000-8000-000000000001');
select lives_ok($$ select submit_report('theft', -2620, 2804, current_date, 3::smallint) $$,
  'Alice reports a theft in a grid square');
select throws_ok($$ select * from incident_reports $$, '42501', null,
  'nobody can read raw reports');
select throws_ok(
  $$ select submit_report('theft', -2620, 2804, current_date + 5, 3::smallint) $$,
  '23514', null, 'future dates are rejected');
select throws_ok(
  $$ select * from community_cells(-3000, -2000, 2700, 2900) $$,
  '22023', 'area_too_large', 'the map can only be read in small areas');

select pg_temp.act_as('b0000000-0000-4000-8000-000000000002');
select lives_ok($$ select submit_report('theft', -2620, 2804, current_date, 2::smallint) $$,
  'Bob reports the same square');
select is((select count(*)::int from community_cells(-2630, -2610, 2800, 2810)), 0,
  'two reporters are not enough to show anything (k = 3)');

select pg_temp.act_as('c0000000-0000-4000-8000-000000000003');
select lives_ok($$ select submit_report('theft', -2620, 2804, current_date, 4::smallint) $$,
  'Carol reports it too');
select results_eq(
  $$ select cell_lat, cell_lon, category, reporters from community_cells(-2630, -2610, 2800, 2810) $$,
  $$ values (-2620, 2804, 'theft'::text, 3) $$,
  'with 3 different reporters the square shows a count, not who or when');

select pg_temp.act_as('a0000000-0000-4000-8000-000000000001');
select lives_ok($$ select submit_report('theft', -2620, 2804, current_date, 5::smallint) $$,
  'reporting again the same day is accepted');
select is((select reporters from community_cells(-2630, -2610, 2800, 2810)), 3,
  '... but counts once');

-- Rate limit: 10 reports a day.
select pg_temp.act_as('e0000000-0000-4000-8000-000000000005');
do $$ begin
  for i in 1..10 loop
    perform submit_report('suspicious', -2500 - i, 2800, current_date, 1::smallint);
  end loop;
end $$;
select throws_ok(
  $$ select submit_report('suspicious', -2400, 2800, current_date, 1::smallint) $$,
  'P0001', 'rate_limited', 'the 11th report in a day is refused');

-- Moderation.
select is(is_moderator(), false, 'ordinary users are not moderators');
select throws_ok($$ select * from moderation_queue() $$, '42501', 'not_a_moderator',
  'only moderators see the moderation queue');
select throws_ok($$ select moderate_cell(-2620, 2804, 'theft', false) $$, '42501',
  'not_a_moderator', 'only moderators decide');

-- Five different people flag the square: it's hidden pending review.
select pg_temp.act_as('a0000000-0000-4000-8000-000000000001');
select flag_cell(-2620, 2804, 'theft');
select pg_temp.act_as('b0000000-0000-4000-8000-000000000002');
select flag_cell(-2620, 2804, 'theft');
select pg_temp.act_as('c0000000-0000-4000-8000-000000000003');
select flag_cell(-2620, 2804, 'theft');
select pg_temp.act_as('d0000000-0000-4000-8000-000000000004');
select flag_cell(-2620, 2804, 'theft');
select flag_cell(-2620, 2804, 'theft');
select is((select count(*)::int from community_cells(-2630, -2610, 2800, 2810)), 1,
  'four distinct flaggers (one flagged twice) do not hide it yet');
select pg_temp.act_as('e0000000-0000-4000-8000-000000000005');
select flag_cell(-2620, 2804, 'theft');
select is((select count(*)::int from community_cells(-2630, -2610, 2800, 2810)), 0,
  'five distinct flaggers hide it until a moderator decides');

select pg_temp.act_as('f0000000-0000-4000-8000-000000000006');
select is(is_moderator(), true, 'the moderator is recognised');
select results_eq(
  $$ select category, reporters, flags from moderation_queue() $$,
  $$ values ('theft'::text, 3, 5) $$,
  'moderators see counts, not identities');
select lives_ok($$ select moderate_cell(-2620, 2804, 'theft', true) $$, 'the moderator keeps it');
select is((select count(*)::int from community_cells(-2630, -2610, 2800, 2810)), 1,
  'kept squares show again despite earlier flags');
select lives_ok($$ select moderate_cell(-2620, 2804, 'theft', false) $$, 'the moderator hides it');
select is((select count(*)::int from community_cells(-2630, -2610, 2800, 2810)), 0,
  'hidden squares stay hidden');
select lives_ok($$ select moderate_cell(-2620, 2804, 'theft', true) $$, 'and keeps it again');

-- Bans (owner, in the SQL Editor).
set local role postgres;
insert into private.community_bans (user_id, reason) values ('c0000000-0000-4000-8000-000000000003', 'test');
set local role authenticated;
select pg_temp.act_as('a0000000-0000-4000-8000-000000000001');
select is((select count(*)::int from community_cells(-2630, -2610, 2800, 2810)), 0,
  'a banned reporter''s reports stop counting (the square falls below k)');
select pg_temp.act_as('c0000000-0000-4000-8000-000000000003');
select throws_ok($$ select submit_report('theft', -2620, 2804, current_date, 1::smallint) $$,
  '42501', 'banned', 'banned users cannot report');

select is(
  (select count(*)::int from pg_tables where schemaname = 'public'
     and tablename in ('incident_reports', 'community_flags', 'community_decisions')
     and not rowsecurity), 0,
  'every community table has RLS');

-- Retention.
set local role postgres;
update incident_reports set created_at = now() - interval '91 days',
    occurred_on = (now() - interval '91 days')::date
 where reporter_id = 'e0000000-0000-4000-8000-000000000005';
select private.purge_expired();
select is((select count(*)::int from incident_reports
            where reporter_id = 'e0000000-0000-4000-8000-000000000005'), 0,
  'reports older than 90 days are deleted');

select * from finish();
rollback;
