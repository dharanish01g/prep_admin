-- Deleting a profile sets ic_tasks.created_by to null, but the update
-- trigger restored the old value, leaving tasks pointing at deleted users.

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
    -- The creator is fixed, but may be cleared: deleting their profile sets
    -- it to null (on delete set null), which must not be undone here.
    if new.created_by is not null then
      new.created_by := old.created_by;
    end if;
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

-- Repair tasks already left pointing at deleted users.
update public.ic_tasks t set created_by = null
where created_by is not null
  and not exists (select 1 from public.profiles p where p.id = t.created_by);
