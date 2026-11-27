"""Source contracts for w2-04 mycanyu/mycanyuinfo parity; not Swift compiler or UI evidence."""
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text()


class ParticipationParityChecks(unittest.TestCase):
    def setUp(self):
        self.core = read('Core/ParticipationParity.swift')
        self.views = read('App/ParticipationParityViews.swift')
        self.journey = read('App/PlayerJourneyViews.swift')

    def test_list_uses_fill_tabs_and_source_status_filter(self):
        history = self.journey.split('@MainActor struct ParticipationHistoryView: View {', 1)[1].split('private struct ParticipationRow: View {', 1)[0]
        self.assertIn('.cyAdaptiveSegmented().accessibilityIdentifier("playerJourney.filter")', history)
        self.assertNotIn('.pickerStyle(.menu)', history)
        self.assertIn('rows.filter { filter.matches($0) }', history)
        self.assertIn('LocalizedStringKey(filter.emptyTitleKey)', history)
        self.assertIn('LocalizedStringKey(filter.emptyDetailKey)', history)

    def test_refresh_snapshot_is_silent_but_unauthorized_still_clears(self):
        history = self.journey.split('@MainActor struct ParticipationHistoryView: View {', 1)[1].split('private struct ParticipationRow: View {', 1)[0]
        self.assertIn('if error as? APIError == .unauthorized { rows = nil; resetPresentation() }', history)
        self.assertIn('issue = rows == nil ? ParticipationLoadIssue(error, detail: false) : nil', history)
        self.assertIn('Text("playerJourney.parity.refreshing")', history)
        self.assertNotIn('playerJourney.refreshFailed', history)

    def test_status_projection_keeps_shared_summary_unchanged(self):
        shared = read('Core/OrderLifecycleContracts.swift')
        self.assertNotIn('firstSuccessfulScanAt', shared)
        self.assertNotIn('cancelTime', shared)
        for text in ['let base = order.summary(now: now).state',
                     'OrderLifecycleTime.date(parity.activityCancelTime) != nil',
                     'order.paymentStatus == 2, OrderLifecycleTime.date(parity.firstSuccessfulScanAt) != nil',
                     '!parity.isFree, order.refundable == false']:
            self.assertIn(text, self.core)
        self.assertLess(self.core.index('case .manualRefund, .refunding, .refunded'), self.core.index('parity.activityCancelTime) != nil'))

    def test_cancel_visibility_is_display_only(self):
        for text in ['URLSession', 'transport.send', 'HTTPTransport', 'Task {', 'UserDefaults', 'func cancel(', 'func refund(']:
            self.assertNotIn(text, self.core)
            self.assertNotIn(text, self.views)
        detail = self.journey.split('@MainActor struct ParticipationDetailView: View {', 1)[1].split('@MainActor struct CompletedPlayHistoryView', 1)[0]
        self.assertIn('OrderLifecycleView(id: id, coordinator: lifecycle).id(lifecycle.scope)', detail)
        self.assertIn('detail.sourceCanCancel() ? "playerJourney.cancellation" : "playerJourney.orderProgress"', detail)
        self.assertIn('if detail.showsContactService() {', detail)
        self.assertIn('order.refundable == true', self.core)
        # 需修改 shows 去修改 and hides 取消参与 / 联系客服. Cancel and 开始游戏 stay on their existing paths.
        contracts = read('Core/PlayerJourneyContracts.swift')
        self.assertIn('needsModification = raw["displayStatus"].text == "需修改"', contracts)
        self.assertIn('guard !needsModification else { return false }', self.core)
        self.assertIn('!sourceCanCancel(now: now) && !needsModification', self.core)
        bottom = detail.split('.safeAreaInset(edge: .bottom)', 1)[1].split('.navigationDestination(item: $merchantApplyID)', 1)[0]
        self.assertIn('Button("playerJourney.start", systemImage: "play.fill") { open(.play(target)) }', bottom)
        self.assertIn('Button("playerJourney.start", systemImage: "ticket") { open(.ticketWallet) }', bottom)
        modify = bottom.split('if detail.needsModification {', 1)[1]
        self.assertEqual(bottom.count('if detail.needsModification {'), 1)
        self.assertIn('Button("participation.editMerchantApply") {', modify)
        self.assertIn('guard id > 0 else { return }', modify)
        self.assertIn('merchantApplyID = id', modify)
        self.assertNotIn('POST', modify)
        self.assertNotIn('open(.play', modify)
        self.assertNotIn('open(.ticketWallet)', modify)
        destination = detail.split('.navigationDestination(item: $merchantApplyID)', 1)[1].split('.task(id: reader.scope)', 1)[0]
        self.assertIn('MPReviewedPageScreen(page: "pages/topic/merchantapply/index", query: ["mode": "1", "id": String(registrationID)])', destination)
        self.assertNotIn('公告', detail)
        self.assertNotIn('open-type', detail)
        self.assertNotIn('playerJourney.modifyNeedsReview', detail)
        catalog = json.loads(read('Resources/Localizable.xcstrings'))['strings']['participation.editMerchantApply']
        self.assertEqual(set(catalog['localizations']), {'en', 'zh-Hans'})
        self.assertEqual(catalog['localizations']['zh-Hans']['stringUnit']['value'], '去修改')

    def test_detail_header_stats_and_fixed_rules(self):
        detail = self.journey.split('@MainActor struct ParticipationDetailView: View {', 1)[1].split('@MainActor struct CompletedPlayHistoryView', 1)[0]
        self.assertIn('ParticipationDetailHeader(detail: detail)', detail)
        self.assertIn('ProgressView("playerJourney.parity.detailLoading")', detail)
        self.assertIn('Text("playerJourney.parity.fixedRules")', detail)
        self.assertIn('"playerJourney.parity.finalNode"', detail)
        self.assertIn('detail.pendingText', detail)
        self.assertIn('detail.verifiedText) \\(detail.totalText)', detail)
        self.assertIn('ProfileParticipationSchedule(', self.views)
        self.assertIn('Text("playerJourney.parity.countdown \\(days)")', self.views)

    def test_fragment_bilingual_and_merged(self):
        fragment = json.loads(read('Resources/W204ParticipationLocalizations.fragment.json'))['strings']
        catalog = json.loads(read('Resources/Localizable.xcstrings'))['strings']
        self.assertEqual(len(fragment), 22)
        for key, entry in fragment.items():
            self.assertEqual(set(entry['localizations']), {'en', 'zh-Hans'})
            self.assertEqual(catalog.get(key), entry, key)
        zh = lambda key: fragment[key]['localizations']['zh-Hans']['stringUnit']['value']
        self.assertEqual(zh('playerJourney.parity.listFailed'), '参与记录没能打开')
        self.assertEqual(zh('playerJourney.parity.filteredEmpty'), '当前筛选暂无参与记录')
        # MP player-facing rules sentence (component wxml:113, PLY-23-5).
        self.assertTrue(zh('playerJourney.parity.fixedRules').startswith('退出与暂停规则：'))
        used = set(re.findall(r'"(playerJourney\.parity\.[A-Za-z.]+)"', self.core + self.views + self.journey))
        used = {key for key in used if not key.endswith('.')}
        self.assertFalse(used - {key.split(' ')[0] for key in fragment}, used)

    def test_core_tests_present(self):
        tests = read('Tests/CoreTests/ParticipationParityTests.swift')
        self.assertEqual(len(re.findall(r'func test\w+\(', tests)), 9)


if __name__ == '__main__':
    unittest.main()
