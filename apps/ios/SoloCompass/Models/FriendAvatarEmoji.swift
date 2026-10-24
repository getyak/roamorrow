/// Stable per-user avatar selection, independent of a particular friends screen.
enum AvatarEmoji {
    static let pool = ["🧭", "🌿", "🏔️", "🌊", "🦊", "🐢", "🦉", "🐬", "🌅", "🍃"]

    /// FNV-1a 64-bit hash — deterministic across process launches, unlike String.hashValue.
    static func stableHash(_ s: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in s.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }

    static func emoji(for userId: String) -> String {
        let idx = Int(stableHash(userId) % UInt64(pool.count))
        return pool[idx]
    }
}
