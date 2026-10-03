-- AfriSafety foundations: secure defaults every later migration relies on.
--
-- 1. A `private` schema for SECURITY DEFINER helpers (e.g. the
--    is_circle_member() check used by RLS policies in Phase 1). It is NOT
--    listed in config.toml `[api] schemas`, so PostgREST never exposes it as
--    an RPC endpoint. RLS policies still need to call its functions, so
--    `authenticated` gets USAGE but nothing else by default.
-- 2. Deny-by-default privileges. Out of the box, Supabase grants anon and
--    authenticated access to every new table and function in `public`, and
--    Postgres lets PUBLIC execute every new function. We revoke those
--    defaults so each migration has to grant exactly what it needs.
--    RLS is still mandatory on every table (enforced by
--    tests/database/000_foundations.test.sql). These revocations are a
--    second layer.

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated, service_role;

-- New functions are not executable by everyone (Postgres's global default).
alter default privileges for role postgres revoke execute on functions from public;

-- Nothing new in `public` is reachable by signed-out (anon) clients. Every
-- AfriSafety feature requires sign-in.
alter default privileges for role postgres in schema public
  revoke all on tables from anon;
alter default privileges for role postgres in schema public
  revoke all on sequences from anon;
alter default privileges for role postgres in schema public
  revoke execute on functions from anon, authenticated;

-- Same for the private schema: helpers are granted explicitly, one by one.
alter default privileges for role postgres in schema private
  revoke execute on functions from anon, authenticated;

-- Keeps `updated_at` honest without trusting the client's clock.
create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
