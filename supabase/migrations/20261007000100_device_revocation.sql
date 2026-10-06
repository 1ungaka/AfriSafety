-- Revocation is final (Phase 3).
--
-- Owners may update their devices' revoked_at (to sign a phone out), but a
-- revoked device must never come back: otherwise a stolen phone whose
-- session hadn't expired yet could clear its own revoked_at, and members'
-- apps would hand it fresh keys again. A signed-out phone that wants back
-- in registers as a new device, which everyone is told about.

create function private.devices_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.revoked_at is not null and new.revoked_at is distinct from old.revoked_at then
    raise exception using message = 'device_revoked', errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger devices_guard before update on public.devices
  for each row execute function private.devices_guard();
