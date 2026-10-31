import Foundation

@main
struct CompanionIdentityHost {
    static func main() throws {
        let decoder = JSONDecoder()
        precondition(tryDecode(decoder, "{}") == CompanionIdentity())
        let future = try decoder.decode(CompanionIdentity.self,
            from: Data(#"{"name":"沿途小伴","portraitRaw":"future-style"}"#.utf8))
        precondition(future.displayName == "沿途小伴" && future.portrait == .moss)
        let restored = try decoder.decode(CompanionIdentity.self, from: JSONEncoder().encode(future))
        precondition(restored == future)
        precondition(CompanionIdentity.normalizedName("  沿途\n小伴\t ") == "沿途 小伴")
        precondition(CompanionIdentity.normalizedName("小\u{0000}伴") == "小伴")
        precondition(CompanionIdentity.normalizedName(" \n ").isEmpty)
        precondition(CompanionIdentity.normalizedName("\u{200D}\u{200C}\u{FE0F}").isEmpty)
        precondition(CompanionIdentity.normalizedName(String(repeating: "👨‍👩‍👧‍👦", count: 20)).count == 16)
        precondition(CompanionIdentity.normalizedName("👨‍👩‍👧‍👦") == "👨‍👩‍👧‍👦")
        precondition(CompanionIdentity.normalizedName("می\u{200C}روم") == "می\u{200C}روم")
        precondition(CompanionIdentity().displayName.count == 4)
        for style in CompanionPortraitStyle.allCases {
            let value = CompanionIdentity(name: "沿途小伴", portrait: style)
            let decoded = try decoder.decode(CompanionIdentity.self, from: JSONEncoder().encode(value))
            precondition(decoded == value)
        }
        print("Companion identity: legacy/future decode, round trips, name normalization and four styles passed")
    }

    private static func tryDecode(_ decoder: JSONDecoder, _ json: String) -> CompanionIdentity? {
        try? decoder.decode(CompanionIdentity.self, from: Data(json.utf8))
    }
}
