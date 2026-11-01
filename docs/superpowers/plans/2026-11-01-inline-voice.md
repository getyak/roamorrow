# Inline Voice Composer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Capture, send or convert a voice message directly in the existing chat input.

**Architecture:** Reuse CompanionAudioSession and CompanionAudioTranscriber. CompanionComposer owns presentation/cancellation; CompanionHomeStore atomically replaces a staged recording with editable draft text. Keep live samples observed only by a small recording view.

**Tech Stack:** SwiftUI, AVFoundation, Speech, XCTest, existing macOS host regressions.

**Spec:** docs/superpowers/specs/2026-11-01-inline-voice-design.md

## Global Constraints

- iOS 17.0+, Swift 5.10, complete concurrency checking; no new dependencies.
- English/Simplified Chinese localization, 44pt controls and Reduce Motion support.
- Only explicit send submits; interruption and failed conversion retain original audio.

## Review Focus

- Disk write failure must retain the previous draft and original recording.
- Duplicate/empty/stale transcription must not duplicate text or remove unrelated media.
- Very short captures must not accidentally submit a previously existing draft.
- Permission/cancellation/background races must stop capture and ignore late results.
- Live sample changes must not invalidate the full conversation or animate with Reduce Motion.

### Task 1: Implement and validate inline voice

**Files:** CompanionComposer.swift; CompanionMediaService.swift; CompanionHomeStore.swift; English and Chinese Localizable.strings; CompanionHomeMediaTests.swift; scripts/qa/companion-chat-host.swift.

**Interfaces:** `CompanionHomeStore.useVoiceTranscript(id: UUID, text: String) -> Bool`; observable read-only `CompanionAudioSession.recordingSamples: [Float]`; existing `finishRecording()`, `stageAttachment(_:)`, `send()` and `transcribe(_:)`.

- [ ] Add store regressions for conversion/restart, preserved draft/other media, empty/missing/duplicate result and failed persistence. Run host checks first and observe the missing feature.
- [ ] Implement transactional conversion and run host checks until green.
- [ ] Replace the extra recording row with an inline recording view, real waveform, duration, pause/transcribe and direct send. Show and cancel pending permission/transcription; protect tasks with operation identity and preserve capture on lifecycle changes.
- [ ] Run audio-ownership host checks, localization and lint checks; build and run affected XCTest cases through dev-ios-session using one registered artifact root.
- [ ] Verify actual recording controls and small-width/large-text layout in Simulator. Save visual evidence; record real speech/device limitations.
- [ ] Obtain an independent review, fix confirmed serious findings, then create the GET-354 PR, wait for current-head gates and merge. Read back release/issue state and clean only owned resources.

## Execution Ledger

Pre-flight: one task; existing audio ownership and durable outbox contracts remain authoritative. Native inline execution follows the user's autonomous-work instruction; independent review is required by AGENTS.md for lifecycle-sensitive changes.
