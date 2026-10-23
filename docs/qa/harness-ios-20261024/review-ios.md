# Native account review

Independent read-only reviewer: `review_native_account`, 2026-10-24. This is
source-level review, not a native build or runtime acceptance result.

Confirmed issues and resolution:

- P1: delayed account-A profile could survive sign-out/account replacement.
  Requests now bind identity and account generation, recheck after network I/O,
  and reject a profile whose owner differs from the authenticated identity.
- P1: injecting private profile context into the device-wide conversation would
  persist derived text and later resend it under another account. The injection
  was removed. Private suggestions use the dedicated stateless server endpoint
  and transient account-page state, with no local chat-journal writes.
- P1: legacy anonymous signup/refresh could replace a new shared email session.
  Harness email authentication now has a separate Keychain account; legacy sync
  and its device-local outbox are not migrated into a different email identity.
- P2: after requesting an OTP, there was no recovery path for the wrong address,
  missing mail or expired code. Change-email, explicit resend with a UI cooldown,
  and a switch to existing-account password sign-in are available.

The reviewer rechecked these corrections and reported no remaining confirmed
P0/P1. Synthetic tests cover delayed refresh/profile after sign-out, verified
session restoration and rejected-code recovery. Test execution remains pending
until a native result bundle is recorded separately.
