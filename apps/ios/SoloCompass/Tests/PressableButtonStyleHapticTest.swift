import SwiftUI
import XCTest
@testable import SoloCompass

/// Behavioral guards for `PressableButtonStyle`'s press-feedback policy.
///
/// Two regressions motivated these tests:
///  1. the shared default press scale (`0.92`) visibly squashed every control
///     it touched — press feedback should be a subtle affordance;
///  2. the style fired a "release" haptic from `isPressed` falling, which also
///     happens on a *cancelled* press (finger dragged off the control) — the
///     user got a commit buzz for an action that never ran.
///
/// The style now owns scale-only feedback; commit haptics live in call-site
/// action closures where the outcome is known. These tests exercise the real
/// style values through `@testable` rather than scanning source strings.
final class PressableButtonStyleFeedbackTests: XCTestCase {

    /// The shared default must stay subtle: visibly responsive but never an
    /// exaggerated squeeze (the 0.92 regression) and not a no-op (≥0.99).
    func testDefaultPressedScaleIsSubtle() {
        let style = PressableButtonStyle()
        XCTAssertEqual(
            style.pressedScale,
            PressableButtonStyle.defaultPressedScale,
            "A default-constructed style must use the shared default scale"
        )
        XCTAssertGreaterThanOrEqual(style.pressedScale, 0.95,
                                    "Default press scale is too exaggerated — controls visibly squash")
        XCTAssertLessThan(style.pressedScale, 0.99,
                          "Default press scale is effectively a no-op — press feedback disappeared")
    }

    /// The initializer API is preserved: existing call sites that pass an
    /// explicit scale keep that exact scale.
    func testExplicitPressedScaleIsPreserved() {
        XCTAssertEqual(PressableButtonStyle(pressedScale: 0.9).pressedScale, 0.9)
        XCTAssertEqual(PressableButtonStyle(pressedScale: 0.985).pressedScale, 0.985)
    }

    /// The `haptic` parameter stays in the API for source compatibility with
    /// existing call sites, but the style must never claim commit feedback —
    /// `ButtonStyle` cannot tell a committed tap from a cancelled press.
    func testHapticParameterRemainsSourceCompatibleWithoutOwningCommitFeedback() {
        let legacyCallSite = PressableButtonStyle(haptic: true)
        let combinedCallSite = PressableButtonStyle(pressedScale: 0.96, haptic: true)
        XCTAssertTrue(legacyCallSite.haptic, "Legacy `haptic:` call sites must still compile and keep their value")
        XCTAssertTrue(combinedCallSite.haptic)
        XCTAssertFalse(PressableButtonStyle.providesCommitHaptics,
                       "The style must not own commit haptics: a cancelled press would buzz")
    }
}
