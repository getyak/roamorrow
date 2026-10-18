import XCTest
import SwiftUI
import UIKit
@testable import SoloCompass

@MainActor
final class AdaptiveActionContrastTests: XCTestCase {
    func testActionTextMeetsAAOnLightCard() {
        XCTAssertGreaterThanOrEqual(contrast(CT.actionTintAdaptive, CT.cardAdaptive, style: .light), 4.5)
    }

    func testActionTextMeetsAAOnDarkCardAndSheet() {
        XCTAssertGreaterThanOrEqual(contrast(CT.actionTintAdaptive, CT.cardAdaptive, style: .dark), 4.5)
        XCTAssertGreaterThanOrEqual(contrast(CT.actionTintAdaptive, CT.sheetAdaptive, style: .dark), 4.5)
    }

    func testFilledActionKeepsWhiteLabelContrast() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            XCTAssertGreaterThanOrEqual(contrast(.white, CT.accent, style: style), 4.5)
        }
    }

    private func contrast(_ foreground: Color, _ background: Color, style: UIUserInterfaceStyle) -> Double {
        let traits = UITraitCollection(userInterfaceStyle: style)
        func luminance(_ color: Color) -> Double {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            XCTAssertTrue(UIColor(color).resolvedColor(with: traits).getRed(&r, green: &g, blue: &b, alpha: &a))
            func linear(_ value: CGFloat) -> Double {
                let v = Double(value)
                return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
        }
        let a = luminance(foreground), b = luminance(background)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}
