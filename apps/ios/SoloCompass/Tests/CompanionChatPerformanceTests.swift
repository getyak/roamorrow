import CoreGraphics
import XCTest
import Observation
@testable import SoloCompass

@MainActor
final class CompanionChatPerformanceTests: XCTestCase {
    private final class ObservationProbe: @unchecked Sendable {
        private let lock = NSLock()
        private var marked = false
        func mark() { lock.lock(); marked = true; lock.unlock() }
        var wasMarked: Bool { lock.lock(); defer { lock.unlock() }; return marked }
    }
    private final class Gate: @unchecked Sendable {
        let started = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        private let lock = NSLock()
        private var used = false
        func encodeOnce() {
            lock.lock()
            let wait = !used
            used = true
            lock.unlock()
            if wait { started.signal(); release.wait() }
        }
        private func waitSynchronously() -> Bool { started.wait(timeout: .now() + 5) == .success }
        func entered() async -> Bool { await Task.detached { self.waitSynchronously() }.value }
    }

    private final class Agent: CompanionHomeResponding {
        var calls = 0
        var beforeReply: (() -> Void)?
        func respond(to entries: [CompanionHomeEntry]) async throws -> CompanionHomeAgentResult {
            calls += 1
            beforeReply?()
            return .init(text: "A controlled reply")
        }
    }

    private struct Fixture: Codable {
        var version = 1
        var entries: [CompanionHomeEntry]
        var composerDraft = ""
        var people: [CompanionHomePerson] = []
        var selectedPeopleIDs: Set<String> = []
        var invites: [CompanionHomeInvite] = []
    }

    private func location() -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("chat-perf-tests-\(UUID())")
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder.appendingPathComponent("v1.json")
    }

    func testTypingDoesNotRewriteFiveThousandMessagesAndRestoresDraft() throws {
        let url = location()
        let messages = (0..<5_000).map { index in
            CompanionHomeEntry(role: .user, text: "History \(index)",
                createdAt: Date(timeIntervalSince1970: Double(index)), status: .delivered)
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let before = try JSONEncoder().encode(Fixture(entries: messages))
        try before.write(to: url)
        let store = CompanionHomeStore(url: url)
        let projection = store.timelineProjection.change.revision
        store.composerDraft = "新草稿 🧭\nsecond line"
        store.noteReadingPosition(anchorID: "message:\(messages[30].id)", followsLatest: false, hasUnread: false)
        XCTAssertEqual(try Data(contentsOf: url), before)
        XCTAssertEqual(store.timelineProjection.change.revision, projection)
        let restored = CompanionHomeStore(url: url)
        XCTAssertEqual(restored.composerDraft, "新草稿 🧭\nsecond line")
        XCTAssertEqual(restored.entries, messages)
    }

    func testReadingCheckpointDoesNotInvalidateDisplayObservationAndStillRestores() async throws {
        let url = location()
        let store = CompanionHomeStore(url: url)
        await store.send(text: "A historical message")
        let entry = try XCTUnwrap(store.entries.first)
        let probe = ObservationProbe()
        withObservationTracking {
            _ = store.readingState
        } onChange: { probe.mark() }
        let anchor = "message:\(entry.id)"
        store.noteReadingPosition(anchorID: anchor, followsLatest: false, hasUnread: true)
        XCTAssertFalse(probe.wasMarked, "Native viewport checkpoints must not invalidate the view that initializes the conversation")
        XCTAssertEqual(store.readingState.anchorID, anchor)
        XCTAssertTrue(store.readingState.hasUnread)
        XCTAssertTrue(store.savePresentation())
        XCTAssertEqual(CompanionHomeStore(url: url).readingState, store.readingState)
    }

    func testPendingAcceptancePublishesOriginalAndKeepsNewDraft() async throws {
        let gate = Gate()
        defer { gate.release.signal() }
        let url = location()
        let store = CompanionHomeStore(url: url,
            snapshotWriter: CompanionSnapshotWriter(beforeAsyncEncoding: { gate.encodeOnce() }))
        let agent = Agent()
        store.configure(agent: agent)
        store.composerDraft = "Original"
        let send = Task { await store.send() }
        let entered = await gate.entered()
        XCTAssertTrue(entered)
        XCTAssertEqual(store.entries.first?.text, "Original")
        XCTAssertTrue(store.isWorking)
        XCTAssertEqual(agent.calls, 0)
        store.composerDraft = "下一句话"
        let duringSave = CompanionHomeStore(url: url)
        XCTAssertEqual(duringSave.entries.first?.text, "Original")
        XCTAssertEqual(duringSave.entries.first?.status, .failed)
        XCTAssertEqual(duringSave.composerDraft, "下一句话")
        await store.send()
        XCTAssertEqual(store.entries.count, 1)
        agent.beforeReply = {
            XCTAssertEqual(CompanionHomeStore(url: url).entries.first?.text, "Original")
        }
        gate.release.signal()
        await send.value
        XCTAssertEqual(agent.calls, 1)
        XCTAssertEqual(store.entries.count, 2)
        XCTAssertEqual(CompanionHomeStore(url: url).composerDraft, "下一句话")
    }

    func testPendingMediaReferencesDurableBytesAndDoesNotDuplicateDraftOnRestart() async throws {
        let gate = Gate()
        defer { gate.release.signal() }
        let url = location()
        let store = CompanionHomeStore(url: url,
            snapshotWriter: CompanionSnapshotWriter(beforeAsyncEncoding: { gate.encodeOnce() }))
        let data = Data(repeating: 42, count: 1_024 * 1_024)
        let attachment = CompanionMediaAttachment(kind: .file, name: "sample.txt", mimeType: "text/plain", data: data)
        XCTAssertTrue(store.stageAttachment(attachment))
        store.composerDraft = "Original with media"
        let send = Task { await store.send() }
        let entered = await gate.entered()
        XCTAssertTrue(entered)
        let outbox = try Data(contentsOf: url.appendingPathExtension("outbox.json"))
        XCTAssertLessThan(outbox.count, 4_096)
        let restored = CompanionHomeStore(url: url)
        XCTAssertEqual(restored.entries.first?.attachments?.first?.data, data)
        XCTAssertTrue(restored.draftAttachments.isEmpty)
        XCTAssertTrue(restored.composerDraft.isEmpty)
        gate.release.signal()
        await send.value
        XCTAssertEqual(CompanionHomeStore(url: url).entries.count, 1)
    }

    func testUnknownOutboxIsPreservedAndPreventsOverwritingAcceptedWork() async throws {
        let url = location()
        let store = CompanionHomeStore(url: url)
        store.composerDraft = "Known draft"
        let outboxURL = url.appendingPathExtension("outbox.json")
        let unknown = Data(#"{"version":999,"future":"preserve this accepted work"}"#.utf8)
        try unknown.write(to: outboxURL)
        let restored = CompanionHomeStore(url: url)
        let agent = Agent()
        restored.configure(agent: agent)
        await restored.send()
        XCTAssertEqual(agent.calls, 0)
        XCTAssertEqual(try Data(contentsOf: outboxURL), unknown)
        XCTAssertEqual(restored.composerDraft, "Known draft")
        XCTAssertTrue(restored.clearLocalData())
        XCTAssertTrue(CompanionHomeStore(url: url).entries.isEmpty)
        XCTAssertFalse(String(decoding: try Data(contentsOf: outboxURL), as: UTF8.self).contains("preserve this accepted work"))
    }

    func testCachedEncodingRoundTripsEscapedTextMediaAndUpdatedStatus() throws {
        let encoder = CompanionHistoryEncoder()
        var entry = CompanionHomeEntry(role: .user, text: "\\\"entries\\\":[嵌套文本]\n😌", attachments: [
            .init(kind: .file, name: "a\\b\".txt", mimeType: "text/plain", data: Data([0, 255, 31]))
        ])
        let first = try encoder.encode(Fixture(entries: []), entries: [entry])
        XCTAssertEqual(try JSONDecoder().decode(Fixture.self, from: first).entries, [entry])
        entry.status = .delivered
        let updated = try encoder.encode(Fixture(entries: []), entries: [entry])
        XCTAssertEqual(try JSONDecoder().decode(Fixture.self, from: updated).entries, [entry])
        encoder.invalidate()
        let empty = try encoder.encode(Fixture(entries: []), entries: [])
        XCTAssertTrue(try JSONDecoder().decode(Fixture.self, from: empty).entries.isEmpty)
    }

    func testCancelDuringAcceptanceKeepsOriginalAndNeverCallsModel() async {
        let gate = Gate()
        defer { gate.release.signal() }
        let store = CompanionHomeStore(url: location(),
            snapshotWriter: CompanionSnapshotWriter(beforeAsyncEncoding: { gate.encodeOnce() }))
        let agent = Agent()
        store.configure(agent: agent)
        let send = Task { await store.send(text: "Cancel this attempt") }
        let entered = await gate.entered()
        XCTAssertTrue(entered)
        store.cancel()
        gate.release.signal()
        await send.value
        XCTAssertEqual(agent.calls, 0)
        XCTAssertEqual(store.entries.first?.status, .failed)
        XCTAssertFalse(store.isWorking)
    }

    func testClearDuringAcceptanceCannotReviveOriginalOrDraft() async {
        let gate = Gate()
        let encoder = CompanionHistoryEncoder()
        defer { gate.release.signal() }
        let url = location()
        let store = CompanionHomeStore(url: url,
            snapshotWriter: CompanionSnapshotWriter(beforeAsyncEncoding: { gate.encodeOnce() }), historyEncoder: encoder)
        let agent = Agent()
        store.configure(agent: agent)
        store.composerDraft = "Forgotten input"
        let send = Task { await store.send() }
        let entered = await gate.entered()
        XCTAssertTrue(entered)
        XCTAssertTrue(store.clearLocalData())
        gate.release.signal()
        await send.value
        XCTAssertEqual(encoder.cachedEntryCount, 0)
        XCTAssertEqual(agent.calls, 0)
        let restored = CompanionHomeStore(url: url)
        XCTAssertTrue(restored.entries.isEmpty)
        XCTAssertTrue(restored.composerDraft.isEmpty)
    }

    func testOlderFileReplacementCannotOverwriteReceiptOrClear() throws {
        let writer = CompanionSnapshotWriter()
        let url = location()
        let older = writer.reserve()
        let newer = writer.reserve()
        XCTAssertEqual(try writer.write(Data("receipt".utf8), to: url, ticket: newer), .written)
        XCTAssertEqual(try writer.write(Data("old".utf8), to: url, ticket: older), .superseded)
        writer.invalidate()
        XCTAssertEqual(try writer.write(Data("late".utf8), to: url, ticket: newer), .invalidated)
        XCTAssertEqual(try Data(contentsOf: url), Data("receipt".utf8))
    }

    func testStorageFailureKeepsUnsentOriginalWithoutCallingModel() async throws {
        let url = location()
        try Data("blocked folder".utf8).write(to: url.deletingLastPathComponent())
        let store = CompanionHomeStore(url: url)
        let agent = Agent()
        store.configure(agent: agent)
        store.composerDraft = "Keep the original"
        await store.send()
        XCTAssertEqual(agent.calls, 0)
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertEqual(store.composerDraft, "Keep the original")
        XCTAssertNotNil(store.errorMessage)
    }

    func testCorruptDraftBytesArePreservedUntilExplicitClear() async throws {
        let url = location()
        let store = CompanionHomeStore(url: url)
        await store.send(text: "Original history")
        let draftURL = url.appendingPathExtension("draft.json")
        let unknown = Data(#"{"version":999,"future":"preserve me"}"#.utf8)
        try unknown.write(to: draftURL)
        let restored = CompanionHomeStore(url: url)
        restored.composerDraft = "Visible replacement"
        XCTAssertEqual(try Data(contentsOf: draftURL), unknown)
        XCTAssertNotNil(restored.errorMessage)
        XCTAssertTrue(restored.clearLocalData())
        XCTAssertFalse(String(decoding: try Data(contentsOf: draftURL), as: UTF8.self).contains("preserve me"))
    }

    func testIncomingDuringInteractionAndHistoryDoesNotForceFollowing() {
        var intent = CompanionScrollIntent(reading: .init())
        intent.interactionChanged(active: true)
        XCTAssertFalse(intent.permitsScroll(.restoration))
        XCTAssertTrue(intent.permitsScroll(.explicit))
        XCTAssertFalse(intent.permitsScroll(.following))
        XCTAssertFalse(intent.contentArrived(isUserAction: false))
        intent.visibilityChanged(nearLatest: true)
        XCTAssertFalse(intent.followsLatest)
        XCTAssertTrue(intent.hasUnread)
        intent.interactionChanged(active: false)
        XCTAssertTrue(intent.followsLatest)
        XCTAssertFalse(intent.hasUnread)
        intent.interactionChanged(active: true)
        intent.visibilityChanged(nearLatest: false)
        intent.interactionChanged(active: false)
        XCTAssertFalse(intent.contentArrived(isUserAction: false))
        XCTAssertTrue(intent.contentArrived(isUserAction: true))
        XCTAssertTrue(intent.followsLatest)
    }

    func testLayoutCannotReplaceHistoryAnchorButUserScrollingCan() {
        var intent = CompanionScrollIntent(reading: .init(anchorID: "source", followsLatest: false))
        XCTAssertEqual(intent.anchorForSaving(visible: "later-layout-row", saved: "source"), "source")
        intent.interactionChanged(active: true)
        XCTAssertFalse(intent.permitsScroll(.restoration))
        XCTAssertEqual(intent.anchorForSaving(visible: "user-chosen-row", saved: "source"), "user-chosen-row")
        intent.interactionChanged(active: false)
        XCTAssertTrue(intent.permitsScroll(.restoration))
        XCTAssertEqual(intent.anchorForSaving(visible: "keyboard-layout-row", saved: "user-chosen-row"), "user-chosen-row")
    }

    func testAutomaticScrollQueuedBeforeAGestureCannotReviveAfterItEnds() {
        var intent = CompanionScrollIntent(reading: .init())
        var pending = CompanionScrollIntent.ScrollRequest(revision: 3)
        let deferred = pending
        intent.interactionChanged(active: true)
        pending.cancelForInteraction()
        intent.visibilityChanged(nearLatest: true)
        intent.interactionChanged(active: false)
        XCTAssertTrue(intent.permitsScroll(.following))
        XCTAssertNil(pending.target, "An old automatic task stays cancelled even after following resumes")
        XCTAssertGreaterThan(pending.revision, 3)
        XCTAssertFalse(intent.permitsScroll(deferred, current: pending),
                       "A captured old task cannot depend on SwiftUI cancelling it before the next layout")

        var explicit = CompanionScrollIntent.ScrollRequest(revision: 7, kind: .explicit)
        explicit.cancelForInteraction()
        XCTAssertEqual(explicit.target, "stream-bottom")
        XCTAssertEqual(explicit.revision, 7)
    }

    func testPendingSendKeepsPriorityUntilConsumedAndCannotBeReplayed() {
        let intent = CompanionScrollIntent(reading: .init())
        var request = CompanionScrollIntent.ScrollRequest(revision: 2, kind: .explicit)
        request.enqueue(kind: .following)
        XCTAssertEqual(request.kind, .explicit, "Working/content repaint cannot downgrade a pending user send")
        let captured = request
        request.consume(revision: captured.revision)
        XCTAssertFalse(intent.permitsScroll(captured, current: request))
        request.enqueue(kind: .following)
        XCTAssertEqual(request.kind, .following, "A later reply uses normal following after the send is consumed")
        let earlier = request.revision
        request.enqueue(target: "source", kind: .restoration)
        request.consume(revision: earlier)
        XCTAssertEqual(request.target, "source")
    }

    func testInitialSavedHistoryHasAnExplicitQueuedRestoration() {
        let reading = CompanionConversationReadingState(anchorID: "source", followsLatest: false, hasUnread: true)
        let request = CompanionScrollIntent.ScrollRequest.initial(reading: reading)
        XCTAssertGreaterThan(request.revision, 0)
        XCTAssertEqual(request.target, "source")
        XCTAssertEqual(request.kind, .restoration)
        let intent = CompanionScrollIntent(reading: reading)
        XCTAssertTrue(intent.permitsScroll(request, current: request))
    }

    func testKeyboardLayoutCannotPromoteCurrentHistoryIntentFromAnOldCheckpoint() {
        var history = CompanionScrollIntent(reading: .init(anchorID: "history", followsLatest: false, hasUnread: true))
        XCTAssertNil(history.keyboardRestorationTarget(reading: .init(anchorID: "stream-bottom", followsLatest: true)))
        XCTAssertFalse(history.followsLatest)
        XCTAssertTrue(history.hasUnread)
        XCTAssertEqual(history.keyboardRestorationTarget(reading: .init(anchorID: "source", followsLatest: false)), "source")
        XCTAssertFalse(history.followsLatest)
        history.interactionChanged(active: true)
        XCTAssertNil(history.keyboardRestorationTarget(reading: .init(anchorID: "source", followsLatest: false)))
        history.interactionChanged(active: false)
        XCTAssertNil(history.keyboardRestorationTarget(reading: .init(anchorID: "source", followsLatest: false)),
                     "Manual reading inside a tall row keeps the native offset instead of jumping to that row's bottom")
        XCTAssertTrue(history.hasUnread)
        let restored = CompanionScrollIntent(reading: .init(anchorID: "source", followsLatest: false))
        XCTAssertEqual(restored.keyboardRestorationTarget(reading: .init(anchorID: "source", followsLatest: false)), "source")
        history.interactionChanged(active: true)
        history.visibilityChanged(nearLatest: true)
        history.interactionChanged(active: false)
        XCTAssertTrue(history.followsLatest)
        XCTAssertEqual(history.keyboardRestorationTarget(reading: .init(anchorID: "source", followsLatest: false)), "stream-bottom")
    }

    func testMapReturnPinsTheSourceInsteadOfANeighboringVisibleRow() async throws {
        let store = CompanionHomeStore(url: location())
        let agent = Agent()
        store.configure(agent: agent)
        await store.send(text: "First question")
        await store.send(text: "A later question")
        let source = try XCTUnwrap(store.entries.first(where: { $0.role == .companion }))
        let last = try XCTUnwrap(store.entries.last)
        store.noteReadingPosition(anchorID: "message:\(last.id)", followsLatest: false, hasUnread: false)
        XCTAssertTrue(store.captureMapSource(messageID: source.id, experienceIDs: []))
        XCTAssertEqual(store.mapSource?.readingAnchorID, "message:\(source.id)")
        XCTAssertTrue(store.restoreMapSource())
        XCTAssertEqual(store.readingState.anchorID, "message:\(source.id)")
        XCTAssertFalse(store.readingState.followsLatest)
    }

    func testCoalescedStatusUpdatesRetainTheUnseenUserSend() {
        let initial = CompanionTimeline.Projection()
        var user = CompanionHomeEntry(role: .user, text: "Quick send")
        let accepted = CompanionTimeline.Projection(entries: [user], invites: [], previous: initial, revision: 1)
        user.status = .working
        let started = CompanionTimeline.Projection(entries: [user], invites: [], previous: accepted, revision: 2)
        let reply = CompanionHomeEntry(role: .companion, text: "Fast reply", replyToID: user.id)
        let completed = CompanionTimeline.Projection(entries: [user, reply], invites: [], previous: started, revision: 3)
        XCTAssertGreaterThan(completed.change.userActionRevision, initial.change.userActionRevision)
        XCTAssertEqual(completed.rows.map(\.id), ["message:\(user.id)", "message:\(reply.id)"])
        XCTAssertNil(completed.replyContexts[reply.id])
    }

    func testScrollPolicyPhasesDoNotNotifyUnchangedPresentation() {
        let state = CompanionScrollState(reading: .init(anchorID: "message:history", followsLatest: false, hasUnread: false))
        state.setInteraction(true)
        let probe = ObservationProbe()
        withObservationTracking { _ = state.presentation } onChange: { probe.mark() }
        state.setInteraction(false)
        state.setInteraction(true)
        state.setInteraction(false)
        XCTAssertFalse(probe.wasMarked, "Pan/deceleration policy must not republish an unchanged latest/unread control")
        XCTAssertTrue(state.presentation.showsLatest)
    }

    func testScrollCommandAndViewportChannelsDoNotInvalidatePresentation() {
        let state = CompanionScrollState(reading: .init())
        let probe = ObservationProbe()
        withObservationTracking { _ = state.presentation } onChange: { probe.mark() }
        state.enqueue(kind: .explicit)
        state.consume(revision: state.request.revision)
        state.updateViewport(CGRect(x: 0, y: 80, width: 390, height: 500))
        XCTAssertFalse(probe.wasMarked, "Execution and viewport changes belong to their own child observers")
        XCTAssertNil(state.request.target)
        XCTAssertFalse(state.presentation.showsLatest)
    }

    func testScrollUnreadUpdatesPresentationWithoutExposingPolicyChanges() {
        let state = CompanionScrollState(reading: .init(anchorID: "message:history", followsLatest: false, hasUnread: false))
        let display = ObservationProbe()
        withObservationTracking { _ = state.presentation } onChange: { display.mark() }
        XCTAssertFalse(state.contentArrived(isUserAction: false))
        XCTAssertTrue(display.wasMarked)
        XCTAssertTrue(state.presentation.hasUnread)
        let policy = ObservationProbe()
        withObservationTracking { _ = state.intent } onChange: { policy.mark() }
        state.setInteraction(true)
        state.setInteraction(false)
        XCTAssertFalse(policy.wasMarked, "Internal policy is not a display observation channel")
        let cleared = ObservationProbe()
        withObservationTracking { _ = state.presentation } onChange: { cleared.mark() }
        state.revealLatest()
        XCTAssertTrue(cleared.wasMarked)
        XCTAssertFalse(state.presentation.hasUnread)
        XCTAssertFalse(state.presentation.showsLatest)
    }

}
