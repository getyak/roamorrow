import CoreLocation
import PhotosUI
import SwiftUI

/// Form to register a new place at a long-pressed map coordinate.
///
/// This is the primary "add a place" path (the voice flow remains as a
/// secondary entry point). The user supplies only honest, mechanical facts:
/// name, category, a short description, and photos. Trust-critical fields
/// (Solo Score, confidence) are NOT user-settable — `Experience.userDraft`
/// fills them with safe, unverified defaults.
public struct CreateExperienceSheet: View {
    /// The map coordinate the user long-pressed. Photos and form text are
    /// gathered here; the coordinate is fixed.
    let coordinate: CLLocationCoordinate2D

    /// Called with the assembled fields when the user taps Save. Photo URLs are
    /// already-persisted `file://` strings.
    var onSave: (_ input: NewPlaceFormInput) -> Void

    /// Called when the user wants the secondary voice path instead of the form.
    var onUseVoice: () -> Void

    var onCancel: () -> Void

    @State private var placeName: String = ""
    @State private var placeNameLocal: String = ""
    @State private var oneLiner: String = ""
    @State private var description: String = ""
    @State private var category: ExperienceCategory = .hidden

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var images: [UIImage] = []
    @State private var isShowingCamera = false
    @State private var photoLoadingTask: Task<Void, Never>?
    @State private var photoLoadGeneration = UUID()
    @State private var isLoadingPhotos = false
    @State private var photoLoadFailureCount = 0

    // Photo-write recovery (R2-10 + review closure 5): a failed write retains
    // the form and the raw images, names the failure, and offers retry or an
    // EXPLICIT omit. Never a silent `compactMap` loss. Batch identity is
    // stable per draft image (no duplicate output files on retry), photo
    // editing is locked while a failed batch is pending, and the omit path
    // only runs against an UNCHANGED batch — never removed/new photos.
    @State private var photoSaveFailureCount = 0
    @State private var lastFailedIndices: [Int] = []
    /// Stable per-image ids + attempt receipt (pure logic, unit-tested).
    @State private var draftBatch = PlacePhotoDraftBatch()
    /// Exact file URLs THIS draft wrote (across attempts) — the only files
    /// cleanup may ever touch.
    @State private var writtenFileUrls: Set<String> = []

    @Environment(\.dismiss) private var dismiss

    public init(
        coordinate: CLLocationCoordinate2D,
        onSave: @escaping (_ input: NewPlaceFormInput) -> Void,
        onUseVoice: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.coordinate = coordinate
        self.onSave = onSave
        self.onUseVoice = onUseVoice
        self.onCancel = onCancel
    }

    /// Save is meaningful only when there's at least a place name.
    private var canSave: Bool {
        !placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isLoadingPhotos && photoLoadFailureCount == 0
    }

    /// Any field touched or photo added → protect against an accidental
    /// swipe-to-dismiss discarding the draft (HIG: guard unsaved edits).
    private var isDirty: Bool {
        !placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !placeNameLocal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !oneLiner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !images.isEmpty
    }

    public var body: some View {
        NavigationStack {
            Form {
                nameSection
                categorySection
                descriptionSection
                photosSection
                photoSaveErrorSection
                photoLoadingSection
                voiceSection
            }
            .navigationTitle(NSLocalizedString("userLocation.create.title", comment: "Add a place"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common.cancel", comment: "Cancel")) {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("userLocation.form.save", comment: "Save")) {
                        submit()
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $isShowingCamera) {
                CameraPicker { captured in
                    if let captured {
                        images.append(captured)
                        draftBatch.appendImage()
                        invalidatePendingReceipt()
                    }
                }
                .ignoresSafeArea()
            }
            .onChange(of: pickerItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                photoLoadingTask?.cancel()
                let generation = UUID()
                photoLoadGeneration = generation
                isLoadingPhotos = true
                photoLoadFailureCount = 0
                photoLoadingTask = Task { await loadPickedImages(newItems, generation: generation) }
            }
        }
        .interactiveDismissDisabled(isDirty || isLoadingPhotos)
        .onDisappear {
            photoLoadGeneration = UUID()
            photoLoadingTask?.cancel()
            photoLoadingTask = nil
            isLoadingPhotos = false
        }
    }

    // MARK: - Sections

    private var nameSection: some View {
        Section {
            labeledField(
                label: NSLocalizedString("userLocation.form.name.fieldLabel", comment: "Required place name field label"),
                placeholder: NSLocalizedString("userLocation.form.name.placeholder", comment: "Place name example prompt"),
                text: $placeName
            )
            labeledField(
                label: NSLocalizedString("userLocation.form.nameLocal.fieldLabel", comment: "Optional local-language name field label"),
                placeholder: NSLocalizedString("userLocation.form.nameLocal.placeholder", comment: "Local-language name example prompt"),
                text: $placeNameLocal
            )
            labeledField(
                label: NSLocalizedString("userLocation.form.oneLiner.fieldLabel", comment: "Optional one-line experience field label"),
                placeholder: NSLocalizedString("userLocation.form.oneLiner.placeholder", comment: "One-line experience example prompt"),
                text: $oneLiner
            )
        } header: {
            Text(NSLocalizedString("userLocation.form.name.label", comment: "Place name section header"))
        }
    }

    /// One field row with a persistent visible label above the input. The
    /// label — not the placeholder — is the field's identity: it stays on
    /// screen after the user types, so the first field is still identifiable
    /// once filled, and the placeholder can stay a plain example/prompt.
    /// Label and field stack vertically, so the row keeps its hierarchy at
    /// every Dynamic Type size instead of shrinking type to fit one line.
    private func labeledField(
        label: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
            TextField(placeholder, text: text)
                .accessibilityLabel(Text(label))
        }
        .padding(.vertical, 2)
    }

    private var categorySection: some View {
        Section {
            Picker(
                NSLocalizedString("userLocation.form.category.label", comment: "Category"),
                selection: $category
            ) {
                ForEach(ExperienceCategory.allCases) { cat in
                    Label(cat.localizedTitle, systemImage: cat.symbol).tag(cat)
                }
            }
        }
    }

    private var descriptionSection: some View {
        Section {
            TextField(
                NSLocalizedString("userLocation.form.notes.placeholder", comment: "Notes placeholder"),
                text: $description,
                axis: .vertical
            )
            .lineLimit(3...6)
        } header: {
            Text(NSLocalizedString("userLocation.form.notes.label", comment: "Notes section header"))
        }
    }

    private var photosSection: some View {
        Section {
            if !images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(images.enumerated()), id: \.offset) { idx, img in
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 72, height: 72)
                                .clipShape(Radius.shape(Radius.sm))
                                .overlay(alignment: .bottomLeading) {
                                    // Name WHICH photo failed to write (R2-10).
                                    if lastFailedIndices.contains(idx) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.white, CT.sunGoldDeep)
                                            .padding(3)
                                    }
                                }
                                .overlay(alignment: .topTrailing) {
                                    // 44pt hit target with a small visible glyph,
                                    // and a contextual label so VoiceOver knows
                                    // WHICH photo the button removes.
                                    Button {
                                        images.remove(at: idx)
                                        draftBatch.removeImage(at: idx)
                                        invalidatePendingReceipt()
                                    } label: {
                                        Color.clear
                                            .frame(width: HitTargetMetrics.minimum, height: HitTargetMetrics.minimum)
                                            .overlay(alignment: .topTrailing) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 18, weight: .semibold))
                                                    .foregroundStyle(.white, .black.opacity(0.55))
                                                    .padding(4)
                                            }
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    // Photo editing is locked while a failed
                                    // batch is pending (review closure 5) —
                                    // the omit receipt must match the images.
                                    .disabled(photoSaveFailureCount > 0 || isLoadingPhotos)
                                    .accessibilityLabel(Text(String(
                                        format: NSLocalizedString(
                                            "userLocation.form.photo.remove.a11y",
                                            comment: "Remove photo %1$d of %2$d"
                                        ),
                                        idx + 1,
                                        images.count
                                    )))
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            PhotosPicker(
                selection: $pickerItems,
                maxSelectionCount: 5,
                matching: .images
            ) {
                Label(
                    NSLocalizedString("userLocation.form.photo.library", comment: "Choose from library"),
                    systemImage: "photo.on.rectangle"
                )
            }
            .disabled(photoSaveFailureCount > 0 || isLoadingPhotos)
            Button {
                isShowingCamera = true
            } label: {
                Label(
                    NSLocalizedString("userLocation.form.photo.camera", comment: "Take a photo"),
                    systemImage: "camera"
                )
            }
            .disabled(photoSaveFailureCount > 0 || isLoadingPhotos)
        } header: {
            Text(NSLocalizedString("userLocation.form.photo.label", comment: "Photos section header"))
        }
    }

    /// Honest photo-write failure surface (R2-10 + review closure 5): says
    /// how many writes failed, keeps every raw image + form field, and offers
    /// retry, an explicit "save without these photos", or return-to-edit.
    @ViewBuilder
    private var photoSaveErrorSection: some View {
        if photoSaveFailureCount > 0 {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        String(format: NSLocalizedString(
                            "userLocation.form.photo.save.error",
                            comment: "Photo write failure count (%d photos)"
                        ), photoSaveFailureCount),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.subheadline)
                    .foregroundStyle(CT.sunGoldDeep)
                    Text(NSLocalizedString(
                        "userLocation.form.photo.save.error.hint",
                        comment: "Failed photos stay in the form; retry or omit them"
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 16) {
                        Button(NSLocalizedString(
                            "userLocation.form.photo.save.retry",
                            comment: "Retry saving the photos"
                        )) {
                            photoSaveFailureCount = 0
                            submit()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CT.accent)
                        .frame(minHeight: HitTargetMetrics.minimum)
                        Button(NSLocalizedString(
                            "userLocation.form.photo.save.omit",
                            comment: "Save without the photos that failed to write"
                        )) {
                            submitOmittingFailedPhotos()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CT.sunGoldDeep)
                        .frame(minHeight: HitTargetMetrics.minimum)
                    }
                    // Explicit return-to-edit (review closure 5): drops the
                    // pending receipt and unlocks photo editing again.
                    Button(NSLocalizedString(
                        "userLocation.form.photo.save.editAgain",
                        comment: "Return to editing the photos; the pending save receipt is dropped"
                    )) {
                        returnToPhotoEditing()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CT.accent)
                    .frame(minHeight: HitTargetMetrics.minimum)
                }
            }
        }
    }

    private var voiceSection: some View {
        Section {
            Button {
                onUseVoice()
                dismiss()
            } label: {
                Label(
                    NSLocalizedString("userLocation.form.useVoice", comment: "Describe with voice instead"),
                    systemImage: "mic"
                )
            }
        } footer: {
            Text(NSLocalizedString("userLocation.form.unverifiedNote", comment: "Unverified note"))
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var photoLoadingSection: some View {
        if isLoadingPhotos {
            Section {
                ProgressView(NSLocalizedString("userLocation.form.photo.loading", comment: "Loading selected photos"))
            }
        } else if photoLoadFailureCount > 0 {
            Section {
                Text(String(format: NSLocalizedString("userLocation.form.photo.loadFailed", comment: "Unreadable photo count"), photoLoadFailureCount))
                    .foregroundStyle(.secondary)
                Button(NSLocalizedString("userLocation.form.photo.skipUnreadable", comment: "Explicitly omit unreadable photos")) {
                    photoLoadFailureCount = 0
                }
                .frame(minHeight: HitTargetMetrics.minimum)
            }
        }
    }

    private func loadPickedImages(_ items: [PhotosPickerItem], generation: UUID) async {
        var loaded: [UIImage] = []
        var failed = 0
        for item in items {
            guard !Task.isCancelled, photoLoadGeneration == generation else { return }
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                loaded.append(img)
            } else {
                failed += 1
            }
        }
        guard !Task.isCancelled, photoLoadGeneration == generation else { return }
        images.append(contentsOf: loaded)
        for _ in loaded { draftBatch.appendImage() }
        invalidatePendingReceipt()
        photoLoadFailureCount = failed
        isLoadingPhotos = false
        pickerItems = []
        photoLoadingTask = nil
    }

    /// Any photo edit invalidates the pending attempt receipt (review closure
    /// 5) — its URLs may reference removed images or miss new ones.
    private func invalidatePendingReceipt() {
        draftBatch.clearAttempt()
        photoSaveFailureCount = 0
        lastFailedIndices = []
    }

    /// The explicit return-to-edit action: drop the receipt and unlock photo
    /// editing (review closure 5).
    private func returnToPhotoEditing() {
        draftBatch.clearAttempt()
        photoSaveFailureCount = 0
        lastFailedIndices = []
    }

    private func submit() {
        guard canSave else { return }
        // Persist images to disk with a result per photo (R2-10). STABLE ids
        // per draft image (review closure 5): a retry overwrites the same
        // output files instead of writing new UUID files every attempt.
        let results = PlacePhotoStore.saveAll(images, uuids: draftBatch.imageIds)
        var urls: [String] = []
        var failed: [Int] = []
        for result in results {
            switch result {
            case .saved(let url):
                urls.append(url)
                writtenFileUrls.insert(url)
            case .failed(let index, _):
                failed.append(index)
            }
        }
        draftBatch.recordAttempt(savedUrls: urls, failedIndices: failed)
        guard failed.isEmpty else {
            // Keep the form and EVERY raw image; explain and offer retry or an
            // explicit omit. Nothing is saved, nothing is dismissed. Photo
            // editing is locked until the batch is resolved.
            lastFailedIndices = failed
            photoSaveFailureCount = failed.count
            return
        }
        finishSubmit(photoUrls: urls)
    }

    /// The traveler explicitly chose to save without the photos whose writes
    /// failed — the only path that may drop them (R2-10). Valid only for an
    /// UNCHANGED batch (review closure 5): never a removed image, never a
    /// silently omitted new one.
    private func submitOmittingFailedPhotos() {
        guard let omitUrls = draftBatch.omitCandidateUrls else {
            // Stale receipt — return to editing instead of guessing.
            returnToPhotoEditing()
            return
        }
        photoSaveFailureCount = 0
        finishSubmit(photoUrls: omitUrls)
    }

    private func finishSubmit(photoUrls: [String]) {
        // Cleanup is strictly limited to files THIS draft wrote and the final
        // submission doesn't reference (review closure 5). Old user photos are
        // never touched — removeDraftFile refuses foreign paths.
        let keep = Set(photoUrls)
        for url in writtenFileUrls where !keep.contains(url) {
            PlacePhotoStore.removeDraftFile(url)
        }
        let trimmedName = placeName.trimmingCharacters(in: .whitespacesAndNewlines)
        let input = NewPlaceFormInput(
            coordinate: coordinate,
            placeNameRomanized: trimmedName,
            placeNameLocal: placeNameLocal.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            // Title falls back to the place name when the user gives no one-liner action.
            title: oneLiner.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? trimmedName,
            oneLiner: oneLiner.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            photoUrls: photoUrls.isEmpty ? nil : photoUrls
        )
        onSave(input)
        dismiss()
    }
}

/// The fields the create-place form hands back. Coordinate is fixed from the
/// long-press; everything else is user-entered. Photo URLs are persisted
/// `file://` strings ready for `ExperienceLocation.photoUrls`.
public struct NewPlaceFormInput {
    public let coordinate: CLLocationCoordinate2D
    public let placeNameRomanized: String
    public let placeNameLocal: String?
    public let title: String
    public let oneLiner: String
    public let description: String
    public let category: ExperienceCategory
    public let photoUrls: [String]?
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

// MARK: - Camera picker (UIKit bridge)

/// Minimal `UIImagePickerController` wrapper for taking a photo. SwiftUI has no
/// native camera capture view, so we bridge UIKit. Library picking uses the
/// native `PhotosPicker` in the form above.
struct CameraPicker: UIViewControllerRepresentable {
    var onCapture: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage?) -> Void
        init(onCapture: @escaping (UIImage?) -> Void) { self.onCapture = onCapture }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            onCapture(info[.originalImage] as? UIImage)
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCapture(nil)
            picker.dismiss(animated: true)
        }
    }
}

#Preview {
    CreateExperienceSheet(
        coordinate: CLLocationCoordinate2D(latitude: 18.7877, longitude: 98.9938),
        onSave: { _ in },
        onUseVoice: {},
        onCancel: {}
    )
}
