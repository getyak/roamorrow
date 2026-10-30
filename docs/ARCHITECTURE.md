# Architecture

The iOS companion and legacy map conversation share device-session, context,
tool-journal recovery and memory contracts. See the [unified Agent runtime
design](architecture/unified-agent-runtime.md) for execution guarantees,
compatibility and the boundary around interrupted side effects. UI history
adapters stay separate; this does not join account Harness context or the map MCP.

The Go service in `apps/api` also exposes the email/context Harness and its
authenticated MCP tools. The native account page uses a separate verified
Supabase session; Harness profiles and encrypted Google tokens live in a private
PostgreSQL schema. See the [Harness architecture](architecture/deepseek-onboarding-harness.md),
[runtime guide](development/harness-backend.md) and
[acceptance record](qa/harness-ios-20261024/README.md) for the exact boundary and pending validation.

## Layered diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                          apps/                                    │
│   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│   │   web/       │  │   ios/       │  │   bot/       │           │
│   │   Next.js    │  │   SwiftUI    │  │   Telegraf   │           │
│   └──────────────┘  └──────────────┘  └──────────────┘           │
│         │                  │                   │                  │
│         └────────┬─────────┴─────────┬─────────┘                  │
└──────────────────┼───────────────────┼────────────────────────────┘
                   │                   │
┌──────────────────▼───────────────────▼────────────────────────────┐
│                       packages/                                   │
│   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│   │   ai/        │  │   data/      │  │   ui/        │           │
│   │  prompts,    │  │  ingestion,  │  │  design      │           │
│   │  ranking,    │  │  storage,    │  │  tokens      │           │
│   │  DeepSeek    │  │  queries     │  │  (web only)  │           │
│   └──────┬───────┘  └──────┬───────┘  └──────────────┘           │
│          │                  │                                     │
│          └────────┬─────────┘                                     │
│                   ▼                                               │
│   ┌──────────────────────────┐                                    │
│   │   core/                  │                                    │
│   │   domain types           │                                    │
│   │   Experience, Confidence │                                    │
│   │   geo primitives         │                                    │
│   │   ZERO runtime deps      │                                    │
│   └──────────────────────────┘                                    │
└───────────────────────────────────────────────────────────────────┘
                   │                   │
┌──────────────────▼───────────────────▼────────────────────────────┐
│                       External services                          │
│   DeepSeek API · Mapbox · Supabase · OSM · Wikivoyage · Reddit   │
└───────────────────────────────────────────────────────────────────┘
```

## Dependency rules (enforced by review, eventually by tooling)

| Layer    | May import from | Must NOT import    |
| -------- | --------------- | ------------------ |
| `core`   | (nothing)       | anything else      |
| `ai`     | `core`          | `data`, `ui`, apps |
| `data`   | `core`          | `ai`, `ui`, apps   |
| `ui`     | `core`          | `ai`, `data`, apps |
| `apps/*` | any package     | other apps         |

The asymmetry is deliberate: `core` is the most-shared, slowest-to-change layer. `data` and `ai` are sister layers that don't talk to each other directly — they communicate via `core` types or via apps composing them.

## Why the iOS app is outside the pnpm workspace

iOS uses Swift Package Manager and Xcode project files. Mixing them into a Node monorepo is more pain than it's worth. The TypeScript `core` types are mirrored as Swift models in `apps/ios/SoloCompass/Models/`, kept in sync by:

- `scripts/check-swift-parity.ts`, run by the schema parity CI gate
- review of matching TypeScript and Swift changes

When the schema changes, the PR title must mention "schema" so the iOS dev knows to mirror.

## Data flow at runtime (Phase 2 web)

```
User opens https://roamorrow.com
  ↓
Browser geolocation: lng/lat
  ↓
[Web app]    GET /api/experiences/nearby?lng=...&lat=...
  ↓
[API route]  experiencesRepo.findNearby(coords, radius)   ← packages/data
  ↓
[Supabase]   PostGIS ST_DWithin query → 50 candidates
  ↓
[API route]  rankCandidates(candidates, userIntent)        ← packages/ai
  ↓
[DeepSeek]   Reads candidate descriptions + user voice intent
             Returns ranked list with reasons
  ↓
[Web app]    Renders ranked experiences as map markers
             User taps one → detail card shows confidence,
             real inconveniences, how-to steps
```

The API route is thin — it composes `data` + `ai` and adds nothing of its own. This way iOS can call the same route during Phase 3.
