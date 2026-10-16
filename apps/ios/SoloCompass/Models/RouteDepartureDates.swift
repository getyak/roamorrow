import Foundation

// MARK: - CivilDay

/// Civil-day ("yyyy-MM-dd") semantics for itinerary dates and departure windows.
///
/// Itinerary `startDate` / `endDate` and `DepartureWindow.from` / `.to` are
/// CIVIL DAYS: a calendar date with no time and no timezone — "2026-04-01"
/// means April 1st in whichever city the trip happens in. The previous
/// OpenForCompanions path parsed with a UTC formatter but formatted with the
/// device timezone, so a device in a negative-offset zone (e.g.
/// America/Los_Angeles) displayed the picked day one day early and wrote it
/// back one day late.
///
/// `CivilDay` keeps parse / display / submit on ONE calendar so the day a
/// traveler reads is the day that gets submitted, on any device timezone and
/// for any destination city.
public enum CivilDay {
    public static let template = "yyyy-MM-dd"

    /// A calendar whose timezone drives civil-day conversion. Callers must use
    /// the SAME calendar for `parse` and `format` — that pairing is the whole
    /// contract. Defaults to the device's current calendar.
    public static func calendar(timeZone: TimeZone = .current) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal
    }

    /// Parse a civil-day string into an absolute instant that falls on that
    /// same civil day in `calendar`'s timezone. Built at local noon so DST
    /// transitions that skip or fold midnight can never shift the day.
    /// Returns nil for malformed input.
    public static func parse(_ string: String, calendar: Calendar = CivilDay.calendar()) -> Date? {
        guard string.range(of: "^[0-9]{4}-[0-9]{2}-[0-9]{2}$", options: .regularExpression) != nil else { return nil }
        let parser = DateFormatter()
        parser.calendar = calendar
        parser.timeZone = calendar.timeZone
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = template
        parser.isLenient = false
        guard let date = parser.date(from: string), parser.string(from: date) == string else { return nil }
        return noon(on: date, calendar: calendar)
    }

    /// Format an instant as a civil-day string in `calendar`.
    public static func format(_ date: Date, calendar: Calendar = CivilDay.calendar()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = template
        return formatter.string(from: date)
    }

    /// Year / month / day of an instant as seen in `calendar`.
    public static func components(
        _ date: Date,
        calendar: Calendar = CivilDay.calendar()
    ) -> (year: Int, month: Int, day: Int) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return (c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// The instant's civil day in `calendar`, expressed as y/m/d equality.
    public static func isSameDay(_ lhs: Date, _ rhs: Date, calendar: Calendar = CivilDay.calendar()) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }

    /// Local-noon anchor on the same civil day as `date` (DST-safe anchor).
    public static func noon(on date: Date, calendar: Calendar = CivilDay.calendar()) -> Date {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        var anchored = DateComponents()
        anchored.year = c.year
        anchored.month = c.month
        anchored.day = c.day
        anchored.hour = 12
        return calendar.date(from: anchored) ?? date
    }

    /// True when the civil day of `string` is within the inclusive window
    /// [today, today + days) in `calendar` — used by the recruiting sort that
    /// asks "is this departure within the next week?".
    public static func isWithinNext(
        _ string: String,
        days: Int,
        now: Date = Date(),
        calendar: Calendar = CivilDay.calendar()
    ) -> Bool {
        guard let date = parse(string, calendar: calendar) else { return false }
        let today = noon(on: now, calendar: calendar)
        guard let limit = calendar.date(byAdding: .day, value: days, to: today) else { return false }
        return date >= today && date <= limit
    }
}

// MARK: - DepartureWindow building

public extension DepartureWindow {
    /// Build a departure window from civil-day date picks and a clock hint.
    ///
    /// The three inputs are absolute instants chosen via pickers rendered in
    /// the DEVICE calendar; the strings that leave this helper are civil days
    /// / a "HH:mm" wall-clock hint in that same calendar, so a route opened in
    /// another city or on another device shows the exact days the host picked.
    /// `from` may not be after `to` — the earlier day wins for `from` and the
    /// later day for `to`, so a swapped pair still yields a valid window.
    static func civilWindow(
        from: Date,
        to: Date,
        time: Date,
        calendar: Calendar = CivilDay.calendar()
    ) -> DepartureWindow {
        let lo = min(from, to)
        let hi = max(from, to)
        let clock = DateFormatter()
        clock.locale = Locale(identifier: "en_US_POSIX")
        clock.calendar = calendar
        clock.timeZone = calendar.timeZone
        clock.dateFormat = "HH:mm"
        return DepartureWindow(
            startDate: CivilDay.format(lo, calendar: calendar),
            to: CivilDay.format(hi, calendar: calendar),
            time: clock.string(from: time)
        )
    }
}
