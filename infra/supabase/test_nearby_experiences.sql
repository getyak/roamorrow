\set ON_ERROR_STOP on
-- Only the named isolated test DB is accepted. Every fixture is rolled back.
begin;
do $$ begin
  if current_database() <> 'roamorrow_geo_test' then raise exception 'isolated test database required'; end if;
end $$;
insert into public.experiences (id,status,city_code,category,location)
select 'far-'||n, 'active','far','culture',extensions.st_setsrid(extensions.st_makepoint(0,0),4326)::extensions.geography
from generate_series(1,120) n;
insert into public.experiences values
 ('near-b','active','cmi','culture','SRID=4326;POINT(98.9853 18.7883)'),
 ('near-a','active','cmi','culture','SRID=4326;POINT(98.9853 18.7883)'),
 ('near-c','active','cmi','culture','SRID=4326;POINT(98.9903 18.7883)'),
 ('near-food','active','cmi','food','SRID=4326;POINT(98.9853 18.7883)'),
 ('other-city','active','other','culture','SRID=4326;POINT(98.9853 18.7883)'),
 ('retired','retired','cmi','culture','SRID=4326;POINT(98.9853 18.7883)'),
 ('outside','active','cmi','culture','SRID=4326;POINT(99.9853 18.7883)'),
 ('date-line','active','dateline','culture','SRID=4326;POINT(-179.999 0)'),
 ('polar','active','polar','culture','SRID=4326;POINT(180 89.999)');

set local role anon;
do $test$
declare ids text[]; point jsonb; old_count integer;
begin
  -- Reproduce the previous global cap against real PostGIS rows.
  select count(*) into old_count from (
    select * from public.experiences where status='active' limit 120
  ) capped where extensions.st_dwithin(location,
    extensions.st_setsrid(extensions.st_makepoint(98.9853,18.7883),4326)::extensions.geography,1500);
  if old_count <> 0 then raise exception 'old cap fixture did not reproduce omission'; end if;

  select array_agg(r->>'id') into ids
  from public.find_nearby_experiences(98.9853,18.7883,1500,2,'culture','cmi') r;
  if ids is distinct from array['near-a','near-b'] then
    raise exception 'nearby completeness, city/category/status isolation or stable tie order failed: %',ids;
  end if;
  select array_agg(r->>'id') into ids
  from public.find_nearby_experiences(98.9853,18.7883,1500,3,'culture','cmi') r;
  if ids is distinct from array['near-a','near-b','near-c'] then
    raise exception 'distance order before limit failed';
  end if;
  select array_agg(r->>'id') into ids
  from public.find_nearby_experiences(98.9853,18.7883,500,100,'culture','cmi') r;
  if ids is distinct from array['near-a','near-b'] then raise exception 'radius boundary failed'; end if;
  if (select prosecdef from pg_proc where oid =
    'public.find_nearby_experiences(double precision,double precision,double precision,integer,text,text)'::regprocedure) then
    raise exception 'public lookup must retain invoker security';
  end if;
  select r->'location' into point
  from public.find_nearby_experiences(98.9853,18.7883,1500,1,'culture','cmi') r;
  if point->>'type' <> 'Point' or point->'coordinates' <> '[98.9853,18.7883]'::jsonb then
    raise exception 'GeoJSON longitude/latitude contract failed';
  end if;
  select array_agg(r->>'id') into ids
  from public.find_nearby_experiences(179.999,0,500,10,null,'dateline') r;
  if ids is distinct from array['date-line'] then raise exception 'antimeridian query failed'; end if;
  select array_agg(r->>'id') into ids
  from public.find_nearby_experiences(0,89.999,500,10,null,'polar') r;
  if ids is distinct from array['polar'] then raise exception 'polar query failed'; end if;
  if has_table_privilege(current_user,'public.experiences','INSERT')
    or has_table_privilege(current_user,'public.experiences','UPDATE') then
    raise exception 'public lookup acquired write privileges';
  end if;
  begin
    perform public.find_nearby_experiences(0,0,10001,1,null,null);
    raise exception 'oversized radius was accepted';
  exception when sqlstate '22023' then null; end;
  begin
    perform public.find_nearby_experiences(0,91,500,1,null,null);
    raise exception 'invalid latitude was accepted';
  exception when sqlstate '22023' then null; end;
end;
$test$;
reset role;
rollback;
select 'nearby geospatial/RLS acceptance passed; fixtures rolled back' as result;
