import XCTest
@testable import SoloCompass

/// I15: the City Codex must show real personal history only — no invented
/// dates, no borrowed omen lines, no fake "completed" progression. The old
/// builder stamped today's omen onto past days and marked the first card done.
/// `ArchiveView.codexEntries(from:)` is the pure rule now in use.
final class ArchiveCodexEntryTests: XCTestCase {

    private func record(_ city: String, daysAgo: Double, title: String) -> ArchiveView.CodexSourceRecord {
        ArchiveView.CodexSourceRecord(
            cityCode: city,
            visitedAt: Date(timeIntervalSince1970: 1_700_000_000 - daysAgo * 86_400),
            title: title
        )
    }

    func testNoRecordsProducesNoCards() {
        XCTAssertTrue(
            ArchiveView.codexEntries(from: []).isEmpty,
            "A new user with no visits must see an empty state, not fabricated history"
        )
    }

    func testEntriesCarryOnlyRealDatesAndTitles() {
        let records = [
            record("cmi", daysAgo: 2, title: "Kalare market alley"),
            record("cmi", daysAgo: 5, title: "Older visit"),
            record("lis", daysAgo: 1, title: "Miradouro da Senhora"),
        ]
        let entries = ArchiveView.codexEntries(from: records)

        XCTAssertEqual(entries.count, 2, "one card per visited city")
        let realDates = Set(records.map(\.visitedAt))
        let realTitles = Set(records.map(\.title))
        for entry in entries {
            XCTAssertTrue(realDates.contains(entry.id), "card date must be a real visit date")
            XCTAssertTrue(realTitles.contains(entry.line), "card text must be real visit content")
        }
    }

    func testNewestVisitPerCityWins() {
        let entries = ArchiveView.codexEntries(from: [
            record("cmi", daysAgo: 9, title: "Older stop"),
            record("cmi", daysAgo: 1, title: "Newest stop"),
        ])
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.line, "Newest stop")
    }

    func testEntryCountIsCappedAtSix() {
        let records = (0..<10).map { record("city\($0)", daysAgo: Double($0), title: "Place \($0)") }
        XCTAssertEqual(ArchiveView.codexEntries(from: records).count, 6)
    }

    /// Cards are "collected" uniformly because they exist — there is no fake
    /// one-of-many completion progression any more.
    func testAllRealEntriesShareOneCollectedState() {
        let entries = ArchiveView.codexEntries(from: [
            record("cmi", daysAgo: 3, title: "A"),
            record("lis", daysAgo: 1, title: "B"),
        ])
        XCTAssertEqual(entries.map(\.completed), [true, true])
    }
}
