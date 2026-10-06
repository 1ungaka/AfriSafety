-- Delete my account (launch readiness).
--
-- Google Play requires in-app account deletion, and POPIA (s24) gives the
-- right to have personal information deleted. Everything a user owns hangs
-- off auth.users with ON DELETE CASCADE, so deleting that row erases their
-- profile, consents, devices, keys, locations, alerts, check-ins, reports
-- and security log.
--
-- One catch: circles.owner_id also cascades, so deleting an owner directly
-- would delete the whole Circle for everyone. So the user first leaves
-- each Circle the normal way (ownership passes to the longest-standing
-- member, members are told, keys rotate), and only then is the account row
-- deleted.

create function private.delete_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_circle uuid;
begin
  if auth.uid() is null then
    raise exception using message = 'not_authenticated', errcode = '42501';
  end if;
  for v_circle in
    select m.circle_id from public.circle_members m where m.user_id = auth.uid()
  loop
    perform private.leave_circle(v_circle);
  end loop;
  delete from auth.users where id = auth.uid();
end;
$$;

create function public.delete_account() returns void
language sql security invoker set search_path = ''
as $$ select private.delete_account(); $$;

grant execute on function private.delete_account(), public.delete_account() to authenticated;
