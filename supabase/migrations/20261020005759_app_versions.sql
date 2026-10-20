-- Latest app version per platform, for "Check for updates" in Settings.
-- Publish an update by editing the row: bump latest_version, set the link
-- (shared APK now, store listing after launch) and optional notes.
create table public.app_versions (
  platform text primary key check (platform in ('android', 'ios')),
  latest_version text not null check (latest_version ~ '^\d+(\.\d+){0,2}$'),
  download_url text,
  notes text not null default '',
  updated_at timestamptz not null default now()
);

create trigger app_versions_set_updated_at
before update on public.app_versions
for each row execute function public.set_updated_at();

-- Anyone may read; changes are made from the dashboard or SQL only.
alter table public.app_versions enable row level security;

create policy "anyone reads app versions" on public.app_versions
for select to anon, authenticated
using (true);

insert into public.app_versions (platform, latest_version) values
  ('android', '1.0.0'),
  ('ios', '1.0.0');
