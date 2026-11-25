"""w2-04 signup parity: source contracts only, not compiled Swift or UI execution."""
import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text()


class W204TicketWalletParity(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.view = read('App/TicketWalletView.swift')
        cls.copy = read('Core/TicketWalletSourceCopy.swift')
        cls.catalog = json.loads(read('Resources/Localizable.xcstrings'))['strings']
        cls.fragment = json.loads(read('Resources/W204TicketWalletLocalizations.fragment.json'))['strings']

    def zh(self, key):
        return self.catalog[key]['localizations']['zh-Hans']['stringUnit']['value']

    def test_source_copy_is_exact(self):
        expected = {'ticketWallet.loading': '加载中…', 'ticketWallet.empty': '还没有票',
                    'ticketWallet.issue.login': '登录后查看票夹', 'ticketWallet.parity.error.title': '票夹没能打开',
                    'ticketWallet.parity.login.detail': '登录后可查看你报名的路线票和场次票',
                    'ticketWallet.parity.empty.detail': '去首页发现路线或报名场次，票会在这里出现。',
                    'ticketWallet.parity.untitled.route': '路线信息待同步',
                    'ticketWallet.parity.untitled.activity': '活动信息待同步',
                    'ticketWallet.parity.hint.ready': '进入游玩'}
        for key, value in expected.items():
            self.assertEqual(self.zh(key), value, key)

    def test_fragment_is_bilingual_and_merged_unchanged(self):
        for key, entry in self.fragment.items():
            self.assertEqual(set(entry['localizations']), {'en', 'zh-Hans'})
            self.assertEqual(self.catalog[key], entry)

    def test_full_failure_title_and_empty_hint_do_not_claim_partial_empty(self):
        self.assertIn('Text("ticketWallet.parity.error.title")', self.view)
        empty = self.view.split('if snapshot.tickets.isEmpty {', 1)[1].split('ForEach(', 1)[0]
        # MP empty is「还没有票」with no sub line (PLY-21-11); a partial read still never claims the wallet is empty.
        self.assertIn('snapshot.partialFailure == nil ? "ticketWallet.empty" : "ticketWallet.partialEmpty"', empty)
        self.assertNotIn('ticketWallet.parity.empty.detail', empty)
        # MP F-R2U-01 (PLY-21-10): the failed lane is a quiet meta note, never the full-failure title.
        partial = self.view.split('if let partial = model.value(owner: key)?.partialFailure {', 1)[1].split('}', 1)[0]
        self.assertIn('.cyText(.meta)', partial)
        self.assertNotIn('ticketWallet.parity.error.title', partial)

    def test_hint_and_title_are_presentation_only(self):
        self.assertIn('TicketWalletTitle(title: ticket.title, untitledKey: ticket.untitledKey)', self.view)
        # Owner rule: no status on the card; the stub carries the MP sub-line (类型 · 剩 N 天) instead (PLY-21-5).
        self.assertIn('if let type = ticket.walletTypeKey {', self.view)
        self.assertNotIn('TicketWalletStatusBadge(status: ticket.status)', self.view)
        body = self.copy.split('public extension TicketWalletTicket {', 1)[1]
        for forbidden in ['action', 'Task {', 'transport', 'URLRequest', 'send(']:
            self.assertNotIn(forbidden, body)
        self.assertIn('status == .ready ? "ticketWallet.parity.hint.ready" : nil', self.copy)

    def test_ready_rows_still_open_detail_first(self):
        # Direct play would bypass the tested fresh-detail gate; parity records this gap.
        # Upcoming / refunding tickets are locked (MP wLocked) and do not open.
        self.assertIn('if ticket.action == .detail && !ticket.isWalletLocked {\n                            NavigationLink {\n                                TicketWalletDetailView(', self.view)
        self.assertNotIn('ticketWalletPlayProvider', self.view)

    def test_list_request_sends_page_size_ten(self):
        # PLY-21-14: the wallet list sends pageNum and pageSize 10, matching signup.js.
        service = read('Core/TicketWalletService.swift')
        self.assertIn('"pageNum": String(page)', service)
        self.assertIn('"pageSize": String(Self.pageSize)', service)
        self.assertIn('public static let pageSize = 10', service)


if __name__ == '__main__':
    unittest.main()
