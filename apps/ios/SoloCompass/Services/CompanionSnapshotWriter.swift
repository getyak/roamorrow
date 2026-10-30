import Foundation

/// Orders atomic file replacement while allowing expensive encoding off-main.
/// An older completion cannot overwrite newer durable tool receipts.
final class CompanionSnapshotWriter: @unchecked Sendable {
    struct Ticket: Sendable {
        fileprivate let generation: UUID
        fileprivate let sequence: UInt64
    }
    enum Outcome: Equatable, Sendable { case written, superseded, invalidated }

    private let lock = NSLock()
    private var generation = UUID()
    private var nextSequence: UInt64 = 0
    private var committedSequence: UInt64 = 0
    private let beforeAsyncEncoding: @Sendable () -> Void

    init(beforeAsyncEncoding: @escaping @Sendable () -> Void = {}) {
        self.beforeAsyncEncoding = beforeAsyncEncoding
    }

    func reserve() -> Ticket {
        lock.lock()
        defer { lock.unlock() }
        nextSequence &+= 1
        return Ticket(generation: generation, sequence: nextSequence)
    }

    /// Invalidate before clearing exact files, so a late encoder cannot
    /// recreate a deleted conversation.
    func invalidate() {
        lock.lock()
        defer { lock.unlock() }
        generation = UUID()
        nextSequence = 0
        committedSequence = 0
    }

    func isCurrent(_ ticket: Ticket) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return ticket.generation == generation && ticket.sequence == committedSequence
    }

    func write(_ data: Data, to url: URL, ticket: Ticket) throws -> Outcome {
        lock.lock()
        defer { lock.unlock() }
        guard ticket.generation == generation else { return .invalidated }
        guard ticket.sequence > committedSequence else { return .superseded }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        committedSequence = ticket.sequence
        return .written
    }

    func writeAsync<Value: Encodable & Sendable>(
        _ value: Value, to url: URL, ticket: Ticket,
        encode: @escaping @Sendable (Value) throws -> Data = { try JSONEncoder().encode($0) }
    ) async throws -> Outcome {
        try await Task.detached(priority: .userInitiated) { [self] in
            beforeAsyncEncoding()
            let data = try encode(value)
            return try write(data, to: url, ticket: ticket)
        }.value
    }
}
