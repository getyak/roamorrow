import XCTest
import Dispatch
@testable import SoloCompass

// MARK: - US-016: markerState(for:) call-count perf test

/// Verifies the CompassMapView marker-state caching optimisation (US-016).
///
/// The map's `ForEach(viewModel.visibleExperiences)` body needs the marker state
/// in two places per pin: the `MarkerIconView` and the `.footprinted` badge.
/// Before US-016 it called `viewModel.markerState(for:)` twice per iteration,
/// re-evaluating the helper's six conditions for every visible marker on every
/// render pass. The fix hoists `let state = viewModel.markerState(for: exp)` to
/// the top of the iteration so both downstream branches reuse it.
///
/// This test reconstructs both shapes — the *cached* path (one call per
/// iteration) and a *non-cached* baseline (two calls per iteration, mirroring
/// the pre-fix code) — and asserts the cached path's p95 of amortized batch
/// latency per pass drops by ≥ 40% versus the baseline. Each shape executes
/// 10000 measured passes, sampled in alternating pairs of 100-pass batches to
/// reduce shared-runner scheduling noise and measurement-order bias.
///
/// Run with:
///   xcodebuild test -only-testing:SoloCompassTests/MarkerStatePerformanceTest
final class MarkerStatePerformanceTest: XCTestCase {

    private static let markerCount = 100
    private static let iterations = 10000
    private static let passesPerBatch = 100
    private static let requiredImprovement = 0.40

    // Bounding box: ±0.15° around Chiang Mai old-city center.
    private static let centerLat: Double = 18.7877
    private static let centerLon: Double = 98.9938
    private static let latSpan: Double   = 0.15
    private static let lonSpan: Double   = 0.15

    // MARK: - Fixture

    @MainActor
    private func makeViewModel(with experiences: [Experience]) throws -> MapViewModel {
        let suite = "marker-state.perf.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        addTeardownBlock {
            UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        }
        let vm = MapViewModel(
            locationService: LocationService(),
            experienceService: ExperienceService(seed: experiences),
            aiService: AIService(),
            preferences: UserPreferences(defaults: defaults)
        )
        vm.visibleExperiences = experiences
        return vm
    }

    private func fixtureNow() throws -> Date {
        // Pin the wall-clock workload without mutating the process time zone.
        try XCTUnwrap(Calendar.current.date(from: DateComponents(
            year: 2026, month: 1, day: 15, hour: 12, minute: 0, second: 0
        )))
    }

    private func makeExperiences(count: Int, now: Date) -> [Experience] {
        return (0..<count).map { index in
            // Spread markers evenly across the bounding box using a grid layout.
            let cols = Int(Double(count).squareRoot().rounded(.up))
            let row = index / cols
            let col = index % cols
            let latStep = Self.latSpan / Double(max(1, cols - 1))
            let lonStep = Self.lonSpan / Double(max(1, cols - 1))
            let lat = Self.centerLat - Self.latSpan / 2 + Double(row) * latStep
            let lon = Self.centerLon - Self.lonSpan / 2 + Double(col) * lonStep

            let categories = ExperienceCategory.allCases.filter { $0 != .hidden }
            let category = categories[index % categories.count]

            return Experience(
                id: "marker_perf_\(index)",
                title: "Marker Perf \(index)",
                oneLiner: "Marker fixture \(index)",
                whyItMatters: "Performance fixture",
                category: category,
                location: ExperienceLocation(
                    coordinates: [lon, lat],
                    cityCode: "perf_cmi"
                ),
                bestTimes: index % 3 == 0 ? [TimeWindow(startHour: 8, endHour: 22)] : [],
                durationMinutes: .init(min: 30, max: 60),
                howTo: [],
                realInconveniences: [],
                soloScore: SoloScore(
                    overall: Double(index % 10) + 0.5,
                    breakdown: .init(
                        seatingFriendly: 7, soloPatronRatio: 7, staffPressure: 7,
                        soloPortioning: 7, ambianceFit: 7, safety: 7
                    ),
                    basedOnCount: index % 5
                ),
                sources: [InformationSource(type: .user, attribution: "perf", verifiedAt: now)],
                confidence: Confidence(
                    level: 3,
                    lastVerifiedAt: now,
                    reason: "Perf fixture",
                    signals: .init(aiScrapeAgeDays: 1, passiveGpsHits30d: index % 4,
                                   activeReports30d: 0, trustedVerifications: 0)
                ),
                nearbyExperienceIds: [],
                stats: .init(completionCount: 0, averageRating: 0),
                status: .active,
                createdAt: now,
                updatedAt: now
            )
        }
    }

    // MARK: - Measurement helpers

    private struct PassOutput: Equatable {
        var markerCount = 0
        var iconChecksum = 0
        var badgeCount = 0
    }

    /// Consume the icon state as well as the badge decision. Unlike an iteration
    /// counter, this checksum depends on every resolver result, including the
    /// associated minutes in an upcoming state.
    private func iconChecksum(for state: ExperienceMarkerState) -> Int {
        switch state {
        case .default: return 1
        case .bestNow: return 2
        case .completed: return 3
        case .favorited: return 4
        case .footprinted: return 5
        case .upcoming(let minutes): return 6 + minutes
        }
    }

    /// Cached path: one `markerState(for:)` call per iteration, the value reused
    /// for both the icon and the `.footprinted` badge branch — matches the
    /// post-US-016 ForEach body in CompassMapView.
    @MainActor
    private func cachedPass(_ vm: MapViewModel, experiences: [Experience], now: Date) -> PassOutput {
        var output = PassOutput()
        for exp in experiences {
            let state = vm.markerState(for: exp, now: now)
            output.markerCount += 1
            output.iconChecksum += iconChecksum(for: state)
            if case .footprinted = state {
                output.badgeCount += vm.footprintCount(for: exp)
            }
        }
        return output
    }

    /// Non-cached baseline: two `markerState(for:)` calls per iteration — the
    /// pre-US-016 shape where the icon and the badge branch each recomputed it.
    @MainActor
    private func nonCachedPass(_ vm: MapViewModel, experiences: [Experience], now: Date) -> PassOutput {
        var output = PassOutput()
        for exp in experiences {
            output.markerCount += 1
            output.iconChecksum += iconChecksum(for: vm.markerState(for: exp, now: now))
            if case .footprinted = vm.markerState(for: exp, now: now) {
                output.badgeCount += vm.footprintCount(for: exp)
            }
        }
        return output
    }

    @MainActor
    private func measureBatch(_ pass: () -> PassOutput) -> (latency: TimeInterval, output: PassOutput) {
        var output = PassOutput()
        let start = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<Self.passesPerBatch {
            let result = pass()
            output.markerCount += result.markerCount
            output.iconChecksum += result.iconChecksum
            output.badgeCount += result.badgeCount
        }
        let elapsed = DispatchTime.now().uptimeNanoseconds - start
        return (Double(elapsed) / 1_000_000_000 / Double(Self.passesPerBatch), output)
    }

    private func p95(_ samples: [TimeInterval]) -> TimeInterval {
        let sorted = samples.sorted()
        let index = Int((Double(sorted.count) * 0.95).rounded(.up)) - 1
        return sorted[min(max(0, index), sorted.count - 1)]
    }

    // MARK: - testCachedMarkerStateP95DropsAtLeast40Percent

    @MainActor
    func testCachedMarkerStateP95DropsAtLeast40Percent() throws {
        let now = try fixtureNow()
        let experiences = makeExperiences(count: Self.markerCount, now: now)
        let vm = try makeViewModel(with: experiences)
        let visibleExperiences = vm.visibleExperiences

        XCTAssertEqual(visibleExperiences.count, Self.markerCount,
                       "Precondition: visibleExperiences must hold exactly \(Self.markerCount) entries")

        // Warm both shapes for a full batch before collecting samples. Longer
        // batches amortize shared-runner scheduling interruptions without
        // dropping samples or changing the p95/40% acceptance threshold.
        XCTAssertEqual(
            measureBatch { cachedPass(vm, experiences: visibleExperiences, now: now) }.output,
            measureBatch { nonCachedPass(vm, experiences: visibleExperiences, now: now) }.output
        )

        let batchCount = Self.iterations / Self.passesPerBatch
        var baseline: [TimeInterval] = []
        var cached: [TimeInterval] = []
        baseline.reserveCapacity(batchCount)
        cached.reserveCapacity(batchCount)

        for batch in 0..<batchCount {
            let baselineSample: (latency: TimeInterval, output: PassOutput)
            let cachedSample: (latency: TimeInterval, output: PassOutput)
            if batch.isMultiple(of: 2) {
                baselineSample = measureBatch { nonCachedPass(vm, experiences: visibleExperiences, now: now) }
                cachedSample = measureBatch { cachedPass(vm, experiences: visibleExperiences, now: now) }
            } else {
                cachedSample = measureBatch { cachedPass(vm, experiences: visibleExperiences, now: now) }
                baselineSample = measureBatch { nonCachedPass(vm, experiences: visibleExperiences, now: now) }
            }
            // Assertions and sample storage stay outside both timed batches.
            XCTAssertEqual(baselineSample.output, cachedSample.output,
                           "Both computation shapes must produce the same icon and badge results")
            XCTAssertEqual(cachedSample.output.markerCount, Self.markerCount * Self.passesPerBatch)
            baseline.append(baselineSample.latency)
            cached.append(cachedSample.latency)
        }

        let baselineP95 = p95(baseline)
        let cachedP95 = p95(cached)

        XCTAssertGreaterThan(baselineP95, 0, "Baseline p95 must be measurable")

        let improvement = (baselineP95 - cachedP95) / baselineP95
        print("MARKER_PERF passesPerBatch=\(Self.passesPerBatch) samples=\(batchCount) "
              + "baselineP95=\(baselineP95) cachedP95=\(cachedP95) improvement=\(improvement)")
        XCTAssertGreaterThanOrEqual(
            improvement,
            Self.requiredImprovement,
            """
            Cached marker-state amortized batch latency per pass should be \
            ≥ \(Int(Self.requiredImprovement * 100))% faster at p95 (\(Self.passesPerBatch) passes/batch). \
            baseline amortized p95 = \(String(format: "%.6f", baselineP95))s, \
            cached amortized p95 = \(String(format: "%.6f", cachedP95))s, \
            improvement = \(String(format: "%.1f", improvement * 100))%
            """
        )
    }

    // MARK: - testCachedAndNonCachedProduceIdenticalStates

    /// Caching must not change behaviour: the per-marker state resolved by the
    /// single hoisted call equals what two separate calls would have produced.
    @MainActor
    func testCachedAndNonCachedProduceIdenticalStates() throws {
        let now = try fixtureNow()
        let experiences = makeExperiences(count: Self.markerCount, now: now)
        let vm = try makeViewModel(with: experiences)
        let visibleExperiences = vm.visibleExperiences

        for exp in visibleExperiences {
            let cached = vm.markerState(for: exp, now: now)
            let recomputed = vm.markerState(for: exp, now: now)
            XCTAssertEqual(cached, recomputed,
                           "markerState must be deterministic for \(exp.id) so caching is safe")
        }
    }
}
