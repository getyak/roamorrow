# @solo-compass/data

Data layer: ingestion, storage, query.

## Responsibilities

- **Ingestion** from open sources (OSM via Overpass, Wikivoyage MediaWiki API, Reddit, YouTube transcripts)
- **Schema** for Postgres + PostGIS (Supabase migration files)
- **Repositories**: `ExperienceRepo`, `UserRepo`, `CompletionRepo` — typed query interfaces
- **Cold-start seeders** that populate a new city to ~50 experiences

## What does NOT live here

- AI generation logic (that's `packages/ai`)
- Domain types (those are `packages/core`)

## Running migrations locally

**Prerequisites**: Supabase CLI installed (`brew install supabase/tap/supabase`) and a project configured.

```bash
# Option A — against a local Supabase instance (recommended for dev)
supabase start                        # starts local Postgres + PostGIS
supabase db push                      # applies migrations/0001_initial.sql

# Option B — directly against your hosted Supabase project
psql "$SUPABASE_DB_URL" -f packages/data/migrations/0001_initial.sql
```

**Required env vars** (copy from `.env.example`):

| Variable                    | Purpose                                                          |
| --------------------------- | ---------------------------------------------------------------- |
| `SUPABASE_URL`              | Project API URL (`https://xxxxx.supabase.co`)                    |
| `SUPABASE_KEY`              | Anon key — used by `createAnonClient()`, subject to RLS          |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role key — used by `createServiceClient()`, bypasses RLS |

**PostGIS**: Must be enabled before running the migration.
Dashboard → Database → Extensions → search "postgis" → Enable.

## Client usage

```ts
import { createAnonClient, createServiceClient, rowToExperience } from "@solo-compass/data";

// In API route handlers (RLS applied):
const client = createAnonClient();
const { data } = await client.from("experiences").select("*").eq("status", "active");

// In server-side seed scripts (bypasses RLS):
const admin = createServiceClient();
```

## Cold-start workflow (target)

```bash
# 1. Pull all OSM POI data for a city (free, offline)
pnpm tsx scripts/ingest-osm.ts --city cmi

# 2. Pull Wikivoyage article + extract listings
pnpm tsx scripts/ingest-wikivoyage.ts --city cmi

# 3. Pull Reddit threads matching city + relevant subs
pnpm tsx scripts/ingest-reddit.ts --city cmi

# 4. Run AI structuring pipeline → Experience candidates
pnpm tsx scripts/ai-structure-experiences.ts --city cmi --target 50

# 5. Field-verify top 20 (manual)
# 6. Push to Supabase
pnpm tsx scripts/seed-supabase.ts --city cmi
```

## Nearby lookup rollout

Web can merge before the additive `0020_nearby_experiences.sql` reaches an existing database. A successful new RPC always owns spatial filtering and ordering before the limit. Only HTTP 404 with PostgREST `PGRST202` explicitly naming `public.find_nearby_experiences` uses the previous bounded, RLS-protected table lookup. Permission failures, database errors, network failures and other missing functions still fail. [PostgREST documents PGRST202](https://docs.postgrest.org/en/v16/references/errors.html) as a missing or stale function signature.

The compatibility path retains the old global-row cap and can still omit nearby rows; merging alone does not activate the spatial correction. Confirm the actual production database, review and apply only migration 0020, and verify the RPC there before claiming the nearby journey repaired. This change does not activate cron credentials, deploy the compiler or seed production data.
