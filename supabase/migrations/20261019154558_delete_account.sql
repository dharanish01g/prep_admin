-- Account deletion (required by Google Play and the App Store).
--
-- Leaving is shared by ic_leave_team and ic_delete_account, so it moves into
-- private.ic_leave, which takes the user explicitly.

create or replace function private.ic_leave(p_team uuid, p_user uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_was_owner boolean;
  v_heir uuid;
begin
  select role = 'owner' into v_was_owner from public.ic_team_members
  where team_id = p_team and user_id = p_user;
  if not found then
    raise exception 'You are not in this team';
  end if;
  perform private.ic_drop_member(p_team, p_user);

  select user_id into v_heir from public.ic_team_members
  where team_id = p_team
  order by joined_at
  limit 1;

  if v_heir is null then
    delete from public.ic_teams where id = p_team;
  elsif v_was_owner then
    update public.ic_team_members set role = 'owner'
    where team_id = p_team and user_id = v_heir;
  end if;
end;
$$;

revoke all on function private.ic_leave(uuid, uuid) from public;

-- If the owner leaves, the longest-standing member takes over; the last
-- person out deletes the team and its tasks.
create or replace function public.ic_leave_team(p_team uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Not signed in';
  end if;
  perform private.ic_leave(p_team, auth.uid());
end;
$$;

-- Leaves every team, then deletes the login. The profile goes with it
-- (on delete cascade); common tasks the user created stay with their team,
-- with created_by cleared.
create or replace function public.ic_delete_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_team uuid;
begin
  if v_user is null then
    raise exception 'Not signed in';
  end if;
  for v_team in
    select team_id from public.ic_team_members where user_id = v_user
  loop
    perform private.ic_leave(v_team, v_user);
  end loop;
  delete from auth.users where id = v_user;
end;
$$;

revoke all on function public.ic_delete_account() from public, anon;
grant execute on function public.ic_delete_account() to authenticated;
