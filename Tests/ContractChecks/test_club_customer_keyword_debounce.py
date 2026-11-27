"""P044 keyword source checks, not Swift execution or Apple target admission.

Reads the live tree. The former frozen club_keyword_context snapshot hashed
unrelated files (.github/workflows/native-ios.yml) and crashed the module at
import; the byte-restore checks against the published P044 base were dropped
with it (see docs/release/receipts/debt-contracts-a.md). The keyword moved into
ClubCustomerFilters and the system search bar in 5a223a87b (CLB-customers-07).
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
PATH = 'App/ClubGovernanceViews.swift'


class ClubCustomerKeywordDebounceContracts(unittest.TestCase):
    def source(self): return (ROOT / PATH).read_text()

    def test_keyword_input_is_wired_and_confirm_and_filter_cancel_first(self):
        source = self.source()
        keyword = source.split('private var customerKeywordBinding: Binding<String> {', 1)[1].split('}\n    }', 1)[0]
        self.assertIn('guard customerFilters.keyword != value else { return }', keyword)
        self.assertIn('scheduleCustomerKeywordRead()', keyword)
        flt = source.split('private var customerFilterBinding: Binding<String> {', 1)[1].split('}\n    }', 1)[0]
        self.assertIn('loadCustomersNow()', flt)
        self.assertIn('.searchable(text: text, prompt: Text("club.gov.keyword"))', source)
        self.assertIn('.onSubmit(of: .search) { submit() }', source)
        self.assertIn('ClubCustomerKeywordSearch(enabled: operation == .customers, text: customerKeywordBinding', source)
        self.assertIn('submit: { loadCustomersNow() }', source)
        body = source.split('private func loadCustomersNow()', 1)[1].split('private func scheduleCustomerKeywordRead()', 1)[0]
        self.assertLess(body.index('customerKeywordDebounce.cancel()'), body.index('Task { await load() }'))

    def test_production_delay_and_generation_cancellation(self):
        body = self.source().split('/// The customers keyword is the system bar search field', 1)[0]
        for text in ['delayNanoseconds: UInt64 = 300_000_000',
                     'try await Task.sleep(nanoseconds: ClubCustomerKeywordDebounce.delayNanoseconds)',
                     'pending?.cancel()', 'revision &+= 1',
                     'guard !Task.isCancelled, self.revision == expected else { return }',
                     'do { try await self.sleep() } catch { return }']:
            self.assertIn(text, body)
        self.assertLess(body.index('self.pending = nil'), body.index('await action()'))

    def test_old_response_is_retired_before_the_debounce_wait(self):
        body = self.source().split('private func scheduleCustomerKeywordRead()', 1)[1].split('private func load() async', 1)[0]
        for text in ['guard operation == .customers else { return }', 'generation &+= 1',
                     'snapshot = nil; snapshotContext = nil', 'context == readContext', 'expected == identity',
                     'access.identity == expected', 'keywordRevision == generation',
                     'customerFilters.keyword == expectedKeyword', 'customerFilters.filter == expectedFilter',
                     '!Task.isCancelled']:
            self.assertIn(text, body)
        self.assertLess(body.index('generation &+= 1'), body.index('customerKeywordDebounce.schedule'))

    def test_refresh_disappear_and_context_invalidation_cancel_pending_work(self):
        source = self.source()
        self.assertIn('.onDisappear {\n            if operation == .customers {\n                customerKeywordDebounce.cancel()\n                generation &+= 1', source)
        self.assertIn('let keywordRevision = generation', source)
        for start in ['private func load() async {', 'private func invalidateRead() {']:
            body = source.split(start, 1)[1].split('\n    @MainActor private func', 1)[0]
            self.assertIn('if operation == .customers { customerKeywordDebounce.cancel() }', body)
        self.assertIn('.refreshable { await load() }', source)
        self.assertIn('.task(id: readContext) { await synchronizeReadContext() }', source)

    def test_payload_and_final_transport_fences_are_unchanged(self):
        source = self.source()
        self.assertIn('let customerQuery = customerFilters', source)
        self.assertIn('if operation == .customers { options = ["filter": .string(customerQuery.filter), "keyword": .string(customerQuery.keyword)] }', source)
        self.assertNotIn('keyword.trimmingCharacters', source)
        self.assertIn('access.identity == expected, !Task.isCancelled else { return }', source)
        self.assertIn('guard context.accepts(result) else { throw ClubGovernanceFailure.targetChanged }', source)

    def test_swift_timer_tests_are_authored_without_runtime_claims(self):
        source = (ROOT / 'Tests/AppUnitTests/ClubCustomerKeywordDebounceTests.swift').read_text()
        self.assertGreaterEqual(source.count('    func test'), 6)
        self.assertIn('NOT_RUN', source)
        self.assertIn('XCTAssertFalse(Task.isCancelled)', source)
        self.assertIn('SleeperIgnoresCancellation', source)


if __name__ == '__main__': unittest.main()
