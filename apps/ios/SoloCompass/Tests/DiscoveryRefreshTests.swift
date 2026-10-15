import XCTest
import SwiftData
@testable import SoloCompass

/// Focused coverage for the same-ID discovery refresh path:
/// `ExperienceRepository.mergeDiscovered` + the pure `DiscoveryRefreshPolicy`
/// + the thin `ExperienceService` wrapper. Uses real in-memory SwiftData
/// (same convention as `MapFoodAccuracyTests` /
/// `ExperienceRepositoryExportTests`), never mocks the persistence layer.
///
/// Pinned behaviors:
/// - same id + fresh facts refreshes the single stored row (count stays 1);
/// - the service reloads its mirrors even when the batch inserts nothing;
/// - user stats, completions, tags, status, createdAt, photos, highlights,
///   community Solo Score (`basedOnCount > 0`) and human evidence survive a
///   refresh;
/// - manual / field-visited / human-verified rows are never overwritten;
/// - a machine skeleton never replaces richer AI content;
/// - duplicate ids inside one batch produce exactly one row;
/// - the new-only count only counts genuinely new unique ids.
@MainActor
final class DiscoveryRefreshTests: XCTestCase {

    private var repo: ExperienceRepository!

    override func setUp() async throws {
        try await super.setUp()
        repo = ExperienceRepository(
            context: ModelContext(SoloCompassModelContainer.makeInMemory()),
            preferences: nil
        )
    }

    override func tearDown() async throws {
        repo = nil
        try await super.tearDown()
    }

    // MARK: - Same-ID fresh facts

    func testSameIDFreshFactsRefreshSingleRowAndCountStaysOne() throws {
        let base = generated(title: "Riverside night market", updatedAt: t0)
        repo.appendGenerated([base])

        let fresh = generated(
            title: "Riverside night bazaar",
            oneLiner: "Fresh tagline",
            whyItMatters: "Fresh copy from a newer synthesis run.",
            coordinates: [100.2, 13.8],
            bestTimes: [],
            updatedAt: t1
        )
        let result = repo.mergeDiscovered([fresh])

        XCTAssertEqual(result.insertedIDs, [], "same-id batch must not insert")
        XCTAssertEqual(result.insertedCount, 0)
        XCTAssertEqual(result.refreshedIDs, [base.id])

        let rows = repo.allExperiences()
        XCTAssertEqual(rows.count, 1, "refresh keeps exactly one stored row")
        let stored = try XCTUnwrap(rows.first)
        XCTAssertEqual(stored.title, "Riverside night bazaar", "title updates")
        XCTAssertEqual(stored.oneLiner, "Fresh tagline", "copy updates")
        XCTAssertEqual(stored.location.coordinates, [100.2, 13.8], "location updates")
        XCTAssertTrue(stored.bestTimes.isEmpty, "stale unsupported windows are cleared")
        XCTAssertEqual(stored.updatedAt.timeIntervalSince(t1), 0, accuracy: 1, "times update")
    }

    // MARK: - Service reload semantics

    func testServiceReloadsWhenBatchInsertsNothing() {
        let stale = generated(title: "Old title", updatedAt: t0)
        repo.appendGenerated([stale])
        let service = ExperienceService(seed: [stale], repository: repo)
        XCTAssertEqual(service.allExperiences.first?.title, "Old title")

        let result = service.mergeDiscovered([generated(title: "New title", updatedAt: t1)])

        XCTAssertEqual(result.insertedCount, 0, "nothing new was inserted")
        XCTAssertEqual(result.refreshedIDs, [stale.id])
        XCTAssertEqual(
            service.allExperiences.first?.title, "New title",
            "a refresh must reload the @Observable mirrors even with zero inserts"
        )
    }

    // MARK: - Evidence retention across a refresh

    func testRefreshRetainsUserEvidenceCommunityScoreAndHighlights() throws {
        let userPhoto = "file:///user/market.jpg"
        let remotePhoto = "https://cdn.example.org/market.jpg"
        let existing = generated(
            title: "Riverside night market",
            soloOverall: 8.1,
            basedOnCount: 12,
            photoUrls: [userPhoto],
            highlights: [CategoryHighlight(kind: .signature, label: "Signature", value: "boat noodles")],
            stats: .init(completionCount: 5, averageRating: 4.8, lastCompletedAt: tUser),
            status: .active,
            userTags: ["night-market", "solo-friendly"],
            createdAt: t0,
            updatedAt: t0,
            confidence: Confidence(
                level: 1,
                lastVerifiedAt: t0,
                reason: "AI-synthesized via Edge Function, unverified",
                signals: .init(aiScrapeAgeDays: 0, passiveGpsHits30d: 6, activeReports30d: 3, trustedVerifications: 0)
            )
        )
        repo.appendGenerated([existing])
        repo.recordCompletion(experienceId: existing.id, at: tUser)

        let fresh = generated(
            title: "Fresh title",
            soloOverall: 8.9,
            basedOnCount: 0,
            photoUrls: [remotePhoto],
            highlights: nil,
            updatedAt: t1
        )
        let result = repo.mergeDiscovered([fresh])
        XCTAssertEqual(result.refreshedIDs, [existing.id])

        let stored = try XCTUnwrap(repo.experience(id: existing.id))
        XCTAssertEqual(stored.title, "Fresh title", "fresh facts win")
        XCTAssertEqual(
            stored.stats.completionCount, 5,
            "user stats are retained, not reset by the fresh zero-stats copy"
        )
        XCTAssertEqual(try XCTUnwrap(stored.stats.lastCompletedAt).timeIntervalSince(tUser), 0, accuracy: 1)
        XCTAssertEqual(stored.userTags, ["night-market", "solo-friendly"], "userTags retained")
        XCTAssertEqual(stored.status, .active, "status retained")
        XCTAssertEqual(stored.createdAt.timeIntervalSince(t0), 0, accuracy: 1, "createdAt retained")
        XCTAssertEqual(
            Set(stored.location.photoUrls ?? []), Set([userPhoto, remotePhoto]),
            "photos are a union — user's real photos survive"
        )
        XCTAssertEqual(stored.highlights.count, 1, "existing highlights kept when incoming lacks them")
        XCTAssertEqual(stored.highlights.first?.value, "boat noodles")
        XCTAssertEqual(stored.soloScore.basedOnCount, 12, "community score retained")
        XCTAssertEqual(stored.soloScore.overall, 8.1, accuracy: 0.001, "basedOnCount > 0 score is never clobbered")
        XCTAssertEqual(
            stored.confidence.signals.activeReports30d, 3,
            "human evidence on confidence signals is retained"
        )
        XCTAssertEqual(stored.confidence.signals.passiveGpsHits30d, 6)
        XCTAssertEqual(repo.completionCount(experienceId: existing.id), 1, "completion records survive")
        XCTAssertTrue(repo.isCompleted(experienceId: existing.id))
    }

    // MARK: - Protected content is never overwritten

    func testFieldVisitAndManualRowsAreNeverRefreshed() throws {
        // 1. manual, user-created row
        let draft = Experience.userDraft(
            uuid: "abc",
            title: "My quiet teahouse",
            oneLiner: "Hand-written",
            category: .coffee,
            coordinates: [100.0, 13.0],
            cityCode: "cnx"
        )
        repo.appendGenerated([draft])

        // 2. machine row carrying human field verification
        let fieldVisited = generated(
            id: "exp_osm_555",
            title: "Field-verified stall",
            sources: [
                InformationSource(
                    type: .user,
                    url: URL(string: "https://www.openstreetmap.org/node/555"),
                    attribution: "© OpenStreetMap contributors + AI",
                    verifiedAt: t0
                ),
                InformationSource(type: .fieldVisit, attribution: "Field visit 2026-01", verifiedAt: tUser),
            ]
        )
        repo.appendGenerated([fieldVisited])

        // 3. machine row with trusted human verification signals
        let trusted = generated(
            id: "exp_osm_666",
            title: "Trusted-verified spot",
            confidence: Confidence(
                level: 3,
                lastVerifiedAt: tUser,
                reason: "Verified by 2 trusted reporters",
                signals: .init(aiScrapeAgeDays: 0, passiveGpsHits30d: 0, activeReports30d: 0, trustedVerifications: 2)
            )
        )
        repo.appendGenerated([trusted])

        let before = [
            draft.id: repo.experience(id: draft.id),
            fieldVisited.id: repo.experience(id: fieldVisited.id),
            trusted.id: repo.experience(id: trusted.id),
        ]

        let result = repo.mergeDiscovered([
            generated(id: draft.id, title: "Overwrite attempt", updatedAt: t2),
            generated(id: fieldVisited.id, title: "Overwrite attempt", updatedAt: t2),
            generated(id: trusted.id, title: "Overwrite attempt", updatedAt: t2),
        ])

        XCTAssertTrue(result.refreshedIDs.isEmpty, "protected rows must never refresh")
        XCTAssertTrue(result.insertedIDs.isEmpty)
        XCTAssertEqual(result.skipped[draft.id], .protectedManual)
        XCTAssertEqual(result.skipped[fieldVisited.id], .protectedManual)
        XCTAssertEqual(result.skipped[trusted.id], .protectedManual)

        for (id, snapshot) in before {
            let stored = try XCTUnwrap(repo.experience(id: id), "row \(id) must still exist")
            XCTAssertEqual(stored, snapshot, "protected row \(id) must be byte-identical")
            XCTAssertNotEqual(stored.title, "Overwrite attempt")
        }
    }

    // MARK: - Skeleton fallback guard

    func testSkeletonFallbackNeverReplacesRicherAIContent() throws {
        let rich = generated(
            title: "Rich AI copy",
            whyItMatters: "Deep, verified-sounding copy worth keeping.",
            updatedAt: t0
        )
        repo.appendGenerated([rich])
        let before = try XCTUnwrap(repo.experience(id: rich.id))

        let fallback = skeleton(title: "Riverside Market", updatedAt: t1)
        let result = repo.mergeDiscovered([fallback])

        XCTAssertEqual(result.skipped[rich.id], .skeletonDowngrade, "skeleton must not overwrite richer content")
        XCTAssertTrue(result.refreshedIDs.isEmpty)
        let stored = try XCTUnwrap(repo.experience(id: rich.id))
        XCTAssertEqual(stored, before, "rich content survives the offline/quota fallback untouched")
    }

    func testFreshRichContentRefreshesSkeletonRow() throws {
        let stale = skeleton(title: "Riverside Market", updatedAt: t0)
        repo.appendGenerated([stale])

        let rich = generated(title: "Riverside night market", updatedAt: t1)
        let result = repo.mergeDiscovered([rich])

        XCTAssertEqual(result.refreshedIDs, [stale.id], "a skeleton row upgrades to fresh AI content")
        let stored = try XCTUnwrap(repo.experience(id: stale.id))
        XCTAssertEqual(stored.title, "Riverside night market")
        XCTAssertTrue(stored.isAIEnriched)
        XCTAssertFalse(stored.bestTimes.isEmpty)
    }

    // MARK: - Batch dedupe + new-only counting

    func testDuplicateBatchIDsProduceOneRowAndLastWins() throws {
        let id = "exp_osm_777"
        let result = repo.mergeDiscovered([
            generated(id: id, title: "First copy", updatedAt: t1),
            generated(id: id, title: "Second copy", updatedAt: t2),
        ])

        XCTAssertEqual(result.insertedIDs, [id])
        XCTAssertEqual(result.insertedCount, 1, "duplicate ids count once")
        let rows = repo.allExperiences()
        XCTAssertEqual(rows.count, 1, "duplicate batch ids must not create duplicate rows")
        XCTAssertEqual(try XCTUnwrap(rows.first).title, "Second copy", "last occurrence wins within a batch")

        // And a duplicated refresh updates the same single row once.
        let refresh = repo.mergeDiscovered([
            generated(id: id, title: "Refresh A", updatedAt: t3),
            generated(id: id, title: "Refresh B", updatedAt: t3),
        ])
        XCTAssertEqual(refresh.insertedIDs, [])
        XCTAssertEqual(refresh.refreshedIDs, [id])
        XCTAssertEqual(refresh.refreshedCount, 1)
        XCTAssertEqual(repo.allExperiences().count, 1)
        XCTAssertEqual(repo.experience(id: id)?.title, "Refresh B")
    }

    func testNewOnlyCountCountsUniqueNewIDs() {
        let existing = generated(id: "exp_osm_1", title: "Known spot", updatedAt: t0)
        repo.appendGenerated([existing])

        let result = repo.mergeDiscovered([
            generated(id: existing.id, title: "Refreshed spot", updatedAt: t1),
            generated(id: "exp_osm_2", title: "New A", updatedAt: t1),
            generated(id: "exp_osm_2", title: "New A duplicate", updatedAt: t1),
            generated(id: "exp_osm_3", title: "New B", updatedAt: t1),
        ])

        XCTAssertEqual(result.insertedCount, 2, "new-only count is the unique new id count")
        XCTAssertEqual(result.insertedIDs, ["exp_osm_2", "exp_osm_3"])
        XCTAssertEqual(result.refreshedIDs, [existing.id])
        XCTAssertEqual(repo.allExperiences().count, 3)
    }

    // MARK: - Ambiguous provenance fails closed

    func testAmbiguousProvenanceIsSkippedNotRefreshed() throws {
        let unknown = generated(
            id: "exp_osm_888",
            title: "Mystery provenance",
            sources: [InformationSource(type: .user, attribution: "Neighborhood newsletter", verifiedAt: t0)]
        )
        repo.appendGenerated([unknown])
        let before = try XCTUnwrap(repo.experience(id: unknown.id))

        let result = repo.mergeDiscovered([generated(id: unknown.id, title: "Overwrite attempt", updatedAt: t1)])

        XCTAssertEqual(result.skipped[unknown.id], .ambiguousIdentity, "unrecognized attribution is ambiguous")
        XCTAssertTrue(result.refreshedIDs.isEmpty)
        XCTAssertEqual(try XCTUnwrap(repo.experience(id: unknown.id)), before, "ambiguous rows stay untouched")
    }

    func testStaleIncomingDoesNotRegressFreshContent() throws {
        let fresh = generated(title: "Fresh facts", updatedAt: t1)
        repo.appendGenerated([fresh])
        let before = try XCTUnwrap(repo.experience(id: fresh.id))

        let result = repo.mergeDiscovered([generated(title: "Older copy", updatedAt: t0)])

        XCTAssertEqual(result.skipped[fresh.id], .staleIncoming)
        XCTAssertTrue(result.refreshedIDs.isEmpty)
        XCTAssertEqual(try XCTUnwrap(repo.experience(id: fresh.id)), before)
    }

    // MARK: - Pure policy assertions (no store)

    func testPolicyDecisionMatrixIsExplicitAndPure() {
        let stored = generated(title: "Stored", updatedAt: t0)

        XCTAssertEqual(
            DiscoveryRefreshPolicy.decision(existing: nil, incoming: stored),
            .insert(stored),
            "no stored row inserts the incoming value"
        )

        let draft = Experience.userDraft(
            uuid: "p", title: "Mine", oneLiner: "Hand-written",
            category: .coffee, coordinates: [100.0, 13.0], cityCode: "cnx"
        )
        XCTAssertEqual(
            DiscoveryRefreshPolicy.decision(existing: draft, incoming: generated(updatedAt: t1)),
            .skip(.protectedManual),
            "user-created rows are protected"
        )

        XCTAssertEqual(
            DiscoveryRefreshPolicy.decision(existing: stored, incoming: skeleton(updatedAt: t1)),
            .skip(.skeletonDowngrade),
            "skeletons never overwrite richer content"
        )

        XCTAssertEqual(
            DiscoveryRefreshPolicy.decision(existing: stored, incoming: generated(title: "Old", updatedAt: t0 - 10)),
            .skip(.staleIncoming),
            "older batches never regress fresher rows"
        )

        guard case .refresh(let merged) = DiscoveryRefreshPolicy.decision(
            existing: stored,
            incoming: generated(title: "New", coordinates: [101.0, 14.0], updatedAt: t1)
        ) else {
            return XCTFail("fresh valid generated content must refresh")
        }
        XCTAssertEqual(merged.id, stored.id)
        XCTAssertEqual(merged.title, "New")
        XCTAssertEqual(merged.location.coordinates, [101.0, 14.0])
        XCTAssertEqual(merged.createdAt.timeIntervalSince(stored.createdAt), 0, accuracy: 1)
        XCTAssertEqual(merged.updatedAt.timeIntervalSince(t1), 0, accuracy: 1)
    }

    func testViewModelRefreshOnlyBatchUpdatesVisibleAndSelectedFacts() throws {
        let original = generated()
        repo.appendGenerated([original])
        let service = ExperienceService(seed: [original], repository: repo)
        let suite = "discovery-vm-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let vm = MapViewModel(locationService: LocationService(), experienceService: service,
                              aiService: AIService(), preferences: UserPreferences(defaults: defaults))
        vm.selectCustomLocation(coordinate: .init(latitude: 13.7, longitude: 100.1), label: "Test", cityCode: "cnx")
        XCTAssertEqual(vm.visibleExperiences.first { $0.id == original.id }?.title, original.title)
        let result = vm.mergeDiscoveryBatch([generated(title: "Refreshed visible facts", updatedAt: t1)])
        XCTAssertEqual(result.insertedCount, 0)
        XCTAssertEqual(vm.visibleExperiences.first { $0.id == original.id }?.title, "Refreshed visible facts")
        XCTAssertEqual(vm.visibleExperiences.filter { $0.id == original.id }.count, 1)
    }

    func testInvalidInsertAndRefreshCoordinatesAreRejected() throws {
        for coordinates in [[], [100.0], [181, 13], [100, 91], [100, 13, 5], [.nan, 13], [100, .infinity]] {
            let invalid = generated(coordinates: coordinates, updatedAt: t1)
            XCTAssertEqual(repo.mergeDiscovered([invalid]).skipped[invalid.id], .invalidCoordinates)
            XCTAssertTrue(repo.allExperiences().isEmpty)
        }
        let original = generated()
        repo.appendGenerated([original])
        _ = repo.mergeDiscovered([generated(coordinates: [181, 91], updatedAt: t1)])
        XCTAssertEqual(repo.experience(id: original.id)?.location.coordinates, original.location.coordinates)
    }

    func testNonAutomaticIncomingCannotInsertOrRefresh() throws {
        let incoming = generated(title: "Unproven copy", updatedAt: t1, sources: [])
        XCTAssertEqual(repo.mergeDiscovered([incoming]).skipped[incoming.id], .ambiguousIdentity)
        XCTAssertTrue(repo.allExperiences().isEmpty)
        let original = generated()
        repo.appendGenerated([original])
        XCTAssertEqual(repo.mergeDiscovered([incoming]).skipped[incoming.id], .ambiguousIdentity)
        XCTAssertEqual(repo.experience(id: original.id)?.title, original.title)
    }

    func testCompleteRefreshClearsUnsupportedMachineFacts() throws {
        let stale = generated(openingHours: "09:00-21:00", rating: 8.8)
        repo.appendGenerated([stale])
        let fresh = generated(guidance: [], bestTimes: [], updatedAt: t1)
        _ = repo.mergeDiscovered([fresh])
        let stored = try XCTUnwrap(repo.experience(id: fresh.id))
        XCTAssertNil(stored.location.openingHours)
        XCTAssertNil(stored.location.rating)
        XCTAssertTrue(stored.howTo.isEmpty)
        XCTAssertTrue(stored.bestTimes.isEmpty)
    }

    func testBatchOrderingCannotInsertOlderOrSkeletonCopy() throws {
        let rich = generated(updatedAt: t2)
        let result = repo.mergeDiscovered([rich, skeleton(updatedAt: t3), generated(title: "Stale", updatedAt: t0)])
        XCTAssertEqual(result.insertedCount, 1)
        XCTAssertEqual(repo.allExperiences().count, 1)
        XCTAssertEqual(repo.experience(id: rich.id)?.title, rich.title)
        XCTAssertEqual(repo.experience(id: rich.id)?.soloScore.overall, rich.soloScore.overall)
    }

    // MARK: - Fixtures

    private var t0: Date { Date(timeIntervalSince1970: 1_700_000_000) }
    private var t1: Date { Date(timeIntervalSince1970: 1_700_086_400) }
    private var t2: Date { Date(timeIntervalSince1970: 1_700_172_800) }
    private var t3: Date { Date(timeIntervalSince1970: 1_700_259_200) }
    private var tUser: Date { Date(timeIntervalSince1970: 1_700_003_600) }

    /// A machine-generated experience as the Explore pipelines emit it:
    /// `exp_osm_` id, known automatic attribution ("© OpenStreetMap
    /// contributors + AI"), machine confidence (level 1, zero signals).
    private func generated(
        id: String = "exp_osm_4242",
        title: String = "Riverside night market",
        oneLiner: String = "AI-generated tagline",
        whyItMatters: String = "AI-generated copy about the market.",
        coordinates: [Double] = [100.1, 13.7],
        openingHours: String? = nil,
        rating: Double? = nil,
        guidance: [HowToStep] = [HowToStep(order: 1, text: "Arrive after 17:00")],
        bestTimes: [TimeWindow] = [TimeWindow(startHour: 17, endHour: 21)],
        soloOverall: Double = 7.5,
        basedOnCount: Int = 0,
        photoUrls: [String]? = nil,
        highlights: [CategoryHighlight]? = nil,
        stats: Experience.Stats = .init(completionCount: 0, averageRating: 0),
        status: Experience.Status = .candidate,
        userTags: [String]? = nil,
        createdAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
        sources: [InformationSource]? = nil,
        confidence: Confidence? = nil
    ) -> Experience {
        Experience(
            id: id,
            title: title,
            oneLiner: oneLiner,
            whyItMatters: whyItMatters,
            category: .food,
            location: ExperienceLocation(
                coordinates: coordinates,
                cityCode: "cnx",
                placeNameRomanized: "Riverside Market",
                rating: rating,
                openingHours: openingHours,
                photoUrls: photoUrls
            ),
            bestTimes: bestTimes,
            durationMinutes: .init(min: 30, max: 90),
            howTo: guidance,
            realInconveniences: [],
            soloScore: SoloScore(
                overall: soloOverall,
                breakdown: .init(
                    seatingFriendly: soloOverall, soloPatronRatio: soloOverall, staffPressure: soloOverall,
                    soloPortioning: soloOverall, ambianceFit: soloOverall, safety: soloOverall
                ),
                hint: soloOverall > 0 ? "Easy to do alone" : "No assessment available",
                basedOnCount: basedOnCount
            ),
            sources: sources ?? [
                InformationSource(
                    type: .user,
                    url: URL(string: "https://www.openstreetmap.org/node/4242"),
                    attribution: "© OpenStreetMap contributors + AI",
                    verifiedAt: updatedAt
                )
            ],
            confidence: confidence ?? Confidence(
                level: 1,
                lastVerifiedAt: updatedAt,
                reason: "AI-synthesized via Edge Function, unverified",
                signals: .init(aiScrapeAgeDays: 0, passiveGpsHits30d: 0, activeReports30d: 0, trustedVerifications: 0)
            ),
            nearbyExperienceIds: [],
            stats: stats,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            userTags: userTags,
            categoryHighlights: highlights
        )
    }

    /// The offline/quota-fallback skeleton `AIService.skeletonExperience`
    /// emits: known non-AI attribution, unassessed score, no timing/guidance.
    private func skeleton(
        id: String = "exp_osm_4242",
        title: String = "Riverside Market",
        updatedAt: Date
    ) -> Experience {
        Experience(
            id: id,
            title: title,
            oneLiner: "A real place from OpenStreetMap",
            whyItMatters: "Details are limited to public map data.",
            category: .food,
            location: ExperienceLocation(coordinates: [100.1, 13.7], cityCode: "cnx"),
            bestTimes: [],
            durationMinutes: .init(min: 30, max: 90),
            howTo: [],
            realInconveniences: [],
            soloScore: SoloScore(
                overall: 0,
                breakdown: .init(
                    seatingFriendly: 0, soloPatronRatio: 0, staffPressure: 0,
                    soloPortioning: 0, ambianceFit: 0, safety: 0
                ),
                hint: "No assessment available",
                basedOnCount: 0
            ),
            sources: [
                InformationSource(
                    type: .user,
                    url: URL(string: "https://www.openstreetmap.org/node/4242"),
                    attribution: "© OpenStreetMap contributors",
                    verifiedAt: updatedAt
                )
            ],
            confidence: Confidence(
                level: 1,
                lastVerifiedAt: updatedAt,
                reason: "OpenStreetMap entry, no AI enrichment",
                signals: .init(aiScrapeAgeDays: 0, passiveGpsHits30d: 0, activeReports30d: 0, trustedVerifications: 0)
            ),
            nearbyExperienceIds: [],
            stats: .init(completionCount: 0, averageRating: 0),
            status: .candidate,
            createdAt: updatedAt,
            updatedAt: updatedAt
        )
    }
}
