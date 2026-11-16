-- Baby TV shared catalog.
-- Anyone can read. Only a signed-in parent can change the list or the rules.
-- The service-role key stays in Supabase. Do not put it in index.html or git.
-- After the project exists: turn off public sign-up and create one parent user.

create table public.household (
  id          integer primary key default 1 check (id = 1),
  limit_wd    integer not null default 0 check (limit_wd between 0 and 600),
  limit_we    integer not null default 0 check (limit_we between 0 and 600),
  bed_on      boolean not null default false,
  bed_start   text not null default '20:00',
  bed_end     text not null default '07:00',
  locked_cats text[] not null default '{}',
  sound       boolean not null default true,
  updated_at  timestamptz not null default now()
);

create table public.videos (
  youtube_id text primary key check (youtube_id ~ '^[A-Za-z0-9_-]{11}$'),
  cat        text not null check (char_length(cat) between 1 and 80),
  name       text not null check (char_length(name) between 1 and 300),
  position   integer not null,
  updated_at timestamptz not null default now()
);

insert into public.household (id) values (1) on conflict (id) do nothing;

alter table public.household enable row level security;
alter table public.videos enable row level security;

create policy "anyone_read_household" on public.household
  for select to anon, authenticated using (true);
create policy "anyone_read_videos" on public.videos
  for select to anon, authenticated using (true);

create policy "parent_write_household" on public.household
  for all to authenticated using (true) with check (true);
create policy "parent_write_videos" on public.videos
  for all to authenticated using (true) with check (true);

grant select on public.household, public.videos to anon, authenticated;
grant insert, update, delete on public.household, public.videos to authenticated;

create or replace function public.replace_catalog(rows jsonb)
returns void
language plpgsql
security invoker
as $$
begin
  if auth.uid() is null then
    raise exception 'login required';
  end if;
  if rows is null or jsonb_typeof(rows) <> 'array' or jsonb_array_length(rows) = 0 then
    raise exception 'empty catalog';
  end if;
  delete from public.videos;
  insert into public.videos (youtube_id, cat, name, position)
  select
    item->>'youtube_id',
    item->>'cat',
    item->>'name',
    (item->>'position')::integer
  from jsonb_array_elements(rows) as item;
end;
$$;

revoke all on function public.replace_catalog(jsonb) from public;
grant execute on function public.replace_catalog(jsonb) to authenticated;
alter function public.replace_catalog(jsonb) set search_path = public;
