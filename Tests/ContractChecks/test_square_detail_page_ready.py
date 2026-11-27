"""CB267 page-ready contract for pages/square/detail/index. Source and JSON only."""
import json
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
NOTE = ROOT / "docs/release/page-ready/pages-square-detail-index.md"
MODEL = ROOT / "Core/SquareXcxPresentation.swift"
TESTS = ROOT / "Tests/CoreTests/SquareDetailInteractionTests.swift"
DECODER = ROOT / "Core/SquareContracts.swift"
VIEW = ROOT / "App/SquareDetailView.swift"
LEDGER = ROOT / "Core/MiniProgramPageByPage99DecisionLedgerContract.swift"

# C-S3 (fix-parity2): 动态加载失败 / 这条帖文暂不可用 / 没有找到这条帖文 are now in the catalog (SquareDetailIssueView).
# Comment failures are in the catalog too (fixr3.square.commentsFailed / moreCommentsFailed),
# matching pages/square/detail/index.wxml:124 and :172.
MISSING_COPY = [
    # mp-activity r3: 服务暂时无法提供这条动态 / 网络异常，请检查连接后重试 / 正在加载更多评论… are now catalog keys
    # (mpr3.square.detail.serviceError / networkError / loadingMoreComments, MP index.js:1040-1086, index.wxml:171).
    "回复评论",
    "转发帖文",
    # "收藏帖文" now exists: fix-parity C-S2 (square detail favourite label, square.bookmark.add).
    "打开用户主页",
    "更多操作",
    "查看大图",
    "评论已发送，计数请刷新查看",
    "选择举报原因",
]
# medalGold / medalSilver / medalBronze are decoded since r8 (45f2b0991, SquareContracts info.medal*; nil when absent).
MISSING_FIELDS = [
    "distanceText",
    "shopText",
    "durationText",
    "kudosAvatars",
    "kudosText",
    "commentNick",
    "commentText",
    "sportSubtitle",
    "isFollowTheUser",
]


# social.portfolio.preview shares the words 查看大图 (cy-profile index.wxml:521).
# Square detail's own image label (pages/square/detail/index.wxml:95) is still missing.
# im.reportPeer.pickHeader is the IM peer-report sheet (选择举报原因); square detail's own report picker is still missing.
UNRELATED_KEYS = {"ui.cloud05.admission.more", "share.title", "share.entry", "social.portfolio.preview", "im.reportPeer.pickHeader"}


def catalog_values():
    values = set()
    for path in (ROOT / "Resources").glob("*.xcstrings"):
        document = json.loads(path.read_text(encoding="utf-8"))
        for key, entry in (document.get("strings") or {}).items():
            # An unrelated admission-menu key now shares the words "更多操作"; it is not a square-detail key.
            if key in UNRELATED_KEYS:
                continue
            for node in (entry.get("localizations") or {}).values():
                value = (node.get("stringUnit") or {}).get("value")
                if isinstance(value, str):
                    values.add(value)
    return values


class SquareDetailPageReadyContract(unittest.TestCase):
    def test_note_lists_missing_keys_and_leaves_the_view_alone(self):
        note = NOTE.read_text(encoding="utf-8")
        self.assertIn("pages/square/detail/index", note)
        self.assertIn("SquareDetailPageModel", note)
        self.assertIn("—", note)
        self.assertNotIn("ui-strings-pages-square-detail-index.json", note)
        for sentence in MISSING_COPY:
            self.assertIn(sentence, note)
            self.assertNotIn(sentence, catalog_values())
        for field in MISSING_FIELDS:
            self.assertIn("- %s" % field, note)
            self.assertNotIn(field, DECODER.read_text(encoding="utf-8"))
        view = VIEW.read_text(encoding="utf-8")
        self.assertIn("SquareCountDisplay.text(post.likeCount)", view)
        self.assertIn("SquareDetailPageModel.emptyCommentsTitleKey", view)
        # visual-parity-2: empty comments show only 还没有评论 (the mini-program dropped the detail line).
        self.assertNotIn("SquareDetailPageModel.emptyCommentsDetailKey", view)
        self.assertNotIn('"square.xcx.noCommentsTitle"', view)
        self.assertNotIn("square.xcx.noCommentsDetail", view)

    def test_model_keeps_states_unknown_dash_and_does_not_mark_a_route(self):
        model = MODEL.read_text(encoding="utf-8")
        self.assertIn("case loading", model)
        self.assertIn("case empty", model)
        self.assertIn("case error(titleKey: String, serverMessage: String?)", model)
        self.assertIn("case unknown", model)
        self.assertIn('public static let unknownMark = "\\u{2014}"', model)
        self.assertIn("public static let blockRouteIsLive = false", model)
        self.assertIn("ChinaReviewedRouteCapability.mark(for: path) == .liveInProduction", model)
        self.assertNotIn("URLSession", model)
        self.assertNotIn("httpMethod", model)
        self.assertNotRegex(model, r"liveInProduction\s*=")
        for path in (
            "/api/creativesquare/info",
            "/api/v1/community/posts/{}",
            "/api/comment/list",
            "/api/v1/community/posts/{}/comments",
        ):
            self.assertIn('"%s"' % path, model)
        debug = model.split("#if DEBUG", 1)[1].split("#endif", 1)[0]
        self.assertIn("enum SquareDetailPageFixtureData", debug)
        decoder = DECODER.read_text(encoding="utf-8")
        self.assertIn('likeCount = SquareCountDisplay.known(post.first("likeCount", "likeNum").number)', decoder)
        self.assertIn('commentCount = SquareCountDisplay.known(post["commentCount"].number)', decoder)
        ledger = LEDGER.read_text(encoding="utf-8")
        self.assertIn('"pages/square/detail/index"', ledger)

    def test_swift_tests_were_added_without_removing_existing_ones(self):
        tests = TESTS.read_text(encoding="utf-8")
        names = re.findall(r"func (test\w+)", tests)
        self.assertGreaterEqual(len(names), 12)
        self.assertEqual(len(names), len(set(names)))
        for kept in (
            "testCommentOnPostSendsOnlyAfterConfirmAndShowsAcknowledgement",
            "testReplyToCommentTargetsThatComment",
            "testCommentLikeToggleIsOneReviewedWrite",
            "testServerRejectionIsNeverShownAsAcknowledged",
            "testDisabledAvailabilityNeverSends",
            "testBlockEntryIsOnlyForOthersAndIsHonestlyNotAvailable",
            "testUnknownMarkIsAnEmDashAndNotZero",
            "testOmittedCountsStayUnknownAndLiteralZeroStaysZero",
        ):
            self.assertIn(kept, names)
        self.assertNotIn("http://", tests)
        self.assertNotIn("https://", tests)
        self.assertFalse((ROOT / "docs/release/ui-strings-pages-square-detail-index.json").exists())


if __name__ == "__main__":
    unittest.main()
