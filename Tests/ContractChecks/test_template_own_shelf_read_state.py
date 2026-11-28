"""我的节点玩法 read-state copy. Source strings only; Swift is not executed."""
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]

# chengyinhub-xcx/subpackageMember/mytemplate/mytemplate.wxml lines 13, 119, 121, 125, 130–135.
# Failure title and the kept-list line are the same page's getList/handleListError fallbacks.
COPY = {
    'templateOwnShelf.read.signIn': '登录后查看我的节点玩法',
    'templateOwnShelf.read.signInHint': '登录后可管理当前账号创作的节点玩法',
    'templateOwnShelf.read.signInAction': '登录',
    'templateOwnShelf.read.denied': '当前身份不能查看这些模板',  # MP subpackageA/pages/myproject/index.wxml:110
    'templateOwnShelf.read.deniedHint': '请确认当前账号的查看权限',
    'templateOwnShelf.read.loading': '正在加载你的节点玩法',
    'templateOwnShelf.read.failed': '玩法草稿没加载出来',  # handbook wording, design hand-off r1 CF-70 (owner default Q-E),
    'templateOwnShelf.read.retry': '重试',
    'templateOwnShelf.read.failedKept': '刷新失败，请重试',
    'templateOwnShelf.read.empty': '还没有节点玩法',
    'templateOwnShelf.read.emptyHint': '发布路线时可以沉淀自己的节点互动，之后在这里复用和管理。',
    'templateOwnShelf.read.moreFailed': '更多玩法没有加载出来',
    'templateOwnShelf.read.moreFailedHint': '玩法草稿加载失败',
    'templateOwnShelf.read.loadingMore': '正在加载更多',  # no ellipsis, CF-69,
    'templateOwnShelf.read.loadMore': '加载更多',
    'templateOwnShelf.read.loadMoreLabel': '加载更多节点玩法',
}


def read(path):
    return (ROOT / path).read_text()


class TemplateOwnShelfReadStateContract(unittest.TestCase):
    def setUp(self):
        self.fragment = json.loads(read('Resources/TemplateOwnShelfReadStateLocalizations.fragment.json'))
        self.view = read('App/TemplateAuthoringMineView.swift')
        self.core = read('Core/TemplateAuthoringShelf.swift')
        self.catalog = read('Resources/Localizable.xcstrings')

    def test_fragment_is_the_mini_wording_and_is_merged(self):
        strings = self.fragment['strings']
        self.assertEqual(set(strings), set(COPY))
        for key, value in COPY.items():
            row = strings[key]['localizations']
            self.assertEqual(set(row), {'en', 'zh-Hans'})
            self.assertEqual(row['zh-Hans']['stringUnit']['value'], value)
            # The English side is now a real translation (it was once the Chinese mini wording verbatim).
            en = row['en']['stringUnit']['value']
            self.assertTrue(en.strip())
            self.assertFalse(any('\u4e00' <= ch <= '\u9fff' for ch in en), key)
            # The fragment has since been merged into the live catalog.
            self.assertIn('"%s"' % key, self.catalog)

    def test_mine_view_uses_the_read_states_without_a_new_login_route(self):
        for key in COPY:
            self.assertIn(key, self.view)
        self.assertIn('readMessageKey == "templateAuthor.signIn"', self.view)
        self.assertIn('readMessageKey == "templateOwnShelf.read.denied" || !coordinator.canRead', self.view)
        self.assertIn('readMessageKey == "templateAuthor.listUnavailable", rows.isEmpty', self.view)
        self.assertIn('Text("templateOwnShelf.read.failedKept")', self.view)
        self.assertIn('readMessageKey == "templateAuthor.shelf.empty"', self.view)
        self.assertIn('readMessageKey == "templateAuthor.shelf.moreFailed"', self.view)
        self.assertIn('Text("templateOwnShelf.read.loadingMore")', self.view)
        self.assertIn('.accessibilityIdentifier("templateAuthor.shelf.loadMore")', self.view)
        self.assertNotIn('retryLogin', self.view)
        # mp-states r3: 登录 is a real button (root sign-in sheet) or nothing; the dead footnote text is gone.
        self.assertNotIn('else { Text(action)', self.view)
        self.assertIn('perform: rootSignIn.signedOutAction(fallback: rootTabSwitch)', self.view)

    def test_failure_snapshot_market_and_owner_bounds_stay(self):
        self.assertIn('(requested == 1 && !Self.isTransientRefreshFailure(error)) || Self.invalidatesReadScope(error) { leave() }', self.core)
        self.assertIn('rows = snapshot; isShowingRefreshSnapshot = !snapshot.isEmpty', self.core)
        self.assertIn('messageKey = requested == 1 ? Self.firstPageFailureKey(error) : "templateAuthor.shelf.moreFailed"', self.core)
        self.assertIn('if case APIError.unauthorized = error { return "templateAuthor.signIn" }', self.core)
        self.assertIn('if status == 403 { return "templateOwnShelf.read.denied" }', self.core)
        self.assertIn('return "templateAuthor.listUnavailable"', self.core)
        # PLY-26-1: the square action comes from the mini-program market plan, never from publishStatus.
        self.assertIn('if let market = TemplateOwnShelfMarketPlan(state).action {', self.view)
        self.assertNotIn('row.publishStatus == 1 ? "templateAuthor.shelf.removeLibrary"', self.view)
        self.assertIn('guard !busy, appliedKeyword == keyword, !coordinator.shelfReader.isShowingRefreshSnapshot else { return }', self.view)
        self.assertEqual(self.view.count('.disabled(!coordinator.canSubmit || locked || busy || !coordinator.rows.contains(row))'), 2)
        self.assertIn('Text("templateAuthor.unavailable")', self.view)
        # Request paths stay in TemplateAuthoringContract; the shelf reader and the view build none.
        self.assertNotIn('/market-submit', self.core + self.view)
        self.assertIn('var opens: Bool { topicID > 0 }', read('App/CooperationProjectNavigation.swift'))


if __name__ == '__main__':
    unittest.main()
