-- Phase 3: device revocation is final.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;

select no_plan();

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-4000-8000-000000000001', 'alice@example.com'),
  ('eeeeeeee-0000-4000-8000-000000000004', 'eve@example.com');

set local role authenticated;
set local request.jwt.claims = '{"sub":"aaaaaaaa-0000-4000-8000-000000000001","role":"authenticated"}';
insert into devices (id, box_public_key, sign_public_key, platform) values
  ('aaaaaaaa-0000-4000-8000-0000000000d1',
   encode(sha256('alice-phone'), 'base64'), encode(sha256('alice-phone-s'), 'base64'), 'android'),
  ('aaaaaaaa-0000-4000-8000-0000000000d2',
   encode(sha256('alice-old'), 'base64'), encode(sha256('alice-old-s'), 'base64'), 'android');

select lives_ok(
  $$ update devices set revoked_at = now() where id = 'aaaaaaaa-0000-4000-8000-0000000000d2' $$,
  'Alice signs out her old phone from her new one');
select throws_ok(
  $$ update devices set revoked_at = null where id = 'aaaaaaaa-0000-4000-8000-0000000000d2' $$,
  '42501', 'device_revoked', 'a revoked device can never be un-revoked');
select lives_ok(
  $$ update devices set last_seen_at = now() where id = 'aaaaaaaa-0000-4000-8000-0000000000d1' $$,
  'active devices can still update last_seen_at');
select is(
  (select count(*)::int from security_events where kind = 'device_revoked'), 1,
  'the revocation is in Alice''s security log');
select throws_ok(
  $$ update devices set box_public_key = 'eA==' where id = 'aaaaaaaa-0000-4000-8000-0000000000d1' $$,
  '42501', null, 'public keys cannot be edited after registration');

set local request.jwt.claims = '{"sub":"eeeeeeee-0000-4000-8000-000000000004","role":"authenticated"}';
update devices set revoked_at = now() where id = 'aaaaaaaa-0000-4000-8000-0000000000d1';
select is((select count(*)::int from devices), 0, 'outsiders see no devices');
set local request.jwt.claims = '{"sub":"aaaaaaaa-0000-4000-8000-000000000001","role":"authenticated"}';
select is(
  (select revoked_at from devices where id = 'aaaaaaaa-0000-4000-8000-0000000000d1'), null,
  'nobody else can revoke your devices');

select * from finish();
rollback;
