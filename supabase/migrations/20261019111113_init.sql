-- prep_admin: teams (separate workspaces) with personal and common tasks.
-- A profile row is created for every new auth user.

-- Helpers live in `private`, which is not exposed through the API.
create schema if not exists private;
grant usage on schema private to authenticated;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- Profiles ------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null default '',
  email text not null default '',
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name, email, avatar_url)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data ->> 'full_name', ''),
      nullif(new.raw_user_meta_data ->> 'name', ''),
      split_part(coalesce(new.email, ''), '@', 1)
    ),
    coalesce(new.email, ''),
    new.raw_user_meta_data ->> 'avatar_url'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function private.handle_new_user();

-- Teams ---------------------------------------------------------------------

-- 6 characters, no look-alikes (0/O, 1/I).
create or replace function private.ic_random_code()
returns text
language sql
volatile
set search_path = ''
as $$
  select string_agg(
    substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', 1 + floor(random() * 32)::int, 1),
    ''
  )
  from generate_series(1, 6);
$$;

create table public.ic_teams (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 1 and 40),
  color smallint not null default 0 check (color between 0 and 7),
  join_code text not null unique default private.ic_random_code()
    check (join_code ~ '^[A-Z0-9]{6}$'),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger ic_teams_set_updated_at
before update on public.ic_teams
for each row execute function public.set_updated_at();

create table public.ic_team_members (
  team_id uuid not null references public.ic_teams (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member')),
  joined_at timestamptz not null default now(),
  primary key (team_id, user_id)
);

create index ic_team_members_user_id_idx on public.ic_team_members (user_id);

-- Tasks ---------------------------------------------------------------------

create table public.ic_tasks (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.ic_teams (id) on delete cascade,
  title text not null check (btrim(title) <> ''),
  description text not null default '',
  scope text not null default 'personal' check (scope in ('personal', 'common')),
  status text not null default 'todo'
    check (status in ('todo', 'in_progress', 'done')),
  priority text not null default 'medium'
    check (priority in ('low', 'medium', 'high')),
  created_by uuid default auth.uid()
    references public.profiles (id) on delete set null,
  assigned_to uuid references public.profiles (id) on delete set null,
  due_date date,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index ic_tasks_team_id_idx on public.ic_tasks (team_id);
create index ic_tasks_assigned_to_idx on public.ic_tasks (assigned_to);
create index ic_tasks_created_by_idx on public.ic_tasks (created_by);

-- Keeps tasks consistent: personal to-dos belong to their creator, assignees
-- must be in the team, tasks never move teams, completed_at tracks status.
create or replace function private.ic_tasks_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    if new.team_id <> old.team_id then
      raise exception 'Tasks cannot move between teams';
    end if;
    new.created_by := old.created_by;
    new.created_at := old.created_at;
    new.updated_at := now();
  end if;

  if new.scope = 'personal' then
    new.assigned_to := new.created_by;
  end if;

  if new.assigned_to is not null and not exists (
    select 1 from public.ic_team_members m
    where m.team_id = new.team_id and m.user_id = new.assigned_to
  ) then
    raise exception 'Assignee is not a member of this team';
  end if;

  if new.status = 'done' then
    if tg_op = 'INSERT' or old.status <> 'done' then
      new.completed_at := now();
    end if;
  else
    new.completed_at := null;
  end if;

  return new;
end;
$$;

create trigger ic_tasks_before_write
before insert or update on public.ic_tasks
for each row execute function private.ic_tasks_before_write();

-- Access helpers --------------------------------------------------------------

create or replace function private.ic_is_member(p_team uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.ic_team_members
    where team_id = p_team and user_id = (select auth.uid())
  );
$$;

create or replace function private.ic_is_owner(p_team uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.ic_team_members
    where team_id = p_team and user_id = (select auth.uid()) and role = 'owner'
  );
$$;

create or replace function private.ic_shares_team(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.ic_team_members mine
    join public.ic_team_members theirs on theirs.team_id = mine.team_id
    where mine.user_id = (select auth.uid()) and theirs.user_id = p_user
  );
$$;

revoke all on function private.ic_is_member(uuid) from public;
revoke all on function private.ic_is_owner(uuid) from public;
revoke all on function private.ic_shares_team(uuid) from public;
grant execute on function private.ic_is_member(uuid) to authenticated;
grant execute on function private.ic_is_owner(uuid) to authenticated;
grant execute on function private.ic_shares_team(uuid) to authenticated;

-- Row level security ----------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.ic_teams enable row level security;
alter table public.ic_team_members enable row level security;
alter table public.ic_tasks enable row level security;

-- You see yourself and people who share a team with you.
create policy "read own and teammates' profiles" on public.profiles
for select to authenticated
using (id = (select auth.uid()) or (select private.ic_shares_team(id)));

create policy "update own profile" on public.profiles
for update to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

-- Teams: members read; owners rename / recolour. Creating, joining, leaving
-- and removing go through the functions below.
create policy "members read team" on public.ic_teams
for select to authenticated
using ((select private.ic_is_member(id)));

create policy "owners update team" on public.ic_teams
for update to authenticated
using ((select private.ic_is_owner(id)))
with check ((select private.ic_is_owner(id)));

create policy "members read memberships" on public.ic_team_members
for select to authenticated
using ((select private.ic_is_member(team_id)));

-- Tasks: fully open inside a team, invisible outside it.
create policy "members read tasks" on public.ic_tasks
for select to authenticated
using ((select private.ic_is_member(team_id)));

create policy "members create tasks" on public.ic_tasks
for insert to authenticated
with check (
  (select private.ic_is_member(team_id)) and created_by = (select auth.uid())
);

create policy "members edit tasks" on public.ic_tasks
for update to authenticated
using ((select private.ic_is_member(team_id)))
with check ((select private.ic_is_member(team_id)));

create policy "members delete tasks" on public.ic_tasks
for delete to authenticated
using ((select private.ic_is_member(team_id)));

-- Team actions (RPC) ----------------------------------------------------------

create or replace function public.ic_create_team(p_name text, p_color int default 0)
returns public.ic_teams
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_team public.ic_teams;
begin
  if auth.uid() is null then
    raise exception 'Not signed in';
  end if;
  loop
    begin
      insert into public.ic_teams (name, color, created_by)
      values (btrim(p_name), p_color, auth.uid())
      returning * into v_team;
      exit;
    exception when unique_violation then
      -- Join code clash; try another.
    end;
  end loop;
  insert into public.ic_team_members (team_id, user_id, role)
  values (v_team.id, auth.uid(), 'owner');
  return v_team;
end;
$$;

-- What a code points to, so the app can show the team before joining.
create or replace function public.ic_preview_team(p_code text)
returns table (id uuid, name text, color smallint, member_count int, is_member boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select t.id, t.name, t.color,
    (select count(*)::int from public.ic_team_members m where m.team_id = t.id),
    exists (
      select 1 from public.ic_team_members m
      where m.team_id = t.id and m.user_id = auth.uid()
    )
  from public.ic_teams t
  where auth.uid() is not null
    and t.join_code = upper(regexp_replace(p_code, '[^A-Za-z0-9]', '', 'g'));
$$;

create or replace function public.ic_join_team(p_code text)
returns public.ic_teams
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_team public.ic_teams;
begin
  if auth.uid() is null then
    raise exception 'Not signed in';
  end if;
  select * into v_team from public.ic_teams
  where join_code = upper(regexp_replace(p_code, '[^A-Za-z0-9]', '', 'g'));
  if not found then
    raise exception 'No team uses this code';
  end if;
  insert into public.ic_team_members (team_id, user_id)
  values (v_team.id, auth.uid())
  on conflict do nothing;
  return v_team;
end;
$$;

create or replace function public.ic_regenerate_join_code(p_team uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text;
begin
  if not private.ic_is_owner(p_team) then
    raise exception 'Only the team owner can do this';
  end if;
  loop
    begin
      update public.ic_teams set join_code = private.ic_random_code()
      where id = p_team
      returning join_code into v_code;
      return v_code;
    exception when unique_violation then
    end;
  end loop;
end;
$$;

-- Drops someone from a team: their personal to-dos there are deleted and
-- their assigned tasks become unassigned.
create or replace function private.ic_drop_member(p_team uuid, p_user uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.ic_tasks
  where team_id = p_team and scope = 'personal' and created_by = p_user;
  update public.ic_tasks set assigned_to = null
  where team_id = p_team and assigned_to = p_user;
  delete from public.ic_team_members
  where team_id = p_team and user_id = p_user;
$$;

revoke all on function private.ic_drop_member(uuid, uuid) from public;

create or replace function public.ic_remove_member(p_team uuid, p_user uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.ic_is_owner(p_team) then
    raise exception 'Only the team owner can do this';
  end if;
  if p_user = auth.uid() then
    raise exception 'Use leave instead';
  end if;
  perform private.ic_drop_member(p_team, p_user);
end;
$$;

-- If the owner leaves, the longest-standing member takes over; the last
-- person out deletes the team and its tasks.
create or replace function public.ic_leave_team(p_team uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_was_owner boolean;
  v_heir uuid;
begin
  if not private.ic_is_member(p_team) then
    raise exception 'You are not in this team';
  end if;
  v_was_owner := private.ic_is_owner(p_team);
  perform private.ic_drop_member(p_team, auth.uid());

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

do $$
declare
  f text;
begin
  foreach f in array array[
    'public.ic_create_team(text, int)',
    'public.ic_preview_team(text)',
    'public.ic_join_team(text)',
    'public.ic_regenerate_join_code(uuid)',
    'public.ic_remove_member(uuid, uuid)',
    'public.ic_leave_team(uuid)'
  ] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end;
$$;

-- Live updates for the app.
alter publication supabase_realtime
  add table public.ic_tasks, public.ic_team_members, public.ic_teams;
