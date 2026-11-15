from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]

class JourneyCheckCancelledEntryTests(unittest.TestCase):
    def test_recovery_metadata_is_projected_from_live_owner(self):
        code = (ROOT / 'Core/JourneyCheckCoordinator.swift').read_text()
        for field in ('pending', 'issue'):
            projection = code.split('public private(set) var ' + field + ':', 1)[1].split('\n    }', 1)[0]
            self.assertIn('identity != nil && identity == currentSession()', projection)
            self.assertIn(': nil }', projection)
        self.assertIn('public var available: Bool { service.checksEnabled && !nodeDone && identity != nil && identity == currentSession() }', code)
        self.assertIn('public var canRecover: Bool { unknown && pending != nil && !acting && available }', code)

    def test_cancelled_probe_cannot_consume_probe_or_change_node(self):
        code = (ROOT / 'Core/JourneyCheckCoordinator.swift').read_text()
        probe = code.split('public func probe(nodeDone: Bool) async {', 1)[1].split('public func reopen()', 1)[0]
        self.assertTrue(probe.lstrip().startswith('guard !Task.isCancelled else { return }'))
        self.assertLess(probe.index('guard !Task.isCancelled'), probe.index('probed = true'))

    def test_cancelled_confirm_is_fenced_before_journal_and_review_mutation(self):
        code = (ROOT / 'Core/JourneyCheckCoordinator.swift').read_text()
        confirm = code.split('public func confirm(_ approved: JourneyCheckReview) async {', 1)[1]
        self.assertTrue(confirm.lstrip().startswith('guard !Task.isCancelled else { return }'))
        self.assertLess(confirm.index('guard !Task.isCancelled'), confirm.index('journal.save('))
        self.assertIn('review = nil; pending = approved; acting = true', confirm)
        self.assertIn('unknown = true // Cancellation, malformed success and transport loss are not rejection.', confirm)

    def test_runtime_regressions_cover_retry_and_existing_unknown(self):
        tests = (ROOT / 'Tests/CoreTests/JourneyContentTests.swift').read_text()
        for name in ('testCancelledProbeDoesNotConsumeOptionalReadOpportunity',
                     'testCancelledConfirmationKeepsReviewAndDoesNotCreateJournal',
                     'testCancelledUnknownRecoveryPreservesOriginalJournalAndReview'):
            self.assertIn('func ' + name, tests)

if __name__ == '__main__':
    unittest.main()
