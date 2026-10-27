# GET-254 — Map-first Web UI

Scope: marketing (`/`, `/zh`) and `/app` in `getyak/roamorrow`.
Baseline: `145b5ec6247a466d41d0816d365d5f530330264e`.
Date: 2026-10-26 (Asia/Shanghai).

## Result

The default map workspace exposes up to five existing Experience cards rather
than a collapsed list teaser. Cards keep the complete verb title, place, evidence
status and an explicitly estimated walk from the map center. A card opens details
with a persistent **Get walking directions** action. The traveler chooses their
origin in Google Maps; this Web app does not fabricate a route or arrival time.

Ask is optional, retains its typed draft and stops voice capture when hidden.
The expanded experience list and footprint remain available. Loading, offline,
empty, error/retry, unavailable-map and denied-location states stay visible.
A missing score is not rendered as zero. Sample data is labeled in both the list
and detail, separate from live results.

Marketing and `/app` use the same teal interaction roles on cream/paper surfaces.
Ritual/iPhone concepts are in a closed secondary disclosure labeled **Preview**.
The hero illustration contains no invented rating, freshness, travel-time or
opening-time assertions. Marketing primary buttons grow with wrapped labels.

Google Maps uses the documented [Maps URLs directions handoff](https://developers.google.com/maps/documentation/urls/get-started#directions):
GeoJSON `[longitude, latitude]` is converted to the URL's `latitude,longitude`,
with `api=1` and `travelmode=walking`. No origin or credential is sent in the URL.

## Local verification

- Web TypeScript check and optimized production build passed.
- Web unit tests: **106 passed / 16 files**. Navigation regressions cover coordinate
  order, invalid coordinates, unknown estimates and unrated scores.
- Production-package browser tests: **13 passed**, one worker, no retries/skips.
  They cover 1280/390/320, dark mode, reduced motion, keyboard open/Escape/focus
  return, touch handoff, 44px navigation action, long titles, 200% text including
  newly mounted details, and 200% marketing/map-header actions. Recovery cases
  include loading, error/retry, empty, reload, offline, location refusal, retained
  Ask draft, desktop repeated submissions and footprint-to-Ask navigation.
- The navigation popup is intercepted at the test boundary. This proves the
  selected-coordinate handoff, not an external route result.
- Primary button contrast: **5.73:1 light / 9.71:1 dark**. Mapbox zoom controls are
  set to 44×44; live Mapbox tiles and WebGL markers were not exercised.
- No iOS Simulator or new paid model/map resource was used.

Machine-readable scenarios, build ID and measured automation timings are in
[local-validation.json](evidence/get-254-map-first-ui/local-validation.json).
These are automation timings, not a human comprehension or ten-second usability
study. No mother/aunt participant test has been performed.

The same baseline local fixture generator (five samples, unchanged coordinates,
ranking and content) is used for the before/after app screenshots at 1280×844
and 390×844. Other positive-state screenshots use explicit test fixtures.
They are not evidence of production data availability.

| Surface         | Before                                                          | After                                                     |
| --------------- | --------------------------------------------------------------- | --------------------------------------------------------- |
| App, 390        | [before](evidence/get-254-map-first-ui/before-app-390.png)      | [after](evidence/get-254-map-first-ui/after-app-390.png)  |
| App, 1280       | [before](evidence/get-254-map-first-ui/before-app-1280.png)     | [after](evidence/get-254-map-first-ui/after-app-1280.png) |
| Marketing, 390  | [before](evidence/get-254-map-first-ui/before-landing-390.png)  | [after](evidence/get-254-map-first-ui/landing-390.png)    |
| Marketing, 1280 | [before](evidence/get-254-map-first-ui/before-landing-1280.png) | [after](evidence/get-254-map-first-ui/landing-1280.png)   |

## Production acceptance still required

Before this change, `roamorrow.com` resolved to the baseline SHA above (Vercel
`dpl_Hir7a1CPoLpPgeBcE647qT3LVnGG`). Both public nearby queries centered on
`[98.9853, 18.7883]` returned **0 results** at radii **1500m and 10000m**.
The response did not identify a data source. This change does not seed records,
import private data, or replace an empty production result with sample content.

After merging, separately verify the exact production SHA, marketing accent,
closed Preview disclosure, real `/app` state and recovery. A positive flow through
an actual production Experience remains unverified while no records are returned.
Keep GET-254 open if that acceptance requirement cannot be met. CI, a merged PR,
a READY deployment and fixture tests alone do not complete this issue.
