\set ON_ERROR_STOP on
-- Isolated-container bootstrap only. Never connect this file to a hosted DB.
do $$ begin
  if current_database() <> 'roamorrow_geo_test' then raise exception 'isolated test database required'; end if;
end $$;
create schema if not exists extensions;
create extension postgis schema extensions;
create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
grant usage on schema public, extensions to anon, authenticated, service_role;
create table public.experiences (
  id text primary key,
  status text not null,
  city_code text not null,
  category text not null,
  location extensions.geography(Point,4326) not null
);
create index experiences_location_gist on public.experiences using gist(location);
alter table public.experiences enable row level security;
create policy experiences_public_read on public.experiences for select using (status = 'active');
grant select on public.experiences to anon, authenticated;
grant all on public.experiences to service_role;
