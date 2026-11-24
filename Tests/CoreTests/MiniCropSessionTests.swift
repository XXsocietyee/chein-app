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

    func testCropPageWaitingAndEmptyDoNotInventAZeroCount() {
        let dash = CropPageModel.unknownDisplay
        let waiting = CropPageModel.facts(hasOpener: true, paths: nil)
        XCTAssertEqual(waiting.phase, .loading)
        XCTAssertEqual(waiting.countText, dash)
        XCTAssertEqual(waiting.widthText, dash)
        XCTAssertEqual(waiting.progressText, dash)
        XCTAssertFalse(waiting.canConfirm)
        XCTAssertFalse(waiting.uploadEnabled)
        XCTAssertEqual(waiting.copyKey, CropPageModel.Copy.loading)

        let noOpener = CropPageModel.facts(hasOpener: false, paths: ["a", "b"])
        XCTAssertEqual(noOpener.phase, .empty)
        XCTAssertEqual(noOpener.countText, "0")
        XCTAssertEqual(noOpener.copyKey, CropPageModel.Copy.empty)

        let emptyQueue = CropPageModel.facts(hasOpener: true, paths: [])
        XCTAssertEqual(emptyQueue.phase, .empty)
        XCTAssertEqual(emptyQueue.countText, "0")
        XCTAssertEqual(emptyQueue.progressText, "")
        XCTAssertFalse(emptyQueue.canUseOriginal)
    }

    func testCropPageUnknownStaysAnEmDashAndALiteralZeroStaysZero() {
        let dash = CropPageModel.unknownDisplay
        XCTAssertEqual(CropPageModel.countText(nil), dash)
        XCTAssertEqual(CropPageModel.countText(0), "0")
        XCTAssertEqual(CropPageModel.countText(numericString: "0"), dash)
        XCTAssertEqual(CropPageModel.countText(numericString: "2"), dash)
        XCTAssertEqual(CropPageModel.dimensionText(nil), dash)
        XCTAssertEqual(CropPageModel.dimensionText(0), "0")
        XCTAssertEqual(CropPageModel.dimensionText(200), "200")
        XCTAssertEqual(CropPageModel.dimensionText(Double.nan), dash)
        XCTAssertEqual(CropPageModel.dimensionText(numericString: "0"), dash)
        XCTAssertEqual(CropPageModel.progressText(index: nil, count: nil), dash)
        XCTAssertEqual(CropPageModel.progressText(index: nil, count: 2), dash)
        XCTAssertEqual(CropPageModel.progressText(index: 0, count: 2), "1/2")
        XCTAssertNotEqual(CropPageModel.progressText(index: 0, count: 2), "0/2")

        let unknown = CropPageModel.facts(hasOpener: true, paths: ["a"], ratio: "UNKNOWN",
                                          width: 200, height: 100, index: 0, source: "ready")
        XCTAssertEqual(unknown.phase, .unknown)
        XCTAssertEqual(unknown.ratioText, dash)
        XCTAssertEqual(unknown.copyKey, CropPageModel.Copy.unknown)
        XCTAssertFalse(unknown.canConfirm)
        XCTAssertNil(MiniCropGeometry.ratio("UNKNOWN"))
        XCTAssertTrue(MiniCropGeometry.keepsOriginal(ratio: "UNKNOWN", scale: 1, x: 0, y: 0))

        let token = CropPageModel.facts(hasOpener: true, paths: ["a"], width: 200, height: 100,
                                        index: 0, source: "UNKNOWN")
        XCTAssertEqual(token.phase, .unknown)
        XCTAssertEqual(token.widthText, "200")

        let unmeasured = CropPageModel.facts(hasOpener: true, paths: ["a", "b"], source: "ready")
        XCTAssertEqual(unmeasured.phase, .unknown)
        XCTAssertEqual(unmeasured.widthText, dash)
        XCTAssertEqual(unmeasured.countText, "2")

        let zero = CropPageModel.facts(hasOpener: true, paths: ["a"], width: 0, height: 10,
                                       index: 0, source: "ready")
        XCTAssertEqual(zero.phase, .error)
        XCTAssertEqual(zero.widthText, "0")
        XCTAssertEqual(zero.heightText, "10")
        XCTAssertTrue(zero.canUseOriginal)
        XCTAssertFalse(zero.canConfirm)
        XCTAssertEqual(zero.copyKey, CropPageModel.Copy.error)
    }

    func testCropPageReadyConfirmsLocallyAndDoesNotMarkARouteOrUpload() {
        let ready = CropPageModel.facts(hasOpener: true, paths: ["local"], ratio: nil, shape: "circle",
                                        merchant: true, width: 200, height: 100, index: 0, source: "ready")
        XCTAssertEqual(ready.phase, .ready)
        XCTAssertEqual(ready.ratioText, "free")
        XCTAssertTrue(ready.round)
        XCTAssertTrue(ready.merchantLight)
        XCTAssertTrue(ready.canConfirm)
        XCTAssertTrue(ready.canReset)
        XCTAssertFalse(ready.canUseOriginal)
        let exportFailed = CropPageModel.facts(hasOpener: true, paths: ["local"], width: 200, height: 100,
                                               index: 0, source: "ready", exportFailed: true)
        XCTAssertEqual(exportFailed.phase, .ready)
        XCTAssertTrue(exportFailed.canUseOriginal)
        let busySource = CropPageModel.facts(hasOpener: true, paths: ["a"], width: 0, height: 10,
                                             index: 0, source: "ready", busy: true)
        XCTAssertEqual(busySource.phase, .error)
        XCTAssertFalse(busySource.canUseOriginal)
        XCTAssertFalse(ready.uploadEnabled)
        XCTAssertEqual(ready.confirmKey, CropPageModel.Copy.confirm)
        XCTAssertEqual(ready.copyKey, CropPageModel.Copy.title)
        XCTAssertEqual(ready.progressText, "")
        XCTAssertFalse(CropPageModel.routeInstalled)
        XCTAssertFalse(CropPageModel.routeMarkedLive)
        XCTAssertFalse(CropPageModel.showsMerchantChoice)
        XCTAssertFalse(CropPageModel.paymentEnabled)
        XCTAssertFalse(CropPageModel.payoutEnabled)
        XCTAssertFalse(CropPageModel.withdrawalEnabled)
        XCTAssertFalse(CropPageModel.virtualGoodsEnabled)

        let otherShape = CropPageModel.facts(hasOpener: true, paths: ["local"], shape: "UNKNOWN",
                                             merchant: nil, width: 20, height: 20, index: 0, source: "ready")
        XCTAssertFalse(otherShape.round)
        XCTAssertFalse(otherShape.merchantLight)
        XCTAssertEqual(otherShape.phase, .ready)

        let batch = CropPageModel.facts(hasOpener: true, paths: ["a", "b"], ratio: "1:1",
                                        width: 10, height: 10, index: 0, source: "ready")
        XCTAssertEqual(batch.progressText, "1/2")
        XCTAssertEqual(batch.indexText, "0")
        let missingIndex = CropPageModel.facts(hasOpener: true, paths: ["a", "b"], width: 10, height: 10, source: "ready")
        XCTAssertEqual(missingIndex.phase, .unknown)
        XCTAssertEqual(missingIndex.indexText, CropPageModel.unknownDisplay)
        let outOfRange = CropPageModel.facts(hasOpener: true, paths: ["a"], width: 10, height: 10, index: 3, source: "ready")
        XCTAssertEqual(outOfRange.phase, .error)

        let busy = CropPageModel.facts(hasOpener: true, paths: ["a"], width: 10, height: 10, index: 0,
                                       source: "ready", busy: true)
        XCTAssertFalse(busy.canConfirm)
        XCTAssertEqual(busy.confirmKey, CropPageModel.Copy.busy)
        let retry = CropPageModel.facts(hasOpener: true, paths: ["a"], width: 10, height: 10, index: 0,
                                        source: "ready", exportFailed: true)
        XCTAssertTrue(retry.canConfirm)
        XCTAssertEqual(retry.confirmKey, CropPageModel.Copy.retry)
    }

    func testCropPageSessionUnsetFrameIsLoadingAndAMeasuredZeroFrameIsError() {
        let dash = CropPageModel.unknownDisplay
        var pending = session(ratio: "1:1")
        let loading = CropPageModel.facts(session: pending)
        XCTAssertEqual(loading.phase, .loading)
        XCTAssertEqual(loading.frameWidthText, dash)
        XCTAssertEqual(loading.frameHeightText, dash)
        XCTAssertEqual(loading.widthText, "200")
        XCTAssertFalse(loading.canConfirm)
        XCTAssertFalse(pending.confirm())

        pending.setFrame(width: 100, height: 100)
        let ready = CropPageModel.facts(session: pending)
        XCTAssertEqual(ready.phase, .ready)
        XCTAssertEqual(ready.frameWidthText, "100")
        XCTAssertTrue(ready.canConfirm)
        XCTAssertTrue(pending.confirm())

        var broken = session(ratio: "free")
        broken.setFrame(width: 0, height: 10)
        let measuredZero = CropPageModel.facts(session: broken)
        XCTAssertEqual(measuredZero.phase, .error)
        XCTAssertEqual(measuredZero.frameWidthText, "0")
        XCTAssertEqual(measuredZero.frameHeightText, "10")

        let unnamed = CropPageModel.facts(session: session(ratio: "UNKNOWN"))
        XCTAssertEqual(unnamed.phase, .unknown)
        XCTAssertEqual(unnamed.ratioText, dash)

        var done = session(ratio: "free", count: 1)
        done.setFrame(width: 200, height: 100)
        XCTAssertTrue(done.confirm())
        let finished = CropPageModel.facts(session: done)
        XCTAssertEqual(finished.phase, .ready)
        XCTAssertFalse(finished.canConfirm)
        XCTAssertFalse(done.confirm())
    }
}
#endif
