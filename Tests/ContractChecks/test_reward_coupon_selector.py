"""MP `pages/publishkit/components/reward-selector` → native `RewardCouponSelectorRow` / sheet.

Pins the request shape (POST api/coupon/mypublishlist, is_select=1, no scope for a player), the MP sheet order
(优惠券/体验卡 tabs → 不发奖励 → loading / error + 重试 / empty / list), the three MP callers and both languages.
"""
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class RewardCouponSelectorContracts(unittest.TestCase):
    def setUp(self):
        self.core = (ROOT / "Core/RewardCouponSelection.swift").read_text()
        self.view = (ROOT / "App/RewardCouponSelector.swift").read_text()

    def test_request_is_the_mp_player_read(self):
        self.assertIn('public static let path = "api/coupon/mypublishlist"', self.core)
        self.assertIn('public static let fields: [String: String] = ["is_select": "1"]', self.core)
        self.assertNotIn('"scope"', self.core.split("public static let fields", 1)[1].split("\n", 1)[0])
        self.assertIn('request.httpMethod = "POST"', self.view)
        self.assertIn("ChinaReviewedProductionTransport(underlying:", self.view)

    def test_pass_is_coupon_type_three_and_errors_are_not_empty(self):
        self.assertIn("couponType == 3 ? .pass : .coupon", self.core)
        decode = self.core.split("public static func decode", 1)[1].split("public static func visible", 1)[0]
        self.assertIn("guard code == 200 else { throw RewardCouponSelectionError.failed }", decode)
        self.assertIn('page["rows"]', decode)

    def test_sheet_follows_mp_order_and_states(self):
        body = self.view.split("struct RewardCouponSelectorSheet", 1)[1]
        order = [body.index(token) for token in ['.cyAdaptiveSegmented()', '"rewardCoupon.none"', "Section { content }"]]
        self.assertEqual(order, sorted(order))
        for state in ["case .loading:", "case .failed:", '"rewardCoupon.retry"', "visible.isEmpty", "ForEach(visible)"]:
            self.assertIn(state, body)
        self.assertIn(".presentationDetents([.medium, .large])", self.view)
        self.assertNotIn(".font(.system(size:", self.view)

    def test_three_mp_callers_use_the_selector_when_the_session_supplies_it(self):
        callers = {
            "App/TemplateAuthoringDetailForms.swift": "RewardCouponSelectorRow(source: couponSource, couponID: rewards.coupon()",
            "App/MPGap/AccountPublish/ProjectEditBingoPage.swift": "RewardCouponSelectorRow(source: couponSource, couponID: $cell.couponID",
            "App/PublishingManagementViews.swift": "RewardCouponSelectorRow(source: couponSource, couponID: couponText",
        }
        for path, call in callers.items():
            text = (ROOT / path).read_text()
            self.assertIn("@Environment(\\.rewardCouponSource) private var couponSource", text, path)
            self.assertIn(call, text, path)
        for host in ["App/TemplateAuthoringLaunchView.swift", "App/SessionPublishingModesView.swift"]:
            self.assertIn(".environment(\\.rewardCouponSource, .session(session))", (ROOT / host).read_text(), host)

    def test_strings_have_en_and_zh(self):
        strings = json.loads((ROOT / "Resources/Localizable.xcstrings").read_text())["strings"]
        keys = {"rewardCoupon.title": "选择奖励", "rewardCoupon.none": "不发奖励", "rewardCoupon.kind.pass": "体验卡",
                "rewardCoupon.empty.coupon": "暂无可选优惠券", "rewardCoupon.occasion.node": "完成节点后发放",
                "rewardCoupon.selectedID %lld": "优惠券 #%lld"}
        for key, zh in keys.items():
            loc = strings[key]["localizations"]
            self.assertEqual(loc["zh-Hans"]["stringUnit"]["value"], zh)
            self.assertTrue(loc["en"]["stringUnit"]["value"])


if __name__ == "__main__":
    unittest.main()
