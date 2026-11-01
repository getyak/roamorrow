import XCTest
import UIKit
@testable import SoloCompass

@MainActor
final class CompanionHomeMediaTests: XCTestCase {
    private func location() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("media-tests-\(UUID())/v1.json") }
    private func file() -> CompanionMediaAttachment {
        .init(kind: .file, name: "行程.txt", mimeType: "text/plain", data: Data("原件正文".utf8), extractedText: "原件正文")
    }
    func testLegacyEntryAndSnapshotDecodeWithNoMedia() async throws {
        let entry = CompanionHomeEntry(role: .user, text: "旧原话")
        let data = try JSONEncoder().encode(entry)
        XCTAssertNil(try JSONDecoder().decode(CompanionHomeEntry.self, from: data).attachments)
        let store = CompanionHomeStore(url: location())
        await store.send(text: "旧原话")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: store.exportedSnapshotData()) as? [String: Any])
        var legacy = json
        legacy.removeValue(forKey: "draftAttachments")
        legacy.removeValue(forKey: "draftQuote")
        let url = location()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: legacy).write(to: url)
        XCTAssertEqual(CompanionHomeStore(url: url).entries.first?.text, "旧原话")
    }
    func testAttachmentOnlySubmissionRetryAndRestartRetainOneOriginal() async throws {
        let url = location()
        let store = CompanionHomeStore(url: url)
        let attachment = file()
        XCTAssertTrue(store.stageAttachment(attachment))
        XCTAssertEqual(CompanionHomeStore(url: url).draftAttachments, [attachment])
        await store.send() // No agent configured: real failure, original retained.
        let entry = try XCTUnwrap(store.entries.first)
        XCTAssertEqual(entry.attachments, [attachment])
        XCTAssertEqual(entry.status, .failed)
        XCTAssertTrue(store.draftAttachments.isEmpty)
        await store.retry(id: entry.id)
        let restored = CompanionHomeStore(url: url)
        XCTAssertEqual(restored.entries.count, 1)
        XCTAssertEqual(restored.entries.first?.id, entry.id)
        XCTAssertEqual(restored.entries.first?.attachments?.first?.data, attachment.data)
        XCTAssertTrue(restored.draftAttachments.isEmpty)
    }
    func testFailedAtomicSubmissionKeepsMediaTextAndQuote() async throws {
        let url = location()
        let store = CompanionHomeStore(url: url)
        let attachment = file()
        XCTAssertTrue(store.stageAttachment(attachment))
        store.composerDraft = "别丢草稿"
        let quote = CompanionQuotedMessage(entryID: UUID(), role: .companion, text: "引用原话")
        store.setDraftQuote(quote)
        let directory = url.deletingLastPathComponent()
        try FileManager.default.moveItem(at: directory, to: directory.appendingPathExtension("preserved"))
        try Data().write(to: directory)
        await store.send()
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertEqual(store.composerDraft, "别丢草稿")
        XCTAssertEqual(store.draftAttachments, [attachment])
        XCTAssertEqual(store.draftQuote, quote)
    }
    func testExportContainsActualMediaBytesAndConfirmedClearDropsThem() throws {
        let url = location()
        let store = CompanionHomeStore(url: url)
        let attachment = file()
        XCTAssertTrue(store.stageAttachment(attachment))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: store.exportedSnapshotData()) as? [String: Any])
        let media = try XCTUnwrap(json["draftAttachments"] as? [[String: Any]])
        XCTAssertEqual(media.first?["data"] as? String, attachment.data?.base64EncodedString())
        XCTAssertTrue(store.clearLocalData())
        XCTAssertTrue(CompanionHomeStore(url: url).draftAttachments.isEmpty)
    }
    func testImageAndTextFilePreserveOriginalBytesAndExtractOnlyRealText() async throws {
        let url = location().deletingLastPathComponent().appendingPathComponent("行程.txt")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let bytes = Data("明天去书店，再喝咖啡。".utf8)
        try bytes.write(to: url)
        let file = try await CompanionMediaPreparation.file(url)
        XCTAssertEqual(file.data, bytes)
        XCTAssertEqual(file.extractedText, "明天去书店，再喝咖啡。")
        let png = UIGraphicsImageRenderer(size: CGSize(width: 60, height: 40)).image { _ in
            UIColor.green.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 60, height: 40))
        }.pngData()!
        let photo = try await CompanionMediaPreparation.image(png, name: "sample.png")
        XCTAssertEqual(photo.data, png)
        XCTAssertEqual(photo.mimeType, "image/png")
        XCTAssertNil(photo.extractedText)
    }

    func testPhotoTextIsRecognizedFromActualPixels() async throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 900, height: 180)).image { _ in
            UIColor.white.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 900, height: 180))
            ("CHIANG MAI CAFE" as NSString).draw(at: CGPoint(x: 35, y: 50), withAttributes: [
                .font: UIFont.systemFont(ofSize: 70, weight: .bold), .foregroundColor: UIColor.black])
        }
        let bytes = try XCTUnwrap(image.pngData())
        let prepared = try await CompanionMediaPreparation.image(bytes)
        XCTAssertEqual(prepared.data, bytes)
        XCTAssertTrue(prepared.extractedText?.uppercased().contains("CHIANG MAI") == true)
    }
    func testPDFTextIsExtractedWhileOriginalBytesAreRetained() async throws {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 500, height: 200))
        let bytes = renderer.pdfData { context in
            context.beginPage()
            ("A quiet afternoon in Chiang Mai" as NSString).draw(at: CGPoint(x: 30, y: 70), withAttributes: [.font: UIFont.systemFont(ofSize: 20)])
        }
        let url = location().deletingLastPathComponent().appendingPathComponent("plan.pdf")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try bytes.write(to: url)
        let prepared = try await CompanionMediaPreparation.file(url)
        XCTAssertEqual(prepared.data, bytes)
        XCTAssertTrue(prepared.extractedText?.contains("quiet afternoon") == true)
    }

    func testQuoteAndOwnReactionPersistWithoutChangingRetryParent() async throws {
        let url = location()
        let store = CompanionHomeStore(url: url)
        await store.send(text: "第一句")
        let id = try XCTUnwrap(store.entries.first?.id)
        store.toggleReaction(entryID: id)
        store.setDraftQuote(.init(entryID: id, role: .user, text: "第一句"))
        store.composerDraft = "接着说"
        await store.send()
        let restored = CompanionHomeStore(url: url)
        XCTAssertEqual(restored.entries.first?.reaction, "heart")
        XCTAssertEqual(restored.entries.last?.quotedMessage?.entryID, id)
        XCTAssertNil(restored.entries.last?.replyToID)
        store.toggleReaction(entryID: id)
        XCTAssertNil(CompanionHomeStore(url: url).entries.first?.reaction)
    }

    func testPlacePickerUsesCurrentCityRatherThanUnscopedHistory() throws {
        let example = try XCTUnwrap(ExperienceService.hardcodedSeed.first)
        XCTAssertTrue(CompanionMediaPlaceScope.includes(example, cityCode: example.location.cityCode))
        XCTAssertFalse(CompanionMediaPlaceScope.includes(example, cityCode: "different-city-491"))
    }

    func testMediaLimitsAndInvalidCoordinates() {
        let store = CompanionHomeStore(url: location())
        for _ in 0..<4 { XCTAssertTrue(store.stageAttachment(file())) }
        XCTAssertFalse(store.stageAttachment(file()))
        XCTAssertFalse(store.canStartRecording)
        var invalid = file()
        invalid.data = Data(repeating: 0, count: 10 * 1_024 * 1_024 + 1)
        XCTAssertFalse(invalid.isValid)
        let place = CompanionMediaAttachment(kind: .place, name: "地点", mimeType: "application/x-roamorrow-place",
            place: .init(experienceID: "existing", name: "地点", latitude: 200, longitude: 0))
        XCTAssertFalse(place.isValid)
    }

    func testVoiceTranscriptReplacesOnlyItsRecordingAndRestoresEditableDraft() throws {
        let url = location()
        let store = CompanionHomeStore(url: url)
        let voice = CompanionMediaAttachment(kind: .audio, name: "Voice.m4a", mimeType: "audio/mp4", data: Data([1, 2, 3]), duration: 2)
        let other = file()
        let quote = CompanionQuotedMessage(entryID: UUID(), role: .companion, text: "引用原话")
        store.composerDraft = "已有草稿"
        store.setDraftQuote(quote)
        XCTAssertTrue(store.stageAttachment(voice))
        XCTAssertTrue(store.stageAttachment(other))
        XCTAssertTrue(store.useVoiceTranscript(id: voice.id, text: "  想去喝咖啡。\n"))
        XCTAssertEqual(store.composerDraft, "已有草稿\n想去喝咖啡。")
        XCTAssertEqual(store.draftAttachments, [other])
        XCTAssertEqual(store.draftQuote, quote)
        let restored = CompanionHomeStore(url: url)
        XCTAssertEqual(restored.composerDraft, store.composerDraft)
        XCTAssertEqual(restored.draftAttachments, [other])
        XCTAssertEqual(restored.draftQuote, quote)
        XCTAssertFalse(store.useVoiceTranscript(id: voice.id, text: "重复结果"))
        XCTAssertEqual(store.composerDraft, restored.composerDraft)
    }

    func testEmptyMissingAndNonAudioTranscriptsPreserveDrafts() {
        let store = CompanionHomeStore(url: location())
        let voice = CompanionMediaAttachment(kind: .audio, name: "Voice.m4a", mimeType: "audio/mp4", data: Data([1, 2, 3]), duration: 2)
        let other = file()
        store.composerDraft = "保持原样"
        XCTAssertTrue(store.stageAttachment(voice))
        XCTAssertTrue(store.stageAttachment(other))
        XCTAssertFalse(store.useVoiceTranscript(id: voice.id, text: " \n "))
        XCTAssertFalse(store.useVoiceTranscript(id: UUID(), text: "过期结果"))
        XCTAssertFalse(store.useVoiceTranscript(id: other.id, text: "文件不可转为语音文字"))
        XCTAssertEqual(store.composerDraft, "保持原样")
        XCTAssertEqual(store.draftAttachments, [voice, other])
        XCTAssertTrue(store.entries.isEmpty)
    }

    func testVoiceConversionWriteFailureKeepsOriginalDraftAndRecording() throws {
        let url = location()
        let store = CompanionHomeStore(url: url)
        let voice = CompanionMediaAttachment(kind: .audio, name: "Voice.m4a", mimeType: "audio/mp4", data: Data([1, 2, 3]), duration: 2)
        store.composerDraft = "不能丢"
        XCTAssertTrue(store.stageAttachment(voice))
        let directory = url.deletingLastPathComponent()
        try FileManager.default.moveItem(at: directory, to: directory.appendingPathExtension("preserved"))
        try Data().write(to: directory)
        XCTAssertFalse(store.useVoiceTranscript(id: voice.id, text: "转写结果"))
        XCTAssertEqual(store.composerDraft, "不能丢")
        XCTAssertEqual(store.draftAttachments, [voice])
        XCTAssertNotNil(store.errorMessage)
    }
    func testModelContextContainsExtractedTextButNoBinaryAndNeverInventsContents() {
        let item = file()
        let entry = CompanionHomeEntry(role: .user, text: "看看", attachments: [item])
        let context = CompanionHomeAgent.messageContent(entry)
        XCTAssertTrue(context.contains("原件正文"))
        XCTAssertFalse(context.contains(item.data?.base64EncodedString() ?? "missing"))
        var unsupported = item
        unsupported.extractedText = nil
        XCTAssertTrue(unsupported.modelContext.contains("No readable content"))
        XCTAssertTrue(unsupported.modelContext.contains("Do not infer"))
    }
}
