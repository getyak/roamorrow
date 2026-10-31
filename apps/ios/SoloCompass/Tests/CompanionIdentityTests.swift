import XCTest
@testable import SoloCompass

final class CompanionIdentityTests: XCTestCase {
    func testLegacyAndFutureIdentityDecodeWithoutLosingTheName() throws {
        let decoder = JSONDecoder()
        XCTAssertEqual(try decoder.decode(CompanionIdentity.self, from: Data("{}".utf8)), CompanionIdentity())
        let future = try decoder.decode(CompanionIdentity.self,
            from: Data(#"{"name":"沿途小伴","portraitRaw":"future-style"}"#.utf8))
        XCTAssertEqual(future.displayName, "沿途小伴")
        XCTAssertEqual(future.portrait, .moss)
        XCTAssertEqual(try decoder.decode(CompanionIdentity.self, from: JSONEncoder().encode(future)), future)
    }

    func testNamesAreSingleLineAndBoundedByUserPerceivedCharacters() {
        XCTAssertEqual(CompanionIdentity.normalizedName("  沿途\n小伴\t "), "沿途 小伴")
        XCTAssertEqual(CompanionIdentity.normalizedName("小\u{0000}伴"), "小伴")
        XCTAssertTrue(CompanionIdentity.normalizedName(" \n ").isEmpty)
        XCTAssertEqual(CompanionIdentity.normalizedName(String(repeating: "👨‍👩‍👧‍👦", count: 20)).count, 16)
        XCTAssertEqual(CompanionIdentity.normalizedName("👨‍👩‍👧‍👦"), "👨‍👩‍👧‍👦")
        XCTAssertEqual(CompanionIdentity.normalizedName("می\u{200C}روم"), "می\u{200C}روم")
        XCTAssertEqual(CompanionIdentity().displayName.count, 4)
    }

    func testIdentitySurvivesPreferenceRestartWithoutChangingTravelerProfile() throws {
        let suite = "companion-identity-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = UserPreferences(defaults: defaults)
        preferences.displayHandle = "Traveler"
        preferences.agentIdentity = CompanionIdentity(name: "沿途小伴", portrait: .moon)
        let restored = UserPreferences(defaults: defaults)
        XCTAssertEqual(restored.agentIdentity.name, "沿途小伴")
        XCTAssertEqual(restored.agentIdentity.portrait, .moon)
        XCTAssertEqual(restored.displayHandle, "Traveler")
    }

    func testPreIdentityPreferencesKeepTheTravelersExistingSettings() throws {
        let suite = "companion-legacy-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data(#"{"displayHandle":"Traveler","maxDistanceKm":12,"favoritedExperiences":["saved-place"]}"#.utf8),
            forKey: "com.solocompass.userPreferences.v1")
        let preferences = UserPreferences(defaults: defaults)
        XCTAssertEqual(preferences.agentIdentity, CompanionIdentity())
        XCTAssertEqual(preferences.displayHandle, "Traveler")
        XCTAssertEqual(preferences.maxDistanceKm, 12)
        XCTAssertEqual(preferences.favoritedExperiences, ["saved-place"])
    }
}
