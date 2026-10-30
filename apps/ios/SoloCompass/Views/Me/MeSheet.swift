import SwiftUI

/// The personal hub: identity, travel archive, people, then preferences.
struct MeSheet: View {
    var pendingRequestCount: Int = 0
    var deepLinkConversationId: String? = nil
    var embedded = false
    var onOpenSettings: (() -> Void)? = nil
    var onExplore: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(UserPreferences.self) private var preferences
    @Environment(\.modelContext) private var modelContext
    @State private var showingSettings = false
    @State private var admin = AdminService.shared
    @State private var path: [MeDestination] = []
    @State private var handledInitialDestination = false

    private enum MeDestination: Hashable {
        case messages(deepLinkConversationId: String?)
        case friends, archive
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    NavigationLink {
                        MyProfileEditView()
                    } label: {
                        MeProfileHeader()
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("me.profile.edit")

                    MeTravelCounts(saved: preferences.favoritedExperiences.count,
                                   explored: preferences.completedExperiences.count)

                    archiveEntry

                    if preferences.favoritedExperiences.isEmpty {
                        emptyGuidance
                    }

                    peopleSection

                    MeHubSection(title: text("me.section.account")) {
                        EntitlementBanner()
                        separator
                        Button(action: openSettings) {
                            MeHubRow(symbol: "slider.horizontal.3", title: text("me.settings"),
                                     subtitle: text("me.settings.detail"))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("me.settings")
                    }

                    if admin.canModerate {
                        MeHubSection(title: text("me.admin.section")) {
                            NavigationLink {
                                ModerationView()
                            } label: {
                                MeHubRow(symbol: "shield.lefthalf.filled", title: text("me.moderation"),
                                         badge: admin.reports.filter { $0.resolvedAt == nil }.count)
                            }.buttonStyle(.plain)
                        }
                    }

                    Text("Roamorrow")
                        .font(.footnote).tracking(1.5)
                        .foregroundStyle(CompanionHomeStyle.secondaryInk)
                        .frame(maxWidth: .infinity).padding(.top, 2).padding(.bottom, 12)
                }
                .padding(.horizontal, 22).padding(.top, 18).padding(.bottom, 24)
                .frame(maxWidth: 640).frame(maxWidth: .infinity)
            }
            .background(CompanionHomeStyle.paper.ignoresSafeArea())
            .tint(CompanionHomeStyle.accent)
            .accessibilityIdentifier("me.hub")
            .navigationTitle(text("me.title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(CompanionHomeStyle.paper, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: openSettings) {
                        Image(systemName: "gearshape")
                            .font(.body).frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .accessibilityLabel(text("me.settings"))
                    .accessibilityIdentifier("me.settings.toolbar")
                    if !embedded {
                        Button(NSLocalizedString("common.done", comment: "Done")) { dismiss() }
                    }
                }
            }
            .task {
                await admin.refreshRole()
                if admin.canModerate { await admin.refreshReports() }
            }
            .navigationDestination(for: MeDestination.self) { destination in
                switch destination {
                case .messages(let conversationId):
                    ConversationListView(deepLinkConversationId: conversationId)
                case .friends:
                    FriendsHubView()
                case .archive:
                    ArchiveView(modelContainer: modelContext.container)
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(onClose: { showingSettings = false })
            }
            .onAppear {
                guard !handledInitialDestination else { return }
                handledInitialDestination = true
                if let conversationId = deepLinkConversationId, path.isEmpty {
                    path = [.messages(deepLinkConversationId: conversationId)]
                }
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-openFriends"), path.isEmpty {
                    path = [.friends]
                }
                if ProcessInfo.processInfo.arguments.contains("-openArchive"), path.isEmpty {
                    path = [.archive]
                }
                if ProcessInfo.processInfo.arguments.contains("-openSettings") { openSettings() }
                #endif
            }
            .onChange(of: deepLinkConversationId) { _, conversationId in
                if let conversationId { path = [.messages(deepLinkConversationId: conversationId)] }
            }
        }
    }

    private var archiveEntry: some View {
        NavigationLink(value: MeDestination.archive) {
            HStack(spacing: 18) {
                Image(systemName: "book.closed")
                    .font(.title2.weight(.light)).frame(width: 28).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(text("me.archive.title")).font(.title3.weight(.medium))
                    Text(text("me.archive.detail")).font(.subheadline)
                        .foregroundStyle(CompanionHomeStyle.secondaryInk)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "arrow.up.right").font(.body).accessibilityHidden(true)
            }
            .foregroundStyle(CompanionHomeStyle.ink)
            .padding(21).frame(minHeight: 96)
            .background(CompanionHomeStyle.outgoing.opacity(0.65),
                        in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("me.archive")
    }

    private var peopleSection: some View {
        MeHubSection(title: text("me.section.people")) {
            NavigationLink { FriendsHubView() } label: {
                MeHubRow(symbol: "person.2", title: text("me.friends"), badge: pendingRequestCount)
            }
            .buttonStyle(.plain).accessibilityIdentifier("me.friends")
            separator
            NavigationLink { ConversationListView() } label: {
                MeHubRow(symbol: "bubble.left.and.bubble.right", title: text("me.messages"))
            }
            .buttonStyle(.plain).accessibilityIdentifier("me.messages")
            separator
            NavigationLink { CompanionProfileView() } label: {
                MeHubRow(symbol: "figure.2.arms.open", title: text("me.companion"))
            }
            .buttonStyle(.plain).accessibilityIdentifier("me.companion")
        }
    }

    private var emptyGuidance: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text("me.empty.note"))
                .font(.subheadline).lineSpacing(3)
                .foregroundStyle(CompanionHomeStyle.secondaryInk)
            Button {
                if let onExplore { onExplore() } else { dismiss() }
            } label: {
                HStack(spacing: 7) {
                    Text(text("me.empty.explore"))
                    Image(systemName: "arrow.up.right").font(.caption.weight(.medium))
                }
                .font(.subheadline.weight(.medium)).frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain).foregroundStyle(CompanionHomeStyle.accent)
            .accessibilityIdentifier("me.explore")
        }
    }

    private var separator: some View {
        Rectangle().fill(CompanionHomeStyle.line).frame(height: 0.5).padding(.leading, 58)
    }

    private func openSettings() {
        if let onOpenSettings { onOpenSettings() } else { showingSettings = true }
    }

    private func text(_ key: String) -> String { NSLocalizedString(key, comment: "Personal hub") }
}

// MARK: - Map avatar bubble

/// US-007: the top-right entry point into `MeSheet`. Lives in the map's
/// safe-area overlay (never the status bar). Shows a red dot when there are
/// pending friend requests so the hub is discoverable at a glance.
struct MapAvatarBubble: View {
    let hasPendingRequests: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Text(CompanionProfile.sample.avatarEmoji)
                    .font(.system(size: 22))
                    .frame(width: 44, height: 44)
                    // Plain thin material, NOT glassSurface: this bubble floats over the
                    // raw map in the top overlay row, and glass surfaces are forbidden
                    // over the map (markers scroll under it → sunGold vibrancy fringe).
                    // Thin material was the goal (regular too heavy) without glass.
                    .background(.thinMaterial, in: Circle())
                    .elevation(.card)

                if hasPendingRequests {
                    Circle()
                        .fill(CT.savedRed)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .offset(x: 2, y: -2)
                }
            }
        }
        .accessibilityLabel(Text(NSLocalizedString("me.avatar.a11y", comment: "Open personal hub")))
        .accessibilityValue(
            hasPendingRequests
                ? Text(NSLocalizedString("me.avatar.a11y.pending", comment: "Pending friend requests"))
                : Text("")
        )
        .accessibilityIdentifier("mapAvatarBubble")
    }
}

#Preview("MeSheet") {
    MeSheet(pendingRequestCount: 2)
        .environment(UserPreferences())
        .environment(SubscriptionService())
}
