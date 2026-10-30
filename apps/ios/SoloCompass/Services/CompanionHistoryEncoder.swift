import Foundation

/// Reuses the encoded bytes of unchanged history while retaining one atomic,
/// backwards-compatible JSON snapshot for tool receipts, media and exports.
final class CompanionHistoryEncoder: @unchecked Sendable {
    struct Generation: Sendable {
        fileprivate let value: UUID
    }
    private struct Cached {
        var entry: CompanionHomeEntry
        var data: Data
    }
    private let lock = NSLock()
    private var generation = UUID()
    private var cache: [UUID: Cached] = [:]
    private var previousEntries: [CompanionHomeEntry] = []
    private var previousJSON: Data?

    var cachedEntryCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return previousEntries.count
    }

    func captureGeneration() -> Generation {
        lock.lock()
        defer { lock.unlock() }
        return Generation(value: generation)
    }

    func invalidate() {
        lock.lock()
        defer { lock.unlock() }
        generation = UUID()
        cache.removeAll()
        previousEntries = []
        previousJSON = nil
    }

    private func cachedState() -> (UUID, [UUID: Cached], [CompanionHomeEntry], Data?) {
        lock.lock()
        defer { lock.unlock() }
        return (generation, cache, previousEntries, previousJSON)
    }

    private func publish(_ replacement: [UUID: Cached], entries: [CompanionHomeEntry], json: Data, generation expected: UUID) {
        lock.lock()
        defer { lock.unlock() }
        // A late background encoder cannot retain forgotten message/media bytes.
        if generation == expected {
            cache = replacement
            previousEntries = entries
            previousJSON = json
        }
    }

    func encode<Metadata: Encodable>(_ metadata: Metadata, entries: [CompanionHomeEntry],
                                    generation token: Generation? = nil) throws -> Data {
        let encoder = JSONEncoder()
        let (epoch, previous, previousEntries, previousJSON) = cachedState()
        // Capture at admission, before an async gate or scheduling delay. Reading
        // the current epoch here would give an old task fresh post-clear authority.
        let expectedGeneration = token?.value ?? epoch
        let history: Data
        if let previousJSON, previousEntries == entries {
            // Tool plan/start/result writes share the same immutable Array
            // storage. Swift's Array equality checks that identity first.
            history = previousJSON
        } else {
            var replacement: [UUID: Cached] = [:]
            replacement.reserveCapacity(entries.count)
            var chunks: [Data] = []
            chunks.reserveCapacity(entries.count)
            for entry in entries {
                let cached: Cached
                if let existing = previous[entry.id], existing.entry == entry { cached = existing }
                else { cached = Cached(entry: entry, data: try encoder.encode(entry)) }
                replacement[entry.id] = cached
                chunks.append(cached.data)
            }
            var bytes = Data()
            bytes.reserveCapacity(chunks.reduce(0) { $0 + $1.count + 1 } + 2)
            bytes.append(91)
            for (index, chunk) in chunks.enumerated() {
                if index > 0 { bytes.append(44) }
                bytes.append(chunk)
            }
            bytes.append(93)
            history = bytes
            publish(replacement, entries: entries, json: bytes, generation: expectedGeneration)
        }
        // Parse only the small envelope. Message text, binary data and nested
        // tool JSON are always escaped by Foundation, never string-interpolated.
        let header = try encoder.encode(metadata)
        guard var object = try JSONSerialization.jsonObject(with: header) as? [String: Any] else {
            throw CocoaError(.coderInvalidValue)
        }
        object.removeValue(forKey: "entries")
        let envelope = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        var data = Data()
        data.reserveCapacity(envelope.count + history.count + 15)
        data.append(contentsOf: envelope.dropLast())
        data.append(contentsOf: (object.isEmpty ? "\"entries\":" : ",\"entries\":").utf8)
        data.append(history)
        data.append(125)
        return data
    }
}
