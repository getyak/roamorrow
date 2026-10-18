-- Roamorrow web launch: initialize the existing web schema alongside native sync.
-- All four table names were absent from the target project before this migration.
-- Sources below preserve the approved row shapes, constraints and RLS policies.
-- No native table, auth identity, existing row or paid resource is modified.
-- Seed data is deliberately not loaded by this migration.

begin;
set local search_path = public, extensions;

-- Source: packages/data/migrations/0001_initial.sql
-- 0001_initial.sql
-- Initial schema for Solo Compass.
--
-- Requires PostGIS extension (enable in Supabase dashboard:
--   Database → Extensions → postgis)

-- ─── Extensions ────────────────────────────────────────────────────────────────
create extension if not exists postgis;

-- ─── Users ─────────────────────────────────────────────────────────────────────
-- Minimal — no real names, no email required at Phase 2.
-- Telegram/anonymous flows use a generated handle only.
create table if not exists users (
  id          uuid primary key default gen_random_uuid(),
  handle      text not null unique,          -- e.g. "wanderer_42" — never a real name
  created_at  timestamptz not null default now()
);

-- ─── Experiences ───────────────────────────────────────────────────────────────
-- Mirrors Experience interface in packages/core/src/experience.ts.
-- Scalar fields are flat columns; nested/array fields are JSONB.
create table if not exists experiences (
  id                  text primary key,      -- "exp_cmi_suan_dok_sunset"
  title               text not null,
  one_liner           text not null,
  why_it_matters      text not null,
  category            text not null check (category in (
                        'culture','nature','food','coffee',
                        'work','wellness','nightlife','hidden'
                      )),

  -- Location — PostGIS geography for accurate distance queries
  location            geography(Point, 4326) not null,
  city_code           text not null,
  address_hint        text,
  place_name_local    text,
  place_name_romanized text,

  -- Time windows: [{startHour, endHour, dayOfWeek?, season?, note?}]
  best_times          jsonb not null default '[]',

  -- Duration range in minutes
  duration_min        integer not null,
  duration_max        integer not null,

  -- How-to steps: [{order, text}]
  how_to              jsonb not null default '[]',

  -- Real inconveniences: [{category, text}]
  real_inconveniences jsonb not null default '[]',

  -- Solo score: {overall, breakdown:{...}, hint?, basedOnCount}
  solo_score          jsonb not null,

  -- Sources: [{type, url?, attribution?, verifiedAt}]
  sources             jsonb not null default '[]',

  -- Confidence: {level, lastVerifiedAt, reason, signals:{...}}
  confidence          jsonb not null,

  -- Nearby experience IDs (expanded by recommendation engine on demand)
  nearby_experience_ids text[] not null default '{}',

  -- Aggregate stats — denormalised, updated by background job
  completion_count    integer not null default 0,
  average_rating      numeric(3,1) not null default 0,
  last_completed_at   timestamptz,

  status              text not null default 'candidate' check (status in (
                        'candidate','active','stale','retired'
                      )),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

-- GiST index on geography column — required for ST_DWithin to be fast
create index if not exists experiences_location_gist
  on experiences using gist (location);

-- Btree indexes for common filter queries
create index if not exists experiences_city_code_idx   on experiences (city_code);
create index if not exists experiences_category_idx    on experiences (category);
create index if not exists experiences_status_idx      on experiences (status);

-- ─── Completions ───────────────────────────────────────────────────────────────
-- A user marking an experience as done.
create table if not exists completions (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references users (id) on delete cascade,
  experience_id   text not null references experiences (id) on delete cascade,
  completed_at    timestamptz not null default now(),
  rating          integer check (rating between 1 and 5),
  note            text,                    -- optional short voice-to-text note
  unique (user_id, experience_id)          -- one completion record per pair
);

create index if not exists completions_user_id_idx        on completions (user_id);
create index if not exists completions_experience_id_idx  on completions (experience_id);

-- ─── Row Level Security ─────────────────────────────────────────────────────────
alter table users       enable row level security;
alter table experiences enable row level security;
alter table completions enable row level security;

-- Experiences: everyone can read active ones; only service role can write
create policy "experiences_public_read" on experiences
  for select using (status = 'active');

-- Completions: users see only their own
create policy "completions_own_read" on completions
  for select using (user_id = auth.uid()::uuid);

create policy "completions_own_insert" on completions
  for insert with check (user_id = auth.uid()::uuid);

create policy "completions_own_delete" on completions
  for delete using (user_id = auth.uid()::uuid);

-- Users: each user can read their own row; insert handled by auth trigger
create policy "users_own_read" on users
  for select using (id = auth.uid()::uuid);

-- ─── Helper: auto-update updated_at ───────────────────────────────────────────
create or replace function public.sc_web_set_updated_at()
returns trigger language plpgsql set search_path = public as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger experiences_updated_at
  before update on experiences
  for each row execute function public.sc_web_set_updated_at();


-- Source: packages/data/migrations/0002_anon_completions.sql
-- 0002_anon_completions.sql
-- Phase 2 web check-in flow uses opaque cookie IDs, not Supabase auth.
-- The web API routes call this with the service-role client, which bypasses
-- RLS — but the existing policies are auth.uid()-based and would block any
-- direct anon-key writes. Add an index on the synthetic handle to make
-- per-cookie upserts fast, and document the boundary with a comment.

-- ─── Anonymous user lookups by handle ──────────────────────────────────────────
-- handle is already UNIQUE (see 0001), but explicit index makes lookups
-- by `handle = 'anon_xxx'` an obvious O(1) plan.
create index if not exists users_handle_idx on users (handle);

-- ─── Completion freshness index ────────────────────────────────────────────────
-- Used by /api confidence-lift queries: "how many completions in the last 30d
-- for this experience?"
create index if not exists completions_experience_completed_at_idx
  on completions (experience_id, completed_at desc);

-- ─── Documentation ─────────────────────────────────────────────────────────────
comment on table completions is
  'One row per (user, experience). Anonymous web users carry an opaque cookie id — the user row is created on first checkin with handle = ''anon_<short>''. Completions inserts from the web are performed by the service-role client; RLS therefore does not block them. Telegram/auth flows continue to use auth.uid()-bound policies.';


-- Source: packages/data/migrations/0003_traffic_pings.sql
-- 0003_traffic_pings.sql
-- Passive anonymous GPS traffic. One row per (experience, visitor).
-- Conflict on the composite PK updates pinged_at so each visitor is counted
-- only once per experience in any given 7-day window query.
--
-- anon_id is a SHA-256 hex of (ip:ua:experience_id) — non-reversible,
-- scoped to a single experience so it cannot be used to correlate across rows.

CREATE TABLE IF NOT EXISTS traffic_pings (
  experience_id TEXT NOT NULL REFERENCES experiences(id) ON DELETE CASCADE,
  anon_id       TEXT NOT NULL,
  pinged_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (experience_id, anon_id)
);

CREATE INDEX IF NOT EXISTS traffic_pings_experience_id_pinged_at
  ON traffic_pings(experience_id, pinged_at DESC);


-- Traffic hashes and timestamps are internal; only the server may access them.
-- The original standalone traffic migration predates this production boundary.
alter table public.traffic_pings enable row level security;
revoke all on table public.traffic_pings from anon, authenticated;
grant all on table public.traffic_pings to service_role;
revoke all on function public.sc_web_set_updated_at() from public, anon, authenticated;

notify pgrst, 'reload schema';
commit;
