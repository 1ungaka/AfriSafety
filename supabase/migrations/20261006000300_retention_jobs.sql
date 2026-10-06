-- Retention and scheduled jobs (Phase 2).
--
-- private.purge_expired() enforces the retention periods promised in the
-- privacy policy. Both jobs are scheduled with pg_cron when it is
-- available. On Supabase, enable it under Integrations → Cron (or let this
-- migration create it), then run this file again if it was skipped.

create function private.purge_expired()
returns void
language sql
security definer
set search_path = ''
as $$
  -- Alerts (and their receipts) for 30 days: long enough to follow up an
  -- incident, short enough not to become a location archive.
  delete from public.alerts where created_at < now() - interval '30 days';
  -- Place and journey events are only useful for a few days.
  delete from public.circle_events where created_at < now() - interval '7 days';
  -- Finished check-ins (with any leftover escrow) after 7 days.
  delete from public.checkins
   where status <> 'active' and updated_at < now() - interval '7 days';
  -- Rate-limit counters are only needed for their window.
  delete from private.rate_limits where window_start < now() - interval '2 days';
$$;

revoke execute on function private.purge_expired() from public, anon, authenticated;

do $$
begin
  if not exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    raise notice 'pg_cron is not available: schedule private.expire_checkins() and private.purge_expired() yourself';
    return;
  end if;
  begin
    create extension if not exists pg_cron with schema pg_catalog;
  exception when others then
    raise notice 'Could not create pg_cron (%). Enable Cron in the dashboard and run this migration again', sqlerrm;
    return;
  end;
  -- Named jobs are replaced if they already exist, so this is safe to rerun.
  execute $sql$ select cron.schedule('afrisafety-checkin-watchdog', '* * * * *',
                  'select private.expire_checkins()') $sql$;
  execute $sql$ select cron.schedule('afrisafety-retention', '17 3 * * *',
                  'select private.purge_expired()') $sql$;
end;
$$;
