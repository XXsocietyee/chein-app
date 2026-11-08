import XCTest
@testable import QuestifyCore
import Foundation

// All values synthetic. The fake client lives here only; nothing in Core/App returns canned data.
@MainActor final class BNDFakeVoucherClient: BundleVoucherServing {
    var voucherOutcomes: [BundleVoucherFetchOutcome] = []
    var versionOutcomes: [BundleVoucherVersionOutcome] = []
    var redeemOutcome: BundleRedeemResultOutcome = .unavailable
    private(set) var voucherCalls = 0
    private(set) var versionCalls = 0
    func voucher(registrationID: String) async -> BundleVoucherFetchOutcome {
        voucherCalls += 1
        return voucherOutcomes.isEmpty ? .failed : (voucherOutcomes.count > 1 ? voucherOutcomes.removeFirst() : voucherOutcomes[0])
    }
    func version(registrationID: String) async -> BundleVoucherVersionOutcome {
        versionCalls += 1
        return versionOutcomes.isEmpty ? .failed : (versionOutcomes.count > 1 ? versionOutcomes.removeFirst() : versionOutcomes[0])
    }
    func redeemResult(registrationID: String, unitID: String) async -> BundleRedeemResultOutcome { redeemOutcome }
}

@MainActor final class BNDVoucherModelTests: XCTestCase {
    private let secretMain = "SYNTH-MAIN-CODE-7f3a"
    private let secretSub = "SYNTH-SUB-CODE-91bc"

    private func voucher(version: String) -> BundleVoucher {
        BundleVoucher(registrationID: "11", version: version, mainCode: secretMain, mainValidTo: "2027-01-01",
                      subs: [BundleVoucherSubCode(unitID: "21", chapterID: "31", unitCode: secretSub, status: "AVAILABLE")])
    }
    /// Never returns until cancelled, so nothing polls unless a test calls `pollOnce()` itself.
    private let hangingSleep: (TimeInterval) async throws -> Void = { _ in try await Task.sleep(nanoseconds: 3_600_000_000_000) }

    private func settle() async { for _ in 0..<50 { await Task.yield() } }

    func testPollStopsWhenViewDisappears() async {
        let client = BNDFakeVoucherClient()
        client.voucherOutcomes = [.voucher(voucher(version: "v1"))]
        client.versionOutcomes = [.version("v1", pollIntervalHint: nil)]
        // Short real sleep, so while visible the loop polls continuously.
        let model = BundleVoucherModel(registrationID: "11", client: client, sleep: { _ in
            try await Task.sleep(nanoseconds: 1_000_000)
        })
        await model.appear()
        for _ in 0..<400 where client.versionCalls == 0 { try? await Task.sleep(nanoseconds: 5_000_000) }
        XCTAssertGreaterThan(client.versionCalls, 0, "polls while visible")
        model.disappear()
        await settle()
        let after = client.versionCalls
        try? await Task.sleep(nanoseconds: 30_000_000)
        await settle()
        XCTAssertEqual(client.versionCalls, after, "no polls after disappear")
        XCTAssertFalse(model.isVisible)
        await model.pollOnce()
        XCTAssertEqual(client.versionCalls, after, "pollOnce is a no-op when hidden")
        XCTAssertEqual(model.state, .idle, "voucher dropped from memory on disappear")
    }

    func testRefetchOnlyOnVersionChange() async {
        let client = BNDFakeVoucherClient()
        client.voucherOutcomes = [.voucher(voucher(version: "v1")), .voucher(voucher(version: "v2"))]
        let model = BundleVoucherModel(registrationID: "11", client: client, sleep: hangingSleep)
        await model.appear()
        XCTAssertEqual(client.voucherCalls, 1)
        client.versionOutcomes = [.version("v1", pollIntervalHint: nil)]
        await model.pollOnce(); await model.pollOnce()
        XCTAssertEqual(client.voucherCalls, 1, "same version never refetches")
        client.versionOutcomes = [.version("v2", pollIntervalHint: nil)]
        await model.pollOnce()
        XCTAssertEqual(client.voucherCalls, 2)
        XCTAssertEqual(model.state, .loaded(voucher(version: "v2")))
        await model.pollOnce()
        XCTAssertEqual(client.voucherCalls, 2, "after refetch the new version is current")
        model.disappear()
    }

    func testCodeNeverPersisted() async {
        let client = BNDFakeVoucherClient()
        client.voucherOutcomes = [.voucher(voucher(version: "v1"))]
        let model = BundleVoucherModel(registrationID: "11", client: client, sleep: hangingSleep)
        await model.appear()
        guard case .loaded(let loaded) = model.state else { return XCTFail("expected loaded") }
        // Printing, debug-printing and dumping must not reveal either code.
        var dumped = ""
        dump(loaded, to: &dumped)
        dump(loaded.subs, to: &dumped)
        let rendered = [String(describing: loaded), String(reflecting: loaded), "\(loaded)", dumped,
                        String(describing: loaded.subs), String(reflecting: loaded.subs[0])].joined(separator: "\n")
        XCTAssertFalse(rendered.contains(secretMain))
        XCTAssertFalse(rendered.contains(secretSub))
        XCTAssertTrue(rendered.contains(bundleVoucherRedactedCode))
        // The model takes no storage dependency; UserDefaults must not have received a code.
        let defaults = String(describing: UserDefaults.standard.dictionaryRepresentation())
        XCTAssertFalse(defaults.contains(secretMain))
        XCTAssertFalse(defaults.contains(secretSub))
        // Leaving the screen drops the in-memory voucher too.
        model.disappear()
        XCTAssertEqual(model.state, .idle)
        XCTAssertFalse(String(describing: model.state).contains(secretMain))
    }

    func testUnknownOutcomeRendersNeutral() async {
        XCTAssertEqual(BundleRedeemPresentation(BundleRedeemOutcome(serverValue: "SOMETHING_NEW")), .processing)
        XCTAssertEqual(BundleRedeemPresentation(BundleRedeemOutcome(serverValue: "")), .processing)
        XCTAssertEqual(BundleRedeemPresentation(BundleRedeemOutcome(serverValue: "success")), .processing, "case-sensitive: not guessed")
        XCTAssertEqual(BundleRedeemPresentation(BundleRedeemOutcome(serverValue: "SUCCESS")), .success)
        XCTAssertEqual(BundleRedeemPresentation(BundleRedeemOutcome(serverValue: "REVIEW")), .review)
        XCTAssertEqual(BundleRedeemPresentation(BundleRedeemOutcome(serverValue: "REJECTED")), .rejected)
        XCTAssertEqual(BundleRedeemPresentation(BundleRedeemOutcome(serverValue: "NONE")), .notRedeemed)
        let client = BNDFakeVoucherClient()
        client.voucherOutcomes = [.voucher(voucher(version: "v1"))]
        client.redeemOutcome = .result(BundleRedeemResult(outcome: BundleRedeemOutcome(serverValue: "WEIRD"), unitID: "21"))
        let model = BundleVoucherModel(registrationID: "11", client: client, sleep: hangingSleep)
        await model.appear()
        await model.loadRedeemResult(unitID: "21")
        guard case .loaded(let presentation, _) = model.redeemState else { return XCTFail("expected loaded") }
        XCTAssertEqual(presentation, .processing)
        model.disappear()
    }

    func testVersionPollBackoffOnFailure() async {
        let client = BNDFakeVoucherClient()
        client.voucherOutcomes = [.voucher(voucher(version: "v1"))]
        let model = BundleVoucherModel(registrationID: "11", client: client, sleep: hangingSleep)
        await model.appear()
        XCTAssertEqual(model.currentInterval, 5)
        client.versionOutcomes = [.failed]
        var seen: [TimeInterval] = []
        for _ in 0..<6 { await model.pollOnce(); seen.append(model.currentInterval) }
        XCTAssertEqual(seen, [10, 20, 40, 60, 60, 60], "exponential, capped at 60 s, never below 5 s")
        XCTAssertEqual(model.state, .loaded(voucher(version: "v1")), "failed polls keep the voucher on screen")
        client.versionOutcomes = [.version("v1", pollIntervalHint: nil)]
        await model.pollOnce()
        XCTAssertEqual(model.currentInterval, 5, "success resets backoff")
        XCTAssertEqual(model.consecutiveFailures, 0)
        client.versionOutcomes = [.version("v1", pollIntervalHint: 12)]
        await model.pollOnce()
        XCTAssertEqual(model.currentInterval, 12, "server hint honoured")
        client.versionOutcomes = [.version("v1", pollIntervalHint: 1)]
        await model.pollOnce()
        XCTAssertEqual(model.currentInterval, 5, "hint below 5 s is clamped")
        model.disappear()
    }

    func testUnavailableDefaultShowsUnavailableNotData() async {
        let model = BundleVoucherModel(registrationID: "11", sleep: hangingSleep)
        await model.appear()
        XCTAssertEqual(model.state, .unavailable)
        await model.loadRedeemResult(unitID: "21")
        XCTAssertEqual(model.redeemState, .unavailable)
        model.disappear()
        XCTAssertEqual(model.state, .unavailable)
    }
}
