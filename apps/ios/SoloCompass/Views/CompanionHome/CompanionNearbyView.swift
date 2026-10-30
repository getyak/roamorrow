import MapKit
import SwiftUI

/// Map, camera and browsing state stay mounted across the four primary tabs.
@MainActor
struct CompanionNearbyView: View {
    @Binding var sheet: CompanionHomePresentation?
    let store: CompanionHomeStore
    let routeSession: CompanionRouteSession
    var isActive = true
    var onModelReady: ((MapViewModel) -> Void)? = nil
    var onConversation: () -> Void
    var onReturnToSource: () -> Void = {}
    var onAskPlace: (Experience) -> Void = { _ in }
    var onAskArea: (CompanionHomeAreaScope) -> Void = { _ in }
    var messageRevealToken = 0
    @Environment(LocationService.self) private var location
    @Environment(ExperienceService.self) private var experiences
    @Environment(AIService.self) private var ai
    @Environment(UserPreferences.self) private var preferences
    @State private var model: MapViewModel?

    var body: some View {
        Group {
            if let model {
                CompanionNearbyMap(sheet: $sheet, store: store, routeSession: routeSession,
                    isActive: isActive, location: location, model: model,
                    onModelReady: onModelReady, onConversation: onConversation,
                    onReturnToSource: onReturnToSource, onAskPlace: onAskPlace, onAskArea: onAskArea,
                    messageRevealToken: messageRevealToken)
            } else { Color(.systemGroupedBackground) }
        }
        .task {
            guard model == nil else { return }
            model = MapViewModel(locationService: location, experienceService: experiences,
                                 aiService: ai, preferences: preferences)
        }
    }
}

@MainActor
private struct CompanionNearbyMap: View {
    @Binding var sheet: CompanionHomePresentation?
    let store: CompanionHomeStore
    let routeSession: CompanionRouteSession
    let isActive: Bool
    let location: LocationService
    @Bindable var model: MapViewModel
    var onModelReady: ((MapViewModel) -> Void)?
    var onConversation: () -> Void
    var onReturnToSource: () -> Void = {}
    var onAskPlace: (Experience) -> Void = { _ in }
    var onAskArea: (CompanionHomeAreaScope) -> Void = { _ in }
    var messageRevealToken = 0
    @State private var didReportModel = false
    @State private var hasActivatedMap = false
    @State private var consumedMessageRevealToken = 0
    @State private var viewport = MapInteractionCoordinator()
    @State private var locationRequested = false
    @State private var mapCenter: CLLocationCoordinate2D?
    @State private var lastCamera: MapCamera?
    @State private var currentRegion: MKCoordinateRegion?
    @State private var searchQuery = ""
    @State private var showsSearch = false
    @State private var searchTask: Task<Void, Never>?
    @State private var workspaceHeaderHeight: CGFloat = 160
    @State private var mapControlsHeight: CGFloat = 44
    @State private var selectedPlaceID: String?
    @State private var level: CompanionPanelLevel = .collapsed
    @State private var page: PanelPage = .browse
    @State private var controlsVisible = true
    @State private var keyboardVisible = false
    @State private var filterOptions = false
    @State private var restoreControls: Task<Void, Never>?
    @State private var endingRoute = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(UserPreferences.self) private var preferences
    @Environment(ExperienceService.self) private var experiences

    private enum PanelPage { case browse, place, route }
    private var place: Experience? {
        selectedPlaceID.flatMap { id in model.allExperiences.first { $0.id == id } ?? experiences.getExperience(id: id) }
    }
    private var panelHeight: CGFloat {
        if keyboardVisible { return 290 }
        switch page {
        case .browse: return 370
        case .place: return 290
        case .route: return 335
        }
    }

    var body: some View {
        Group {
        if hasActivatedMap || isActive {
        map
            .ignoresSafeArea(edges: .top)
            .overlay { GeometryReader { proxy in
                VStack(spacing: 8) {
                    workspaceHeader
                        .background { GeometryReader { geometry in
                            Color.clear.preference(key: CompanionMapHeaderHeight.self, value: geometry.size.height)
                        } }
                    Spacer(minLength: 0)
                    if !keyboardVisible {
                    mapControls
                        .background { GeometryReader { geometry in
                            Color.clear.preference(key: CompanionMapControlsHeight.self, value: geometry.size.height)
                        } }
                        .opacity(controlsVisible || voiceOver ? 1 : 0)
                        .allowsHitTesting(controlsVisible || voiceOver)
                        .accessibilityHidden(!controlsVisible && !voiceOver)
                    CompanionMapPanel(level: $level, expandedHeight: panelHeight,
                                      availableHeight: max(86, proxy.size.height - workspaceHeaderHeight - mapControlsHeight - 24)) {
                        collapsedSummary
                    } header: {
                        panelHeader
                    } content: {
                        panelContent
                    }
                    }
                }
                .onPreferenceChange(CompanionMapHeaderHeight.self) { workspaceHeaderHeight = $0 }
                .onPreferenceChange(CompanionMapControlsHeight.self) { mapControlsHeight = $0 }
                .padding(.horizontal, 12).padding(.bottom, 8)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .opacity(sheet == nil ? 1 : 0)
                .allowsHitTesting(sheet == nil)
                .accessibilityHidden(sheet != nil)
            } }
        } else { Color.clear }
        }
            .task {
                if isActive { hasActivatedMap = true }
                if !didReportModel {
                    didReportModel = true
                    onModelReady?(model)
                    if routeSession.active != nil { page = .route }
                }
                consumeRouteReveal()
                consumeMessageReveal()
            }
            .onChange(of: isActive) { _, active in
                if !active {
                    if model.cameraPosition.positionedByUser, let lastCamera {
                        model.cameraPosition = .camera(lastCamera)
                    }
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    restoreControls?.cancel()
                    controlsVisible = true
                    if sheet?.isMapTask == true { sheet = nil }
                    if locationRequested { location.stopUpdating() }
                } else {
                    hasActivatedMap = true
                    consumeRouteReveal()
                    consumeMessageReveal()
                    if locationRequested && scenePhase == .active { location.startUpdating() }
                }
            }
            .onChange(of: scenePhase) { _, phase in
                guard locationRequested else { return }
                if phase == .active && isActive { location.startUpdating() } else { location.stopUpdating() }
            }
            .onDisappear { searchTask?.cancel(); restoreControls?.cancel(); if locationRequested { location.stopUpdating() } }
            .onChange(of: location.currentLocation) { _, value in
                guard isActive, scenePhase == .active, locationRequested, let value else { return }
                model.followUserLocation(value.coordinate)
            }
            .onChange(of: model.selectedCity) { _, _ in
                searchTask?.cancel()
                if locationRequested { location.stopUpdating() }
                locationRequested = false
                mapCenter = model.cameraPosition.region?.center
                selectedPlaceID = nil
                page = .browse
            }
            .onChange(of: model.mapBrowseMode) { _, _ in
                searchTask?.cancel()
            }
            .onChange(of: preferences.favoritedExperiences) { _, _ in
                model.refreshFavorites()
            }
            .onChange(of: messageRevealToken) { _, _ in
                consumeMessageReveal()
            }
            .onChange(of: model.selectedExperience?.id) { _, id in
                selectedPlaceID = id
                page = id == nil ? .browse : .place
                if id != nil && isActive { expand() }
            }
            .onChange(of: model.messageResultIDs) { _, ids in
                if ids != nil {
                    selectedPlaceID = model.selectedExperience?.id
                    page = selectedPlaceID == nil ? .browse : .place
                    if isActive { expand() }
                }
            }
            .onChange(of: model.visibleExperiences.map(\.id)) { _, ids in
                if let selectedPlaceID, !ids.contains(selectedPlaceID) {
                    self.selectedPlaceID = nil; page = .browse
                }
            }
            .onChange(of: experiences.allExperiences.map(\.id)) { _, _ in
                if let center = distanceOrigin { model.refreshForLocation(center) }
            }
            .onChange(of: routeSession.revealRequest) { _, _ in
                consumeRouteReveal()
            }
            .onChange(of: routeSession.active?.contextID) { _, value in
                if value == nil && page == .route { page = .browse; collapse() }
                else { consumeRouteReveal() }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                guard isActive else { return }
                keyboardVisible = true
                if showsSearch { level = .collapsed } else { expand() }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardVisible = false }
    }

    private var map: some View {
        Map(position: $model.cameraPosition) {
            ForEach(Array(model.clusteredMapItems.prefix(50))) { item in
                if let coordinate = item.coordinate {
                    Annotation(annotationTitle(item), coordinate: coordinate) {
                        Button { select(item) } label: {
                            marker(item).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(annotationTitle(item))
                        .accessibilityIdentifier(annotationID(item))
                    }
                }
            }
            if locationRequested && isActive { UserAnnotation() }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .accessibilityIdentifier("companion.nearby.map")
        .onMapCameraChange(frequency: .continuous) { context in
            guard isActive else { return }
            lastCamera = context.camera
            if model.cameraPosition.positionedByUser { searchTask?.cancel() }
            guard model.cameraPosition.positionedByUser, !voiceOver, !keyboardVisible,
                  !typeSize.isAccessibilitySize else { return }
            restoreControls?.cancel()
            if controlsVisible {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) { controlsVisible = false }
                collapse()
            }
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            guard isActive else { return }
            restoreControls?.cancel()
            restoreControls = Task {
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { controlsVisible = true }
            }
            mapCenter = context.region.center
            currentRegion = context.region
            model.noteWorkspaceViewport(context.region)
            guard viewport.consumeRefresh(for: context.region) else { return }
            model.refreshForLocation(context.region.center)
        }
    }

    private var workspaceHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                cityButton.padding(.horizontal, 14).companionGlass(in: Capsule())
                Spacer(minLength: 8)
                Button {
                    showsSearch.toggle()
                    if !showsSearch {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                } label: {
                    Image(systemName: "magnifyingglass").font(.system(size: 20))
                        .frame(width: 44, height: 44).companionGlass(in: Circle())
                }.buttonStyle(.plain)
                    .accessibilityLabel(companionText("companion.map.search", "搜索地点"))
                    .accessibilityIdentifier("companion.map.search")
            }
            if !keyboardVisible {
            MapWorkspaceControls(viewModel: model,
                sourceLabel: store.mapSource == nil ? nil : companionText("companion.map.sourceKept", "原对话与草稿已保留"),
                onReturnToConversation: store.mapSource == nil ? nil : onReturnToSource,
                onSearchArea: {
                    model.searchThisArea()
                    if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { performSearch() }
                })
            }
            if showsSearch {
                HStack {
                    TextField(companionText("companion.map.searchPlaceholder", "地点、咖啡馆、书店…"), text: $searchQuery)
                        .font(.body).submitLabel(.search).onSubmit(performSearch)
                        .accessibilityIdentifier("companion.map.searchField")
                    if model.isSearchingWeb { ProgressView() }
                    else {
                        Button(action: performSearch) {
                            Image(systemName: "arrow.up.right").frame(width: 44, height: 44)
                        }.disabled(searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityLabel(companionText("companion.map.search", "搜索地点"))
                    }
                }.padding(.leading, 14).companionGlass(in: Capsule())
            }
        }.padding(.top, 8)
    }

    private func performSearch() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, let origin = model.agentSearchOrigin else { return }
        model.searchThisArea()
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        let previous = searchTask
        previous?.cancel()
        searchTask = Task {
            await previous?.value
            guard !Task.isCancelled else { return }
            await model.webSearchPOIs(query: query, near: origin.coordinate, constrainWorkspaceResults: true)
        }
    }

    private func consumeMessageReveal() {
        guard isActive, messageRevealToken != consumedMessageRevealToken else { return }
        consumedMessageRevealToken = messageRevealToken
        searchTask?.cancel()
        searchQuery = ""; showsSearch = false
        model.lastWebSearchResult = nil
        selectedPlaceID = model.selectedExperience?.id
        page = selectedPlaceID == nil ? .browse : .place
        expand()
    }

    private func askCurrentArea() {
        guard let origin = model.agentSearchOrigin else { return }
        let area = CompanionHomeSearchArea(
            name: origin.source == "selected_city" ? currentCityName : companionText("companion.map.area", "这片地图"),
            latitude: origin.coordinate.latitude, longitude: origin.coordinate.longitude,
            cityCode: origin.source == "selected_city" ? (model.selectedCity ?? "map_area") : "map_area")
        let region = currentRegion ?? model.cameraPosition.region
        onAskArea(CompanionHomeAreaScope(area: area,
            query: searchQuery.isEmpty ? nil : searchQuery, category: model.selectedCategory?.rawValue,
            experienceIDs: Array(model.visibleExperiences.prefix(100)).map(\.id),
            latitudeDelta: region?.span.latitudeDelta, longitudeDelta: region?.span.longitudeDelta))
    }

    private var mapControls: some View {
        CompanionGlassGroup {
            HStack(alignment: .center, spacing: 8) {
                if !typeSize.isAccessibilitySize {
                    CompanionMapFilters(selected: model.selectedCategory, isFavoriteFilter: model.isFavoriteFilter,
                        onSelect: selectCategory)
                }
                Spacer(minLength: 0)
                Button {
                    locationRequested = true
                    if location.authorizationStatus == .notDetermined { location.requestPermission() }
                    else { location.startUpdating() }
                    model.recenterOnUser()
                } label: {
                    Image(systemName: "location").font(.system(size: 18, weight: .medium))
                        .frame(width: 44, height: 44).companionGlass(in: Circle())
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                .accessibilityLabel(companionText("companion.nearby.locate", "定位到我"))
                .accessibilityIdentifier("companion.nearby.locate")
            }
        }
        .frame(height: 44)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var collapsedSummary: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                HStack { cityButton; Spacer(minLength: 0); expandControl }
                summaryOpen
            }
        } else {
        HStack(spacing: 8) {
            cityButton
            Rectangle().fill(CompanionHomeStyle.line).frame(width: 1, height: 16)
            summaryOpen
            expandControl
        }
        }
    }

    private var summaryOpen: some View {
        Button {
                if routeSession.active != nil && page == .route { page = .route }
                else if place != nil { page = .place }
                else { page = .browse }
                expand()
            } label: {
                Text(collapsedTitle).font(.subheadline).foregroundStyle(CompanionHomeStyle.secondaryInk)
                    .lineLimit(typeSize.isAccessibilitySize ? 2 : 1).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("companion.panel.open")
    }

    private var expandControl: some View {
        Button { expand() } label: {
                Image(systemName: "chevron.up").font(.system(size: 17))
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(companionText("companion.panel.expand", "展开附近面板"))
            .accessibilityIdentifier("companion.panel.expand")
    }

    private var collapsedTitle: String {
        if page == .route, let active = routeSession.active { return active.placeName }
        if let place { return place.shortName }
        return store.composerDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? companionText("companion.panel.prompt", "想去哪里…")
            : companionText("companion.panel.resumeDraft", "继续编辑草稿")
    }

    private var cityButton: some View {
        Button {
            sheet = .cities(model, onSelect: {
                if locationRequested { location.stopUpdating() }
                locationRequested = false
            })
        } label: {
            HStack(spacing: 4) {
                Text(currentCityName).font(.headline).lineLimit(1)
                Image(systemName: "chevron.down").font(.caption2)
            }
            .foregroundStyle(CompanionHomeStyle.ink)
            .frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("companion.nearby.city")
    }

    @ViewBuilder private var panelContent: some View {
        if typeSize.isAccessibilitySize || filterOptions {
            ScrollView(.horizontal, showsIndicators: false) {
                CompanionMapFilters(selected: model.selectedCategory, isFavoriteFilter: model.isFavoriteFilter, onSelect: selectCategory)
            }.padding(.vertical, 6)
        }
        switch page {
        case .place:
            if let place { placePeek(place) } else { browseContent }
        case .route:
            if let active = routeSession.active { routeContent(active) } else { browseContent }
        case .browse: browseContent
        }
        if let error = routeSession.errorMessage {
            HStack(alignment: .top, spacing: 6) {
                Text(error).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                Button { routeSession.clearError() } label: {
                    Image(systemName: "xmark").frame(width: 44, height: 44)
                }.accessibilityLabel(companionText("companion.dismiss_notice", "关闭提示"))
            }.foregroundStyle(CompanionHomeStyle.secondaryInk)
        }
        if locationRequested && (location.authorizationStatus == .denied || location.authorizationStatus == .restricted) {
            Text(companionText("companion.nearby.locationDenied", "定位未开启，仍可移动地图查看。可在系统设置中更改权限。"))
                .font(.subheadline).foregroundStyle(CompanionHomeStyle.secondaryInk).padding(.vertical, 8)
        }
    }

    private var panelHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) { cityButton; Spacer(minLength: 0); panelActions }
            VStack(alignment: .leading, spacing: 4) { cityButton; panelActions }
        }
    }

    private var panelActions: some View {
        HStack(spacing: 2) {
            Button {
                model.setMapBrowseMode(model.mapBrowseMode == .saved ? .nearby : .saved)
                selectedPlaceID = model.selectedExperience?.id
                page = selectedPlaceID == nil ? .browse : .place
            } label: { Image(systemName: model.isFavoriteFilter ? "heart.fill" : "heart").font(.system(size: 17)).frame(width: 44, height: 44).contentShape(Rectangle()) }
                .buttonStyle(.plain).accessibilityLabel(companionText("companion.nearby.saved", "收藏"))
                .accessibilityAddTraits(model.mapBrowseMode == .saved ? .isSelected : [])
                .accessibilityIdentifier("companion.nearby.saved")
            Button {
                filterOptions.toggle(); page = .browse
            } label: { Image(systemName: "slider.horizontal.3").font(.system(size: 17)).frame(width: 44, height: 44).contentShape(Rectangle()) }
                .buttonStyle(.plain).accessibilityLabel(companionText("companion.panel.filters", "展开筛选"))
                .accessibilityIdentifier("companion.panel.filters")
            Button { collapse() } label: { Image(systemName: "chevron.down").font(.system(size: 17)).frame(width: 44, height: 44).contentShape(Rectangle()) }
                .buttonStyle(.plain).accessibilityLabel(companionText("companion.panel.collapse", "收起面板"))
                .accessibilityIdentifier("companion.panel.collapse")
        }.font(.subheadline).foregroundStyle(CompanionHomeStyle.secondaryInk)
    }

    private var browseContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: askCurrentArea) {
                Label(companionText("companion.map.askArea", "问问这片区域"), systemImage: "bubble.left")
                    .font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }.accessibilityIdentifier("companion.map.askArea")
                .disabled(model.agentSearchOrigin == nil)
            if let active = routeSession.active {
                Button { page = .route; expand() } label: {
                    Label(active.placeName, systemImage: "figure.walk")
                        .font(.subheadline).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }.accessibilityIdentifier("companion.route.open")
            }
            if model.visibleExperiences.isEmpty {
                if model.isSearchingWeb {
                    Text(companionText("companion.progress.search", "正在查找地点…"))
                        .font(.subheadline).foregroundStyle(CompanionHomeStyle.secondaryInk)
                } else if model.mapBrowseMode == .nearby,
                          let outcome = model.lastWebSearchResult, outcome.matches(searchQuery) {
                    Text(outcome.message).font(.subheadline)
                        .foregroundStyle(CompanionHomeStyle.secondaryInk)
                        .accessibilityIdentifier("companion.map.searchOutcome")
                    if outcome.status == .failed {
                        Button(companionText("companion.map.retrySearch", "重试这次搜索"), action: performSearch)
                            .frame(minHeight: 44)
                    } else {
                        Button(companionText("companion.map.editSearch", "修改搜索词")) { showsSearch = true }
                            .frame(minHeight: 44)
                    }
                } else if model.mapBrowseMode == .saved {
                    Text(companionText("map.workspace.empty.saved", "这个范围还没有收藏，可以切回附近挑选地点。"))
                        .font(.subheadline).foregroundStyle(CompanionHomeStyle.secondaryInk)
                    Button(companionText("companion.map.browseNearby", "看看附近")) { model.setMapBrowseMode(.nearby) }
                        .frame(minHeight: 44)
                } else if model.messageResultIDs != nil {
                    Text(companionText("companion.map.sourceMissing", "这条回答的地点资料暂不可用，可回到原对话继续核对。"))
                        .font(.subheadline).foregroundStyle(CompanionHomeStyle.secondaryInk)
                    if store.mapSource != nil {
                        Button(companionText("map.workspace.source.return", "回到原对话"), action: onReturnToSource)
                            .frame(minHeight: 44)
                    }
                } else {
                    Text(companionText("companion.nearby.empty", "这片区域还没有收录的体验，移动地图看看"))
                        .font(.subheadline).foregroundStyle(CompanionHomeStyle.secondaryInk)
                    Button(companionText("companion.filter.clear", "清除筛选")) {
                        model.clearFilters(); model.refreshWorkspaceMapPreservingCamera()
                    }.frame(minHeight: 44)
                }
            } else {
                ForEach(model.visibleExperiences) { experience in
                    Button { choose(experience) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: experience.category.symbol).font(.subheadline).frame(width: 24)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(experience.shortName).font(.headline).fixedSize(horizontal: false, vertical: true)
                                Text(sourceStatus(experience)).font(.caption).foregroundStyle(CompanionHomeStyle.secondaryInk)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption)
                        }.frame(maxWidth: .infinity, minHeight: 52, alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("companion.nearby.place.\(experience.id)")
                    Divider().accessibilityHidden(true)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("companion.nearby.candidates")
    }

    private func placePeek(_ experience: Experience) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(experience.shortName).font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
            Text(sourceStatus(experience)).font(.caption).foregroundStyle(CompanionHomeStyle.secondaryInk)
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) { askPlaceButton(experience); saveButton(experience) }
            } else {
                HStack(spacing: 12) { askPlaceButton(experience); saveButton(experience) }
            }
            Text(CompanionPlacePresentation.summary(experience.oneLiner,
                chinese: LanguageService.shared.effectiveLocale.language.languageCode?.identifier == "zh"))
                .font(.subheadline).foregroundStyle(CompanionHomeStyle.secondaryInk).lineLimit(2)
            if let distance = CompanionPlacePresentation.distance(to: experience.coordinate, from: distanceOrigin, usesGPS: hasFreshGPS) {
                Text(distance).font(.subheadline).foregroundStyle(CompanionHomeStyle.secondaryInk)
            }
            detailButton(experience)
            Button {
                Task { if await routeSession.start(experience: experience, cityCode: experience.location.cityCode) { page = .route; expand() } }
            } label: {
                Label(companionText("companion.route.start", "开始前往这里"), systemImage: "figure.walk")
                    .font(.subheadline).frame(minHeight: 44).contentShape(Rectangle())
            }
            .accessibilityIdentifier("companion.route.start")
            .disabled(routeSession.isUpdating)
        }.padding(.top, 8)
    }

    private func askPlaceButton(_ experience: Experience) -> some View {
        Button { onAskPlace(experience) } label: {
            Label(companionText("map.workspace.askSelected", "聊聊这里"), systemImage: "bubble.left")
                .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(CompanionHomeStyle.paper)
                .background(CompanionHomeStyle.ink, in: Capsule())
        }.buttonStyle(.plain).accessibilityIdentifier("companion.map.askPlace")
    }

    private func detailButton(_ experience: Experience) -> some View {
        Button { sheet = .place(experience, distanceOrigin: distanceOrigin, usesGPS: hasFreshGPS) } label: {
            Text(companionText("companion.panel.detail", "查看地点")).font(.subheadline.weight(.semibold))
                .padding(.horizontal, 18).frame(minHeight: 44)
                .foregroundStyle(CompanionHomeStyle.paper).background(CompanionHomeStyle.ink, in: Capsule())
        }.buttonStyle(.plain).accessibilityIdentifier("companion.panel.detail")
    }
    private func saveButton(_ experience: Experience) -> some View {
        let saved = preferences.favoritedExperiences.contains(experience.id)
        return Button { preferences.toggleFavorite(experience.id) } label: {
            Label(saved ? companionText("companion.place.favorited", "已收藏") : companionText("companion.nearby.saved", "收藏"),
                  systemImage: saved ? "heart.fill" : "heart").font(.subheadline)
                .padding(.horizontal, 12).frame(minHeight: 44)
        }.buttonStyle(.plain).accessibilityIdentifier("companion.panel.save")
            .accessibilityAddTraits(saved ? .isSelected : [])
    }

    private func routeContent(_ active: CompanionRouteProgress) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(companionText("companion.route.active", "路线进行中"), systemImage: "figure.walk").font(.subheadline)
                .foregroundStyle(CompanionHomeStyle.secondaryInk)
            Text(active.placeName).font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
            Text(String(format: companionText("companion.route.progress", "第 %d 站，共 %d 站"), active.stopIndex + 1, active.totalStops))
                .font(.subheadline).foregroundStyle(CompanionHomeStyle.secondaryInk)
            Text(companionText("companion.route.timeUnknown", "时间待更新 · 到达后请标记"))
                .font(.subheadline).foregroundStyle(CompanionHomeStyle.secondaryInk).fixedSize(horizontal: false, vertical: true)
            Button { Task { _ = await routeSession.arrived() } } label: {
                Label(companionText("companion.route.arrived", "标记已到达"), systemImage: "checkmark")
                    .frame(maxWidth: .infinity, minHeight: 44).foregroundStyle(CompanionHomeStyle.paper)
                    .background(CompanionHomeStyle.ink, in: Capsule())
            }.buttonStyle(.plain).accessibilityIdentifier("companion.route.arrived")
                .disabled(routeSession.isUpdating)
            Button(companionText("companion.route.end", "结束这次路线")) { endingRoute = true }
                .disabled(routeSession.isUpdating)
                .frame(minHeight: 44).accessibilityIdentifier("companion.route.end")
                .confirmationDialog(companionText("companion.route.endQuestion", "结束这次路线？"), isPresented: $endingRoute, titleVisibility: .visible) {
                    Button(companionText("companion.route.end", "结束这次路线")) { Task { _ = await routeSession.end() } }
                    Button(companionText("companion.common.cancel", "取消"), role: .cancel) {}
                }
            if !routeSession.islandAvailable {
                Text(companionText("companion.route.islandUnavailable", "实时活动暂不可用，路线仍保留在这里。"))
                    .font(.subheadline).foregroundStyle(CompanionHomeStyle.secondaryInk)
            }
        }.padding(.top, 8).accessibilityElement(children: .contain)
            .accessibilityIdentifier("companion.route.active")
    }

    private func selectCategory(_ value: ExperienceCategory) {
        model.selectWorkspaceCategory(model.selectedCategory == value ? nil : value)
        selectedPlaceID = nil; page = .browse
    }
    private func consumeRouteReveal() {
        guard isActive, routeSession.wantsRoutePresentation, routeSession.active != nil else { return }
        page = .route
        expand()
        routeSession.acknowledgeReveal()
    }
    private func choose(_ experience: Experience) {
        model.selectWorkspaceExperience(experience)
        model.focusOnExperience(experience)
        selectedPlaceID = experience.id; page = .place; expand()
    }
    private func expand() { withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.94)) { level = .expanded } }
    private func collapse() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.94)) { level = .collapsed }
    }
    private func sourceStatus(_ experience: Experience) -> String {
        experience.sources.contains(where: { $0.url != nil })
            ? companionText("companion.place.sourceAvailable", "附来源链接 · 详情可核对")
            : companionText("companion.place.sourceUnverified", "收录资料 · 出发前请核实")
    }
    private var currentCityName: String {
        guard let city = model.availableCities.first(where: { $0.code == model.selectedCity }) else {
            return companionText("companion.city.choose", "选择城市")
        }
        if let center = currentRegion?.center,
           CLLocation(latitude: center.latitude, longitude: center.longitude).distance(
               from: CLLocation(latitude: city.center.latitude, longitude: city.center.longitude)) > 25_000 {
            return companionText("companion.map.area", "这片地图")
        }
        return CompanionPlacePresentation.cityName(code: city.code, fallback: city.name)
    }
    private var hasFreshGPS: Bool {
        guard locationRequested, let fix = location.currentLocation, fix.horizontalAccuracy >= 0,
              abs(fix.timestamp.timeIntervalSinceNow) < 300 else { return false }
        return location.authorizationStatus == .authorizedWhenInUse || location.authorizationStatus == .authorizedAlways
    }
    private var distanceOrigin: CLLocationCoordinate2D? {
        hasFreshGPS ? location.currentLocation?.coordinate : (mapCenter ?? model.cameraPosition.region?.center)
    }
    private func annotationTitle(_ item: MapItem) -> String {
        switch item { case .single(let value): return value.shortName; case .cluster(let cluster): return "\(cluster.count)" }
    }
    private func annotationID(_ item: MapItem) -> String {
        switch item { case .single(let value): return "companion.nearby.pin.\(value.id)"; case .cluster(let cluster): return "companion.nearby.cluster.\(cluster.id)" }
    }
    private func marker(_ item: MapItem) -> some View {
        let selected: Bool
        if case .single(let value) = item { selected = selectedPlaceID == value.id } else { selected = false }
        return Group {
            switch item {
            case .single(let value): Image(systemName: value.category.symbol)
            case .cluster(let cluster): Text("\(cluster.count)").fontWeight(.semibold)
            }
        }
        .font(selected ? .body : .caption)
        .foregroundStyle(CompanionHomeStyle.paper)
        .frame(width: selected ? 40 : 28, height: selected ? 40 : 28)
        .background(CompanionHomeStyle.ink.opacity(selected ? 1 : 0.7), in: Circle())
        .overlay(Circle().strokeBorder(.background, lineWidth: 2))
    }
    private func select(_ item: MapItem) {
        switch item {
        case .single(let value): choose(value)
        case .cluster(let cluster):
            model.cameraPosition = .region(MKCoordinateRegion(center: cluster.coordinate,
                span: MKCoordinateSpan(latitudeDelta: max(model.currentSpanLatitudeDelta / 3, 0.005),
                                       longitudeDelta: max(model.currentSpanLatitudeDelta / 3, 0.005))))
        }
    }
}

func companionMapText(_ key: String, _ fallback: String) -> String {
    NSLocalizedString(key, value: fallback, comment: "Continuous companion map and people")
}

private struct CompanionMapHeaderHeight: PreferenceKey {
    static let defaultValue: CGFloat = 160
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct CompanionMapControlsHeight: PreferenceKey {
    static let defaultValue: CGFloat = 44
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
