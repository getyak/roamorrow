import Foundation

/// Stable card-template identifiers retained for encoded values and asset names.
public enum BragCardTemplate: String, CaseIterable, Codable, Hashable, Sendable {
    /// Warm noon light — general-purpose default.
    case sun          = "templateA_sun"
    /// Golden hour through a café window — the "slow afternoon" mood.
    case lateWindow   = "templateB_lateWindow"
    /// Overcast rain on stone streets — introspective walks.
    case rain         = "templateC_rain"
    /// Purple-amber dusk — end-of-day reflection.
    case dusk         = "templateD_dusk"
    /// Still, quiet room — solo-time-at-home archetype.
    case still        = "templateE_still"

    /// Human-readable descriptor for accessibility + share metadata.
    public var displayName: String {
        switch self {
        case .sun:        return "Noon"
        case .lateWindow: return "Late Window"
        case .rain:       return "Rain"
        case .dusk:       return "Dusk"
        case .still:      return "Still"
        }
    }

    /// Deterministic pick for a given seed — used by the composer so the
    /// same city+day pair renders the same face across runs (a returning
    /// user recognizes "their" card).
    public static func deterministic(for seed: String) -> BragCardTemplate {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100_0000_01b3
        }
        let cases = BragCardTemplate.allCases
        return cases[Int(hash % UInt64(cases.count))]
    }
}
