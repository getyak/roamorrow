#if DEBUG
import XCTest
@testable import SoloCompass

final class CompanionHomeSearchContextObservationTests: XCTestCase {
    private func row(_ json: String) -> [[String: Any]] {
        [["role": "system", "content": "Selected map search area (read fresh for this turn):\n<selected_public_map_search_center>\(json)</selected_public_map_search_center>"]]
    }

    func testReadsOnlyNameFromActualSerializedFirstSystemIgnoringOldHistory() {
        var messages = row(#"{"name":"清迈","latitude":18.7883,"longitude":98.9853}"#)
        messages.append(["role": "assistant", "content": "你当前选中的是万象"])
        messages.append(["role": "user", "content": "现在呢？"])
        XCTAssertEqual(AIService.debugCompanionSearchCity(serializedMessages: messages), "清迈")
    }

    func testMissingOrMalformedSelectedAreaIsExplicitlyUnavailable() {
        XCTAssertEqual(AIService.debugCompanionSearchCity(serializedMessages: [["role": "system", "content": "Selected map search area (read fresh for this turn):\nNo selected area available"]]), "unavailable")
        for raw in ["not json", #"{"latitude":18.7883}"#, #"{"name":12}"#, #"{"name":"bad\nname"}"#] {
            XCTAssertEqual(AIService.debugCompanionSearchCity(serializedMessages: row(raw)), "unavailable")
        }
    }

    func testUnrelatedCallsHaveNoObservationAndLaterSystemCannotOverrideFirst() {
        XCTAssertNil(AIService.debugCompanionSearchCity(serializedMessages: []))
        var messages: [[String: Any]] = [["role": "system", "content": "Unrelated conversation"]]
        messages += row(#"{"name":"清迈"}"#)
        XCTAssertNil(AIService.debugCompanionSearchCity(serializedMessages: messages))
    }
}
#endif
