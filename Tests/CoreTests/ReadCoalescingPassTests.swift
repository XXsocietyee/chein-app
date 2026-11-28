import XCTest
@testable import QuestifyCore

final class ReadCoalescingPassTests: XCTestCase {
    private let base = URL(string: "https://example.com")!

    func testRequestKeyIgnoresTheMultipartBoundaryAndKeepsTheToken() throws {
        let url = base.appendingPathComponent("api/registration/list")
        let fields = ["b": "2", "a": "1"]
        let left = try AuthRequestBuilder.makeFormRequest(url: url, fields: fields, token: "perf-boundary", boundary: "BoundaryA")
        let right = try AuthRequestBuilder.makeFormRequest(url: url, fields: fields, token: "perf-boundary", boundary: "BoundaryB")
        XCTAssertEqual(InFlightReadKey.request(left), InFlightReadKey.request(right))
        let other = try AuthRequestBuilder.makeFormRequest(url: url, fields: fields, token: "perf-boundary-other", boundary: "BoundaryA")
        XCTAssertNotEqual(InFlightReadKey.request(left), InFlightReadKey.request(other))
    }

    func testOverlappingProfileOrdersShareOneSendThenALaterCallSendsAgain() async throws {
        let transport = GateTransport()
        let service = ProfileService(configuration: try APIConfiguration(baseURL: base), transport: transport)
        let first = Task { _ = try? await service.orders(token: "perf-profile-orders") }
        await transport.waitUntilPaused()
        let second = Task { _ = try? await service.orders(token: "perf-profile-orders") }
        await Task.yield()
        XCTAssertEqual(transport.sends, 1)
        transport.resume()
        _ = await first.value
        _ = await second.value
        _ = try? await service.orders(token: "perf-profile-orders")
        XCTAssertEqual(transport.sends, 2)
    }

    func testADifferentTokenDoesNotShareTheProfileRead() async throws {
        let transport = GateTransport()
        let service = ProfileService(configuration: try APIConfiguration(baseURL: base), transport: transport)
        let first = Task { _ = try? await service.orders(token: "perf-profile-a") }
        await transport.waitUntilPaused()
        let second = Task { _ = try? await service.orders(token: "perf-profile-b") }
        await transport.waitUntilSends(2)
        XCTAssertEqual(transport.sends, 2)
        transport.resume()
        _ = await first.value
        _ = await second.value
    }

    func testOverlappingJourneyParticipationsShareOneSend() async throws {
        let transport = GateTransport()
        let service = PlayerJourneyService(configuration: try APIConfiguration(baseURL: base), transport: transport, readsEnabled: true)
        let first = Task { _ = try? await service.participations(token: "perf-journey") }
        await transport.waitUntilPaused()
        let second = Task { _ = try? await service.participations(token: "perf-journey") }
        await Task.yield()
        XCTAssertEqual(transport.sends, 1)
        transport.resume()
        _ = await first.value
        _ = await second.value
    }

    func testOverlappingOfficialEventsShareOneSend() async throws {
        let transport = GateTransport()
        let service = OfficialEventService(configuration: try APIConfiguration(baseURL: base), transport: transport)
        let first = Task { _ = try? await service.events(token: "perf-official") }
        await transport.waitUntilPaused()
        let second = Task { _ = try? await service.events(token: "perf-official") }
        await Task.yield()
        XCTAssertEqual(transport.sends, 1)
        transport.resume()
        _ = await first.value
        _ = await second.value
    }

    func testOverlappingGrowthCenterReadsShareOneSend() async throws {
        let transport = GateTransport()
        let service = GrowthCenterService(configuration: try APIConfiguration(baseURL: base), transport: transport)
        let first = Task { _ = try? await service.center(token: "perf-growth") }
        await transport.waitUntilPaused()
        let second = Task { _ = try? await service.center(token: "perf-growth") }
        await Task.yield()
        XCTAssertEqual(transport.sends, 1)
        transport.resume()
        _ = await first.value
        _ = await second.value
    }

    func testOverlappingUnreadTotalsShareOneSendAcrossInstances() async throws {
        let transport = GateTransport()
        let configuration = try APIConfiguration(baseURL: base)
        let paths: Set<String> = [IMUnreadTotalService.path]
        let firstService = IMUnreadTotalService(configuration: configuration, transport: transport, enabledPaths: paths)
        let secondService = IMUnreadTotalService(configuration: configuration, transport: transport, enabledPaths: paths)
        let first = Task { _ = try? await firstService.total(token: "perf-unread-static") }
        await transport.waitUntilPaused()
        let second = Task { _ = try? await secondService.total(token: "perf-unread-static") }
        await Task.yield()
        XCTAssertEqual(transport.sends, 1)
        transport.resume()
        _ = await first.value
        _ = await second.value
    }

    func testFavoriteReadsShareOneSendWhileCouponReadsDoNot() async throws {
        let joined = GateTransport()
        let favorites = AccountCollectionService(configuration: try APIConfiguration(baseURL: base), transport: joined)
        let first = Task { _ = try? await favorites.favorites(token: "perf-favorites") }
        await joined.waitUntilPaused()
        let second = Task { _ = try? await favorites.favorites(token: "perf-favorites") }
        await Task.yield()
        XCTAssertEqual(joined.sends, 1)
        joined.resume()
        _ = await first.value
        _ = await second.value

        let separate = GateTransport()
        let coupons = AccountCollectionService(configuration: try APIConfiguration(baseURL: base), transport: separate)
        let left = Task { _ = try? await coupons.coupons(token: "perf-coupons") }
        await separate.waitUntilPaused()
        let right = Task { _ = try? await coupons.coupons(token: "perf-coupons") }
        await separate.waitUntilSends(2)
        XCTAssertEqual(separate.sends, 2)
        separate.resume()
        _ = await left.value
        _ = await right.value
    }
}

private final class ReadPassPause: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Never>?
    private var entered: CheckedContinuation<Void, Never>?
    private var open = false
    func pause() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.lock.lock()
            self.continuation = continuation
            self.entered?.resume()
            self.entered = nil
            self.lock.unlock()
        }
    }
    func waitUntilPaused() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.lock.lock()
            if self.continuation != nil || self.open {
                self.lock.unlock()
                continuation.resume()
            } else {
                self.entered = continuation
                self.lock.unlock()
            }
        }
    }
    func resume() {
        lock.lock()
        open = true
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume()
    }
}

private final class GateTransport: HTTPTransport, @unchecked Sendable {
    private let pause = ReadPassPause()
    private let lock = NSLock()
    private var sendCount = 0
    private var waiters: [(Int, CheckedContinuation<Void, Never>)] = []
    var sends: Int {
        lock.lock(); defer { lock.unlock() }
        return sendCount
    }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let count = note()
        if count == 1 { await pause.pause() }
        return (Data("{}".utf8), 200)
    }
    func waitUntilPaused() async { await pause.waitUntilPaused() }
    func waitUntilSends(_ count: Int) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.lock.lock()
            if self.sendCount >= count {
                self.lock.unlock()
                continuation.resume()
                return
            }
            self.waiters.append((count, continuation))
            self.lock.unlock()
        }
    }
    func resume() { pause.resume() }
    private func note() -> Int {
        lock.lock()
        sendCount += 1
        let count = sendCount
        let ready = waiters.filter { $0.0 <= count }
        waiters.removeAll { $0.0 <= count }
        lock.unlock()
        for waiter in ready { waiter.1.resume() }
        return count
    }
}
