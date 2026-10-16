import XCTest
@testable import SoloCompass

/// Group-chat gating for closed/completed routes (contract item 1 / R2-02):
/// the chat action is only enabled when a conversation actually exists AND the
/// viewer is authorized; the completion replay is separately named and
/// host-only. No enabled dead actions, no celebration under the chat label.
@MainActor
final class RouteChatAccessTests: XCTestCase {

    private func companion(
        hostId: String = "host",
        members: [String] = ["host", "member"],
        status: CompanionStatus = .closed,
        groupConversationId: String? = "conv_1"
    ) -> RouteCompanion {
        RouteCompanion(
            status: status,
            hostId: hostId,
            departureWindow: DepartureWindow(startDate: "2026-04-01", to: "2026-04-02", time: "09:00"),
            departureLabel: "2026-04-01 09:00",
            maxMembers: 4,
            confirmedMembers: members,
            groupConversationId: groupConversationId
        )
    }

    private func conversation(participants: [String]) -> Conversation {
        Conversation(
            id: ConversationId(rawValue: "conv_1"),
            participantIds: participants,
            type: .groupRoute,
            routeId: "route_1",
            createdAt: "2026-01-01T00:00:00Z",
            updatedAt: "2026-01-01T00:00:00Z"
        )
    }

    // MARK: - Chat availability

    func testParticipantGetsAvailableConversation() {
        let access = RouteChatAccess.decide(
            companion: companion(),
            conversation: conversation(participants: ["host", "someone"]),
            viewerId: "host"
        )
        guard case .available(let conv) = access else {
            return XCTFail("host is a participant — chat must be available")
        }
        XCTAssertEqual(conv.id.rawValue, "conv_1")
    }

    func testConfirmedMemberNotYetInParticipantsIsAuthorized() {
        let access = RouteChatAccess.decide(
            companion: companion(members: ["host", "member"]),
            conversation: conversation(participants: ["host"]),
            viewerId: "member"
        )
        guard case .available = access else {
            return XCTFail("a confirmed member of the group is authorized")
        }
    }

    func testStrangerIsNotAuthorized() {
        let access = RouteChatAccess.decide(
            companion: companion(),
            conversation: conversation(participants: ["host", "member"]),
            viewerId: "stranger"
        )
        XCTAssertEqual(access, .notAuthorized)
    }

    func testMissingConversationIsUnavailableNotDeadChat() {
        let access = RouteChatAccess.decide(
            companion: companion(groupConversationId: nil),
            conversation: nil,
            viewerId: "host"
        )
        XCTAssertEqual(access, .noConversation)

        // Even with a groupConversationId set, a missing stored conversation
        // means the chat can't open — never an enabled dead action.
        let dangling = RouteChatAccess.decide(
            companion: companion(groupConversationId: "conv_missing"),
            conversation: nil,
            viewerId: "host"
        )
        XCTAssertEqual(dangling, .noConversation)
    }

    // MARK: - Completion replay naming (separate from chat)

    func testCompletionReplayIsHostOnlyAndOnlyForCompletedRoutes() {
        XCTAssertTrue(RouteCompletionReplay.isReplayVisible(status: .completed, viewerIsHost: true))
        XCTAssertFalse(
            RouteCompletionReplay.isReplayVisible(status: .completed, viewerIsHost: false),
            "a non-host must not get the completion replay"
        )
        XCTAssertFalse(
            RouteCompletionReplay.isReplayVisible(status: .closed, viewerIsHost: true),
            "a merely closed route is the 'Mark done' case, not a replay"
        )
        XCTAssertFalse(RouteCompletionReplay.isReplayVisible(status: .open, viewerIsHost: true))
    }
}
