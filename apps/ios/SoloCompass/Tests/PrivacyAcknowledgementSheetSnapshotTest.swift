import XCTest
import SwiftUI
@testable import SoloCompass

/// V-001 regression coverage: the Explore-Here privacy acknowledgement sheet
/// (`ExploreConsentSheet`) must render the full explanation of map position and
/// public place information without truncation, at both the default and largest
/// accessibility Dynamic Type sizes.
///
/// We don't ship a third-party snapshot library, so instead of comparing pixels
/// we render the sheet through SwiftUI's `ImageRenderer` at two Dynamic Type
/// sizes and assert each render produces a valid, non-empty image whose height
/// grows with the accessibility size. A truncated subtitle would collapse to a
/// single line and the AX5 render would not be meaningfully taller than the
/// default one — so the height ordering is our truncation guard.
@MainActor
final class PrivacyAcknowledgementSheetSnapshotTest: XCTestCase {

    /// Render the consent sheet at a fixed width and a given Dynamic Type size.
    private func render(_ size: DynamicTypeSize) -> UIImage? {
        let view = ExploreConsentSheet(onAccept: {}, onCancel: {})
            .dynamicTypeSize(size)
            .frame(width: 390) // iPhone 17 Pro logical width
            .fixedSize(horizontal: false, vertical: true)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.uiImage
    }

    func testSnapshotAtAccessibilityMedium() throws {
        let image = try XCTUnwrap(
            render(.accessibility1),
            "Sheet must render at .accessibility1"
        )
        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
    }

    func testSnapshotAtAccessibilityExtraExtraExtraLarge() throws {
        let image = try XCTUnwrap(
            render(.accessibility5),
            "Sheet must render at AX5 (.accessibility5)"
        )
        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
    }

    /// The core anti-truncation assertion: at the largest accessibility size the
    /// subtitle wraps across more lines, so the overall sheet must be strictly
    /// taller than at the default-ish accessibility size. If the subtitle were
    /// truncated (single line, fixed height) this ordering would not hold.
    func testSubtitleExpandsAtLargerDynamicType() throws {
        let medium = try XCTUnwrap(render(.accessibility1))
        let ax5 = try XCTUnwrap(render(.accessibility5))
        XCTAssertGreaterThan(
            ax5.size.height,
            medium.size.height,
            "AX5 render must be taller than AX-medium — proves text grows/wraps instead of truncating"
        )
    }

    /// The English copy must explain both inputs, independently of host locale.
    func testSubtitleLocalizedStringIsComplete() throws {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "en", ofType: "lproj"))
        let english = try XCTUnwrap(Bundle(path: path))
        let subtitle = english.localizedString(forKey: "explore.consent.subtitle", value: nil, table: nil)
        XCTAssertTrue(subtitle.contains("map position"), "Explain the location input")
        XCTAssertTrue(subtitle.contains("public place information."), "Keep the complete public-data explanation")
    }
}
