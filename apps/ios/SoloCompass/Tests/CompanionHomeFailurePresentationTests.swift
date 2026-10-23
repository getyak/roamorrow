import XCTest
@testable import SoloCompass

@MainActor
final class CompanionHomeFailurePresentationTests: XCTestCase {
    func testKnownFailuresHaveChineseNextStepsWithoutRawCodes() {
        let cases = [
            ("authentication_required", "登录"), ("quota_exceeded", "稍后"),
            ("network_error", "网络"), ("backend_disabled", "稍后"),
            ("access_denied", "权限"), ("request_failed", "重试"),
            ("not_saved", "保留"), ("invalid_query", "补充")
        ]
        for (code, nextStep) in cases {
            let presented = CompanionHomeAgent.userFacingResponse("web_search failed: \(code)")
            XCTAssertFalse(presented.contains(code))
            XCTAssertFalse(presented.contains("web_search"))
            XCTAssertTrue(presented.contains(nextStep))
            XCTAssertFalse(presented.contains("没有找到"))
            XCTAssertFalse(presented.contains("已核实"))
        }
        XCTAssertEqual(CompanionHomeAgent.userFacingResponse("可以先保留这个安排，出发前再确认。"), "可以先保留这个安排，出发前再确认。")
        XCTAssertEqual(CompanionHomeAgent.userFacingResponse("web_search 暂时没有完成。"), "网页查询 暂时没有完成。")
    }

    func testNewResponseIsReadableWhileUserWordsAndJournalKeepOriginalEvidence() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("failure-presentation-\(UUID())/v1.json")
        let store = CompanionHomeStore(url: url)
        let userWords = "原话中提到 authentication_required，请保留我的原话"
        await store.send(text: userWords)
        let entryID = try XCTUnwrap(store.entries.first?.id)
        let raw = #"{"success":false,"available":false,"errorCategory":"authentication_required"}"#
        var call = CompanionHomeToolCheckpoint(id: "search", name: "web_search", argumentsJSON: #"{"query":"地点"}"#)
        XCTAssertTrue(store.checkpointToolPlan(entryID: entryID, batch: .init(calls: [call])))
        call.resultJSON = raw
        XCTAssertTrue(store.checkpointToolResult(entryID: entryID, result: call))
        let agent = CompanionHomeAgent(aiService: AIService(useSharedCache: false), experienceService: ExperienceService(seed: []))
        agent.journalStore = store
        agent.messageSender = { _, _ in .init(content: "web_search: authentication_required", toolCalls: []) }
        store.configure(agent: agent)
        await store.retry(id: entryID)
        XCTAssertEqual(store.entries.first?.text, userWords)
        XCTAssertEqual(store.entries.count, 2)
        XCTAssertTrue(store.entries.last?.text.contains("登录") == true)
        XCTAssertFalse(store.entries.last?.text.contains("authentication_required") == true)
        XCTAssertEqual(store.toolJournal(for: entryID).first?.calls.first?.resultJSON, raw)
        let restarted = CompanionHomeStore(url: url)
        XCTAssertEqual(restarted.toolJournal(for: entryID).first?.calls.first?.resultJSON, raw)
        XCTAssertEqual(restarted.entries.first?.text, userWords)
    }
}
