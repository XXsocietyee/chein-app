import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private struct ProbeError: Error {}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }
    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
}

/// One in-flight body waits here until the test resumes it.
private final class Pause: @unchecked Sendable {
    private let lock = NSLock()
    private var entered: CheckedContinuation<Void, Never>?
    private var gate: CheckedContinuation<Void, Never>?
    private var started = false
    private var opened = false

    func pause() async {
        let waiter: CheckedContinuation<Void, Never>?
        lock.lock()
        started = true
        waiter = entered
        entered = nil
        lock.unlock()
        waiter?.resume()
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

    func waitUntilPaused() async {
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

    func resume() {
        lock.lock()
        opened = true
        let gate = self.gate
        self.gate = nil
        lock.unlock()
        gate?.resume()
    }
}

private final class CountingTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var sendCount = 0
    var sends: Int {
        lock.lock()
        defer { lock.unlock() }
        return sendCount
    }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        lock.lock()
        sendCount += 1
        lock.unlock()
        return (Data(#"{"code":200,"data":[]}"#.utf8), 200)
    }
}

private final class GatedTransport: HTTPTransport, @unchecked Sendable {
    private let pause = Pause()
    private let lock = NSLock()
    private var sendCount = 0
    var sends: Int {
        lock.lock()
        defer { lock.unlock() }
        return sendCount
    }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        lock.lock()
        sendCount += 1
        let isFirst = sendCount == 1
        lock.unlock()
        if isFirst { await pause.pause() }
        return (Data(#"{"code":200,"data":[]}"#.utf8), 200)
    }
    func waitUntilPaused() async { await pause.waitUntilPaused() }
    func resume() { pause.resume() }
}

final class InFlightReadCoalescerTests: XCTestCase {
    func testReadKeysIgnoreFieldOrderAndKeepTheToken() {
        let left = InFlightReadKey.fields(method: "POST", path: "api/topic/list", fields: ["b": "2", "a": "1"], token: "tok")
        let right = InFlightReadKey.fields(method: "POST", path: "api/topic/list", fields: ["a": "1", "b": "2"], token: "tok")
        XCTAssertEqual(left, right)
        let otherToken = InFlightReadKey.fields(method: "POST", path: "api/topic/list", fields: ["a": "1", "b": "2"], token: "other")
        XCTAssertNotEqual(left, otherToken)
        let emptyJSON = InFlightReadKey.fields(method: "POST", path: "api/template/homeData", fields: [:], token: nil, tag: "true")
        let multipart = InFlightReadKey.fields(method: "POST", path: "api/template/homeData", fields: [:], token: nil, tag: "false")
        XCTAssertNotEqual(emptyJSON, multipart)
    }

    func testOverlappingJoinRunsTheBodyOnce() async throws {
        let reads = InFlightReadCoalescer<Int>()
        let pause = Pause()
        let runs = LockedCounter()
        let first = Task { () throws -> Int in
            try await reads.join("k") {
                await pause.pause()
                runs.increment()
                return 7
            }
        }
        await pause.waitUntilPaused()
        let second = Task { () throws -> Int in
            try await reads.join("k") {
                runs.increment()
                return 8
            }
        }
        pause.resume()
        let left = try await first.value
        let right = try await second.value
        XCTAssertEqual(left, 7)
        XCTAssertEqual(right, 7)
        XCTAssertEqual(runs.value, 1)
        XCTAssertFalse(reads.isInFlight("k"))
    }

    func testDistinctKeysRunSideBySide() async throws {
        let reads = InFlightReadCoalescer<Int>()
        let pause = Pause()
        let first = Task { () throws -> Int in
            try await reads.join("a") {
                await pause.pause()
                return 1
            }
        }
        await pause.waitUntilPaused()
        let second = try await reads.join("b") { 2 }
        XCTAssertEqual(second, 2)
        XCTAssertTrue(reads.isInFlight("a"))
        pause.resume()
        let firstValue = try await first.value
        XCTAssertEqual(firstValue, 1)
        XCTAssertFalse(reads.isInFlight("a"))
    }

    func testAFinishedReadStartsAgain() async throws {
        let reads = InFlightReadCoalescer<Int>()
        let first = try await reads.join("k") { 1 }
        let second = try await reads.join("k") { 2 }
        XCTAssertEqual(first, 1)
        XCTAssertEqual(second, 2)
    }

    func testSharedFailureDoesNotKeepTheRead() async throws {
        let reads = InFlightReadCoalescer<Int>()
        let pause = Pause()
        let runs = LockedCounter()
        let first = Task { () throws -> Int in
            try await reads.join("k") {
                await pause.pause()
                runs.increment()
                throw ProbeError()
            }
        }
        await pause.waitUntilPaused()
        let second = Task { () throws -> Int in
            try await reads.join("k") {
                runs.increment()
                return 1
            }
        }
        pause.resume()
        let firstResult = await first.result
        let secondResult = await second.result
        XCTAssertThrowsError(try firstResult.get())
        XCTAssertThrowsError(try secondResult.get())
        XCTAssertEqual(runs.value, 1)
        XCTAssertFalse(reads.isInFlight("k"))
        let third = try await reads.join("k") { 4 }
        XCTAssertEqual(third, 4)
    }

    func testSequentialBannersSendTwice() async throws {
        let transport = CountingTransport()
        let service = try discovery(transport)
        _ = try await service.banners()
        _ = try await service.banners()
        XCTAssertEqual(transport.sends, 2)
    }

    func testOverlappingBannersShareOneSend() async throws {
        let transport = GatedTransport()
        let service = try discovery(transport)
        let first = Task { try await service.banners() }
        await transport.waitUntilPaused()
        let second = Task { try await service.banners() }
        let deadline = Date().addingTimeInterval(0.5)
        while Date() < deadline { await Task.yield() }
        XCTAssertEqual(transport.sends, 1)
        transport.resume()
        _ = try await first.value
        _ = try await second.value
        XCTAssertEqual(transport.sends, 1)
    }

    func testDifferentTokensDoNotShareABannerRead() async throws {
        let transport = GatedTransport()
        let service = try discovery(transport)
        let first = Task { try await service.banners(token: "one") }
        await transport.waitUntilPaused()
        _ = try await service.banners(token: "two")
        XCTAssertEqual(transport.sends, 2)
        transport.resume()
        _ = try await first.value
        XCTAssertEqual(transport.sends, 2)
    }

    private func discovery(_ transport: any HTTPTransport) throws -> DiscoveryService {
        try DiscoveryService(
            configuration: APIConfiguration(baseURL: URL(string: "https://api.example.com/prod-api")!),
            transport: transport)
    }
}
