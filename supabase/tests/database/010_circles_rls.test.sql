-- Behavioural RLS tests for Phase 1, acting as real users:
--   Alice: creates the Family Circle (owner)
--   Bob, Carol: join with an invite code
--   Eve: an outsider who must never see or touch Family's data
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
-- Let impersonated users call pgTAP (rolled back at the end).
grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;

select no_plan();

-- Scratch table for passing ids between users.
create temp table t_ids (name text primary key, val text) on commit drop;
grant all on t_ids to authenticated;

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-4000-8000-000000000001', 'alice@example.com'),
  ('bbbbbbbb-0000-4000-8000-000000000002', 'bob@example.com'),
  ('cccccccc-0000-4000-8000-000000000003', 'carol@example.com'),
  ('eeeeeeee-0000-4000-8000-000000000004', 'eve@example.com');

set local role authenticated;

-- ===========================================================================
-- Onboarding as each user: profile, device, consents (Eve skips consent)
-- ===========================================================================

set local request.jwt.claims = '{"sub":"aaaaaaaa-0000-4000-8000-000000000001","role":"authenticated"}';
insert into profiles (id, display_name) values (auth.uid(), 'Alice');
insert into devices (id, box_public_key, sign_public_key, platform) values
  ('aaaaaaaa-0000-4000-8000-0000000000d1',
   encode(sha256('alice-box'), 'base64'), encode(sha256('alice-sign'), 'base64'), 'android');
insert into consents (consent_type, policy_version) values
  ('location_sharing', '1'), ('age_18_plus', '1'), ('terms_privacy', '1');

set local request.jwt.claims = '{"sub":"bbbbbbbb-0000-4000-8000-000000000002","role":"authenticated"}';
insert into profiles (id, display_name) values (auth.uid(), 'Bob');
insert into devices (id, box_public_key, sign_public_key, platform) values
  ('bbbbbbbb-0000-4000-8000-0000000000d2',
   encode(sha256('bob-box'), 'base64'), encode(sha256('bob-sign'), 'base64'), 'android');

set local request.jwt.claims = '{"sub":"cccccccc-0000-4000-8000-000000000003","role":"authenticated"}';
insert into profiles (id, display_name) values (auth.uid(), 'Carol');
insert into devices (id, box_public_key, sign_public_key, platform) values
  ('cccccccc-0000-4000-8000-0000000000d3',
   encode(sha256('carol-box'), 'base64'), encode(sha256('carol-sign'), 'base64'), 'android');
insert into consents (consent_type, policy_version) values ('location_sharing', '1'), ('age_18_plus', '1');

set local request.jwt.claims = '{"sub":"eeeeeeee-0000-4000-8000-000000000004","role":"authenticated"}';
insert into profiles (id, display_name) values (auth.uid(), 'Eve');
insert into devices (id, box_public_key, sign_public_key, platform) values
  ('eeeeeeee-0000-4000-8000-0000000000d4',
   encode(sha256('eve-box'), 'base64'), encode(sha256('eve-sign'), 'base64'), 'android');

select throws_ok(
  $$ insert into profiles (id, display_name) values ('aaaaaaaa-0000-4000-8000-000000000001', 'Not Alice') $$,
  '42501', null, 'cannot create a profile for someone else');
select throws_ok(
  $$ insert into consents (user_id, consent_type, policy_version)
     values ('aaaaaaaa-0000-4000-8000-000000000001', 'location_sharing', '1') $$,
  '42501', null, 'cannot record consent on someone else''s behalf');
select throws_ok(
  $$ select create_circle('Eve''s circle') $$,
  'P0001', 'consent_required', 'creating a Circle requires location-sharing and 18+ consent');

-- ===========================================================================
-- Alice creates Family and an invite
-- ===========================================================================

set local request.jwt.claims = '{"sub":"aaaaaaaa-0000-4000-8000-000000000001","role":"authenticated"}';
insert into t_ids values ('family', (select create_circle('Family')::text));
insert into t_ids values ('code', (select create_invite((select val::uuid from t_ids where name = 'family'))));

select is((select count(*)::int from circles), 1, 'Alice sees her Circle');
select is((select role from circle_members where user_id = auth.uid()), 'owner', 'Alice is the owner');
select matches((select val from t_ids where name = 'code'), '^[0-9A-HJKMNP-TV-Z]{5}-[0-9A-HJKMNP-TV-Z]{5}$',
  'invite codes are 10 Crockford base32 characters');
select throws_ok($$ select * from circle_invites $$, '42501', null,
  'invite rows (even hashed) are not readable');
select throws_ok($$ update devices set box_public_key = encode(sha256('swap'), 'base64') $$,
  '42501', null, 'device public keys cannot be edited after registration');

-- ===========================================================================
-- Eve, an outsider, sees nothing
-- ===========================================================================

set local request.jwt.claims = '{"sub":"eeeeeeee-0000-4000-8000-000000000004","role":"authenticated"}';
select is((select count(*)::int from circles), 0, 'outsider: no circles');
select is((select count(*)::int from circle_members), 0, 'outsider: no members');
select is((select count(*)::int from profiles where id <> auth.uid()), 0, 'outsider: no other profiles');
select is((select count(*)::int from devices where user_id <> auth.uid()), 0, 'outsider: no other devices');
select throws_ok(
  $$ select create_invite((select val::uuid from t_ids where name = 'family')) $$,
  '42501', 'not_a_member', 'outsider cannot create invites');
select throws_ok(
  $$ select set_share_level((select val::uuid from t_ids where name = 'family'),
       'aaaaaaaa-0000-4000-8000-000000000001', 'sos_only') $$,
  '42501', 'not_a_member', 'outsider cannot change share levels');
select is((select count(*)::int from preview_invite('00000-00000')), 0,
  'a wrong code reveals nothing');
select throws_ok($$ select accept_invite('00000-00000') $$, 'P0001', 'consent_required',
  'joining needs consent before any code is checked');

-- ===========================================================================
-- Bob and Carol join
-- ===========================================================================

set local request.jwt.claims = '{"sub":"bbbbbbbb-0000-4000-8000-000000000002","role":"authenticated"}';
select is(
  (select circle_name from preview_invite((select val from t_ids where name = 'code'))),
  'Family', 'Bob can preview the invite');
select is(
  (select inviter_name from preview_invite(lower(replace((select val from t_ids where name = 'code'), '-', ' ')))),
  'Alice', 'codes are case- and separator-insensitive');
select throws_ok(
  $$ select accept_invite((select val from t_ids where name = 'code')) $$,
  'P0001', 'consent_required', 'joining requires consent first');
insert into consents (consent_type, policy_version) values ('location_sharing', '1'), ('age_18_plus', '1');
select is(accept_invite('00000-00000'), null, 'a wrong code joins nothing');
select is(
  accept_invite((select val from t_ids where name = 'code'))::text,
  (select val from t_ids where name = 'family'), 'Bob joins Family');
select is((select count(*)::int from circle_members), 2, 'Bob now sees both members');
select is((select display_name from profiles where id = 'aaaaaaaa-0000-4000-8000-000000000001'),
  'Alice', 'members see each other''s display names');
select is((select count(*)::int from devices where user_id = 'aaaaaaaa-0000-4000-8000-000000000001'),
  1, 'members see each other''s device public keys');

set local request.jwt.claims = '{"sub":"cccccccc-0000-4000-8000-000000000003","role":"authenticated"}';
select lives_ok($$ select accept_invite((select val from t_ids where name = 'code')) $$, 'Carol joins Family');

set local request.jwt.claims = '{"sub":"aaaaaaaa-0000-4000-8000-000000000001","role":"authenticated"}';
select is(
  (select count(*)::int from security_events where kind = 'member_joined'),
  2, 'Alice is told each time someone joins');

-- ===========================================================================
-- Pausing is sovereign
-- ===========================================================================

select throws_ok(
  $$ update circle_members set sharing_paused = false
     where user_id = 'bbbbbbbb-0000-4000-8000-000000000002' $$,
  '42501', null, 'the owner cannot change another member''s pause state');
select throws_ok(
  $$ delete from circle_members where user_id = 'bbbbbbbb-0000-4000-8000-000000000002' $$,
  '42501', null, 'members cannot be removed with a direct delete');

set local request.jwt.claims = '{"sub":"bbbbbbbb-0000-4000-8000-000000000002","role":"authenticated"}';
select lives_ok($$ select set_sharing_paused(null, true) $$, 'Bob pauses all sharing');
select is(
  (select array_agg(user_id::text order by user_id) from circle_members where sharing_paused),
  array['bbbbbbbb-0000-4000-8000-000000000002'], 'only Bob is paused');

-- ===========================================================================
-- Locations: own device, own row, not while paused
-- ===========================================================================

select throws_ok(
  $$ insert into location_latest (circle_id, user_id, sender_device_id, key_version, ciphertext)
     values ((select val::uuid from t_ids where name = 'family'), auth.uid(),
             'bbbbbbbb-0000-4000-8000-0000000000d2', 1, 'AAAA') $$,
  '42501', null, 'no location writes while paused');
select lives_ok($$ select set_sharing_paused(null, false) $$, 'Bob resumes');
select lives_ok(
  $$ insert into location_latest (circle_id, user_id, sender_device_id, key_version, ciphertext)
     values ((select val::uuid from t_ids where name = 'family'), auth.uid(),
             'bbbbbbbb-0000-4000-8000-0000000000d2', 1, 'AAAA') $$,
  'Bob shares a location');
select throws_ok(
  $$ insert into location_latest (circle_id, user_id, sender_device_id, key_version, ciphertext)
     values ((select val::uuid from t_ids where name = 'family'), 'aaaaaaaa-0000-4000-8000-000000000001',
             'bbbbbbbb-0000-4000-8000-0000000000d2', 1, 'AAAA') $$,
  '42501', null, 'cannot write a location as someone else');
select throws_ok(
  $$ update location_latest set sender_device_id = 'aaaaaaaa-0000-4000-8000-0000000000d1'
     where user_id = auth.uid() $$,
  '42501', null, 'cannot send from someone else''s device');

set local request.jwt.claims = '{"sub":"aaaaaaaa-0000-4000-8000-000000000001","role":"authenticated"}';
select is((select count(*)::int from location_latest), 1, 'members see shared locations (as ciphertext)');
select is(
  (select count(*)::int from location_latest where user_id = 'bbbbbbbb-0000-4000-8000-000000000002'
     and ciphertext = 'AAAA'), 1, 'the server only ever holds what the device sent');

set local request.jwt.claims = '{"sub":"eeeeeeee-0000-4000-8000-000000000004","role":"authenticated"}';
select is((select count(*)::int from location_latest), 0, 'outsider: no locations');

-- ===========================================================================
-- Sender key envelopes (D7)
-- ===========================================================================

set local request.jwt.claims = '{"sub":"aaaaaaaa-0000-4000-8000-000000000001","role":"authenticated"}';
select lives_ok(
  $$ insert into sender_key_envelopes (circle_id, sender_device_id, sender_id, channel, key_version,
       recipient_device_id, sealed_key, signature)
     values ((select val::uuid from t_ids where name = 'family'), 'aaaaaaaa-0000-4000-8000-0000000000d1',
       auth.uid(), 'location', 1, 'bbbbbbbb-0000-4000-8000-0000000000d2', 'AAAA',
       encode(sha512('sig'), 'base64')) $$,
  'Alice seals her location key to Bob''s device');
select throws_ok(
  $$ insert into sender_key_envelopes (circle_id, sender_device_id, sender_id, channel, key_version,
       recipient_device_id, sealed_key, signature)
     values ((select val::uuid from t_ids where name = 'family'), 'aaaaaaaa-0000-4000-8000-0000000000d1',
       auth.uid(), 'location', 1, 'eeeeeeee-0000-4000-8000-0000000000d4', 'AAAA',
       encode(sha512('sig'), 'base64')) $$,
  '42501', null, 'keys cannot be sealed to a non-member''s device');
select throws_ok(
  $$ insert into sender_key_envelopes (circle_id, sender_device_id, sender_id, channel, key_version,
       recipient_device_id, sealed_key, signature)
     values ((select val::uuid from t_ids where name = 'family'), 'bbbbbbbb-0000-4000-8000-0000000000d2',
       'bbbbbbbb-0000-4000-8000-000000000002', 'location', 1, 'aaaaaaaa-0000-4000-8000-0000000000d1', 'AAAA',
       encode(sha512('sig'), 'base64')) $$,
  '42501', null, 'cannot forge an envelope from someone else''s device');

set local request.jwt.claims = '{"sub":"bbbbbbbb-0000-4000-8000-000000000002","role":"authenticated"}';
select is((select count(*)::int from sender_key_envelopes), 1, 'Bob sees the envelope addressed to him');

set local request.jwt.claims = '{"sub":"cccccccc-0000-4000-8000-000000000003","role":"authenticated"}';
select is((select count(*)::int from sender_key_envelopes), 0, 'Carol cannot see envelopes addressed to Bob');

set local request.jwt.claims = '{"sub":"eeeeeeee-0000-4000-8000-000000000004","role":"authenticated"}';
select is((select count(*)::int from sender_key_envelopes), 0, 'outsider: no envelopes');
select throws_ok(
  $$ insert into sender_key_envelopes (circle_id, sender_device_id, sender_id, channel, key_version,
       recipient_device_id, sealed_key, signature)
     values ((select val::uuid from t_ids where name = 'family'), 'eeeeeeee-0000-4000-8000-0000000000d4',
       auth.uid(), 'alert', 1, 'aaaaaaaa-0000-4000-8000-0000000000d1', 'AAAA',
       encode(sha512('sig'), 'base64')) $$,
  '42501', null, 'outsider cannot push keys into a Circle');

-- ===========================================================================
-- Share levels: chosen only by the sharer
-- ===========================================================================

set local request.jwt.claims = '{"sub":"aaaaaaaa-0000-4000-8000-000000000001","role":"authenticated"}';
select lives_ok(
  $$ select set_share_level((select val::uuid from t_ids where name = 'family'),
       'cccccccc-0000-4000-8000-000000000003', 'sos_only') $$,
  'Alice limits Carol to SOS alerts only');
select throws_ok(
  $$ select set_share_level((select val::uuid from t_ids where name = 'family'), auth.uid(), 'sos_only') $$,
  'P0001', 'invalid_viewer', 'a share level needs another member as viewer');
select throws_ok(
  $$ insert into share_levels (circle_id, sharer_id, viewer_id, level)
     values ((select val::uuid from t_ids where name = 'family'), 'bbbbbbbb-0000-4000-8000-000000000002',
       auth.uid(), 'live') $$,
  '42501', null, 'share levels cannot be written directly (only the sharer, via RPC)');

set local request.jwt.claims = '{"sub":"cccccccc-0000-4000-8000-000000000003","role":"authenticated"}';
select is((select level from share_levels where sharer_id = 'aaaaaaaa-0000-4000-8000-000000000001'),
  'sos_only', 'Carol can see that Alice limited her (honest status)');

set local request.jwt.claims = '{"sub":"bbbbbbbb-0000-4000-8000-000000000002","role":"authenticated"}';
select is((select count(*)::int from share_levels), 0, 'Bob cannot see share levels between Alice and Carol');

-- ===========================================================================
-- Alerts and receipts
-- ===========================================================================

select lives_ok(
  $$ insert into alerts (id, incident_id, circle_id, sender_id, sender_device_id, kind, key_version, ciphertext)
     values ('a1e70000-0000-4000-8000-000000000001', 'a1e70000-0000-4000-8000-0000000000ff',
       (select val::uuid from t_ids where name = 'family'), auth.uid(),
       'bbbbbbbb-0000-4000-8000-0000000000d2', 'panic', 1, 'AAAA') $$,
  'Bob raises a panic alert');
select throws_ok(
  $$ insert into alerts (id, incident_id, circle_id, sender_id, sender_device_id, kind, key_version, ciphertext)
     values ('a1e70000-0000-4000-8000-000000000002', 'a1e70000-0000-4000-8000-0000000000fe',
       (select val::uuid from t_ids where name = 'family'), 'aaaaaaaa-0000-4000-8000-000000000001',
       'bbbbbbbb-0000-4000-8000-0000000000d2', 'panic', 1, 'AAAA') $$,
  '42501', null, 'cannot raise an alert as someone else');
select throws_ok(
  $$ select acknowledge_alert('a1e70000-0000-4000-8000-000000000001', true) $$,
  '42501', 'not_a_recipient', 'the sender cannot acknowledge their own alert');
select throws_ok(
  $$ insert into alerts (id, incident_id, circle_id, sender_id, sender_device_id, kind, key_version,
       ciphertext, dispatched_at)
     values ('a1e70000-0000-4000-8000-000000000003', 'a1e70000-0000-4000-8000-0000000000fd',
       (select val::uuid from t_ids where name = 'family'), auth.uid(),
       'bbbbbbbb-0000-4000-8000-0000000000d2', 'panic', 1, 'AAAA', now()) $$,
  '42501', null, 'clients cannot set dispatched_at (only the push function does)');
select throws_ok(
  $$ update alerts set dispatched_at = null $$,
  '42501', null, 'alerts cannot be edited directly');

set local request.jwt.claims = '{"sub":"aaaaaaaa-0000-4000-8000-000000000001","role":"authenticated"}';
select is((select count(*)::int from alerts), 1, 'members receive the alert');
select lives_ok($$ select acknowledge_alert('a1e70000-0000-4000-8000-000000000001', false) $$,
  'Alice''s app records delivery');
select lives_ok($$ select acknowledge_alert('a1e70000-0000-4000-8000-000000000001', true) $$,
  'Alice opens the alert');
select lives_ok($$ select resolve_incident('a1e70000-0000-4000-8000-0000000000ff') $$,
  'resolve_incident is harmless for non-senders');
select is((select resolved_at from alerts), null, 'only the sender can resolve their alert');

set local request.jwt.claims = '{"sub":"bbbbbbbb-0000-4000-8000-000000000002","role":"authenticated"}';
select ok((select seen_at is not null from alert_receipts
  where recipient_id = 'aaaaaaaa-0000-4000-8000-000000000001'), 'Bob sees that Alice opened it');

set local request.jwt.claims = '{"sub":"cccccccc-0000-4000-8000-000000000003","role":"authenticated"}';
select is((select count(*)::int from alert_receipts), 0, 'Carol cannot see other people''s receipts');

set local request.jwt.claims = '{"sub":"eeeeeeee-0000-4000-8000-000000000004","role":"authenticated"}';
select is((select count(*)::int from alerts), 0, 'outsider: no alerts');
select throws_ok(
  $$ select acknowledge_alert('a1e70000-0000-4000-8000-000000000001', true) $$,
  '42501', 'not_a_recipient', 'outsider cannot acknowledge');

set local request.jwt.claims = '{"sub":"bbbbbbbb-0000-4000-8000-000000000002","role":"authenticated"}';
select lives_ok($$ select resolve_incident('a1e70000-0000-4000-8000-0000000000ff') $$, 'Bob marks himself safe');
select ok((select resolved_at is not null from alerts), 'the alert is resolved');

-- ===========================================================================
-- Leaving: always allowed, takes your data with you
-- ===========================================================================

select lives_ok($$ select leave_circle((select val::uuid from t_ids where name = 'family')) $$,
  'Bob leaves without anyone''s approval');
select is((select count(*)::int from circles), 0, 'Bob no longer sees Family');
select is((select count(*)::int from sender_key_envelopes), 0,
  'envelopes sealed to Bob are no longer readable by him');

set local request.jwt.claims = '{"sub":"aaaaaaaa-0000-4000-8000-000000000001","role":"authenticated"}';
select is((select count(*)::int from location_latest), 0, 'Bob''s location left with him');
select is((select count(*)::int from alerts), 0, 'Bob''s alerts left with him');
select is((select count(*)::int from sender_key_envelopes), 1,
  'Alice still sees her old envelope to Bob, so her app knows to rotate');
select is((select count(*)::int from security_events where kind = 'member_left'), 1,
  'Alice is told Bob left');

select lives_ok($$ select leave_circle((select val::uuid from t_ids where name = 'family')) $$,
  'the owner can leave too');

set local request.jwt.claims = '{"sub":"cccccccc-0000-4000-8000-000000000003","role":"authenticated"}';
select is((select role from circle_members where user_id = auth.uid()), 'owner',
  'ownership passes to the longest-standing member');
select is((select owner_id from circles), 'cccccccc-0000-4000-8000-000000000003'::uuid,
  'circles.owner_id follows');
select is((select count(*)::int from share_levels), 0, 'share levels involving a leaver are removed');

select lives_ok($$ select leave_circle((select val::uuid from t_ids where name = 'family')) $$,
  'the last member leaves');
reset role;
select is((select count(*)::int from circles where id = (select val::uuid from t_ids where name = 'family')),
  0, 'an empty Circle is deleted');

-- ===========================================================================
-- Rate limiting: invite codes can't be brute-forced
-- ===========================================================================

set local role authenticated;
set local request.jwt.claims = '{"sub":"eeeeeeee-0000-4000-8000-000000000004","role":"authenticated"}';
-- Eve used 1 redeem attempt above. Wrong guesses still count (they don't
-- raise, so the counter isn't rolled back): 9 more are allowed...
select is((select count(*)::int from preview_invite('11111-1111' || n)), 0, 'wrong guess ' || (n + 1))
from generate_series(1, 9) as n;
-- ...and the 11th attempt within the hour is refused outright, even with
-- the right code.
select throws_ok($$ select preview_invite('11111-1111A') $$, 'P0001', 'rate_limited',
  'the 11th attempt in an hour is rate limited');

reset role;
select * from finish();
rollback;
