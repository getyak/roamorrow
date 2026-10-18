-- Transactional acceptance for the web launch schema. No probe row persists.
-- Run after 0018 + 0014–0016 + 0019 on the intended Supabase project.

begin;
set local role service_role;
do $test$
declare
  probe public.places;
begin
  probe := public.upsert_place_identity(
    'roamorrow_bootstrap_probe', gen_random_uuid()::text,
    'Transaction-only schema probe', 0::double precision, 0::double precision
  );
  if probe.location is null
     or extensions.st_srid(probe.location::extensions.geometry) <> 4326
     or extensions.st_x(probe.location::extensions.geometry) <> 0
     or extensions.st_y(probe.location::extensions.geometry) <> 0 then
    raise exception 'Private-schema PostGIS RPC did not preserve point coordinates';
  end if;
  if not has_function_privilege(current_user,
    'public.claim_refresh_jobs(text,integer,integer)', 'EXECUTE') then
    raise exception 'Service role cannot execute the refresh queue RPC';
  end if;
end;
$test$;
rollback;

begin;
set local role anon;
do $test$
begin
  if not has_table_privilege(current_user, 'public.experiences', 'SELECT') then
    raise exception 'Public experience reads are not granted';
  end if;
  if has_table_privilege(current_user, 'public.traffic_pings', 'SELECT')
     or has_table_privilege(current_user, 'public.traffic_pings', 'INSERT') then
    raise exception 'Internal traffic records are exposed to anonymous clients';
  end if;
  if has_function_privilege(current_user,
    'public.claim_refresh_jobs(text,integer,integer)', 'EXECUTE')
     or has_function_privilege(current_user,
    'public.upsert_place_identity(text,text,text,double precision,double precision,text,double precision,jsonb)',
    'EXECUTE') then
    raise exception 'An internal service RPC is exposed to anonymous clients';
  end if;
  perform id from public.experiences where status = 'active' limit 1;
end;
$test$;
rollback;

select 'web bootstrap role and spatial RPC checks passed; probe rolled back' as result;
