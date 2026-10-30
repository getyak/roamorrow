# Design and motion review

## Direction

The film follows one Tokyo trip through next action, its sidebar, a sourced time conflict, spending confirmation, preference confirmation, and lock-screen presence. Alternative stories were source-to-action ingestion and before/after offline recovery. This is a concept film, not a claim that native system integrations have shipped.

## Checks and fixes

- HyperFrames static lint, browser runtime, layout, timeline and audio checks pass with browser audits executed. Intentional modal occlusion is marked narrowly; hidden map-home content under the sidebar is excluded from reading audits.
- Independent design review found two P1 issues: confirmed flight status did not propagate to the timeline; important footnotes/archive entry touched the bottom safe area. Both were repaired and rechecked against final boards. No P0/P1 remained in that directed review.
- Browser interaction checks covered sidebar routing and focus, budget vs planned spend, payment preview and explicit simulation result, sourced truth confirmation and homepage reminder removal, memory promotion, and deleting a demo preference. These operate only on fixtures, without real travel/payment/location/model APIs.
- Final film checks may flag low contrast on the intentionally dimmed payment preview behind the modal. That content is not the active reading target. Active modal explanation lines were darkened and visually inspected in the decoded frame. Key action/amount text is also repeated at large size on the left.
- Craft warnings: native screen metadata is smaller than the 28 px video text floor, while the required concepts are stated in large editorial text. The full 390 pt app screen is retained for context, and separate design boards support detailed reading. Some holds intentionally leave enough time to read a UI state. Fast transitional lines are not action instructions.
- Local fonts load by PostScript name. The compiler still emits an alias mapping warning for custom family names; a cross-machine render needs those system fonts or a licensed replacement. No system font files are redistributed.

## Evidence limits

This is HTML design and motion work. No SwiftUI build, Simulator, real iPhone, VoiceOver, live ActivityKit, Wallet, offline persistence, airline API or payment execution was tested. Final audio measured 46 seconds, stereo 48 kHz, −24.5 LUFS integrated, −8.3 dBTP true peak, and no clipping; it was not audited by listening. Weakest shot: dense native metadata inside the full-phone money preview; a future vertical cut could keep the confirmation card larger throughout.

Use CREDITS.md when sharing or publishing, including the music attribution. This review does not approve the proposed native redesign for implementation.

## Delivery render

Final 1920×1080 H.264/AAC output: 46.000 seconds at 30 fps. A first export exposed a renderer-only relative-mask URL rewrite; source Lucide SVGs were then embedded as data URIs. The corrected export has no missing-asset 404s, and decoded home/payment frames show their icons. The delivery check passes with 0 layout/runtime errors; warnings on inactive dimmed payment content and native-size metadata remain documented above.
