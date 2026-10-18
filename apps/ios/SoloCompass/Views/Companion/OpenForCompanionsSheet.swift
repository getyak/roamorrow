import SwiftUI

/// US-039 — Host converts a private itinerary into a recruiting route.
///
/// Presented from ItineraryDetailView. On submit, builds a Route via
/// Route(itinerary:) from US-005, attaches a RouteCompanion with the form
/// values (status = .open, hostId = deviceId, confirmedMembers = [deviceId]),
/// and persists via RouteStore.save.
public struct OpenForCompanionsSheet: View {
    let itinerary: Itinerary

    @Environment(\.dismiss) private var dismiss

    // MARK: - Form state

    @State private var departureFrom: Date
    @State private var departureTo: Date
    @State private var departureTime: Date
    @State private var pace: Pace = .standard
    @State private var maxMembers: Int = 4
    @State private var visibility: RouteCompanionVisibility = .public
    @State private var hostMessage: String = ""

    /// True only while the creation write is in flight — blocks duplicate
    /// submits without permanently disabling a failed form (contract 3).
    @State private var isSubmitting = false
    /// Non-nil after a failed persist. The form keeps every value so the
    /// traveler can retry; nothing is claimed created.
    @State private var submitErrorText: String?

    private let storeProvider: () -> RouteStore

    public init(
        itinerary: Itinerary,
        storeProvider: @escaping () -> RouteStore = { RouteStore() }
    ) {
        self.itinerary = itinerary
        self.storeProvider = storeProvider

        // Default departure window to the itinerary's own dates. Civil-day
        // semantics (contract 6): "2026-04-01" must READ as April 1st on any
        // device timezone — the old UTC parse showed it as March 31st in
        // America/Los_Angeles.
        let from = Self.parseDate(itinerary.startDate) ?? Date()
        let to = Self.parseDate(itinerary.endDate) ?? from.addingTimeInterval(86400 * 3)
        _departureFrom = State(initialValue: from)
        _departureTo = State(initialValue: max(from, to))
        // Default departure time: 09:00 on the from date.
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: from)
        comps.hour = 9; comps.minute = 0
        _departureTime = State(initialValue: Calendar.current.date(from: comps) ?? from)
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            Form {
                submitErrorSection
                departureDateSection
                paceSection
                membersSection
                visibilitySection
                hostMessageSection
            }
            .navigationTitle(NSLocalizedString(
                "openForCompanions.sheet.title",
                comment: "Open For Companions sheet nav title"
            ))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("action.cancel", comment: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString(
                        "openForCompanions.submit",
                        comment: "Submit button: create recruiting route"
                    )) {
                        submit()
                    }
                    .fontWeight(.semibold)
                    .disabled(isSubmitting)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        // Protect an edited recruiting form (host message typed, or any default
        // pace/size/visibility changed) from a stray swipe-down.
        .interactiveDismissDisabled(
            !hostMessage.trimmingCharacters(in: .whitespaces).isEmpty
                || pace != .standard
                || maxMembers != 4
                || visibility != .public
        )
    }

    // MARK: - Sections

    /// Honest failure surface (contract 3): the recruiting route was NOT
    /// created; every form value is retained and Retry re-runs the same submit.
    @ViewBuilder
    private var submitErrorSection: some View {
        if let submitErrorText {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label(submitErrorText, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(CT.sunGoldDeep)
                    Button(NSLocalizedString(
                        "openForCompanions.retry",
                        comment: "Retry creating the recruiting route"
                    )) {
                        self.submitErrorText = nil
                        submit()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CT.accent)
                }
            }
        }
    }

    private var departureDateSection: some View {
        Section {
            DatePicker(
                NSLocalizedString("openForCompanions.departureFrom", comment: "Departure window start label"),
                selection: $departureFrom,
                displayedComponents: .date
            )
            .onChange(of: departureFrom) { _, newFrom in
                if departureTo < newFrom { departureTo = newFrom }
            }
            DatePicker(
                NSLocalizedString("openForCompanions.departureTo", comment: "Departure window end label"),
                selection: $departureTo,
                in: departureFrom...,
                displayedComponents: .date
            )
            DatePicker(
                NSLocalizedString("openForCompanions.departureTime", comment: "Departure time label"),
                selection: $departureTime,
                displayedComponents: .hourAndMinute
            )
        } header: {
            Text(NSLocalizedString("openForCompanions.departure.header", comment: "Departure section header"))
        }
    }

    private var paceSection: some View {
        Section {
            Picker(
                NSLocalizedString("openForCompanions.pace", comment: "Pace picker label"),
                selection: $pace
            ) {
                ForEach(Pace.allCases, id: \.self) { p in
                    Text(p.localizedLabel).tag(p)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text(NSLocalizedString("openForCompanions.pace", comment: "Pace section header"))
        }
    }

    private var membersSection: some View {
        Section {
            Stepper(
                String(format: NSLocalizedString(
                    "openForCompanions.maxMembers.value",
                    comment: "Max members stepper value; %d = count"
                ), maxMembers),
                value: $maxMembers,
                in: 2...8
            )
        } header: {
            Text(NSLocalizedString("openForCompanions.maxMembers", comment: "Max members section header"))
        }
    }

    private var visibilitySection: some View {
        Section {
            Picker(
                NSLocalizedString("openForCompanions.visibility", comment: "Visibility picker label"),
                selection: $visibility
            ) {
                Text(NSLocalizedString("openForCompanions.visibility.public", comment: "Public visibility option"))
                    .tag(RouteCompanionVisibility.public)
                Text(NSLocalizedString("openForCompanions.visibility.linkOnly", comment: "Link-only visibility option"))
                    .tag(RouteCompanionVisibility.linkOnly)
            }
            .pickerStyle(.segmented)
        } header: {
            Text(NSLocalizedString("openForCompanions.visibility", comment: "Visibility section header"))
        }
    }

    private var hostMessageSection: some View {
        Section {
            TextField(
                NSLocalizedString("openForCompanions.hostMessage.placeholder", comment: "Host message placeholder"),
                text: $hostMessage,
                axis: .vertical
            )
            .lineLimit(3...6)
            .onChange(of: hostMessage) { _, new in
                if new.count > 300 { hostMessage = String(new.prefix(300)) }
            }
        } header: {
            Text(NSLocalizedString("openForCompanions.hostMessage", comment: "Host message section header"))
        }
    }

    // MARK: - Submit

    private func submit() {
        guard !isSubmitting else { return }
        isSubmitting = true
        submitErrorText = nil
        defer { isSubmitting = false }
        let deviceId = DeviceIdentityService.shared.deviceID

        // Consistent civil-day semantics (contract 6): parse, display and
        // submit share ONE calendar, so the day the picker shows is the day
        // written to the departure window on every device timezone.
        let window = DepartureWindow.civilWindow(
            from: departureFrom,
            to: departureTo,
            time: departureTime
        )

        let companion = RouteCompanion(
            status: .open,
            hostId: deviceId,
            departureWindow: window,
            departureLabel: "\(window.from) \(window.time)",
            pacePreference: pace.asPacePreference,
            maxMembers: maxMembers,
            confirmedMembers: [deviceId],
            joinRequests: [],
            visibility: visibility,
            groupConversationId: nil,
            hostMessage: hostMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : hostMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        var route = Route(itinerary: itinerary)
        route = Route(
            id: route.id,
            title: route.title,
            summary: route.summary,
            experienceIds: route.experienceIds,
            cityCode: route.cityCode,
            region: route.region,
            estimatedDuration: route.estimatedDuration,
            distanceMeters: route.distanceMeters,
            pace: pace,
            tags: route.tags,
            source: .userCreated,
            authorId: deviceId,
            bestStartHour: route.bestStartHour,
            bestNow: route.bestNow,
            verification: route.verification,
            companion: companion
        )

        // Durable ack first (contract 3): success haptic + dismissal happen
        // only after the route actually persisted. On failure the form keeps
        // every value and offers a retry.
        do {
            try storeProvider().savePersisted(route)
        } catch {
            submitErrorText = NSLocalizedString(
                "openForCompanions.save.error",
                comment: "Shown when creating the recruiting route fails"
            )
            return
        }
        Haptics.notify(.success)
        dismiss()
    }

    // MARK: - Helpers

    /// Civil-day parse for the itinerary's stored "yyyy-MM-dd" dates
    /// (contract 6) — device calendar, no UTC shift.
    private static func parseDate(_ iso: String) -> Date? {
        CivilDay.parse(iso)
    }
}

// MARK: - Pace helpers

private extension Pace {
    var asPacePreference: PacePreference {
        switch self {
        case .relaxed:  return .relaxed
        case .standard: return .standard
        case .packed:   return .packed
        }
    }
}

// MARK: - Preview

#Preview {
    OpenForCompanionsSheet(itinerary: Itinerary(
        id: ItineraryId(rawValue: "itin_preview"),
        ownerId: "user_preview",
        title: "Tokyo Spring 2026",
        cityCode: "TYO",
        startDate: "2026-04-01",
        endDate: "2026-04-10",
        experienceIds: ["exp_cmi_suan_dok_sunset"],
        note: "Focus on cherry blossom spots.",
        openToCompanions: false,
        createdAt: "2026-01-15T09:00:00Z",
        updatedAt: "2026-01-15T09:00:00Z"
    ))
}
