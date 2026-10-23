import Foundation
import Observation

@MainActor
@Observable
final class CompanionHomeStore {
    private(set) var entries: [CompanionHomeEntry] = []
    var composerDraft = "" { didSet { if !isLoading { persist() } } }
    private(set) var draftAttachments: [CompanionMediaAttachment] = []
    private(set) var draftQuote: CompanionQuotedMessage?
    private(set) var isWorking = false
    private(set) var activity: CompanionActivity = .idle
    private(set) var errorMessage: String?
    private var storedPeople: [CompanionHomePerson] = []
    var people: [CompanionHomePerson] {
        get { storedPeople }
        set { _ = updatePeople(newValue) }
    }
    private(set) var selectedPeopleIDs: Set<String> = []
    private(set) var commitments: [CompanionHomeCommitment] = []
    var activeCommitments: [CompanionHomeCommitment] { commitments.filter { $0.status == .active } }
    private(set) var invites: [CompanionHomeInvite] = []
    private(set) var experienceService: ExperienceService?

    @ObservationIgnored private var agent: (any CompanionHomeResponding)?
    @ObservationIgnored private var productionAgent: CompanionHomeAgent?
    @ObservationIgnored private var searchAreaProvider: (() -> CompanionHomeSearchArea?)?
    @ObservationIgnored private var activeTask: Task<CompanionHomeAgentResult, Error>?
    @ObservationIgnored private var activeID: UUID?
    @ObservationIgnored private var activeAttemptID: UUID?
    @ObservationIgnored private var isLoading = true
    @ObservationIgnored private var url: URL
    @ObservationIgnored private let originalURL: URL
    @ObservationIgnored private var storageBlocked = false
    @ObservationIgnored private var stagingToolResult = false
    private var toolJournals: [String: [CompanionHomeToolBatch]] = [:]

    private struct Snapshot: Codable {
        var version = 1
        var entries: [CompanionHomeEntry]
        var composerDraft: String
        var people: [CompanionHomePerson]
        var selectedPeopleIDs: Set<String>
        var invites: [CompanionHomeInvite]
        var commitments: [CompanionHomeCommitment]? = nil
        var toolJournals: [String: [CompanionHomeToolBatch]]? = nil
        var draftAttachments: [CompanionMediaAttachment]? = nil
        var draftQuote: CompanionQuotedMessage? = nil
    }

    init(url: URL? = nil) {
        self.url = url ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Roamorrow/CompanionHome/v1.json")
        self.originalURL = self.url
        load()
        isLoading = false
    }

    /// Call once from the app's existing service graph. Optional router is the same
    /// instance owned by the map, so tools resolve actual visible Experience data.
    func configure(aiService: AIService, experienceService: ExperienceService) {
        self.experienceService = experienceService
        let production = CompanionHomeAgent(aiService: aiService, experienceService: experienceService)
        production.journalStore = self
        production.searchArea = searchAreaProvider
        production.activeCommitments = { [weak self] in self?.activeCommitments ?? [] }
        productionAgent = production
        agent = production
    }

    func configure(toolRouter: VoiceAgentToolRouter) {
        productionAgent?.toolRouter = toolRouter
    }

    /// The provider must return only a selected public map/city center, never device GPS.
    func configure(searchArea: @escaping () -> CompanionHomeSearchArea?) {
        searchAreaProvider = searchArea
        productionAgent?.searchArea = searchArea
        (agent as? CompanionHomeAgent)?.searchArea = searchArea
    }

    /// Injection seam; does not create a second production credential path.
    func configure(agent: any CompanionHomeResponding) {
        self.agent = agent
        (agent as? CompanionHomeAgent)?.searchArea = searchAreaProvider
    }

    var selectedSearchArea: CompanionHomeSearchArea? { searchAreaProvider?() }

    var canStartRecording: Bool {
        let bytes = (entries.flatMap { $0.attachments ?? [] } + draftAttachments).reduce(0) { $0 + $1.byteCount }
        // 120s mono AAC at 64kbps fits within a reserved 2MB. No import runs while recording.
        return draftAttachments.count < 4 && bytes <= 28 * 1_024 * 1_024
    }

    @discardableResult
    func stageAttachment(_ attachment: CompanionMediaAttachment) -> Bool {
        if draftAttachments.contains(where: { $0.id == attachment.id }) { return persist() }
        let totalBytes = (entries.flatMap { $0.attachments ?? [] } + draftAttachments).reduce(0) { $0 + $1.byteCount }
        guard attachment.isValid, draftAttachments.count < 4,
              totalBytes + attachment.byteCount <= 30 * 1_024 * 1_024 else {
            errorMessage = companionMediaText("companion.media.limit", "每次最多添加 4 个附件，单个不超过 10 MB。本机附件总量已满时，请先导出。")
            return false
        }
        draftAttachments.append(attachment)
        // A unique recording has no external original: retain it in memory even if disk is temporarily unavailable.
        guard persist() else { return false }
        return true
    }

    @discardableResult
    func setAttachmentTranscript(id: UUID, text: String) -> Bool {
        guard let index = draftAttachments.firstIndex(where: { $0.id == id }) else { return false }
        let previous = draftAttachments[index]
        draftAttachments[index].extractedText = String(text.prefix(12_000))
        guard persist() else { draftAttachments[index] = previous; return false }
        return true
    }

    func toggleReaction(entryID: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return }
        let previous = entries[index].reaction
        entries[index].reaction = previous == "heart" ? nil : "heart"
        if !persist() { entries[index].reaction = previous }
    }

    func removeDraftAttachment(id: UUID) {
        let previous = draftAttachments
        draftAttachments.removeAll { $0.id == id }
        if !persist() { draftAttachments = previous }
    }

    func setDraftQuote(_ quote: CompanionQuotedMessage?) {
        let previous = draftQuote
        draftQuote = quote.map { .init(entryID: $0.entryID, role: $0.role, text: String($0.text.prefix(600))) }
        if !persist() { draftQuote = previous }
    }

    func send() async { await submit(text: composerDraft, attachments: draftAttachments, quote: draftQuote, consumesDraft: true) }

    func send(text: String) async {
        await submit(text: text, attachments: [], quote: nil, consumesDraft: text == composerDraft)
    }

    private func submit(text: String, attachments: [CompanionMediaAttachment], quote: CompanionQuotedMessage?, consumesDraft: Bool) async {
        guard !isWorking, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachments.isEmpty else { return }
        guard attachments.allSatisfy(\.isValid) else { return }
        let previousText = composerDraft
        let previousAttachments = draftAttachments
        let previousQuote = draftQuote
        let entry = CompanionHomeEntry(role: .user, text: text, attachments: attachments.isEmpty ? nil : attachments, quotedMessage: quote)
        entries.append(entry)
        // One write moves draft -> message; a crash cannot restore both copies.
        isLoading = true
        if consumesDraft { composerDraft = ""; draftAttachments = []; draftQuote = nil }
        isLoading = false
        guard persist() else {
            entries.removeAll { $0.id == entry.id }
            isLoading = true
            composerDraft = previousText.isEmpty ? text : previousText
            draftAttachments = previousAttachments
            draftQuote = previousQuote
            isLoading = false
            activity = .failed(entry.id)
            return
        }
        await run(id: entry.id)
    }

    func retry(id: UUID) async {
        guard !isWorking, let entry = entries.first(where: { $0.id == id }), entry.role == .user,
              entry.status == .failed || entry.status == .queued else { return }
        // A received reply may still be waiting for its final local save. Preserve
        // that exact response and its tool receipts rather than regenerating it.
        if entries.contains(where: { $0.replyToID == id && $0.status == .delivered }),
           let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index].status = .delivered
            if persist() {
                errorMessage = nil
                activity = .completed(id)
            } else {
                entries[index].status = .failed
                activity = .failed(id)
            }
            return
        }
        await run(id: id)
    }

    func cancel() {
        activeTask?.cancel()
        activeTask = nil
        if let id = activeID, let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index].status = .failed
        }
        activeID = nil
        activeAttemptID = nil
        isWorking = false
        activity = .idle
        persist()
    }

    /// User-maintained names are local intent candidates, never verified accounts or contacts.
    /// Direct assignment remains supported for the people sheet's existing binding.
    @discardableResult
    func updatePeople(_ people: [CompanionHomePerson], selectedIDs: Set<String>? = nil) -> Bool {
        let previousPeople = storedPeople
        let previousSelection = selectedPeopleIDs
        storedPeople = people
        selectedPeopleIDs = (selectedIDs ?? selectedPeopleIDs).intersection(Set(people.map(\.id)))
        guard isLoading || persist() else {
            storedPeople = previousPeople
            selectedPeopleIDs = previousSelection
            return false
        }
        return true
    }

    @discardableResult
    func selectPeople(_ ids: Set<String>) -> Bool {
        // Selection expresses intent only; no relationship or location permission is created.
        let previousSelection = selectedPeopleIDs
        selectedPeopleIDs = ids.intersection(Set(people.map(\.id)))
        guard persist() else { selectedPeopleIDs = previousSelection; return false }
        return true
    }

    @discardableResult
    func saveInvite(_ invite: CompanionHomeInvite) async -> Bool {
        let previousInvites = invites
        var draft = invite
        draft.status = .draft
        draft.durationMinutes = max(1, draft.durationMinutes)
        if let index = invites.firstIndex(where: { $0.id == draft.id }) {
            draft.createdAt = invites[index].createdAt
            invites[index] = draft
        } else {
            draft.createdAt = Date()
            invites.append(draft)
        }
        guard persist() else { invites = previousInvites; return false }
        return true
    }

    @discardableResult
    func completeCommitment(id: UUID) -> Bool { changeCommitmentStatus(id: id, status: .done) }

    @discardableResult
    func cancelCommitment(id: UUID) -> Bool { changeCommitmentStatus(id: id, status: .cancelled) }

    private func changeCommitmentStatus(id: UUID, status: CompanionHomeCommitment.Status) -> Bool {
        guard let index = commitments.firstIndex(where: { $0.id == id }) else { return false }
        guard commitments[index].status == .active || commitments[index].status == status else { return false }
        let previous = commitments
        commitments[index].status = status
        commitments[index].updatedAt = Date()
        guard persist() else { commitments = previous; return false }
        return true
    }

    /// One bounded, local function call; no contacts, notification or transport effects.
    func manageFollowUp(_ request: CompanionHomeFollowUpRequest, originEntryID: UUID) -> CompanionHomeFollowUpResult {
        let previous = commitments
        let id: UUID
        switch request.action {
        case .create:
            guard let title = request.title else { return .init(success: false, error: "title_required") }
            if let existing = commitments.first(where: {
                $0.originEntryID == originEntryID && $0.title.localizedCaseInsensitiveCompare(title) == .orderedSame
            }) {
                return .init(success: true, commitment: existing)
            }
            guard commitments.count < 500, activeCommitments.count < 50 else {
                return .init(success: false, error: "local_item_limit")
            }
            let commitment = CompanionHomeCommitment(title: title, note: request.note ?? "", dueAt: request.dueAt, originEntryID: originEntryID)
            commitments.append(commitment)
            id = commitment.id
        case .update:
            guard let target = request.id, let index = commitments.firstIndex(where: { $0.id == target }),
                  commitments[index].status == .active else { return .init(success: false, error: "active_id_required") }
            id = target
            if let title = request.title { commitments[index].title = title }
            if let note = request.note { commitments[index].note = note }
            if request.hasDueAt { commitments[index].dueAt = request.dueAt }
            commitments[index].updatedAt = Date()
        case .complete, .cancel:
            guard let target = request.id else { return .init(success: false, error: "id_required") }
            let success = request.action == .complete ? completeCommitment(id: target) : cancelCommitment(id: target)
            return .init(success: success, commitment: success ? commitments.first { $0.id == target } : nil,
                         error: success ? nil : "not_saved_or_invalid_status")
        }
        guard persist() else {
            commitments = previous
            return .init(success: false, error: "not_saved")
        }
        return .init(success: true, commitment: commitments.first { $0.id == id })
    }

    func toolJournal(for entryID: UUID) -> [CompanionHomeToolBatch] {
        toolJournals[entryID.uuidString] ?? []
    }

    /// A complete model tool plan must reach disk before any of its calls execute.
    @discardableResult
    func checkpointToolPlan(entryID: UUID, batch: CompanionHomeToolBatch) -> Bool {
        guard !Task.isCancelled, entries.contains(where: { $0.id == entryID && $0.role == .user }) else { return false }
        let previous = toolJournal(for: entryID)
        let existingCalls = previous.flatMap(\.calls)
        let allowed: Set<String> = ["manage_follow_up", "search_places", "show_details", "web_search"]
        guard previous.count < 3, !batch.calls.isEmpty,
              existingCalls.allSatisfy({ $0.resultJSON != nil }),
              existingCalls.count + batch.calls.count <= 5,
              (batch.assistantContent?.count ?? 0) <= 2_000,
              batch.calls.allSatisfy({ !$0.id.isEmpty && $0.id.count <= 128 && allowed.contains($0.name) && $0.argumentsJSON.utf8.count <= 12_000 && $0.resultJSON == nil && $0.sourceTitles.isEmpty && $0.placeID == nil }),
              Set((existingCalls + batch.calls).map(\.id)).count == existingCalls.count + batch.calls.count else { return false }
        toolJournals[entryID.uuidString] = previous + [batch]
        guard persist() else { toolJournals[entryID.uuidString] = previous; return false }
        return true
    }

    /// Read tools have no local commitment mutation; record their actual bounded result.
    @discardableResult
    func checkpointToolResult(entryID: UUID, result: CompanionHomeToolCheckpoint) -> Bool {
        guard !Task.isCancelled, let json = result.resultJSON, json.utf8.count <= 64_000,
              result.sourceTitles.count <= 20, result.sourceTitles.allSatisfy({ $0.count <= 600 }),
              let position = checkpointPosition(entryID: entryID, callID: result.id) else { return false }
        let key = entryID.uuidString
        let planned = toolJournals[key]?[position.0].calls[position.1]
        guard planned?.name == result.name, planned?.argumentsJSON == result.argumentsJSON else { return false }
        if planned?.resultJSON != nil { return planned == result }
        let previous = toolJournals[key]
        toolJournals[key]?[position.0].calls[position.1] = result
        guard persist() else { toolJournals[key] = previous; return false }
        return true
    }

    /// Commitment change and its exact tool result share one atomic snapshot write.
    /// A failed write restores both, so recovery cannot see an action without its receipt.
    func executeFollowUpCheckpoint(entryID: UUID, callID: String) -> CompanionHomeToolCheckpoint? {
        guard !Task.isCancelled, let position = checkpointPosition(entryID: entryID, callID: callID),
              let planned = toolJournals[entryID.uuidString]?[position.0].calls[position.1],
              planned.name == "manage_follow_up" else { return nil }
        if planned.resultJSON != nil { return planned }
        let previousCommitments = commitments
        let previousJournals = toolJournals
        let outcome: CompanionHomeFollowUpResult
        stagingToolResult = true
        do {
            let request = try CompanionHomeFollowUpRequest(argumentsJSON: planned.argumentsJSON)
            outcome = manageFollowUp(request, originEntryID: entryID)
        } catch { outcome = .init(success: false, error: "invalid_arguments_ask_for_missing_details") }
        stagingToolResult = false
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(outcome), let json = String(data: data, encoding: .utf8) else {
            commitments = previousCommitments
            return nil
        }
        var completed = planned
        completed.resultJSON = json
        toolJournals[entryID.uuidString]?[position.0].calls[position.1] = completed
        guard persist() else {
            commitments = previousCommitments
            toolJournals = previousJournals
            return nil
        }
        return completed
    }

    private func checkpointPosition(entryID: UUID, callID: String) -> (Int, Int)? {
        for (batchIndex, batch) in toolJournal(for: entryID).enumerated() {
            if let callIndex = batch.calls.firstIndex(where: { $0.id == callID }) { return (batchIndex, callIndex) }
        }
        return nil
    }

    /// Export only this store's full in-memory state, including unsent text and tool receipts.
    /// No credentials, service configuration, or unrelated local stores are read.
    func exportedSnapshotData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(currentSnapshot())
    }

    /// Call only after the settings UI receives explicit confirmation to clear local data.
    /// Replace exact known files with valid empty snapshots; never enumerate directories.
    @discardableResult
    func clearLocalData() -> Bool {
        cancel() // Invalidates both attempt identity and the owned task before touching storage.
        let manager = FileManager.default
        let recoveryURL = originalURL.appendingPathExtension("recovery.json")
        var targets = [originalURL]
        if recoveryURL != originalURL && (recoveryURL == url || manager.fileExists(atPath: recoveryURL.path)) {
            targets.append(recoveryURL)
        }
        if !targets.contains(url) { targets.append(url) }
        var prepared: [(url: URL, bytes: Data?)] = []
        var attempted: [(url: URL, bytes: Data?)] = []
        do {
            let empty = Snapshot(entries: [], composerDraft: "", people: [], selectedPeopleIDs: [], invites: [], commitments: [], toolJournals: [:])
            let data = try JSONEncoder().encode(empty)
            // Read only the exact files we might overwrite so a partial failure can roll back.
            for target in targets {
                guard target.isFileURL else { throw CocoaError(.fileWriteUnsupportedScheme) }
                if manager.fileExists(atPath: target.path) {
                    let attributes = try manager.attributesOfItem(atPath: target.path)
                    guard attributes[.type] as? FileAttributeType == .typeRegular else { throw CocoaError(.fileWriteNoPermission) }
                    prepared.append((target, try Data(contentsOf: target)))
                } else { prepared.append((target, nil)) }
            }
            for backup in prepared {
                try manager.createDirectory(at: backup.url.deletingLastPathComponent(), withIntermediateDirectories: true)
                attempted.append(backup)
                try data.write(to: backup.url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            }
            isLoading = true
            entries = []
            composerDraft = ""
            storedPeople = []
            selectedPeopleIDs = []
            invites = []
            commitments = []
            toolJournals = [:]
            draftAttachments = []
            draftQuote = nil
            isLoading = false
            storageBlocked = false
            url = originalURL
            errorMessage = nil
            activity = .idle
            return true
        } catch {
            var rollbackIncomplete = false
            for backup in attempted.reversed() {
                do {
                    if let bytes = backup.bytes {
                        // Avoid needless writes when the failed atomic operation left bytes intact.
                        if (try? Data(contentsOf: backup.url)) != bytes {
                            try bytes.write(to: backup.url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                        }
                    } else if manager.fileExists(atPath: backup.url.path) {
                        let attributes = try manager.attributesOfItem(atPath: backup.url.path)
                        guard attributes[.type] as? FileAttributeType == .typeRegular else { throw CocoaError(.fileWriteNoPermission) }
                        try manager.removeItem(at: backup.url)
                    }
                } catch { rollbackIncomplete = true }
            }
            errorMessage = rollbackIncomplete
                ? NSLocalizedString("companion.clear_partial", value: "部分文件未能恢复，清空未完成。当前记录仍在页面中，请先导出并稍后重试。", comment: "Partial clear failure")
                : NSLocalizedString("companion.clear_failed", value: "未能清空本机记录，内容仍已保留，请稍后重试。", comment: "Clear failure")
            return false
        }
    }

    private func currentSnapshot() -> Snapshot {
        Snapshot(entries: entries, composerDraft: composerDraft, people: people,
                 selectedPeopleIDs: selectedPeopleIDs, invites: invites,
                 commitments: commitments, toolJournals: toolJournals,
                 draftAttachments: draftAttachments, draftQuote: draftQuote)
    }

    func clearError() { errorMessage = nil }

    private func run(id: UUID) async {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        guard let agent else {
            entries[index].status = .failed
            activity = .failed(id)
            errorMessage = NSLocalizedString("companion.service_unavailable", value: "暂时无法回应，原话已保留，可以稍后重试。", comment: "Companion unavailable")
            persist()
            return
        }
        let attemptID = UUID()
        activeAttemptID = attemptID
        isWorking = true
        activity = .working(id)
        activeID = id
        entries[index].status = .working
        guard persist() else {
            isWorking = false; activeID = nil; activeAttemptID = nil
            entries[index].status = .failed; activity = .failed(id)
            return
        }
        errorMessage = nil
        // Retry a past input with the history that preceded it, never later user turns.
        let context = Array(entries.prefix(index + 1))
        let task = Task { try await agent.respond(to: context) }
        activeTask = task
        var responded = false
        do {
            let result = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: { task.cancel() }
            guard activeID == id, activeAttemptID == attemptID else { return }
            try Task.checkCancellation()
            guard !task.isCancelled else { throw CancellationError() }
            entries[index].status = .delivered
            if let responseIndex = entries.firstIndex(where: { $0.replyToID == id }) {
                entries[responseIndex].text = result.text
                entries[responseIndex].sourceTitles = result.sourceTitles
                entries[responseIndex].placeID = result.placeID
                entries[responseIndex].status = .delivered
            } else {
                let response = CompanionHomeEntry(role: .companion, text: result.text, status: .delivered,
                                                  sourceTitles: result.sourceTitles, placeID: result.placeID, replyToID: id)
                entries.insert(response, at: index + 1)
            }
            responded = true
        } catch {
            guard activeID == id, activeAttemptID == attemptID else { return }
            entries[index].status = .failed
            // Never surface raw network response bodies, credentials, or model diagnostics.
            if errorMessage == nil {
                errorMessage = NSLocalizedString("companion.response_failed", value: "这次没有完成，原话已保留，可以重试。", comment: "Companion failed")
            }
        }
        activeTask = nil
        activeID = nil
        activeAttemptID = nil
        isWorking = false
        let saved = persist()
        if !saved { entries[index].status = .failed }
        activity = responded && saved ? .completed(id) : .failed(id)
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let snapshot = try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: url))
            guard snapshot.version == 1 else { throw CocoaError(.fileReadCorruptFile) }
            entries = snapshot.entries.map { entry in
                var restored = entry
                if restored.status == .working { restored.status = .failed }
                return restored
            }
            commitments = snapshot.commitments ?? []
            toolJournals = snapshot.toolJournals ?? [:]
            draftAttachments = snapshot.draftAttachments ?? []
            draftQuote = snapshot.draftQuote
            composerDraft = snapshot.composerDraft
            people = snapshot.people
            selectedPeopleIDs = snapshot.selectedPeopleIDs.intersection(Set(people.map(\.id)))
            invites = snapshot.invites.map { value in var draft = value; draft.status = .draft; return draft }
        } catch {
            // Preserve the original bytes at the original URL. Save new work to a distinct
            // recovery namespace; never silently replace a damaged or future-version store.
            if url.lastPathComponent.hasSuffix(".recovery.json") {
                storageBlocked = true
            } else {
                url = url.appendingPathExtension("recovery.json")
                if FileManager.default.fileExists(atPath: url.path) { load() }
            }
            errorMessage = NSLocalizedString("companion.storage_recovery", value: "旧记录暂时无法读取，原文件已保留。新内容将另行保存。", comment: "Recovery")
        }
    }

    @discardableResult
    private func persist() -> Bool {
        guard !isLoading, !stagingToolResult else { return true }
        guard !storageBlocked else {
            errorMessage = NSLocalizedString("companion.storage_failed", value: "暂时无法保存到本机，请保留当前页面后重试。", comment: "Storage failure")
            return false
        }
        do {
            let directory = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(currentSnapshot())
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            storageBlocked = false
            return true
        } catch {
            errorMessage = NSLocalizedString("companion.storage_failed", value: "暂时无法保存到本机，请保留当前页面后重试。", comment: "Storage failure")
            return false
        }
    }
}

private func companionMediaText(_ key: String, _ fallback: String) -> String {
    NSLocalizedString(key, value: fallback, comment: "Conversation media")
}
