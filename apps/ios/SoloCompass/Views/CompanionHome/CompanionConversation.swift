import SwiftUI

@MainActor
struct CompanionConversation: View {
    let store: CompanionHomeStore
    let isActive: Bool
    let onSources: (CompanionHomeEntry) -> Void
    let onPlace: (CompanionHomeEntry, String?) -> Void
    let onCommitments: () -> Void
    let onMedia: (CompanionMediaAttachment) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scrollTarget: String?
    @State private var intent: CompanionScrollIntent
    @State private var scrollRequest = ScrollRequest()
    @State private var viewport = CGRect.zero
    private struct ScrollRequest {
        var revision = 0
        var target: String? = "stream-bottom"
        var animated = false
        var kind: CompanionScrollIntent.ScrollRequestKind = .following
    }

    init(store: CompanionHomeStore, isActive: Bool,
         onSources: @escaping (CompanionHomeEntry) -> Void,
         onPlace: @escaping (CompanionHomeEntry, String?) -> Void,
         onCommitments: @escaping () -> Void, onMedia: @escaping (CompanionMediaAttachment) -> Void) {
        self.store = store; self.isActive = isActive; self.onSources = onSources
        self.onPlace = onPlace; self.onCommitments = onCommitments; self.onMedia = onMedia
        _scrollTarget = State(initialValue: store.readingState.anchorID)
        _intent = State(initialValue: CompanionScrollIntent(reading: store.readingState))
    }

    var body: some View {
        let projection = store.timelineProjection
        return ScrollViewReader { scrollProxy in
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
                        HStack(spacing: 10) {
                            CompanionCharacter(activity: isActive ? store.activity : .idle, viewport: viewport)
                            Text(progressText)
                                .font(.subheadline).foregroundStyle(CompanionHomeStyle.secondaryInk)
                        }
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
                if viewport != value { viewport = value }
            }
            .contentMargins(.horizontal, CompanionHomeStyle.inset, for: .scrollContent)
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(.bottom)
            .scrollPosition(id: $scrollTarget, anchor: .bottom)
            .modifier(CompanionScrollInteractionObserver(isActive: isActive,
                onVisibility: observeNearLatest, action: observeInteraction))
            .onPreferenceChange(CompanionConversationBottom.self) { bottom in
                if #available(iOS 18.0, *) { return }
                guard isActive, viewport.height > 0 else { return }
                let near = bottom <= viewport.maxY + 24 && bottom >= viewport.minY
                observeNearLatest(near)
            }
            .onChange(of: store.presentationRestoreToken) { _, _ in restoreReading() }
            .onChange(of: scrollTarget) { _, target in
                saveReading()
            }
            .onChange(of: projection.change) { old, new in
                if new.reset { restoreReading(); return }
                if new.contentRevision > old.contentRevision {
                    let userAction = new.userActionRevision > old.userActionRevision
                    if intent.contentArrived(isUserAction: userAction) {
                        requestLatest(force: userAction)
                    }
                } else if intent.followsLatest && !intent.isInteracting {
                    requestLatest()
                }
                saveReading()
            }
            .onChange(of: store.isWorking) { _, _ in
                if intent.followsLatest && !intent.isInteracting { requestLatest() }
            }
            .onChange(of: isActive) { _, active in if active { restoreReading() } }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in restoreHistoryAfterLayout() }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification)) { _ in restoreHistoryAfterLayout() }
            .task(id: scrollRequest.revision) {
                let request = scrollRequest
                guard request.revision > 0 else { return }
                await Task.yield()
                guard !Task.isCancelled, isActive, let target = request.target,
                      intent.permitsScroll(request.kind) else { return }
                withAnimation(request.animated && !reduceMotion ? .easeOut(duration: 0.2) : nil) {
                    scrollProxy.scrollTo(target, anchor: .bottom)
                }
            }
            .overlay(alignment: .bottom) {
                if isActive && (intent.hasUnread || (!intent.followsLatest && !intent.nearLatest)) {
                    Button {
                        intent.revealLatest()
                        requestLatest(force: true)
                        saveReading()
                    } label: {
                        Label(intent.hasUnread ? companionText("companion.new_content", "有新内容")
                            : companionText("companion.scroll.latest", "回到最新"), systemImage: "arrow.down")
                            .font(.subheadline.weight(.medium)).padding(.horizontal, 16).frame(minHeight: 44)
                            .background(.regularMaterial, in: Capsule())
                    }.padding(.bottom, 8)
                        .accessibilityIdentifier("companion.stream.latest")
                }
            }
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

    private func saveReading() {
        // Scroll observation updates memory; tab/background transitions flush once.
        guard isActive else { return }
        let anchor = intent.anchorForSaving(visible: scrollTarget, saved: store.readingState.anchorID)
        guard intent.followsLatest || anchor != "stream-bottom" else { return }
        store.noteReadingPosition(anchorID: anchor, followsLatest: intent.followsLatest, hasUnread: intent.hasUnread)
    }

    private func restoreReading() {
        scrollTarget = store.readingState.anchorID
        intent = CompanionScrollIntent(reading: store.readingState)
        if let target = store.readingState.anchorID {
            // An unchanged binding ID does not re-position an existing native
            // scroll view after tab/keyboard layout. Replay the stable target.
            scrollRequest = ScrollRequest(revision: scrollRequest.revision + 1, target: target, kind: .restoration)
        }
    }

    private func restoreHistoryAfterLayout() {
        guard isActive, !intent.followsLatest, !intent.isInteracting else { return }
        restoreReading()
    }

    private func requestLatest(force: Bool = false) {
        guard isActive else { return }
        scrollRequest = ScrollRequest(revision: scrollRequest.revision + 1, kind: force ? .explicit : .following)
    }

    private func observeInteraction(_ active: Bool) {
        guard isActive, intent.isInteracting != active else { return }
        intent.interactionChanged(active: active)
        if active, scrollRequest.kind == .restoration, scrollRequest.target != nil {
            // Invalidate a queued restoration even if the gesture also finishes
            // before its task resumes. Explicit send/latest actions still win.
            scrollRequest = ScrollRequest(revision: scrollRequest.revision + 1, target: nil, kind: .restoration)
        }
        saveReading()
    }

    private func observeNearLatest(_ near: Bool) {
        guard isActive, near != intent.nearLatest else { return }
        intent.visibilityChanged(nearLatest: near)
        saveReading()
    }

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
