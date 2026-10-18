import XCTest
@testable import SoloCompass

/// Route-generation provenance (contract 2 / R2-11): when the model is
/// unavailable, the deterministic local plan is returned with an explicit
/// reason and is honestly sourced `.userCreated` — never `.aiGenerated` just
/// because the summary is non-empty. The URLSession is mocked with a failing
/// protocol: no real request ever leaves the test process.
final class AIServiceRouteProvenanceTests: XCTestCase {

    /// Fails every request immediately — deterministic offline behavior with
    /// zero network I/O regardless of any configured key or flag.
    private final class FailingURLProtocol: URLProtocol {
        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            let error = NSError(
                domain: "AIServiceRouteProvenanceTests",
                code: -1009,
                userInfo: [NSLocalizedDescriptionKey: "offline (test)"]
            )
            client?.urlProtocol(self, didFailWithError: error)
        }
        override func stopLoading() {}
    }

    private func makeExperience(id: String, lat: Double, lon: Double) -> Experience {
        Experience(
            id: id,
            title: "Place \(id)",
            oneLiner: "one",
            whyItMatters: "why",
            category: .nature,
            location: ExperienceLocation(
                coordinates: [lon, lat],
                cityCode: "VTE",
                addressHint: "hint",
                placeNameLocal: nil,
                placeNameRomanized: "Place"
            ),
            bestTimes: [],
            durationMinutes: .init(min: 30, max: 60),
            howTo: [],
            realInconveniences: [],
            soloScore: SoloScore(
                overall: 8.0,
                breakdown: .init(
                    seatingFriendly: 8,
                    soloPatronRatio: 8,
                    staffPressure: 8,
                    soloPortioning: 8,
                    ambianceFit: 8,
                    safety: 8
                ),
                basedOnCount: 3
            ),
            sources: [],
            confidence: Confidence(
                level: 3,
                lastVerifiedAt: Date(),
                reason: "test",
                signals: .init(
                    aiScrapeAgeDays: 1,
                    passiveGpsHits30d: 0,
                    activeReports30d: 0,
                    trustedVerifications: 0
                )
            ),
            nearbyExperienceIds: [],
            stats: .init(completionCount: 1, averageRating: 4.0),
            status: .active,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    private func makeOfflineService() -> AIService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FailingURLProtocol.self]
        return AIService(session: URLSession(configuration: configuration))
    }

    // MARK: - Fallback provenance

    func testUnavailableModelYieldsHonestLocalFallback() async throws {
        let service = makeOfflineService()
        let candidates = [
            makeExperience(id: "exp_a", lat: 17.96, lon: 102.60),
            makeExperience(id: "exp_b", lat: 17.97, lon: 102.61),
            makeExperience(id: "exp_c", lat: 17.98, lon: 102.62),
        ]

        let result = try await service.generateRouteDetailed(
            from: candidates,
            cityCode: "VTE",
            userCoordinate: nil
        )

        XCTAssertEqual(result.provenance, .localFallback, "an unreachable model must read as a local fallback")
        XCTAssertNotNil(result.fallbackReason, "the fallback must expose WHY")
        XCTAssertEqual(
            result.route.source,
            .userCreated,
            "a deterministic local plan is not AI output — never .aiGenerated"
        )
        XCTAssertFalse(result.route.experienceIds.isEmpty, "the useful local result is retained")
        XCTAssertEqual(result.route.experienceIds.count, 3)
        XCTAssertFalse(result.route.title.isEmpty)
    }

    func testCompatibilityWrapperAlsoHidesFalseAiProvenance() async throws {
        let service = makeOfflineService()
        let candidates = [
            makeExperience(id: "exp_a", lat: 17.96, lon: 102.60),
            makeExperience(id: "exp_b", lat: 17.97, lon: 102.61),
        ]

        let route = try await service.generateRoute(
            from: candidates,
            cityCode: "VTE",
            userCoordinate: nil
        )
        // The wrapper's other caller (voice-agent tool router) must not label
        // local output as AI either.
        XCTAssertNotEqual(route.source, .aiGenerated)
        XCTAssertNotEqual(route.source, .coCreated)
        XCTAssertEqual(route.source, .userCreated)
    }

    func testEmptyCandidatesStillThrowsInsteadOfInventingStops() async {
        let service = makeOfflineService()
        do {
            _ = try await service.generateRouteDetailed(from: [], cityCode: "VTE", userCoordinate: nil)
            XCTFail("no candidates must fail loudly, never fabricate a route")
        } catch {
            // Expected: AIError.decodingFailed("no candidates to build a route")
        }
    }
}
