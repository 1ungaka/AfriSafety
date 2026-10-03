-- Guards for the security defaults in 20261003000000_foundations.sql.
-- These are written so they keep protecting us as tables are added: they
-- inspect the catalog rather than naming specific tables.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(6);

select has_schema('private', 'private schema exists');

select is(
  (select coalesce(array_agg(c.relname::text order by c.relname), '{}')
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind in ('r', 'p')
      and not c.relrowsecurity),
  '{}'::text[],
  'every table in public has row level security enabled'
);

select is(
  (select coalesce(array_agg(table_name::text order by table_name), '{}')
     from information_schema.role_table_grants
    where table_schema = 'public' and grantee = 'anon'),
  '{}'::text[],
  'anon (signed-out) has no privileges on any public table'
);

select is(
  (select coalesce(array_agg(p.proname::text order by p.proname), '{}')
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'private')
      and has_function_privilege('anon', p.oid, 'execute')),
  '{}'::text[],
  'anon cannot execute any function in public or private'
);

select is(
  (select coalesce(array_agg(p.proname::text order by p.proname), '{}')
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'private')
      and p.prosecdef
      and not exists (
        select 1 from unnest(coalesce(p.proconfig, '{}')) cfg
         where cfg like 'search_path=%'
      )),
  '{}'::text[],
  'every SECURITY DEFINER function pins its search_path'
);

select ok(
  not has_schema_privilege('anon', 'private', 'usage'),
  'anon cannot use the private schema'
);

select * from finish();
rollback;
