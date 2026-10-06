-- Deleting an account erases the user without taking their Circles away
-- from everyone else.
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
  ('bbbbbbbb-0000-4000-8000-000000000002', 'bob@example.com');

set local role authenticated;

set local request.jwt.claims = '{"sub":"aaaaaaaa-0000-4000-8000-000000000001","role":"authenticated"}';
insert into profiles (id, display_name) values (auth.uid(), 'Alice');
insert into consents (consent_type, policy_version) values
  ('location_sharing', '1'), ('age_18_plus', '1'), ('terms_privacy', '1');
insert into devices (id, box_public_key, sign_public_key, platform) values
  ('aaaaaaaa-0000-4000-8000-0000000000d1',
   encode(sha256('a-box'), 'base64'), encode(sha256('a-sign'), 'base64'), 'android');
insert into t_ids values ('family', (select create_circle('Family')::text));
insert into t_ids values ('solo', (select create_circle('Just me')::text));
insert into t_ids values ('code', (select create_invite((select val::uuid from t_ids where name = 'family'))));

set local request.jwt.claims = '{"sub":"bbbbbbbb-0000-4000-8000-000000000002","role":"authenticated"}';
insert into profiles (id, display_name) values (auth.uid(), 'Bob');
insert into consents (consent_type, policy_version) values
  ('location_sharing', '1'), ('age_18_plus', '1'), ('terms_privacy', '1');
select accept_invite((select val from t_ids where name = 'code'));

-- Alice, the owner of both Circles, deletes her account.
set local request.jwt.claims = '{"sub":"aaaaaaaa-0000-4000-8000-000000000001","role":"authenticated"}';
select lives_ok($$ select delete_account() $$, 'Alice deletes her account');

set local role postgres;
select is((select count(*)::int from auth.users where email = 'alice@example.com'), 0,
  'her account is gone');
select is((select count(*)::int from profiles where id = 'aaaaaaaa-0000-4000-8000-000000000001'), 0,
  'her profile is gone');
select is((select count(*)::int from devices where user_id = 'aaaaaaaa-0000-4000-8000-000000000001'), 0,
  'her devices are gone');
select is((select count(*)::int from consents where user_id = 'aaaaaaaa-0000-4000-8000-000000000001'), 0,
  'her consents are gone');
select is(
  (select owner_id from circles where id = (select val::uuid from t_ids where name = 'family')),
  'bbbbbbbb-0000-4000-8000-000000000002'::uuid,
  'the shared Circle survives, with Bob as the new owner');
select is((select count(*)::int from circles where id = (select val::uuid from t_ids where name = 'solo')), 0,
  'a Circle with nobody left in it is removed');
select is(
  (select count(*)::int from security_events
    where user_id = 'bbbbbbbb-0000-4000-8000-000000000002' and kind = 'member_left'), 1,
  'Bob is told that Alice left');

set local role authenticated;
set local request.jwt.claims = '{"sub":"bbbbbbbb-0000-4000-8000-000000000002","role":"authenticated"}';
select is((select count(*)::int from profiles), 1, 'Bob still has his own account');

set local role anon;
select throws_ok($$ select delete_account() $$, '42501', null,
  'signed-out callers cannot delete anything');

select * from finish();
rollback;
