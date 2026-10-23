import XCTest
@testable import SoloCompass

@MainActor
final class CompanionHomeAgentSourceTests: XCTestCase {
    func testLocalReferenceIncludesActualURLWithoutClaimingLiveLookup() {
        let label = CompanionHomeAgent.sourceLabel(kind: "本机参考", title: "本机地点 · 手工资料", url: "https://example.org/original")
        XCTAssertEqual(label, "本机参考 · 本机地点 · 手工资料\nhttps://example.org/original")
        XCTAssertFalse(label.contains("实时"))
    }

    func testSearchLabelRetainsActualReturnedLink() {
        XCTAssertEqual(CompanionHomeAgent.sourceLabel(kind: "本轮网页检索", title: "实际结果", url: "https://example.org/result"),
                       "本轮网页检索 · 实际结果\nhttps://example.org/result")
    }

    func testMissingAndUnsupportedLinksDoNotInventAnAddress() {
        for url in [nil, "file:///private/local", "javascript:alert(1)", "https:///", "not a URL"] {
            XCTAssertEqual(CompanionHomeAgent.sourceLabel(kind: "本机参考", title: "原有来源", url: url), "本机参考 · 原有来源")
        }
    }
}
