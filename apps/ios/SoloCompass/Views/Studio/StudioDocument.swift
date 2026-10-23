import Foundation
import Observation

/// A saved composition is data, not a regenerated image. Every edit keeps stable IDs.
struct StudioPiece: Identifiable, Codable, Equatable {
    enum Kind: String, Codable { case photo, coffee, book, note }
    var id = UUID()
    var kind: Kind
    var title: String
    var detail = ""
    var x = 0.5
    var y = 0.5
    var scale = 1.0
    var angle = 0.0
    var color = 0
    var original: Data?
    var cutout: Data?
    var createdAt = Date()
}

struct StudioDocument: Codable, Equatable {
    var version = 1
    var title = ""
    var paper = 0
    var background: Data?
    var pieces: [StudioPiece] = []
}

@MainActor @Observable
final class StudioStore {
    private(set) var document = StudioDocument()
    private(set) var history: [StudioDocument] = []
    private(set) var error: String?
    private(set) var isReadable = true
    private let url: URL

    init(url: URL? = nil) {
        self.url = url ?? URL.applicationSupportDirectory
            .appendingPathComponent("LifeStudio", isDirectory: true)
            .appendingPathComponent("composition.json")
        guard FileManager.default.fileExists(atPath: self.url.path) else { return }
        do {
            let decoded = try JSONDecoder().decode(StudioDocument.self, from: Data(contentsOf: self.url))
            guard decoded.version == 1 else { throw CocoaError(.fileReadCorruptFile) }
            document = decoded
        } catch {
            // Never overwrite an unreadable or newer document with an empty draft.
            isReadable = false
            self.error = NSLocalizedString("studio.error.load", comment: "Saved composition could not load")
        }
    }

    @discardableResult
    func change(_ edit: (inout StudioDocument) -> Void) -> Bool {
        guard isReadable else { return false }
        var next = document
        edit(&next)
        guard next != document else { return true }
        guard save(next) else { return false }
        history.append(document)
        if history.count > 20 { history.removeFirst() }
        document = next
        return true
    }

    func update(_ piece: StudioPiece) {
        change { draft in
            guard let index = draft.pieces.firstIndex(where: { $0.id == piece.id }) else { return }
            draft.pieces[index] = piece
        }
    }

    func move(_ id: UUID, x: Double, y: Double) {
        change { draft in
            guard let index = draft.pieces.firstIndex(where: { $0.id == id }) else { return }
            draft.pieces[index].x = min(0.85, max(0.15, x))
            draft.pieces[index].y = min(0.85, max(0.15, y))
        }
    }

    func undo() {
        guard let previous = history.last, save(previous) else { return }
        history.removeLast()
        document = previous
    }

    func clearError() { error = nil }

    private func save(_ value: StudioDocument) -> Bool {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(value)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            error = nil
            return true
        } catch {
            self.error = NSLocalizedString("studio.error.save", comment: "Failed to save composition")
            return false
        }
    }

    func addSample() {
        guard document.pieces.isEmpty else { return }
        change { draft in
            draft.title = NSLocalizedString("studio.sample.title", comment: "Sample title")
            var coffee = StudioPiece(kind: .coffee, title: NSLocalizedString("studio.sample.coffee", comment: "Sample coffee"))
            coffee.x = 0.69; coffee.y = 0.59; coffee.scale = 1.12; coffee.angle = 12
            var book = StudioPiece(kind: .book, title: NSLocalizedString("studio.sample.book", comment: "Sample book"))
            book.detail = "A LITTLE EVERYDAY"; book.x = 0.32; book.y = 0.36; book.angle = -12
            var note = StudioPiece(kind: .note, title: NSLocalizedString("studio.sample.note", comment: "Sample note"))
            note.x = 0.35; note.y = 0.75; note.scale = 0.85; note.angle = -5
            draft.pieces = [book, coffee, note]
        }
    }
}
