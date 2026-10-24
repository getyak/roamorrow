import SwiftUI
import XCTest
@testable import SoloCompass

@MainActor
final class SoloScoreBreakdownTests: XCTestCase {
    private func card(expanded: Binding<Bool> = .constant(false)) -> SoloScoreBreakdownCard {
        SoloScoreBreakdownCard(
            score: SoloScore(
                overall: 7.8,
                breakdown: .init(seatingFriendly: 9, soloPatronRatio: 3, staffPressure: 8,
                                 soloPortioning: 7, ambianceFit: 6, safety: 5),
                hint: "Quiet seating", basedOnCount: 22
            ),
            subtitle: "22 signals", isEstimate: false,
            isExpanded: expanded, barsAppeared: .constant(true)
        )
    }

    func testCollapsedCardShowsTheSameFirstThreeDimensions() {
        let view = card()
        XCTAssertEqual(view.displayedDimensions.map(\.value), [9, 8, 3])
        XCTAssertEqual(view.displayedDimensions.map(\.label), ["solo.seating", "solo.staff", "solo.patrons"].map {
            NSLocalizedString($0, comment: "")
        })
    }

    func testExpansionReadsTheDetailScreensBinding() {
        var expanded = false
        let view = card(expanded: Binding(get: { expanded }, set: { expanded = $0 }))
        XCTAssertEqual(view.displayedDimensions.count, 3)
        expanded = true
        XCTAssertEqual(view.displayedDimensions.count, 6)
        expanded = false
        XCTAssertEqual(view.displayedDimensions.count, 3)
    }

    func testEveryDimensionKeepsItsLocalizedVoiceOverNameAndValue() {
        let dimensions = card(expanded: .constant(true)).displayedDimensions
        XCTAssertEqual(dimensions.count, 6)
        for dimension in dimensions {
            XCTAssertFalse(dimension.label.isEmpty)
            XCTAssertTrue(dimension.accessibilityLabel.contains(dimension.label))
            XCTAssertTrue(dimension.accessibilityLabel.contains(String(format: "%.0f", dimension.clampedValue)))
        }
    }

    func testBarAndSpokenValuesUseTheSameClampedRange() {
        let negative = SoloScoreBreakdownCard.Dimension(label: "Low", value: -3)
        let excessive = SoloScoreBreakdownCard.Dimension(label: "High", value: 14)
        XCTAssertEqual(negative.clampedValue, 0)
        XCTAssertEqual(negative.accessibilityLabel, "Low 0")
        XCTAssertEqual(excessive.clampedValue, 10)
        XCTAssertEqual(excessive.accessibilityLabel, "High 10")
    }

    func testStrongestCalloutUsesTheActualHighestDimension() throws {
        let strongest = try XCTUnwrap(card().strongestDimension)
        XCTAssertEqual(strongest.label, NSLocalizedString("solo.seating", comment: ""))
        XCTAssertEqual(strongest.value, 9)
    }
}
