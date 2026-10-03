#!/usr/bin/env bash
# Runs the pgTAP database tests against a throwaway local Postgres cluster,
# for machines where Docker (and therefore `supabase start`) isn't available.
#
# The normal path is:   supabase start && supabase test db
#
# This script recreates just enough of Supabase (roles, `extensions` and
# `auth` schemas, auth.uid()) to apply our migrations and run the tests.
# It is a fallback, not a replacement: CI runs the real Supabase stack.
#
# Requirements: Postgres 15+ server binaries, pgTAP and pg_prove
#   Ubuntu/Debian: sudo apt install postgresql postgresql-16-pgtap libtap-parser-sourcehandler-pgtap-perl
#   macOS:         brew install postgresql@16 pgtap
set -euo pipefail

if [[ $(id -u) -eq 0 ]]; then
  echo "Postgres refuses to run as root. Run as a normal user, e.g.:" >&2
  echo "  sudo -u postgres $0" >&2
  exit 1
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUPABASE_DIR="$(dirname "$HERE")"
PG_BIN="${PG_BIN:-$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1)}"
PG_BIN="${PG_BIN:-$(dirname "$(command -v initdb)")}"
PORT="${PORT:-54329}"
WORK="$(mktemp -d)"
trap '"$PG_BIN/pg_ctl" -D "$WORK/data" -m immediate stop >/dev/null 2>&1 || true; rm -rf "$WORK"' EXIT

"$PG_BIN/initdb" -D "$WORK/data" -U postgres --auth=trust >/dev/null
"$PG_BIN/pg_ctl" -D "$WORK/data" -o "-p $PORT -k $WORK -c listen_addresses=''" -l "$WORK/log" start >/dev/null

PSQL=(psql -h "$WORK" -p "$PORT" -U postgres -v ON_ERROR_STOP=1 -q)

"${PSQL[@]}" -d postgres <<'SQL'
-- Minimal Supabase shim (see supabase/postgres for the real definitions).
create role anon nologin noinherit;
create role authenticated nologin noinherit;
create role service_role nologin noinherit bypassrls;
create schema extensions;
grant usage on schema extensions to anon, authenticated, service_role;
create extension pgtap with schema extensions;

create schema auth;
grant usage on schema auth to anon, authenticated, service_role;
create table auth.users (
  id uuid primary key,
  email text,
  phone text,
  created_at timestamptz not null default now()
);
create function auth.uid() returns uuid language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;
create function auth.role() returns text language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
  )::text
$$;
grant execute on function auth.uid(), auth.role() to anon, authenticated, service_role;

-- Supabase's default grants on public, which our migrations then tighten.
grant usage on schema public to anon, authenticated, service_role;
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
SQL

for migration in "$SUPABASE_DIR"/migrations/*.sql; do
  echo "applying $(basename "$migration")"
  "${PSQL[@]}" -d postgres -f "$migration"
done

pg_prove -h "$WORK" -p "$PORT" -U postgres -d postgres --ext .sql -r "$SUPABASE_DIR/tests"
