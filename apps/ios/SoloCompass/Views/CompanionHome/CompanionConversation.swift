import SwiftUI
#if DEBUG
import OSLog
#endif

@MainActor
struct CompanionConversation: View {
    let store: CompanionHomeStore
    let isActive: Bool
    let onSources: (CompanionHomeEntry) -> Void
    let onPlace: (CompanionHomeEntry, String?) -> Void
    let onCommitments: () -> Void
    let onMedia: (CompanionMediaAttachment) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // Only the iOS 17 binding publishes this value. Modern visible-ID readback
    // records an ignored checkpoint without invalidating the whole lazy list.
    @State private var legacyAnchorID: String?
    @State private var scrolling: CompanionScrollState

    init(store: CompanionHomeStore, isActive: Bool,
         onSources: @escaping (CompanionHomeEntry) -> Void,
         onPlace: @escaping (CompanionHomeEntry, String?) -> Void,
         onCommitments: @escaping () -> Void, onMedia: @escaping (CompanionMediaAttachment) -> Void) {
        self.store = store; self.isActive = isActive; self.onSources = onSources
        self.onPlace = onPlace; self.onCommitments = onCommitments; self.onMedia = onMedia
        _legacyAnchorID = State(initialValue: store.readingState.anchorID)
        _scrolling = State(initialValue: CompanionScrollState(reading: store.readingState))
    }

    var body: some View {
        let projection = store.timelineProjection
        return Group {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if !store.activeCommitments.isEmpty {
                        Button(action: onCommitments) {
                            HStack(spacing: 10) {
                                Image(systemName: "text.badge.checkmark")
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(String(format: companionText("companion.commitments.count", "%d 件待办"), store.activeCommitments.count))
                                        .companionMetadata().foregroundStyle(CompanionHomeStyle.secondaryInk)
                                    Text(store.activeCommitments.first?.title ?? "").lineLimit(2)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").companionMetadata()
                            }.font(.subheadline).frame(minHeight: 44).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .accessibilityIdentifier("companion.commitments")
                            .id("stream-commitments")
                    }
                    if projection.events.isEmpty { introduction.id("stream-introduction") }
                    ForEach(projection.rows) { row in
                        let event = row.event
                        VStack(alignment: .leading, spacing: 0) {
                            switch event {
                            case .message(let entry):
                                if projection.timestampIDs.contains(entry.id) {
                                    Text(entry.createdAt, format: .dateTime.month().day().hour().minute())
                                        .font(.footnote).foregroundStyle(CompanionHomeStyle.secondaryInk)
                                        .frame(maxWidth: .infinity).padding(.top, 14).padding(.bottom, 6)
                                }
                                CompanionMessageRow(entry: entry,
                                    replyContext: projection.replyContexts[entry.id],
                                    onRetry: { Task { await store.retry(id: entry.id) } },
                                    onSources: { onSources(entry) },
                                    onPlace: { id in onPlace(entry, id) },
                                    onMedia: onMedia, onQuote: { store.setDraftQuote($0) },
                                    onReaction: { store.toggleReaction(entryID: entry.id) })
                            case .invite(let invite):
                                CompanionInviteCard(invite: invite)
                            }
                        }.id(row.id)
                    }
                    if store.isWorking {
                        CompanionWorkingIndicator(store: store, scrolling: scrolling, isActive: isActive)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("companion.activity.working")
                        .id("stream-working")
                    }
                    if let error = store.errorMessage {
                        HStack(alignment: .top, spacing: 10) {
                            CompanionCharacter(activity: store.activity)
                            Text(error).companionMetadata()
                            Spacer(minLength: 0)
                            Button { store.clearError() } label: {
                                Image(systemName: "xmark").frame(width: 44, height: 44)
                            }.accessibilityLabel(companionText("companion.dismiss_notice", "关闭提示"))
                        }
                        .foregroundStyle(CompanionHomeStyle.secondaryInk).padding(14)
                        .background(.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
                        .id("stream-error")
                    }
                    Color.clear.frame(height: 1).id("stream-bottom")
                        .background {
                            if #unavailable(iOS 18.0) {
                            GeometryReader { proxy in
                                Color.clear.preference(key: CompanionConversationBottom.self, value: proxy.frame(in: .global).maxY)
                            }
                            }
                        }
                }
                .background {
                    if #unavailable(iOS 18.0) {
                        CompanionLegacyScrollProbe(isActive: isActive, onVisibility: observeNearLatest,
                            onInteraction: observeInteraction).frame(width: 0, height: 0)
                    }
                }
                .scrollTargetLayout()
                .padding(.top, 20).padding(.bottom, 16)
                .frame(maxWidth: 640, alignment: .leading).frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("companion.stream")
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: CompanionConversationViewport.self, value: proxy.frame(in: .global))
                }
            }
            .onPreferenceChange(CompanionConversationViewport.self) { value in
                guard scrolling.viewport != value else { return }
                let resized = scrolling.viewport.height > 0 && scrolling.viewport.size != value.size
                scrolling.updateViewport(value, isActive: isActive)
                // The execution channel follows real size changes only while
                // idle at latest; history and native gestures retain ownership.
                if resized { traceScroll("viewport-resized") }
            }
            .contentMargins(.horizontal, CompanionHomeStyle.inset, for: .scrollContent)
            .scrollDismissesKeyboard(.interactively)
            .modifier(CompanionInitialScrollAnchor())
            .modifier(CompanionReadingPositionObserver(legacyID: $legacyAnchorID, isActive: isActive,
                onVisibleIDs: observeVisibleIDs))
            .modifier(CompanionScrollInteractionObserver(isActive: isActive,
                onVisibility: observeNearLatest, action: observeInteraction))
            .onPreferenceChange(CompanionConversationBottom.self) { bottom in
                if #available(iOS 18.0, *) { return }
                guard isActive, scrolling.viewport.height > 0 else { return }
                let near = bottom <= scrolling.viewport.maxY + 24 && bottom >= scrolling.viewport.minY
                observeNearLatest(near)
            }
            .onChange(of: store.presentationRestoreToken) { _, _ in restoreReading() }
            .onChange(of: legacyAnchorID) { _, _ in
                if #unavailable(iOS 18.0) { saveReading() }
            }
            .onChange(of: projection.change) { old, new in
                if new.reset { restoreReading(); return }
                if new.contentRevision > old.contentRevision {
                    let userAction = new.userActionRevision > old.userActionRevision
                    if scrolling.contentArrived(isUserAction: userAction) {
                        requestLatest(force: userAction)
                    }
                } else if scrolling.intent.followsLatest && !scrolling.intent.isInteracting {
                    requestLatest()
                }
                saveReading()
            }
            .onChange(of: store.isWorking) { _, _ in
                if scrolling.intent.followsLatest && !scrolling.intent.isInteracting { requestLatest() }
            }
            .onChange(of: isActive) { _, active in if active { restoreReading() } }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in restoreAfterKeyboardLayout() }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification)) { _ in restoreAfterKeyboardLayout() }
            .modifier(CompanionScrollExecution(scrolling: scrolling,
                isActive: isActive, reduceMotion: reduceMotion, trace: traceScroll))
            .overlay(alignment: .bottom) {
                CompanionScrollLatestControl(scrolling: scrolling, isActive: isActive) {
                    scrolling.revealLatest()
                    requestLatest(force: true)
                    saveReading()
                }
            }
        }
    }

    private func saveReading(visibleAnchor: String? = nil) {
        // Scroll observation updates memory; tab/background transitions flush once.
        guard isActive else { return }
        let visible: String?
        if #available(iOS 18.0, *) { visible = visibleAnchor ?? store.readingState.anchorID }
        else { visible = legacyAnchorID }
        let anchor = scrolling.intent.anchorForSaving(visible: visible, saved: store.readingState.anchorID)
        guard scrolling.intent.followsLatest || anchor != "stream-bottom" else { return }
        store.noteReadingPosition(anchorID: anchor, followsLatest: scrolling.intent.followsLatest, hasUnread: scrolling.intent.hasUnread)
    }

    private func restoreReading() {
        legacyAnchorID = store.readingState.anchorID
        scrolling.restore(reading: store.readingState)
        traceScroll("restore-presentation")
    }

    private func restoreAfterKeyboardLayout() {
        guard isActive else { return }
        traceScroll("keyboard-completed")
        guard let target = scrolling.intent.keyboardRestorationTarget(reading: store.readingState) else { return }
        if scrolling.intent.followsLatest { requestLatest() }
        else {
            // The bound scroll position is also a command. Automatic layout
            // restoration must use the cancellable queue, then let the native
            // scroll view report its new visible ID.
            scrolling.enqueue(target: target, kind: .restoration)
        }
    }

    private func requestLatest(force: Bool = false) {
        guard isActive else { return }
        scrolling.enqueue(kind: force ? .explicit : .following)
        traceScroll(force ? "request-explicit" : "request-following")
    }

    private func observeInteraction(_ active: Bool) {
        guard isActive, scrolling.intent.isInteracting != active else { return }
        scrolling.setInteraction(active)
        traceScroll(active ? "phase-interacting" : "phase-idle")
        saveReading()
    }

    private func observeNearLatest(_ near: Bool) {
        guard isActive, near != scrolling.intent.nearLatest else { return }
        scrolling.setNearLatest(near)
        saveReading()
    }

    private func observeVisibleIDs(_ ids: [String]) {
        guard isActive else { return }
        let anchor = store.timelineProjection.readingAnchor(visibleIDs: ids, retaining: store.readingState.anchorID)
        guard anchor != store.readingState.anchorID else { return }
        saveReading(visibleAnchor: anchor)
        traceScroll("visible-anchor-observed")
    }

    // Debug-only, constant-size state diagnostics. Never record message text,
    // identities, travel data or the scroll anchor itself.
    private func traceScroll(_ event: String) {
        #if DEBUG
        Self.scrollLog.debug("event=\(event, privacy: .public) follows=\(scrolling.intent.followsLatest) interacting=\(scrolling.intent.isInteracting) near=\(scrolling.intent.nearLatest) unread=\(scrolling.intent.hasUnread) kind=\(String(describing: scrolling.request.kind), privacy: .public) revision=\(scrolling.request.revision) targetNil=\(scrolling.request.target == nil) checkpointNil=\(store.readingState.anchorID == nil) savedBottom=\(store.readingState.anchorID == "stream-bottom")")
        #endif
    }
    #if DEBUG
    private static let scrollLog = Logger(subsystem: "com.solocompass.chat-scroll", category: "intent")
    #endif

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 8) {
                CompanionCharacter(size: 76)
                Text(Date.now, format: .dateTime.month(.wide).day()).font(.subheadline)
            }.foregroundStyle(CompanionHomeStyle.secondaryInk)
            VStack(alignment: .leading, spacing: 14) {
                Text(companionText("companion.welcome.title", "我在。\n你慢慢来。"))
                    .font(.largeTitle.weight(.semibold))
                    .lineSpacing(5).fixedSize(horizontal: false, vertical: true)
                Text(companionText("companion.welcome.body", "想去哪里、还惦记着什么，\n都可以留在这里。"))
                    .font(.body).lineSpacing(5).foregroundStyle(CompanionHomeStyle.secondaryInk)
            }
            VStack(alignment: .leading, spacing: 0) {
                prompt(companionText("companion.example.care", "帮我照看暹粒这几天"), symbol: "sparkle")
                Divider().padding(.leading, 40)
                prompt(companionText("companion.example.coffee", "想找一家能安静坐会儿的咖啡馆"), symbol: "cup.and.saucer")
                Divider().padding(.leading, 40)
                prompt(companionText("companion.example.plan", "有几件事，想请你帮我理一理"), symbol: "text.badge.checkmark")
            }
            .padding(.horizontal, 14)
            .background(.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 22))
            Text(companionText("companion.welcome.hint", "点一句放进草稿，也可以直接说。"))
                .companionMetadata().foregroundStyle(CompanionHomeStyle.secondaryInk)
        }
        .foregroundStyle(CompanionHomeStyle.ink)
        .padding(.top, 32).padding(.bottom, 32)
    }

    private func prompt(_ value: String, symbol: String) -> some View {
        Button { store.composerDraft += (store.composerDraft.isEmpty ? "" : "\n\n") + value } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.body).frame(width: 24)
                Text(value).font(.subheadline).multilineTextAlignment(.leading)
                Spacer(minLength: 4)
                Image(systemName: "arrow.up.left").companionMetadata().foregroundStyle(.tertiary)
            }.padding(.vertical, 17).frame(minHeight: 52)
        }.buttonStyle(.plain)
    }
}

private struct CompanionConversationViewport: PreferenceKey {
    static let defaultValue = CGRect.zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

private struct CompanionConversationBottom: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}


@MainActor
private struct CompanionScrollLatestControl: View {
    let scrolling: CompanionScrollState
    let isActive: Bool
    let onLatest: () -> Void
    var body: some View {
        if isActive && scrolling.presentation.showsLatest {
            Button(action: onLatest) {
                Label(scrolling.presentation.hasUnread ? companionText("companion.new_content", "有新内容")
                    : companionText("companion.scroll.latest", "回到最新"), systemImage: "arrow.down")
                    .font(.subheadline.weight(.medium)).padding(.horizontal, 16).frame(minHeight: 44)
                    .background(.regularMaterial, in: Capsule())
            }.padding(.bottom, 8)
                .accessibilityIdentifier("companion.stream.latest")
        }
    }
}

@MainActor
private struct CompanionWorkingIndicator: View {
    let store: CompanionHomeStore
    let scrolling: CompanionScrollState
    let isActive: Bool
    var body: some View {
        HStack(spacing: 10) {
            CompanionCharacter(activity: isActive ? store.activity : .idle, viewport: scrolling.viewport)
            Text(progressText).font(.subheadline).foregroundStyle(CompanionHomeStyle.secondaryInk)
        }
    }
    private var progressText: String {
        switch store.workingProgress {
        case .thinking: return companionText("companion.progress.thinking", "正在整理回复…")
        case .tool(let name):
            switch name {
            case "search_places": return companionText("companion.progress.search", "正在查找地点…")
            case "manage_follow_up": return companionText("companion.progress.followup", "正在记录待办…")
            default: return companionText("companion.progress.sources", "正在核对资料…")
            }
        }
    }

}
