#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

final class MiniCropSessionTests: XCTestCase {
    private func session(ratio: String, count: Int = 1) -> MiniCropSession {
        MiniCropSession(ratio: ratio, imageSizes: Array(repeating: .init(width: 200, height: 100), count: count))
    }

    func testConfirmWithoutFrameRecordsNothing() {
        var s = session(ratio: "1:1")
        XCTAssertFalse(s.confirm())
        XCTAssertTrue(s.outcomes.isEmpty)
        XCTAssertFalse(s.isFinished)
    }

    func testPanThenConfirmProducesClampedSourceRect() {
        var s = session(ratio: "1:1")
        s.setFrame(width: 100, height: 100)
        s.applyGesture(scale: 1, x: 999, y: 0)
        XCTAssertEqual(s.offsetX, 50)
        XCTAssertTrue(s.confirm())
        XCTAssertEqual(s.outcomes, [.crop(.init(x: 0, y: 0, width: 100, height: 100))])
        XCTAssertTrue(s.isFinished)
    }

    func testUntouchedFreeCropKeepsOriginalButFixedRatioCrops() {
        var free = session(ratio: "free")
        free.setFrame(width: 200, height: 100)
        XCTAssertTrue(free.confirm())
        XCTAssertEqual(free.outcomes, [.original])
        var fixed = session(ratio: "1:1")
        fixed.setFrame(width: 100, height: 100)
        XCTAssertTrue(fixed.confirm())
        XCTAssertEqual(fixed.outcomes, [.crop(.init(x: 50, y: 0, width: 100, height: 100))])
    }

    func testBatchIteratesInOrderAndResetsTransformBetweenImages() {
        var s = session(ratio: "1:1", count: 2)
        s.setFrame(width: 100, height: 100)
        s.applyGesture(scale: 2, x: 0, y: 0)
        XCTAssertTrue(s.confirm())
        XCTAssertEqual(s.index, 1)
        XCTAssertEqual(s.scale, 1)
        XCTAssertFalse(s.isFinished)
        XCTAssertTrue(s.useOriginal())
        XCTAssertTrue(s.isFinished)
        XCTAssertEqual(s.outcomes.count, 2)
        XCTAssertEqual(s.outcomes[0], .crop(.init(x: 75, y: 25, width: 50, height: 50)))
        XCTAssertEqual(s.outcomes[1], .original)
        XCTAssertFalse(s.confirm(), "finished session accepts no more results")
    }

    func testGestureIsClampedToScaleRange() {
        var s = session(ratio: "1:1")
        s.setFrame(width: 100, height: 100)
        s.applyGesture(scale: 9, x: 0, y: 0)
        XCTAssertEqual(s.scale, 4)
        s.applyGesture(scale: 0.1, x: 0, y: 0)
        XCTAssertEqual(s.scale, 1)
    }
}
#endif
