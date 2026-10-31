import Foundation

enum CompanionPortraitStyle: String, CaseIterable, Identifiable {
    case moss, pixel, moon, landscape
    var id: String { rawValue }
    var title: String {
        NSLocalizedString("companion.identity.style.\(rawValue)", comment: "Built-in companion portrait")
    }
}

/// Local Agent appearance, separate from the traveler's public profile.
struct CompanionIdentity: Codable, Equatable {
    static let maximumNameLength = 16
    var name: String
    var portraitRaw: String

    var portrait: CompanionPortraitStyle { CompanionPortraitStyle(rawValue: portraitRaw) ?? .moss }
    var displayName: String {
        let value = Self.normalizedName(name)
        return value.isEmpty
            ? NSLocalizedString("companion.identity.defaultName", value: "Roam", comment: "Short Agent name")
            : value
    }

    init(name: String = "", portrait: CompanionPortraitStyle = .moss) {
        self.name = Self.normalizedName(name)
        self.portraitRaw = portrait.rawValue
    }

    static func normalizedName(_ value: String) -> String {
        let printable = String(value.unicodeScalars.filter {
            $0.value == 0x200C || $0.value == 0x200D
                || !CharacterSet.controlCharacters.contains($0) || CharacterSet.whitespacesAndNewlines.contains($0)
        })
        return String(printable.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ").prefix(maximumNameLength))
    }

    private enum CodingKeys: String, CodingKey { case name, portraitRaw }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = Self.normalizedName(try container.decodeIfPresent(String.self, forKey: .name) ?? "")
        portraitRaw = try container.decodeIfPresent(String.self, forKey: .portraitRaw) ?? CompanionPortraitStyle.moss.rawValue
    }
}
