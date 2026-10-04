-- Identity: profiles, consents, devices, push tokens, the user-visible
-- security log, and rate limiting.
--
-- Conventions used in every Phase 1 migration:
-- * RLS is enabled on every table and each table's grants are set
--   explicitly, so what a signed-in user can do is readable right here.
-- * Writes that need cross-table checks go through RPCs. The logic lives in
--   `private.*` SECURITY DEFINER functions with a pinned search_path; thin
--   SECURITY INVOKER wrappers in `public` are what the app calls.
-- * Public keys and ciphertext are stored as base64 text, which round-trips
--   through PostgREST JSON without bytea escaping.

-- ---------------------------------------------------------------------------
-- Rate limiting (private: never exposed through the API)
-- ---------------------------------------------------------------------------

create table private.rate_limits (
  bucket text not null,
  subject uuid not null,
  window_start timestamptz not null,
  hits integer not null default 0,
  primary key (bucket, subject, window_start)
);

-- Counts one hit for the current user in a fixed time window and raises
-- `rate_limited` once `p_max` is exceeded. The failed statement rolls back,
-- so a blocked caller can't push the counter further.
create function private.hit_rate_limit(p_bucket text, p_max integer, p_window interval)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_seconds double precision := extract(epoch from p_window);
  v_start timestamptz := to_timestamp(floor(extract(epoch from now()) / v_seconds) * v_seconds);
  v_hits integer;
begin
  if auth.uid() is null then
    raise exception using message = 'not_authenticated', errcode = '42501';
  end if;
  insert into private.rate_limits (bucket, subject, window_start, hits)
  values (p_bucket, auth.uid(), v_start, 1)
  on conflict (bucket, subject, window_start)
    do update set hits = private.rate_limits.hits + 1
  returning hits into v_hits;
  if v_hits > p_max then
    raise exception using message = 'rate_limited', errcode = 'P0001',
      detail = p_bucket;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Profiles: the only personal detail other members see is a display name.
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null check (char_length(btrim(display_name)) between 1 and 40),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
revoke all on table public.profiles from authenticated;
grant select, insert, update (display_name) on table public.profiles to authenticated;

create policy profiles_select_own on public.profiles
  for select to authenticated using (id = (select auth.uid()));
create policy profiles_insert_own on public.profiles
  for insert to authenticated with check (id = (select auth.uid()));
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

create trigger profiles_updated_at before update on public.profiles
  for each row execute function private.set_updated_at();

-- ---------------------------------------------------------------------------
-- Consents (POPIA s11): what was agreed, which policy version, and when.
-- Rows are never edited by clients; withdrawing consent stamps revoked_at.
-- ---------------------------------------------------------------------------

create table public.consents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  consent_type text not null
    check (consent_type in ('terms_privacy', 'location_sharing', 'age_18_plus')),
  policy_version text not null check (char_length(policy_version) between 1 and 20),
  granted_at timestamptz not null default now(),
  revoked_at timestamptz
);

create index consents_user_type on public.consents (user_id, consent_type);

alter table public.consents enable row level security;
revoke all on table public.consents from authenticated;
grant select, insert on table public.consents to authenticated;

create policy consents_select_own on public.consents
  for select to authenticated using (user_id = (select auth.uid()));
create policy consents_insert_own on public.consents
  for insert to authenticated
  with check (user_id = (select auth.uid()) and revoked_at is null);

create function private.has_consent(p_type text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.consents c
    where c.user_id = auth.uid() and c.consent_type = p_type and c.revoked_at is null
  );
$$;

create function private.revoke_consent(p_type text)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.consents set revoked_at = now()
  where user_id = auth.uid() and consent_type = p_type and revoked_at is null;
$$;

create function public.revoke_consent(p_type text)
returns void
language sql
security invoker
set search_path = ''
as $$ select private.revoke_consent(p_type); $$;

-- ---------------------------------------------------------------------------
-- Devices: one row per installed app, holding only PUBLIC keys.
-- Co-members can read these (they need them to seal keys to you). Push
-- tokens live in a separate owner-only table so they never leak.
-- ---------------------------------------------------------------------------

create table public.devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  box_public_key text not null unique
    check (length(decode(box_public_key, 'base64')) = 32),
  sign_public_key text not null unique
    check (length(decode(sign_public_key, 'base64')) = 32),
  platform text not null check (platform in ('android', 'ios')),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz
);

create index devices_user on public.devices (user_id);

alter table public.devices enable row level security;
revoke all on table public.devices from authenticated;
-- Public keys can't be edited after registration: a new key means a new
-- device row, which members' apps notice and treat as a key change.
grant select, insert, update (last_seen_at, revoked_at) on table public.devices to authenticated;

create policy devices_select_own on public.devices
  for select to authenticated using (user_id = (select auth.uid()));
create policy devices_insert_own on public.devices
  for insert to authenticated
  with check (user_id = (select auth.uid()) and revoked_at is null);
create policy devices_update_own on public.devices
  for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create function private.device_owner(p_device uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$ select d.user_id from public.devices d where d.id = p_device; $$;

-- True if the device belongs to the caller and hasn't been revoked.
create function private.is_my_active_device(p_device uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.devices d
    where d.id = p_device and d.user_id = auth.uid() and d.revoked_at is null
  );
$$;

create table public.device_push_tokens (
  device_id uuid primary key references public.devices (id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  token text not null check (char_length(token) between 10 and 4096),
  updated_at timestamptz not null default now()
);

alter table public.device_push_tokens enable row level security;
revoke all on table public.device_push_tokens from authenticated;
grant select, insert, update, delete on table public.device_push_tokens to authenticated;

create policy push_tokens_own on public.device_push_tokens
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()) and private.is_my_active_device(device_id));

create trigger device_push_tokens_updated_at before update on public.device_push_tokens
  for each row execute function private.set_updated_at();

-- ---------------------------------------------------------------------------
-- Security log: things a user should know happened to their account or
-- Circles. Written only by database code; users can read their own.
-- ---------------------------------------------------------------------------

create table public.security_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in (
    'new_device', 'device_revoked', 'member_joined', 'member_left',
    'joined_circle', 'left_circle'
  )),
  circle_id uuid,
  actor_id uuid,
  created_at timestamptz not null default now()
);

create index security_events_user on public.security_events (user_id, created_at desc);

alter table public.security_events enable row level security;
revoke all on table public.security_events from authenticated;
grant select on table public.security_events to authenticated;

create policy security_events_select_own on public.security_events
  for select to authenticated using (user_id = (select auth.uid()));

create function private.log_new_device()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.security_events (user_id, kind, actor_id)
  values (new.user_id, 'new_device', new.user_id);
  return new;
end;
$$;

create trigger devices_log_new after insert on public.devices
  for each row execute function private.log_new_device();

create function private.log_device_revoked()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.revoked_at is null and new.revoked_at is not null then
    insert into public.security_events (user_id, kind, actor_id)
    values (new.user_id, 'device_revoked', new.user_id);
  end if;
  return new;
end;
$$;

create trigger devices_log_revoked after update of revoked_at on public.devices
  for each row execute function private.log_device_revoked();

-- Helpers used by RLS policies and wrappers must be callable by signed-in
-- users. (Default privileges revoke EXECUTE, so grants are explicit.)
grant execute on function
  private.hit_rate_limit(text, integer, interval),
  private.has_consent(text),
  private.revoke_consent(text),
  private.device_owner(uuid),
  private.is_my_active_device(uuid)
to authenticated;
grant execute on function public.revoke_consent(text) to authenticated;
