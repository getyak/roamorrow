import XCTest
@testable import SoloCompass

final class CompanionTimelineTests: XCTestCase {
    func testLightweightRowIdentityResolvesOnlyItsFrozenProjection() {
        let date = Date(timeIntervalSince1970: 10)
        let message = CompanionHomeEntry(role: .companion, text: "original", createdAt: date)
        var draft = invite(at: date)
        draft.id = message.id
        let original = CompanionTimeline.Projection(entries: [message], invites: [draft])
        var changed = message
        changed.text = "updated"
        let later = CompanionHomeEntry(role: .user, text: "later", createdAt: date.addingTimeInterval(1))
        let updated = CompanionTimeline.Projection(entries: [changed, later], invites: [draft], previous: original, revision: 1)

        XCTAssertEqual(original.rowIDs, ["message:\(message.id)", "invite:\(message.id)"])
        XCTAssertEqual(Set(original.rowIDs).count, original.rowIDs.count)
        XCTAssertEqual(original.rowIDs.compactMap { original.event(forID: $0) }, original.events)
        XCTAssertEqual(updated.rowIDs.compactMap { updated.event(forID: $0) }, updated.events)
        XCTAssertEqual(original.event(forID: "message:\(message.id)"), .message(message))
        XCTAssertEqual(updated.event(forID: "message:\(message.id)"), .message(changed))
        XCTAssertEqual(original.event(forID: "invite:\(message.id)"), .invite(draft))
        XCTAssertNil(original.event(forID: "message:\(later.id)"))
        XCTAssertNil(updated.event(forID: "missing"))
        XCTAssertEqual(updated.readingAnchor(visibleIDs: original.rowIDs, retaining: original.rowIDs.first), original.rowIDs.first)
    }

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

    func testVisibleAnchorUsesCachedOrderAndPreservesHistoryWhenVisibilityIsTransient() {
        let first = CompanionHomeEntry(role: .user, text: "first", createdAt: Date(timeIntervalSince1970: 10))
        let tall = CompanionHomeEntry(role: .companion, text: String(repeating: "long message ", count: 5_000), createdAt: Date(timeIntervalSince1970: 20))
        let last = CompanionHomeEntry(role: .user, text: "last", createdAt: Date(timeIntervalSince1970: 30))
        var draft = invite(at: Date(timeIntervalSince1970: 25)); draft.id = first.id
        let projection = CompanionTimeline.Projection(entries: [last, first, tall], invites: [draft])
        let old = "message:\(first.id)", middle = "message:\(tall.id)", newest = "message:\(last.id)"
        XCTAssertEqual(projection.readingAnchor(visibleIDs: [middle, newest], retaining: nil), newest)
        XCTAssertEqual(projection.readingAnchor(visibleIDs: [newest, middle], retaining: nil), newest)
        XCTAssertEqual(projection.readingAnchor(visibleIDs: [newest, middle], retaining: middle), middle)
        XCTAssertEqual(projection.readingAnchor(visibleIDs: [middle], retaining: old), middle)
        XCTAssertEqual(projection.readingAnchor(visibleIDs: [old, "invite:\(draft.id)"], retaining: nil), "invite:\(draft.id)")
        XCTAssertEqual(projection.readingAnchor(visibleIDs: [], retaining: middle), middle)
        XCTAssertEqual(projection.readingAnchor(visibleIDs: ["unknown"], retaining: middle), middle)
        XCTAssertNil(projection.readingAnchor(visibleIDs: [], retaining: nil))
    }
}
