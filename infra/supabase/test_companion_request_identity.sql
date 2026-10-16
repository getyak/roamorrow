-- Run in a disposable database after 0003, 0004 and 0017. Everything rolls back.
begin;
insert into auth.users (id) values
 ('10000000-0000-0000-0000-000000000001'),
 ('10000000-0000-0000-0000-000000000002'),
 ('10000000-0000-0000-0000-000000000003');
insert into public.companion_profiles (id,user_id,visibility) values
 ('identity-author','10000000-0000-0000-0000-000000000002','itinerary_only');
insert into public.companion_posts (id,author_id,mode,blurb,city_code) values
 ('identity-post','10000000-0000-0000-0000-000000000002','itinerary','Test','TYO');

-- Test the direct client path with a real non-superuser role and auth.uid().
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
insert into public.companion_requests (id,post_id,requester_id,recipient_id) values
 ('valid','identity-post','10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002');
do $$ begin
  begin
    insert into public.companion_requests (id,post_id,requester_id,recipient_id) values
     ('forged','identity-post','10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000003');
    raise exception 'FAIL mismatched recipient was allowed';
  exception when insufficient_privilege then null; end;
  begin
    update public.companion_requests set recipient_id='10000000-0000-0000-0000-000000000003' where id='valid';
    raise exception 'FAIL recipient identity update was allowed';
  exception when insufficient_privilege then null; end;
  begin
    update public.companion_requests set status='accepted' where id='valid';
    raise exception 'FAIL requester self-accepted';
  exception when insufficient_privilege then null; end;
  begin
    insert into public.companion_requests (id,post_id,requester_id,recipient_id,status) values
     ('pre-accepted','identity-post','10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002','accepted');
    raise exception 'FAIL inserted an accepted request';
  exception when insufficient_privilege then null; end;
  begin
    insert into public.companion_requests (id,post_id,requester_id,recipient_id) values
     ('spoofed','identity-post','10000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000002');
    raise exception 'FAIL spoofed requester was allowed';
  exception when insufficient_privilege then null; end;
end $$;
-- Requester can withdraw; terminal requests cannot be resurrected.
insert into public.companion_requests (id,post_id,requester_id,recipient_id) values
 ('withdraw-test','identity-post','10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002');
update public.companion_requests set status='withdrawn' where id='withdraw-test';
do $$ begin
  begin
    update public.companion_requests set status='pending' where id='withdraw-test';
    raise exception 'FAIL terminal request resurrected';
  exception when insufficient_privilege then null; end;
end $$;
-- Recipient can accept, and cannot rewrite the sender's note.
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
update public.companion_requests set status='accepted' where id='valid';
do $$ begin
  begin
    update public.companion_requests set note='rewritten' where id='valid';
    raise exception 'FAIL recipient rewrote sender note';
  exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
insert into public.companion_requests (id,post_id,requester_id,recipient_id) values
 ('pending-before-block','identity-post','10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002');
reset role;

-- Incoming block must also prevent inserts; the client cannot read this block.
insert into public.companion_blocks(blocker_id,blocked_id) values
 ('10000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001');
set local role authenticated;
do $$ begin
  begin
    insert into public.companion_requests (id,post_id,requester_id,recipient_id) values
     ('blocked','identity-post','10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002');
    raise exception 'FAIL incoming block bypassed';
  exception when insufficient_privilege then null; end;
  begin
    update public.companion_requests set note='new contact' where id='pending-before-block';
    raise exception 'FAIL sender edited note after block';
  exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
do $$ begin
  begin
    update public.companion_requests set status='accepted' where id='pending-before-block';
    raise exception 'FAIL recipient accepted after block';
  exception when insufficient_privilege then null; end;
end $$;
-- A recipient may still safely decline after blocking.
update public.companion_requests set status='declined' where id='pending-before-block';
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
reset role;
delete from public.companion_blocks where blocker_id='10000000-0000-0000-0000-000000000002';
insert into public.companion_blocks(blocker_id,blocked_id) values
 ('10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002');
set local role authenticated;
do $$ begin
  begin
    insert into public.companion_requests (id,post_id,requester_id,recipient_id) values
     ('blocked-out','identity-post','10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002');
    raise exception 'FAIL outgoing block bypassed';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
delete from public.companion_blocks where blocker_id='10000000-0000-0000-0000-000000000001';

-- Each mutable eligibility condition is checked by the same direct insert.
do $$ declare field text; begin
  foreach field in array array['hidden','deleted','low-trust'] loop
    update public.companion_profiles set visibility=case when field='hidden' then 'off' else 'itinerary_only' end,
      reporter_weight=case when field='low-trust' then 0.1 else 1 end where id='identity-author';
    update public.companion_posts set is_deleted=(field='deleted') where id='identity-post';
    set local role authenticated;
    begin
      insert into public.companion_requests (id,post_id,requester_id,recipient_id) values
       ('ineligible-' || field,'identity-post','10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002');
      raise exception 'FAIL % post allowed',field;
    exception when insufficient_privilege then null; end;
    reset role;
  end loop;
end $$;
rollback;
select 'PASS direct inserts, RLS requester, immutable identity, both block directions and hidden/deleted/low-trust targets' as result;
