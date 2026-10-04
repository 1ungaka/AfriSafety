-- Circles: groups of people who share with each other.
--
-- Anti-stalkerware rules enforced here, not just in the app:
-- * Nobody can add you to a Circle. You join only by redeeming an invite
--   yourself, after recording consent.
-- * Leaving always succeeds, needs no approval, and removes your data.
-- * Only you can pause your sharing or choose who sees your live location.
--   The owner role grants no control over other members.

create table public.circles (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 1 and 40),
  owner_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.circle_members (
  circle_id uuid not null references public.circles (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member')),
  sharing_paused boolean not null default false,
  joined_at timestamptz not null default now(),
  primary key (circle_id, user_id)
);

create index circle_members_user on public.circle_members (user_id);

-- Per-member sharing level, chosen by the person sharing (D7). No row
-- means 'live'. 'sos_only' viewers never receive the sharer's location
-- key, so the server couldn't show them the location even if it wanted to.
create table public.share_levels (
  circle_id uuid not null,
  sharer_id uuid not null,
  viewer_id uuid not null,
  level text not null check (level in ('live', 'sos_only')),
  updated_at timestamptz not null default now(),
  primary key (circle_id, sharer_id, viewer_id),
  foreign key (circle_id, sharer_id)
    references public.circle_members (circle_id, user_id) on delete cascade,
  foreign key (circle_id, viewer_id)
    references public.circle_members (circle_id, user_id) on delete cascade,
  check (sharer_id <> viewer_id)
);

-- Invite codes are stored only as SHA-256 hashes, so a database leak
-- doesn't hand out working invites.
create table public.circle_invites (
  id uuid primary key default gen_random_uuid(),
  circle_id uuid not null references public.circles (id) on delete cascade,
  created_by uuid not null references auth.users (id) on delete cascade,
  code_hash text not null unique,
  expires_at timestamptz not null,
  max_uses integer not null default 5 check (max_uses between 1 and 20),
  uses integer not null default 0,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Membership helpers. SECURITY DEFINER so policies on circle_members can
-- use them without recursing into their own RLS.
-- ---------------------------------------------------------------------------

create function private.is_circle_member(p_circle uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.circle_members m
    where m.circle_id = p_circle and m.user_id = auth.uid()
  );
$$;

create function private.is_member_of(p_circle uuid, p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.circle_members m
    where m.circle_id = p_circle and m.user_id = p_user
  );
$$;

create function private.shares_circle_with(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.circle_members mine
    join public.circle_members theirs on theirs.circle_id = mine.circle_id
    where mine.user_id = auth.uid() and theirs.user_id = p_user
  );
$$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.circles enable row level security;
alter table public.circle_members enable row level security;
alter table public.share_levels enable row level security;
alter table public.circle_invites enable row level security;

revoke all on table public.circles, public.circle_members, public.share_levels,
  public.circle_invites from authenticated;
-- Reads only. Every change goes through the RPCs below.
grant select on table public.circles, public.circle_members, public.share_levels
  to authenticated;
-- circle_invites: no access at all. Codes are checked by RPCs only.

create policy circles_select_member on public.circles
  for select to authenticated using (private.is_circle_member(id));

create policy circle_members_select_member on public.circle_members
  for select to authenticated using (private.is_circle_member(circle_id));

create policy share_levels_select_involved on public.share_levels
  for select to authenticated
  using (
    private.is_circle_member(circle_id)
    and (sharer_id = (select auth.uid()) or viewer_id = (select auth.uid()))
  );

-- Co-members can see each other's display name and device public keys.
create policy profiles_select_comember on public.profiles
  for select to authenticated using (private.shares_circle_with(id));
create policy devices_select_comember on public.devices
  for select to authenticated using (private.shares_circle_with(user_id));

-- ---------------------------------------------------------------------------
-- Invite codes: 10 Crockford base32 characters (50 random bits), shown as
-- XXXXX-XXXXX. Crockford avoids I, L, O and U so codes survive being read
-- out over the phone.
-- ---------------------------------------------------------------------------

create function private.normalise_invite_code(p_code text)
returns text
language sql
immutable
set search_path = ''
as $$
  select translate(upper(regexp_replace(coalesce(p_code, ''), '[^0-9A-Za-z]', '', 'g')), 'OIL', '011');
$$;

create function private.hash_invite_code(p_code text)
returns text
language sql
immutable
set search_path = ''
as $$
  select encode(sha256(convert_to(private.normalise_invite_code(p_code), 'UTF8')), 'hex');
$$;

create function private.new_invite_code()
returns text
language plpgsql
volatile
set search_path = ''
as $$
declare
  alphabet constant text := '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  -- A v4 UUID carries 122 random bits. Bytes 6 and 8 hold the version and
  -- variant, so only the other bytes are used; 256 is a multiple of 32, so
  -- taking the low 5 bits of each byte is unbiased.
  raw bytea := uuid_send(gen_random_uuid());
  positions constant integer[] := array[0, 1, 2, 3, 4, 5, 7, 9, 10, 11];
  code text := '';
  i integer;
begin
  foreach i in array positions loop
    code := code || substr(alphabet, (get_byte(raw, i) % 32) + 1, 1);
  end loop;
  return code;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC implementations
-- ---------------------------------------------------------------------------

create function private.require_member(p_circle uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.is_circle_member(p_circle) then
    raise exception using message = 'not_a_member', errcode = '42501';
  end if;
end;
$$;

create function private.require_sharing_consent()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not (private.has_consent('location_sharing') and private.has_consent('age_18_plus')) then
    raise exception using message = 'consent_required', errcode = 'P0001';
  end if;
end;
$$;

create function private.create_circle(p_name text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_circle uuid;
begin
  perform private.require_sharing_consent();
  perform private.hit_rate_limit('create_circle', 10, interval '1 day');
  insert into public.circles (name, owner_id)
  values (btrim(p_name), auth.uid())
  returning id into v_circle;
  insert into public.circle_members (circle_id, user_id, role)
  values (v_circle, auth.uid(), 'owner');
  return v_circle;
end;
$$;

create function private.create_invite(p_circle uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text;
begin
  perform private.require_member(p_circle);
  perform private.hit_rate_limit('create_invite', 20, interval '1 day');
  v_code := private.new_invite_code();
  insert into public.circle_invites (circle_id, created_by, code_hash, expires_at)
  values (p_circle, auth.uid(), private.hash_invite_code(v_code), now() + interval '48 hours');
  return substr(v_code, 1, 5) || '-' || substr(v_code, 6, 5);
end;
$$;

create function private.preview_invite(p_code text)
returns table (circle_name text, inviter_name text, member_count integer)
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Shared with accept_invite: 10 guesses an hour makes 50-bit codes
  -- impossible to brute-force.
  --
  -- A wrong code returns no rows instead of raising an error. An error would
  -- roll back the whole call, including the rate-limit hit above, and
  -- wrong guesses would never be counted.
  perform private.hit_rate_limit('redeem_invite', 10, interval '1 hour');
  return query
    select c.name,
           coalesce(p.display_name, ''),
           (select count(*)::integer from public.circle_members m where m.circle_id = c.id)
    from public.circle_invites i
    join public.circles c on c.id = i.circle_id
    left join public.profiles p on p.id = i.created_by
    where i.code_hash = private.hash_invite_code(p_code)
      and i.expires_at > now()
      and i.uses < i.max_uses;
end;
$$;

-- Returns the Circle id, or null for a wrong/expired code (see
-- preview_invite for why that isn't an error).
create function private.accept_invite(p_code text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invite public.circle_invites%rowtype;
begin
  perform private.require_sharing_consent();
  perform private.hit_rate_limit('redeem_invite', 10, interval '1 hour');

  select * into v_invite
  from public.circle_invites i
  where i.code_hash = private.hash_invite_code(p_code)
    and i.expires_at > now()
    and i.uses < i.max_uses
  for update;
  if not found then
    return null;
  end if;

  if private.is_circle_member(v_invite.circle_id) then
    return v_invite.circle_id;
  end if;

  insert into public.circle_members (circle_id, user_id) values (v_invite.circle_id, auth.uid());
  update public.circle_invites set uses = uses + 1 where id = v_invite.id;

  -- Everyone already in the Circle is told someone joined (anti-stalkerware).
  insert into public.security_events (user_id, kind, circle_id, actor_id)
  select m.user_id,
         case when m.user_id = auth.uid() then 'joined_circle' else 'member_joined' end,
         v_invite.circle_id, auth.uid()
  from public.circle_members m
  where m.circle_id = v_invite.circle_id;

  return v_invite.circle_id;
end;
$$;

-- Leaving can't be blocked: the only check is that you're a member.
create function private.leave_circle(p_circle uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_was_owner boolean;
  v_successor uuid;
begin
  perform private.require_member(p_circle);

  select role = 'owner' into v_was_owner
  from public.circle_members where circle_id = p_circle and user_id = auth.uid();

  -- Keys this user handed out are useless now; delete them. Keys sealed TO
  -- their devices are left in place but unreadable (RLS requires
  -- membership). Remaining members' apps see them and rotate.
  delete from public.sender_key_envelopes e
  where e.circle_id = p_circle and e.sender_id = auth.uid();

  -- Their location, alerts and share levels go with the membership row
  -- (ON DELETE CASCADE).
  delete from public.circle_members where circle_id = p_circle and user_id = auth.uid();

  insert into public.security_events (user_id, kind, circle_id, actor_id)
  values (auth.uid(), 'left_circle', p_circle, auth.uid());
  insert into public.security_events (user_id, kind, circle_id, actor_id)
  select m.user_id, 'member_left', p_circle, auth.uid()
  from public.circle_members m where m.circle_id = p_circle;

  if v_was_owner then
    select m.user_id into v_successor
    from public.circle_members m
    where m.circle_id = p_circle
    order by m.joined_at, m.user_id
    limit 1;
    if v_successor is null then
      delete from public.circles where id = p_circle;
    else
      update public.circle_members set role = 'owner'
      where circle_id = p_circle and user_id = v_successor;
      update public.circles set owner_id = v_successor where id = p_circle;
    end if;
  end if;
end;
$$;

-- p_circle null = every Circle ("Pause all sharing").
create function private.set_sharing_paused(p_circle uuid, p_paused boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_circle is not null then
    perform private.require_member(p_circle);
  end if;
  update public.circle_members
  set sharing_paused = p_paused
  where user_id = auth.uid() and (p_circle is null or circle_id = p_circle);
  if p_paused then
    -- Pausing hides you immediately rather than leaving a stale pin.
    delete from public.location_latest
    where user_id = auth.uid() and (p_circle is null or circle_id = p_circle);
  end if;
end;
$$;

create function private.set_share_level(p_circle uuid, p_viewer uuid, p_level text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_member(p_circle);
  if p_viewer = auth.uid() or not private.is_member_of(p_circle, p_viewer) then
    raise exception using message = 'invalid_viewer', errcode = 'P0001';
  end if;
  if p_level = 'live' then
    delete from public.share_levels
    where circle_id = p_circle and sharer_id = auth.uid() and viewer_id = p_viewer;
  elsif p_level = 'sos_only' then
    insert into public.share_levels (circle_id, sharer_id, viewer_id, level)
    values (p_circle, auth.uid(), p_viewer, 'sos_only')
    on conflict (circle_id, sharer_id, viewer_id)
      do update set level = excluded.level, updated_at = now();
  else
    raise exception using message = 'invalid_level', errcode = 'P0001';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Public wrappers (what the app calls via supabase.rpc)
-- ---------------------------------------------------------------------------

create function public.create_circle(p_name text) returns uuid
language sql security invoker set search_path = ''
as $$ select private.create_circle(p_name); $$;

create function public.create_invite(p_circle uuid) returns text
language sql security invoker set search_path = ''
as $$ select private.create_invite(p_circle); $$;

create function public.preview_invite(p_code text)
returns table (circle_name text, inviter_name text, member_count integer)
language sql security invoker set search_path = ''
as $$ select * from private.preview_invite(p_code); $$;

create function public.accept_invite(p_code text) returns uuid
language sql security invoker set search_path = ''
as $$ select private.accept_invite(p_code); $$;

create function public.leave_circle(p_circle uuid) returns void
language sql security invoker set search_path = ''
as $$ select private.leave_circle(p_circle); $$;

create function public.set_sharing_paused(p_circle uuid, p_paused boolean) returns void
language sql security invoker set search_path = ''
as $$ select private.set_sharing_paused(p_circle, p_paused); $$;

create function public.set_share_level(p_circle uuid, p_viewer uuid, p_level text) returns void
language sql security invoker set search_path = ''
as $$ select private.set_share_level(p_circle, p_viewer, p_level); $$;

grant execute on function
  private.is_circle_member(uuid),
  private.is_member_of(uuid, uuid),
  private.shares_circle_with(uuid),
  private.require_member(uuid),
  private.require_sharing_consent(),
  private.create_circle(text),
  private.create_invite(uuid),
  private.preview_invite(text),
  private.accept_invite(text),
  private.leave_circle(uuid),
  private.set_sharing_paused(uuid, boolean),
  private.set_share_level(uuid, uuid, text),
  public.create_circle(text),
  public.create_invite(uuid),
  public.preview_invite(text),
  public.accept_invite(text),
  public.leave_circle(uuid),
  public.set_sharing_paused(uuid, boolean),
  public.set_share_level(uuid, uuid, text)
to authenticated;
