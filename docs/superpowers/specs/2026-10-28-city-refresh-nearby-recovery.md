# City refresh and nearby lookup recovery

The approved remediation has two separate outcomes: restore the existing bounded city-brief refresh without exposing credentials, and make nearby public-experience queries complete before applying their result limit. The production cause of Chiang Mai's empty list must remain separate from the isolated query defect.

## Evidence and boundaries

The 2026-10-28 preflight found a missing GitHub `CITY_BRIEF_CRON_SECRET`. Follow-up metadata from the locally linked Supabase project also found no deployed `compile-city-brief`, no backend cron secret, and no `TAVILY_API_KEY`. The root environment and linked project agree. Anonymous reads from this local linked service returned zero active experiences, including Chiang Mai; this service is not yet verified as production. Therefore those counts must not be presented as production evidence. The production Web project's identity must be confirmed before configuration writes.

Only shared city data and public places are in scope. Never inspect private itineraries, conversations or user records. Do not import demonstration seed records or invent experience facts. Native views and map layouts are out of scope. Preserve the original dirty checkout and use an exclusive worktree.

## Approach

Use a stable, security-invoker PostGIS RPC for the nearby lookup. Apply active status, optional category/city and exact geographic radius in PostgreSQL, order by measured distance with an ID tie break, then apply the existing result limit. Return explicit GeoJSON coordinates to preserve the domain contract. Use the existing geography GiST index. A client-side paginated global scan was rejected because it remains unbounded and performs geographic filtering too late. JSON bounding-box filters alone were rejected because they cannot establish nearest-first completeness and require special pole/dateline handling.

Keep the city-brief guard. Validate the complete per-target response, rather than treating an HTTP 200 carrying failed outcomes as success. Check city/target/force input before network or provider work. Existing cooldown remains active. A successful skipped cooldown must be distinguishable from an actual refresh.

Recover an existing cron credential if one is found. If none exists, configuration must wait for the root's concrete approval of the consumer inventory and rollback plan. A new dedicated cron secret would be generated only in memory and delivered through protected standard input to the backend and GitHub, without changing service-role or provider credentials. Deploy the current function only to the confirmed existing service, use the already authorized Tavily configuration, then execute one bounded refresh with `force=false`.

## Completion evidence

A real database regression must show that more than 120 earlier unrelated active rows cannot hide a nearby row. SQL verification covers radius, distance order, equal-distance stability, city/category/status isolation, public read privileges, no public write grant, and GeoJSON shape. Repository tests use the real Supabase client with a controlled HTTP boundary. Normal CI and independent review precede merge. Record database/function/Web deployment revisions separately, and verify the real Chiang Mai choose/detail/walking-navigation journey only if genuine public experiences exist. Zero results, provider failures and missing configuration remain explicit incomplete outcomes.

## Primary references

- https://supabase.com/docs/guides/database/extensions/postgis
- https://postgis.net/docs/ST_DWithin.html
- https://supabase.com/docs/reference/javascript/rpc
