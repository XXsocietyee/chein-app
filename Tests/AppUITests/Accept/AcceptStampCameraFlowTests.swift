import XCTest

/// Stamp camera. Design fixture `e2-stamp-camera`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptStampCameraFlowTests: XCTestCase {
    func testStampCameraFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "e2-stamp-camera", markers: ["nativeR2.stamp.capture", "media.stamp.capture", "media.stamp.cameraDenied"], en: "Stamp camera", zh: "集邮相机")
    }
}
