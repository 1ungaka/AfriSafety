-- Community incident reports (Phase 4).
--
-- This is the one deliberate plaintext-location feature (architecture
-- §4.5), so it's built to reveal as little as possible:
-- * Category only: no free text, photos or names, so nothing to dox
--   anyone with and nothing to moderate word by word.
-- * The phone snaps the place to a 0.01° grid square (~1 km) before
--   sending. The server never receives a precise location.
-- * Time is a date plus a 4-hour block, not a timestamp.
-- * Nobody can read the raw rows (no grant). The map comes from
--   community_cells(), which only returns a square/category once at least
--   3 different people have reported it in the last 30 days
--   (k-anonymity), and never says who or exactly when.
-- * The reporter id is stored only for rate limits, duplicate control,
--   bans and account deletion (cascade).

alter table public.consents drop constraint consents_consent_type_check;
alter table public.consents add constraint consents_consent_type_check
  check (consent_type in ('terms_privacy', 'location_sharing', 'age_18_plus', 'community'));

create table public.incident_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users (id) on delete cascade,
  category text not null check (category in (
    'suspicious', 'theft', 'robbery', 'assault', 'harassment', 'vandalism'
  )),
  cell_lat integer not null check (cell_lat between -9000 and 8999),
  cell_lon integer not null check (cell_lon between -18000 and 17999),
  occurred_on date not null,
  period smallint not null check (period between 0 and 5),
  created_at timestamptz not null default now(),
  -- Recent things only: a week back at most, and not in the future.
  check (occurred_on between (created_at at time zone 'UTC')::date - 7
                         and (created_at at time zone 'UTC')::date + 1)
);

-- One report per person, square, category and day.
create unique index incident_reports_once
  on public.incident_reports (reporter_id, cell_lat, cell_lon, category, occurred_on);
create index incident_reports_cell
  on public.incident_reports (cell_lat, cell_lon, created_at desc);

alter table public.incident_reports enable row level security;
revoke all on table public.incident_reports from authenticated;
-- Deliberately no policies or grants: only the functions below touch it.

-- Flags on a square/category ("this looks wrong"). Five different people
-- flagging hides it until a moderator decides.
create table public.community_flags (
  flagger_id uuid not null references auth.users (id) on delete cascade,
  cell_lat integer not null,
  cell_lon integer not null,
  category text not null,
  created_at timestamptz not null default now(),
  primary key (flagger_id, cell_lat, cell_lon, category)
);

alter table public.community_flags enable row level security;
revoke all on table public.community_flags from authenticated;

-- Moderator decisions per square/category.
create table public.community_decisions (
  cell_lat integer not null,
  cell_lon integer not null,
  category text not null,
  status text not null check (status in ('kept', 'hidden')),
  decided_by uuid references auth.users (id) on delete set null,
  decided_at timestamptz not null default now(),
  primary key (cell_lat, cell_lon, category)
);

alter table public.community_decisions enable row level security;
revoke all on table public.community_decisions from authenticated;

-- Moderators and bans live in the private schema (not exposed by the
-- API). The project owner manages them in the SQL Editor:
--   insert into private.moderators (user_id) values ('<user uuid>');
--   insert into private.community_bans (user_id, reason) values ('<uuid>', '...');
create table private.moderators (
  user_id uuid primary key references auth.users (id) on delete cascade,
  added_at timestamptz not null default now()
);

create table private.community_bans (
  user_id uuid primary key references auth.users (id) on delete cascade,
  reason text,
  banned_at timestamptz not null default now()
);

create function private.is_moderator()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$ select exists (select 1 from private.moderators m where m.user_id = auth.uid()); $$;

create function private.is_community_banned(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$ select exists (select 1 from private.community_bans b where b.user_id = p_user); $$;

-- ---------------------------------------------------------------------------
-- Submitting
-- ---------------------------------------------------------------------------

create function private.submit_report(
  p_category text, p_cell_lat integer, p_cell_lon integer,
  p_occurred_on date, p_period smallint
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception using message = 'not_authenticated', errcode = '42501';
  end if;
  if not private.has_consent('community') then
    raise exception using message = 'consent_required', errcode = 'P0001';
  end if;
  if private.is_community_banned(auth.uid()) then
    raise exception using message = 'banned', errcode = '42501';
  end if;
  perform private.hit_rate_limit('community_report', 10, interval '1 day');
  insert into public.incident_reports
    (reporter_id, category, cell_lat, cell_lon, occurred_on, period)
  values (auth.uid(), p_category, p_cell_lat, p_cell_lon, p_occurred_on, p_period)
  on conflict (reporter_id, cell_lat, cell_lon, category, occurred_on) do nothing;
end;
$$;

-- ---------------------------------------------------------------------------
-- Reading: k-anonymous aggregates only
-- ---------------------------------------------------------------------------

-- Squares in a bounding box (at most 120 × 120 squares, ~130 km) with at
-- least 3 different reporters per category in the last 30 days. Hidden by
-- a moderator, auto-hidden by 5+ flags since the last "keep", or from
-- banned reporters: left out.
create function private.community_cells(
  p_min_lat integer, p_max_lat integer, p_min_lon integer, p_max_lon integer
)
returns table (cell_lat integer, cell_lon integer, category text, reporters integer)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception using message = 'not_authenticated', errcode = '42501';
  end if;
  if p_max_lat < p_min_lat or p_max_lon < p_min_lon
     or p_max_lat - p_min_lat > 120 or p_max_lon - p_min_lon > 120 then
    raise exception using message = 'area_too_large', errcode = '22023';
  end if;
  return query
    with agg as (
      select r.cell_lat, r.cell_lon, r.category,
             count(distinct r.reporter_id)::integer as reporters
        from public.incident_reports r
       where r.cell_lat between p_min_lat and p_max_lat
         and r.cell_lon between p_min_lon and p_max_lon
         and r.created_at > now() - interval '30 days'
         and not private.is_community_banned(r.reporter_id)
       group by r.cell_lat, r.cell_lon, r.category
      having count(distinct r.reporter_id) >= 3
    )
    select a.cell_lat, a.cell_lon, a.category, a.reporters
      from agg a
      left join public.community_decisions d
        on d.cell_lat = a.cell_lat and d.cell_lon = a.cell_lon and d.category = a.category
     where coalesce(d.status, '') <> 'hidden'
       and (
         select count(*) from public.community_flags f
          where f.cell_lat = a.cell_lat and f.cell_lon = a.cell_lon
            and f.category = a.category
            and f.created_at > coalesce(
              case when d.status = 'kept' then d.decided_at end, '-infinity'::timestamptz)
       ) < 5;
end;
$$;

create function private.flag_cell(p_cell_lat integer, p_cell_lon integer, p_category text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception using message = 'not_authenticated', errcode = '42501';
  end if;
  perform private.hit_rate_limit('community_flag', 20, interval '1 day');
  insert into public.community_flags (flagger_id, cell_lat, cell_lon, category)
  values (auth.uid(), p_cell_lat, p_cell_lon, p_category)
  on conflict do nothing;
end;
$$;

-- ---------------------------------------------------------------------------
-- Moderation
-- ---------------------------------------------------------------------------

create function private.is_moderator_rpc()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$ select private.is_moderator(); $$;

-- Flagged squares, for moderators only. Still aggregates: moderators see
-- how many people reported and flagged, never who.
create function private.moderation_queue()
returns table (
  cell_lat integer, cell_lon integer, category text,
  reporters integer, flags integer, status text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.is_moderator() then
    raise exception using message = 'not_a_moderator', errcode = '42501';
  end if;
  return query
    select f.cell_lat, f.cell_lon, f.category,
           (select count(distinct r.reporter_id)::integer from public.incident_reports r
             where r.cell_lat = f.cell_lat and r.cell_lon = f.cell_lon
               and r.category = f.category
               and r.created_at > now() - interval '30 days') as reporters,
           count(*)::integer as flags,
           (select d.status from public.community_decisions d
             where d.cell_lat = f.cell_lat and d.cell_lon = f.cell_lon
               and d.category = f.category) as status
      from public.community_flags f
     where f.created_at > now() - interval '30 days'
     group by f.cell_lat, f.cell_lon, f.category
     order by count(*) desc
     limit 100;
end;
$$;

create function private.moderate_cell(
  p_cell_lat integer, p_cell_lon integer, p_category text, p_keep boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_moderator() then
    raise exception using message = 'not_a_moderator', errcode = '42501';
  end if;
  insert into public.community_decisions
    (cell_lat, cell_lon, category, status, decided_by, decided_at)
  values (p_cell_lat, p_cell_lon, p_category,
          case when p_keep then 'kept' else 'hidden' end, auth.uid(), now())
  on conflict (cell_lat, cell_lon, category) do update
    set status = excluded.status, decided_by = excluded.decided_by,
        decided_at = excluded.decided_at;
end;
$$;

-- Wrappers callable through the API (SECURITY INVOKER; the work and the
-- checks happen in the private functions above).
create function public.submit_report(
  p_category text, p_cell_lat integer, p_cell_lon integer,
  p_occurred_on date, p_period smallint
) returns void
language sql security invoker set search_path = ''
as $$ select private.submit_report(p_category, p_cell_lat, p_cell_lon, p_occurred_on, p_period); $$;

create function public.community_cells(
  p_min_lat integer, p_max_lat integer, p_min_lon integer, p_max_lon integer
) returns table (cell_lat integer, cell_lon integer, category text, reporters integer)
language sql stable security invoker set search_path = ''
as $$ select * from private.community_cells(p_min_lat, p_max_lat, p_min_lon, p_max_lon); $$;

create function public.flag_cell(p_cell_lat integer, p_cell_lon integer, p_category text)
returns void
language sql security invoker set search_path = ''
as $$ select private.flag_cell(p_cell_lat, p_cell_lon, p_category); $$;

create function public.is_moderator() returns boolean
language sql stable security invoker set search_path = ''
as $$ select private.is_moderator_rpc(); $$;

create function public.moderation_queue()
returns table (
  cell_lat integer, cell_lon integer, category text,
  reporters integer, flags integer, status text
)
language sql stable security invoker set search_path = ''
as $$ select * from private.moderation_queue(); $$;

create function public.moderate_cell(
  p_cell_lat integer, p_cell_lon integer, p_category text, p_keep boolean
) returns void
language sql security invoker set search_path = ''
as $$ select private.moderate_cell(p_cell_lat, p_cell_lon, p_category, p_keep); $$;

grant execute on function
  private.is_moderator(),
  private.is_moderator_rpc(),
  private.is_community_banned(uuid),
  private.submit_report(text, integer, integer, date, smallint),
  private.community_cells(integer, integer, integer, integer),
  private.flag_cell(integer, integer, text),
  private.moderation_queue(),
  private.moderate_cell(integer, integer, text, boolean),
  public.submit_report(text, integer, integer, date, smallint),
  public.community_cells(integer, integer, integer, integer),
  public.flag_cell(integer, integer, text),
  public.is_moderator(),
  public.moderation_queue(),
  public.moderate_cell(integer, integer, text, boolean)
to authenticated;

-- Retention: reports and flags go after 90 days (the map only uses 30).
create or replace function private.purge_expired()
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.alerts where created_at < now() - interval '30 days';
  delete from public.circle_events where created_at < now() - interval '7 days';
  delete from public.checkins
   where status <> 'active' and updated_at < now() - interval '7 days';
  delete from private.rate_limits where window_start < now() - interval '2 days';
  delete from public.incident_reports where created_at < now() - interval '90 days';
  delete from public.community_flags where created_at < now() - interval '90 days';
$$;
