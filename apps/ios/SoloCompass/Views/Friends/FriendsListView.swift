import SwiftUI

/// US-010: One screen showing the current user's friends and the pending
/// requests addressed to them.
///
/// Structure mirrors `RequestInboxView` / `MyRequestsListView`:
/// - A top "pending requests" section (incoming) with [Accept] / [Decline]
///   per row.
/// - The friends list below (an avatar strip + a tappable list) where tapping
///   a friend opens `FriendProfileView`.
/// - Dedicated empty-state copy for "no friends" and "no requests".
///
/// All relationship I/O defers to `FriendService` (the persistent relationship
/// layer); this view is purely presentational + dispatch.
public struct FriendsListView: View {
    @State private var service: FriendService
    @State private var errorMessage: String?
    /// US-013: presents the AddFriendSheet (my shareable code + QR).
    @State private var showAddFriend = false
    @State private var justConnectedId: String?
    @State private var friendToRemove: Friendship?
    /// In-flight remove guard — one delete at a time, no duplicate requests
    /// (contract 3).
    @State private var removingFriendId: FriendshipId?
    /// Friendship whose delete failed, retained for an explicit retry.
    @State private var failedRemoval: Friendship?

    /// When false, the on-appear `refresh()` is skipped. Production always uses
    /// the default (true); tests/previews pass false to render fixture-backed
    /// state that `refresh()` would otherwise clear.
    private let autoRefresh: Bool

    public init(service: FriendService = .shared, autoRefresh: Bool = true) {
        _service = State(initialValue: service)
        self.autoRefresh = autoRefresh
    }

    private var currentUserId: String {
        SupabaseClient.shared.currentSession?.userId ?? "local"
    }

    private var pendingCount: Int {
        service.incomingRequests.filter { $0.status == .pending }.count
    }

    public var body: some View {
        Group {
            if service.isLoading {
                ScrollView {
                    CompanionSkeletonList(rows: 5)
                }
            } else if let error = service.lastError {
                ScrollView {
                    errorView(message: error)
                        .frame(maxWidth: .infinity, minHeight: UIScreen.main.bounds.height * 0.7)
                }
                .refreshable { await service.refresh() }
            } else if service.friends.isEmpty && service.incomingRequests.isEmpty {
                ScrollView {
                    EmptyFriendsView(onAddFriend: { showAddFriend = true })
                        .frame(maxWidth: .infinity, minHeight: UIScreen.main.bounds.height * 0.7)
                }
                .refreshable { await service.refresh() }
            } else {
                friendsList
            }
        }
        .navigationTitle(NSLocalizedString("friends.list.title", comment: "Friends list nav title"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if pendingCount > 0 {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 4) {
                        Image(systemName: "bell.badge.fill")
                            .accessibilityHidden(true)
                        Text(String(format: NSLocalizedString("friends.list.pending.count", comment: "Pending request count pill"), pendingCount))
                            .contentTransition(.numericText())
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CT.warningText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(CT.warningSoft, in: Capsule())
                    .animation(.easeInOut, value: pendingCount)
                    .accessibilityLabel(String(format: NSLocalizedString("friends.list.pending.count.a11y", comment: "VoiceOver: pending requests count"), pendingCount))
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptics.impact(.light)
                    showAddFriend = true
                } label: {
                    Image(systemName: "person.badge.plus")
                }
                .accessibilityLabel(NSLocalizedString("friends.add.open.a11y", comment: "Show my friend code"))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await service.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel(NSLocalizedString("friends.list.refresh.a11y", comment: "Refresh friends"))
            }
        }
        .task {
            guard autoRefresh else { return }
            await service.refresh()
            // US-021: this is an appropriate, non-cold-start moment to ask for
            // push permission — the traveler has explicitly opened the friends
            // surface, so push (friend requests, meetup invites) has clear
            // context. The system prompt is only shown once; subsequent calls
            // re-register a possibly-rotated token without re-prompting.
            await PushTokenService.shared.requestAuthorizationAndRegister()
        }
        .sheet(isPresented: $showAddFriend) {
            AddFriendSheet(service: service)
        }
        .overlay(alignment: .bottom) {
            if let msg = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                    Text(msg)
                        .font(.subheadline)
                        .lineLimit(2)
                    if let failedRemoval {
                        Button(NSLocalizedString("friends.list.remove.retry", comment: "Retry removing a friend")) {
                            let friendship = failedRemoval
                            self.failedRemoval = nil
                            errorMessage = nil
                            Task { await removeFriend(friendship) }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CT.accent)
                        .frame(minHeight: HitTargetMetrics.minimum)
                    }
                }
                .foregroundStyle(CT.savedRed)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityLabel(msg)
            }
        }
        .animation(.easeInOut, value: errorMessage)
    }

    // MARK: - Friend removal (contract 3)

    /// Delete a friendship with durable-ack feedback: on failure the row
    /// stays, the error explains and offers a retry; the success haptic and
    /// VoiceOver announcement run only after the confirmed removal.
    private func removeFriend(_ friendship: Friendship) async {
        guard removingFriendId == nil else { return }
        removingFriendId = friendship.id
        defer { removingFriendId = nil }
        let result = await service.unfriend(friendship, block: false)
        switch result {
        case .success:
            failedRemoval = nil
            Haptics.notify(.success)
            #if canImport(UIKit)
            UIAccessibility.post(
                notification: .announcement,
                argument: String(format: NSLocalizedString("friends.removed.a11y", comment: "VoiceOver: removed a friend"), friendship.otherUserId(viewer: currentUserId))
            )
            #endif
        case .failure:
            failedRemoval = friendship
            errorMessage = String(
                format: NSLocalizedString("friends.list.remove.error", comment: "Shown when removing a friend fails"),
                friendship.otherUserId(viewer: currentUserId)
            )
            Haptics.notify(.error)
        }
    }

    // MARK: - Subviews

    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label(
                NSLocalizedString("friends.list.error.title", comment: "Friends load error title"),
                systemImage: "exclamationmark.triangle"
            )
        } description: {
            Text(message)
        } actions: {
            Button {
                Haptics.impact(.light)
                Task { await service.refresh() }
            } label: {
                Label(
                    NSLocalizedString("friends.list.error.retry", comment: "Retry button"),
                    systemImage: "arrow.clockwise"
                )
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var friendsList: some View {
        List {
            // Top section: incoming pending requests.
            if !service.incomingRequests.isEmpty {
                Section {
                    ForEach(service.incomingRequests) { request in
                        IncomingRequestRow(
                            request: request,
                            showConnected: justConnectedId == request.requesterId,
                            onAccept: { Task { await acceptRequest(request) } },
                            onDecline: { Task { await service.decline(request) } }
                        )
                    }
                } header: {
                    Text(NSLocalizedString("friends.list.requests.section", comment: "Pending requests section header"))
                }
            }

            // Friends section: avatar strip + list.
            Section {
                if service.friends.isEmpty {
                    Text(NSLocalizedString("friends.list.empty.friends", comment: "No friends yet inline copy"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                } else {
                    avatarStrip
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    ForEach(service.friends) { friendship in
                        let otherId = friendship.otherUserId(viewer: currentUserId)
                        NavigationLink {
                            FriendProfileContainer(
                                friendship: friendship,
                                profile: profileData(for: otherId),
                                service: service
                            )
                        } label: {
                            FriendRow(userId: otherId)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Haptics.impact(.light)
                                friendToRemove = friendship
                            } label: {
                                Label(
                                    NSLocalizedString("friends.list.row.remove", comment: "Swipe action to remove a friend"),
                                    systemImage: "person.badge.minus"
                                )
                            }
                        }
                    }
                    .confirmationDialog(
                        String(format: NSLocalizedString("friends.list.remove.confirm.title", comment: "Remove friend confirmation title — %@ is the friend's id"), friendToRemove.map { $0.otherUserId(viewer: currentUserId) } ?? ""),
                        isPresented: Binding(get: { friendToRemove != nil }, set: { if !$0 { friendToRemove = nil } }),
                        titleVisibility: .visible
                    ) {
                        Button(NSLocalizedString("friends.list.remove.confirm.action", comment: "Confirm remove friend button"), role: .destructive) {
                            guard let friendship = friendToRemove else { return }
                            friendToRemove = nil
                            Task { await removeFriend(friendship) }
                        }
                        Button(NSLocalizedString("action.cancel", comment: "Cancel"), role: .cancel) {
                            friendToRemove = nil
                        }
                    }
                }
            } header: {
                Text(NSLocalizedString("friends.list.friends.section", comment: "Friends section header"))
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await service.refresh() }
    }

    // MARK: - Avatar strip

    private var avatarStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(service.friends) { friendship in
                    let otherId = friendship.otherUserId(viewer: currentUserId)
                    NavigationLink {
                        FriendProfileContainer(
                            friendship: friendship,
                            profile: profileData(for: otherId),
                            service: service
                        )
                    } label: {
                        VStack(spacing: 4) {
                            Text(AvatarEmoji.emoji(for: otherId))
                                .font(.system(size: 32))
                                .frame(width: 56, height: 56)
                                .background(Circle().fill(CT.accent.opacity(0.12)))
                            Text(otherId)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .frame(maxWidth: 64)
                        }
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded { Haptics.selection() })
                }
            }
            .padding(.horizontal, 16)
        }
        .accessibilityLabel(NSLocalizedString("friends.list.strip.a11y", comment: "VoiceOver: friend avatar strip"))
    }

    // MARK: - Helpers

    /// Build a minimal read-only profile from a user id. Trust signals default
    /// to zero until a richer profile fetch lands; the handle falls back to the
    /// raw id so the row is never blank.
    private func profileData(for userId: String) -> FriendProfileData {
        FriendProfileData(
            userId: userId,
            displayHandle: userId,
            avatarEmoji: AvatarEmoji.emoji(for: userId),
            bio: "",
            languages: [],
            placesWalked: 0,
            routesJoined: 0,
            friendCount: 0
        )
    }

    private func acceptRequest(_ request: FriendRequest) async {
        let result = await service.accept(request)
        if case .failure(let err) = result {
            errorMessage = err.localizedDescription
            Haptics.notify(.error)
            Task {
                try? await Task.sleep(for: .seconds(3))
                errorMessage = nil
            }
        } else {
            Haptics.notify(.success)
            justConnectedId = request.requesterId
            #if canImport(UIKit)
            UIAccessibility.post(
                notification: .announcement,
                argument: String(format: NSLocalizedString("friends.connected.a11y", comment: "VoiceOver: connected with friend"), request.requesterId)
            )
            #endif
            Task {
                try? await Task.sleep(for: .seconds(1.6))
                justConnectedId = nil
            }
        }
    }
}

// MARK: - FriendProfileContainer

/// Wraps the pure, value-driven `FriendProfileView` with the `Friendship` + the
/// `FriendService` so the [Message] action can lazily open (or create) the
/// persistent `friendDirect` conversation and push the shared `ChatView` (US-012).
///
/// Keeping this container separate preserves `FriendProfileView`'s previewability
/// — that view stays a plain function of `FriendProfileData` + relation + callbacks.
private struct FriendProfileContainer: View {
    let friendship: Friendship
    let profile: FriendProfileData
    let service: FriendService

    @State private var conversation: Conversation?
    @State private var isOpening = false
    @State private var errorMessage: String?
    /// Presents the local, user-controlled invitation-draft composer
    /// (round 2 follow-up) — no synthetic companion post, no invented FK.
    @State private var showInvite = false
    /// Draft to prefill in ChatView once the invite handoff conversation is
    /// pushed. Consumed on first appear so later [Message] opens stay empty.
    @State private var pendingInvitationDraft: String?
    /// Conversation held until the composer sheet is fully dismissed.
    @State private var pendingInvitationConversation: Conversation?
    /// Open failure shown INSIDE the composer — its draft is retained.
    @State private var inviteOpenError: String?

    private var currentUserId: String? {
        SupabaseClient.shared.currentSession?.userId
    }

    private var otherUserId: String {
        friendship.otherUserId(viewer: currentUserId ?? "local")
    }

    var body: some View {
        FriendProfileView(
            profile: profile,
            relation: .accepted,
            onMessage: { Task { await openConversation() } },
            // Round 2 follow-up: the invite action opens the LOCAL draft
            // composer; the reviewed text is prefilled in the existing
            // friendDirect chat and the user sends it themselves.
            onInvite: {
                inviteOpenError = nil
                showInvite = true
            }
        )
        .sheet(isPresented: $showInvite, onDismiss: {
            // Push the chat only after the composer is fully gone — never
            // stack presentation on a dismissing sheet.
            if let conv = pendingInvitationConversation {
                pendingInvitationConversation = nil
                conversation = conv
            }
        }) {
            FriendInviteDraftComposer(
                friendLabel: otherUserId,
                isOpening: isOpening,
                openError: inviteOpenError,
                onOpenDraft: { draft in Task { await openConversationWithDraft(draft) } },
                onCancel: {
                    inviteOpenError = nil
                    showInvite = false
                }
            )
        }
        .overlay(alignment: .center) {
            if isOpening {
                ProgressView()
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .navigationDestination(item: $conversation) { conv in
            ChatView(
                conversation: conv,
                currentUserId: currentUserId,
                // Friend-invite handoff: a user-REVIEWED draft prefilled in the
                // composer. The traveler sends it themselves — no auto-send.
                initialDraft: pendingInvitationDraft,
                // friendDirect: blocking from the Report/Block menu also unfriends.
                onBlocked: {
                    Task { await service.unfriend(friendship, block: false) }
                }
            )
            .onAppear { pendingInvitationDraft = nil }
        }
        .alert(
            NSLocalizedString("friends.list.error.title", comment: "Friends error title"),
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button(NSLocalizedString("action.ok", comment: "OK")) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func openConversation() async {
        guard !isOpening else { return }
        isOpening = true
        defer { isOpening = false }
        let result = await service.openDirectConversation(with: friendship)
        switch result {
        case .success(let conv):
            conversation = conv
        case .failure(let err):
            errorMessage = err.localizedDescription
            Haptics.notify(.error)
        }
    }

    /// Open the existing authenticated friendDirect conversation with the
    /// user-reviewed invitation draft prefilled (round 2 follow-up).
    ///
    /// Honest replacement for the old `sendInvite`, which synthesized a
    /// `friend-invite:<userId>` companion-post id — a fake foreign key the
    /// real `companion_requests.post_id` cannot satisfy — and reported success
    /// for a request that never existed. Here NOTHING is sent automatically
    /// and no post/row is created: the traveler sends the message themselves
    /// from chat. On failure the composer keeps the draft for retry.
    private func openConversationWithDraft(_ draft: String) async {
        guard !isOpening else { return }
        isOpening = true
        inviteOpenError = nil
        defer { isOpening = false }
        let result = await service.openDirectConversation(with: friendship)
        switch result {
        case .success(let conv):
            pendingInvitationDraft = draft
            pendingInvitationConversation = conv
            showInvite = false
        case .failure(let err):
            // Draft retained in the open composer; nothing sent, nothing
            // claimed. The error explains so the user can retry.
            inviteOpenError = err.localizedDescription
            Haptics.notify(.error)
        }
    }
}

// MARK: - FriendInviteDraftComposer

/// Local, user-controlled friend-invitation composer (round 2 follow-up).
///
/// The traveler reviews/edits the draft here, then the explicit
/// "Open invitation draft" action opens the existing authenticated friendDirect
/// chat with the text prefilled — the user sends it from chat. No auto-send, no
/// companion post, no invented foreign key. A failed open keeps the sheet and
/// its draft exactly as edited, with the error visible for retry.
private struct FriendInviteDraftComposer: View {
    let friendLabel: String
    let isOpening: Bool
    let openError: String?
    let onOpenDraft: (String) -> Void
    let onCancel: () -> Void

    @State private var draft: String
    @FocusState private var draftFocused: Bool

    init(
        friendLabel: String,
        isOpening: Bool,
        openError: String?,
        onOpenDraft: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.friendLabel = friendLabel
        self.isOpening = isOpening
        self.openError = openError
        self.onOpenDraft = onOpenDraft
        self.onCancel = onCancel
        _draft = State(initialValue: NSLocalizedString(
            "friends.invite.draft.default",
            comment: "Default invitation draft the traveler can edit before opening it in chat"
        ))
    }

    private var trimmed: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $draft)
                        .disabled(isOpening)
                        .frame(minHeight: 110)
                        .focused($draftFocused)
                        .accessibilityLabel(Text(NSLocalizedString(
                            "friends.invite.composer.title",
                            comment: "Invitation draft editor"
                        )))
                } header: {
                    Text(String(
                        format: NSLocalizedString("friends.invite.composer.header", comment: "Invitation draft for %@"),
                        friendLabel
                    ))
                } footer: {
                    Text(NSLocalizedString(
                        "friends.invite.composer.hint",
                        comment: "Nothing is sent until the traveler sends it from chat"
                    ))
                    .fixedSize(horizontal: false, vertical: true)
                }

                if let openError {
                    Section {
                        Label(openError, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(CT.sunGoldDeep)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Section {
                    Button {
                        onOpenDraft(trimmed)
                    } label: {
                        HStack {
                            Spacer()
                            if isOpening {
                                ProgressView()
                            } else {
                                Text(NSLocalizedString(
                                    "friends.invite.open",
                                    comment: "Open the reviewed invitation draft in chat (sends nothing)"
                                ))
                                .font(.subheadline.weight(.semibold))
                            }
                            Spacer()
                        }
                        .frame(minHeight: HitTargetMetrics.minimum)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isOpening || trimmed.isEmpty)
                    .accessibilityLabel(Text(NSLocalizedString(
                        "friends.invite.open",
                        comment: "Open the reviewed invitation draft in chat (sends nothing)"
                    )))
                    .accessibilityHint(Text(NSLocalizedString(
                        "friends.invite.composer.hint",
                        comment: "Nothing is sent until the traveler sends it from chat"
                    )))
                }
            }
            .navigationTitle(NSLocalizedString(
                "friends.invite.composer.title",
                comment: "Invitation draft"
            ))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("action.cancel", comment: "Cancel"), action: onCancel)
                        .disabled(isOpening)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        // The draft is the traveler's text — never discard it on a stray swipe.
        .interactiveDismissDisabled(true)
    }
}

// MARK: - AvatarEmoji (stable per-user emoji)

/// Deterministic emoji for a user id so the same friend always renders the same
/// avatar without a stored profile. Purely cosmetic.
enum AvatarEmoji {
    static let pool = ["🧭", "🌿", "🏔️", "🌊", "🦊", "🐢", "🦉", "🐬", "🌅", "🍃"]

    /// FNV-1a 64-bit hash — deterministic across process launches, unlike String.hashValue.
    static func stableHash(_ s: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in s.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }

    static func emoji(for userId: String) -> String {
        let idx = Int(stableHash(userId) % UInt64(pool.count))
        return pool[idx]
    }
}

// MARK: - IncomingRequestRow

private struct ConnectedBadge: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(CT.verifiedGreen)
            Text(NSLocalizedString("friends.connected.label", comment: "Connected badge label"))
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: Capsule())
        .scaleEffect(reduceMotion ? 1.0 : (visible ? 1.0 : 0.6))
        .opacity(visible ? 1.0 : 0.0)
        .animation(
            reduceMotion
                ? .easeInOut(duration: 0.25)
                : .spring(response: 0.35, dampingFraction: 0.6),
            value: visible
        )
        .onAppear { visible = true }
    }
}

private struct IncomingRequestRow: View {
    let request: FriendRequest
    var showConnected: Bool = false
    let onAccept: () -> Void
    let onDecline: () -> Void

    private static let isoFormatter = ISO8601DateFormatter()
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private var relative: String {
        guard let date = Self.isoFormatter.date(from: request.createdAt) else { return request.createdAt }
        return Self.relativeFormatter.localizedString(for: date, relativeTo: .now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(AvatarEmoji.emoji(for: request.requesterId))
                    .font(.system(size: 24))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(CT.accent.opacity(0.12)))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("friends.list.request.from", comment: "Request from label"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(request.requesterId)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                }
                Spacer()
                Text(relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if let note = request.note, !note.isEmpty {
                Text(note)
                    .font(.body)
                    .lineLimit(4)
                    .padding(.horizontal, 4)
            }

            HStack(spacing: 12) {
                Button(role: .destructive) {
                    onDecline()
                } label: {
                    Text(NSLocalizedString("friends.request.decline", comment: "Decline button"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    onAccept()
                } label: {
                    Text(NSLocalizedString("friends.request.accept", comment: "Accept button"))
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 4)
        .overlay(alignment: .center) {
            if showConnected {
                ConnectedBadge()
            }
        }
        .animation(.easeInOut, value: showConnected)
    }
}

// MARK: - FriendRow

private struct FriendRow: View {
    let userId: String

    var body: some View {
        HStack(spacing: 12) {
            Text(AvatarEmoji.emoji(for: userId))
                .font(.system(size: 22))
                .frame(width: 36, height: 36)
                .background(Circle().fill(CT.accent.opacity(0.12)))
                .accessibilityHidden(true)
            Text(userId)
                .font(.body)
                .lineLimit(1)
            Spacer()
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("friends.list.friend.a11y", comment: "VoiceOver: friend row"), userId))
    }
}

// MARK: - EmptyFriendsView

private struct EmptyFriendsView: View {
    var onAddFriend: (() -> Void)? = nil

    var body: some View {
        SoloEmptyState(
            systemImage: "person.2",
            title: NSLocalizedString("friends.list.empty.title", comment: "Empty friends title"),
            message: NSLocalizedString("friends.list.empty.description", comment: "Empty friends description"),
            actionTitle: onAddFriend == nil
                ? nil
                : NSLocalizedString("friends.list.empty.cta", comment: "Add a friend button in empty friends state"),
            action: onAddFriend.map { add in
                {
                    Haptics.selection()
                    add()
                }
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview("With friends + requests") {
    let service = FriendService()
    service.incomingRequests = [
        FriendRequest(
            id: FriendRequestId(rawValue: "freq_01"),
            requesterId: "traveler_abc",
            recipientId: "local",
            status: .pending,
            source: .companionChat,
            note: "We crossed paths in Tokyo — let's stay in touch!",
            expiresAt: "2026-07-01T10:00:00Z",
            createdAt: "2026-06-01T10:00:00Z",
            updatedAt: "2026-06-01T10:00:00Z"
        ),
    ]
    service.friends = [
        Friendship(
            id: FriendshipId(rawValue: "fnd_01"),
            userLowId: "local",
            userHighId: "maya",
            initiatedBy: "local",
            conversationId: nil,
            acceptedAt: "2026-05-01T10:00:00Z",
            createdAt: "2026-05-01T10:00:00Z",
            updatedAt: "2026-05-01T10:00:00Z"
        ),
        Friendship(
            id: FriendshipId(rawValue: "fnd_02"),
            userLowId: "kenji",
            userHighId: "local",
            initiatedBy: "kenji",
            conversationId: nil,
            acceptedAt: "2026-05-02T10:00:00Z",
            createdAt: "2026-05-02T10:00:00Z",
            updatedAt: "2026-05-02T10:00:00Z"
        ),
    ]
    return NavigationStack {
        FriendsListView(service: service)
    }
}

#Preview("Empty") {
    let service = FriendService()
    service.friends = []
    service.incomingRequests = []
    return NavigationStack {
        FriendsListView(service: service)
    }
}

#Preview("Error") {
    let service = FriendService()
    service.friends = []
    service.incomingRequests = []
    service.lastError = NSLocalizedString("friends.list.error.preview", comment: "Preview error message")
    return NavigationStack {
        FriendsListView(service: service, autoRefresh: false)
    }
}
