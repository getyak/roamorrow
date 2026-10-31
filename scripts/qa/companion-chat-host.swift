import Foundation
import Observation

@main struct CompanionChatHostChecks {
    @MainActor static var failures = 0
    @MainActor static var checks = 0
    @MainActor static func require(_ value: @autoclosure () -> Bool, _ label: String) {
        checks += 1
        if !value() { failures += 1; print("FAIL: \(label)") }
    }

    struct Fixture: Codable {
        var version = 1
        var entries: [CompanionHomeEntry]
        var composerDraft = ""
        var people: [CompanionHomePerson] = []
        var selectedPeopleIDs: Set<String> = []
        var invites: [CompanionHomeInvite] = []
    }

    final class ObservationProbe: @unchecked Sendable {
        private let lock = NSLock()
        private var marked = false
        func mark() { lock.lock(); marked = true; lock.unlock() }
        var wasMarked: Bool { lock.lock(); defer { lock.unlock() }; return marked }
    }

    final class EncodingGate: @unchecked Sendable {
        let entered = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        private let lock = NSLock()
        private var used = false
        func waitOnce() {
            lock.lock()
            let shouldWait = !used
            used = true
            lock.unlock()
            if shouldWait { entered.signal(); release.wait() }
        }
        func waitForStart() async -> Bool {
            await Task.detached { self.waitForStartSynchronously() }.value
        }
        private func waitForStartSynchronously() -> Bool { entered.wait(timeout: .now() + 5) == .success }
    }

    @MainActor final class Agent: CompanionHomeResponding {
        var calls = 0
        var onResponse: (() -> Void)?
        func respond(to entries: [CompanionHomeEntry]) async throws -> CompanionHomeAgentResult {
            calls += 1
            onResponse?()
            return .init(text: "A controlled reply")
        }
    }

    @MainActor static func persistenceChecks(root: URL) async throws {
        let writer = CompanionSnapshotWriter()
        let old = writer.reserve()
        let newer = writer.reserve()
        let file = root.appendingPathComponent("writer.json")
        let committed = try writer.write(Data("new receipt".utf8), to: file, ticket: newer)
        require(committed == .written, "new receipt commits")
        let superseded = try writer.write(Data("old snapshot".utf8), to: file, ticket: old)
        require(superseded == .superseded, "older snapshot cannot overwrite newer receipt")
        writer.invalidate()
        let invalidated = try writer.write(Data("late data".utf8), to: file, ticket: newer)
        require(invalidated == .invalidated, "invalidated writes cannot revive cleared data")
        let bytes = try Data(contentsOf: file)
        require(String(decoding: bytes, as: UTF8.self) == "new receipt", "durable newer bytes retained")

        let gate = EncodingGate()
        let store = CompanionHomeStore(url: root.appendingPathComponent("admission.json"),
            snapshotWriter: CompanionSnapshotWriter(beforeAsyncEncoding: { gate.waitOnce() }))
        let agent = Agent()
        store.configure(agent: agent)
        store.composerDraft = "original send"
        let send = Task { await store.send() }
        let entered = await gate.waitForStart()
        require(entered, "initial save reaches background encoder")
        require(store.entries.first?.text == "original send" && store.isWorking, "original appears while durable acceptance is pending")
        require(agent.calls == 0, "no model call before durable acceptance")
        store.composerDraft = "new draft while saving"
        require(CompanionHomeStore(url: root.appendingPathComponent("admission.json")).entries.first?.text == "original send",
                "restart during slow acceptance retains original even after a newer draft is typed")
        await store.send()
        require(store.entries.count == 1, "rapid second send does not duplicate a pending message")
        gate.release.signal()
        await send.value
        require(agent.calls == 1 && store.entries.count == 2, "accepted turn calls model once and stores one reply")
        require(CompanionHomeStore(url: root.appendingPathComponent("admission.json")).composerDraft == "new draft while saving", "new draft survives older async writes")

        let clearGate = EncodingGate()
        let clearEncoder = CompanionHistoryEncoder()
        let clearStore = CompanionHomeStore(url: root.appendingPathComponent("clear.json"),
            snapshotWriter: CompanionSnapshotWriter(beforeAsyncEncoding: { clearGate.waitOnce() }), historyEncoder: clearEncoder)
        let clearAgent = Agent()
        clearStore.configure(agent: clearAgent)
        clearStore.composerDraft = "must disappear"
        let pending = Task { await clearStore.send() }
        let clearEntered = await clearGate.waitForStart()
        require(clearEntered, "clear race reaches background encoder")
        require(clearStore.clearLocalData(), "clear succeeds while old encoding is suspended")
        clearGate.release.signal()
        await pending.value
        require(clearEncoder.cachedEntryCount == 0, "late encoder cannot retain forgotten messages after explicit clear")
        let afterClear = CompanionHomeStore(url: root.appendingPathComponent("clear.json"))
        require(afterClear.entries.isEmpty && afterClear.composerDraft.isEmpty && clearAgent.calls == 0, "clear rejects late snapshot, original draft and model start")

        let cancelGate = EncodingGate()
        let cancelStore = CompanionHomeStore(url: root.appendingPathComponent("cancel.json"),
            snapshotWriter: CompanionSnapshotWriter(beforeAsyncEncoding: { cancelGate.waitOnce() }))
        let cancelAgent = Agent()
        cancelStore.configure(agent: cancelAgent)
        let cancelled = Task { await cancelStore.send(text: "cancel before model") }
        let cancelEntered = await cancelGate.waitForStart()
        require(cancelEntered, "cancel race reaches background encoder")
        cancelStore.cancel()
        cancelGate.release.signal()
        await cancelled.value
        require(cancelAgent.calls == 0 && cancelStore.entries.first?.status == .failed, "cancel during admission never starts model and keeps retryable original")

        let failureGate = EncodingGate()
        let failingURL = root.appendingPathComponent("blocked/v1.json")
        let failing = CompanionHomeStore(url: failingURL,
            snapshotWriter: CompanionSnapshotWriter(beforeAsyncEncoding: { failureGate.waitOnce() }))
        let failureAgent = Agent()
        failing.configure(agent: failureAgent)
        failing.composerDraft = "original preserved on failed write"
        let failureSend = Task { await failing.send() }
        let failureEntered = await failureGate.waitForStart()
        require(failureEntered, "failure race reaches background encoder")
        failing.composerDraft = "keep newer draft"
        let directory = failingURL.deletingLastPathComponent()
        let backup = directory.appendingPathExtension("saved")
        try FileManager.default.moveItem(at: directory, to: backup)
        try Data("blocked".utf8).write(to: directory)
        failureGate.release.signal()
        await failureSend.value
        require(failing.entries.first?.text == "original preserved on failed write" && failing.entries.first?.status == .failed,
                "failed acceptance retains retryable original when a new draft exists")
        require(failing.composerDraft == "keep newer draft" && failureAgent.calls == 0, "failed acceptance cannot replace new draft or call model")
        try FileManager.default.removeItem(at: directory)
        try FileManager.default.moveItem(at: backup, to: directory)
        if let id = failing.entries.first?.id { await failing.retry(id: id) }
        require(failing.entries.count == 2 && failureAgent.calls == 1, "storage recovery retries the exact original once")
        require(CompanionHomeStore(url: failingURL).composerDraft == "keep newer draft", "new draft survives failed acceptance and later retry")

        let mediaGate = EncodingGate()
        let mediaURL = root.appendingPathComponent("media.json")
        let mediaStore = CompanionHomeStore(url: mediaURL,
            snapshotWriter: CompanionSnapshotWriter(beforeAsyncEncoding: { mediaGate.waitOnce() }))
        let media = CompanionMediaAttachment(kind: .file, name: "owned-fixture.txt", mimeType: "text/plain",
            data: Data(repeating: 42, count: 1_024 * 1_024))
        require(mediaStore.stageAttachment(media), "media bytes durably stage before acceptance")
        mediaStore.composerDraft = "original with media"
        let mediaSend = Task { await mediaStore.send() }
        let mediaEntered = await mediaGate.waitForStart()
        require(mediaEntered, "media acceptance is gated before full save")
        let mediaOutbox = try Data(contentsOf: mediaURL.appendingPathExtension("outbox.json"))
        require(mediaOutbox.count < 4_096,
            "acceptance references durable media without base64-encoding it on main")
        let restoredMedia = CompanionHomeStore(url: mediaURL)
        require(restoredMedia.entries.first?.attachments?.first?.data == media.data,
            "restart reconstructs accepted original media bytes")
        require(restoredMedia.draftAttachments.isEmpty && restoredMedia.composerDraft.isEmpty,
            "restart consumes only the original draft and media, without a duplicate")
        mediaGate.release.signal()
        await mediaSend.value

        let unknownURL = root.appendingPathComponent("unknown.json")
        let knownStore = CompanionHomeStore(url: unknownURL)
        knownStore.composerDraft = "known draft"
        let unknownOutbox = unknownURL.appendingPathExtension("outbox.json")
        let unknownBytes = Data(#"{"version":999,"future":"preserve accepted original"}"#.utf8)
        try unknownBytes.write(to: unknownOutbox)
        let protected = CompanionHomeStore(url: unknownURL)
        let protectedAgent = Agent()
        protected.configure(agent: protectedAgent)
        await protected.send()
        let stillUnknown = try Data(contentsOf: unknownOutbox)
        require(stillUnknown == unknownBytes && protectedAgent.calls == 0 && protected.composerDraft == "known draft",
            "unknown acceptance bytes are preserved and cannot be overwritten by a new send")
        require(protected.clearLocalData(), "explicit clear resets unknown acceptance namespace")
        require(CompanionHomeStore(url: unknownURL).entries.isEmpty, "unknown original cannot revive after explicit clear")
    }

    @MainActor static func scrollChecks(entries: [CompanionHomeEntry]) {
        let projection = CompanionTimeline.Projection(entries: entries, invites: [])
        require(projection.events.count == 5_000 && projection.eventIDs.count == 5_000, "long projection preserves every identity")
        let outgoing = CompanionHomeEntry(role: .user, text: "fast outgoing", createdAt: .distantFuture)
        let inserted = CompanionTimeline.Projection(entries: entries + [outgoing], invites: [], previous: projection, revision: 1)
        var changed = outgoing
        changed.status = .working
        let repainted = CompanionTimeline.Projection(entries: entries + [changed], invites: [], previous: inserted, revision: 2)
        require(repainted.change.userActionRevision > projection.change.userActionRevision,
                "coalesced status updates retain an unseen outgoing event")
        require(repainted.rows.map(\.id) == repainted.events.map(\.id), "cached lazy-row IDs match stable event identities")
        var intent = CompanionScrollIntent(reading: .init())
        intent.interactionChanged(active: true)
        require(!intent.contentArrived(isUserAction: false) && intent.hasUnread, "incoming during finger/inertia never pulls reader")
        intent.visibilityChanged(nearLatest: true)
        require(!intent.followsLatest, "visible bottom cannot override active interaction")
        intent.interactionChanged(active: false)
        require(intent.followsLatest && !intent.hasUnread, "stopping at bottom restores following")
        intent.interactionChanged(active: true)
        intent.visibilityChanged(nearLatest: false)
        intent.interactionChanged(active: false)
        require(!intent.contentArrived(isUserAction: false), "reading history retains anchor on incoming")
        require(intent.contentArrived(isUserAction: true) && intent.followsLatest, "explicit user send returns to latest immediately")
        var restored = CompanionScrollIntent(reading: .init(anchorID: "source", followsLatest: false))
        require(restored.anchorForSaving(visible: "layout-row", saved: "source") == "source",
            "layout binding changes cannot replace a restored history anchor")
        restored.interactionChanged(active: true)
        require(!restored.permitsScroll(.restoration), "queued history restoration respects a newly started gesture")
        require(restored.permitsScroll(.explicit), "explicit send/latest action can still override history interaction")
        require(restored.anchorForSaving(visible: "user-row", saved: "source") == "user-row",
            "native user scrolling can move the reading anchor")
        restored.interactionChanged(active: false)
        require(restored.permitsScroll(.restoration), "idle history restoration may replay its stable target")
        require(restored.anchorForSaving(visible: "keyboard-row", saved: "user-row") == "user-row",
            "keyboard geometry after deceleration preserves the chosen history anchor")

        let layout = CompanionScrollState(reading: .init())
        let sizingObserver = ObservationProbe()
        withObservationTracking { _ = layout.pinsLatestDuringLayout } onChange: { sizingObserver.mark() }
        require(layout.pinsLatestDuringLayout, "idle latest retains a native sizing anchor")
        layout.setNearLatest(false)
        require(layout.pinsLatestDuringLayout, "temporary keyboard geometry does not cancel latest sizing intent")
        require(!sizingObserver.wasMarked, "geometry-only visibility does not publish sizing ownership")
        layout.setNearLatest(true)
        let controlObserver = ObservationProbe()
        withObservationTracking { _ = layout.presentation } onChange: { controlObserver.mark() }
        layout.setInteraction(true)
        require(!layout.pinsLatestDuringLayout && !layout.presentation.showsLatest,
            "tracking releases the sizing anchor even before the latest control changes")
        require(sizingObserver.wasMarked && !controlObserver.wasMarked,
            "sizing and latest-control projections notify their own observers independently")
        layout.setNearLatest(false); layout.setInteraction(false)
        _ = layout.contentArrived(isUserAction: false)
        require(!layout.pinsLatestDuringLayout, "incoming history content never reanchors a reader")
        layout.revealLatest()
        require(layout.pinsLatestDuringLayout, "explicit latest restores native sizing ownership")
        layout.restore(reading: .init(anchorID: "source", followsLatest: false))
        layout.setNearLatest(true)
        require(!layout.pinsLatestDuringLayout, "history visibility readback cannot acquire latest sizing ownership")
        layout.setInteraction(true)
        _ = layout.contentArrived(isUserAction: true)
        require(!layout.pinsLatestDuringLayout, "an explicit send still waits for native interaction to end before sizing pins")
        layout.setInteraction(false)
        require(layout.pinsLatestDuringLayout, "the explicit send pins layout once native interaction ends")

        let native = CompanionScrollState(reading: .init())
        native.enqueue(kind: .explicit)
        let semanticRequest = native.request
        native.updateViewport(CGRect(x: 0, y: 80, width: 390, height: 500), nativeSizing: true)
        native.updateViewport(CGRect(x: 0, y: 80, width: 390, height: 300), nativeSizing: true)
        require(native.request == semanticRequest, "native resizing neither duplicates nor consumes an explicit latest command")
        require(native.viewport.height == 300, "native sizing still records the real viewport cache")
        require(native.intent.keyboardRestorationTarget(reading: .init(), nativeSizing: true) == nil,
            "native sizing owns latest keyboard layout without another ID command")
        require(native.intent.keyboardRestorationTarget(reading: .init()) == "stream-bottom",
            "legacy keyboard layout retains the queued latest fallback")
        var nativeHistory = CompanionScrollIntent(reading: .init(anchorID: "source", followsLatest: false))
        require(nativeHistory.keyboardRestorationTarget(reading: .init(anchorID: "source", followsLatest: false), nativeSizing: true) == "source",
            "native sizing does not disable explicit saved history restoration")
        nativeHistory.interactionChanged(active: true); nativeHistory.interactionChanged(active: false)
        require(nativeHistory.keyboardRestorationTarget(reading: .init(anchorID: "source", followsLatest: false), nativeSizing: true) == nil,
            "manual history keeps native ownership of its position inside a tall row")

        let visibilityCases: [(String, CGFloat, CGRect, Bool)] = [
            ("normal tail", 1_000, CGRect(x: 0, y: 640, width: 390, height: 361), true),
            ("history", 1_000, CGRect(x: 0, y: 200, width: 390, height: 361), false),
            ("past EOF", 1_000, CGRect(x: 0, y: 1_200, width: 390, height: 361), false),
            ("exact EOF", 1_000, CGRect(x: 0, y: 1_000, width: 390, height: 361), false),
            ("bottom bounce intersects content", 1_000, CGRect(x: 0, y: 700, width: 390, height: 400), true),
            ("short content", 10, CGRect(x: 0, y: 0, width: 390, height: 361), true),
            ("short content entirely below viewport", 10, CGRect(x: 0, y: -110, width: 390, height: 100), false),
            ("zero height", 1_000, CGRect(x: 0, y: 990, width: 390, height: 0), false),
            ("zero width", 1_000, CGRect(x: 0, y: 640, width: 0, height: 361), false),
            ("empty content", 0, CGRect(x: 0, y: 0, width: 390, height: 361), false),
            ("infinite viewport", 1_000, .infinite, false),
            ("unknown height", .nan, CGRect(x: 0, y: 0, width: 390, height: 361), false)
        ]
        for (name, height, rect, expected) in visibilityCases {
            require(CompanionScrollVisibility.isNearLatest(contentHeight: height, visibleRect: rect) == expected,
                "native visibility: \(name)")
        }
    }

    @MainActor static func main() async throws {
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("companion-chat-host-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("v1.json")
        let entries = (0..<5_000).map { index in
            CompanionHomeEntry(role: index.isMultiple(of: 2) ? .user : .companion,
                text: "\(index) " + String(repeating: "消息与公共旅行资料。", count: 20),
                createdAt: Date(timeIntervalSince1970: Double(index)), status: .delivered)
        }
        try JSONEncoder().encode(Fixture(entries: entries)).write(to: url)
        let store = CompanionHomeStore(url: url)
        require(store.entries.count == 5_000, "real Store loads 5,000 fixture messages")
        let before = try Data(contentsOf: url)
        var durations: [Double] = []
        for index in 0..<20 {
            let start = ContinuousClock.now
            store.composerDraft = "下一条消息 \(index)"
            let elapsed = start.duration(to: .now).components
            durations.append(Double(elapsed.seconds) * 1_000 + Double(elapsed.attoseconds) / 1e15)
        }
        var metrics: [String: Any] = [
            "scope": "optimized macOS host; real Store, synthetic 5000-message history, controlled transport; not native frame rate",
            "messages": store.entries.count,
            "snapshot_bytes": before.count,
            "typing_ms_median": durations.sorted()[durations.count / 2],
            "typing_ms_max": durations.max() ?? 0
        ]
        let data = try JSONSerialization.data(withJSONObject: metrics, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: output.appendingPathComponent("metrics.json"))
        print(String(decoding: data, as: UTF8.self))
        let after = try Data(contentsOf: url)
        require(after == before, "typing must not rewrite or re-encode the complete history snapshot")
        require(CompanionHomeStore(url: url).composerDraft == store.composerDraft, "latest lightweight draft restores immediately")
        var checkpointDurations: [Double] = []
        let checkpointAgent = Agent()
        checkpointAgent.onResponse = {
            guard let id = store.entries.last(where: { $0.role == .user })?.id else { return }
            let calls = (0..<4).map { index in
                CompanionHomeToolCheckpoint(id: "host-work-budget-\(index)", name: "web_search",
                    argumentsJSON: "{\"query\":\"public fixture \(index)\"}")
            }
            let turn = AgentTurnIdentity(session: store.agentSession, turnID: id)
            require(store.savePlan(CompanionHomeToolBatch(calls: calls), for: turn), "active turn saves a distinct tool plan")
            for call in calls {
                let start = ContinuousClock.now
                let saved = store.saveStarted(callID: call.id, for: turn)
                let elapsed = start.duration(to: .now).components
                require(saved, "active turn saves a new started checkpoint")
                checkpointDurations.append(Double(elapsed.seconds) * 1_000 + Double(elapsed.attoseconds) / 1e15)
                var result = call
                result.resultJSON = "{\"ok\":true}"
                require(store.saveResult(result, for: turn), "active turn saves a distinct observed result")
            }
        }
        store.configure(agent: checkpointAgent)
        await store.send(text: "[host fixture] persistence work budget")
        let journalMedian = checkpointDurations.sorted()[checkpointDurations.count / 2]
        print("Synchronous journal save median ms: \(journalMedian)")
        metrics["journal_save_ms_median"] = journalMedian
        try JSONSerialization.data(withJSONObject: metrics, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("metrics.json"))
        let recovered = CompanionHomeStore(url: url)
        let restoredTurn = recovered.entries.last(where: { $0.role == .user })!
        require(recovered.toolJournal(for: restoredTurn.id).flatMap(\.calls).allSatisfy { $0.state == .completed },
            "cached snapshots round-trip every durable observed result")
        let sourceID = entries[1].id
        store.noteReadingPosition(anchorID: "message:\(restoredTurn.id)", followsLatest: false, hasUnread: false)
        require(store.captureMapSource(messageID: sourceID, experienceIDs: []), "source capture accepts an existing historical message")
        require(store.mapSource?.readingAnchorID == "message:\(sourceID)", "map source pins its own ID instead of a neighboring visible row")
        require(store.restoreMapSource() && store.readingState.anchorID == "message:\(sourceID)",
            "map return restores the actual source while keeping history intention")
        try await persistenceChecks(root: root)
        scrollChecks(entries: entries)
        print("Companion chat host: \(checks) checks, \(failures) failures")
        if failures > 0 { exit(1) }
    }
}
