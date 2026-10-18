import XCTest
@testable import SoloCompass

/// Civil-day semantics for itinerary dates and departure windows (contract 6):
/// parse, display and submit share one calendar, so "2026-04-01" is April 1st
/// on every device timezone and in every destination city. The regression
/// target is the old UTC-parse → device-format pair that shifted negative-
/// offset devices (America/Los_Angeles) a whole day early.
@MainActor
final class CivilDayTests: XCTestCase {

    private func calendar(_ identifier: String) -> Calendar {
        guard let tz = TimeZone(identifier: identifier) else {
            XCTFail("missing timezone \(identifier)")
            return CivilDay.calendar()
        }
        return CivilDay.calendar(timeZone: tz)
    }

    func testDefaultFormattingStoresGregorianYearForBuddhistDisplayDate() throws {
        var displayCalendar = Calendar(identifier: .buddhist)
        displayCalendar.timeZone = .current
        let date = try XCTUnwrap(displayCalendar.date(from: DateComponents(year: 2569, month: 10, day: 16, hour: 12)))
        XCTAssertEqual(CivilDay.format(date), "2026-10-16")
        let restored = try XCTUnwrap(CivilDay.parse("2026-10-16"))
        XCTAssertEqual(displayCalendar.component(.year, from: restored), 2569)
    }

    // MARK: - America/Los_Angeles: unchanged day (regression)

    func testLosAngelesRoundTripKeepsTheDayUnchanged() {
        let la = calendar("America/Los_Angeles")
        let date = CivilDay.parse("2026-04-01", calendar: la)
        XCTAssertNotNil(date)

        let comps = CivilDay.components(date!, calendar: la)
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 4)
        XCTAssertEqual(comps.day, 1, "April 1st must READ as April 1st in Los Angeles")
        XCTAssertEqual(CivilDay.format(date!, calendar: la), "2026-04-01")
    }

    func testNegativeOffsetNoLongerShiftsTheDay() {
        let la = calendar("America/Los_Angeles")
        // The OLD path parsed the civil day as UTC midnight…
        var utcParser = DateFormatter()
        utcParser.dateFormat = "yyyy-MM-dd"
        utcParser.timeZone = TimeZone(identifier: "UTC")
        utcParser.locale = Locale(identifier: "en_US_POSIX")
        let legacy = utcParser.date(from: "2026-04-01")
        XCTAssertNotNil(legacy)
        // …and it displayed one day EARLY on a Los Angeles device:
        XCTAssertEqual(CivilDay.format(legacy!, calendar: la), "2026-03-31")

        // The civil-day path shows and submits the day the traveler picked.
        let fixed = CivilDay.parse("2026-04-01", calendar: la)!
        XCTAssertEqual(CivilDay.format(fixed, calendar: la), "2026-04-01")
    }

    // MARK: - Cross-city semantics

    func testCivilDaySurvivesEveryDeviceTimezone() {
        for identifier in ["America/Los_Angeles", "Asia/Shanghai", "Pacific/Auckland", "Asia/Bangkok"] {
            let cal = calendar(identifier)
            guard let date = CivilDay.parse("2026-11-05", calendar: cal) else {
                XCTFail("parse failed in \(identifier)")
                continue
            }
            XCTAssertEqual(
                CivilDay.format(date, calendar: cal),
                "2026-11-05",
                "civil day must round-trip unchanged on \(identifier)"
            )
            let comps = CivilDay.components(date, calendar: cal)
            XCTAssertEqual(comps.year, 2026)
            XCTAssertEqual(comps.month, 11)
            XCTAssertEqual(comps.day, 5, "day components on \(identifier)")
        }
    }

    func testDepartureWindowUsesCivilDaysInAnyCityPairing() {
        // A trip departing Vientiane, edited on devices in different cities:
        // the window strings are civil days and never drift.
        let bangkok = calendar("Asia/Bangkok")
        let la = calendar("America/Los_Angeles")

        let fromBKK = CivilDay.parse("2026-04-01", calendar: bangkok)!
        let toBKK = CivilDay.parse("2026-04-03", calendar: bangkok)!
        var clock = DateFormatter()
        clock.dateFormat = "HH:mm"
        clock.locale = Locale(identifier: "en_US_POSIX")
        clock.timeZone = bangkok.timeZone
        let evening = clock.date(from: "18:30")!

        let windowFromBangkok = DepartureWindow.civilWindow(
            from: fromBKK, to: toBKK, time: evening, calendar: bangkok
        )
        XCTAssertEqual(windowFromBangkok.from, "2026-04-01")
        XCTAssertEqual(windowFromBangkok.to, "2026-04-03")
        XCTAssertEqual(windowFromBangkok.time, "18:30")

        // Same civil picks expressed in the LA device calendar give the same
        // days — the departure is anchored to the TRIP's civil days.
        let fromLA = CivilDay.parse("2026-04-01", calendar: la)!
        let toLA = CivilDay.parse("2026-04-03", calendar: la)!
        clock.timeZone = la.timeZone
        let laEvening = clock.date(from: "18:30")!
        let windowFromLA = DepartureWindow.civilWindow(
            from: fromLA, to: toLA, time: laEvening, calendar: la
        )
        XCTAssertEqual(windowFromLA.from, windowFromBangkok.from)
        XCTAssertEqual(windowFromLA.to, windowFromBangkok.to)
        XCTAssertEqual(windowFromLA.time, windowFromBangkok.time)
    }

    func testDepartureWindowNormalizesSwappedDays() {
        let la = calendar("America/Los_Angeles")
        let a = CivilDay.parse("2026-04-03", calendar: la)!
        let b = CivilDay.parse("2026-04-01", calendar: la)!
        var clock = DateFormatter()
        clock.dateFormat = "HH:mm"
        clock.locale = Locale(identifier: "en_US_POSIX")
        let morning = clock.date(from: "09:00")!

        let window = DepartureWindow.civilWindow(from: a, to: b, time: morning, calendar: la)
        XCTAssertEqual(window.from, "2026-04-01")
        XCTAssertEqual(window.to, "2026-04-03")
    }

    // MARK: - Recruiting "within 7 days" stays day-based

    func testIsWithinNextComparesCivilDaysNotUtcMidnight() {
        let la = calendar("America/Los_Angeles")
        let now = CivilDay.parse("2026-04-01", calendar: la)!

        XCTAssertTrue(CivilDay.isWithinNext("2026-04-01", days: 7, now: now, calendar: la))
        XCTAssertTrue(CivilDay.isWithinNext("2026-04-07", days: 7, now: now, calendar: la))
        XCTAssertFalse(CivilDay.isWithinNext("2026-04-09", days: 7, now: now, calendar: la))
        XCTAssertFalse(CivilDay.isWithinNext("2026-03-31", days: 7, now: now, calendar: la))
        XCTAssertFalse(CivilDay.isWithinNext("not-a-date", days: 7, now: now, calendar: la))
    }

    func testMalformedCivilDayStringReturnsNil() {
        XCTAssertNil(CivilDay.parse(""))
        XCTAssertNil(CivilDay.parse("2026/04/01"))
        XCTAssertNil(CivilDay.parse("04-01-2026"))
    }
}
