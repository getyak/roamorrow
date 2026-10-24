import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Shared attachment ingestion; each composer owns its draft and picker state.
enum ChatAttachmentDecoder {
    static func photoDrafts(_ items: [PhotosPickerItem]) async -> [LocalAttachment] {
        var drafts: [LocalAttachment] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
            let mime = item.supportedContentTypes.first?.preferredMIMEType ?? "image/jpeg"
            drafts.append(await imageDraft(data: data, fileName: "image-\(UUID().uuidString.prefix(8)).\(ext)", mimeType: mime))
        }
        return drafts
    }

    static func fileDrafts(_ urls: [URL]) async -> [LocalAttachment] {
        var drafts: [LocalAttachment] = []
        for url in urls {
            if let draft = await fileDraft(url) { drafts.append(draft) }
        }
        return drafts
    }

    static func cameraDraft(_ image: UIImage) -> LocalAttachment? {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
        return LocalAttachment(kind: .image, fileName: "camera-\(UUID().uuidString.prefix(8)).jpg", mimeType: "image/jpeg", data: data, image: image)
    }

    /// Decode image bytes into a preview-ready draft off the main actor.
    /// `preparingForDisplay()` forces the decode now instead of lazily on the
    /// render thread at first draw.
    static func imageDraft(data: Data, fileName: String, mimeType: String) async -> LocalAttachment {
        let prepared: UIImage? = await Task.detached(priority: .userInitiated) {
            guard let raw = UIImage(data: data) else { return nil }
            return raw.preparingForDisplay() ?? raw
        }.value
        return LocalAttachment(
            kind: .image,
            fileName: fileName,
            mimeType: mimeType,
            data: data,
            image: prepared
        )
    }

    /// Read one picked file off the main actor: opens its security scope, reads
    /// the bytes, and (for images) decodes a preview. Returns nil on read failure.
    static func fileDraft(_ url: URL) async -> LocalAttachment? {
        await Task.detached(priority: .userInitiated) {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { return nil }
            let type = UTType(filenameExtension: url.pathExtension)
            let isImage = type?.conforms(to: .image) ?? false
            let mime = type?.preferredMIMEType ?? "application/octet-stream"
            let image = isImage ? UIImage(data: data)?.preparingForDisplay() : nil
            return LocalAttachment(
                kind: isImage ? .image : .file,
                fileName: url.lastPathComponent,
                mimeType: mime,
                data: data,
                image: image
            )
        }.value
    }
}
