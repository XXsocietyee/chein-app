"""CB281 page-ready contract for pages/mylike/mylike. Source and JSON only."""
import json
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
NOTE = ROOT / "docs/release/page-ready/pages-mylike-mylike.md"
MODEL = ROOT / "Core/AccountCollectionContracts.swift"
TESTS = ROOT / "Tests/CoreTests/AccountCollectionTests.swift"
POSTS = ROOT / "Tests/CoreTests/AccountCollectionPostTests.swift"
DECODER = ROOT / "Core/SquareContracts.swift"
TOPICS = ROOT / "Core/TopicContracts.swift"
VIEW = ROOT / "App/AccountCollectionFavoritesView.swift"
LEDGER = ROOT / "Core/MiniProgramPageByPage99DecisionLedgerContract.swift"
ROUTES = ROOT / "Core/ChinaReviewedRouteCapability.swift"

MISSING_COPY = [
    "收藏没能加载出来",
    "看到想留着慢慢看的动态，可以点星标收藏。",
    "收藏帖文加载失败",
    "喜欢列表加载失败",
    "分享主题",
    "收藏主题",
    "查看收藏的动态",
    "分享一条城瘾动态",
    "推荐路线：",
    "分享成功",
    "分享取消",
    "网络错误，请重试",
    "未通过审核 · 仅自己可见",
    "查看路线图",
    "转发帖文",
    # "收藏帖文" now exists: fix-parity C-S2 (square detail favourite label, square.bookmark.add).
]
MISSING_FIELDS = [
    "status",
    "link",
    "imgArr",
    "endDate",
    "total",
    "isFollowTheUser",
    "medalGold",
    "medalSilver",
    "medalBronze",
    "distanceText",
    "shopText",
    "durationText",
    "kudosAvatars",
    "kudosText",
    "commentNick",
    "commentText",
]
KEPT_COLLECTION_TESTS = [
    "testFavoriteExactContractAndEnvelopeVariants",
    "testMissingNullOrMalformedCollectionsNeverBecomeSuccessfulEmpty",
    "testPaginationDeduplicatesRawPagesAndRetriesSamePageWithoutLosingRows",
]
KEPT_POST_TESTS = [
    "testExactPrivateCollectionContractAndLegacyRouteGeneration",
    "testMissingMalformedOrWrongGenerationRowsNeverBecomeEmptySuccess",
]
ADDED_TESTS = [
    "testUnknownMarkIsAnEmDashAndNotZero",
    "testOmittedPostCountsStayUnknownAndLiteralZeroStaysZero",
    "testNumericStringFractionAndBooleanCountsStayUnknown",
    "testReadyPostKeepsLiteralCountsAndIgnoresTotal",
    "testTopicCountsKeepLiteralZeroAndDoNotReadANumericStringAsZero",
    "testEmptyRowsStayEmptyAndAMissingListStaysUnknown",
    "testFailureLoadingAndRejectedShapesStaySeparate",
    "testExistingFavoriteRoutesStayLiveWithoutANewMark",
]


# Other pages reuse a few sentences this page still does not catalog.
# They are not my-like keys. Do not add those sentences here to clear the note,
# and do not point the favorites view at AccountCollectionFavoritesPageModel.
UNRELATED_KEYS = {
    "share.title",
    "share.entry",  # 转发帖文
    "topic.share.mp",  # 分享主题
    "topic.favorite.add",  # 收藏主题
    "club.follow.networkFailed",  # 网络错误，请重试
}


def catalog_values():
    values = set()
    for path in (ROOT / "Resources").glob("*.xcstrings"):
        document = json.loads(path.read_text(encoding="utf-8"))
        for key, entry in (document.get("strings") or {}).items():
            if key in UNRELATED_KEYS:
                continue
            for node in (entry.get("localizations") or {}).values():
                value = (node.get("stringUnit") or {}).get("value")
                if isinstance(value, str):
                    values.add(value)
    return values


class MyLikePageReadyContract(unittest.TestCase):
    def test_note_lists_missing_keys_and_leaves_the_view_alone(self):
        note = NOTE.read_text(encoding="utf-8")
        catalog = catalog_values()
        self.assertIn("pages/mylike/mylike", note)
        self.assertIn("AccountCollectionFavoritesPageModel", note)
        self.assertIn("—", note)
        self.assertNotIn("ui-strings-pages-mylike-mylike.json", note)
        for sentence in MISSING_COPY:
            self.assertIn(sentence, note)
            self.assertNotIn(sentence, catalog)
        for field in MISSING_FIELDS:
            self.assertIn("- %s" % field, note)
        view = VIEW.read_text(encoding="utf-8")
        self.assertNotIn("AccountCollectionFavoritesPageModel", view)
        self.assertIn("SquarePostContent", view)
        self.assertFalse((ROOT / "docs/release/ui-strings-pages-mylike-mylike.json").exists())

    def test_model_keeps_states_unknown_dash_and_does_not_mark_a_route(self):
        model = MODEL.read_text(encoding="utf-8")
        self.assertIn("case loading", model)
        self.assertIn("case empty", model)
        self.assertIn("case error(titleKey: String, serverMessage: String?)", model)
        self.assertIn("case unknown", model)
        self.assertIn('public static let unknownMark = "\\u{2014}"', model)
        self.assertIn("ChinaReviewedRouteCapability.mark(for: path) == .liveInProduction", model)
        self.assertNotIn("URLSession", model)
        self.assertNotIn("httpMethod", model)
        self.assertNotRegex(model, r"liveInProduction\s*=")
        for field in ("medalGold", "imgArr", "isFollowTheUser", "distanceText", "kudosText"):
            self.assertNotIn(field, model)
        self.assertNotIn('object["total"]', model)
        self.assertNotIn('object["status"]', model)
        self.assertNotIn('object["endDate"]', model)
        self.assertIn('public static let postsPath = "/api/creativesquare/list"', model)
        self.assertIn('public static let topicsPath = "/api/topic/like_list"', model)
        self.assertIn("enum AccountCollectionFavoritesPageFixtureData", model)
        decoder = DECODER.read_text(encoding="utf-8")
        self.assertIn('likeCount = SquareCountDisplay.known(post.first("likeCount", "likeNum").number)', decoder)
        self.assertIn('commentCount = SquareCountDisplay.known(post["commentCount"].number)', decoder)
        self.assertIn('nodeTotal = root["nodeTotal"].number ?? 0', decoder)
        topics = TOPICS.read_text(encoding="utf-8")
        self.assertIn('likeCount = c.int("likeNum") ?? 0', topics)
        ledger = LEDGER.read_text(encoding="utf-8")
        self.assertIn('"pages/mylike/mylike"', ledger)
        routes = ROUTES.read_text(encoding="utf-8")
        self.assertIn('"/api/creativesquare/list": .liveInProduction', routes)
        self.assertIn('"/api/topic/like_list": .liveInProduction', routes)

    def test_swift_tests_were_added_without_removing_existing_ones(self):
        tests = TESTS.read_text(encoding="utf-8")
        names = re.findall(r"func (test\w+)", tests)
        self.assertEqual(len(names), len(set(names)))
        for kept in KEPT_COLLECTION_TESTS + ADDED_TESTS:
            self.assertIn(kept, names)
        posts = POSTS.read_text(encoding="utf-8")
        post_names = re.findall(r"func (test\w+)", posts)
        for kept in KEPT_POST_TESTS:
            self.assertIn(kept, post_names)
        added = tests.split("final class AccountCollectionFavoritesPageReadyTests", 1)[1]
        self.assertNotIn("http://", added)
        self.assertNotIn("https://", added)


if __name__ == "__main__":
    unittest.main()
