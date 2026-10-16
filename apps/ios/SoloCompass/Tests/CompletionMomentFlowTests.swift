import XCTest
@testable import SoloCompass

// MARK: - Scripted remote (serialized with the completion flow)

private enum ScriptedBehavior {
    case succeed
    case slowSucceed
    case stub      // NotImplementedError — server completion not implemented
    case fail      // real failure
}

private struct UnexpectedCompletionFailure: Error {}

@MainActor
private final class ScriptedCompletionRemote: RouteCompanionRemote {
    let behavior: ScriptedBehavior
    private(set) var markCompletedCalls: [RouteId] = []

    init(behavior: ScriptedBehavior) {
        self.behavior = behavior
    }

    func fetchRecruitingRoutes(cityCode: String) async throws -> [Route] {
        throw NotImplementedError("fetchRecruitingRoutes")
    }
    func sendJoinRequest(routeId: RouteId, message: String, pace: String) async throws {
        throw NotImplementedError("sendJoinRequest")
    }
    func fetchInbox() async throws -> [JoinRequest] {
        throw NotImplementedError("fetchInbox")
    }
    func accept(_ request: JoinRequest, route: Route) async throws {
        throw NotImplementedError("accept")
    }
    func decline(_ request: JoinRequest, route: Route) async throws {
        throw NotImplementedError("decline")
    }
    func withdraw(_ request: JoinRequest, route: Route) async throws {
        throw NotImplementedError("withdraw")
    }

    func markCompleted(routeId: RouteId) async throws {
        markCompletedCalls.append(routeId)
        switch behavior {
        case .succeed:
            return
        case .slowSucceed:
            try? await Task.sleep(for: .milliseconds(120))
            return
        case .stub:
            throw NotImplementedError("markCompleted")
        case .fail:
            throw UnexpectedCompletionFailure()
        }
    }
}

/// Completion-moment lifecycle (round 2 follow-up):
///   - replay of an already-completed route is strictly READ-ONLY;
///   - a closed route writes only after an explicit confirmation and only
///     celebrates after the durable acknowledgement;
///   - a stub/unavailable remote is a visible, retryable failure that claims
///     NOTHING as completed;
///   - viewing/replaying never starts a completion write.
///
/// The remote is a scripted in-process fake — no network, no external sends.
@MainActor
final class CompletionMomentFlowTests: XCTestCase {

    // MARK: - Helpers

    private let routeId = RouteId(rawValue: "route_completion")

    private func makeFlow(
        status: CompanionStatus?,
        behavior: ScriptedBehavior
    ) -> (CompletionMomentFlow, ScriptedCompletionRemote) {
        let remote = ScriptedCompletionRemote(behavior: behavior)
        let flow = CompletionMomentFlow(
            routeStatus: status,
            routeId: routeId,
            remoteProvider: { remote }
        )
        return (flow, remote)
    }

    // MARK: - Replay is strictly read-only

    func testReplayOfCompletedRouteStartsCelebratingWithoutWriting() async {
        let (flow, remote) = makeFlow(status: .completed, behavior: .succeed)

        XCTAssertTrue(flow.isReplay)
        XCTAssertEqual(flow.phase, .celebrating, "replay shows the moment immediately")
        XCTAssertTrue(remote.markCompletedCalls.isEmpty, "viewing/replaying must never write")

        // Even a forced confirm action must stay inert in replay mode.
        await flow.confirmCompletion()
        XCTAssertEqual(remote.markCompletedCalls.count, 0, "replay stays read-only")
        XCTAssertEqual(flow.phase, .celebrating)
    }

    // MARK: - Closed route: explicit confirm → ack → celebrate

    func testClosedRouteWritesOnlyAfterExplicitConfirmation() async {
        let (flow, remote) = makeFlow(status: .closed, behavior: .succeed)

        XCTAssertEqual(flow.phase, .awaitingConfirmation)
        XCTAssertTrue(remote.markCompletedCalls.isEmpty, "nothing runs by appearing")

        await flow.confirmCompletion()

        XCTAssertEqual(remote.markCompletedCalls, [routeId])
        XCTAssertEqual(flow.phase, .celebrating, "celebration only after the durable ack")
    }

    func testMissingCompanionStatusTakesTheSafeConfirmPath() async {
        let (flow, remote) = makeFlow(status: nil, behavior: .succeed)

        XCTAssertFalse(flow.isReplay)
        XCTAssertEqual(flow.phase, .awaitingConfirmation)
        XCTAssertTrue(remote.markCompletedCalls.isEmpty)
    }

    // MARK: - Failures claim nothing and stay retryable

    func testStubRemoteIsVisibleRetryFailureAndClaimsNothing() async {
        let (flow, remote) = makeFlow(status: .closed, behavior: .stub)

        await flow.confirmCompletion()

        XCTAssertEqual(flow.phase, .failed(.remoteUnavailable))
        XCTAssertNotEqual(flow.phase, .celebrating, "no local claim of remote completion")

        // Retry goes through the same honest path and can still fail visibly.
        await flow.confirmCompletion()
        XCTAssertEqual(remote.markCompletedCalls.count, 2)
        XCTAssertEqual(flow.phase, .failed(.remoteUnavailable))
    }

    func testRealFailureKeepsNothingClaimedAndOffersRetry() async {
        let (flow, _) = makeFlow(status: .closed, behavior: .fail)

        await flow.confirmCompletion()
        XCTAssertEqual(flow.phase, .failed(.saveFailed))

        flow.dismissFailure()
        XCTAssertEqual(flow.phase, .awaitingConfirmation, "failure can return to the explicit confirm step")
    }

    func testCompletedRouteNeverRewritesEvenThroughConfirm() async {
        let (flow, remote) = makeFlow(status: .completed, behavior: .succeed)

        await flow.confirmCompletion()
        XCTAssertEqual(flow.phase, .celebrating)

        // A completed route never re-writes, even through confirmCompletion
        // (replay is strictly read-only — root-fixed assertion, kept at 0).
        await flow.confirmCompletion()
        XCTAssertEqual(remote.markCompletedCalls.count, 0)
    }

    // MARK: - Duplicate in-flight guard

    func testConcurrentConfirmAttemptsFireExactlyOnce() async {
        let (flow, remote) = makeFlow(status: .closed, behavior: .slowSucceed)

        let first = Task { await flow.confirmCompletion() }
        try? await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(flow.phase, .committing, "the attempt is in flight")

        // A double-tap during committing must not start a second attempt.
        await flow.confirmCompletion()
        await first.value

        XCTAssertEqual(remote.markCompletedCalls.count, 1, "no duplicate completion writes")
        XCTAssertEqual(flow.phase, .celebrating)
    }
}
