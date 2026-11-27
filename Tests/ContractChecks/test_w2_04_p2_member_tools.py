"""Source contracts only: not compiled Swift, real reads, or UI execution."""
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text()


class W204P2MemberToolsChecks(unittest.TestCase):
    def setUp(self):
        self.notice = read('Core/TicketWalletSourceNotice.swift')
        self.wallet = read('App/TicketWalletView.swift')
        self.complaint_core = read('Core/ProfileComplaintSourceCopy.swift')
        self.complaint_view = read('App/ProfileComplaintPreparationView.swift')
        self.invite_issue = read('App/ProfileInviteHistoryIssueView.swift')
        self.invite_view = read('App/SocialInviteHistoryView.swift')
        self.catalog = json.loads(read('Resources/Localizable.xcstrings'))['strings']

    def zh(self, key):
        return self.catalog[key]['localizations']['zh-Hans']['stringUnit']['value']

    def test_wallet_notices_are_display_only(self):
        # The restyled card names the state through the status badge and the schedule-sync/status-hint lines; the
        # per-row source-notice strip is mounted again for rows that do not open (cancelled/expired/unknown/payment).
        # Owner rule (MP 2026-10-28): no status badge on a wallet card; only the MP tag (PLY-21-5).
        self.assertIn('TicketWalletCardTag(ticket: ticket)', self.wallet)
        self.assertIn('Text("ticketWallet.p2.notice.scheduleSync")', self.wallet)
        self.assertIn('Text(LocalizedStringKey(ticket.sourceNoticeKey))', self.wallet)
        self.assertIn('if ticket.action != .detail {', self.wallet)
        self.assertNotIn('"ticketWallet.action." + ticket.action.rawValue', self.wallet)
        for token in ['URLSession', 'Task {', 'func pay', 'TeamCoordinator']:
            self.assertNotIn(token, self.notice)
        self.assertIn('var needsScheduleSync: Bool { action == .detail && (ownerID ?? 0) <= 0 }', self.notice)
        self.assertIn('if ticket.needsScheduleSync {', self.wallet)

    def test_wallet_source_toast_copy(self):
        self.assertEqual(self.zh('ticketWallet.p2.notice.cancelled'), '票已取消')
        self.assertEqual(self.zh('ticketWallet.p2.notice.expired'), '票已过期')
        self.assertEqual(self.zh('ticketWallet.p2.notice.unknown'), '票状态待确认')
        self.assertEqual(self.zh('ticketWallet.p2.notice.scheduleSync'), '场次信息待同步')

    def test_invite_summary_keeps_existing_total_row(self):
        # FIN-20-2: one hero section carries the total (已邀请 N 人, em dash via countText); no duplicate row.
        self.assertIn('ProfileInviteRewardReviewSection(review: .init(scan: model.scan), total: model.pagination.total', self.invite_view)
        self.assertNotIn('LabeledContent("social.invites.total"', self.invite_view)
        hero = read('App/ProfileInviteRewardReviewSection.swift')
        self.assertIn('ProfileInviteHistoryPageReady.countText(total)', hero)
        self.assertIn('Text("profile.inviteHistoryP2.summary \\(total)")', self.invite_issue)
        self.assertEqual(self.zh('profile.inviteHistoryP2.summary %lld'), '累计邀请 %lld 人')

    def test_complaint_load_failure_copy_keeps_native_line_and_retry(self):
        # mp-states r3 re-pin: current MP complaint wxml:19-31 titles (登录后发起投诉与查看进展 / 可投诉活动加载失败) on ContentUnavailableView.
        self.assertIn('Text(LocalizedStringKey(complaintStateTitleKey(issue)))', self.complaint_view)
        self.assertIn('.accessibilityIdentifier("profile.complaint.issue")', self.complaint_view)
        self.assertIn('if issue == .failed {', self.complaint_view)
        self.assertEqual(self.zh('profile.complaintP2.loadFailed.title'), '可投诉活动没能加载出来')
        self.assertEqual(self.zh('profile.complaintP2.loadFailed.generic'), '可投诉活动加载失败，请重试')
        self.assertEqual(self.zh('profile.complaintP2.loadFailed.signIn'), '登录状态已失效，请重新进入')

    def test_fragment_is_bilingual_and_merged(self):
        fragment = json.loads(read('Resources/W204P2MemberToolsLocalizations.fragment.json'))['strings']
        for key, entry in fragment.items():
            self.assertEqual(set(entry['localizations']), {'en', 'zh-Hans'})
            self.assertEqual(self.catalog[key], entry)

    def test_pinned_template_files_untouched_by_this_pass(self):
        # PLY-26-1: the host row offers the plan's one action through the reviewed shelf write; the card stays facts only.
        view = read('App/TemplateAuthoringMineView.swift')
        self.assertIn('TemplateOwnShelfCardSection', view)
        self.assertNotIn('/market-submit', view)
        self.assertIn('if let market = TemplateOwnShelfMarketPlan(state).action {', view)
        self.assertIn('public var isDispatchable: Bool { action != nil }', read('Core/TemplateOwnShelfMarketPlan.swift'))
        card = read('App/TemplateOwnShelfCardSection.swift')
        self.assertIn('the host row owns the action, so this view', card)
        for token in ['Button', 'NavigationLink', 'URLSession', 'Task {', 'market-submit']:
            self.assertNotIn(token, card)


if __name__ == '__main__':
    unittest.main()
