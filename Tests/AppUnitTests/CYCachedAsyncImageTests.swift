import XCTest
import UIKit
@testable import Questify

/// Local bytes only. No URL session, no request, and no remote image fetch.
@MainActor
final class CYCachedAsyncImageTests: XCTestCase {
    private let cover = "https://cdn.example.invalid/cover.jpg"
    private let shelf = "https://cdn.example.invalid/shelf.jpg"

    func testUnknownReferenceStaysOnThePlaceholderWithoutLoading() async throws {
        let loader = LocalImageLoader(result: .success(try png()))
        let store = CYCachedAsyncImageStore(capacity: 4)
        let unknown = [
            nil as String?,
            "",
            "   ",
            "cover.jpg",
            "/covers/a.jpg",
            "http://cdn.example.invalid/a.jpg",
            "HTTPS://cdn.example.invalid/a.jpg",
            "https://u:p@cdn.example.invalid/a.jpg",
            "https://user@cdn.example.invalid/a.jpg",
            "https://cdn.example.invalid/a.jpg#frame",
            "https://cdn.example.invalid/a b.jpg",
            "https://cdn.example.invalid/a\\b.jpg",
            "https://cdn.example.invalid/a\nb.jpg",
            "https:///missing-host.jpg",
            overlongReference()
        ]
        for source in unknown {
            let phase = await CYCachedAsyncImageModel.resolve(source: source, store: store, loader: loader)
            XCTAssertEqual(phase, .placeholder, String(describing: source))
        }
        XCTAssertTrue(loader.calls.isEmpty)
        XCTAssertEqual(store.count, 0)
        let prefix = "https://cdn.example.invalid/"
        let exact = prefix + String(repeating: "b", count: CYCachedAsyncImageSource.maximumUTF8Bytes - prefix.utf8.count)
        XCTAssertEqual(exact.utf8.count, CYCachedAsyncImageSource.maximumUTF8Bytes)
        XCTAssertEqual(CYCachedAsyncImageSource.key(from: exact), exact)
        XCTAssertNil(CYCachedAsyncImageSource.key(from: overlongReference()))
    }

    func testImageMissingFromTheCacheStaysOnThePlaceholder() async {
        let store = CYCachedAsyncImageStore(capacity: 4)
        let phase = await CYCachedAsyncImageModel.resolve(source: cover, store: store, loader: nil)
        XCTAssertEqual(phase, .placeholder)
        XCTAssertNil(store.peek(cover))
        XCTAssertEqual(store.count, 0)
    }

    func testLocalLoadIsCachedAndASecondLookupDoesNotLoadAgain() async throws {
        let bytes = try png()
        let loader = LocalImageLoader(result: .success(bytes))
        let store = CYCachedAsyncImageStore(capacity: 4)
        let padded = "  \(cover)  "
        let first = await CYCachedAsyncImageModel.resolve(source: padded, store: store, loader: loader)
        XCTAssertEqual(first, .ready(bytes))
        XCTAssertEqual(loader.calls, [cover])
        XCTAssertEqual(store.peek(cover), bytes)

        loader.result = .failure(CYCachedAsyncImageFailure.unavailable)
        let second = await CYCachedAsyncImageModel.resolve(source: cover, store: store, loader: loader)
        XCTAssertEqual(second, .ready(bytes))
        XCTAssertEqual(loader.calls, [cover])
        XCTAssertEqual(store.count, 1)
    }

    func testLoadFailureIsVisibleAndNotCached() async throws {
        let loader = LocalImageLoader(result: .failure(CYCachedAsyncImageFailure.unavailable))
        let store = CYCachedAsyncImageStore(capacity: 4)
        let failed = await CYCachedAsyncImageModel.resolve(source: cover, store: store, loader: loader)
        XCTAssertEqual(failed, .failed)
        XCTAssertNil(store.peek(cover))
        XCTAssertEqual(loader.calls, [cover])

        let bytes = try png()
        loader.result = .success(bytes)
        let retried = await CYCachedAsyncImageModel.resolve(source: cover, store: store, loader: loader)
        XCTAssertEqual(retried, .ready(bytes))
        XCTAssertEqual(loader.calls, [cover, cover])

        let cached = await CYCachedAsyncImageModel.resolve(source: cover, store: store, loader: loader)
        XCTAssertEqual(cached, .ready(bytes))
        XCTAssertEqual(loader.calls.count, 2)
    }

    func testEmptyOversizedAndUndecodableBytesFailAndStayUncached() async {
        let store = CYCachedAsyncImageStore(capacity: 4)
        let samples = [
            Data(),
            Data([0x00, 0x01, 0x02, 0x03]),
            Data(repeating: 0, count: CYCachedAsyncImageStore.maximumByteCount + 1)
        ]
        for sample in samples {
            let loader = LocalImageLoader(result: .success(sample))
            let phase = await CYCachedAsyncImageModel.resolve(source: cover, store: store, loader: loader)
            XCTAssertEqual(phase, .failed)
            XCTAssertEqual(loader.calls, [cover])
            XCTAssertNil(store.peek(cover))
        }
        XCTAssertEqual(store.count, 0)
        XCTAssertFalse(store.insert(Data(), for: cover))
        XCTAssertFalse(store.insert(Data([0x00, 0x01]), for: ""))
    }

    func testADifferentImageDoesNotReuseAnotherCacheEntry() async throws {
        let bytes = try png()
        let loader = LocalImageLoader(result: .success(bytes))
        let store = CYCachedAsyncImageStore(capacity: 4)
        let ready = await CYCachedAsyncImageModel.resolve(source: cover, store: store, loader: loader)
        XCTAssertEqual(ready, .ready(bytes))
        let other = await CYCachedAsyncImageModel.resolve(source: shelf, store: store, loader: nil)
        XCTAssertEqual(other, .placeholder)
        XCTAssertNil(store.peek(shelf))
        XCTAssertEqual(store.peek(cover), bytes)
        XCTAssertEqual(loader.calls, [cover])
    }

    func testLeastRecentlyUsedImageIsEvicted() throws {
        let bytes = try png()
        let store = CYCachedAsyncImageStore(capacity: 2)
        let third = "https://cdn.example.invalid/third.jpg"
        XCTAssertTrue(store.insert(bytes, for: cover))
        XCTAssertTrue(store.insert(bytes, for: shelf))
        store.touch(cover)
        XCTAssertTrue(store.insert(bytes, for: third))
        XCTAssertNil(store.peek(shelf))
        XCTAssertEqual(store.peek(cover), bytes)
        XCTAssertEqual(store.peek(third), bytes)
        XCTAssertEqual(store.count, 2)
        XCTAssertTrue(store.insert(bytes, for: cover))
        XCTAssertEqual(store.count, 2)
    }

    func testCoverAndShelfFramesStayDistinct() {
        XCTAssertEqual(CYCachedAsyncImageRole.cover.aspectRatio, 16.0 / 10.0)
        XCTAssertNil(CYCachedAsyncImageRole.cover.fixedWidth)
        XCTAssertEqual(CYCachedAsyncImageRole.shelf.aspectRatio, 3.0 / 2.0)
        XCTAssertEqual(CYCachedAsyncImageRole.shelf.fixedWidth, 280)
    }

    func testTotalByteBudgetEvictsTheLeastRecentlyUsedImage() throws {
        let bytes = try png()
        let store = CYCachedAsyncImageStore(capacity: 8, totalByteBudget: bytes.count * 2)
        let third = "https://cdn.example.invalid/third.jpg"
        XCTAssertTrue(store.insert(bytes, for: cover))
        XCTAssertTrue(store.insert(bytes, for: shelf))
        store.touch(cover)
        XCTAssertTrue(store.insert(bytes, for: third))
        XCTAssertEqual(store.count, 2)
        XCTAssertNil(store.peek(shelf))
        XCTAssertEqual(store.peek(cover), bytes)
        XCTAssertEqual(store.peek(third), bytes)
    }

    func testAnImageLargerThanTheByteBudgetIsRefused() throws {
        let bytes = try png()
        let store = CYCachedAsyncImageStore(capacity: 4, totalByteBudget: bytes.count - 1)
        XCTAssertFalse(store.insert(bytes, for: cover))
        XCTAssertEqual(store.count, 0)
    }

    func testOverlappingResolvesShareOneLoad() async throws {
        let bytes = try png()
        let loader = HeldImageLoader(result: bytes)
        let store = CYCachedAsyncImageStore(capacity: 4)
        let first = Task { await CYCachedAsyncImageModel.resolve(source: cover, store: store, loader: loader) }
        await loader.waitUntilStarted()
        XCTAssertTrue(store.isCoalescing(cover))
        let second = Task { await CYCachedAsyncImageModel.resolve(source: cover, store: store, loader: loader) }
        let deadline = Date().addingTimeInterval(0.5)
        while Date() < deadline { await Task.yield() }
        XCTAssertEqual(loader.callCount, 1)
        loader.release()
        let phases = await [first.value, second.value]
        XCTAssertEqual(phases, [.ready(bytes), .ready(bytes)])
        XCTAssertEqual(loader.callCount, 1)
        XCTAssertEqual(store.count, 1)
    }

    func testStateIdentifiersStayOnPlaceholderFailureAndImage() {
        XCTAssertEqual(CYCachedAsyncImage.placeholderAccessibilityID, "cy.cachedImage.placeholder")
        XCTAssertEqual(CYCachedAsyncImage.failureAccessibilityID, "cy.cachedImage.failure")
        XCTAssertEqual(CYCachedAsyncImage.imageAccessibilityID, "cy.cachedImage.image")
    }

    private func png() throws -> Data {
        let encoded = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII="
        return try XCTUnwrap(Data(base64Encoded: encoded))
    }

    private func overlongReference() -> String {
        let prefix = "https://cdn.example.invalid/"
        let extra = CYCachedAsyncImageSource.maximumUTF8Bytes - prefix.utf8.count + 1
        return prefix + String(repeating: "a", count: extra)
    }
}

private final class LocalImageLoader: CYCachedAsyncImageLoading {
    var calls: [String] = []
    var result: Result<Data, Error>

    init(result: Result<Data, Error>) {
        self.result = result
    }

    func loadImage(for key: String) async throws -> Data {
        calls.append(key)
        return try result.get()
    }
}

/// Holds the first load until the test releases it, so a second resolve can join.
private final class HeldImageLoader: CYCachedAsyncImageLoading, @unchecked Sendable {
    private let lock = NSLock()
    private var calls = 0
    private var started = false
    private var opened = false
    private var entered: CheckedContinuation<Void, Never>?
    private var gate: CheckedContinuation<Void, Never>?
    private let result: Data

    init(result: Data) { self.result = result }

    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }

    func loadImage(for key: String) async throws -> Data {
        let isFirst: Bool
        let waiter: CheckedContinuation<Void, Never>?
        lock.lock()
        calls += 1
        isFirst = calls == 1
        started = true
        waiter = entered
        entered = nil
        lock.unlock()
        waiter?.resume()
        if isFirst {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                lock.lock()
                if opened {
                    lock.unlock()
                    continuation.resume()
                    return
                }
                gate = continuation
                lock.unlock()
            }
        }
        return result
    }

    func waitUntilStarted() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            lock.lock()
            if started {
                lock.unlock()
                continuation.resume()
                return
            }
            entered = continuation
            lock.unlock()
        }
    }

    func release() {
        lock.lock()
        opened = true
        let gate = self.gate
        self.gate = nil
        lock.unlock()
        gate?.resume()
    }
}
