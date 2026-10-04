-- End-to-end encrypted sharing: sender keys (D7), latest locations, panic
-- alerts and delivery receipts.
--
-- Key model (D7, "sender keys"): every device has its own symmetric key per
-- Circle and per channel:
--   * 'location': given only to members allowed to see live location
--   * 'alert':    given to every member, so SOS alerts always get through
-- A device seals its key to each recipient device's public key (sealed
-- box) and signs the envelope. The server stores envelopes and ciphertext
-- but never sees a usable key.

create table public.sender_key_envelopes (
  circle_id uuid not null references public.circles (id) on delete cascade,
  sender_device_id uuid not null references public.devices (id) on delete cascade,
  sender_id uuid not null references auth.users (id) on delete cascade,
  channel text not null check (channel in ('location', 'alert')),
  key_version integer not null check (key_version >= 1),
  recipient_device_id uuid not null references public.devices (id) on delete cascade,
  sealed_key text not null check (char_length(sealed_key) <= 256),
  signature text not null check (length(decode(signature, 'base64')) = 64),
  created_at timestamptz not null default now(),
  primary key (circle_id, sender_device_id, channel, key_version, recipient_device_id)
);

create index envelopes_recipient on public.sender_key_envelopes (recipient_device_id);

alter table public.sender_key_envelopes enable row level security;
revoke all on table public.sender_key_envelopes from authenticated;
grant select, insert, delete on table public.sender_key_envelopes to authenticated;

-- Recipients read envelopes addressed to their devices, but only while
-- they're still members. Senders read what they've handed out so their app
-- can tell when a key must rotate.
create policy envelopes_select on public.sender_key_envelopes
  for select to authenticated
  using (
    sender_id = (select auth.uid())
    or (
      private.device_owner(recipient_device_id) = (select auth.uid())
      and private.is_circle_member(circle_id)
    )
  );

create policy envelopes_insert on public.sender_key_envelopes
  for insert to authenticated
  with check (
    sender_id = (select auth.uid())
    and private.is_my_active_device(sender_device_id)
    and private.is_circle_member(circle_id)
    and private.is_member_of(circle_id, private.device_owner(recipient_device_id))
    and exists (
      select 1 from public.devices d
      where d.id = recipient_device_id and d.revoked_at is null
    )
  );

create policy envelopes_delete_own on public.sender_key_envelopes
  for delete to authenticated using (sender_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- Latest location per member per Circle. One row each, overwritten in place:
-- history (Phase 2) lives elsewhere with its own retention.
-- ---------------------------------------------------------------------------

create table public.location_latest (
  circle_id uuid not null,
  user_id uuid not null,
  sender_device_id uuid not null references public.devices (id) on delete cascade,
  key_version integer not null check (key_version >= 1),
  ciphertext text not null check (char_length(ciphertext) <= 512),
  updated_at timestamptz not null default now(),
  primary key (circle_id, user_id),
  foreign key (circle_id, user_id)
    references public.circle_members (circle_id, user_id) on delete cascade
);

alter table public.location_latest enable row level security;
revoke all on table public.location_latest from authenticated;
grant select, insert, update, delete on table public.location_latest to authenticated;

create policy location_select_member on public.location_latest
  for select to authenticated using (private.is_circle_member(circle_id));

-- Writes must come from your own active device, in a Circle where you
-- haven't paused sharing. (The app also stops sending when paused; this is
-- the second layer.)
create function private.can_write_location(p_circle uuid, p_user uuid, p_device uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_user = auth.uid()
    and private.is_my_active_device(p_device)
    and exists (
      select 1 from public.circle_members m
      where m.circle_id = p_circle and m.user_id = p_user and not m.sharing_paused
    );
$$;

create policy location_insert_own on public.location_latest
  for insert to authenticated
  with check (private.can_write_location(circle_id, user_id, sender_device_id));
create policy location_update_own on public.location_latest
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (private.can_write_location(circle_id, user_id, sender_device_id));
create policy location_delete_own on public.location_latest
  for delete to authenticated using (user_id = (select auth.uid()));

create trigger location_latest_updated_at before update on public.location_latest
  for each row execute function private.set_updated_at();

-- ---------------------------------------------------------------------------
-- Panic alerts. One row per Circle; rows from the same button press share
-- an incident_id. The id is generated by the app, so retries are idempotent.
-- Alerts are allowed even while sharing is paused.
-- ---------------------------------------------------------------------------

create table public.alerts (
  id uuid primary key,
  incident_id uuid not null,
  circle_id uuid not null,
  sender_id uuid not null,
  sender_device_id uuid not null references public.devices (id) on delete cascade,
  kind text not null check (kind in ('panic')),
  key_version integer not null check (key_version >= 1),
  ciphertext text not null check (char_length(ciphertext) <= 1024),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  -- Set by the dispatch-alert function (service role) after pushing, so a
  -- sender can't make it push the same alert again and again.
  dispatched_at timestamptz,
  foreign key (circle_id, sender_id)
    references public.circle_members (circle_id, user_id) on delete cascade
);

create index alerts_circle on public.alerts (circle_id, created_at desc);
create index alerts_incident on public.alerts (incident_id);

alter table public.alerts enable row level security;
revoke all on table public.alerts from authenticated;
grant select, insert on table public.alerts to authenticated;

create policy alerts_select_member on public.alerts
  for select to authenticated using (private.is_circle_member(circle_id));
create policy alerts_insert_own on public.alerts
  for insert to authenticated
  with check (
    sender_id = (select auth.uid())
    and resolved_at is null
    and dispatched_at is null
    and private.is_my_active_device(sender_device_id)
    and private.is_circle_member(circle_id)
  );

-- Generous enough for real emergencies across several Circles, tight
-- enough to stop alert spam.
create function private.rate_limit_alerts()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.hit_rate_limit('panic_alert', 30, interval '1 hour');
  return new;
end;
$$;

create trigger alerts_rate_limit before insert on public.alerts
  for each row execute function private.rate_limit_alerts();

create table public.alert_receipts (
  alert_id uuid not null references public.alerts (id) on delete cascade,
  recipient_id uuid not null references auth.users (id) on delete cascade,
  delivered_at timestamptz not null default now(),
  seen_at timestamptz,
  primary key (alert_id, recipient_id)
);

alter table public.alert_receipts enable row level security;
revoke all on table public.alert_receipts from authenticated;
grant select on table public.alert_receipts to authenticated;

create function private.alert_sender(p_alert uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$ select a.sender_id from public.alerts a where a.id = p_alert; $$;

-- The sender sees who has received and opened their alert; each recipient
-- sees only their own receipt.
create policy receipts_select on public.alert_receipts
  for select to authenticated
  using (
    recipient_id = (select auth.uid())
    or private.alert_sender(alert_id) = (select auth.uid())
  );

create function private.acknowledge_alert(p_alert uuid, p_seen boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_circle uuid;
  v_sender uuid;
begin
  select a.circle_id, a.sender_id into v_circle, v_sender
  from public.alerts a where a.id = p_alert;
  if v_circle is null or not private.is_circle_member(v_circle) or v_sender = auth.uid() then
    raise exception using message = 'not_a_recipient', errcode = '42501';
  end if;
  insert into public.alert_receipts (alert_id, recipient_id, seen_at)
  values (p_alert, auth.uid(), case when p_seen then now() end)
  on conflict (alert_id, recipient_id) do update
    set seen_at = coalesce(public.alert_receipts.seen_at, excluded.seen_at);
end;
$$;

create function private.resolve_incident(p_incident uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.alerts set resolved_at = now()
  where incident_id = p_incident and sender_id = auth.uid() and resolved_at is null;
$$;

create function public.acknowledge_alert(p_alert uuid, p_seen boolean) returns void
language sql security invoker set search_path = ''
as $$ select private.acknowledge_alert(p_alert, p_seen); $$;

create function public.resolve_incident(p_incident uuid) returns void
language sql security invoker set search_path = ''
as $$ select private.resolve_incident(p_incident); $$;

grant execute on function
  private.can_write_location(uuid, uuid, uuid),
  private.alert_sender(uuid),
  private.acknowledge_alert(uuid, boolean),
  private.resolve_incident(uuid),
  public.acknowledge_alert(uuid, boolean),
  public.resolve_incident(uuid)
to authenticated;

-- ---------------------------------------------------------------------------
-- Realtime. Supabase Realtime applies these RLS policies to every change it
-- streams, so members only receive rows for their own Circles.
-- ---------------------------------------------------------------------------

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table
      public.circle_members,
      public.share_levels,
      public.sender_key_envelopes,
      public.location_latest,
      public.alerts,
      public.alert_receipts;
  end if;
end;
$$;
