-- Explicit grants for the API roles, so AfriSafety works with Supabase's
-- "Automatically expose new tables" setting switched OFF (recommended).
--
-- * authenticated: each table already grants exactly what the app may do
--   (see the earlier migrations); RLS narrows it further. Only schema
--   usage is made explicit here.
-- * service_role: used only by Edge Functions (dispatch-alert). It bypasses
--   RLS by design and never reaches the app.
-- * anon: deliberately gets nothing.

grant usage on schema public to authenticated, service_role;

grant select, insert, update, delete on all tables in schema public to service_role;
alter default privileges for role postgres in schema public
  grant select, insert, update, delete on tables to service_role;
