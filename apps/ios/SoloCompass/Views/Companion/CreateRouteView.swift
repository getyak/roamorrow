import SwiftUI
import CoreLocation

// MARK: - CreateRouteEntryCard

/// Dashed entry card shown beneath the routes section in the bottom sheet:
/// "創建你自己的路線 · 串聯幾個地點 · 可選擇招募同伴一起走". Tapping it opens
/// `CreateRouteView`. Mirrors the reference design's create-route affordance.
struct CreateRouteEntryCard: View {
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var cardBg: Color { colorScheme == .dark ? CT.warmCardDark : CT.surfaceWhite }
    private var titleColor: Color { colorScheme == .dark ? CT.fgPrimaryDark : CT.fgPrimary }
    private var subtitleColor: Color { colorScheme == .dark ? CT.fgMutedDark : CT.fgMuted }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(CT.accent)
                        .frame(width: 44, height: 44)
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(NSLocalizedString("route.create.entry.title", comment: "Create your own route"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(titleColor)
                    Text(NSLocalizedString("route.create.entry.subtitle", comment: "Link a few stops · optionally recruit companions"))
                        .font(.caption)
                        .foregroundStyle(subtitleColor)
                        .lineLimit(2)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(subtitleColor)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(cardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        CT.borderDefault,
                        style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                    )
            )
        }
        // PressableButtonStyle drives the press-scale via the system's own tap
        // recognizer. The previous `.simultaneousGesture(DragGesture(minimumDistance: 0))`
        // press-feedback hack swallowed the tap inside the BottomInfoSheet's
        // ScrollView — a zero-distance drag claims the touch and the host scroll
        // view classifies the release as a drag, so the Button action never fired
        // and the card was un-tappable. See [[project_dead_fab_sheet_wiring]] kin.
        .buttonStyle(PressableButtonStyle(pressedScale: 0.985))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(NSLocalizedString("route.create.entry.title", comment: "Create your own route")))
        .accessibilityHint(Text(NSLocalizedString("route.create.entry.subtitle", comment: "Create route hint")))
    }
}

// MARK: - CreateRouteView

/// Build a route by selecting a few nearby experiences — either by hand or by
/// letting the AI string them into a walk — then save it as a `userCreated`
/// (or `coCreated` when AI-seeded) route. Companion recruiting is offered as a
/// follow-up from the saved route's detail, so this flow stays focused on the
/// walk itself.
struct CreateRouteView: View {
    /// Nearby experiences the user can pick stops from.
    let candidates: [Experience]
    let cityCode: String
    let userCoordinate: CLLocationCoordinate2D?
    /// When true, the AI generation starts as soon as the sheet appears —
    /// used by entries whose copy promises Solo picks the stops (the Now
    /// section's "让 Solo 为你拼一条" placeholder). Manual entries pass false.
    var autoGenerate: Bool = false
    /// When true the sheet dismisses itself after a successful save (list
    /// hosts like DiscoverRecruitingRoutesView). The map host passes false —
    /// it swaps this sheet's content to the saved route's detail in place.
    var dismissOnSave: Bool = false
    /// Persists the saved route. Throwing so a failed write can keep the
    /// draft on screen with a retry instead of a silent loss (R2-07).
    let onSave: (Route) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AIService.self) private var aiService

    @State private var selectedIds: [String] = []
    @State private var title: String = ""
    @State private var pace: Pace = .relaxed
    @State private var isGenerating = false
    @State private var aiSummary: String?
    /// Where the current suggestion's copy came from (model vs local).
    @State private var routeProvenance: AIService.RouteProvenance?
    /// Non-nil after a failed AI generation. The old `try?`-and-return made
    /// the ✨ button a silent no-op on any error (missing key, network, quota)
    /// — the user tapped, nothing loaded, nothing explained itself.
    @State private var generateErrorText: String?
    /// Non-nil after a failed SAVE — the draft stays on screen for a retry.
    @State private var saveErrorText: String?
    /// A generation result that arrived after the user edited the draft. Kept
    /// for EXPLICIT adoption — never written over the user's picks silently
    /// (R2-07).
    @State private var pendingSuggestion: AIService.GeneratedRoute?
    /// Owns the generation task + stale-result guard (single owner, cancel on
    /// re-generate / save / disappear).
    @State private var generationGuard = RouteGenerationGuard()
    @State private var generationTask: Task<Void, Never>?

    /// Selected experiences in selection order (the walk order).
    private var orderedSelection: [Experience] {
        selectedIds.compactMap { id in candidates.first { $0.id == id } }
    }

    private var canSave: Bool { selectedIds.count >= 2 && !isGenerating }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    aiGenerateButton
                    generateErrorBanner
                    saveErrorBanner
                    staleSuggestionBanner
                    summaryHeader
                    titleField
                    pacePicker
                    pickerSection
                }
                .padding(16)
            }
            .background(CT.bgWarm)
            .navigationTitle(NSLocalizedString("route.create.title", comment: "Create route nav title"))
            .navigationBarTitleDisplayMode(.inline)
            // Honour the "Solo picks the stops" promise: kick the generation
            // off on open. `.task` runs once per appearance; the guard keeps
            // it from clobbering a session where the user already picked.
            .task {
                guard autoGenerate, selectedIds.isEmpty, candidates.count >= 2 else { return }
                startGeneration()
            }
            .onChange(of: title) { _, _ in generationGuard.noteUserEdit() }
            .onChange(of: pace) { _, _ in generationGuard.noteUserEdit() }
            .onDisappear {
                // Owned lifetime: a disappearing sheet must not keep a
                // generation alive whose result could apply later (R2-07).
                generationTask?.cancel()
                generationTask = nil
                generationGuard.cancelAttempt()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("action.cancel", comment: "Cancel")) {
                        generationTask?.cancel()
                        generationGuard.cancelAttempt()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("route.create.save", comment: "Save route")) { save() }
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
        }
        // Once stops are picked or a title is typed, block swipe-to-dismiss so a
        // stray gesture can't discard the walk-in-progress; Cancel is the exit.
        .interactiveDismissDisabled(!selectedIds.isEmpty || !title.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    // MARK: - Sections

    private var aiGenerateButton: some View {
        Button { startGeneration() } label: {
            HStack(spacing: 8) {
                if isGenerating {
                    ProgressView().tint(CT.accent)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(NSLocalizedString("route.create.ai", comment: "Let AI build the route"))
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(CT.sunGoldDeep)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(CT.sunGoldSoft)
            )
        }
        .buttonStyle(.plain)
        .disabled(isGenerating || candidates.count < 2)
        // `.disabled` alone doesn't dim a plain-style button with explicit
        // foreground/background colors — it looked fully tappable while
        // candidates were empty, reading as a dead button. Make the disabled
        // state visible.
        .opacity(candidates.count < 2 ? 0.4 : 1)
    }

    /// Error surface for a failed AI generation (replaces the silent no-op).
    @ViewBuilder
    private var generateErrorBanner: some View {
        if let generateErrorText {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text(generateErrorText)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(CT.fgMuted)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(CT.surfaceWhite))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(CT.borderSubtle, lineWidth: 0.5))
        }
    }

    /// A save failure keeps the whole draft on screen and offers a retry —
    /// nothing is cleared and nothing is claimed saved (R2-07).
    @ViewBuilder
    private var saveErrorBanner: some View {
        if let saveErrorText {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text(saveErrorText)
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(CT.sunGoldDeep)
                Button(NSLocalizedString("route.create.save.retry", comment: "Retry saving the route")) {
                    self.saveErrorText = nil
                    save()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(CT.accent)
                .frame(minHeight: HitTargetMetrics.minimum)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(CT.sunGoldSoft))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(CT.accentBorder, lineWidth: 0.5))
        }
    }

    /// Stale generation result awaiting EXPLICIT adoption (R2-07). The user
    /// edited the draft while the suggestion was generating, so applying it is
    /// their decision, not a silent overwrite.
    @ViewBuilder
    private var staleSuggestionBanner: some View {
        if pendingSuggestion != nil {
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString(
                    "route.create.suggestion.stale.title",
                    comment: "A generated suggestion arrived after your edits"
                ))
                .font(.caption.weight(.semibold))
                .foregroundStyle(CT.fgPrimary)
                .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    Button(NSLocalizedString(
                        "route.create.suggestion.adopt",
                        comment: "Use the generated suggestion anyway"
                    )) {
                        if let pendingSuggestion { apply(pendingSuggestion) }
                        pendingSuggestion = nil
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(minHeight: HitTargetMetrics.minimum)
                    .background(Capsule().fill(CT.accent))
                    Button(NSLocalizedString(
                        "route.create.suggestion.keep",
                        comment: "Keep my own edits and drop the suggestion"
                    )) {
                        pendingSuggestion = nil
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CT.fgMuted)
                    .frame(minHeight: HitTargetMetrics.minimum)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(CT.surfaceWhite))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(CT.accentBorder, lineWidth: 0.5))
        }
    }

    /// Provenance-honest summary line (R2-11): model copy reads as AI copy;
    /// the local fallback reads as a local plan with a deliberate retry —
    /// never as "the model finished this".
    @ViewBuilder
    private var summaryHeader: some View {
        if let aiSummary, !aiSummary.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: routeProvenance == .model ? "sparkles" : "map")
                        .font(.system(size: 11, weight: .semibold))
                    Text(aiSummary).font(.caption).fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(CT.sunGoldDeep)

                if routeProvenance == .localFallback {
                    Text(NSLocalizedString(
                        "route.create.localFallback",
                        comment: "Honest label: this suggestion was planned locally, not by the AI"
                    ))
                    .font(.caption2)
                    .foregroundStyle(CT.fgMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    Button(NSLocalizedString("route.create.ai.retry", comment: "Retry AI generation")) {
                        startGeneration()
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(CT.accent)
                    .frame(minHeight: HitTargetMetrics.minimum)
                } else {
                    Text(NSLocalizedString(
                        "route.create.modelCopy",
                        comment: "Honest label: title/summary drafted by AI, stops chosen locally"
                    ))
                    .font(.caption2)
                    .foregroundStyle(CT.fgMuted)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(CT.sunGoldSoft))
        }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(NSLocalizedString("route.create.titleLabel", comment: "Route title field label"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(CT.fgMuted)
            TextField(
                NSLocalizedString("route.create.titlePlaceholder", comment: "Route title placeholder"),
                text: $title
            )
            .textFieldStyle(.plain)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(CT.surfaceWhite))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(CT.borderSubtle, lineWidth: 0.5))
        }
    }

    private var pacePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(NSLocalizedString("route.create.paceLabel", comment: "Pace field label"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(CT.fgMuted)
            Picker("", selection: $pace) {
                ForEach(Pace.allCases, id: \.self) { p in
                    Text(p.localizedLabel).tag(p)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var pickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(NSLocalizedString("route.create.pickLabel", comment: "Pick stops label"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CT.fgMuted)
                Spacer()
                Text(String(
                    format: NSLocalizedString("route.create.selectedCount", comment: "N selected"),
                    selectedIds.count
                ))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(CT.fgSubtle)
            }
            if candidates.isEmpty {
                // Dead-end guard: with zero candidates both paths (manual pick
                // + AI generate) are unusable — say so instead of rendering a
                // blank section under an inert button.
                Text(NSLocalizedString(
                    "route.create.empty",
                    comment: "Shown when no nearby experiences are available to build a route from"
                ))
                .font(.caption)
                .foregroundStyle(CT.fgMuted)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(candidates) { exp in
                    selectRow(exp)
                }
            }
        }
    }

    private func selectRow(_ exp: Experience) -> some View {
        let order = selectedIds.firstIndex(of: exp.id)
        let isSelected = order != nil
        return Button { toggle(exp.id) } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(exp.category.color).frame(width: 34, height: 34)
                    if let order {
                        Text("\(order + 1)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: exp.category.symbol)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(exp.title).font(.subheadline.weight(.medium))
                        .foregroundStyle(CT.fgPrimary).lineLimit(1)
                    Text(String(format: NSLocalizedString("nearby.chip.solo", comment: "Solo score"), exp.soloScore.overall))
                        .font(.caption2.weight(.semibold)).foregroundStyle(CT.verifiedGreen)
                }
                Spacer(minLength: 4)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? CT.accent : CT.fgSubtle)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? CT.accentSoft : CT.surfaceWhite)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? CT.accentBorder : CT.borderSubtle, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(exp.title))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    // MARK: - Actions

    private func toggle(_ id: String) {
        #if canImport(UIKit)
        Haptics.selection()
        #endif
        generationGuard.noteUserEdit()
        if let idx = selectedIds.firstIndex(of: id) {
            selectedIds.remove(at: idx)
        } else {
            selectedIds.append(id)
        }
    }

    /// Start (or re-start) the generation under the guard's ownership. Any
    /// in-flight attempt is cancelled first — one task, one owner (R2-07).
    private func startGeneration() {
        generationTask?.cancel()
        generationGuard.cancelAttempt()
        pendingSuggestion = nil
        generateErrorText = nil
        saveErrorText = nil
        let attempt = generationGuard.beginAttempt()
        isGenerating = true
        generationTask = Task { @MainActor in
            // Attempt-owned cleanup (review closure 1): only the CURRENT
            // attempt may touch shared generation state. A superseded or
            // canceled request that exits late must not clear the NEW
            // attempt's isGenerating/generationTask — only its own.
            defer {
                if generationGuard.isCurrent(attempt: attempt.attempt) {
                    isGenerating = false
                    generationTask = nil
                }
            }
            do {
                let result = try await aiService.generateRouteDetailed(
                    from: candidates,
                    cityCode: cityCode,
                    userCoordinate: userCoordinate
                )
                // Attempt IDENTITY is checked separately from draftVersion
                // (review closure 1):
                //   - a superseded/canceled attempt writes NOTHING back
                //     (no apply, no stale pendingSuggestion, no error banner);
                //   - the CURRENT attempt whose draft moved on offers the
                //     result for explicit adoption.
                guard generationGuard.isCurrent(attempt: attempt.attempt), !Task.isCancelled else { return }
                if generationGuard.draftVersion == attempt.versionAtStart {
                    apply(result)
                } else {
                    pendingSuggestion = result
                }
            } catch {
                guard generationGuard.isCurrent(attempt: attempt.attempt), !Task.isCancelled else { return }
                generateErrorText = NSLocalizedString(
                    "route.create.ai.error",
                    comment: "Shown when AI route generation fails"
                )
            }
        }
    }

    /// Adopt a generation result as the editable starting point, recording its
    /// provenance so save() can label the route honestly (R2-11).
    private func apply(_ result: AIService.GeneratedRoute) {
        selectedIds = result.route.experienceIds
        if title.isEmpty { title = result.route.title }
        aiSummary = result.route.summary
        routeProvenance = result.provenance
        pace = result.route.pace
    }

    private func save() {
        // A save must never race an in-flight generation (R2-07): cancel it
        // and keep the draft intact if persistence fails.
        generationTask?.cancel()
        generationTask = nil
        generationGuard.cancelAttempt()
        isGenerating = false
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = trimmed.isEmpty
            ? NSLocalizedString("route.generate.fallback.title", comment: "Default route title")
            : trimmed
        let route = RouteBuilder.makeRoute(
            id: RouteId(rawValue: "user-\(UUID().uuidString.prefix(8))"),
            title: finalTitle,
            summary: aiSummary ?? "",
            orderedExperiences: orderedSelection,
            cityCode: cityCode,
            pace: pace,
            source: routeProvenance == .model ? .coCreated : .userCreated,
            // A hand-built route is for *today*: anchor it to the current hour
            // so the Now shelf's `isBestNow()` filter shows it immediately
            // instead of silently hiding the route the user just made.
            bestStartHour: Double(Calendar.current.component(.hour, from: Date()))
        )
        do {
            try onSave(route)
        } catch {
            // Honest failure (R2-07): nothing saved, the draft (stops, title,
            // pace and the adopted suggestion) stays exactly as edited.
            saveErrorText = NSLocalizedString(
                "route.create.save.error",
                comment: "Shown when persisting the created route fails"
            )
            return
        }
        saveErrorText = nil
        if dismissOnSave {
            dismiss()
        }
        // No dismiss() when hosted by the map: it swaps this sheet's content
        // from .create to .detail in place, and dismissing would tear that
        // detail view down before the user ever sees the saved route.
    }
}
