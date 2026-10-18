import Foundation

// MARK: - ExperienceReportDraft

/// A traveler's report about a place, saved on THIS device.
///
/// There is no report-upload backend: the honest pipeline is (1) save the
/// draft locally, (2) let the traveler send it themselves through a
/// user-controlled email/share composition addressed to the confirmed support
/// inbox. `status` therefore distinguishes `savedLocally` (written here, not
/// sent anywhere) from `sent` (the mail composer reported a completed send).
/// Nothing in this file transmits anything on its own.
public struct ExperienceReportDraft: Codable, Identifiable, Equatable, Sendable {
    /// Distinguishes a local draft from a completed user-controlled mail send.
    public enum Status: String, Codable, Sendable {
        /// Written to this device only. NOT sent to anyone.
        case savedLocally
        /// A user-controlled mail composition completed with `.sent`.
        case sent
    }

    public let id: String
    /// The experience the report is about.
    public let experienceId: String
    /// `ReportIssueSheet.ReportReason.rawValue`. Mutable for re-entry edits
    /// (review closure 6) — editing never changes the id or claims a send.
    public var reasonRaw: String
    public var detail: String
    public let createdAt: Date
    public var status: Status
    public var sentAt: Date?
}

// MARK: - ExperienceReportDraftStore

/// Local persistence for report drafts. Small Codable array in `UserDefaults`
/// — same atomic-blob approach as `UserPreferences`. Injectable `UserDefaults`
/// so tests never touch the standard suite.
@MainActor
public final class ExperienceReportDraftStore {
    /// The confirmed support inbox. The compose step is always user-driven:
    /// nothing is sent without the traveler pressing send in the composer.
    public static let supportEmailAddress = "hello@roamorrow.com"

    private static let storageKey = "com.solocompass.experienceReportDrafts.v1"

    private let defaults: UserDefaults
    public private(set) var drafts: [ExperienceReportDraft]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder.iso8601Decoder.decode([ExperienceReportDraft].self, from: data) {
            self.drafts = decoded
        } else {
            self.drafts = []
        }
    }

    /// Persist a new draft as `savedLocally`. Never claims anything was sent.
    @discardableResult
    public func saveDraft(
        experienceId: String,
        reasonRaw: String,
        detail: String,
        now: Date = Date(),
        id: String = "rpt_\(UUID().uuidString)"
    ) -> ExperienceReportDraft {
        let draft = ExperienceReportDraft(
            id: id,
            experienceId: experienceId,
            reasonRaw: reasonRaw,
            detail: detail,
            createdAt: now,
            status: .savedLocally,
            sentAt: nil
        )
        drafts.insert(draft, at: 0)
        persist()
        return draft
    }

    /// Mark a draft as actually sent. ONLY call after the mail composer
    /// reports `.sent` — share-sheet completion is not proof of delivery, so
    /// those flows must leave the status at `savedLocally`.
    public func markSent(id: String, at date: Date = Date()) {
        guard let idx = drafts.firstIndex(where: { $0.id == id }) else { return }
        drafts[idx].status = .sent
        drafts[idx].sentAt = date
        persist()
    }

    /// Most recent draft for an experience, for re-entry / retained-draft UI.
    public func latestDraft(forExperienceId experienceId: String) -> ExperienceReportDraft? {
        drafts.first { $0.experienceId == experienceId }
    }

    /// Most recent UNSENT draft for an experience — the only kind that may be
    /// restored into the composer as "pending" (review closure 6). A `.sent`
    /// draft is history, not pending work.
    public func latestUnsentDraft(forExperienceId experienceId: String) -> ExperienceReportDraft? {
        drafts.first { $0.experienceId == experienceId && $0.status == .savedLocally }
    }

    /// Update an existing draft's content after a re-entry edit. Keeps the
    /// same id and `savedLocally` status — editing never claims a send.
    @discardableResult
    public func updateDraft(
        id: String,
        reasonRaw: String,
        detail: String
    ) -> ExperienceReportDraft? {
        guard let idx = drafts.firstIndex(where: { $0.id == id }) else { return nil }
        // Sent content is an immutable receipt. An edit starts a new local draft.
        if drafts[idx].status == .sent {
            return saveDraft(experienceId: drafts[idx].experienceId, reasonRaw: reasonRaw, detail: detail)
        }
        drafts[idx].reasonRaw = reasonRaw
        drafts[idx].detail = detail
        persist()
        return drafts[idx]
    }

    /// Returns the stored draft or send receipt with this stable identifier.
    public func draft(id: String) -> ExperienceReportDraft? {
        drafts.first { $0.id == id }
    }

    private func persist() {
        guard let data = try? JSONEncoder.iso8601Encoder.encode(drafts) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

// MARK: - ExperienceReportComposer

/// Builds the user-controlled email/share composition for a report draft.
/// Pure text assembly — sending happens only when the traveler acts inside the
/// system mail/share UI.
public enum ExperienceReportComposer {
    /// Identifies the experience in the support email subject.
    public static func emailSubject(experienceTitle: String) -> String {
        "[Roamorrow] \(experienceTitle)"
    }

    /// Plain-text report body. Includes the machine-readable ids so support
    /// can act, plus the traveler's own words verbatim.
    public static func emailBody(
        experienceTitle: String,
        placeName: String?,
        cityCode: String?,
        reasonLabel: String,
        detail: String
    ) -> String {
        var lines: [String] = []
        lines.append(String(format: NSLocalizedString(
            "report.email.body.experience",
            comment: "Report email body — experience line"
        ), experienceTitle))
        if let placeName, !placeName.isEmpty {
            lines.append(String(format: NSLocalizedString(
                "report.email.body.place",
                comment: "Report email body — place line"
            ), placeName))
        }
        if let cityCode, !cityCode.isEmpty {
            lines.append(String(format: NSLocalizedString(
                "report.email.body.city",
                comment: "Report email body — city line"
            ), cityCode))
        }
        lines.append(String(format: NSLocalizedString(
            "report.email.body.reason",
            comment: "Report email body — reason line"
        ), reasonLabel))
        lines.append("")
        lines.append(detail.isEmpty
            ? NSLocalizedString("report.email.body.noDetail", comment: "Report email body — no detail")
            : detail)
        return lines.joined(separator: "\n")
    }

    /// `mailto:` fallback for devices without a configured mail account. The
    /// system still requires the user to press send inside the mail app.
    public static func mailtoURL(subject: String, body: String) -> URL? {
        var comps = URLComponents()
        comps.scheme = "mailto"
        comps.path = ExperienceReportDraftStore.supportEmailAddress
        comps.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]
        return comps.url
    }
}
