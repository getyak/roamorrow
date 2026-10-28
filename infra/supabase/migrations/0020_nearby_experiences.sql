-- Apply geographic/status/city/category filters and stable distance order before
-- the result limit. Existing experiences_location_gist serves ST_DWithin.
-- https://supabase.com/docs/guides/database/extensions/postgis
-- https://postgis.net/docs/ST_DWithin.html
begin;

create or replace function public.find_nearby_experiences(
  p_longitude double precision,
  p_latitude double precision,
  p_radius_meters double precision,
  p_limit integer default 50,
  p_category text default null,
  p_city_code text default null
)
returns setof jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $function$
declare
  origin extensions.geography;
begin
  if p_longitude is null or p_longitude < -180 or p_longitude > 180
    or p_latitude is null or p_latitude < -90 or p_latitude > 90
    or p_radius_meters is null or p_radius_meters <= 0 or p_radius_meters > 10000
    or p_limit is null or p_limit < 1 or p_limit > 100 then
    raise exception 'Invalid bounded nearby query' using errcode = '22023';
  end if;
  origin := extensions.st_setsrid(extensions.st_makepoint(p_longitude, p_latitude), 4326)::extensions.geography;
  return query
    select to_jsonb(e) || jsonb_build_object('location', extensions.st_asgeojson(e.location)::jsonb)
    from public.experiences e
    where e.status = 'active'
      and (p_category is null or e.category = p_category)
      and (p_city_code is null or e.city_code = p_city_code)
      and extensions.st_dwithin(e.location, origin, p_radius_meters)
    order by extensions.st_distance(e.location, origin), e.id
    limit p_limit;
end;
$function$;

revoke all on function public.find_nearby_experiences(double precision, double precision, double precision, integer, text, text) from public;
grant execute on function public.find_nearby_experiences(double precision, double precision, double precision, integer, text, text) to anon, authenticated, service_role;
-- No table grant, write grant, definer privilege or policy change is introduced.
notify pgrst, 'reload schema';
commit;
