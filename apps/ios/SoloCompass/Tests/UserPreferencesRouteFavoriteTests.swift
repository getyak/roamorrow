import XCTest
@testable import SoloCompass

/// Route favorites are a persistent, LOCAL user preference in their own id
/// namespace (contract item 1): separate from the experience favorites
/// repository, backward compatible with older persisted snapshots, and read
/// back across re-open / relaunch.
@MainActor
final class UserPreferencesRouteFavoriteTests: XCTestCase {

    private func makeIsolatedDefaults() -> UserDefaults {
        let suite = "userprefs.route.favorite.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    // MARK: - Persistence + read-back

    func testToggleRouteFavoritePersistsAcrossReopen() {
        let defaults = makeIsolatedDefaults()
        let first = UserPreferences(defaults: defaults)
        XCTAssertFalse(first.isRouteFavorited("route_mekong"))

        let nowFavorited = first.toggleRouteFavorite("route_mekong")
        XCTAssertTrue(nowFavorited)
        XCTAssertTrue(first.isRouteFavorited("route_mekong"))

        // A fresh instance reading the same blob is the "re-open" read-back.
        let second = UserPreferences(defaults: defaults)
        XCTAssertTrue(second.isRouteFavorited("route_mekong"))

        let unfav = second.toggleRouteFavorite("route_mekong")
        XCTAssertFalse(unfav)
        XCTAssertFalse(second.isRouteFavorited("route_mekong"))
        XCTAssertFalse(UserPreferences(defaults: defaults).isRouteFavorited("route_mekong"))
    }

    // MARK: - Namespace separation

    func testRouteFavoritesDoNotTouchExperienceFavorites() {
        let defaults = makeIsolatedDefaults()
        let prefs = UserPreferences(defaults: defaults)
        prefs.toggleFavorite("exp_a")
        prefs.toggleRouteFavorite("route_a")

        XCTAssertTrue(prefs.isFavorited("exp_a"))
        XCTAssertTrue(prefs.isRouteFavorited("route_a"))
        // A route id must never appear in the experience namespace (and vice
        // versa) — the two stores mirror to different persistence layers.
        XCTAssertFalse(prefs.isFavorited("route_a"))
        XCTAssertFalse(prefs.isRouteFavorited("exp_a"))
        XCTAssertEqual(prefs.favoritedExperiences, ["exp_a"])
        XCTAssertEqual(prefs.favoritedRouteIds, ["route_a"])
    }

    // MARK: - Backward compatible decoding

    func testLegacySnapshotWithoutRouteFavoriteKeysDecodes() throws {
        let defaults = makeIsolatedDefaults()
        // A blob written before route favorites existed: old keys present, new
        // keys absent. Must decode (no whole-snapshot failure) with empty
        // defaults for the new fields.
        let legacyJSON = """
        {"favoritedExperiences":["exp_old"],"favoritedAt":{"exp_old":"2026-01-01T00:00:00Z"},"completedExperiences":["exp_done"]}
        """
        defaults.set(Data(legacyJSON.utf8), forKey: "com.solocompass.userPreferences.v1")

        let prefs = UserPreferences(defaults: defaults)
        XCTAssertEqual(prefs.favoritedExperiences, ["exp_old"])
        XCTAssertEqual(prefs.completedExperiences, ["exp_done"])
        XCTAssertTrue(prefs.favoritedRouteIds.isEmpty)
        XCTAssertTrue(prefs.favoritedRouteAt.isEmpty)

        // New favorites written on top of the migrated blob still persist.
        prefs.toggleRouteFavorite("route_new")
        let reloaded = UserPreferences(defaults: defaults)
        XCTAssertTrue(reloaded.isRouteFavorited("route_new"))
        XCTAssertEqual(reloaded.favoritedExperiences, ["exp_old"])
    }

    func testRoundTripKeepsRouteFavoriteTimestamp() {
        let defaults = makeIsolatedDefaults()
        let stamp = Date(timeIntervalSince1970: 1_770_000_000)
        let prefs = UserPreferences(defaults: defaults)
        prefs.toggleRouteFavorite("route_dated", at: stamp)

        let reloaded = UserPreferences(defaults: defaults)
        XCTAssertEqual(reloaded.favoritedRouteAt["route_dated"]?.timeIntervalSince1970 ?? 0,
                       stamp.timeIntervalSince1970,
                       accuracy: 1)
    }
}
