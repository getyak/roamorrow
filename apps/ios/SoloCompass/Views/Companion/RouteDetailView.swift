import SwiftData
import SwiftUI

// MARK: - RouteDetailView

/// Pure-content route detail screen.
///
/// Layout (top → bottom):
///   1. Hero: gradient + category emoji + title + romanized + region badge
///   2. Mono baseline: duration · distance · pace · bestNow
///   3. VerifiedBadge
///   4. RecruitingModule (when companionEnabled && route.companion != nil)
///   5. StopsList (tapping a stop navigates to ExperienceDetailView)
///   6. Bottom dock: Save + Favorite CTAs
public struct RouteDetailView: View {
    let route: Route
    /// Explicit stop-tap handler for hosts that own the navigation (the map
    /// host). Optional — when absent, the detail pushes its own real stop
    /// detail (`ExperienceDetailView`) so every presentation site works
    /// instead of inheriting a silent no-op default.
    var onTapStop: ((Experience) -> Void)?
    /// Explicit start-route handler for the map host. Optional — when absent,
    /// the detail posts the unified `RouteNavigationRequest`, which
    /// CompassMapView consumes (dismissing any presenting surface first).
    var onStartRoute: ((Route) -> Void)?

    @Environment(ExperienceService.self) private var service
    @Environment(AIService.self) private var aiService
    @Environment(UserPreferences.self) private var preferences
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var heartBurstTrigger = 0
    @State private var showCompletionMoment = false
    @State private var showApprovalQueue = false
    /// Internal stop-detail fallback target (R2-03 / R2-05).
    @State private var stopDetailExperience: Experience?
    /// Real add-to-itinerary selection (R2-01) — the sheet pins every stop.
    @State private var showingAddToItinerary = false
    /// Read-back: title of an itinerary that already holds every route stop.
    @State private var savedItineraryTitle: String?
    /// Group-chat destination, only set when a conversation exists AND the
    /// viewer is authorized (R2-02).
    @State private var routeChatConversation: Conversation?
    // Single source of truth for the join / share sheets. Stacking two
    // `.sheet(isPresented:)` on one view collapses to only the last in SwiftUI
    // (the outer modifier overrides the inner), so a `.sheet(item:)` keyed on
    // this enum keeps both presentations working.
    @State private var activeSheet: RouteDetailSheet? = nil
    // Refreshes whenever RouteStore.didChange fires (join request submitted, accepted, etc.)
    @State private var liveRoute: Route

    public init(
        route: Route,
        onTapStop: ((Experience) -> Void)? = nil,
        onStartRoute: ((Route) -> Void)? = nil
    ) {
        self.route = route
        self._liveRoute = State(initialValue: route)
        self.onTapStop = onTapStop
        self.onStartRoute = onStartRoute
    }

    // MARK: - Companion recruiting helpers

    private var viewerDeviceId: String {
        DeviceIdentityService.shared.deviceID
    }

    private var viewerIsHost: Bool {
        guard let companion = liveRoute.companion else { return false }
        return companion.hostId == viewerDeviceId
    }

    private var hasMyRequest: Bool {
        guard let companion = liveRoute.companion else { return false }
        let deviceId = DeviceIdentityService.shared.deviceID
        return companion.joinRequests.contains { $0.requesterId == deviceId && $0.status == .pending }
    }

    // MARK: - Persistent favorite + itinerary read-back (R2-01)

    /// Route favorite state lives in UserPreferences (route-id namespace,
    /// independent of the experience favorites repository) so re-opening the
    /// detail reads the same state back.
    private var isFavorited: Bool {
        preferences.isRouteFavorited(liveRoute.id.rawValue)
    }

    /// Read-back for the itinerary dock button: finds an itinerary holding
    /// EVERY stop of this route. Keeps the button honest across re-opens
    /// instead of a per-session @State flip.
    private func refreshItineraryReadBack() {
        let stops = Set(liveRoute.experienceIds)
        guard !stops.isEmpty else {
            savedItineraryTitle = nil
            return
        }
        let store = ItineraryStore(context: modelContext)
        savedItineraryTitle = store.loadAll()
            .first { Set($0.experienceIds).isSuperset(of: stops) }?
            .title
    }

    // MARK: - Primary category (majority category of stops)

    private var primaryCategory: ExperienceCategory {
        let stops = liveRoute.experienceIds.compactMap { service.getExperience(id: $0) }
        guard !stops.isEmpty else { return .hidden }
        var counts: [ExperienceCategory: Int] = [:]
        for stop in stops { counts[stop.category, default: 0] += 1 }
        return counts.max(by: { $0.value < $1.value })?.key ?? .hidden
    }

    // MARK: - Mono baseline string

    private var monoBaseline: String {
        let durStr = "\(liveRoute.estimatedDuration)"
        let distStr = "\(liveRoute.distanceMeters) m"
        let paceStr = liveRoute.pace.localizedLabel
        let bestStr = liveRoute.bestNow
            ? NSLocalizedString("route.detail.bestNow.yes", comment: "")
            : NSLocalizedString("route.detail.bestNow.no", comment: "")
        return "\(durStr) min · \(distStr) · \(paceStr) · \(bestStr)"
    }

    // MARK: - Body

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heroBlock
                contentStack
                Spacer(minLength: 100) // room for bottom dock
            }
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) { bottomDock }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { shareButton }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .join:
                JoinRouteRequestSheet(route: liveRoute)
            case .share:
                RouteShareSheet(payload: sharePayload)
            }
        }
        .fullScreenCover(isPresented: $showCompletionMoment) {
            CompletionMoment(route: liveRoute, onDismiss: { showCompletionMoment = false })
        }
        .navigationDestination(isPresented: $showApprovalQueue) {
            ApprovalQueueView(route: liveRoute, contextProvider: { modelContext })
        }
        // Internal stop-detail fallback: hosts that pass `onTapStop` own the
        // navigation; every other presentation site lands on the real
        // ExperienceDetailView from the stop row (R2-03 / R2-05).
        .navigationDestination(item: $stopDetailExperience) { exp in
            ExperienceDetailView(
                viewModel: ExperienceDetailViewModel(
                    experience: exp,
                    experienceService: service,
                    aiService: aiService,
                    preferences: preferences
                ),
                onClose: { stopDetailExperience = nil }
            )
        }
        // Group chat for closed/completed routes — only reachable when the
        // conversation actually exists and the viewer is authorized (R2-02).
        .navigationDestination(item: $routeChatConversation) { conversation in
            ChatView(
                conversation: conversation,
                currentUserId: FriendService.shared.resolvedUserId
            )
        }
        .sheet(isPresented: $showingAddToItinerary) {
            // Real itinerary selection — saves every route stop in one write,
            // with the sheet's own honest success / error handling (R2-01).
            AddToItinerarySheet(
                experienceIds: liveRoute.experienceIds,
                experienceTitle: liveRoute.title,
                onSuccess: { itinerary in
                    savedItineraryTitle = itinerary.title
                }
            )
            .environment(service)
        }
        .onAppear { refreshItineraryReadBack() }
        .onReceive(NotificationCenter.default.publisher(for: RouteStore.didChange)) { note in
            // Accept both targeted (routeId key present) and broadcast (nil userInfo) changes.
            let affectedId = note.userInfo?["routeId"] as? String
            guard affectedId == nil || affectedId == route.id.rawValue else { return }
            if let updated = RouteStore(context: modelContext).get(route.id) {
                liveRoute = updated
            }
        }
    }

    // MARK: - Hero

    private var heroBlock: some View {
        ZStack(alignment: .bottomLeading) {
            CategoryVisual.gradient(for: primaryCategory)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 200)

            VStack(alignment: .leading, spacing: 6) {
                Text(CategoryVisual.emoji(for: primaryCategory))
                    .font(.system(size: 40))

                Text(liveRoute.title)
                    .ctDisplay(26, .bold)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                if !liveRoute.summary.isEmpty {
                    Text(liveRoute.summary)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    regionBadge
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .padding(.top, 60)
        }
    }

    private var regionBadge: some View {
        Text(liveRoute.region)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(.white.opacity(0.25))
            )
    }

    // MARK: - Content stack

    private var contentStack: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Mono baseline — quiet JetBrains-Mono line with a bottom hairline
            // (border-subtle), per .sc-meta-row.
            metaRow

            // VerifiedBadge
            VerifiedBadge(route: liveRoute)
                .padding(.horizontal, 20)

            // RecruitingModule — only when companion feature is on and route has a companion slot
            if preferences.companionEnabled, let _ = liveRoute.companion {
                RecruitingModule(
                    route: liveRoute,
                    viewerIsHost: viewerIsHost,
                    hasMyRequest: hasMyRequest,
                    strength: preferences.companionModuleStrength,
                    onRequestJoin: {
                        activeSheet = .join
                    },
                    onViewRequests: {
                        showApprovalQueue = true
                    }
                )
                .padding(.horizontal, 16)
            }

            if let plan = liveRoute.compiledPlan {
                compiledPlanCard(plan)
                    .padding(.horizontal, 16)
            }

            // Completion replay — separately named, host-only (R2-02).
            completionReplayRow
                .padding(.horizontal, 20)

            // StopsList
            StopsList(route: liveRoute) { exp in
                if let onTapStop {
                    onTapStop(exp)
                } else {
                    stopDetailExperience = exp
                }
            }
                .background(CT.surfaceWhite)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(CT.borderSubtle, lineWidth: 0.5)
                )
                .padding(.horizontal, 16)

            // Route analysis status — honest availability only (R2-06).
            aiInsightUnavailable
                .padding(.horizontal, 20)

            // Route tags (.sc-tag-row) — accent-soft pills, only when the route has tags
            if !liveRoute.tags.isEmpty {
                tagRow
                    .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Meta row (.sc-meta-row)

    private var metaRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(monoBaseline)
                .ctMono(12)
                .foregroundStyle(CT.fgMuted)
                .padding(.vertical, 14)
            Rectangle()
                .fill(CT.borderSubtle)
                .frame(height: 0.5)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    // MARK: - Compiled workday schedule

    private func compiledPlanCard(_ plan: CompiledWorkdayPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CT.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("route.workday.schedule.title", comment: "Workday schedule title"))
                        .ctDisplay(12, .bold)
                        .tracking(0.7)
                        .textCase(.uppercase)
                    Text("\(plan.localDate) · \(Self.minuteLabel(plan.startsAtMinute))–\(Self.minuteLabel(plan.endsAtMinute))")
                        .ctMono(11)
                        .foregroundStyle(CT.fgMuted)
                }
                Spacer(minLength: 4)
                Text(NSLocalizedString(
                    plan.evidenceCoverage == "fresh"
                        ? "route.workday.evidence.badge.fresh"
                        : "route.workday.evidence.badge.partial",
                    comment: "Evidence status badge"
                ))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(plan.evidenceCoverage == "fresh" ? CT.verifiedGreen : CT.sunGoldDeep)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(
                        plan.evidenceCoverage == "fresh" ? CT.successSoft : CT.sunGoldSoft
                    )
                )
            }

            ForEach(plan.stops) { stop in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(Self.minuteLabel(stop.startMinute))–\(Self.minuteLabel(stop.endMinute))")
                            .ctMono(11, .semibold)
                            .foregroundStyle(CT.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stop.title)
                                .ctBody(13.5, .semibold)
                                .foregroundStyle(CT.fgPrimary)
                            Text(Self.taskKindLabel(stop.taskKind))
                                .ctBody(11)
                                .foregroundStyle(CT.fgMuted)
                        }
                        Spacer(minLength: 0)
                    }
                    if stop.travelFromPreviousMinutes > 0 || stop.waitMinutes > 0 {
                        Text(Self.stopMeta(stop))
                            .ctBody(10.5)
                            .foregroundStyle(CT.fgMuted)
                    }
                    if let fallback = plan.fallbacks.first(where: { $0.taskId == stop.taskId }) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 10, weight: .semibold))
                            Text(String(
                                format: NSLocalizedString("route.workday.fallback", comment: "Fallback place and extra minutes"),
                                fallback.title,
                                fallback.extraTravelMinutes
                            ))
                            .ctBody(11, .medium)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(CT.accent)
                    }
                }
                .padding(.vertical, 2)
            }

            if plan.evidenceCoverage != "fresh" {
                Label(
                    NSLocalizedString(
                        plan.refreshScheduled
                            ? "route.workday.refresh.scheduled"
                            : "route.workday.refresh.partial",
                        comment: "Partial route evidence note"
                    ),
                    systemImage: "exclamationmark.triangle"
                )
                .ctBody(10.5)
                .foregroundStyle(CT.sunGoldDeep)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(CT.surfaceWhite)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(CT.accentBorder, lineWidth: 0.5)
        )
    }

    private static func minuteLabel(_ minute: Int) -> String {
        String(format: "%02d:%02d", max(0, minute) / 60, max(0, minute) % 60)
    }

    private static func taskKindLabel(_ raw: String) -> String {
        NSLocalizedString("route.workday.task.\(raw)", comment: "Compiled route task kind")
    }

    private static func stopMeta(_ stop: CompiledRouteStop) -> String {
        var parts: [String] = []
        if stop.travelFromPreviousMinutes > 0 {
            parts.append(String(
                format: NSLocalizedString("route.workday.travel", comment: "Travel minutes"),
                stop.travelFromPreviousMinutes
            ))
        }
        if stop.waitMinutes > 0 {
            parts.append(String(
                format: NSLocalizedString("route.workday.wait", comment: "Wait minutes"),
                stop.waitMinutes
            ))
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Route analysis availability (R2-06)
    //
    // Weather / crowd / season analysis does not exist for routes yet. The
    // old card promised a Pro "Unlock" for it — paywalled copy for a feature
    // with no implementation behind it. This card states the actual status:
    // nothing is for sale here and no benefit is invented.
    private var aiInsightUnavailable: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("route.detail.aiInsight.title", comment: "AI insight section title"))
                .ctDisplay(12, .bold)
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(CT.fgMuted)

            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(CT.surfaceWhite)
                        .frame(width: 28, height: 28)
                    Image(systemName: "info")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CT.fgMuted)
                }
                Text(NSLocalizedString(
                    "route.detail.aiInsight.unavailable",
                    comment: "Weather/crowd/season analysis is not available for this route yet"
                ))
                .ctBody(12)
                .foregroundStyle(CT.fgMuted)
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(CT.surfaceSunken)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(CT.borderSubtle, lineWidth: 0.5)
            )
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Tag row (.sc-tag-row)

    private var tagRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("route.detail.tags.title", comment: "Route tags section title"))
                .ctDisplay(12, .bold)
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(CT.fgMuted)

            FlowLayout(spacing: 6) {
                ForEach(liveRoute.tags, id: \.self) { tag in
                    Text(tag)
                        .ctBody(12)
                        .foregroundStyle(CT.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(CT.accentSoft))
                        .overlay(Capsule().strokeBorder(CT.accentBorder, lineWidth: 1))
                }
            }
        }
    }

    // MARK: - Bottom dock

    private var showMarkCompleted: Bool {
        viewerIsHost && liveRoute.companion?.status == .closed
    }

    /// Resolved primary-CTA for the dock — label, SF symbol, disabled flag and
    /// action vary by companion state: no-companion → 开始路线; viewer
    /// open/forming → 申请加入; host open/forming → 审批 N; hasMyRequest →
    /// 等待确认(disabled); closed/completed → 进入群聊 only when a real group
    /// conversation exists and this viewer is allowed in (R2-02), otherwise an
    /// honestly disabled item — never an enabled dead action.
    private struct PrimaryCTA {
        let label: String
        let systemImage: String
        let isDisabled: Bool
        let action: () -> Void
    }

    /// Group-chat access for the closed/completed branch (R2-02).
    private var chatAccess: RouteChatAccess {
        guard let companion = liveRoute.companion else { return .noConversation }
        let conversation: Conversation?
        if let convId = companion.groupConversationId {
            conversation = ConversationStore(context: modelContext)
                .get(ConversationId(rawValue: convId))
        } else {
            conversation = nil
        }
        return RouteChatAccess.decide(
            companion: companion,
            conversation: conversation,
            viewerId: viewerDeviceId
        )
    }

    private var primaryCTA: PrimaryCTA {
        // Host of a closed route gets the "mark completed" celebration CTA.
        if showMarkCompleted {
            return PrimaryCTA(
                label: NSLocalizedString("completion.mark.done", comment: ""),
                systemImage: "checkmark.seal.fill",
                isDisabled: false,
                action: { showCompletionMoment = true }
            )
        }

        guard preferences.companionEnabled, let companion = liveRoute.companion else {
            return PrimaryCTA(
                label: NSLocalizedString("route.detail.start", comment: ""),
                systemImage: "location.north.line.fill",
                isDisabled: false,
                action: {
                    // Map hosts draw the polyline + numbered stops and frame
                    // the camera via their own callback; every other site
                    // posts the unified request, which CompassMapView consumes
                    // after dismissing any presenting surface (R2-03).
                    if let onStartRoute {
                        onStartRoute(liveRoute)
                    } else {
                        RouteNavigationRequest.requestStart(route: liveRoute)
                    }
                    dismiss()
                }
            )
        }

        let isRecruiting = companion.status == .open || companion.status == .forming

        if isRecruiting && viewerIsHost {
            let pending = companion.joinRequests.filter { $0.status == .pending }.count
            return PrimaryCTA(
                label: String(format: NSLocalizedString("route.detail.cta.review", comment: ""), pending),
                systemImage: "person.2.fill",
                isDisabled: false,
                action: { showApprovalQueue = true }
            )
        }
        if isRecruiting && hasMyRequest {
            return PrimaryCTA(
                label: NSLocalizedString("route.detail.cta.waiting", comment: ""),
                systemImage: "clock.fill",
                isDisabled: true,
                action: {}
            )
        }
        if isRecruiting {
            return PrimaryCTA(
                label: NSLocalizedString("route.detail.cta.requestJoin", comment: ""),
                systemImage: "person.2.fill",
                isDisabled: false,
                action: { activeSheet = .join }
            )
        }
        // closed / completed → real group chat when available; otherwise an
        // honestly disabled item. The completion celebration is a separate,
        // separately-named control (completionReplayRow) — it must never play
        // under a "chat" label (R2-02).
        switch chatAccess {
        case .available(let conversation):
            return PrimaryCTA(
                label: NSLocalizedString("route.detail.cta.groupChat", comment: ""),
                systemImage: "message.fill",
                isDisabled: false,
                action: { routeChatConversation = conversation }
            )
        case .noConversation, .notAuthorized:
            return PrimaryCTA(
                label: NSLocalizedString("route.detail.cta.groupChat.unavailable", comment: ""),
                systemImage: "message.fill",
                isDisabled: true,
                action: {}
            )
        }
    }

    /// Host-only replay of the completion celebration — named for what it
    /// does and kept out of the chat CTA (R2-02).
    @ViewBuilder
    private var completionReplayRow: some View {
        if let companion = liveRoute.companion,
           RouteCompletionReplay.isReplayVisible(status: companion.status, viewerIsHost: viewerIsHost) {
            Button {
                showCompletionMoment = true
            } label: {
                Label(
                    NSLocalizedString(
                        "route.detail.completion.replay",
                        comment: "Replay the route completion moment (host, completed route)"
                    ),
                    systemImage: "arrow.counterclockwise"
                )
                .ctBody(13, .semibold)
                .foregroundStyle(CT.accent)
                .frame(minHeight: HitTargetMetrics.minimum)
                .padding(.horizontal, 14)
                .background(Capsule().fill(CT.accentSoft))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(NSLocalizedString(
                "route.detail.completion.replay",
                comment: "Replay the route completion moment (host, completed route)"
            )))
        }
    }

    private var bottomDock: some View {
        let cta = primaryCTA
        return VStack(spacing: 0) {
            Rectangle().fill(CT.borderSubtle).frame(height: 0.5)
            // Adaptive dock (review closure 4): the horizontal dock is the
            // quiet default; the single-line label reports its full ideal
            // width to ViewThatFits, so at large Dynamic Type (or a long CTA
            // label) the row stops fitting and the vertical dock takes over.
            // Either way the CTA uses minHeight 44 with a vertically-growing
            // label — scaled text is never clipped.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    favoriteButton
                    itineraryButton
                    ctaButton(cta, wrapsLabel: false)
                }
                VStack(spacing: 10) {
                    ctaButton(cta, wrapsLabel: true)
                    HStack(spacing: 12) {
                        favoriteButton
                        itineraryButton
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
        }
    }

    // MARK: - Dock pieces

    /// Ghost button — favorite. Persists through UserPreferences (route-id
    /// namespace, separate from experience favorites) so the state survives
    /// re-entry (R2-01) — no @State fake toggle.
    private var favoriteButton: some View {
        Button {
            let nowFavorited = preferences.toggleRouteFavorite(liveRoute.id.rawValue)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if nowFavorited { heartBurstTrigger += 1 }
            }
            if nowFavorited {
                Haptics.notify(.success)
            } else {
                Haptics.impact(.light)
            }
        } label: {
            Image(systemName: isFavorited ? "heart.fill" : "heart")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isFavorited ? CT.toneClosed : CT.fgMuted)
                .symbolEffect(.bounce, value: isFavorited)
                .scaleEffect(isFavorited ? 1.12 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFavorited)
                .frame(width: 44, height: 44)
                .background(Circle().fill(CT.surfaceSunken))
                .overlay { HeartBurstView(trigger: heartBurstTrigger) }
        }
        .accessibilityLabel(Text(NSLocalizedString("route.detail.favorite", comment: "")))
        .accessibilityValue(Text(isFavorited
            ? NSLocalizedString("action.favorited", comment: "Favorited accessibility value")
            : NSLocalizedString("action.notFavorited", comment: "Not favorited accessibility value")))
    }

    /// Ghost button — add to itinerary. Opens the real itinerary picker;
    /// every route stop is pinned on success (R2-01).
    private var itineraryButton: some View {
        Button {
            showingAddToItinerary = true
        } label: {
            Image(systemName: savedItineraryTitle != nil ? "calendar.badge.checkmark" : "calendar.badge.plus")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(savedItineraryTitle != nil ? CT.accent : CT.fgMuted)
                .frame(width: 44, height: 44)
                .background(Circle().fill(CT.surfaceSunken))
        }
        .accessibilityLabel(Text(NSLocalizedString("route.detail.save", comment: "")))
        .accessibilityValue(Text(savedItineraryTitle.map {
            String(format: NSLocalizedString("route.detail.save.savedIn", comment: "Saved in itinerary %@"), $0)
        } ?? ""))
    }

    /// Primary CTA — accent fill, state-dependent label. The ONLY primary
    /// element in the dock (quiet ghost buttons beside it). `wrapsLabel`
    /// selects the vertical-dock variant where the label may wrap to more
    /// lines; both keep a real minHeight-44 hit region (review closure 4).
    private func ctaButton(_ cta: PrimaryCTA, wrapsLabel: Bool) -> some View {
        Button(action: cta.action) {
            HStack(spacing: 6) {
                Image(systemName: cta.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                if wrapsLabel {
                    Text(cta.label)
                        .ctBody(15, .semibold)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    // Single-line ideal width drives the ViewThatFits choice.
                    Text(cta.label)
                        .ctBody(15, .semibold)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(minHeight: HitTargetMetrics.minimum)
            .foregroundStyle(cta.isDisabled ? CT.fgMuted : CT.surfaceWhite)
            .background(
                Capsule().fill(cta.isDisabled ? CT.surfaceSunken : CT.accent)
            )
        }
        .disabled(cta.isDisabled)
        .accessibilityLabel(Text(cta.label))
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var shareButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                activeSheet = .share
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel(NSLocalizedString("route.share.title", comment: "Share route"))
        }
    }

    /// Pre-built payload for the share sheet — resolves the primary category,
    /// stop count, and ordered stop coordinates once so the sheet stays a pure
    /// visual layer. Coordinates drive the map-basemap / vector-trace share card.
    private var sharePayload: RouteSharePayload {
        let coordinates = liveRoute.experienceIds
            .compactMap { service.getExperience(id: $0) }
            .compactMap { $0.coordinate }
        return RouteSharePayload(
            route: liveRoute,
            category: primaryCategory,
            stopCount: liveRoute.experienceIds.count,
            coordinates: coordinates
        )
    }
}

// MARK: - RouteDetailSheet

/// Which modal RouteDetailView is presenting. A single `.sheet(item:)` keyed on
/// this enum avoids stacking two `.sheet(isPresented:)` modifiers (SwiftUI keeps
/// only the last, breaking the other).
enum RouteDetailSheet: Identifiable {
    case join
    case share

    var id: String {
        switch self {
        case .join:  return "join"
        case .share: return "share"
        }
    }
}

// MARK: - Pace localization

extension Pace {
    var localizedLabel: String {
        switch self {
        case .relaxed:  return NSLocalizedString("route.detail.pace.relaxed", comment: "")
        case .standard: return NSLocalizedString("route.detail.pace.standard", comment: "")
        case .packed:   return NSLocalizedString("route.detail.pace.packed", comment: "")
        }
    }
}

// MARK: - Preview

#Preview("mekong-sunset route") {
    let now = Date()
    let recent = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now

    let conf = Confidence(
        level: 4,
        lastVerifiedAt: recent,
        reason: "Preview",
        signals: .init(aiScrapeAgeDays: 7, passiveGpsHits30d: 24, activeReports30d: 8, trustedVerifications: 1)
    )

    let mekongExp = Experience(
        id: "exp_vte_mekong_riverside_sunset",
        title: "Watch the sun fall into Thailand from the Mekong promenade",
        oneLiner: "Plastic chairs, cheap Beerlao, and a river that swallows the sun in 12 minutes.",
        whyItMatters: "The Mekong here is the border.",
        category: .nature,
        location: ExperienceLocation(
            coordinates: [102.6093, 17.9633],
            cityCode: "VTE",
            addressHint: "Chao Anouvong Park, Quai Fa Ngum",
            placeNameLocal: "ແມ່ນ້ຳຂອງ",
            placeNameRomanized: "Mae Nam Khong"
        ),
        bestTimes: [TimeWindow(startHour: 17, endHour: 19)],
        durationMinutes: .init(min: 45, max: 90),
        howTo: [],
        realInconveniences: [],
        soloScore: SoloScore(
            overall: 9.0,
            breakdown: .init(seatingFriendly: 10, soloPatronRatio: 7, staffPressure: 10, soloPortioning: 9, ambianceFit: 9, safety: 9),
            basedOnCount: 22
        ),
        sources: [],
        confidence: conf,
        nearbyExperienceIds: [],
        stats: .init(completionCount: 22, averageRating: 4.8),
        status: .active,
        createdAt: recent,
        updatedAt: recent
    )

    let watExp = Experience(
        id: "exp_vte_wat_si_saket_morning",
        title: "Sit alone in the oldest surviving temple in Vientiane at dawn",
        oneLiner: "Clay Buddha niches, terracotta floor, and 6,840 ceramic figurines — all to yourself before 8am.",
        whyItMatters: "Wat Si Saket was built in 1818.",
        category: .culture,
        location: ExperienceLocation(
            coordinates: [102.6161, 17.9629],
            cityCode: "VTE",
            addressHint: "Lane Xang Ave, Vientiane",
            placeNameLocal: "ວັດສີສະເກດ",
            placeNameRomanized: "Wat Si Saket"
        ),
        bestTimes: [TimeWindow(startHour: 8, endHour: 10)],
        durationMinutes: .init(min: 30, max: 60),
        howTo: [],
        realInconveniences: [],
        soloScore: SoloScore(
            overall: 8.8,
            breakdown: .init(seatingFriendly: 9, soloPatronRatio: 6, staffPressure: 10, soloPortioning: 10, ambianceFit: 10, safety: 8),
            basedOnCount: 18
        ),
        sources: [],
        confidence: conf,
        nearbyExperienceIds: [],
        stats: .init(completionCount: 30, averageRating: 4.9),
        status: .active,
        createdAt: recent,
        updatedAt: recent
    )

    let route = Route(
        id: RouteId(rawValue: "mekong-sunset"),
        title: "Mekong Sunset Walk",
        summary: "A 45-minute promenade walk that ends on a plastic chair facing Thailand.",
        experienceIds: ["exp_vte_mekong_riverside_sunset", "exp_vte_wat_si_saket_morning"],
        cityCode: "VTE",
        region: "Riverfront",
        estimatedDuration: 90,
        distanceMeters: 1200,
        pace: .relaxed,
        source: .editorial,
        bestNow: true,
        verification: RouteVerification(status: .walkedBy, walkedByCount: 12, walkedBy: ["maya", "leo"])
    )

    let service = ExperienceService(seed: [mekongExp, watExp])

    NavigationStack {
        RouteDetailView(route: route)
            .environment(service)
            .environment(AIService())
            .environment(UserPreferences())
    }
    .modelContainer(SoloCompassModelContainer.makeInMemory())
}
