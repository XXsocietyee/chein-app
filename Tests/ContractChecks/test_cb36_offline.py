"""CB36 source locks: unconfigured original-receipt reads fail before any request."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def body(text, signature):
    start = text.index(signature)
    brace = text.index('{', start)
    depth = 0
    for index in range(brace, len(text)):
        if text[index] == '{':
            depth += 1
        elif text[index] == '}':
            depth -= 1
            if depth == 0:
                return text[brace:index + 1]
    raise AssertionError('unbalanced ' + signature)


class CB36OfflineContract(unittest.TestCase):
    def test_game_node_receipt_fails_before_send_unless_offline_harness(self):
        service = (ROOT / 'Core/MerchantGameNodeService.swift').read_text()
        receipt = body(service, 'public func readReceipt(activityID: Int, requestID: String) async throws')
        self.assertLess(receipt.index('throw APIError.notConfigured'), receipt.index('send(Self.receiptPath'))
        self.assertIn('"requestId": requestID', receipt)
        gate = body(service, 'private var originalReceiptConfigured: Bool')
        self.assertLess(gate.index('configuration != nil'), gate.index('injectedOfflineHarness'))
        self.assertIn('transport is any MerchantContentOfflineTransport', gate)
        self.assertIn('gates.allows(Self.receiptPath, market: market)', gate)
        reader = service[service.index('class MerchantGameNodeContentReader'):]
        reader_receipt = body(reader, 'public func readReceipt(activityID: Int, requestID: String) async throws')
        self.assertIn('throw APIError.notConfigured', reader_receipt)
        self.assertNotIn('transport.send', reader_receipt)
        self.assertNotIn('service.', reader_receipt)

    def test_unknown_lock_survives_not_configured_and_existing_tests_remain(self):
        coordinator = (ROOT / 'Core/MerchantGameNodeCoordinator.swift').read_text()
        confirm = body(coordinator, 'public func confirmUnknownWrite() async')
        self.assertIn('(error as? APIError) == .notConfigured', confirm)
        self.assertIn('writeState = .unknown', confirm)
        self.assertIn('entry.index.requestID', confirm)
        tests = (ROOT / 'Tests/CoreTests/MerchantGameNodeTests.swift').read_text()
        for name in (
            'testUnknownWriteLocksAndOnlyExactReceiptReleases',
            'testUnconfiguredOriginalReceiptFailsBeforeAnyRequest',
            'testUnknownWriteStaysLockedWhenOriginalReceiptIsNotConfigured',
            'testGatesDefaultOffAndProductionReaderNeverWrites',
        ):
            self.assertIn('func ' + name, tests)
        fake = (ROOT / 'Tests/AppUnitTests/MerchantGameNodeEntryReadModelTests.swift').read_text()
        self.assertIn('fatalError("No receipt request")', fake)

    def test_existing_unconfigured_routes_still_refuse_before_send(self):
        runtime = (ROOT / 'Core/BusinessRuntimeConfiguration.swift').read_text()
        send = body(runtime, 'public func send(_ request: URLRequest) async throws')
        self.assertLess(send.index('throw APIError.notConfigured'), send.index('transport.send'))
        poll = (ROOT / 'Core/GroupPollService.swift').read_text()
        self.assertIn('guard enabledPaths.contains(path) else { throw APIError.notConfigured }', poll)
        created = body(poll, 'public func creationReceipt(scope: IMScope,clientPollKey: String,token: String)')
        self.assertLess(created.index('try permit(path)'), created.index('transport.send'))
        club = (ROOT / 'Core/ClubActionWriting.swift').read_text()
        self.assertIn('throw APIError.notConfigured', club)
        content = (ROOT / 'Core/MerchantContentService.swift').read_text()
        envelope = body(content, 'private func envelope(')
        self.assertLess(envelope.index('throw APIError.notConfigured'), envelope.index('transport.send'))
        city = (ROOT / 'Core/CityOriginalReceiptReading.swift').read_text()
        read = body(city, 'public func read(_ reference: CityOriginalReceiptReference) async throws')
        self.assertLess(read.index('throw CityOriginalReceiptReadFailure.disabled'), read.index('transport.send'))
        self.assertIn('request/\\(reference.requestID)', read)
        budget = (ROOT / 'Core/CityActionBudgetReader.swift').read_text()
        receipt = body(budget, 'func receipt(_ scope: CityActionBudgetScope, prepared: CityActionBudgetPrepared)')
        self.assertLess(receipt.index('throw CityActionBudgetFailure.disabled'), receipt.index('transport.send'))
        square = (ROOT / 'Core/SquareReportService.swift').read_text()
        original = body(square, 'func original(_ intent: SquareReportOriginalIntent')
        self.assertIn('intent.requestID', original)
        read_path = body(square, 'private func read(path: String')
        self.assertLess(read_path.index('throw SquareReportFailure.disabled'), read_path.index('transport.send'))
        team = (ROOT / 'Core/TeamHTTPService.swift').read_text()
        self.assertIn('func receipt(operationID: UUID, session: TeamSession) async throws -> TeamWriteOutcome? { nil }', team)
        registration = (ROOT / 'Core/RegistrationService.swift').read_text()
        self.assertIn('no lookup-by-requestId contract', registration)

    def test_payment_withdrawal_and_launch_defaults_stay_closed(self):
        gates = (ROOT / 'Core/MerchantCityNPCParityGates.swift').read_text()
        self.assertIn('public var stationCommands = false', gates)
        self.assertIn('public static var reviewedEndpoints: [RegionalMarket: Set<String>] { [.china: mpFirstChinaEndpoints] }', gates)  # MP-first 2026-11-25
        commerce = (ROOT / 'Core/MerchantAICommerceGates.swift').read_text()
        self.assertIn('public var paymentAndCashEnabled: Bool { false }', commerce)
        runtime = (ROOT / 'Core/BusinessRuntimeConfiguration.swift').read_text()
        self.assertIn('bankChallengeActions: Set<BankWithdrawalServerAction> = []', runtime)
        self.assertIn('selfPlayPayment: Bool = false', runtime)
        config = (ROOT / 'Config/Base.xcconfig').read_text()
        self.assertIn('MARKETING_VERSION = 0.1.0\n', config)
        self.assertIn('CURRENT_PROJECT_VERSION = 1\n', config)
        self.assertIn('QUESTIFY_API_BASE_URL =\n', config)
        self.assertIn('QUESTIFY_SESSION_REALM =\n', config)
        session = (ROOT / 'App/AppSession.swift').read_text()
        compiled = body(session, 'static var passwordLoginCompiledIn:Bool')
        self.assertIn('#else', compiled)
        self.assertIn('false', compiled)


if __name__ == '__main__':
    unittest.main()
