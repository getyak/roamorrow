# Roamorrow Web design

## Map and experience surfaces

Mode: Operate. The map leads; nearby experiences support the choice. Ask opens explicitly.

- Paper uses the existing warm surface and ink tokens in `src/app/globals.css`, with teal reserved for actions, focus and selection.
- Karla carries utility text; Literata carries experience and field-note titles. Both include an ordinary readable fallback. The font declarations in Tailwind and CSS agree.
- The account-authorized Mapbox Light style retains its sources, roads, labels, attribution and geometry. Only background, water, landuse, landcover and building fills receive the paper palette.
- The collapsed experience rail uses at most 36dvh, with a 16px bottom margin on desktop. Horizontal overflow reveals another note; keyboard focus scrolls it into view. Expansion restores a vertical list and the footprint.
- A one-pixel rule separates adjacent notes. No nested card backgrounds or decorative category emoji. Experience details retain confidence, source links, real inconveniences and walking directions.
- Sample and non-live availability remain visible in the rail header. Errors, permission denial and unknown values retain their existing recovery paths.
- Ask keeps its draft, stops hidden recording and scrolls above the rail at intermediate widths.

## Ritual Preview

Mode: Read. The existing bilingual Preview is a secondary disclosure below the real map action. Its paper divider, serif summary and reversible fold reveal the existing illustrations. It opens with a short clip reveal and stays static with reduced motion. Preview copy never implies these concepts are active subscription benefits.

## Verification

Run the map-first browser suite on desktop, 320/390px phones, light/dark and 200% text. Review 768px Ask with fallback messages. Run the Impeccable detector on changed Web sources, and inspect actual screenshots independently of its result.
