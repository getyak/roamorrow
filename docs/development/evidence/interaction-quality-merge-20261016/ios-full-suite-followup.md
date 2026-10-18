# iOS full-suite merge follow-up

The superseded run [38864674137](https://github.com/getyak/solo-compass/actions/runs/38864674137) built successfully and executed 1,914 tests, with 14 skips and five assertion failures. The run was cancelled when the CI-only head was pushed; its test log is diagnostic evidence, not a passing gate.

The five assertions belonged to four tests:

- `GroupConversationAutoCreateTests.testSubsequentAcceptAppendsToExistingConversation` had two count assertions that omitted the fixture’s already-confirmed member `lin`. The production implementation correctly retains all confirmed members. The test now checks exact participant sets and duplicate-free counts after each acceptance.
- `PendingCheckInBannerTests.testAutoDismissSecondsDefault` still expected six seconds, while the reviewed design intentionally uses ten seconds. The assertion now verifies the actual ten-second property. The obsolete VoiceOver test compared hard-coded six/twelve values without exercising the banner; it was removed. Runtime VoiceOver focus and timer acceptance remain explicitly unverified.
- `PrivacyAcknowledgementSheetSnapshotTest.testSubtitleLocalizedStringIsComplete` required an obsolete English phrase. It now resolves the English resource bundle explicitly and verifies the current explanation of map position and public place information. Existing Dynamic Type rendering assertions remain intact.
- `PublicAPIDocCommentTests.testAllPublicAPIsHaveDocComments` identified four undocumented declarations. Added purpose comments to `CompanionPostActionService.Action`, `ExperienceReportDraft.Status`, `ExperienceReportDraftStore.draft(id:)` and `ExperienceReportComposer.emailSubject(experienceTitle:)`.

This follow-up changes test assertions and source comments only. Product execution logic, localization resources and rendered layouts remain unchanged. Prior source fingerprints retain their original snapshot boundary; new comment bytes are not misrepresented as matching the earlier native build. The latest PR head’s full native CI remains the authoritative build/test gate. No skips or workflow requirements were added.
