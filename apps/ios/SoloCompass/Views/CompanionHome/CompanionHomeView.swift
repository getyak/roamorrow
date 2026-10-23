import SwiftUI

/// One conversation, with the map beside it. Neither surface owns the session.
@MainActor
struct CompanionHomeView: View {
    @Environment(AIService.self) private var aiService
    @Environment(ExperienceService.self) private var experiences
    @Environment(UserPreferences.self) private var preferences
    @Environment(LiveActivityService.self) private var liveActivities
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var store = CompanionHomeStore()
    @State private var surface: Surface = .now
    @State private var sheet: CompanionHomePresentation?
    @State private var didConfigure = false
    @State private var toolRouter: VoiceAgentToolRouter?
    @State private var composerID = UUID()
    @State private var mediaAudio = CompanionAudioSession()
    @State private var recordAfterDismiss = false
    @State private var routeSession = CompanionRouteSession()
    @Environment(\.scenePhase) private var scenePhase

    private enum Surface: String, CaseIterable { case now, nearby }
    var body: some View {
        @Bindable var store = store
        ZStack {
            CompanionHomeStyle.paper.ignoresSafeArea()
            // A stable view identity keeps the map's camera, filters and results.
            CompanionNearbyView(sheet: $sheet, store: store, routeSession: routeSession,
                isActive: surface == .nearby, onModelReady: configureTools,
                onConversation: { surface = .now })
                .allowsHitTesting(surface == .nearby)
                .accessibilityHidden(surface != .nearby)
            VStack(spacing: 0) {
                header
                CompanionConversation(store: store, isActive: surface == .now, onSources: { sheet = .sources($0) },
                    onPlace: showPlace, onCommitments: { sheet = .journey },
                    onMedia: openMedia)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(surface == .now)
                    .accessibilityHidden(surface != .now)
                if surface == .now {
                    CompanionComposer(text: $store.composerDraft, isWorking: store.isWorking, isActive: sheet == nil,
                        onSend: { Task { await store.send() } }, onCancel: { store.cancel() }, store: store,
                        onAddMedia: { sheet = .addMedia }, onOpenMedia: openMedia)
                        .id(composerID) // Clearing invalidates pending capture/OCR callbacks.
                        .background(CompanionHomeStyle.paper)
                }
            }
        }
        .tint(CompanionHomeStyle.accent)
        .environment(mediaAudio)
        .sheet(item: $sheet, onDismiss: {
            let shouldRecord = recordAfterDismiss
            recordAfterDismiss = false
            if shouldRecord && store.canStartRecording { Task { await mediaAudio.startRecording() } }
        }) { destination in
            switch destination {
            case .addMedia:
                CompanionAttachmentPicker(store: store, onRecord: { recordAfterDismiss = true })
            case .media(let attachment): CompanionMediaPreview(attachment: attachment)
            case .people: CompanionPeopleSheet(store: store)
            case .journey: CompanionJourneySheet(store: store)
            case .settings:
                SettingsView(onClose: { sheet = nil },
                    onClearAdditionalData: {
                        let cleared = store.clearLocalData()
                        if cleared { mediaAudio.stopPlayback(); mediaAudio.cancelPendingPermission(); recordAfterDismiss = false; composerID = UUID() }
                        return cleared
                    },
                    additionalExportFiles: {
                        let data = try store.exportedSnapshotData()
                        return [.init(filename: "roamorrow-companion.json", contents: String(decoding: data, as: UTF8.self))]
                    })
            case .sources(let entry): CompanionSourcesSheet(entry: entry)
            case .place(let experience, let origin, let usesGPS):
                CompanionPlaceSheet(experience: experience, store: store,
                    onInviteSaved: { surface = .now }, distanceOrigin: origin, distanceUsesGPS: usesGPS)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            case .cities(let model, let onSelect):
                CompanionCitySheet(model: model, onSelectCity: onSelect)
            }
        }
        .task {
            await routeSession.refresh(experiences: experiences.allExperiences)
            guard !didConfigure else { return }
            didConfigure = true
            store.configure(aiService: aiService, experienceService: experiences)
        }
        .onReceive(NotificationCenter.default.publisher(for: RouteStore.didChange)) { _ in
            Task { await routeSession.refresh(experiences: experiences.allExperiences) }
        }
        .onChange(of: mediaAudio.completedRecording?.id) { _, id in
            if id != nil, let recording = mediaAudio.takeCompletedRecording() { _ = store.stageAttachment(recording) }
        }
        .onDisappear {
            recordAfterDismiss = false
            mediaAudio.cancelPendingPermission()
            mediaAudio.stopPlayback()
            if mediaAudio.isRecording, let recording = mediaAudio.finishRecording() { _ = store.stageAttachment(recording) }
        }
        .onChange(of: surface) { _, _ in mediaAudio.stopPlayback() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { mediaAudio.stopPlayback() }
            if phase == .active { Task { await routeSession.refresh(experiences: experiences.allExperiences) } }
        }
        .onChange(of: liveActivities.current?.id) { _, _ in
            Task { await routeSession.refresh(experiences: experiences.allExperiences) }
        }
        .onOpenURL { url in
            guard url.scheme == "solocompass", url.host == "companion", url.path == "/route" else { return }
            surface = .nearby
            sheet = nil
            routeSession.reveal()
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) {
                surfacePicker
                Spacer(minLength: 4)
                headerActions
            }
            expandedHeader
        }
        .foregroundStyle(CompanionHomeStyle.ink)
        .padding(.horizontal, 16).padding(.vertical, 6)
        .background(surface == .now ? CompanionHomeStyle.paper : Color.clear)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("companion.header")
    }

    private var expandedHeader: some View {
        VStack(spacing: 4) {
            surfacePicker.frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 4)
            headerActions.frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var headerActions: some View {
        HStack(spacing: 0) {
            Menu {
                Button(companionText("companion.people.open", "选择这次的同行人"), systemImage: "person.2") { sheet = .people }
                if let active = routeSession.active {
                    Button(active.placeName, systemImage: "figure.walk") {
                        surface = .nearby; routeSession.reveal()
                    }
                }
                Button(companionText("companion.journey.open", "行程与约定"), systemImage: "calendar") { sheet = .journey }
                Button(companionText("companion.settings.open", "偏好与设置"), systemImage: "slider.horizontal.3") { sheet = .settings }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 20, weight: .medium))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .companionGlass(in: Circle())
            }
            .accessibilityLabel(companionText("companion.more", "更多"))
            .accessibilityIdentifier("companion.more")
        }
    }

    private var surfacePicker: some View {
        HStack(spacing: 2) {
            surfaceButton(.now, title: companionText("companion.now", "此刻"))
            surfaceButton(.nearby, title: companionText("companion.nearby", "附近"))
        }
        .padding(3)
        .companionGlass(in: Capsule())
    }

    private func surfaceButton(_ value: Surface, title: String) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { surface = value }
        } label: {
            Text(title).font(.subheadline.weight(.medium))
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 16).frame(minHeight: 44)
                .foregroundStyle(CompanionHomeStyle.ink)
                .background(Capsule().fill(surface == value ? CompanionHomeStyle.paper.opacity(0.9) : Color.clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(surface == value ? .isSelected : [])
        .accessibilityIdentifier("companion.surface.\(value.rawValue)")
    }

    private func openMedia(_ attachment: CompanionMediaAttachment) {
        if let place = attachment.place { showPlace(place.experienceID) }
        else { sheet = .media(attachment) }
    }

    private func showPlace(_ id: String) {
        guard let experience = experiences.getExperience(id: id) else { return }
        sheet = .place(experience, distanceOrigin: nil, usesGPS: false)
    }

    private func configureTools(_ model: MapViewModel) {
        if !didConfigure {
            store.configure(aiService: aiService, experienceService: experiences)
            didConfigure = true
        }
        store.configure(searchArea: { [weak model] in
            guard let model, let code = model.selectedCity, !code.hasPrefix("custom_"),
                  let city = model.availableCities.first(where: { $0.code == code }) else { return nil }
            return CompanionHomeSearchArea(
                name: CompanionPlacePresentation.cityName(code: city.code, fallback: city.name),
                latitude: city.center.latitude, longitude: city.center.longitude, cityCode: city.code)
        })
        guard toolRouter == nil else { return }
        let router = VoiceAgentToolRouter(mapViewModel: model, preferences: preferences, aiService: aiService)
        toolRouter = router
        store.configure(toolRouter: router)
    }
}

@MainActor
private struct CompanionJourneySheet: View {
    let store: CompanionHomeStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section {
                    if store.activeCommitments.isEmpty {
                        Text(companionText("companion.commitments.empty", "还没有记下待办。对话会先问清楚，再把需要做的事留在这里。"))
                            .foregroundStyle(CompanionHomeStyle.secondaryInk)
                    }
                    ForEach(store.activeCommitments) { commitment in
                        HStack(alignment: .top, spacing: 12) {
                            Button {
                                _ = store.completeCommitment(id: commitment.id)
                            } label: {
                                Image(systemName: "circle").frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(companionText("companion.commitments.complete", "标记完成") + "：" + commitment.title)
                            .accessibilityIdentifier("companion.commitment.complete.\(commitment.id)")
                            VStack(alignment: .leading, spacing: 8) {
                                Text(commitment.title).font(.body)
                                if !commitment.note.isEmpty {
                                    Text(commitment.note).font(.subheadline).foregroundStyle(CompanionHomeStyle.secondaryInk)
                                }
                                if let due = commitment.dueAt {
                                    Text(due, format: .dateTime.month().day().hour().minute())
                                        .companionMetadata().foregroundStyle(CompanionHomeStyle.secondaryInk)
                                }
                                Button(companionText("companion.commitments.discuss", "接着说这件事")) {
                                    store.composerDraft += (store.composerDraft.isEmpty ? "" : "\n\n") + commitment.title + "："
                                    dismiss()
                                }.font(.subheadline).frame(minHeight: 44)
                                    .accessibilityIdentifier("companion.commitment.discuss.\(commitment.id)")
                            }.padding(.vertical, 8)
                        }
                    }
                } header: {
                    Text(companionText("companion.commitments.active", "这几天的待办"))
                } footer: {
                    Text(companionText("companion.commitments.boundary", "这里记录要做的事；本机记录不会自动联系商家，也不代表正在后台监控。"))
                }
                Section(companionText("companion.journey.pending", "还在惦记的事")) {
                    let pending = store.entries.filter { $0.role == .user && $0.status != .delivered }
                    if pending.isEmpty {
                        Text(companionText("companion.journey.noPending", "暂时没有等待处理的对话。"))
                            .foregroundStyle(CompanionHomeStyle.secondaryInk)
                    }
                    ForEach(pending) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(entry.text).font(.system(.body, design: .serif))
                            Button(companionText("companion.retry", "继续处理这件事")) {
                                dismiss()
                                Task { await store.retry(id: entry.id) }
                            }.disabled(store.isWorking)
                        }.padding(.vertical, 6)
                    }
                }
                Section(companionText("companion.journey.invites", "这次的约定")) {
                    if store.invites.isEmpty {
                        Text(companionText("companion.journey.noInvites", "在附近选一个地方，记下想一起去的人。"))
                            .foregroundStyle(CompanionHomeStyle.secondaryInk)
                    }
                    ForEach(store.invites) { CompanionInviteCard(invite: $0).listRowBackground(Color.clear) }
                }
                if !store.commitments.filter({ $0.status == .done }).isEmpty {
                    Section(companionText("companion.commitments.finished", "已经完成")) {
                        ForEach(store.commitments.filter { $0.status == .done }) { commitment in
                            Label(commitment.title, systemImage: "checkmark.circle")
                                .foregroundStyle(CompanionHomeStyle.secondaryInk)
                        }
                    }
                }
                if let error = store.errorMessage {
                    Section { Text(error).companionMetadata().foregroundStyle(.red) }
                }
            }
            .navigationTitle(companionText("companion.journey.open", "行程与约定"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button(companionText("companion.common.done", "完成")) { dismiss() }
            } }
        }
    }
}

private struct CompanionSourcesSheet: View {
    let entry: CompanionHomeEntry
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(entry.sourceTitles.enumerated()), id: \.offset) { _, title in
                        sourceRow(title)
                    }
                } footer: {
                    Text(companionText("companion.sources.hint", "这些是提供给本轮回应的参考资料，不代表营业或交通情况已经实时核实。出发前请再确认。"))
                }
            }
            .navigationTitle(companionText("companion.sources.open", "查看依据"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button(companionText("companion.common.done", "完成")) { dismiss() }
            } }
        }.presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func sourceRow(_ title: String) -> some View {
        let parts = title.components(separatedBy: "\n")
        if parts.count > 1, let raw = parts.last, let url = URL(string: raw),
           ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
           let host = url.host, !host.isEmpty {
            Link(destination: url) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(parts.dropLast().joined(separator: "\n")).foregroundStyle(.primary)
                    Label(host, systemImage: "arrow.up.right").companionMetadata()
                }.frame(minHeight: 44, alignment: .leading)
            }
        } else { Text(title).textSelection(.enabled) }
    }
}
