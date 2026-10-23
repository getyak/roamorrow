import XCTest
@testable import SoloCompass

final class CompanionTimelineTests: XCTestCase {
    private func invite(at time: Date?) -> CompanionHomeInvite {
        .init(placeID: "place", placeName: "本机地点", date: Date(timeIntervalSince1970: 9_999),
              createdAt: time, durationMinutes: 30, people: [], note: "")
    }

    func testInvitesUseCreationTimeRatherThanFutureMeetingTime() {
        let first = CompanionHomeEntry(role: .user, text: "先说的话", createdAt: Date(timeIntervalSince1970: 10))
        let last = CompanionHomeEntry(role: .companion, text: "后来的回应", createdAt: Date(timeIntervalSince1970: 30))
        let draft = invite(at: Date(timeIntervalSince1970: 20))
        let result = CompanionTimeline.events(entries: [first, last], invites: [draft])
        XCTAssertEqual(result.map(\.id), ["message:\(first.id)", "invite:\(draft.id)", "message:\(last.id)"])
    }

    func testLegacyInvitesHaveStablePositionWithoutInventedTimestamp() {
        let old = invite(at: nil)
        let message = CompanionHomeEntry(role: .user, text: "已有记录", createdAt: Date(timeIntervalSince1970: 10))
        let result = CompanionTimeline.events(entries: [message], invites: [old])
        XCTAssertEqual(result.first?.id, "invite:\(old.id)")
        XCTAssertNil(result.first?.createdAt)
        XCTAssertEqual(result, CompanionTimeline.events(entries: [message], invites: [old]))
    }

    func testRetryResponseUsesActualArrivalTimeAndKeepsOriginalAssociation() {
        let earlier = CompanionHomeEntry(role: .user, text: "旧问题", createdAt: Date(timeIntervalSince1970: 10))
        let later = CompanionHomeEntry(role: .user, text: "新问题", createdAt: Date(timeIntervalSince1970: 20))
        let retry = CompanionHomeEntry(role: .companion, text: "后来才到的回应", createdAt: Date(timeIntervalSince1970: 30), replyToID: earlier.id)
        let result = CompanionTimeline.events(entries: [earlier, retry, later], invites: [])
        XCTAssertEqual(result.map(\.id), ["message:\(earlier.id)", "message:\(later.id)", "message:\(retry.id)"])
        XCTAssertEqual(CompanionTimeline.replyContext(for: retry, in: result), earlier.text)
    }

    func testEqualTimestampsKeepMessageOrderAndSeparateIdentityNamespaces() {
        let date = Date(timeIntervalSince1970: 10)
        let first = CompanionHomeEntry(role: .user, text: "原话", createdAt: date)
        let second = CompanionHomeEntry(role: .companion, text: "回应", createdAt: date, replyToID: first.id)
        var draft = invite(at: date)
        draft.id = first.id
        let result = CompanionTimeline.events(entries: [first, second], invites: [draft])
        XCTAssertEqual(result.map(\.id), ["message:\(first.id)", "message:\(second.id)", "invite:\(first.id)"])
        XCTAssertNil(CompanionTimeline.replyContext(for: second, in: result))
    }
}
