import SwiftUI
import SwiftData

/// Sheet that lets the user pin an experience to one of their saved itineraries,
/// or create a new itinerary and pin it in one step.
///
/// The create form is pushed inside this sheet's single `NavigationStack` — no
/// nested sheet presentation — and reports the exact itinerary it persisted.
/// Cancelling the form never pins the experience, and `onSuccess` only runs
/// after persistence succeeded.
public struct AddToItinerarySheet: View {
    /// Experience ids to pin. Single-experience callers use `experienceId:`;
    /// route add-to-itinerary passes every stop so the whole walk lands in the
    /// chosen itinerary in one durable write.
    let experienceIds: [String]
    let experienceTitle: String
    /// Called after a successful add, with the exact itinerary that was updated.
    var onSuccess: ((Itinerary) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(ExperienceService.self) private var experienceService

    private let store: ItineraryStore
    @State private var model: AddToItineraryModel
    /// Local failure surface for the multi-stop write. Non-nil keeps the sheet
    /// open with the user's selection intact (no silent loss).
    @State private var saveErrorMessage: String?
    /// Guards the in-flight write against double taps.
    @State private var isSaving = false
    /// Itinerary just updated (read-back highlight for the multi-stop path).
    @State private var justAddedId: ItineraryId?
    /// Target of the most recent (possibly failed) write — drives Retry.
    @State private var lastAttemptedItineraryId: ItineraryId?

    public init(
        experienceId: String,
        experienceTitle: String,
        store: ItineraryStore = ItineraryStore(),
        onSuccess: ((Itinerary) -> Void)? = nil
    ) {
        self.init(
            experienceIds: [experienceId],
            experienceTitle: experienceTitle,
            store: store,
            onSuccess: onSuccess
        )
    }

    public init(
        experienceIds: [String],
        experienceTitle: String,
        store: ItineraryStore = ItineraryStore(),
        onSuccess: ((Itinerary) -> Void)? = nil
    ) {
        self.experienceIds = experienceIds
        self.experienceTitle = experienceTitle
        self.store = store
        self.onSuccess = onSuccess
        _model = State(initialValue: AddToItineraryModel(store: store))
    }

    // MARK: - Derived

    /// City of the source experience, or nil when it is not loaded.
    private var sourceCityCode: String? {
        guard let firstId = experienceIds.first else { return nil }
        return ItineraryCreationRules.sourceCityCode(experienceId: firstId, in: experienceService.allExperiences)
    }

    private var isCreating: Binding<Bool> {
        Binding(
            get: { model.step == .creating },
            set: { $0 ? model.beginCreation() : model.cancelCreation() }
        )
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack() {
            Group {
                if model.itineraries.isEmpty {
                    emptyState
                } else {
                    itineraryList
                }
            }
            .navigationTitle(NSLocalizedString("itinerary.addTo.title", comment: "Add to Itinerary sheet title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("common.cancel", comment: "Cancel")) { dismiss() }
                }
            }
            .navigationDestination(isPresented: isCreating) {
                ItineraryFormView(
                    store: store,
                    sourceCityCode: sourceCityCode,
                    pinnedExperienceIds: experienceIds,
                    embedInNavigationStack: false,
                    onSaved: { created in handleCreated(created) },
                    onCancel: { model.cancelCreation() }
                )
            }
        }
        .presentationDetents([.large])
        .presentationBackground(CT.cardAdaptive)
        .presentationDragIndicator(.visible)
        // While the form is on screen, leave via its explicit Cancel/back so a
        // stray drag can't silently discard an in-progress itinerary.
        .interactiveDismissDisabled(model.step == .creating)
        .onAppear { model.reload() }
        .alert(
            NSLocalizedString("itinerary.addTo.error.title", comment: "Error alert title when pinning fails"),
            isPresented: Binding(
                get: { saveErrorMessage != nil || model.errorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil; model.clearError() } }
            )
        ) {
            Button(NSLocalizedString("itinerary.addTo.error.retry", comment: "Retry pinning after a failure")) {
                let message = saveErrorMessage ?? model.errorMessage
                saveErrorMessage = nil
                model.clearError()
                if message != nil, let target = model.itineraries.first(where: { $0.id == lastAttemptedItineraryId }) {
                    addExisting(target)
                }
            }
            Button(NSLocalizedString("common.ok", comment: "OK"), role: .cancel) {
                saveErrorMessage = nil
                model.clearError()
            }
        } message: {
            Text(saveErrorMessage ?? model.errorMessage ?? "")
        }
    }

    // MARK: - List

    private var itineraryList: some View {
        List {
            Section {
                ForEach(model.itineraries) { itin in
                    itineraryRow(itin)
                }
            }
            Section {
                createNewRow
            }
        }
        .listStyle(.insetGrouped)
    }

    private func itineraryRow(_ itin: Itinerary) -> some View {
        let alreadyAdded = experienceIds.allSatisfy { itin.experienceIds.contains($0) }
        let wasJustAdded = (justAddedId ?? model.addedToId) == itin.id

        return Button {
            guard !alreadyAdded, !isSaving else { return }
            addExisting(itin)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(CT.accent.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: alreadyAdded ? "checkmark" : "plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(alreadyAdded ? CT.verifiedGreen : CT.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(itin.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(itin.cityCode)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSaving && !alreadyAdded {
                    ProgressView()
                } else if wasJustAdded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(CT.verifiedGreen)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(minHeight: HitTargetMetrics.minimum)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(alreadyAdded || isSaving)
        .accessibilityLabel(Text(alreadyAdded
            ? String(format: NSLocalizedString("itinerary.addTo.alreadyAdded", comment: "Already in itinerary"), itin.title)
            : String(format: NSLocalizedString("itinerary.addTo.addToNamed", comment: "Add to itinerary name"), itin.title)
        ))
    }

    private var createNewRow: some View {
        Button {
            model.beginCreation()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: "plus.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(NSLocalizedString("itinerary.addTo.createNew", comment: "Create new itinerary option"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "map")
                .font(.system(size: 40))
                .foregroundStyle(CT.accent.opacity(0.6))
            Text(NSLocalizedString("itinerary.addTo.noItineraries", comment: "No itineraries empty state"))
                .font(.headline)
            Text(NSLocalizedString("itinerary.addTo.noItineraries.hint", comment: "Create one hint"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                model.beginCreation()
            } label: {
                Text(NSLocalizedString("itinerary.addTo.createFirst", comment: "Create first itinerary CTA"))
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(CT.accent))
                    .foregroundStyle(.white)
            }
        }
        .padding(32)
    }

    // MARK: - Actions

    /// Invoked by the form only after it persisted the itinerary. The callback
    /// receives that exact itinerary — no `loadAll().first` resolution.
    private func handleCreated(_ created: Itinerary) {
        let surfaced = model.creationSucceeded(created)
        Haptics.notify(.success)
        onSuccess?(surfaced)
        dismiss()
    }

    private func addExisting(_ itinerary: Itinerary) {
        // One durable write for every stop; on failure the sheet stays open,
        // the selection survives, and the error offers a retry (R2-01).
        isSaving = true
        defer { isSaving = false }
        lastAttemptedItineraryId = itinerary.id
        do {
            guard let updated = try store.addExperiences(experienceIds, to: itinerary.id) else {
                return
            }
            justAddedId = updated.id
            model.reload()
            Haptics.notify(.success)
            onSuccess?(updated)
            dismiss()
        } catch {
            saveErrorMessage = NSLocalizedString(
                "itinerary.addTo.error.message",
                comment: "Recoverable message shown when adding an experience fails"
            )
        }
    }
}

// MARK: - Preview

#Preview {
    let container = SoloCompassModelContainer.makeInMemory()
    let store = ItineraryStore(context: ModelContext(container))
    try? store.save(.sample)
    return AddToItinerarySheet(
        experienceId: "exp_preview",
        experienceTitle: "Doi Suthep Temple",
        store: store
    )
    .environment(ExperienceService(seed: ExperienceService.hardcodedSeed))
}
