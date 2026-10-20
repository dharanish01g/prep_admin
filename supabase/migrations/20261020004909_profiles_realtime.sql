-- Renaming yourself in Settings shows up live for teammates. Row level
-- security still decides who receives each change.
alter publication supabase_realtime add table public.profiles;
