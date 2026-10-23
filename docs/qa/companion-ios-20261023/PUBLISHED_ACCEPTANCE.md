# Continuous Companion iOS — published delivery notes

The shipping iOS entry now includes the approved C character, semantic reply bubbles, local photo/audio/file/place attachments, compact map filters and a folding task panel. Existing navigation, map camera, city selection, favorites and unsent drafts are retained. The character animates only during actual work and respects visibility, scene state, Reduce Motion and Low Power Mode.

This is an implementation branch for review. It is not a claim of complete accessibility or release acceptance.

## Validation

The original simulator delivery passed 101 affected native unit tests and 20 distinct native interaction/settings cases across batches on iPhone 17 Pro, iOS 26.4. Those cases covered real model responses, semantic groups, cancellation/retry, whole-message quoting, media pickers and recording/playback, city/map/favorite/draft preservation, relaunch, denied permissions, maximum Dynamic Type, software keyboard, dark mode and real accessibility Settings toggles.

The last unfiltered seven-category accessibility audit did not pass. Two larger-type text-clipping warnings need targeted visible-position verification; one contrast warning was reported for content entirely outside the visible scroll viewport. The original reports remain available locally. Full VoiceOver gestures, rotor and reading order are deferred until a physical iPhone is connected. Whole-device offline behavior, on-device transcription and physical camera capture also remain unverified. Local media persistence does not establish model understanding of image/audio originals.

Publish review additionally identified an unavailable save-retry path after a response arrived and its final write failed. The recovery change retains the original response and retries its save without running the model or tools again. A targeted regression exercises continued write failure, restored storage, original message/response identity and restart recovery. The final affected suite passed 102 tests with no failures or skips. Two native smoke tests then passed against the rebuilt App, including an actual model response and restoration of the original draft. The independent Store recovery probe passed. Existing records and draft contents matched the pre-publish snapshot, and the installed executable matched this final build. See [publish-validation.json](publish-validation.json) for the aggregate result.

Project generation explicitly excludes local Secrets.plist and seed backup files. Runtime credentials continue to use the existing generated/runtime configuration path; local credential files are neither staged nor deleted.

## Public and local evidence

The four manual UI test source files referenced by `project.yml` are included in this repository under `round2` through `round5`. They are scoped acceptance harnesses and require suitable test state; publishing them does not enable automatic live-model UI execution in CI. The affected regression scheme uses deterministic unit tests.

Approved character assets and the interactive design proposal are in [the C design directory](../../design/travel-companion-character-20261023/README.md). Its HTML controls simulate states and are not native acceptance evidence.

Original chat snapshots, user preferences, raw screenshots/AX trees, recordings, full logs and result bundles remain local. They are deliberately excluded from this public commit. The local `round5/acceptance.md` and evidence gallery remain the detailed handoff; a fresh public checkout does not contain those private artifacts.
