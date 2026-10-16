import SwiftUI

/// Recovery decision for the visibility-off gate on the companion-post flow.
///
/// When a user tries to open an itinerary to companions while their companion
/// visibility is `.off`, the alert routes them to the real profile editor. On
/// return the flow re-checks the (possibly edited) visibility and either
/// resumes the interrupted intent or leaves the itinerary closed. Kept as a
/// pure decision so XCTest can cover every branch.
enum VisibilityOffRecovery: Equatable {
    /// No interrupted intent — nothing to resume.
    case none
    /// Visibility is now on and the user was mid-intent: continue the flow.
    case resumeCompanionPost
    /// Visibility is still off: keep the itinerary closed.
    case stillBlocked

    static func decide(visibility: CompanionVisibility, hadPendingIntent: Bool) -> VisibilityOffRecovery {
        guard hadPendingIntent else { return .none }
        return visibility == .off ? .stillBlocked : .resumeCompanionPost
    }
}

/// Detail view for a single itinerary.
/// Shows all fields: title, city, dates, note, companion toggle, and pinned experiences.
/// Supports drag-to-reorder and "Import from Favorites".
///
/// US-010: the companion toggle is interactive — enabling it prompts for a blurb
/// and categories, then creates a CompanionPost. Disabling it removes the post.
/// When the user's companion visibility is .off, the toggle is blocked with guidance.
public struct ItineraryDetailView: View {
    let itinerary: Itinerary

    @Environment(UserPreferences.self) private var preferences
    @Environment(ExperienceService.self) private var experienceService

    private let store: ItineraryStore
    @State private var experienceIds: [String]
    @State private var openToCompanions: Bool
    @State private var showingImportConfirm = false
    @State private var importedCount: Int?

    // Companion post flow (US-010)
    @State private var showingCompanionPostSheet = false
    @State private var showingVisibilityOffAlert = false
    @State private var showingRemovePostConfirm = false

    // Visibility recovery (I05): open the real profile editor from the
    // visibility-off alert, then re-check visibility when the user returns.
    @State private var showingProfileSettings = false
    @State private var pendingCompanionPostIntent = false

    // Open for companions flow (US-039)
    @State private var showingOpenForCompanionsSheet = false

    // Save-failure recovery (contract 3): a failed publish / unpublish / reorder
    // keeps the previous values, explains, and offers a retry that re-runs the
    // exact failed write. Success feedback only after the durable ack.
    @State private var saveErrorMessage: String?
    @State private var retryAction: (() -> Void)?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    public init(itinerary: Itinerary, store: ItineraryStore = ItineraryStore()) {
        self.itinerary = itinerary
        self.store = store
        _experienceIds = State(initialValue: itinerary.experienceIds)
        _openToCompanions = State(initialValue: itinerary.openToCompanions)
    }

    private var formattedStart: String {
        guard let d = iso8601Date(itinerary.startDate) else { return itinerary.startDate }
        return Self.dateFormatter.string(from: d)
    }

    private var formattedEnd: String {
        guard let d = iso8601Date(itinerary.endDate) else { return itinerary.endDate }
        return Self.dateFormatter.string(from: d)
    }

    private var activePost: CompanionPost? {
        preferences.activeCompanionPosts[itinerary.id.rawValue]
    }

    public var body: some View {
        List {
            // MARK: Header section
            Section {
                LabeledDetailRow(
                    label: NSLocalizedString("itinerary.detail.city", comment: "City label"),
                    value: itinerary.cityCode
                )
                LabeledDetailRow(
                    label: NSLocalizedString("itinerary.detail.startDate", comment: "Start date label"),
                    value: formattedStart
                )
                LabeledDetailRow(
                    label: NSLocalizedString("itinerary.detail.endDate", comment: "End date label"),
                    value: formattedEnd
                )
            }

            // MARK: Note section
            if let note = itinerary.note, !note.isEmpty {
                Section(NSLocalizedString("itinerary.detail.note.header", comment: "Notes section header")) {
                    Text(note)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
            }

            // MARK: Companion section (US-010)
            companionSection

            // MARK: Experiences section (drag-to-reorder)
            Section {
                if experienceIds.isEmpty {
                    Text(NSLocalizedString("itinerary.detail.experiences.empty", comment: "No experiences pinned yet"))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(experienceIds, id: \.self) { expId in
                        experienceRow(expId)
                    }
                    .onMove(perform: moveExperience)
                }
            } header: {
                HStack {
                    Text(String(
                        format: NSLocalizedString("itinerary.detail.experiences.header", comment: "Experiences header with count"),
                        experienceIds.count
                    ))
                    Spacer()
                    if !preferences.favoritedExperiences.subtracting(Set(experienceIds)).isEmpty {
                        Button {
                            showingImportConfirm = true
                        } label: {
                            Text(NSLocalizedString("itinerary.detail.importFavorites", comment: "Import from favorites button"))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(CT.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(itinerary.title)
        .navigationBarTitleDisplayMode(.large)
        .environment(\.editMode, .constant(.active))
        .confirmationDialog(
            NSLocalizedString("itinerary.detail.importFavorites.confirm.title", comment: "Import favorites confirm title"),
            isPresented: $showingImportConfirm,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("itinerary.detail.importFavorites.confirm.action", comment: "Import confirm action")) {
                importFavorites()
            }
            Button(NSLocalizedString("action.cancel", comment: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(
                format: NSLocalizedString("itinerary.detail.importFavorites.confirm.message", comment: "Import favorites confirm message"),
                preferences.favoritedExperiences.count
            ))
        }
        .alert(
            NSLocalizedString("companion.post.visibilityOff.title", comment: "Visibility off alert title"),
            isPresented: $showingVisibilityOffAlert
        ) {
            Button(NSLocalizedString("companion.post.visibilityOff.action", comment: "Open profile settings")) {
                // The alert is dismissing while this runs, so present the real
                // profile editor on the next runloop instead of racing it.
                pendingCompanionPostIntent = true
                DispatchQueue.main.async {
                    showingProfileSettings = true
                }
            }
            Button(NSLocalizedString("action.cancel", comment: "Cancel"), role: .cancel) {
                pendingCompanionPostIntent = false
            }
        } message: {
            Text(NSLocalizedString("companion.post.visibilityOff.message", comment: "Visibility off alert message"))
        }
        .sheet(isPresented: $showingProfileSettings, onDismiss: resumeBlockedFlow) {
            // The real "My Profile" editor (CompanionProfileView alias) with its
            // required UserPreferences dependency, in its own stack so the inner
            // walked-routes push still works from this modal entry point.
            NavigationStack {
                MyProfileEditView()
                    .environment(preferences)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(NSLocalizedString("common.done", comment: "Done")) {
                                showingProfileSettings = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingCompanionPostSheet) {
            CompanionPostCreationSheet(itinerary: itinerary) { post in
                activateCompanionPost(post)
            }
        }
        .sheet(isPresented: $showingOpenForCompanionsSheet) {
            OpenForCompanionsSheet(itinerary: itinerary)
        }
        .overlay(alignment: .bottom) {
            if let count = importedCount {
                importedToast(count: count)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 16)
            } else if let saveErrorMessage {
                saveErrorToast(message: saveErrorMessage)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 16)
            }
        }
    }

    /// Inline failure toast with a real retry (contract 3) — the previous
    /// value/order is already restored by the action that failed.
    private func saveErrorToast(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(CT.sunGoldDeep)
            Text(message)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            if retryAction != nil {
                Button(NSLocalizedString("itinerary.detail.save.retry", comment: "Retry the failed itinerary write")) {
                    let retry = retryAction
                    saveErrorMessage = nil
                    retryAction = nil
                    retry?()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(CT.accent)
                .frame(minHeight: HitTargetMetrics.minimum)
            }
            Button {
                withAnimation {
                    saveErrorMessage = nil
                    retryAction = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: HitTargetMetrics.minimum, height: HitTargetMetrics.minimum)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(NSLocalizedString("common.ok", comment: "Dismiss")))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color(.systemBackground)).shadow(radius: 4))
    }

    // MARK: - Experience row

    @ViewBuilder
    private func experienceRow(_ expId: String) -> some View {
        if let exp = experienceService.getExperience(id: expId) {
            HStack(spacing: 12) {
                Image(systemName: "line.3.horizontal")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                ZStack {
                    Circle()
                        .fill(exp.category.color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: exp.category.symbol)
                        .font(.footnote)
                        .foregroundStyle(exp.category.color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(exp.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(exp.oneLiner)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("\(exp.title), \(exp.oneLiner)"))
        } else {
            HStack(spacing: 12) {
                Image(systemName: "line.3.horizontal")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(.secondary)
                Text(NSLocalizedString("itinerary.detail.experience.unavailable", comment: "Unavailable experience fallback"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Companion section

    @ViewBuilder
    private var companionSection: some View {
        Section {
            // Interactive toggle (US-010)
            Toggle(
                NSLocalizedString("companion.post.openToCompanions", comment: "Open to companions toggle"),
                isOn: openToCompanionsBinding
            )
            .tint(CT.accent)

            // Show post blurb when active
            if let post = activePost {
                VStack(alignment: .leading, spacing: 4) {
                    Text(post.blurb)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if !post.categories.isEmpty {
                        Text(post.categories.map(\.rawValue).joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 2)
            }

            // US-039: Convert to a recruiting route
            Button {
                showingOpenForCompanionsSheet = true
            } label: {
                HStack {
                    Text(NSLocalizedString(
                        "openForCompanions.button",
                        comment: "Button to open itinerary as a recruiting route"
                    ))
                    .foregroundStyle(CT.accent)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        } footer: {
            if openToCompanions {
                Text(NSLocalizedString("companion.post.openToCompanions.footer", comment: "Open to companions footer"))
                    .font(.caption)
            }
        }
    }

    private var openToCompanionsBinding: Binding<Bool> {
        Binding(
            get: { openToCompanions },
            set: { newValue in
                if newValue {
                    // Block if visibility is off
                    guard preferences.companionVisibility != .off else {
                        pendingCompanionPostIntent = true
                        showingVisibilityOffAlert = true
                        return
                    }
                    // Show blurb+categories sheet
                    showingCompanionPostSheet = true
                } else {
                    removeCompanionPost()
                }
            }
        )
    }

    /// Called when the profile editor sheet closes. Re-checks the visibility
    /// the user just edited: if they turned it on, continue the companion-post
    /// flow they were in the middle of; if it is still off, leave the itinerary
    /// closed and drop the pending intent.
    private func resumeBlockedFlow() {
        let outcome = VisibilityOffRecovery.decide(
            visibility: preferences.companionVisibility,
            hadPendingIntent: pendingCompanionPostIntent
        )
        pendingCompanionPostIntent = false
        switch outcome {
        case .none, .stillBlocked:
            break
        case .resumeCompanionPost:
            showingCompanionPostSheet = true
        }
    }

    // MARK: - Actions

    private func activateCompanionPost(_ post: CompanionPost) {
        let now = ISO8601DateFormatter().string(from: Date())
        let updated = Itinerary(
            id: itinerary.id,
            ownerId: itinerary.ownerId,
            title: itinerary.title,
            cityCode: itinerary.cityCode,
            startDate: itinerary.startDate,
            endDate: itinerary.endDate,
            experienceIds: itinerary.experienceIds,
            note: itinerary.note,
            openToCompanions: true,
            createdAt: itinerary.createdAt,
            updatedAt: now
        )
        do {
            // Durable ack first (contract 3): only a successful write flips
            // the UI state, records the post and fires the haptic.
            try store.update(updated)
        } catch {
            openToCompanions = false
            withAnimation {
                saveErrorMessage = NSLocalizedString(
                    "itinerary.detail.save.error",
                    comment: "Shown when an itinerary write fails"
                )
                retryAction = { activateCompanionPost(post) }
            }
            return
        }
        openToCompanions = true
        preferences.activeCompanionPosts[itinerary.id.rawValue] = post
        withAnimation { saveErrorMessage = nil; retryAction = nil }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func removeCompanionPost() {
        let now = ISO8601DateFormatter().string(from: Date())
        let updated = Itinerary(
            id: itinerary.id,
            ownerId: itinerary.ownerId,
            title: itinerary.title,
            cityCode: itinerary.cityCode,
            startDate: itinerary.startDate,
            endDate: itinerary.endDate,
            experienceIds: itinerary.experienceIds,
            note: itinerary.note,
            openToCompanions: false,
            createdAt: itinerary.createdAt,
            updatedAt: now
        )
        do {
            try store.update(updated)
        } catch {
            // Stay open (the previous value) and offer a retry — closing
            // without a write would claim a state that never persisted.
            openToCompanions = true
            withAnimation {
                saveErrorMessage = NSLocalizedString(
                    "itinerary.detail.save.error",
                    comment: "Shown when an itinerary write fails"
                )
                retryAction = { removeCompanionPost() }
            }
            return
        }
        openToCompanions = false
        preferences.activeCompanionPosts.removeValue(forKey: itinerary.id.rawValue)
        withAnimation { saveErrorMessage = nil; retryAction = nil }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func moveExperience(from source: IndexSet, to destination: Int) {
        var ids = experienceIds
        ids.move(fromOffsets: source, toOffset: destination)
        let previous = experienceIds
        experienceIds = ids
        persistOrder(ids, previous: previous)
    }

    /// Persist a reorder; on failure restore the previous visible order and
    /// offer a retry of the exact new order (contract 3).
    private func persistOrder(_ ids: [String], previous: [String]) {
        do {
            try store.reorderExperiences(ids, in: itinerary.id)
            withAnimation { saveErrorMessage = nil; retryAction = nil }
        } catch {
            experienceIds = previous
            withAnimation {
                saveErrorMessage = NSLocalizedString(
                    "itinerary.detail.save.error",
                    comment: "Shown when an itinerary write fails"
                )
                retryAction = {
                    experienceIds = ids
                    persistOrder(ids, previous: previous)
                }
            }
        }
    }

    @ViewBuilder
    private func experienceRow(for expId: String) -> some View {
        if let exp = experienceService.getExperience(id: expId) {
            HStack(spacing: 10) {
                Image(systemName: "line.3.horizontal")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Circle()
                    .fill(exp.category.color.opacity(0.15))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: exp.category.symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(exp.category.color)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(exp.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(exp.oneLiner)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(exp.title). \(exp.oneLiner)")
        } else {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(.secondary)
                Text(String(
                    format: NSLocalizedString("itinerary.detail.experiences.unknown", comment: "Unknown experience fallback with truncated id"),
                    String(expId.prefix(12))
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(
                format: NSLocalizedString("itinerary.detail.experiences.unknown", comment: "Unknown experience fallback with truncated id"),
                String(expId.prefix(12))
            ))
        }
    }

    private func importFavorites() {
        let favIds = preferences.favoritedExperiences
        do {
            let count = try store.importFavorites(favIds, into: itinerary.id)
            guard count > 0 else { return }
            experienceIds = store.load(id: itinerary.id)?.experienceIds ?? experienceIds
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation {
                importedCount = count
                saveErrorMessage = nil
                retryAction = nil
            }
            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                withAnimation { importedCount = nil }
            }
        } catch {
            // Keep the current list untouched and offer a retry (contract 3).
            withAnimation {
                saveErrorMessage = NSLocalizedString(
                    "itinerary.detail.save.error",
                    comment: "Shown when an itinerary write fails"
                )
                retryAction = { importFavorites() }
            }
        }
    }

    private func importedToast(count: Int) -> some View {
        Text(String(
            format: NSLocalizedString("itinerary.detail.importFavorites.toast", comment: "Import favorites success toast"),
            count
        ))
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Capsule().fill(Color(.systemBackground)).shadow(radius: 4))
        .foregroundStyle(.primary)
    }
}

// MARK: - Companion post creation sheet (US-010)

/// Sheet for entering blurb + categories before enabling the companion post.
private struct CompanionPostCreationSheet: View {
    let itinerary: Itinerary
    let onConfirm: (CompanionPost) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var blurb = ""
    @State private var selectedCategories: Set<ExperienceCategory> = []

    private var isValid: Bool { !blurb.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        NSLocalizedString("companion.post.blurb.placeholder", comment: "Blurb placeholder"),
                        text: $blurb,
                        axis: .vertical
                    )
                    .lineLimit(2...4)
                    .onChange(of: blurb) { _, new in
                        if new.count > 280 { blurb = String(new.prefix(280)) }
                    }
                } header: {
                    Text(NSLocalizedString("companion.post.blurb.header", comment: "Blurb section header"))
                }

                Section {
                    ForEach(ExperienceCategory.allCases, id: \.self) { cat in
                        Button {
                            if selectedCategories.contains(cat) {
                                selectedCategories.remove(cat)
                            } else {
                                selectedCategories.insert(cat)
                            }
                        } label: {
                            HStack {
                                Text(cat.rawValue.capitalized)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedCategories.contains(cat) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(CT.accent)
                                        .font(.footnote.weight(.semibold))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(NSLocalizedString("companion.post.categories.header", comment: "Categories section header"))
                }
            }
            .navigationTitle(NSLocalizedString("companion.post.openToCompanions", comment: "Sheet nav title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(NSLocalizedString("action.cancel", comment: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("itinerary.form.action.save", comment: "Save")) {
                        confirm()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func confirm() {
        let now = ISO8601DateFormatter().string(from: Date())
        let post = CompanionPost(
            id: CompanionPostId(rawValue: UUID().uuidString),
            authorId: "local",
            mode: .itinerary,
            itineraryId: itinerary.id,
            blurb: blurb.trimmingCharacters(in: .whitespaces),
            categories: Array(selectedCategories),
            cityCode: itinerary.cityCode,
            activeFrom: itinerary.startDate,
            activeTo: itinerary.endDate,
            createdAt: now,
            updatedAt: now
        )
        onConfirm(post)
        dismiss()
    }
}

// MARK: - Subviews

private struct LabeledDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Helpers

private func iso8601Date(_ string: String) -> Date? {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.timeZone = TimeZone(identifier: "UTC")
    return f.date(from: string)
}

// MARK: - Preview

#Preview("With note and experiences") {
    NavigationStack {
        ItineraryDetailView(itinerary: Itinerary(
            id: ItineraryId(rawValue: "itin_preview"),
            ownerId: "user_preview",
            title: "Tokyo Spring 2026",
            cityCode: "TYO",
            startDate: "2026-04-01",
            endDate: "2026-04-10",
            experienceIds: ["exp_cmi_suan_dok_sunset", "exp_cmi_nimman_coffee", "exp_cmi_bookstore_work"],
            note: "Focus on cherry blossom spots and quiet cafes.",
            openToCompanions: true,
            createdAt: "2026-01-15T09:00:00Z",
            updatedAt: "2026-01-15T09:00:00Z"
        ))
    }
    .environment(UserPreferences())
    .environment(ExperienceService(seed: ExperienceService.hardcodedSeed))
}

#Preview("Open to companions, no experiences") {
    NavigationStack {
        ItineraryDetailView(itinerary: Itinerary(
            id: ItineraryId(rawValue: "itin_preview_b"),
            ownerId: "user_preview",
            title: "Bali Retreat",
            cityCode: "DPS",
            startDate: "2026-06-10",
            endDate: "2026-06-20",
            experienceIds: [],
            note: nil,
            openToCompanions: true,
            createdAt: "2026-03-01T09:00:00Z",
            updatedAt: "2026-03-01T09:00:00Z"
        ))
    }
    .environment(UserPreferences())
    .environment(ExperienceService(seed: ExperienceService.hardcodedSeed))
}

#Preview("Visibility off — toggle blocked") {
    let prefs = UserPreferences()
    prefs.companionVisibility = .off
    return NavigationStack {
        ItineraryDetailView(itinerary: Itinerary(
            id: ItineraryId(rawValue: "itin_preview_c"),
            ownerId: "user_preview",
            title: "Seoul Week",
            cityCode: "SEL",
            startDate: "2026-09-01",
            endDate: "2026-09-07",
            experienceIds: [],
            note: nil,
            openToCompanions: false,
            createdAt: "2026-05-01T09:00:00Z",
            updatedAt: "2026-05-01T09:00:00Z"
        ))
    }
    .environment(prefs)
    .environment(ExperienceService(seed: ExperienceService.hardcodedSeed))
}
