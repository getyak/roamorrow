import UIKit
import XCTest
@testable import SoloCompass

@MainActor
final class ChatAttachmentDecoderTests: XCTestCase {
    func testFileBatchPreservesOrderAndSkipsUnreadableFiles() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = directory.appendingPathComponent("first.txt")
        let second = directory.appendingPathComponent("second.pdf")
        try Data("first".utf8).write(to: first)
        try Data("second".utf8).write(to: second)
        let drafts = await ChatAttachmentDecoder.fileDrafts([first, directory.appendingPathComponent("missing.txt"), second])
        XCTAssertEqual(drafts.map(\.fileName), ["first.txt", "second.pdf"])
        XCTAssertEqual(drafts.map(\.data), [Data("first".utf8), Data("second".utf8)])
        XCTAssertEqual(drafts.map(\.mimeType), ["text/plain", "application/pdf"])
        XCTAssertTrue(drafts.allSatisfy { $0.kind == .file && $0.image == nil })
    }

    func testCameraAndImageDraftPreserveImageDataAndMetadata() async throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 3)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 3))
        }
        let camera = try XCTUnwrap(ChatAttachmentDecoder.cameraDraft(image))
        XCTAssertEqual(camera.kind, .image)
        XCTAssertEqual(camera.mimeType, "image/jpeg")
        XCTAssertTrue(camera.fileName.hasPrefix("camera-"))
        XCTAssertNotNil(UIImage(data: camera.data))
        let data = try XCTUnwrap(image.pngData())
        let draft = await ChatAttachmentDecoder.imageDraft(data: data, fileName: "picked.png", mimeType: "image/png")
        XCTAssertEqual(draft.data, data)
        XCTAssertEqual(draft.fileName, "picked.png")
        XCTAssertEqual(draft.mimeType, "image/png")
        XCTAssertNotNil(draft.image)
    }

    func testEmptyPickBatchesProduceNoDrafts() async {
        let photos = await ChatAttachmentDecoder.photoDrafts([])
        let files = await ChatAttachmentDecoder.fileDrafts([])
        XCTAssertTrue(photos.isEmpty)
        XCTAssertTrue(files.isEmpty)
    }
}
