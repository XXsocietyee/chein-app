"""w2-07: source guards for topic pricing / partner and merchantapply parity."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text()


class W207PricingApplyParity(unittest.TestCase):
    def test_pricing_keeps_dormant_review_and_identifiers(self):
        view = read('App/PublisherLifecycleViews.swift')
        for exact in ['accessibilityIdentifier("publisher.subtype")', 'accessibilityIdentifier("publisher.preview")',
                      'accessibilityIdentifier("publisher.finalPrice")', 'accessibilityIdentifier("publisher.reviewPrice")',
                      'accessibilityIdentifier("publisher.confirmPrice")',
                      'TopicPricingXcx.sliderMax(floor: preview.minimum, reference: preview.reference)', '"publisherPricing.confirmFinalPriceAndSubmitFor"',
                      'preview.canConfirm == false', '"publisherPricing.thisPartnerLinkIsNoLonger"', '"publisherPricing.theLineupFreezesWhenSalesOpen"']:
            self.assertIn(exact, view)
        # MP pages/topic/pricing/index.js:419 confirmPrice posts /api/topic/pricing/confirm (:443).
        # R8-PC-B4-1: pricing confirm is a final-price save, not money (pages/topic/pricing/index.js:419-460).
        # The view sends it through the coordinator (which still needs the runtime pricing grant and a fresh review),
        # toasts res.msg and goes back; a 支付资质 note is the 终价已确认 modal (index.js:446-460).
        pricing = view.split('@MainActor struct PublisherPricingView', 1)[1].split('@MainActor struct PublisherPartnerView', 1)[0]
        self.assertIn('await coordinator.confirm(value, consequentialApproval: true)', pricing)
        self.assertIn('text.contains("支付资质")', pricing)
        self.assertNotIn('URLSession', pricing)
        self.assertIn('coordinator.confirm(value, consequentialApproval: true)', view)
        contract = read('Core/PlayerContentMPContract.swift')
        # R7-PC-B4-1: pricing confirm is a final-price save, not money (MP pages/topic/pricing/index.js:419-460).
        self.assertIn('public static var pricingGrantEnabled: Bool { true }', contract)
        self.assertIn('if !pricingGrantEnabled { throw Refusal.pricingGrantDisabled }', contract)
        # Copy moved from inline Chinese literals to catalog keys; the catalog must still carry the exact wording.
        import json
        catalog = json.loads(read('Resources/Localizable.xcstrings'))['strings']
        zh = lambda key: catalog[key]['localizations']['zh-Hans']['stringUnit']['value']
        self.assertEqual(zh('publisherPricing.confirmFinalPriceAndSubmitFor'), '确认终价并提交开售审核')
        self.assertEqual(zh('publisherPricing.thisPartnerLinkIsNoLonger'), '合作链接已失效')
        self.assertIn('开售后阵容冻结', zh('publisherPricing.theLineupFreezesWhenSalesOpen'))
        self.assertIn('"api/topic/pricing/preview"', read('Core/PublisherLifecycleHTTP.swift'))
        self.assertIn('public func partnerName(type: String, id: Int) async throws -> String', read('Core/PublisherLifecycleHTTP.swift'))
        self.assertIn('try? await client.partnerName(type: row.type, id: row.partnerID), generation == stamp', view)

    def test_topic_owner_pricing_entry_is_injected(self):
        self.assertIn(r'.environment(\.topicPricingDestination, session.publisherLifecycleContext', read('App/SessionTopicBrowserView.swift'))

    def test_merchant_apply_create_sends_source_dates(self):
        commands = read('Core/MerchantContentCommands.swift')
        self.assertIn('f["startDate"] = .string(range.start + " 00:00:00"); f["endDate"] = .string(range.end + " 23:59:59")', commands)
        editor = read('App/MerchantContentEditor.swift')
        self.assertIn('if case .registrationCreate = kind { applyDateSection }', editor)
        # 104580afa: the editor lists every missing field (allMissing) rather than only the first; dates still checked.
        self.assertIn('MerchantApplyXcx.allMissing(\n                address: text["address"] ?? "", startDay: draft.createStartDay, endDay: draft.createEndDay,', editor)
        self.assertIn('MerchantApplyXcx.editBlock(status: s.value["status"].integer', editor)


if __name__ == '__main__':
    unittest.main()
