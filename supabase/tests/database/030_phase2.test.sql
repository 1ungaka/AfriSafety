-- Behavioural RLS tests for Phase 2: Circle events, check-ins, escrowed
-- alerts, the watchdog and retention.
--   Alice: owns Family    Bob: member    Eve: outsider
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;

select no_plan();

create temp table t_ids (name text primary key, val text) on commit drop;
grant all on t_ids to authenticated;

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-4000-8000-000000000001', 'alice@example.com'),
  ('bbbbbbbb-0000-4000-8000-000000000002', 'bob@example.com'),
  ('eeeeeeee-0000-4000-8000-000000000004', 'eve@example.com');

set local role authenticated;

set local request.jwt.claims = '{"sub":"aaaaaaaa-0000-4000-8000-000000000001","role":"authenticated"}';
insert into profiles (id, display_name) values (auth.uid(), 'Alice');
insert into devices (id, box_public_key, sign_public_key, platform) values
  ('aaaaaaaa-0000-4000-8000-0000000000d1',
   encode(sha256('alice-box'), 'base64'), encode(sha256('alice-sign'), 'base64'), 'android');
insert into consents (consent_type, policy_version) values
  ('location_sharing', '1'), ('age_18_plus', '1'), ('terms_privacy', '1');
insert into t_ids values ('family', (select create_circle('Family')::text));
insert into t_ids values ('code', (select create_invite((select val::uuid from t_ids where name = 'family'))));

set local request.jwt.claims = '{"sub":"bbbbbbbb-0000-4000-8000-000000000002","role":"authenticated"}';
insert into profiles (id, display_name) values (auth.uid(), 'Bob');
insert into devices (id, box_public_key, sign_public_key, platform) values
  ('bbbbbbbb-0000-4000-8000-0000000000d2',
   encode(sha256('bob-box'), 'base64'), encode(sha256('bob-sign'), 'base64'), 'android');
insert into consents (consent_type, policy_version) values
  ('location_sharing', '1'), ('age_18_plus', '1'), ('terms_privacy', '1');
select accept_invite((select val from t_ids where name = 'code'));

set local request.jwt.claims = '{"sub":"eeeeeeee-0000-4000-8000-000000000004","role":"authenticated"}';
insert into profiles (id, display_name) values (auth.uid(), 'Eve');
insert into devices (id, box_public_key, sign_public_key, platform) values
  ('eeeeeeee-0000-4000-8000-0000000000d4',
   encode(sha256('eve-box'), 'base64'), encode(sha256('eve-sign'), 'base64'), 'android');

-- ===========================================================================
-- Circle events
-- ===========================================================================

set local request.jwt.claims = '{"sub":"bbbbbbbb-0000-4000-8000-000000000002","role":"authenticated"}';
select lives_ok(
  $$ insert into circle_events (id, circle_id, sender_id, sender_device_id, key_version, ciphertext)
     values ('e0000000-0000-4000-8000-000000000001', (select val::uuid from t_ids where name = 'family'),
             auth.uid(), 'bbbbbbbb-0000-4000-8000-0000000000d2', 1, 'Y2lwaGVy') $$,
  'Bob posts an encrypted event from his device');
select throws_ok(
  $$ insert into circle_events (id, circle_id, sender_id, sender_device_id, key_version, ciphertext)
     values (gen_random_uuid(), (select val::uuid from t_ids where name = 'family'),
             'aaaaaaaa-0000-4000-8000-000000000001', 'bbbbbbbb-0000-4000-8000-0000000000d2', 1, 'eA==') $$,
  '42501', null, 'cannot post an event as someone else');
select throws_ok(
  $$ insert into circle_events (id, circle_id, sender_id, sender_device_id, key_version, ciphertext)
     values (gen_random_uuid(), (select val::uuid from t_ids where name = 'family'),
             auth.uid(), 'aaaaaaaa-0000-4000-8000-0000000000d1', 1, 'eA==') $$,
  '42501', null, 'cannot post from someone else''s device');

select lives_ok($$ select set_sharing_paused(null, true) $$, 'Bob pauses');
select throws_ok(
  $$ insert into circle_events (id, circle_id, sender_id, sender_device_id, key_version, ciphertext)
     values (gen_random_uuid(), (select val::uuid from t_ids where name = 'family'),
             auth.uid(), 'bbbbbbbb-0000-4000-8000-0000000000d2', 1, 'eA==') $$,
  '42501', null, 'no events while paused (they reveal location)');
select lives_ok($$ select set_sharing_paused(null, false) $$, 'Bob resumes');

set local request.jwt.claims = '{"sub":"aaaaaaaa-0000-4000-8000-000000000001","role":"authenticated"}';
select is((select count(*)::int from circle_events), 1, 'members see events (as ciphertext)');
delete from circle_events where id = 'e0000000-0000-4000-8000-000000000001';
select is((select count(*)::int from circle_events), 1, 'members cannot delete someone else''s event');

set local request.jwt.claims = '{"sub":"eeeeeeee-0000-4000-8000-000000000004","role":"authenticated"}';
select is((select count(*)::int from circle_events), 0, 'outsider: no events');
select throws_ok(
  $$ insert into circle_events (id, circle_id, sender_id, sender_device_id, key_version, ciphertext)
     values (gen_random_uuid(), (select val::uuid from t_ids where name = 'family'),
             auth.uid(), 'eeeeeeee-0000-4000-8000-0000000000d4', 1, 'eA==') $$,
  '42501', null, 'outsider cannot post events into a Circle');

-- ===========================================================================
-- Check-ins and escrowed alerts
-- ===========================================================================

set local request.jwt.claims = '{"sub":"bbbbbbbb-0000-4000-8000-000000000002","role":"authenticated"}';
select lives_ok(
  $$ insert into checkins (id, kind, deadline)
     values ('c0000000-0000-4000-8000-000000000001', 'timer', now() + interval '30 minutes') $$,
  'Bob starts a check-in timer');
select lives_ok(
  $$ insert into checkin_escrows (checkin_id, circle_id, alert_id, sender_device_id, key_version, ciphertext)
     values ('c0000000-0000-4000-8000-000000000001', (select val::uuid from t_ids where name = 'family'),
             'a1000000-0000-4000-8000-000000000001', 'bbbbbbbb-0000-4000-8000-0000000000d2', 1, 'ZXNjcm93') $$,
  'Bob escrows an encrypted alert for Family');
select throws_ok(
  $$ insert into checkin_escrows (checkin_id, circle_id, alert_id, sender_device_id, key_version, ciphertext)
     values ('c0000000-0000-4000-8000-000000000001', gen_random_uuid(),
             gen_random_uuid(), 'bbbbbbbb-0000-4000-8000-0000000000d2', 1, 'eA==') $$,
  '42501', null, 'cannot escrow an alert for a Circle you are not in');
select throws_ok(
  $$ insert into checkins (id, kind, deadline) values (gen_random_uuid(), 'timer', now() + interval '2 days') $$,
  '23514', null, 'check-ins last at most 24 hours');
select throws_ok(
  $$ insert into checkins (id, user_id, kind, deadline)
     values (gen_random_uuid(), 'aaaaaaaa-0000-4000-8000-000000000001', 'timer', now() + interval '1 hour') $$,
  '42501', null, 'cannot start a check-in for someone else');
select throws_ok(
  $$ update checkins set status = 'missed' where id = 'c0000000-0000-4000-8000-000000000001' $$,
  '42501', null, 'only the watchdog can mark a check-in missed');
select throws_ok(
  $$ update checkins set kind = 'journey' where id = 'c0000000-0000-4000-8000-000000000001' $$,
  '42501', null, 'the kind cannot be changed');
select lives_ok(
  $$ update checkins set deadline = now() + interval '45 minutes' where id = 'c0000000-0000-4000-8000-000000000001' $$,
  'Bob extends his timer');

-- A second check-in that Bob cancels: its escrow must never be released.
insert into checkins (id, kind, deadline)
  values ('c0000000-0000-4000-8000-000000000002', 'journey', now() + interval '20 minutes');
insert into checkin_escrows (checkin_id, circle_id, alert_id, sender_device_id, key_version, ciphertext)
  values ('c0000000-0000-4000-8000-000000000002', (select val::uuid from t_ids where name = 'family'),
          'a1000000-0000-4000-8000-000000000002', 'bbbbbbbb-0000-4000-8000-0000000000d2', 1, 'ZXNjcm93');
select lives_ok(
  $$ update checkins set status = 'cancelled' where id = 'c0000000-0000-4000-8000-000000000002' $$,
  'Bob cancels a journey');

set local request.jwt.claims = '{"sub":"aaaaaaaa-0000-4000-8000-000000000001","role":"authenticated"}';
select is((select count(*)::int from checkins), 0, 'members cannot see each other''s check-ins');
select is((select count(*)::int from checkin_escrows), 0, 'members cannot see escrowed alerts early');

set local request.jwt.claims = '{"sub":"eeeeeeee-0000-4000-8000-000000000004","role":"authenticated"}';
select is((select count(*)::int from checkins), 0, 'outsider: no check-ins');
select throws_ok(
  $$ insert into checkin_escrows (checkin_id, circle_id, alert_id, sender_device_id, key_version, ciphertext)
     values ('c0000000-0000-4000-8000-000000000001', (select val::uuid from t_ids where name = 'family'),
             gen_random_uuid(), 'eeeeeeee-0000-4000-8000-0000000000d4', 1, 'eA==') $$,
  '42501', null, 'outsider cannot attach to someone else''s check-in');

select ok(not has_function_privilege('authenticated', 'private.expire_checkins()', 'execute'),
  'users cannot run the watchdog');
select ok(not has_function_privilege('authenticated', 'private.purge_expired()', 'execute'),
  'users cannot run the retention job');

-- ===========================================================================
-- The watchdog (runs as pg_cron: no user)
-- ===========================================================================

set local role postgres;
set local request.jwt.claims = '';
-- Time travel: Bob's timer started an hour ago and is now overdue.
update checkins set created_at = now() - interval '1 hour', deadline = now() - interval '1 minute'
 where id = 'c0000000-0000-4000-8000-000000000001';
update checkins set created_at = now() - interval '1 hour', deadline = now() - interval '1 minute'
 where id = 'c0000000-0000-4000-8000-000000000002';

select is(private.expire_checkins(), 1, 'the watchdog releases the overdue escrow (not the cancelled one)');
select is(private.expire_checkins(), 0, 'running it again releases nothing');
select is((select status from checkins where id = 'c0000000-0000-4000-8000-000000000001'), 'missed',
  'the overdue check-in is marked missed');
select is((select status from checkins where id = 'c0000000-0000-4000-8000-000000000002'), 'cancelled',
  'the cancelled check-in stays cancelled');

set local role authenticated;
set local request.jwt.claims = '{"sub":"aaaaaaaa-0000-4000-8000-000000000001","role":"authenticated"}';
select results_eq(
  $$ select id, incident_id, kind, ciphertext from alerts $$,
  $$ values ('a1000000-0000-4000-8000-000000000001'::uuid, 'c0000000-0000-4000-8000-000000000001'::uuid,
             'checkin_missed'::text, 'ZXNjcm93'::text) $$,
  'Alice receives the escrowed alert unchanged, linked to the check-in');

set local request.jwt.claims = '{"sub":"bbbbbbbb-0000-4000-8000-000000000002","role":"authenticated"}';
update checkins set status = 'completed' where id = 'c0000000-0000-4000-8000-000000000001';
select is((select status from checkins where id = 'c0000000-0000-4000-8000-000000000001'), 'missed',
  'a missed check-in cannot be quietly undone');
select lives_ok(
  $$ select resolve_incident('c0000000-0000-4000-8000-000000000001') $$,
  'Bob can mark the incident resolved ("I''m OK")');

set local request.jwt.claims = '{"sub":"eeeeeeee-0000-4000-8000-000000000004","role":"authenticated"}';
select is((select count(*)::int from alerts), 0, 'outsider: no released alerts');

-- ===========================================================================
-- Retention
-- ===========================================================================

set local role postgres;
set local request.jwt.claims = '';
insert into alerts (id, incident_id, circle_id, sender_id, sender_device_id, kind, key_version, ciphertext, created_at)
  values ('a1000000-0000-4000-8000-0000000000ff', gen_random_uuid(),
          (select val::uuid from t_ids where name = 'family'), 'bbbbbbbb-0000-4000-8000-000000000002',
          'bbbbbbbb-0000-4000-8000-0000000000d2', 'panic', 1, 'b2xk', now() - interval '31 days');
update circle_events set created_at = now() - interval '8 days';
-- (Skip the updated_at trigger for this backdate.)
set local session_replication_role = replica;
update checkins set updated_at = now() - interval '8 days'
 where id = 'c0000000-0000-4000-8000-000000000002';
set local session_replication_role = origin;

select lives_ok($$ select private.purge_expired() $$, 'retention job runs');
select is((select count(*)::int from alerts where id = 'a1000000-0000-4000-8000-0000000000ff'), 0,
  'alerts older than 30 days are deleted');
select is((select count(*)::int from alerts), 1, 'recent alerts are kept');
select is((select count(*)::int from circle_events), 0, 'events older than 7 days are deleted');
select is((select count(*)::int from checkins), 1, 'finished check-ins older than 7 days are deleted');
select is((select count(*)::int from checkin_escrows), 1, 'their escrows go with them');

select * from finish();
rollback;
