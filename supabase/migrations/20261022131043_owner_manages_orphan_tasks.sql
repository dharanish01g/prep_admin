-- Tasks whose creator has left the team (or deleted their account, which
-- clears created_by) could no longer be edited or deleted by anyone. The
-- team owner now looks after them: edit, delete, move between statuses.
-- Everything else stays as before: the creator edits and deletes, the
-- assignee only changes the status.

-- The creator, or the team owner once the creator is gone from the team.
-- Never null (a cleared creator must read as "no", not "unknown").
create or replace function private.ic_can_manage_task(p_team uuid, p_creator uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(p_creator = (select auth.uid()), false)
    or (
      private.ic_is_owner(p_team)
      and not exists (
        select 1 from public.ic_team_members
        where team_id = p_team and user_id = p_creator
      )
    );
$$;

revoke all on function private.ic_can_manage_task(uuid, uuid) from public;
grant execute on function private.ic_can_manage_task(uuid, uuid) to authenticated;

drop policy "creator or assignee edit tasks" on public.ic_tasks;
drop policy "creator deletes tasks" on public.ic_tasks;

create policy "manager or assignee edit tasks" on public.ic_tasks
for update to authenticated
using (
  (select private.ic_is_member(team_id))
  and (
    private.ic_can_manage_task(team_id, created_by)
    or assigned_to = (select auth.uid())
  )
)
with check ((select private.ic_is_member(team_id)));

create policy "manager deletes tasks" on public.ic_tasks
for delete to authenticated
using (
  (select private.ic_is_member(team_id))
  and private.ic_can_manage_task(team_id, created_by)
);

-- Same as before, with "the creator" widened to whoever manages the task.
-- Only the creator may turn a task into a personal to-do: one made for
-- someone who has left would be hidden from everyone.
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
    if current_user = 'authenticated' then
      if not private.ic_can_manage_task(old.team_id, old.created_by)
        and (
          new.title, new.description, new.scope, new.priority,
          new.assigned_to, new.due_date
        ) is distinct from (
          old.title, old.description, old.scope, old.priority,
          old.assigned_to, old.due_date
        )
      then
        raise exception 'Only the task''s creator can edit it';
      end if;
      if new.scope = 'personal' and old.scope <> 'personal'
        and old.created_by is distinct from (select auth.uid())
      then
        raise exception 'Only the task''s creator can make it personal';
      end if;
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
