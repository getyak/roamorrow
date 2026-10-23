import SwiftUI

@MainActor
struct CompanionConversation: View {
    let store: CompanionHomeStore
    let isActive: Bool
    let onSources: (CompanionHomeEntry) -> Void
    let onPlace: (String) -> Void
    let onCommitments: () -> Void
    let onMedia: (CompanionMediaAttachment) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scrollTarget: String?
    @State private var unread = false
    @State private var viewport = CGRect.zero
    private var events: [CompanionTimeline.Event] {
        CompanionTimeline.events(entries: store.entries, invites: store.invites)
    }

    var body: some View {
        let events = self.events
        let replyContexts = CompanionTimeline.replyContexts(in: events)
        Group {
        if isActive {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
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
                    if events.isEmpty { introduction.id("stream-introduction") }
                    ForEach(events) { event in
                        Group {
                            switch event {
                            case .message(let entry):
                                if showsTimestamp(entry) {
                                    Text(entry.createdAt, format: .dateTime.month().day().hour().minute())
                                        .font(.footnote).foregroundStyle(CompanionHomeStyle.secondaryInk)
                                        .frame(maxWidth: .infinity).padding(.top, 14).padding(.bottom, 6)
                                }
                                CompanionMessageRow(entry: entry,
                                    replyContext: replyContexts[entry.id],
                                    onRetry: { Task { await store.retry(id: entry.id) } },
                                    onSources: { onSources(entry) },
                                    onPlace: { if let id = entry.placeID { onPlace(id) } },
                                    onMedia: onMedia, onQuote: { store.setDraftQuote($0) },
                                    onReaction: { store.toggleReaction(entryID: entry.id) })
                            case .invite(let invite):
                                CompanionInviteCard(invite: invite)
                            }
                        }.id(event.id)
                    }
                    if store.isWorking {
                        HStack(spacing: 10) {
                            CompanionCharacter(activity: store.activity, viewport: viewport)
                            Text(companionText("companion.character.working", "正在处理消息…"))
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
            .onPreferenceChange(CompanionConversationViewport.self) { viewport = $0 }
            .contentMargins(.horizontal, CompanionHomeStyle.inset, for: .scrollContent)
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(.bottom)
            .scrollPosition(id: $scrollTarget, anchor: .bottom)
        } else { Color.clear }
        }
            .onChange(of: scrollTarget) { _, target in
                if target == "stream-bottom" { unread = false }
            }
            .onChange(of: events.map(\.id)) { old, new in
                let added = Set(new).subtracting(old)
                guard !added.isEmpty else { return }
                if events.contains(where: { added.contains($0.id) && $0.isUserAction }) {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { scrollTarget = "stream-bottom" }
                    unread = false
                } else if scrollTarget != "stream-bottom" { unread = true }
            }
            .overlay(alignment: .bottom) {
                if unread && isActive {
                    Button {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { scrollTarget = "stream-bottom" }
                        unread = false
                    } label: {
                        Label(companionText("companion.new_content", "有新内容"), systemImage: "arrow.down")
                            .font(.subheadline.weight(.medium)).padding(.horizontal, 16).frame(minHeight: 44)
                            .background(.regularMaterial, in: Capsule())
                    }.padding(.bottom, 8)
                }
            }
    }

    private func showsTimestamp(_ entry: CompanionHomeEntry) -> Bool {
        guard let index = store.entries.firstIndex(where: { $0.id == entry.id }), index > 0 else { return true }
        let previous = store.entries[index - 1]
        return !Calendar.current.isDate(previous.createdAt, inSameDayAs: entry.createdAt)
            || entry.createdAt.timeIntervalSince(previous.createdAt) >= 300
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 8) {
                CompanionCharacter(size: 76)
                Text(Date.now, format: .dateTime.month(.wide).day()).font(.subheadline)
            }.foregroundStyle(CompanionHomeStyle.secondaryInk)
            VStack(alignment: .leading, spacing: 14) {
                Text(companionText("companion.welcome.title", "我在。\n你慢慢来。"))
                    .font(.system(.largeTitle, design: .serif))
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
