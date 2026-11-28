import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class HomeCityLocationConsentWiring(unittest.TestCase):
    def test_row_17_wires_the_existing_card_without_a_second_search_or_a_new_order(self):
        host = (ROOT / 'App/SessionHomeFeedView.swift').read_text()
        feed = (ROOT / 'App/HomeFeedView.swift').read_text()
        # mp-home r3 continue 31 (function audit P2-3b): 同意 records consent, then locates the city on the device.
        self.assertIn('cityLocationConsent: cityConsent.asks ? (agree: { agreeAndLocateHomeCity() }, decline: { cityConsent.decline() }) : nil', host)
        locate = host[host.index('private func agreeAndLocateHomeCity()'):host.index('private func selectHomeCity(')]
        self.assertIn('cityConsent.agree(session)', locate)
        self.assertIn('HomeCityCentre.nearest(to: fix.coordinate)', locate)
        self.assertNotIn('reverse-geocode', locate)
        self.assertNotIn('TextField', host)
        self.assertNotIn('.searchable', host)
        # P-021: one search, the system field drawn by `globalSearchField` (no second field, no capsule).
        self.assertEqual(host.count('.globalSearchField(search)'), 1)
        card = feed.index('if let consent = cityLocationConsent')
        rails = feed.index('feedSection(.recommended)')
        self.assertLess(card, rails)
        self.assertLess(rails, feed.index('feedSection(.nearby)'))
        self.assertLess(feed.index('feedSection(.nearby)'), feed.index('feedSection(.upcoming)'))

    def test_agree_records_privacy_policy_home_city_and_decline_saves_locally(self):
        model = (ROOT / 'App/HomeCityLocationConsentHost.swift').read_text()
        service = (ROOT / 'Core/AccountComplianceService.swift').read_text()
        subject = (ROOT / 'Core/AccountComplianceContracts.swift').read_text()
        self.assertIn('HomeCityLocationDeclineStore.saveLocationDeclined(true, defaults: defaults)', model)
        self.assertIn('HomeCityLocationDeclineStore.saveLocationDeclined(false, defaults: defaults)', model)
        self.assertIn('coordinator.recordHomeCityLocationAgree()', model)
        self.assertIn('case .homeCityLocation: return "home_city_location"', subject)
        self.assertIn('case .roamLocation, .homeCityLocation: return "privacy_policy"', subject)
        self.assertIn('fields["expectedRequestId"]', service)
        self.assertIn('subject == .cancellation || subject == .roamLocation || subject == .homeCityLocation', (ROOT / 'App/AppSession.swift').read_text())

    def test_unknown_is_an_em_dash_in_both_languages(self):
        record = (ROOT / 'Core/HomeCityLocationConsent.swift').read_text()
        self.assertIn('public static let unknownDisplay = "\u2014"', record)
        catalog = json.loads((ROOT / 'Resources/Localizable.xcstrings').read_text())['strings']
        for key in ('homeCityConsent.title', 'homeCityConsent.body', 'homeCityConsent.privacy', 'homeCityConsent.agree', 'homeCityConsent.decline', 'homeCityConsent.saveFailed', 'homeCityConsent.unknown'):
            entry = catalog[key]['localizations']
            for language in ('en', 'zh-Hans'):
                unit = entry[language]['stringUnit']
                self.assertEqual(unit['state'], 'translated')
                self.assertTrue(unit['value'].strip())
        self.assertEqual(catalog['homeCityConsent.unknown']['localizations']['en']['stringUnit']['value'], '\u2014')
        self.assertEqual(catalog['homeCityConsent.unknown']['localizations']['zh-Hans']['stringUnit']['value'], '\u2014')

    def test_card_primes_honestly_with_one_primary_and_a_quiet_not_now(self):
        # mp-home r3 continue 45 (P40): the coordinate is matched on the device and never sent, so the copy must not
        # say it is uploaded; one prominent 同意定位, a plain 暂不定位, and a privacy line.
        card = (ROOT / 'App/HomeCityLocationConsentCard.swift').read_text()
        self.assertIn('Label("homeCityConsent.privacy", systemImage: "lock.fill")', card)
        self.assertEqual(card.count('.buttonStyle(.borderedProminent)'), 1)
        self.assertIn('.buttonStyle(.borderless)', card)
        catalog = json.loads((ROOT / 'Resources/Localizable.xcstrings').read_text())['strings']
        for language in ('en', 'zh-Hans'):
            body = catalog['homeCityConsent.body']['localizations'][language]['stringUnit']['value']
            self.assertNotIn('sent to', body)
            self.assertNotIn('发送给', body)

    def test_glue_files_stay_at_the_ratchet_ceiling(self):
        # Never above the ratchet ceilings (lowered by E2E-20261112 when code moved out of the glue files).
        self.assertLessEqual(len((ROOT / 'App/AppSession.swift').read_text().splitlines()), 8171)
        self.assertLessEqual(len((ROOT / 'App/AppCompositionRoot.swift').read_text().splitlines()), 4184)


if __name__ == '__main__':
    unittest.main()
