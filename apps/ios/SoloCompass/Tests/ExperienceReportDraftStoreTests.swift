import XCTest
@testable import SoloCompass

/// Honest local report drafts (contract item 5): the report pipeline saves a
/// draft on-device, and only an explicit mail-composer `.sent` result marks it
/// sent. Share/cancel/error paths keep the draft at `savedLocally` — no
/// claimed remote submission anywhere.
@MainActor
final class ExperienceReportDraftStoreTests: XCTestCase {

    private func makeIsolatedDefaults() -> UserDefaults {
        let suite = "experience.report.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    // MARK: - Local persistence

    func testSavedDraftIsLocalAndSurvivesReopen() {
        let defaults = makeIsolatedDefaults()
        let store = ExperienceReportDraftStore(defaults: defaults)
        let draft = store.saveDraft(
            experienceId: "exp_1",
            reasonRaw: "hours_wrong",
            detail: "Closes at 17:00 now"
        )
        XCTAssertEqual(draft.status, .savedLocally, "saving must never claim the report was sent")
        XCTAssertNil(draft.sentAt)

        let reopened = ExperienceReportDraftStore(defaults: defaults)
        let readBack = reopened.latestDraft(forExperienceId: "exp_1")
        XCTAssertEqual(readBack?.id, draft.id)
        XCTAssertEqual(readBack?.detail, "Closes at 17:00 now")
        XCTAssertEqual(readBack?.reasonRaw, "hours_wrong")
        XCTAssertEqual(readBack?.status, .savedLocally)
    }

    // MARK: - Sent only on explicit acknowledgment

    func testMarkSentIsTheOnlyWayToSent() {
        let defaults = makeIsolatedDefaults()
        let store = ExperienceReportDraftStore(defaults: defaults)
        let draft = store.saveDraft(experienceId: "exp_1", reasonRaw: "moved", detail: "")

        // A cancelled / failed composition simply does nothing — the draft
        // stays saved-locally and is retained for retry.
        XCTAssertEqual(store.draft(id: draft.id)?.status, .savedLocally)

        store.markSent(id: draft.id)
        let sent = store.draft(id: draft.id)
        XCTAssertEqual(sent?.status, .sent)
        XCTAssertNotNil(sent?.sentAt)

        // Persisted honestly across reopen.
        let reopened = ExperienceReportDraftStore(defaults: defaults)
        XCTAssertEqual(reopened.draft(id: draft.id)?.status, .sent)
    }

    func testMarkSentUnknownIdIsInert() {
        let store = ExperienceReportDraftStore(defaults: makeIsolatedDefaults())
        store.markSent(id: "rpt_missing")
        XCTAssertTrue(store.drafts.isEmpty)
    }

    func testNewestDraftIsFirst() {
        let store = ExperienceReportDraftStore(defaults: makeIsolatedDefaults())
        let older = store.saveDraft(experienceId: "exp_1", reasonRaw: "moved", detail: "old",
                                   now: Date(timeIntervalSince1970: 1_000))
        let newer = store.saveDraft(experienceId: "exp_1", reasonRaw: "moved", detail: "new",
                                   now: Date(timeIntervalSince1970: 2_000))
        XCTAssertEqual(store.latestDraft(forExperienceId: "exp_1")?.id, newer.id)
        XCTAssertEqual(store.drafts.count, 2)
        XCTAssertNotEqual(older.id, newer.id)
    }

    // MARK: - Re-entry restore (review closure 6)

    func testLatestUnsentDraftSkipsSentHistory() {
        let defaults = makeIsolatedDefaults()
        let store = ExperienceReportDraftStore(defaults: defaults)
        let sent = store.saveDraft(experienceId: "exp_1", reasonRaw: "moved", detail: "old",
                                   now: Date(timeIntervalSince1970: 1_000), id: "rpt_sent")
        store.markSent(id: sent.id)
        store.saveDraft(experienceId: "exp_1", reasonRaw: "hours_wrong", detail: "pending",
                        now: Date(timeIntervalSince1970: 2_000), id: "rpt_pending")

        // A `.sent` draft is history — only the unsent one may be restored as
        // pending work.
        XCTAssertEqual(store.latestUnsentDraft(forExperienceId: "exp_1")?.id, "rpt_pending")
        XCTAssertEqual(store.latestUnsentDraft(forExperienceId: "exp_1")?.detail, "pending")
    }

    func testLatestUnsentDraftIsNilWhenAllSent() {
        let store = ExperienceReportDraftStore(defaults: makeIsolatedDefaults())
        let draft = store.saveDraft(experienceId: "exp_1", reasonRaw: "other", detail: "done")
        store.markSent(id: draft.id)
        XCTAssertNil(store.latestUnsentDraft(forExperienceId: "exp_1"),
                     "a sent draft must not be mislabeled pending")
        XCTAssertEqual(store.latestDraft(forExperienceId: "exp_1")?.status, .sent)
    }

    func testUpdateDraftKeepsIdentityAndStaysUnsent() {
        let defaults = makeIsolatedDefaults()
        let store = ExperienceReportDraftStore(defaults: defaults)
        let draft = store.saveDraft(experienceId: "exp_1", reasonRaw: "moved", detail: "first")

        store.updateDraft(id: draft.id, reasonRaw: "hours_wrong", detail: "edited")

        let updated = store.draft(id: draft.id)
        XCTAssertEqual(updated?.detail, "edited")
        XCTAssertEqual(updated?.reasonRaw, "hours_wrong")
        XCTAssertEqual(updated?.status, .savedLocally, "editing never claims a send")
        XCTAssertEqual(store.drafts.count, 1, "re-entry edits update the same draft")

        // Persisted across reopen.
        let reopened = ExperienceReportDraftStore(defaults: defaults)
        XCTAssertEqual(reopened.latestUnsentDraft(forExperienceId: "exp_1")?.detail, "edited")
    }

    func testEditingSentReportCreatesNewUnsentDraftAndKeepsReceipt() throws {
        let store = ExperienceReportDraftStore(defaults: makeIsolatedDefaults())
        let original = store.saveDraft(experienceId: "exp_1", reasonRaw: "moved", detail: "sent content")
        store.markSent(id: original.id)
        let edited = try XCTUnwrap(store.updateDraft(id: original.id, reasonRaw: "other", detail: "new content"))
        XCTAssertNotEqual(edited.id, original.id)
        XCTAssertEqual(edited.status, .savedLocally)
        XCTAssertNil(edited.sentAt)
        XCTAssertEqual(store.latestUnsentDraft(forExperienceId: "exp_1")?.id, edited.id)
        XCTAssertEqual(store.draft(id: original.id)?.detail, "sent content")
        XCTAssertEqual(store.draft(id: original.id)?.status, .sent)
    }

    // MARK: - User-controlled composition

    func testEmailCompositionAddressesSupportAndCarriesTheReport() {
        let body = ExperienceReportComposer.emailBody(
            experienceTitle: "Mekong sunset walk",
            placeName: "Chao Anouvong Park",
            cityCode: "VTE",
            reasonLabel: "Hours are wrong",
            detail: "Closes at 17:00 now"
        )
        XCTAssertTrue(body.contains("Mekong sunset walk"))
        XCTAssertTrue(body.contains("Chao Anouvong Park"))
        XCTAssertTrue(body.contains("VTE"))
        XCTAssertTrue(body.contains("Hours are wrong"))
        XCTAssertTrue(body.contains("Closes at 17:00 now"))

        let subject = ExperienceReportComposer.emailSubject(experienceTitle: "Mekong sunset walk")
        XCTAssertTrue(subject.contains("Mekong sunset walk"))

        let url = ExperienceReportComposer.mailtoURL(subject: subject, body: body)
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("cubxxw@gmail.com"), "mailto must target the confirmed support inbox")
    }

    func testEmailCompositionHandlesEmptyDetailHonestly() {
        let body = ExperienceReportComposer.emailBody(
            experienceTitle: "Place",
            placeName: nil,
            cityCode: nil,
            reasonLabel: "Other",
            detail: ""
        )
        XCTAssertTrue(body.contains(NSLocalizedString("report.email.body.noDetail", comment: "")))
        XCTAssertFalse(body.contains("Place:"), "absent fields must not be invented")
    }
}
