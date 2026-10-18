-- Move the newly initialized, empty web geography columns to a private
-- PostGIS schema before first production use. No native table is touched.
-- Supabase's documented PostGIS relocation uses drop/recreate; without CASCADE,
-- unexpected dependencies abort the entire transaction instead of being removed.
-- https://supabase.com/docs/guides/database/extensions/postgis

begin;
set local search_path = public, extensions;

do $move$
declare
  installed_schema text;
begin
  select n.nspname into installed_schema
  from pg_extension e join pg_namespace n on n.oid = e.extnamespace
  where e.extname = 'postgis';

  if installed_schema = 'extensions' then
    return;
  end if;
  if installed_schema is distinct from 'public' then
    raise exception 'Unexpected PostGIS schema; inspect before migrating';
  end if;
  if exists (select 1 from public.experiences limit 1)
     or exists (select 1 from public.places limit 1) then
    raise exception 'Web geography contains data; a backed-up data migration is required';
  end if;

  -- Lock before rechecking emptiness so a concurrent first write cannot be lost.
  lock table public.experiences, public.places in access exclusive mode;
  if exists (select 1 from public.experiences limit 1)
     or exists (select 1 from public.places limit 1) then
    raise exception 'Web geography received data; stop before rebuilding empty columns';
  end if;

  alter table public.experiences drop column location;
  alter table public.places drop column location;
  drop extension postgis;
  create extension postgis schema extensions;
  alter table public.experiences
    add column location extensions.geography(Point, 4326) not null;
  alter table public.places
    add column location extensions.geography(Point, 4326) not null;
  create index experiences_location_gist on public.experiences using gist (location);
  create index places_location_gist on public.places using gist (location);
end;
$move$;

-- Preserve the existing RPC body and permissions; resolve PostGIS in extensions.
create or replace function public.upsert_place_identity(
  p_provider text,
  p_external_id text,
  p_canonical_name text,
  p_longitude double precision,
  p_latitude double precision,
  p_basic_category text default null,
  p_identity_confidence double precision default 0.5,
  p_metadata jsonb default null
)
returns public.places
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  place_row public.places%rowtype;
  existing_place_id uuid;
begin
  if p_longitude < -180 or p_longitude > 180 or p_latitude < -90 or p_latitude > 90 then
    raise exception 'invalid WGS-84 coordinate';
  end if;
  if p_identity_confidence < 0 or p_identity_confidence > 1 then
    raise exception 'identity confidence must be between 0 and 1';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_provider || ':' || p_external_id, 0));
  select place_id into existing_place_id
  from public.place_external_refs
  where provider = p_provider and external_id = p_external_id
  for update;

  if existing_place_id is null then
    insert into public.places (canonical_name, basic_category, location, identity_confidence)
    values (
      p_canonical_name,
      p_basic_category,
      st_setsrid(st_makepoint(p_longitude, p_latitude), 4326)::geography,
      p_identity_confidence
    )
    returning * into place_row;

    insert into public.place_external_refs (place_id, provider, external_id, metadata)
    values (place_row.id, p_provider, p_external_id, p_metadata);
  else
    update public.places
    set canonical_name = p_canonical_name,
        basic_category = coalesce(p_basic_category, basic_category),
        location = st_setsrid(st_makepoint(p_longitude, p_latitude), 4326)::geography,
        identity_confidence = greatest(identity_confidence, p_identity_confidence)
    where id = existing_place_id
    returning * into place_row;

    update public.place_external_refs
    set last_seen_at = now(), retired_at = null, metadata = coalesce(p_metadata, metadata)
    where provider = p_provider and external_id = p_external_id;
  end if;

  return place_row;
end;
$$;

notify pgrst, 'reload schema';
commit;
