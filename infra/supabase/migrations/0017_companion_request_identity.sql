-- A post ID is not a recipient ID. Enforce this even for direct PostgREST
-- callers, which can bypass the discovery action Edge Function.
begin;

create or replace function public.sc_guard_companion_request_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  eligible boolean;
begin
  if TG_OP = 'UPDATE' then
    if NEW.id is distinct from OLD.id
      or NEW.post_id is distinct from OLD.post_id
      or NEW.requester_id is distinct from OLD.requester_id
      or NEW.recipient_id is distinct from OLD.recipient_id then
      raise exception 'request identity cannot change' using errcode = '42501';
    end if;
    if NEW.status is distinct from OLD.status and not (
      OLD.status = 'pending' and (
        (auth.uid() = OLD.requester_id and NEW.status = 'withdrawn')
        or (auth.uid() = OLD.recipient_id and NEW.status in ('accepted','declined'))
      )
    ) then
      raise exception 'request transition unavailable' using errcode = '42501';
    end if;
    if NEW.note is distinct from OLD.note and not (
      OLD.status = 'pending' and auth.uid() = OLD.requester_id
    ) then
      raise exception 'request note cannot change' using errcode = '42501';
    end if;
    -- Blocking ends new contact. Safe exits (withdraw/decline) remain allowed.
    if (NEW.note is distinct from OLD.note or (NEW.status is distinct from OLD.status and NEW.status = 'accepted'))
      and exists (
        select 1 from public.companion_blocks b
        where (b.blocker_id = OLD.requester_id and b.blocked_id = OLD.recipient_id)
           or (b.blocker_id = OLD.recipient_id and b.blocked_id = OLD.requester_id)
      ) then
      raise exception 'request contact unavailable' using errcode = '42501';
    end if;
    return NEW;
  end if;

  if NEW.status <> 'pending' then
    raise exception 'new request must await recipient confirmation' using errcode = '42501';
  end if;

  select exists (
    select 1
    from public.companion_posts p
    join public.companion_profiles cp on cp.user_id = p.author_id
    where p.id = NEW.post_id
      and p.author_id = NEW.recipient_id
      and p.author_id <> NEW.requester_id
      and not p.is_deleted
      and cp.visibility <> 'off'
      and cp.reporter_weight >= 0.3
      and not exists (
        select 1 from public.companion_blocks b
        where (b.blocker_id = NEW.requester_id and b.blocked_id = p.author_id)
           or (b.blocker_id = p.author_id and b.blocked_id = NEW.requester_id)
      )
  ) into eligible;
  if not eligible then
    -- Same error for mismatched, hidden, absent and blocked targets.
    raise exception 'request unavailable' using errcode = '42501';
  end if;
  return NEW;
end;
$$;

revoke all on function public.sc_guard_companion_request_identity() from public;
drop trigger if exists companion_request_identity_guard on public.companion_requests;
create trigger companion_request_identity_guard
  before insert or update on public.companion_requests
  for each row execute function public.sc_guard_companion_request_identity();

commit;
