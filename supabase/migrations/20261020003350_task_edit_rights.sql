-- Only a task's creator edits or deletes it. The assignee may only move it
-- between statuses; other team members just read it.

drop policy "members edit tasks" on public.ic_tasks;
drop policy "members delete tasks" on public.ic_tasks;

create policy "creator or assignee edit tasks" on public.ic_tasks
for update to authenticated
using (
  (select private.ic_is_member(team_id))
  and (created_by = (select auth.uid()) or assigned_to = (select auth.uid()))
)
with check ((select private.ic_is_member(team_id)));

create policy "creator deletes tasks" on public.ic_tasks
for delete to authenticated
using (
  (select private.ic_is_member(team_id)) and created_by = (select auth.uid())
);

-- Same as before, plus: an assignee's update may change the status only.
-- Team functions (security definer, so current_user isn't 'authenticated')
-- still unassign tasks when someone leaves, and deleting a profile still
-- clears created_by.
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
    if current_user = 'authenticated'
      and old.created_by is distinct from (select auth.uid())
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
