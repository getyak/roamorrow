import Foundation
import UIKit

/// Persists photos a user attaches to a place they create.
///
/// Phase 1 stores images in the app's Application Support directory and returns
/// `file://` URLs, which go straight into `ExperienceLocation.photoUrls`. When
/// Phase 2 adds upload sync, the same field is repopulated with remote https
/// URLs and these local files can be cleaned up — the schema doesn't change.
enum PlacePhotoStore {
    /// Why a single image write failed. Surfaced so callers can retain the
    /// raw image and offer a retry instead of dropping it silently (R2-10).
    enum PlacePhotoWriteError: Error, Equatable {
        case directoryUnavailable
        case encodeFailed
        case writeFailed(String)
    }

    /// Per-image outcome of a batch write — one entry per input image,
    /// positionally paired. A batch NEVER silently drops an image.
    enum ItemWriteResult: Equatable {
        case saved(url: String)
        case failed(index: Int, error: PlacePhotoWriteError)
    }

    /// Subdirectory under Application Support that holds user place photos.
    private static let folderName = "UserPlacePhotos"

    private static var folderURL: URL? {
        guard
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return nil }
        let dir = base.appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Write a single image to disk as JPEG and return its `file://` URL
    /// string. Throws on any failure so the caller decides — retain + retry,
    /// or explicitly omit — instead of losing the photo (R2-10).
    ///
    /// - Parameters:
    ///   - image: the picked or captured image.
    ///   - uuid: a caller-supplied unique id so filenames stay deterministic
    ///           for tests (e.g. `UUID().uuidString`).
    ///   - quality: JPEG compression quality (0–1). Defaults to 0.8.
    static func saveThrowing(_ image: UIImage, uuid: String, quality: CGFloat = 0.8) throws -> String {
        guard let dir = folderURL else {
            throw PlacePhotoWriteError.directoryUnavailable
        }
        guard let data = image.jpegData(compressionQuality: quality) else {
            throw PlacePhotoWriteError.encodeFailed
        }
        let fileURL = dir.appendingPathComponent("photo_\(uuid).jpg")
        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL.absoluteString
        } catch {
            throw PlacePhotoWriteError.writeFailed(String(describing: error))
        }
    }

    /// Non-throwing compatibility wrapper. Prefer `saveThrowing` — a nil here
    /// cannot tell encode failures from write failures.
    static func save(_ image: UIImage, uuid: String, quality: CGFloat = 0.8) -> String? {
        try? saveThrowing(image, uuid: uuid, quality: quality)
    }

    /// Write several images with a positional result per image. The `uuids`
    /// array must be at least as long as `images`; extra ids are ignored and
    /// indices pair positionally so retries stay deterministic.
    static func saveAll(_ images: [UIImage], uuids: [String]) -> [ItemWriteResult] {
        var results: [ItemWriteResult] = []
        results.reserveCapacity(images.count)
        for (index, image) in images.enumerated() {
            let uuid = index < uuids.count ? uuids[index] : UUID().uuidString
            do {
                let url = try saveThrowing(image, uuid: uuid)
                results.append(.saved(url: url))
            } catch let error as PlacePhotoWriteError {
                results.append(.failed(index: index, error: error))
            } catch {
                results.append(.failed(index: index, error: .writeFailed(String(describing: error))))
            }
        }
        return results
    }

    /// Legacy batch write returning only the URLs that succeeded. Prefer
    /// `saveAll`, which reports every outcome — this helper cannot distinguish
    /// "user omitted a photo" from "the write silently failed".
    static func save(_ images: [UIImage], uuids: [String]) -> [String] {
        zip(images, uuids).compactMap { save($0, uuid: $1) }
    }

    /// Delete ONE photo file previously written by THIS store (review closure
    /// 5). Refuses to touch anything outside the `UserPlacePhotos` folder or
    /// not matching this store's `photo_*.jpg` naming — cleanup is strictly
    /// limited to files the current draft wrote; old user photos are never
    /// removed and there is no broad sweep.
    @discardableResult
    static func removeDraftFile(_ urlString: String) -> Bool {
        guard let base = folderURL, let url = URL(string: urlString) else { return false }
        let basePath = base.path + "/"
        guard url.path.hasPrefix(basePath) else { return false }
        let name = url.lastPathComponent
        guard name.hasPrefix("photo_"), url.pathExtension == "jpg" else { return false }
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - PlacePhotoDraftBatch

/// Identity + receipt bookkeeping for the create-place photo draft (review
/// closure 5). Pure logic — batch identity and invalidation are unit-tested
/// without UIKit images.
///
/// Guarantees:
///   - every draft image gets a STABLE id at insert time, so retries write the
///     same `photo_<id>.jpg` instead of accumulating duplicate output files;
///   - the receipt of a failed save attempt is valid ONLY while the batch is
///     unchanged — editing (add/remove) invalidates it, so the explicit-omit
///     path can never save a removed image nor silently drop a newly picked
///     one;
///   - `clearAttempt()` is the explicit return-to-edit action.
struct PlacePhotoDraftBatch: Equatable {
    /// The outcome of the last save attempt, tied to the exact image ids it
    /// wrote.
    struct Attempt: Equatable {
        let imageIds: [String]
        let savedUrls: [String]
        let failedIndices: [Int]
    }

    /// Stable per-image ids, in image order.
    private(set) var imageIds: [String] = []
    private(set) var lastAttempt: Attempt?

    init(imageIds: [String] = []) {
        self.imageIds = imageIds
    }

    /// Append a new draft image. The id is assigned ONCE and kept across
    /// retries. Any edit invalidates a pending attempt receipt.
    mutating func appendImage(id: String = UUID().uuidString) {
        imageIds.append(id)
        lastAttempt = nil
    }

    /// Remove a draft image (by index). Returns the removed id. Invalidates a
    /// pending attempt receipt — its saved URLs may reference the removed
    /// image and must not be reused.
    @discardableResult
    mutating func removeImage(at index: Int) -> String? {
        guard imageIds.indices.contains(index) else { return nil }
        let removed = imageIds.remove(at: index)
        lastAttempt = nil
        return removed
    }

    /// Record a batch write attempt against the CURRENT ids.
    mutating func recordAttempt(savedUrls: [String], failedIndices: [Int]) {
        lastAttempt = Attempt(
            imageIds: imageIds,
            savedUrls: savedUrls,
            failedIndices: failedIndices
        )
    }

    /// True only when no edit happened since the attempt — the only case in
    /// which the attempt's receipts may drive the explicit-omit path.
    var isAttemptCurrent: Bool {
        guard let lastAttempt else { return false }
        return lastAttempt.imageIds == imageIds
    }

    /// Saved URLs usable for explicit omit (nil when the receipt is stale).
    var omitCandidateUrls: [String]? {
        isAttemptCurrent ? lastAttempt?.savedUrls : nil
    }

    /// The explicit return-to-edit action: drop the receipt and unlock photo
    /// editing.
    mutating func clearAttempt() {
        lastAttempt = nil
    }
}
