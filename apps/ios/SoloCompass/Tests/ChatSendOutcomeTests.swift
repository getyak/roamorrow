import XCTest
@testable import SoloCompass

/// I24: `ChatService.send` must return a structured `SendOutcome` so the
/// composer can keep the user's draft until a send is actually acknowledged.
/// These tests exercise the REAL `ChatService` send pipeline through the
/// injectable `SupabaseClientProtocol` / `AttachmentUploading` seams — no
/// network, no credentials, no real contacts.
///
/// Covered branches (per the settled contract):
///  - backend / text-row failure      → `.notSent`, nothing appended
///  - attachment-only upload failure  → `.notSent`, no row written at all
///  - partial text success (degrade)  → `.textSentAttachmentsFailed`, text row
///    written exactly once (a retry must not resend it)
///  - true success                    → `.sent`
///  - auth-missing / gated sends are NOT silently treated as success.
@MainActor
final class ChatSendOutcomeTests: XCTestCase {

    // MARK: - Fakes

    final class SendTestClient: SupabaseClientProtocol {
        var currentSession: SupabaseClient.Session? = SupabaseClient.Session(
            userId: "user_sendtest",
            accessToken: "tok",
            refreshToken: "ref",
            expiresAt: Date().addingTimeInterval(3600)
        )
        /// Set to a failure to simulate the chat_messages insert failing.
        var postResult: Result<Data, SupabaseClient.SupabaseError> = .success(Data())
        private(set) var postCallCount = 0
        private(set) var postedBodies: [Data] = []

        func signInAnonymously() async -> Result<SupabaseClient.Session, SupabaseClient.SupabaseError> { .failure(.backendDisabled) }
        func refreshSession() async -> Result<SupabaseClient.Session, SupabaseClient.SupabaseError> { .failure(.backendDisabled) }
        func post(table: String, body: Data) async -> Result<Data, SupabaseClient.SupabaseError> {
            postCallCount += 1
            postedBodies.append(body)
            return postResult
        }
        func get(table: String, query: [URLQueryItem]) async -> Result<Data, SupabaseClient.SupabaseError> { .success(Data()) }
        func invoke(function: String, body: Data) async -> Result<Data, SupabaseClient.SupabaseError> { .success(Data()) }
        func delete(table: String, id: String) async -> Result<Void, SupabaseClient.SupabaseError> { .success(()) }
        func linkAppleIdentity(identityToken: String, nonce: String) async -> Result<SupabaseClient.Session, SupabaseClient.SupabaseError> { .failure(.backendDisabled) }
        var isAnonymous: Bool { get async { false } }
    }

    final class SendTestUploader: AttachmentUploading {
        /// When true every upload throws `.backendNotReady` (the documented
        /// degrade trigger).
        var failUploads = false
        private(set) var uploadCallCount = 0
        var pauseNextUpload = false
        var onPaused: (() -> Void)?
        private var pausedUpload: CheckedContinuation<Void, Never>?

        func resumeUpload() {
            pausedUpload?.resume()
            pausedUpload = nil
        }

        func upload(_ local: LocalAttachment, conversationId: String, messageId: String) async throws -> ChatAttachment {
            uploadCallCount += 1
            if pauseNextUpload {
                pauseNextUpload = false
                await withCheckedContinuation { continuation in
                    pausedUpload = continuation
                    onPaused?()
                }
            }
            if failUploads { throw AttachmentError.backendNotReady }
            return ChatAttachment(
                id: "att-\(local.id)",
                kind: local.kind,
                fileName: local.fileName,
                mimeType: local.mimeType,
                fileSizeBytes: local.data.count,
                storagePath: "\(conversationId)/\(messageId)/\(local.fileName)"
            )
        }

        func signedURL(for attachment: ChatAttachment) async throws -> URL {
            URL(fileURLWithPath: "/tmp/\(attachment.id)")
        }
    }

    // MARK: - Fixtures

    private var client: SendTestClient!
    private var uploader: SendTestUploader!
    private var service: ChatService!

    /// `FeatureFlags.companion` short-circuits `send` when off; pin it ON for
    /// the duration of each test so the real pipeline runs deterministically.
    private var savedFlagDefault: Any?
    private var savedFlagEnv: String?

    override func setUp() async throws {
        try await super.setUp()
        savedFlagDefault = UserDefaults.standard.object(forKey: "FF_COMPANION")
        savedFlagEnv = getenv("FF_COMPANION").map { String(cString: $0) }
        UserDefaults.standard.set(true, forKey: "FF_COMPANION")
        setenv("FF_COMPANION", "1", 1)

        client = SendTestClient()
        uploader = SendTestUploader()
        service = ChatService(
            conversationId: ConversationId(rawValue: "conv_sendtest"),
            client: client,
            attachmentService: uploader
        )
    }

    override func tearDown() async throws {
        service = nil
        client = nil
        uploader = nil
        if let savedFlagDefault {
            UserDefaults.standard.set(savedFlagDefault, forKey: "FF_COMPANION")
        } else {
            UserDefaults.standard.removeObject(forKey: "FF_COMPANION")
        }
        if let savedFlagEnv { setenv("FF_COMPANION", savedFlagEnv, 1) } else { unsetenv("FF_COMPANION") }
        try await super.tearDown()
    }

    private func sampleAttachment() -> LocalAttachment {
        LocalAttachment(
            kind: .image,
            fileName: "photo.jpg",
            mimeType: "image/jpeg",
            data: Data([0xFF, 0xD8, 0xFF, 0xD9])
        )
    }

    func testOversizedMessageKeepsEntireDraftUnsent() async {
        let outcome = await service.send(String(repeating: "x", count: 1001))
        guard case .notSent(let reason) = outcome else { return XCTFail("Oversized text must not be truncated and acknowledged") }
        XCTAssertNotNil(reason)
        XCTAssertEqual(client.postCallCount, 0)
        XCTAssertTrue(service.messages.isEmpty)
    }

    // MARK: - True success

    @MainActor
    func testTrueSuccessReturnsSentAndAppendsExactlyOneMessage() async {
        let outcome = await service.send("hello", attachments: [sampleAttachment()])

        guard case .sent = outcome else {
            return XCTFail("Expected .sent, got \(outcome)")
        }
        XCTAssertEqual(client.postCallCount, 1, "the row must be written exactly once")
        XCTAssertEqual(service.messages.count, 1)
        XCTAssertEqual(service.messages.first?.body, "hello")
        XCTAssertEqual(service.messages.first?.attachments?.count, 1,
                       "a successful send keeps its uploaded attachments")
    }

    // MARK: - Partial text success (documented degrade)

    @MainActor
    func testUploadFailureWithTextStillSendsTextAndReportsAttachmentsFailed() async {
        uploader.failUploads = true

        let outcome = await service.send("keep my words", attachments: [sampleAttachment()])

        guard case .textSentAttachmentsFailed = outcome else {
            return XCTFail("Expected .textSentAttachmentsFailed, got \(outcome)")
        }
        XCTAssertEqual(client.postCallCount, 1,
                       "the documented degrade still writes the text row")
        XCTAssertEqual(service.messages.count, 1)
        XCTAssertEqual(service.messages.first?.body, "keep my words")
        XCTAssertNil(service.messages.first?.attachments,
                     "dropped attachments must not be written into the row")
    }

    func testDelayedPartialSendRetriesAttachmentsWithoutResendingAcknowledgedText() async {
        let paused = expectation(description: "Upload suspended")
        uploader.pauseNextUpload = true
        uploader.failUploads = true
        uploader.onPaused = { paused.fulfill() }
        let files = [sampleAttachment()]
        let attempt = Task { await self.service.send("Meet at 6", attachments: files) }
        await fulfillment(of: [paused], timeout: 5)
        let editedDraft = "Meet at 6 please"
        uploader.resumeUpload()
        let first = await attempt.value
        guard case .textSentAttachmentsFailed = first else { return XCTFail("Expected partial delivery") }
        uploader.failUploads = false
        let retry = await AttachmentRetryBatch(attachments: files).send { text, attachments in
            XCTAssertEqual(text, "", "Retry cannot receive either old text or the edited draft")
            XCTAssertNotEqual(text, editedDraft)
            return await self.service.send(text, attachments: attachments)
        }
        XCTAssertEqual(retry, .sent)
        XCTAssertEqual(service.messages.map(\.body), ["Meet at 6", ""])
        XCTAssertEqual(service.messages.last?.attachments?.count, 1)
        XCTAssertEqual(client.postCallCount, 2)
    }

    // MARK: - Backend / text-row failure

    @MainActor
    func testTextRowInsertFailureReturnsNotSentAndAppendsNothing() async {
        client.postResult = .failure(.requestFailed(status: 500, body: "boom"))

        let outcome = await service.send("not delivered", attachments: [sampleAttachment()])

        guard case .notSent(let reason) = outcome else {
            return XCTFail("Expected .notSent, got \(outcome)")
        }
        XCTAssertNotNil(reason, "a failed insert must carry a user-presentable reason")
        XCTAssertTrue(service.messages.isEmpty,
                      "nothing may be appended when the row insert failed")
    }

    // MARK: - Attachment-only failure

    @MainActor
    func testAttachmentOnlySendWithFailedUploadsWritesNoRow() async {
        uploader.failUploads = true

        let outcome = await service.send("", attachments: [sampleAttachment()])

        guard case .notSent = outcome else {
            return XCTFail("Expected .notSent for an attachment-only failure, got \(outcome)")
        }
        XCTAssertEqual(client.postCallCount, 0,
                        "an attachment-only failure must not write an empty row")
        XCTAssertTrue(service.messages.isEmpty)
    }

    // MARK: - Auth-missing and gated sends are never "success"

    @MainActor
    func testMissingSessionIsNotSentNotSuccess() async {
        client.currentSession = nil

        let outcome = await service.send("who am I", attachments: [])

        guard case .notSent(let reason) = outcome else {
            return XCTFail("Expected .notSent without a session, got \(outcome)")
        }
        XCTAssertNotNil(reason, "auth-missing must explain itself")
        XCTAssertEqual(client.postCallCount, 0)
    }

    @MainActor
    func testGatedSendIsNotSentNotSuccess() async {
        UserDefaults.standard.set(false, forKey: "FF_COMPANION")
        defer { UserDefaults.standard.set(true, forKey: "FF_COMPANION") }

        let outcome = await service.send("gated", attachments: [])

        guard case .notSent = outcome else {
            return XCTFail("A gated send must not be reported as success, got \(outcome)")
        }
        XCTAssertEqual(client.postCallCount, 0)
        XCTAssertTrue(service.messages.isEmpty)
    }

    // MARK: - Outcome semantics for the composer

    /// The composer relies on this contract: only `.sent` clears both text and
    /// attachments; `.textSentAttachmentsFailed` must be distinguishable from
    /// `.sent` so the text is never resent with the attachment retry.
    @MainActor
    func testDegradeOutcomeIsDistinctFromFullSuccess() async {
        XCTAssertNotEqual(
            ChatService.SendOutcome.sent,
            ChatService.SendOutcome.textSentAttachmentsFailed("x"),
            "the composer must be able to tell a degraded send from a full one"
        )
        XCTAssertNotEqual(
            ChatService.SendOutcome.sent,
            ChatService.SendOutcome.notSent(nil)
        )
    }
}
